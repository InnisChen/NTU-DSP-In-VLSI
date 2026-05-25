`timescale 1ns/1ps

module tb_FinalProject;

localparam WI = 17;
localparam WO = 17;
localparam FRAC_W = 12;
localparam ACC_W = 27;
localparam CORDIC_STAGES = 10;
localparam ITER_MAX = 7;

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

integer out_count;
integer cycle_count;
integer start_cycle;
integer finish_cycle;
integer error_count;
integer out_file;

reg signed [WO-1:0] expected [0:3][0:2];
reg signed [WO-1:0] captured [0:3][0:2];

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

task send_col;
    input signed [WI-1:0] d1;
    input signed [WI-1:0] d2;
    input signed [WI-1:0] d3;
    begin
        @(negedge Clk);
        InData1 = d1;
        InData2 = d2;
        InData3 = d3;
        InValid = 1'b1;
    end
endtask

integer r;
integer c;

initial begin
    Clk = 1'b0;
    Reset = 1'b1;
    InValid = 1'b0;
    InData1 = 0;
    InData2 = 0;
    InData3 = 0;
    out_count = 0;
    cycle_count = 0;
    start_cycle = 0;
    finish_cycle = 0;
    error_count = 0;

    expected[0][0] = 17'sd29687;
    expected[0][1] = 17'sd5343;
    expected[0][2] = 17'sd10;
    expected[1][0] = 17'sd394;
    expected[1][1] = 17'sd2349;
    expected[1][2] = 17'sd3339;
    expected[2][0] = -17'sd848;
    expected[2][1] = 17'sd3331;
    expected[2][2] = -17'sd2250;
    expected[3][0] = -17'sd4004;
    expected[3][1] = -17'sd475;
    expected[3][2] = 17'sd797;

    for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 3; c = c + 1) begin
            captured[r][c] = 0;
        end
    end

    $dumpfile("FinalProject_beh.vcd");
    $dumpvars(0, tb_FinalProject);

    repeat (5) @(negedge Clk);
    Reset = 1'b0;

    send_col(17'sd1991, 17'sd1891, -17'sd3111);
    start_cycle = cycle_count;
    send_col(17'sd1891, 17'sd4725, 17'sd5324);
    send_col(-17'sd3111, 17'sd5324, 17'sd28281);

    @(negedge Clk);
    InValid = 1'b0;
    InData1 = 0;
    InData2 = 0;
    InData3 = 0;

    out_file = $fopen("../matlab/rtl_output_matrix8_q12.txt", "w");

    while (out_count < 4) begin
        @(negedge Clk);
        if (OutValid) begin
            captured[out_count][0] = OutData1;
            captured[out_count][1] = OutData2;
            captured[out_count][2] = OutData3;
            $fdisplay(out_file, "%0d %0d %0d", OutData1, OutData2, OutData3);
            $display("OUT[%0d] = %0d %0d %0d", out_count, OutData1, OutData2, OutData3);
            out_count = out_count + 1;
        end
    end

    finish_cycle = cycle_count;
    $fclose(out_file);

    for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 3; c = c + 1) begin
            if (captured[r][c] !== expected[r][c]) begin
                $display("Mismatch row %0d col %0d: got %0d expected %0d",
                         r, c, captured[r][c], expected[r][c]);
                error_count = error_count + 1;
            end
        end
    end

    $display("M cycles from first input column to last output row = %0d", finish_cycle - start_cycle);

    if (error_count == 0) begin
        $display("PASS: RTL output matches bit-true expected Matrix(:,:,8).");
    end else begin
        $display("FAIL: %0d mismatches.", error_count);
    end

    repeat (5) @(negedge Clk);
    $finish;
end

endmodule
