// =============================================================================
// Testbench: fir_filter_parallel_tb
// 從外部 x_input.dat 讀取輸入，每 clock 送 2 個樣本
// 輸出寫入 y_parallel_output.dat（格式與 y_output.dat 相同，可直接比對）
//
// 輸入格式：16-bit signed [1S+2I+13F]，x_input.dat 每行 4 位 hex
// 輸出格式：21-bit signed [1S+3I+17F]，每行 signed 整數
//   轉回浮點：y_float = y_integer / 2^17
//
// 驗證：y_parallel_output.dat 應與 y_output.dat 數值完全一致
// =============================================================================

`timescale 1ns / 1ps

module fir_filter_parallel_tb;

parameter CLK_PERIOD  = 10;
parameter N_SAMPLES   = 144;
parameter N_CLK_IN    = N_SAMPLES / 2;  // 72 clocks to send all inputs
parameter F_ADD       = 17;

reg clk, rst_n;
always #(CLK_PERIOD/2) clk = ~clk;

// DUT
reg  signed [15:0] FilterIn0;
reg  signed [15:0] FilterIn1;
reg                ValidIn;
wire signed [20:0] FilterOut0;
wire signed [20:0] FilterOut1;
wire               ValidOut;

fir_filter_parallel dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .FilterIn0 (FilterIn0),
    .FilterIn1 (FilterIn1),
    .ValidIn   (ValidIn),
    .FilterOut0(FilterOut0),
    .FilterOut1(FilterOut1),
    .ValidOut  (ValidOut)
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
real    y_float0, y_float1;

initial begin
    $dumpfile("fir_parallel_sim.vcd");
    $dumpvars(0, fir_filter_parallel_tb);

    clk       = 0;
    rst_n     = 0;
    FilterIn0 = 0;
    FilterIn1 = 0;
    ValidIn   = 0;
    out_count = 0;

    out_file = $fopen("y_parallel_output.dat", "w");

    // Reset 4 cycles
    repeat(4) @(posedge clk);
    #1 rst_n = 1;

    $display("=== FIR Parallel Filter Simulation Start ===");
    $display("Input : 16-bit signed [1S+2I+13F], 2 samples/clock");
    $display("Output: 21-bit signed [1S+3I+17F], 2 outputs/clock, float = int / 2^%0d", F_ADD);
    $display("");

    // 每個 clock 送 2 個樣本：test_input[2i] 和 test_input[2i+1]
    for (i = 0; i < N_CLK_IN; i = i + 1) begin
        @(posedge clk);
        #1;
        FilterIn0 = test_input[2*i];      // x[2n]   even (older)
        FilterIn1 = test_input[2*i + 1];  // x[2n+1] odd  (newer)
        ValidIn   = 1;
    end

    // 關閉輸入，等 pipeline flush（2 cycle latency）
    @(posedge clk); #1;
    FilterIn0 = 0;
    FilterIn1 = 0;
    ValidIn   = 0;
    repeat(5) @(posedge clk);

    $fclose(out_file);
    $display("");
    $display("=== Simulation Done: y_parallel_output.dat saved ===");
    $finish;
end

// =============================================================================
// 輸出監控：每 clock 收 2 個輸出，寫入順序 y[2n] 先、y[2n+1] 後
// =============================================================================
always @(posedge clk) begin
    if (ValidOut) begin
        y_float0 = $itor($signed(FilterOut0)) / (2.0 ** F_ADD);
        y_float1 = $itor($signed(FilterOut1)) / (2.0 ** F_ADD);

        // 寫入輸出檔（y[2n] 先，y[2n+1] 後，與 y_output.dat 順序一致）
        $fdisplay(out_file, "%d", $signed(FilterOut0));
        $fdisplay(out_file, "%d", $signed(FilterOut1));

        // 顯示前 10 筆（即前 20 個 output）
        if (out_count < 10) begin
            $display("[y%3d] int=%10d  float=%9.5f", 2*out_count,   $signed(FilterOut0), y_float0);
            $display("[y%3d] int=%10d  float=%9.5f", 2*out_count+1, $signed(FilterOut1), y_float1);
        end

        // 顯示後 10 筆（即後 20 個 output）
        if (out_count >= N_CLK_IN-10) begin
            $display("[y%3d] int=%10d  float=%9.5f", 2*out_count,   $signed(FilterOut0), y_float0);
            $display("[y%3d] int=%10d  float=%9.5f", 2*out_count+1, $signed(FilterOut1), y_float1);
        end

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
