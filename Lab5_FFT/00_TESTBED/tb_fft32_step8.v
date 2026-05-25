`timescale 1ns/1ps
`include "fft32_params.vh"

module tb_fft32_step8;
    localparam DATA_W = `FFT32_DATA_W;
    localparam FRAC_W = `FFT32_FRAC_W;
    localparam CLK_PERIOD = 10;
    localparam ERR_TOL = 0;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_W-1:0] FFTInRe;
    reg signed [DATA_W-1:0] FFTInIm;

    wire sdf_valid_out;
    wire signed [DATA_W-1:0] SDFOutRe;
    wire signed [DATA_W-1:0] SDFOutIm;
    wire br_valid_out;
    wire signed [DATA_W-1:0] BROutRe;
    wire signed [DATA_W-1:0] BROutIm;

    reg signed [DATA_W-1:0] input_re [0:31];
    reg signed [DATA_W-1:0] input_im [0:31];
    reg signed [DATA_W-1:0] golden_sdf_re [0:31];
    reg signed [DATA_W-1:0] golden_sdf_im [0:31];
    reg signed [DATA_W-1:0] golden_br_re [0:31];
    reg signed [DATA_W-1:0] golden_br_im [0:31];

    fft32_top #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .TWIDDLE_W(`FFT32_TWIDDLE_W),
        .WF_STAGE1(`FFT32_WF_STAGE1),
        .WF_STAGE2(`FFT32_WF_STAGE2),
        .WF_STAGE3(`FFT32_WF_STAGE3),
        .WF_STAGE4(`FFT32_WF_STAGE4),
        .WF_STAGE5(`FFT32_WF_STAGE5),
        .WF_TWIDDLE(`FFT32_WF_TWIDDLE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .FFTInRe(FFTInRe),
        .FFTInIm(FFTInIm),
        .sdf_valid_out(sdf_valid_out),
        .SDFOutRe(SDFOutRe),
        .SDFOutIm(SDFOutIm),
        .br_valid_out(br_valid_out),
        .BROutRe(BROutRe),
        .BROutIm(BROutIm)
    );

    `ifdef SDF_SIM
        initial begin
            $sdf_annotate("../02_SYN/Netlist/fft32_top.sdf", dut, , , "MAXIMUM");
        end
    `endif

    always #(CLK_PERIOD/2) clk = ~clk;

    integer i;
    integer sdf_count;
    integer br_count;
    integer err_count;
    integer file_error;
    integer fd_rtl_sdf_re;
    integer fd_rtl_sdf_im;
    integer fd_rtl_br_re;
    integer fd_rtl_br_im;

    initial begin
        $readmemh({`FFT32_DAT_DIR, "/fftinput32_re.dat"}, input_re);
        $readmemh({`FFT32_DAT_DIR, "/fftinput32_im.dat"}, input_im);
        $readmemh({`FFT32_DAT_DIR, "/golden_sdf32_re.dat"}, golden_sdf_re);
        $readmemh({`FFT32_DAT_DIR, "/golden_sdf32_im.dat"}, golden_sdf_im);
        $readmemh({`FFT32_DAT_DIR, "/golden_br32_re.dat"}, golden_br_re);
        $readmemh({`FFT32_DAT_DIR, "/golden_br32_im.dat"}, golden_br_im);
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        FFTInRe = {DATA_W{1'b0}};
        FFTInIm = {DATA_W{1'b0}};
        sdf_count = 0;
        br_count = 0;
        err_count = 0;
        file_error = 0;
        fd_rtl_sdf_re = $fopen({`FFT32_DAT_DIR, "/rtl_sdf32_re.dat"}, "w");
        fd_rtl_sdf_im = $fopen({`FFT32_DAT_DIR, "/rtl_sdf32_im.dat"}, "w");
        fd_rtl_br_re = $fopen({`FFT32_DAT_DIR, "/rtl_br32_re.dat"}, "w");
        fd_rtl_br_im = $fopen({`FFT32_DAT_DIR, "/rtl_br32_im.dat"}, "w");
        if (fd_rtl_sdf_re == 0 || fd_rtl_sdf_im == 0 || fd_rtl_br_re == 0 || fd_rtl_br_im == 0) begin
            $display("[ERROR] Cannot open RTL output dat files under %s.", `FFT32_DAT_DIR);
            file_error = 1;
        end

        $dumpfile("tb_fft32_step8.vcd");
        $dumpvars(0, tb_fft32_step8);

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 32; i = i + 1) begin
            @(negedge clk);
            valid_in = 1'b1;
            FFTInRe = input_re[i];
            FFTInIm = input_im[i];
        end

        @(negedge clk);
        valid_in = 1'b0;
        FFTInRe = {DATA_W{1'b0}};
        FFTInIm = {DATA_W{1'b0}};

        repeat (100) @(negedge clk);
        if (err_count == 0 && file_error == 0 && sdf_count == 32 && br_count == 32) begin
            $display("============================================================");
            $display("[PASS] tb_fft32_step8");
            $display("       SDFOut checked: %0d samples", sdf_count);
            $display("       BROut checked : %0d samples", br_count);
            $display("       Mismatches    : %0d", err_count);
            $display("============================================================");
        end else begin
            $display("================================================------------");
            $display("[FAIL] tb_fft32_step8");
            $display("       SDFOut checked: %0d / 32 samples", sdf_count);
            $display("       BROut checked : %0d / 32 samples", br_count);
            $display("       Mismatches    : %0d", err_count);
            $display("       File errors   : %0d", file_error);
            $display("============================================================");
        end
        $fclose(fd_rtl_sdf_re);
        $fclose(fd_rtl_sdf_im);
        $fclose(fd_rtl_br_re);
        $fclose(fd_rtl_br_im);
        $finish;
    end

    always @(posedge clk) begin
        if (sdf_valid_out && sdf_count < 32) begin
            $fdisplay(fd_rtl_sdf_re, "%0h", SDFOutRe);
            $fdisplay(fd_rtl_sdf_im, "%0h", SDFOutIm);
            if (abs_diff(SDFOutRe, golden_sdf_re[sdf_count]) > ERR_TOL ||
                abs_diff(SDFOutIm, golden_sdf_im[sdf_count]) > ERR_TOL) begin
                $display("[ERROR] SDF mismatch %0d: got (%0d,%0d), exp (%0d,%0d)",
                         sdf_count, SDFOutRe, SDFOutIm, golden_sdf_re[sdf_count], golden_sdf_im[sdf_count]);
                err_count = err_count + 1;
            end
            sdf_count = sdf_count + 1;
        end

        if (br_valid_out && br_count < 32) begin
            $fdisplay(fd_rtl_br_re, "%0h", BROutRe);
            $fdisplay(fd_rtl_br_im, "%0h", BROutIm);
            if (abs_diff(BROutRe, golden_br_re[br_count]) > ERR_TOL ||
                abs_diff(BROutIm, golden_br_im[br_count]) > ERR_TOL) begin
                $display("[ERROR] BR mismatch %0d: got (%0d,%0d), exp (%0d,%0d)",
                         br_count, BROutRe, BROutIm, golden_br_re[br_count], golden_br_im[br_count]);
                err_count = err_count + 1;
            end
            br_count = br_count + 1;
        end
    end

    function integer abs_diff;
        input signed [DATA_W-1:0] a;
        input signed [DATA_W-1:0] b;
        reg signed [DATA_W:0] d;
        begin
            d = a - b;
            abs_diff = (d < 0) ? -d : d;
        end
    endfunction
endmodule
