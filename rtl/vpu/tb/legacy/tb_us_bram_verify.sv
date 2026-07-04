`timescale 1ns/1ps
module tb_us_bram_verify;
  localparam VPU_BW=256, DEPTH=16384, VPU_ADDR_W=32, NB_COL=32;
  reg clk=0, rst_n=0, us_unit_start=0;
  wire us_unit_ready;
  reg [31:0] us_src_addr, us_src_h, us_src_w, us_src_c, us_dst_addr;
  wire [VPU_ADDR_W-1:0] gb_addrb;
  wire [VPU_BW-1:0] gb_dinb, gb_doutb;
  wire [VPU_BW/8-1:0] gb_web;
  wire gb_enb;
  always #2 clk=~clk;
  us_unit_fixed #(.ADDR_WIDTH(32),.VB_BANDWIDTH(VPU_BW),.VPU_ADDR_WIDTH(VPU_ADDR_W),.FP_WIDTH(32)) dut(
    .clk(clk),.rst_n(rst_n),.us_unit_start(us_unit_start),.us_unit_ready(us_unit_ready),
    .us_src_addr(us_src_addr),.us_src_h(us_src_h),.us_src_w(us_src_w),.us_src_c(us_src_c),.us_dst_addr(us_dst_addr),
    .gb_addrb(gb_addrb),.gb_dinb(gb_dinb),.gb_web(gb_web),.gb_enb(gb_enb),.gb_doutb(gb_doutb));
  global_buffer_bram #(.NB_COL(NB_COL),.COL_WIDTH(8),.RAM_DEPTH(DEPTH)) bram(
    .addra(14'b0),.addrb(gb_addrb[13:0]),.dina(256'b0),.dinb(gb_dinb),.clka(clk),
    .wea(32'b0),.web(gb_web),.ena(1'b0),.enb(gb_enb),.rsta(1'b0),.rstb(1'b0),
    .regcea(1'b1),.regceb(1'b1),.douta(),.doutb(gb_doutb));
  integer errors;
  initial begin
    errors=0;
    rst_n=0; #20; rst_n=1;
    us_src_addr=0; us_dst_addr=51200; us_src_h=10; us_src_w=10; us_src_c=128;
    @(posedge clk); us_unit_start=1; @(posedge clk); us_unit_start=0;
    wait(us_unit_ready==0); wait(us_unit_ready==1); #200;
    if (bram.BRAM[1600][31:0] !== 32'h0) errors=errors+1;
    if (errors==0) $display("PASS 128ch US in 512KB BRAM model"); else $display("FAIL");
    $finish;
  end
endmodule
