#include <iostream>
#include <memory>
#include <verilated.h>
#include "Vdcim_wrapper.h"
#include "verilated_vcd_c.h"

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

class TopTB {
public:
    Vdcim_wrapper* dut; 
    VerilatedVcdC* tfp;

    TopTB() {
        dut = new Vdcim_wrapper;
        tfp = new VerilatedVcdC;
        Verilated::traceEverOn(true);
        dut->trace(tfp, 99); 
        tfp->open("waveform.vcd");

        dut->clk = 0;
		dut->rstn = 0;
        dut->axi_req_i = 0;
		dut->axi_we_i = 0;
        dut->axi_addr_i = 0;
		dut->axi_wdata_i = 0;
		dut->axi_be_i = 0;
    }

    ~TopTB() {
        tfp->close(); delete dut; delete tfp;
    }

    void tick() {
        dut->clk = 0; dut->eval(); tfp->dump(main_time++);
        dut->clk = 1; dut->eval(); tfp->dump(main_time++);
    }

    void reset() {
        dut->rstn = 0; for(int i=0; i<5; i++) tick();
        dut->rstn = 1; tick();
    }

    void axi_write(uint64_t addr, uint64_t data, uint64_t be = 0xFF) {
        dut->axi_req_i = 1;
		dut->axi_we_i = 1;
        dut->axi_addr_i = addr;
		dut->axi_wdata_i = data;
		dut->axi_be_i = be;
        tick();
        dut->axi_req_i = 0; dut->axi_we_i = 0;
    }

	void axi_read(uint64_t addr) {
		dut->axi_req_i = 1;
		dut->axi_we_i = 0;
		dut->axi_addr_i = addr;
		std::cout << "Read time: " << std::dec << main_time << ", address: 0x" << std::hex << addr << std::endl;
		tick();
		std::cout << dut->axi_rdata_o << std::endl;
	}
};

int main(int argc, char** argv) {
   Verilated::commandArgs(argc, argv);
    TopTB tb;
    tb.reset();
	/*
		CFG_ENA_ADDR		=	AXI_BASE_ADDR + 16'h0000;
		CFG_MODE_ADDR		=	AXI_BASE_ADDR + 16'h0008;
		CFG_ACC_ADDR		=	AXI_BASE_ADDR + 16'h0010;
		CFG_RES_RIGHT_ADDR	=	AXI_BASE_ADDR + 16'h0018;
		CFG_ACT_LEN_ADDR	=	AXI_BASE_ADDR + 16'h0020;
		CFG_LOOP_ADDR		=	AXI_BASE_ADDR + 16'h0028
	*/
    std::cout << "--- DCIM SoC Testbench Started ---" << std::endl;

	// -----------------------------------------------------------
    // 0. 花 6 个周期初始化配置寄存器ena
    // -----------------------------------------------------------
	tb.axi_write(0x0000, 1);	// ena
	tb.axi_write(0x0008, 0);	// mode
	tb.axi_write(0x0010, 0);	// acc
	tb.axi_write(0x0018, 0);	// res_right
	tb.axi_write(0x0020, 0);	// act_len
	tb.axi_write(0x0028, 0);	// loop

	// -----------------------------------------------------------
    // 1. 花 256 个周期向 WEI Buffer 写入数据 (基地址 0x1000)
    // 深度 128，宽度 128-bit。通过 64-bit AXI 需要写 256 次。
    // -----------------------------------------------------------
    std::cout << "=== 1. Write Data to DCIM WEI Buffer (256 writes for 128 depth) ===" << std::endl;
    for(int i = 0; i < 128; i++) {
        // 写低 64 位 (存在 wei_packer 锁存器中)
        tb.axi_write(0x1000 + (i * 16) + 0, 0x10000000ULL + i); 
        // 写高 64 位 (触发 packer 组装成 128-bit 并产生 wei_wr 脉冲)
        tb.axi_write(0x1000 + (i * 16) + 8, 0x20000000ULL + i); 
    }

    // -----------------------------------------------------------
    // 2. 发送 LOAD 指令 (ADDR_LOAD = 0x0110)
    // -----------------------------------------------------------
    std::cout << "=== 2. Trigger LOAD and wait ===" << std::endl;
    tb.axi_write(0x0110, 0x1ULL);
    for(int i = 0; i < 5; i++) tb.tick();

    // -----------------------------------------------------------
    // 3. 花 64 个周期向 ACT Buffer 写入数据 (基地址 0x2000)
    // 深度 64，宽度 64-bit。直接写 64 次。
    // -----------------------------------------------------------
    std::cout << "=== 3. Write Data to ACT Buffer (64 cycles) ===" << std::endl;
    for(int i = 0; i < 64; i++) {
        tb.axi_write(0x2000 + (i * 8), 0x30000000ULL + i);
    }

    // -----------------------------------------------------------
    // 4. 动态拼接并配置 CFG 寄存器 
	// -----------------------------------------------------------
	std::cout << "=== 4. Configure CSR (ADDR_CFG = 0x0000) ===" << std::endl;
	//tb.axi_write(0x0000, 1);	// ena
	//tb.axi_write(0x0008, 0);	// mode
	//tb.axi_write(0x0010, 0);	// acc
	tb.axi_write(0x0018, 1);	// res_right
	tb.axi_write(0x0020, 64);	// act_len
	//tb.axi_write(0x0028, 0);	// loop


    for(int i = 0; i < 5; i++) tb.tick(); // 等待配置落盘

    // -----------------------------------------------------------
    // 5. 发送 START 指令 (ADDR_START = 0x0120)
    // -----------------------------------------------------------
    std::cout << "=== 5. Trigger START ===" << std::endl;
    tb.axi_write(0x0108, 0x1ULL);

    // -----------------------------------------------------------
    // 6. 让流水线运转以观察波形
    // -----------------------------------------------------------
    std::cout << "=== 6. Running Pipeline... ===" << std::endl;
    // 运行 150 个周期，观察 Valid/Ready 的握手以及结果算出
    for(int i = 0; i < 150; i++) {
        tb.tick();
    }

    // -----------------------------------------------------------
    // 7. 取回权限并读取结果 (RES Buffer 读取)
    // -----------------------------------------------------------
    std::cout << "=== 7. Reclaim RES Buffer right and Read Results ===" << std::endl;
    // 重写 CFG 寄存器，把 res_right 设回 0，交还给 AXI
	// res_right = 0;

	//tb.axi_write(0x0000, 1);	// ena
	//tb.axi_write(0x0008, 0);	// mode
	//tb.axi_write(0x0010, 0);	// acc
	tb.axi_write(0x0018, 0);	// res_right
	//tb.axi_write(0x0020, 64);	// act_len
	//tb.axi_write(0x0028, 0);	// loop

    for(int i = 0; i < 3; i++) tb.tick();

    // RES_ADDR = 0x3000。结果宽度 256-bit，Ratio=4。
    // 连续读 4 个 64-bit AXI 地址，即可拼凑出一个完整的 256-bit 结果
    tb.axi_read(0x3000); // Index 0 (Sub-word 0)
    tb.axi_read(0x3008); // Index 0 (Sub-word 1)
    tb.axi_read(0x3010); // Index 0 (Sub-word 2)
    tb.axi_read(0x3018); // Index 0 (Sub-word 3)
    
    // 再读下一个 256-bit 结果
    tb.axi_read(0x3020); 
	return 0;
}
