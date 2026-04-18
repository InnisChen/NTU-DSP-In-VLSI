`timescale 1ns/1ps

// `define Path  "../00_TESTBED/src/"              // server (sim runs from project root)
`define Path  "../../../../../../00_TESTBED/src/"  // Vivado xsim
// ============================================================
// MODE SELECT (uncomment exactly one):
//   USE_ITERATIVE = Step 6 iterative      (4 inputs: m=0,3,6,9)
//   USE_UNFOLDED  = Step 7 S/2-unfolded   (10 inputs, theta only)
//   USE_MAG       = Step 9 magnitude+theta (10 inputs, both outputs)
// ============================================================
//`define USE_ITERATIVE
//`define USE_UNFOLDED
 `define USE_MAG

module TESTBED;

parameter W          = 11;
parameter TW         = 11;
parameter S          = 10;
parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

// DUT ports
reg                   clk, rst_n;
reg                   in_valid;
reg  signed [W-1:0]  inX, inY;
wire                  out_valid;
wire signed [TW-1:0] outTheta;
`ifdef USE_MAG
wire signed [W-1:0]  outMag;
`endif

// -----------------------------------------------------------------------
// DUT instantiation
// -----------------------------------------------------------------------
`ifdef USE_MAG
CORDIC_mag      #(.W(W), .TW(TW), .S(S)) dut (
    .clk(clk),    .rst_n(rst_n),
    .inX(inX),    .inY(inY),    .in_valid(in_valid),
    .outTheta(outTheta), .outMag(outMag), .out_valid(out_valid)
);
`elsif USE_UNFOLDED
CORDIC_unfolded #(.W(W), .TW(TW), .S(S)) dut (
    .clk(clk),    .rst_n(rst_n),
    .inX(inX),    .inY(inY),    .in_valid(in_valid),
    .outTheta(outTheta),         .out_valid(out_valid)
);
`elsif USE_ITERATIVE
CORDIC          #(.W(W), .TW(TW), .S(S)) dut (
    .clk(clk),    .rst_n(rst_n),
    .inX(inX),    .inY(inY),    .in_valid(in_valid),
    .outTheta(outTheta),         .out_valid(out_valid)
);
`endif

// Clock
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// -----------------------------------------------------------------------
// Test vectors (hardcoded from MATLAB step3: w=9, S=10, aw=8)
// inX_data, inY_data : 1S+1I+9F  (scale 2^9 = 512)
// theta_ref_data     : 1S+2I+8F  (scale 2^8 = 256)
// -----------------------------------------------------------------------
integer inX_data      [0:9];
integer inY_data      [0:9];
integer theta_ref_data[0:9];

// -----------------------------------------------------------------------
// Simulation variables
// -----------------------------------------------------------------------
real    SCALE_XY, SCALE_TH, PI;
real    alpha_m  [0:9];
integer m_val    [0:9];
integer num_tests, i;
real    theta_out_real, theta_ref_real, err_rad;
integer sim_fd;
`ifdef USE_MAG
real    mag_out_real, mag_ref_real, err_mag_pct;
`endif

initial begin
    SCALE_XY = 512.0;   // 2^9
    SCALE_TH = 256.0;   // 2^8
    PI       = 3.14159265358979;

    // --- Hardcoded test vectors (w=9, S=10, aw=8) ---
    inX_data[0] =  486; inY_data[0] =  158; theta_ref_data[0] =   80;
    inX_data[1] =  300; inY_data[1] =  414; theta_ref_data[1] =  242;
    inX_data[2] =    0; inY_data[2] =  512; theta_ref_data[2] =  402;
    inX_data[3] = -301; inY_data[3] =  414; theta_ref_data[3] =  562;
    inX_data[4] = -487; inY_data[4] =  158; theta_ref_data[4] =  724;
    inX_data[5] = -487; inY_data[5] = -159; theta_ref_data[5] = -724;
    inX_data[6] = -301; inY_data[6] = -415; theta_ref_data[6] = -562;
    inX_data[7] =   -1; inY_data[7] = -512; theta_ref_data[7] = -402;
    inX_data[8] =  300; inY_data[8] = -415; theta_ref_data[8] = -242;
    inX_data[9] =  486; inY_data[9] = -159; theta_ref_data[9] =  -80;

    // Pre-compute alpha for display
    for (i = 0; i < 10; i = i+1)
        alpha_m[i] = (4.0*i + 2.0) / 20.0 * PI;

    // --- Configure num_tests per mode ---
`ifdef USE_MAG
    num_tests = 10;
    for (i = 0; i < 10; i = i+1) m_val[i] = i;
`elsif USE_UNFOLDED
    num_tests = 10;
    for (i = 0; i < 10; i = i+1) m_val[i] = i;
`elsif USE_ITERATIVE
    num_tests = 4;
    m_val[0] = 0; m_val[1] = 3; m_val[2] = 6; m_val[3] = 9;
