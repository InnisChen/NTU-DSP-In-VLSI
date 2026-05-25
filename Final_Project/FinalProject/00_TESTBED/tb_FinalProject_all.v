`timescale 1ns/1ps

module tb_FinalProject_all;

localparam WI = 17;
localparam WO = 17;
localparam FRAC_W = 12;
localparam ACC_W = 27;
localparam CORDIC_STAGES = 10;
localparam ITER_MAX = 7;
localparam SETS = 11;

reg Clk;
reg Reset;
reg InValid;
reg signed [WI-1:0] InData1;
reg signed [WI-1:0] InData2;
reg signed [WI-1:0] InData3;
wire OutValid;
wire signed [WO-1:0] OutData1;
wire signed [WO-1:0] OutData2;
wire signed [WO-1:0] OutData3;

integer input_file;
integer expected_file;
integer output_file;
integer scan_count;
integer set_idx;
integer col_idx;
integer row_idx;
integer timeout_count;
integer error_count;
integer cycle_count;
integer first_start_cycle;
integer last_finish_cycle;

integer in1_i;
integer in2_i;
integer in3_i;
integer exp1_i;
integer exp2_i;
integer exp3_i;

reg signed [WO-1:0] expected1;
reg signed [WO-1:0] expected2;
reg signed [WO-1:0] expected3;

FinalProject #(
    .WI(WI),
    .WO(WO),
    .FRAC_W(FRAC_W),
    .ACC_W(ACC_W),
    .CORDIC_STAGES(CORDIC_STAGES),
    .ITER_MAX(ITER_MAX)
) dut (
    .Clk(Clk),
    .Reset(Reset),
    .InValid(InValid),
    .InData1(InData1),
    .InData2(InData2),
    .InData3(InData3),
    .OutValid(OutValid),
    .OutData1(OutData1),
    .OutData2(OutData2),
    .OutData3(OutData3)
);

always #5 Clk = ~Clk;

always @(posedge Clk) begin
    if (Reset) begin
        cycle_count <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
    end
end

task send_col_from_file;
    begin
        scan_count = $fscanf(input_file, "%d %d %d\n", in1_i, in2_i, in3_i);
        if (scan_count != 3) begin
            $display("Failed to read input column at set %0d col %0d", set_idx + 1, col_idx + 1);
            error_count = error_count + 1;
        end

        @(negedge Clk);
        InData1 = in1_i[WI-1:0];
        InData2 = in2_i[WI-1:0];
        InData3 = in3_i[WI-1:0];
        InValid = 1'b1;
    end
endtask

initial begin
    Clk = 1'b0;
    Reset = 1'b1;
    InValid = 1'b0;
    InData1 = 0;
    InData2 = 0;
    InData3 = 0;
    error_count = 0;
    cycle_count = 0;
    first_start_cycle = 0;
    last_finish_cycle = 0;

    input_file = $fopen("../matlab/all11_input_q12.txt", "r");
    expected_file = $fopen("../matlab/all11_expected_q12.txt", "r");
    output_file = $fopen("../matlab/rtl_output_all11_q12.txt", "w");

    if (input_file == 0 || expected_file == 0 || output_file == 0) begin
        $display("Failed to open all11 input, expected, or output file.");
        $finish;
    end

    repeat (5) @(negedge Clk);
    Reset = 1'b0;

    for (set_idx = 0; set_idx < SETS; set_idx = set_idx + 1) begin
        for (col_idx = 0; col_idx < 3; col_idx = col_idx + 1) begin
            send_col_from_file();
            if (set_idx == 0 && col_idx == 0) begin
                first_start_cycle = cycle_count;
            end
        end

        @(negedge Clk);
        InValid = 1'b0;
        InData1 = 0;
        InData2 = 0;
        InData3 = 0;

        row_idx = 0;
        timeout_count = 0;
        while (row_idx < 4 && timeout_count < 2000) begin
            @(negedge Clk);
            timeout_count = timeout_count + 1;

            if (OutValid) begin
                scan_count = $fscanf(expected_file, "%d %d %d\n", exp1_i, exp2_i, exp3_i);
                expected1 = exp1_i[WO-1:0];
                expected2 = exp2_i[WO-1:0];
                expected3 = exp3_i[WO-1:0];

                $fdisplay(output_file, "%0d %0d %0d", OutData1, OutData2, OutData3);

                if (scan_count != 3) begin
                    $display("Failed to read expected output at set %0d row %0d", set_idx + 1, row_idx);
                    error_count = error_count + 1;
                end else if (OutData1 !== expected1 || OutData2 !== expected2 || OutData3 !== expected3) begin
                    $display("Mismatch set %0d row %0d: got %0d %0d %0d expected %0d %0d %0d",
                             set_idx + 1, row_idx, OutData1, OutData2, OutData3,
                             expected1, expected2, expected3);
                    error_count = error_count + 1;
                end

                row_idx = row_idx + 1;
                last_finish_cycle = cycle_count;
            end
        end

        if (row_idx != 4) begin
            $display("Timeout waiting for set %0d outputs", set_idx + 1);
            error_count = error_count + 1;
        end
    end

    $fclose(input_file);
    $fclose(expected_file);
    $fclose(output_file);

    $display("Total cycles from first input column to last output row = %0d", last_finish_cycle - first_start_cycle);

    if (error_count == 0) begin
        $display("PASS: all 11 RTL outputs match bit-true expected data.");
    end else begin
        $display("FAIL: %0d mismatches or file/timeout errors.", error_count);
    end

    repeat (5) @(negedge Clk);
    $finish;
end

endmodule
