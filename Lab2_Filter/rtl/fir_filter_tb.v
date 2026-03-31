// =============================================================================
// Testbench: fir_filter_tb
// 從外部 x_input.dat 讀取輸入（$readmemh），輸出寫入 y_output.dat
//
// 輸入格式：16-bit signed [1S+2I+13F]，x_input.dat 每行 4 位 hex
// 輸出格式：21-bit signed [1S+3I+17F]，y_output.dat 每行 signed 整數
//   轉回浮點：y_float = y_out_integer / 2^17
// =============================================================================

`timescale 1ns / 1ps

module fir_filter_tb;

parameter CLK_PERIOD = 14;
parameter N_SAMPLES  = 144;
parameter F_ADD      = 17;

reg clk, rst_n;
always #(CLK_PERIOD/2) clk = ~clk;

// DUT
reg  signed [15:0] FilterIn;
reg                ValidIn;
wire signed [20:0] FilterOut;
wire               ValidOut;

fir_filter dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .FilterIn (FilterIn),
    .ValidIn  (ValidIn),
    .FilterOut(FilterOut),
    .ValidOut (ValidOut)
);

// =============================================================================
// 從 x_input.dat 讀取測試向量
// =============================================================================
reg [15:0] test_input [0:N_SAMPLES-1];

initial begin
    $readmemh("C:/Project/DSP in VLSI/Lab2_Filter/matlab/x_input.dat", test_input);
end

// =============================================================================
// 主要 stimulus
// =============================================================================
integer i;
integer out_count;
integer out_file;
// real    y_float;

initial begin
    $dumpfile("fir_sim.vcd");
    $dumpvars(0, fir_filter_tb);

    clk       = 0;
    rst_n     = 1;
    FilterIn  = 0;
    ValidIn   = 0;
    out_count = 0;

    repeat(5) @(posedge clk);   //globle reset 

    out_file = $fopen("C:/Project/DSP in VLSI/Lab2_Filter/matlab/y_output.dat", "w");

    // Reset 2 cycles
    repeat(2) @(posedge clk);
    #1 rst_n = 0;
    repeat(2) @(negedge clk);
    #1 rst_n = 1;

    @(posedge clk);

    // $display("=== FIR Filter Simulation Start ===");
    // $display("Input : 16-bit signed [1S+2I+13F]");
    // $display("Output: 21-bit signed [1S+3I+17F], float = int / 2^%0d", F_ADD);
    // $display("");

    // 送入 144 個樣本
    for (i = 0; i < N_SAMPLES; i = i + 1) begin
        @(negedge clk);
        FilterIn = test_input[i];
        ValidIn  = 1;
    end

    // 關閉輸入，等 pipeline flush（2 cycle latency）
    @(negedge clk);
    FilterIn = 0;
    ValidIn  = 0;
    repeat(5) @(posedge clk);

    $fclose(out_file);
    // $display("");
    // $display("=== Simulation Done: y_output.dat saved ===");
    $finish;
end

// =============================================================================
// 輸出監控
// =============================================================================
always @(posedge clk) begin
    if (ValidOut) begin
        // y_float = $itor($signed(FilterOut)) / (2.0 ** F_ADD);

        // 寫入輸出檔（signed 整數，MATLAB 讀回後除以 2^17）
        $fdisplay(out_file, "%0d", $signed(FilterOut));

        // // 顯示前 20 筆
        // if (out_count < 20)
        //     $display("[y%3d] int=%10d  float=%9.5f", out_count, $signed(FilterOut), y_float);

        // // 顯示後 20 筆
        // if (out_count >= N_SAMPLES-20)
        //     $display("[y%3d] int=%10d  float=%9.5f", out_count, $signed(FilterOut), y_float);

        out_count = out_count + 1;
    end
end

// Timeout
initial begin
    #100000;
    $display("ERROR: Timeout");
    $finish;
end

endmodule