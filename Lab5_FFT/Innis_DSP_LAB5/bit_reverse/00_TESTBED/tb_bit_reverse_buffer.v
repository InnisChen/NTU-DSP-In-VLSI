`timescale 1ns/1ps

module tb_bit_reverse_buffer;
    localparam DATA_W = 16;
    localparam CLK_PERIOD = 10;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_W-1:0] SDFOutRe;
    reg signed [DATA_W-1:0] SDFOutIm;

    wire br_valid_out;
    wire signed [DATA_W-1:0] BROutRe;
    wire signed [DATA_W-1:0] BROutIm;
    wire [4:0] br_out_idx;
    wire wr_bank;
    wire rd_bank;
    wire [4:0] wr_addr;
    wire [4:0] rd_addr;

    bit_reverse_buffer #(
        .DATA_W(DATA_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .SDFOutRe(SDFOutRe),
        .SDFOutIm(SDFOutIm),
        .br_valid_out(br_valid_out),
        .BROutRe(BROutRe),
        .BROutIm(BROutIm),
        .br_out_idx(br_out_idx),
        .wr_bank(wr_bank),
        .rd_bank(rd_bank),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    integer i;
    integer frame;
    integer out_count;
    integer err_count;
    integer expected_value;
    reg expected_rd_bank;
    reg [4:0] br_seq [0:31];

    initial begin
        br_seq[0] = 5'd0;  br_seq[1] = 5'd16; br_seq[2] = 5'd8;  br_seq[3] = 5'd24;
        br_seq[4] = 5'd4;  br_seq[5] = 5'd20; br_seq[6] = 5'd12; br_seq[7] = 5'd28;
        br_seq[8] = 5'd2;  br_seq[9] = 5'd18; br_seq[10] = 5'd10; br_seq[11] = 5'd26;
        br_seq[12] = 5'd6; br_seq[13] = 5'd22; br_seq[14] = 5'd14; br_seq[15] = 5'd30;
        br_seq[16] = 5'd1; br_seq[17] = 5'd17; br_seq[18] = 5'd9;  br_seq[19] = 5'd25;
        br_seq[20] = 5'd5; br_seq[21] = 5'd21; br_seq[22] = 5'd13; br_seq[23] = 5'd29;
        br_seq[24] = 5'd3; br_seq[25] = 5'd19; br_seq[26] = 5'd11; br_seq[27] = 5'd27;
        br_seq[28] = 5'd7; br_seq[29] = 5'd23; br_seq[30] = 5'd15; br_seq[31] = 5'd31;
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        SDFOutRe = {DATA_W{1'b0}};
        SDFOutIm = {DATA_W{1'b0}};
        out_count = 0;
        err_count = 0;

        $dumpfile("tb_bit_reverse_buffer.vcd");
        $dumpvars(0, tb_bit_reverse_buffer);

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        for (frame = 0; frame < 2; frame = frame + 1) begin
            for (i = 0; i < 32; i = i + 1) begin
                @(negedge clk);
                valid_in = 1'b1;
                SDFOutRe = br_seq[i];
                SDFOutIm = {DATA_W{1'b0}};
            end
        end

        @(negedge clk);
        valid_in = 1'b0;
        SDFOutRe = {DATA_W{1'b0}};
        SDFOutIm = {DATA_W{1'b0}};

        repeat (80) @(negedge clk);
        if (out_count == 64 && err_count == 0) begin
            $display("============================================================");
            $display("[PASS] tb_bit_reverse_buffer");
            $display("       Checked BROut order and ping-pong banks: 64 samples, 0 mismatches.");
            $display("============================================================");
        end else begin
            $display("============================================================");
            $display("[FAIL] tb_bit_reverse_buffer");
            $display("       Expected 64 BROut samples, got %0d.", out_count);
            $display("       Mismatches: %0d.", err_count);
            $display("============================================================");
        end
        $finish;
    end

    always @(posedge clk) begin
        if (br_valid_out) begin
            expected_value = out_count % 32;
            expected_rd_bank = (out_count >= 32);
            if (BROutRe !== expected_value[DATA_W-1:0]) begin
                $display("[ERROR] BROut order mismatch at %0d, got %0d, exp %0d.",
                         out_count, BROutRe, expected_value);
                err_count = err_count + 1;
            end
            if ((expected_value != 31) && (rd_bank !== expected_rd_bank)) begin
                $display("[ERROR] rd_bank mismatch at %0d, got %0d, exp %0d.",
                         out_count, rd_bank, expected_rd_bank);
                err_count = err_count + 1;
            end
            out_count = out_count + 1;
        end
    end
endmodule
