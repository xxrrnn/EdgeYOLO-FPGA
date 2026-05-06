module rf128x128(clk,cen,gwen,wen,a,d,q,ema,emaw,emas,ret1n);
input  clk;
input  cen;
input  gwen;
input  [127:0]wen;
input  [6:0]a;
input  [127:0]d;
output [127:0]q;
input  [2:0]ema;
input  [1:0]emaw;
input  emas;
input  ret1n;
endmodule

module rf64x128(clk,cen,gwen,wen,a,d,q,ema,emaw,emas,ret1n);
input  clk;
input  cen;
input  gwen;
input  [127:0]wen;
input  [5:0]a;
input  [127:0]d;
output [127:0]q;
input  [2:0]ema;
input  [1:0]emaw;
input  emas;
input  ret1n;
endmodule

module rf64x64(clk,cen,gwen,wen,a,d,q,ema,emaw,emas,ret1n);
input  clk;
input  cen;
input  gwen;
input  [63:0]wen;
input  [5:0]a;
input  [63:0]d;
output [63:0]q;
input  [2:0]ema;
input  [1:0]emaw;
input  emas;
input  ret1n;
endmodule