`endif

    // Reset
    rst_n = 0; inX = 0; inY = 0; in_valid = 0;
    @(posedge clk); @(negedge clk);
    @(posedge clk); @(negedge clk);
    rst_n = 1;
    @(posedge clk); @(negedge clk);

`ifdef USE_MAG
    sim_fd = $fopen({`Path, "step9_sim_results.dat"}, "w");
    if (sim_fd == 0) begin
        $display("[ERROR] Cannot open step9_sim_results.dat for writing.");
        $finish;
    end
    $fwrite(sim_fd, "# m  outMag_int  outTheta_int  inX_int  inY_int\n");
    $display("=== Step 9: Magnitude CORDIC (S=%0d, A_N=2^-1+2^-3-2^-6-2^-9) ===", S);
    $display("  m | alpha (deg) | mag_out  | mag_ref  | err(%%)  | theta_out (deg) | theta_ref (deg)");
    $display("----|-------------|----------|----------|---------|-----------------|----------------");
`elsif USE_UNFOLDED
    sim_fd = $fopen({`Path, "step7_sim_results.dat"}, "w");
    if (sim_fd == 0) begin
        $display("[ERROR] Cannot open step7_sim_results.dat for writing.");
        $finish;
    end
    $fwrite(sim_fd, "# m  outTheta_int  inX_int  inY_int\n");
    $display("=== Step 7: S/2-Unfolded CORDIC (S=%0d, latency=2 cycles) ===", S);
    $display("  m | alpha (deg) | theta_out (deg) | theta_ref (deg) | error (deg)");
    $display("----|-------------|-----------------|-----------------|------------");
`elsif USE_ITERATIVE
    sim_fd = $fopen({`Path, "step6_sim_results.dat"}, "w");
    if (sim_fd == 0) begin
        $display("[ERROR] Cannot open step6_sim_results.dat for writing.");
        $finish;
    end
    $fwrite(sim_fd, "# m  outTheta_int  inX_int  inY_int\n");
    $display("=== Step 6: Iterative CORDIC (S=%0d, latency=%0d cycles) ===", S, S+1);
    $display("  m | alpha (deg) | theta_out (deg) | theta_ref (deg) | error (deg)");
    $display("----|-------------|-----------------|-----------------|------------");
`endif

    for (i = 0; i < num_tests; i = i+1) begin
        inX      = inX_data[m_val[i]][W-1:0];
        inY      = inY_data[m_val[i]][W-1:0];
        in_valid = 1;
        @(posedge clk);
        @(negedge clk);
        in_valid = 0;

        // @(posedge out_valid);
        @(posedge clk);
        @(negedge clk);

        theta_out_real = $itor($signed(outTheta)) / SCALE_TH;
        theta_ref_real = $itor(theta_ref_data[m_val[i]]) / SCALE_TH;
        err_rad        = theta_out_real - theta_ref_real;
        if (err_rad >  PI) err_rad = err_rad - 2.0*PI;
        if (err_rad < -PI) err_rad = err_rad + 2.0*PI;

`ifdef USE_MAG
        mag_out_real  = $itor($signed(outMag)) / SCALE_XY;
        mag_ref_real  = $sqrt($itor(inX_data[m_val[i]]*inX_data[m_val[i]] +
                               inY_data[m_val[i]]*inY_data[m_val[i]])) / SCALE_XY;
        err_mag_pct   = (mag_out_real - mag_ref_real) / mag_ref_real * 100.0;
        $display("  %1d | %11.4f | %8.5f | %8.5f | %+7.4f | %15.4f | %15.4f",
            m_val[i],
            alpha_m[m_val[i]] * 180.0 / PI,
            mag_out_real, mag_ref_real, err_mag_pct,
            theta_out_real * 180.0 / PI,
            theta_ref_real * 180.0 / PI);
        $fwrite(sim_fd, "%0d %0d %0d %0d %0d\n",
            m_val[i], $signed(outMag), $signed(outTheta),
            inX_data[m_val[i]], inY_data[m_val[i]]);
`else
        $display("  %1d | %11.4f | %15.4f | %15.4f | %11.6f",
            m_val[i],
            alpha_m[m_val[i]]  * 180.0 / PI,
            theta_out_real     * 180.0 / PI,
            theta_ref_real     * 180.0 / PI,
            err_rad            * 180.0 / PI);
        $fwrite(sim_fd, "%0d %0d %0d %0d\n",
            m_val[i], $signed(outTheta),
            inX_data[m_val[i]], inY_data[m_val[i]]);
`endif

    end

    $fclose(sim_fd);
`ifdef USE_MAG
    $display("\nDone. Written step9_sim_results.dat");
    $display("Magnitude threshold = 0.1%%,  Phase threshold = 2^-9 rad");
`elsif USE_UNFOLDED
    $display("\nDone. Written step7_sim_results.dat");
    $display("Threshold = 2^-9 rad = %.6f rad = %.4f deg",
        1.0/512.0, 180.0/(512.0*PI));
`elsif USE_ITERATIVE
    $display("\nDone. Written step6_sim_results.dat");
    $display("Threshold = 2^-9 rad = %.6f rad = %.4f deg",
        1.0/512.0, 180.0/(512.0*PI));
`endif

    @(posedge clk); //確保最後一組輸出有顯示出來
    @(posedge clk);
    $finish;
end

// Timeout watchdog
initial begin
    #(CLK_PERIOD * 400);
    $display("[TIMEOUT] Simulation exceeded 400 cycles.");
    $finish;
end

// Waveform dump
initial begin
`ifdef USE_MAG
    $dumpfile("cordic_step9.vcd");
`elsif USE_UNFOLDED
    $dumpfile("cordic_step7.vcd");
`elsif USE_ITERATIVE
    $dumpfile("cordic_step6.vcd");
`endif
    $dumpvars(0, TESTBED);
end

endmodule
