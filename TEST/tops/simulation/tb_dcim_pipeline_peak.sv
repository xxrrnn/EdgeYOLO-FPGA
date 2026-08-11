`timescale 1ns/1ps

// Sustained INT8 pipeline proof for the deployed DCIM arithmetic datapath.
//
// This test intentionally bypasses SRAM/ppCache loading: weight and activation
// transfer is outside the peak-compute denominator.  The instantiated
// calculate_core + postProcess modules are the unmodified modules instantiated
// by dcim.v.  Eight copies use the same parameters as DCIM_Array.
module tb_dcim_pipeline_peak;
    localparam integer NUM_TILES = 8;
    localparam integer CH_IN = 64;
    localparam integer CH_OUT = 32;
    localparam integer WD1 = 4;
    localparam integer ACC = 80;
    localparam integer BATCH_JOBS = 32;
    localparam integer PHASES_PER_JOB = 2;
    localparam integer PHASE_COUNT = BATCH_JOBS * PHASES_PER_JOB;
    localparam integer OUT_WORDS_PER_TILE = CH_OUT / 2 / 4;
    localparam integer EXPECTED_WORDS_PER_TILE = BATCH_JOBS * OUT_WORDS_PER_TILE;
    localparam integer WEIGHT_WORDS_PER_TILE = CH_IN * CH_OUT * WD1 / 128;
    localparam integer WD2 = 2*WD1 + $clog2(CH_IN);
    localparam integer WD3 = WD2 + $clog2(ACC);

    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg clr = 1'b0;
    reg phase_valid = 1'b0;
    reg [CH_IN*WD1-1:0] phase_data = '0;
    reg [15:0] issue_job_id = '0;
    reg issue_phase = 1'b0;

    wire [NUM_TILES-1:0] phase_ready;
    wire [NUM_TILES-1:0] post_ready;
    wire [NUM_TILES-1:0] ma_valid;
    wire [NUM_TILES-1:0] merge_valid;
    wire [NUM_TILES-1:0] merge_accum_valid;
    wire [NUM_TILES-1:0] result_valid;
    wire [WD2*CH_OUT-1:0] ma_data [0:NUM_TILES-1];
    wire [WD3*CH_OUT-1:0] result_data [0:NUM_TILES-1];
    reg  [CH_IN*CH_OUT*WD1-1:0] weight_bus [0:NUM_TILES-1];

    reg [127:0] weight_words [0:NUM_TILES*WEIGHT_WORDS_PER_TILE-1];
    reg [CH_IN*WD1-1:0] phase_words [0:PHASE_COUNT-1];
    reg [127:0] expected_words [0:NUM_TILES*EXPECTED_WORDS_PER_TILE-1];
    string data_dir;

    longint unsigned cycle_count = 0;
    integer issue_phase_count = 0;
    integer result_job_count = 0;
    longint signed first_issue_cycle = -1;
    longint signed last_issue_cycle = -1;
    longint signed first_result_cycle = -1;
    longint signed last_result_cycle = -1;
    integer mismatch_count = 0;

    // Stable top-level aliases for compact FSDB/Verdi evidence.
    wire [NUM_TILES-1:0] peak_issue_fire_mask =
        {NUM_TILES{phase_valid}} & phase_ready;
    wire [15:0] peak_issue_job = issue_job_id;
    wire peak_issue_phase = issue_phase;
    wire [31:0] peak_tile0_input = phase_data[31:0];
    wire [NUM_TILES-1:0] peak_ma_valid = ma_valid;
    wire [NUM_TILES-1:0] peak_merge_valid = merge_valid;
    wire [NUM_TILES-1:0] peak_accum_valid = merge_accum_valid;
    wire [NUM_TILES-1:0] peak_result_valid = result_valid;
    wire [15:0] peak_result_job = result_job_count[15:0];
    wire signed [31:0] peak_tile0_result =
        {{(32-WD3){result_data[0][WD3-1]}}, result_data[0][0 +: WD3]};
    reg [31:0] peak_tile0_expected;

    // Short display aliases: nWave's default signal-name pane is intentionally
    // narrow in automated screenshots.
    wire [15:0] IJ = peak_issue_job;
    wire        IP = peak_issue_phase;
    wire [7:0]  IM = peak_issue_fire_mask;
    wire [31:0] ID = peak_tile0_input;
    wire [7:0]  MV = peak_ma_valid;
    wire [7:0]  GV = peak_merge_valid;
    wire [7:0]  AV = peak_accum_valid;
    wire [7:0]  RV = peak_result_valid;
    wire [15:0] OJ = peak_result_job;
    wire [31:0] OD = peak_tile0_result;
    wire [31:0] EX = peak_tile0_expected;

    always #2 clk = ~clk; // 250 MHz

    genvar tile;
    generate
        for (tile = 0; tile < NUM_TILES; tile = tile + 1) begin : gen_tiles
            calculate_core #(
                .WD1(WD1),
                .CH_IN(CH_IN),
                .CH_OUT(CH_OUT),
                .MULT_DSP_EN(1),
                .DSP_COL_NUM(3),
                .DSP_PARTIAL_SUBCOL(3)
            ) u_calculate_core (
                .clk(clk),
                .rstn(rstn),
                .clr(clr),
                .ena(1'b1),
                .mode(`MODE_INT8),
                .up_valid(phase_valid),
                .up_ready(phase_ready[tile]),
                .up_data1(phase_data),
                .up_data2(weight_bus[tile]),
                .dn_valid(ma_valid[tile]),
                .dn_ready(post_ready[tile]),
                .dn_data(ma_data[tile])
            );

            postProcess #(
                .WD1(WD1),
                .CH_IN(CH_IN),
                .CH_OUT(CH_OUT),
                .ACC(ACC)
            ) u_post_process (
                .clk(clk),
                .rstn(rstn),
                .clr(clr),
                .ena(1'b1),
                .mode(`MODE_INT8),
                .acc(7'd0),
                .up_valid(ma_valid[tile]),
                .up_ready(post_ready[tile]),
                .up_data(ma_data[tile]),
                .dn_valid(result_valid[tile]),
                .dn_ready(1'b1),
                .dn_data(result_data[tile])
            );

            assign merge_valid[tile] = u_post_process.merge_valid;
            assign merge_accum_valid[tile] = u_post_process.pipe_valid;
        end
    endgenerate

    // This assertion proves that all eight ready chains remain lock-step.
    always @(posedge clk) begin
        if (rstn && (phase_valid || (issue_phase_count != 0 && result_job_count < BATCH_JOBS))) begin
            if ((phase_ready !== {NUM_TILES{1'b1}}) && phase_valid)
                $fatal(1, "PIPELINE_STALL cycle=%0d ready=0x%0h", cycle_count, phase_ready);
        end
    end

    function automatic [31:0] logical_result_lane(
        input [WD3*CH_OUT-1:0] data,
        input integer logical_lane
    );
        reg signed [WD3-1:0] physical_value;
        begin
            physical_value = data[(logical_lane*2)*WD3 +: WD3];
            logical_result_lane = {{(32-WD3){physical_value[WD3-1]}}, physical_value};
        end
    endfunction

    function automatic [127:0] pack_result_word(
        input [WD3*CH_OUT-1:0] data,
        input integer word_index
    );
        reg [127:0] packed_word;
        integer lane;
        begin
            packed_word = '0;
            for (lane = 0; lane < 4; lane = lane + 1)
                packed_word[lane*32 +: 32] = logical_result_lane(data, word_index*4 + lane);
            pack_result_word = packed_word;
        end
    endfunction

    integer init_tile;
    integer init_word;
    initial begin : load_vectors
        if (!$value$plusargs("DATA_DIR=%s", data_dir))
            data_dir = ".";
        $readmemh({data_dir, "/weight_all_tiles.hex"}, weight_words);
        $readmemh({data_dir, "/activation_phase.hex"}, phase_words);
        $readmemh({data_dir, "/expected_all_tiles.hex"}, expected_words);
        for (init_tile = 0; init_tile < NUM_TILES; init_tile = init_tile + 1) begin
            weight_bus[init_tile] = '0;
            for (init_word = 0; init_word < WEIGHT_WORDS_PER_TILE; init_word = init_word + 1)
                weight_bus[init_tile][init_word*128 +: 128] =
                    weight_words[init_tile*WEIGHT_WORDS_PER_TILE + init_word];
        end
    end

    initial begin : fsdb_dump
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("tb_dcim_pipeline_peak.fsdb");
            $fsdbDumpvars(1, tb_dcim_pipeline_peak);
            $fsdbDumpon();
            $display("PIPELINE_FSDB=tb_dcim_pipeline_peak.fsdb");
        end
    end

    initial begin : reset_and_stimulus
        integer phase_index;
        repeat (8) @(negedge clk);
        rstn = 1'b1;
        repeat (4) @(negedge clk);
        wait (&phase_ready);

        // A single continuous valid run: every pair of cycles is one complete
        // M=1,K=64,N=128 job. There are no injected bubbles.
        for (phase_index = 0; phase_index < PHASE_COUNT; phase_index = phase_index + 1) begin
            @(negedge clk);
            phase_valid = 1'b1;
            phase_data = phase_words[phase_index];
            issue_job_id = phase_index / PHASES_PER_JOB;
            issue_phase = phase_index % PHASES_PER_JOB;
        end
        @(negedge clk);
        phase_valid = 1'b0;
        phase_data = '0;

        fork
            begin
                wait (result_job_count == BATCH_JOBS);
                repeat (4) @(posedge clk);
            end
            begin
                repeat (300) @(posedge clk);
                $fatal(1, "PIPELINE_TIMEOUT results=%0d/%0d", result_job_count, BATCH_JOBS);
            end
        join_any
        disable fork;

        $display(
            "PIPELINE_METRIC batch_jobs=%0d issue_phases=%0d result_jobs=%0d first_issue_cycle=%0d last_issue_cycle=%0d first_result_cycle=%0d last_result_cycle=%0d mismatches=%0d",
            BATCH_JOBS, issue_phase_count, result_job_count,
            first_issue_cycle, last_issue_cycle, first_result_cycle,
            last_result_cycle, mismatch_count
        );
        if (mismatch_count == 0 && issue_phase_count == PHASE_COUNT &&
            result_job_count == BATCH_JOBS &&
            (last_issue_cycle - first_issue_cycle + 1) == PHASE_COUNT &&
            (last_result_cycle - first_result_cycle) == (BATCH_JOBS-1)*2) begin
            $display("PIPELINE CHECK PASSED");
            $finish;
        end else begin
            $fatal(1, "PIPELINE CHECK FAILED");
        end
    end

    integer score_tile;
    integer score_word;
    reg [127:0] actual_word;
    reg [127:0] expected_word;
    always @(posedge clk) begin : scoreboard
        if (!rstn) begin
            cycle_count = 0;
        end else begin
            cycle_count = cycle_count + 1;
            if (|peak_issue_fire_mask) begin
                if (peak_issue_fire_mask !== {NUM_TILES{1'b1}})
                    $fatal(1, "PIPELINE_ISSUE_SKEW cycle=%0d mask=0x%0h", cycle_count, peak_issue_fire_mask);
                if (first_issue_cycle < 0)
                    first_issue_cycle = cycle_count;
                last_issue_cycle = cycle_count;
                issue_phase_count = issue_phase_count + 1;
                if (issue_phase_count <= 8)
                    $display(
                        "PIPELINE_ISSUE cycle=%0d job=%0d phase=%0d mask=0x%0h input=0x%08h",
                        cycle_count, issue_job_id, issue_phase, peak_issue_fire_mask, phase_data[31:0]
                    );
            end

            if (|result_valid) begin
                if (result_valid !== {NUM_TILES{1'b1}})
                    $fatal(1, "PIPELINE_RESULT_SKEW cycle=%0d mask=0x%0h", cycle_count, result_valid);
                if (first_result_cycle < 0)
                    first_result_cycle = cycle_count;
                last_result_cycle = cycle_count;
                for (score_tile = 0; score_tile < NUM_TILES; score_tile = score_tile + 1) begin
                    for (score_word = 0; score_word < OUT_WORDS_PER_TILE; score_word = score_word + 1) begin
                        actual_word = pack_result_word(result_data[score_tile], score_word);
                        expected_word = expected_words[
                            score_tile*EXPECTED_WORDS_PER_TILE +
                            result_job_count*OUT_WORDS_PER_TILE + score_word
                        ];
                        if (actual_word !== expected_word) begin
                            mismatch_count = mismatch_count + 1;
                            if (mismatch_count <= 8)
                                $display(
                                    "PIPELINE_MISMATCH job=%0d tile=%0d word=%0d actual=%032h expected=%032h",
                                    result_job_count, score_tile, score_word, actual_word, expected_word
                                );
                        end
                    end
                end
                if (result_job_count < 8)
                    $display(
                        "PIPELINE_RESULT cycle=%0d job=%0d mask=0x%0h tile0_ch0=0x%08h",
                        cycle_count, result_job_count, result_valid,
                        logical_result_lane(result_data[0], 0)
                    );
                result_job_count = result_job_count + 1;
            end
        end
    end

    always @* begin
        if (result_job_count < BATCH_JOBS)
            peak_tile0_expected = expected_words[result_job_count*OUT_WORDS_PER_TILE][31:0];
        else
            peak_tile0_expected = '0;
    end

endmodule
