`timescale 1ns/1ps

// Step 6 Testbench: test alpha_0, alpha_3, alpha_6, alpha_9
// alpha_m = (4m+2)/20 * pi,  m = 0,3,6,9
// X = cos(alpha_m), Y = sin(alpha_m), quantized to 1S+1I+9F (W=11 bits)
// Expected theta = atan2(Y,X) = alpha_m (mapped to [-pi,pi])

module TESTBED;

parameter W  = 11;
parameter TW = 11;
parameter S  = 10;
parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

// DUT ports
reg                    clk, rst_n;
reg  signed [W-1:0]   inX, inY;
reg                    in_valid;
wire signed [TW-1:0]  outTheta;
wire                   out_valid;

// DUT
CORDIC #(.W(W), .TW(TW), .S(S)) dut (
    .clk(clk), .rst_n(rst_n),
    .inX(inX), .inY(inY), .in_valid(in_valid),
    .outTheta(outTheta), .out_valid(out_valid)
);

// Clock
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Scale factors
real SCALE_XY;    // 2^9 = 512
real SCALE_TH;    // 2^8 = 256
real PI;

initial begin
    SCALE_XY = 512.0;
    SCALE_TH = 256.0;
    PI = 3.14159265358979;
end

// Test vector storage
real   alpha [0:3];
real   X_true[0:3], Y_true[0:3], theta_ref[0:3];
integer m_idx[0:3];
integer i;

real theta_out_real, err_rad;

initial begin
    // Test cases: m = 0, 3, 6, 9
    m_idx[0] = 0; m_idx[1] = 3; m_idx[2] = 6; m_idx[3] = 9;

    for (i = 0; i < 4; i = i+1) begin
        alpha[i]     = (4.0*m_idx[i] + 2.0) / 20.0 * PI;
        X_true[i]    = $cos(alpha[i]);
        Y_true[i]    = $sin(alpha[i]);
        theta_ref[i] = alpha[i];
        // Map to [-pi, pi]
        if (theta_ref[i] > PI)  theta_ref[i] = theta_ref[i] - 2.0*PI;
        if (theta_ref[i] < -PI) theta_ref[i] = theta_ref[i] + 2.0*PI;
    end

    // Reset
    rst_n    = 0;
    inX      = 0; inY = 0; in_valid = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    rst_n = 1;
    @(posedge clk); #1;

    $display("=== Step 6: Iterative CORDIC Test (S=%0d) ===", S);
    $display("  m | alpha (deg) | theta_out (deg) | theta_ref (deg) | error (deg)");
    $display("----|-------------|-----------------|-----------------|------------");

    for (i = 0; i < 4; i = i+1) begin
        // Apply quantized input
        inX      = $rtoi($floor(X_true[i] * SCALE_XY));
        inY      = $rtoi($floor(Y_true[i] * SCALE_XY));
        in_valid = 1;
        @(posedge clk); #1;
        in_valid = 0;

        // Wait for out_valid
        @(posedge out_valid); #1;

        theta_out_real = $itor(outTheta) / SCALE_TH;
        err_rad        = theta_out_real - theta_ref[i];
        if (err_rad >  PI) err_rad = err_rad - 2.0*PI;
        if (err_rad < -PI) err_rad = err_rad + 2.0*PI;

        $display("  %1d | %11.4f | %15.4f | %15.4f | %11.6f",
            m_idx[i],
            alpha[i] * 180.0 / PI,
            theta_out_real * 180.0 / PI,
            theta_ref[i] * 180.0 / PI,
            err_rad * 180.0 / PI);

        @(posedge clk); #1;
    end

    $display("\nDone. Threshold = 2^-9 rad = %.6f rad = %.4f deg",
        1.0/512.0, 180.0/(512.0*PI));
    $finish;
end

// Timeout watchdog
initial begin
    #(CLK_PERIOD * 200);
    $display("[TIMEOUT] Simulation exceeded 200 cycles.");
    $finish;
end

// Waveform dump
initial begin
    $dumpfile("cordic_step6.vcd");
    $dumpvars(0, TESTBED);
end

endmodule
