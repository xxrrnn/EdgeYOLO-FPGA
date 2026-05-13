`timescale 1ns/1ps

module tb_dcim_cell_array;

    // Parameters
    parameter NUM_CELL_PER_DCIM = 32;
    parameter WEIGHT_DW = 8;
    parameter ACT_DW = 8;
    parameter OUT_DW = 32;

    // Signals
    reg clk;
    reg rst_n;
    reg [WEIGHT_DW * NUM_CELL_PER_DCIM-1:0] w_buf;
    reg [ACT_DW * NUM_CELL_PER_DCIM-1:0] a_buf;
    wire [OUT_DW-1:0] cell_out;
    reg in_valid;

    // Instantiate DUT
    dcim_cell_array #(
        .WEIGHT_DW(WEIGHT_DW),
        .NUM_CELL_PER_DCIM(NUM_CELL_PER_DCIM),
        .ACT_DW(ACT_DW),
        .OUT_DW(OUT_DW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .w_buf(w_buf),
        .a_buf(a_buf),
        .in_valid(in_valid),
        .cell_out(cell_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // Test stimulus
    initial begin
        // Reset
        rst_n = 0;
        w_buf = 0;
        a_buf = 0;
        #20;
        rst_n = 1;

        // Apply some example weights and activations
        w_buf = 256'h32D737F7BCAC41876DE929297D63E403191EBD2ED83E54113457127B76EDF7B5; // example weights
        a_buf = 256'h241F3302A9658317E848340C293D0174B75F2FADE1F83B2D6A3F9125246617A5; // example activations
        in_valid = 1'b1;
        // Wait enough cycles for computation
        #200;

        // Print result
        $display("cell_out = %0d", cell_out);

        // $finish;
    end

endmodule
