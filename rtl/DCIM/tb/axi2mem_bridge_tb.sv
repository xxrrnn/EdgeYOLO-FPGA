`timescale 1ns/1ps

module tb_axi2dcim_bridge();

    // --------------------------------------------------------
    // 参数定义 (与 DUT 保持一致)
    // --------------------------------------------------------
    parameter AXI_DATA_WIDTH = 64;
    parameter AXI_ADDR_WIDTH = 64;
    parameter WEI_DEPTH      = 128;
    parameter ACT_DEPTH      = 64;
    parameter RES_DEPTH      = 64;
    parameter WEI_DATA_WIDTH = 128;
    parameter ACT_DATA_WIDTH = 64;
    parameter RES_DATA_WIDTH = 256;
    localparam WEI_ADDR_WIDTH= $clog2(WEI_DEPTH);
    localparam ACT_ADDR_WIDTH= $clog2(ACT_DEPTH);
    localparam RES_ADDR_WIDTH= $clog2(RES_DEPTH);
    parameter LOAD_CYCLE     = 8;

    // --------------------------------------------------------
    // 时钟与复位
    // --------------------------------------------------------
    logic clk;
    logic rstn;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // --------------------------------------------------------
    // DUT 接口信号
    // --------------------------------------------------------
    // AXI Interface
    logic                        axi_req;
    logic                        axi_we;
    logic [AXI_ADDR_WIDTH-1:0]   axi_addr;
    logic [AXI_ADDR_WIDTH/8-1:0] axi_be;
    logic [AXI_DATA_WIDTH-1:0]   axi_wdata;
    logic [AXI_DATA_WIDTH-1:0]   axi_rdata;

    // DCIM Interface (Mock)
    logic                        dcim_ena;
    logic                        dcim_clr;
    logic                        dcim_mode_cal;
    logic                        dcim_acc;
    logic                        dcim_wr_wei;
    logic                        dcim_load;
    logic                        dcim_swap;
    logic                        dcim_ready_wei;
    logic [WEI_ADDR_WIDTH-1:0]   dcim_addr_wei;
    logic [WEI_DATA_WIDTH-1:0]   dcim_data_wei;
    logic [WEI_DATA_WIDTH-1:0]   dcim_be_wei;
    logic                        dcim_valid_cal;
    logic                        dcim_ready_cal;
    logic [ACT_DATA_WIDTH-1:0]   dcim_data_cal;
    logic                        dcim_valid_res;
    logic                        dcim_ready_res;
    logic [RES_DATA_WIDTH-1:0]   dcim_data_res;

    // --------------------------------------------------------
    // 例化顶层模块 (DUT)
    // --------------------------------------------------------
    axi2dcim_bridge #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .WEI_DEPTH     (WEI_DEPTH     ),
        .ACT_DEPTH     (ACT_DEPTH     ),
        .RES_DEPTH     (RES_DEPTH     ),
        .WEI_DATA_WIDTH(WEI_DATA_WIDTH),
        .ACT_DATA_WIDTH(ACT_DATA_WIDTH),
        .RES_DATA_WIDTH(RES_DATA_WIDTH),
        .LOAD_CYCLE    (LOAD_CYCLE    )
    ) u_dut (
        .clk            (clk            ),
        .rstn           (rstn           ),
        
        .axi_req_i      (axi_req        ),
        .axi_we_i       (axi_we         ),
        .axi_addr_i     (axi_addr       ),
        .axi_be_i       (axi_be         ),
        .axi_wdata_i    (axi_wdata      ),
        .axi_rdata_o    (axi_rdata      ),
        
        .dcim_ena       (dcim_ena       ),
        .dcim_clr       (dcim_clr       ),
        .dcim_mode_cal  (dcim_mode_cal  ),
        .dcim_acc       (dcim_acc       ),
        .dcim_wr_wei    (dcim_wr_wei    ),
        .dcim_load      (dcim_load      ),
        .dcim_swap      (dcim_swap      ),
        
        .dcim_ready_wei (dcim_ready_wei ),
        .dcim_addr_wei  (dcim_addr_wei  ),
        .dcim_data_wei  (dcim_data_wei  ),
        .dcim_be_wei    (dcim_be_wei    ),
        
        .dcim_valid_cal (dcim_valid_cal ),
        .dcim_ready_cal (dcim_ready_cal ),
        .dcim_data_cal  (dcim_data_cal  ),
        
        .dcim_valid_res (dcim_valid_res ),
        .dcim_ready_res (dcim_ready_res ),
        .dcim_data_res  (dcim_data_res  )
    );

    // --------------------------------------------------------
    // AXI 读写 Task 封装
    // --------------------------------------------------------
    task automatic axi_write(input [63:0] addr, input [63:0] data);
        @(posedge clk);
        axi_req   <= 1'b1;
        axi_we    <= 1'b1;
        axi_addr  <= addr;
        axi_wdata <= data;
        axi_be    <= 8'hFF; // 默认全字写
        @(posedge clk);
        axi_req   <= 1'b0;
        axi_we    <= 1'b0;
    endtask

    task automatic axi_read(input [63:0] addr);
        @(posedge clk);
        axi_req   <= 1'b1;
        axi_we    <= 1'b0;
        axi_addr  <= addr;
        @(posedge clk);
        axi_req   <= 1'b0;
        $display("[%0t] READ ADDR: 0x%h, DATA: 0x%h", $time, addr, axi_rdata);
    endtask

	// --------------------------------------------------------
    // 真实的 DCIM 阵列例化
    // --------------------------------------------------------
    // 假设你的模块名叫 dcim_array_top
    dcim_array_top u_real_dcim_array (
        .clk            (clk            ),
        .rstn           (rstn           ),
        .clr       		(dcim_clr       ),
		.ena			(dcim_ena		),		

        // 控制与配置信号
        .dcim_mode_cal  (dcim_mode_cal  ), // 控制阵列的精度模式 (如 INT4/INT8/INT16)
        .dcim_acc       (dcim_acc       ),

        // 权重加载接口 (SRAM 接口)
        .wr_wei    		(dcim_wr_wei    ),
        .load_wei      	(dcim_load      ),
        .swap_wei      	(dcim_swap      ),
        .up_ready_wei 	(dcim_ready_wei ),
        .up_addr_wei  	(dcim_addr_wei  ),
        .up_data_wei  	(dcim_data_wei  ),
        .up_be_wei    	(dcim_be_wei    ),

        // 激活值输入 (ACT 流)
        .up_valid_cal 	(dcim_valid_cal ),
        .up_ready_cal 	(dcim_ready_cal ),
        .up_data_cal  	(dcim_data_cal  ),

        // 计算结果输出 (RES 流)
        .dn_valid 		(dcim_valid_res ),
        .dn_ready 		(dcim_ready_res ),
        .dn_data  		(dcim_data_res  )
    );

    // --------------------------------------------------------
    // 测试激励主流程 (Test Sequence)
    // --------------------------------------------------------
    initial begin
        $fsdbDumpfile("waveform.fsdb"); // 为 GTKWave 抓取波形
        $fsdbDumpvars(0, tb_axi2dcim_bridge);

        // 初始化
        rstn      = 0;
        axi_req   = 0;
        axi_we    = 0;
        axi_addr  = 0;
        axi_wdata = 0;
        axi_be    = 0;
        
        #25 rstn = 1; // 释放复位
        #20;

        $display("========================================");
        $display(" 1. 预加载 WEI 与 ACT 数据");
        $display("========================================");
        // WEI 基地址 0x1000
        axi_write(64'h1000, 64'hAAAA_AAAA_AAAA_AAAA); 
        axi_write(64'h1008, 64'hBBBB_BBBB_BBBB_BBBB); 
        // ACT 基地址 0x2000
        axi_write(64'h2000, 64'h0000_0000_0000_1111);
        axi_write(64'h2008, 64'h0000_0000_0000_2222);
        #30;

        $display("========================================");
        $display(" 2. 配置 CSR 寄存器 (ADDR_CFG)");
        $display("========================================");
        // CSR 偏移 0x40
        // BusCfg 结构: cfg_ena[30], cfg_act_len[20:14]=2, cfg_res_len[13:7]=2
        // 数据拼接: (1<<30) | (2<<14) | (2<<7) = 0x40008100
        axi_write(64'h0040, 64'h40008100);
        #20;

        $display("========================================");
        $display(" 3. 触发 LOAD 脉冲加载权重");
        $display("========================================");
        axi_write(64'h0010, 64'h0); // 偏移 0x10 为 ADDR_LOAD
        #(LOAD_CYCLE * 10 + 20);    // 等待状态机退出 ST_LOAD

        $display("========================================");
        $display(" 4. 触发 START 脉冲启动计算");
        $display("========================================");
        axi_write(64'h0000, 64'h0); // 偏移 0x00 为 ADDR_START

        // 给 FSM 一点时间把数据推给 DCIM，再把结果吸回 RES Buffer
        #150; 

        $display("========================================");
        $display(" 5. 通过 AXI 读取计算结果");
        $display("========================================");
        // RES 基地址 0x3000
        axi_read(64'h3000);
        axi_read(64'h3008);
        axi_read(64'h3010);
        axi_read(64'h3018);

        #50;
        $display("========================================");
        $display(" 仿真结束，请打开 VCD 检查波形！");
        $display("========================================");
        $finish;
    end

endmodule
