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

parameter W          = 14;
parameter TW         = 13;
parameter S          = 12;
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
// inX_data, inY_data : 1S+1I+12F  (scale 2^12 = 4096)
// theta_ref_data     : 1S+2I+10F  (scale 2^10 = 1024)
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

// Golden answer arrays (loaded from MATLAB-exported hex files)
reg [TW-1:0] golden_theta [0:9];
`ifdef USE_MAG
reg [W-1:0]  golden_mag   [0:9];
`endif
integer mismatch_count;
integer golden_fd, scan_ret;

initial begin
    SCALE_XY = 4096.0;  // 2^12
    SCALE_TH = 1024.0;  // 2^10
    PI       = 3.14159265358979;

    // --- Hardcoded test vectors (w=12, S=12, aw=10) ---
    inX_data[0] =  3896; inY_data[0] =  1266; theta_ref_data[0] =   322;
    inX_data[1] =  2408; inY_data[1] =  3314; theta_ref_data[1] =   965;
    inX_data[2] =     0; inY_data[2] =  4096; theta_ref_data[2] =  1608;
    inX_data[3] = -2408; inY_data[3] =  3314; theta_ref_data[3] =  2252;
    inX_data[4] = -3896; inY_data[4] =  1266; theta_ref_data[4] =  2895;
    inX_data[5] = -3896; inY_data[5] = -1266; theta_ref_data[5] = -2895;
    inX_data[6] = -2408; inY_data[6] = -3314; theta_ref_data[6] = -2252;
    inX_data[7] =     0; inY_data[7] = -4096; theta_ref_data[7] = -1608;
    inX_data[8] =  2408; inY_data[8] = -3314; theta_ref_data[8] =  -965;
    inX_data[9] =  3896; inY_data[9] = -1266; theta_ref_data[9] =  -322;

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
        $fwrite(sim_fd, "# outMag_int  outTheta_int\n");
        $display("=== Step 9: Magnitude CORDIC (S=%0d, A_N=2^-1+2^-3-2^-6-2^-9) ===", S);
        $display("  m | alpha (deg) | mag_out  | mag_ref  | err(%%)  | theta_out (deg) | theta_ref (deg)");
        $display("----|-------------|----------|----------|---------|-----------------|----------------");
    `elsif USE_UNFOLDED
        sim_fd = $fopen({`Path, "step7_sim_results.dat"}, "w");
        if (sim_fd == 0) begin
            $display("[ERROR] Cannot open step7_sim_results.dat for writing.");
            $finish;
        end
        $fwrite(sim_fd, "# outTheta_int\n");
        $display("=== Step 7: S/2-Unfolded CORDIC (S=%0d, latency=2 cycles) ===", S);
        $display("  m | alpha (deg) | theta_out (deg) | theta_ref (deg) | error (deg)");
        $display("----|-------------|-----------------|-----------------|------------");
    `elsif USE_ITERATIVE
        sim_fd = $fopen({`Path, "step6_sim_results.dat"}, "w");
        if (sim_fd == 0) begin
            $display("[ERROR] Cannot open step6_sim_results.dat for writing.");
            $finish;
        end
        $fwrite(sim_fd, "# outTheta_int\n");
        $display("=== Step 6: Iterative CORDIC (S=%0d, latency=%0d cycles) ===", S, S+2);
        $display("  m | alpha (deg) | theta_out (deg) | theta_ref (deg) | error (deg)");
        $display("----|-------------|-----------------|-----------------|------------");
    `endif

    // Load golden answers (MATLAB-exported hex, 2's complement)
    mismatch_count = 0;
`ifdef USE_MAG
    golden_fd = $fopen({`Path, "golden_step9_theta.dat"}, "r");
    if (golden_fd != 0) begin
        for (i = 0; i < num_tests; i = i+1) scan_ret = $fscanf(golden_fd, "%h", golden_theta[i]);
        $fclose(golden_fd);
    end else $display("[WARN] golden_step9_theta.dat not found, comparison skipped.");
    golden_fd = $fopen({`Path, "golden_step9_mag.dat"}, "r");
    if (golden_fd != 0) begin
        for (i = 0; i < num_tests; i = i+1) scan_ret = $fscanf(golden_fd, "%h", golden_mag[i]);
        $fclose(golden_fd);
    end else $display("[WARN] golden_step9_mag.dat not found, comparison skipped.");
`elsif USE_UNFOLDED
    golden_fd = $fopen({`Path, "golden_step7.dat"}, "r");
    if (golden_fd != 0) begin
        for (i = 0; i < num_tests; i = i+1) scan_ret = $fscanf(golden_fd, "%h", golden_theta[i]);
        $fclose(golden_fd);
    end else $display("[WARN] golden_step7.dat not found, comparison skipped.");
`elsif USE_ITERATIVE
    golden_fd = $fopen({`Path, "golden_step6.dat"}, "r");
    if (golden_fd != 0) begin
        for (i = 0; i < num_tests; i = i+1) scan_ret = $fscanf(golden_fd, "%h", golden_theta[i]);
        $fclose(golden_fd);
    end else $display("[WARN] golden_step6.dat not found, comparison skipped.");
`endif

    for (i = 0; i < num_tests; i = i+1) begin
        inX      = inX_data[m_val[i]][W-1:0];
        inY      = inY_data[m_val[i]][W-1:0];
        in_valid = 1;
        @(posedge clk);
        @(negedge clk);
        in_valid = 0;

`ifdef USE_ITERATIVE
        repeat(S+2) begin
            @(posedge clk); @(negedge clk);
        end
`else
        @(posedge clk); @(negedge clk);
        @(posedge clk); @(negedge clk);
`endif

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
                $fwrite(sim_fd, "%h %h\n", outMag, outTheta);
        `else
                $display("  %1d | %11.4f | %15.4f | %15.4f | %11.6f",
                    m_val[i],
                    alpha_m[m_val[i]]  * 180.0 / PI,
                    theta_out_real     * 180.0 / PI,
                    theta_ref_real     * 180.0 / PI,
                    err_rad            * 180.0 / PI);
                $fwrite(sim_fd, "%h\n", outTheta);
        `endif

        // Compare against golden
        if (outTheta !== golden_theta[i]) begin
            mismatch_count = mismatch_count + 1;
            $display("  [MISMATCH] i=%0d m=%0d: outTheta=%0d (golden=%0d)",
                i, m_val[i], $signed(outTheta), $signed(golden_theta[i]));
        end
`ifdef USE_MAG
        if (outMag !== golden_mag[i]) begin
            mismatch_count = mismatch_count + 1;
            $display("  [MISMATCH] i=%0d m=%0d: outMag=%0d (golden=%0d)",
                i, m_val[i], $signed(outMag), $signed(golden_mag[i]));
        end
`endif

    end

    if (mismatch_count == 0)
        $display("\n=== PASS: all %0d outputs match golden ===", num_tests);
    else
        $display("\n=== FAIL: %0d mismatch(es) ===", mismatch_count);

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
