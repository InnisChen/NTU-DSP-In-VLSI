`timescale 1ns/1ps

module sdf_fft32 #(
    parameter DATA_W = 24,
    parameter FRAC_W = 16,
    parameter WF_STAGE1 = 9,
    parameter WF_STAGE2 = 9,
    parameter WF_STAGE3 = 9,
    parameter WF_STAGE4 = 9,
    parameter WF_STAGE5 = 9,
    parameter WF_TWIDDLE = 9
) (
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [DATA_W-1:0] FFTInRe,
    input  wire signed [DATA_W-1:0] FFTInIm,

    output wire sdf_valid_out,
    output wire signed [DATA_W-1:0] SDFOutRe,
    output wire signed [DATA_W-1:0] SDFOutIm
);
    wire stage1_valid;
    wire stage2_valid;
    wire stage3_valid;
    wire stage4_valid;
    wire stage5_valid;

    wire signed [DATA_W-1:0] stage1_re;
    wire signed [DATA_W-1:0] stage1_im;
    wire signed [DATA_W-1:0] stage2_re;
    wire signed [DATA_W-1:0] stage2_im;
    wire signed [DATA_W-1:0] stage3_re;
    wire signed [DATA_W-1:0] stage3_im;
    wire signed [DATA_W-1:0] stage4_re;
    wire signed [DATA_W-1:0] stage4_im;
    wire signed [DATA_W-1:0] stage5_re;
    wire signed [DATA_W-1:0] stage5_im;

    sdf_stage #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE1),
        .WF_TWIDDLE(WF_TWIDDLE),
        .DEPTH(16),
        .PERIOD(32),
        .CTR_BIT(4),
        .LOW_MASK(4'hf),
        .PHASE_SHIFT(0),
        .TWIDDLE_MODE(0)
    ) u_stage1 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .stage_in_re(FFTInRe),
        .stage_in_im(FFTInIm),
        .valid_out(stage1_valid),
        .stage_out_re(stage1_re),
        .stage_out_im(stage1_im)
    );

    sdf_stage #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE2),
        .WF_TWIDDLE(WF_TWIDDLE),
        .DEPTH(8),
        .PERIOD(16),
        .CTR_BIT(3),
        .LOW_MASK(4'h7),
        .PHASE_SHIFT(1),
        .TWIDDLE_MODE(1)
    ) u_stage2 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(stage1_valid),
        .stage_in_re(stage1_re),
        .stage_in_im(stage1_im),
        .valid_out(stage2_valid),
        .stage_out_re(stage2_re),
        .stage_out_im(stage2_im)
    );

    sdf_stage #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE3),
        .WF_TWIDDLE(WF_TWIDDLE),
        .DEPTH(4),
        .PERIOD(8),
        .CTR_BIT(2),
        .LOW_MASK(4'h3),
        .PHASE_SHIFT(2),
        .TWIDDLE_MODE(2)
    ) u_stage3 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(stage2_valid),
        .stage_in_re(stage2_re),
        .stage_in_im(stage2_im),
        .valid_out(stage3_valid),
        .stage_out_re(stage3_re),
        .stage_out_im(stage3_im)
    );

    sdf_stage #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE4),
        .WF_TWIDDLE(WF_TWIDDLE),
        .DEPTH(2),
        .PERIOD(4),
        .CTR_BIT(1),
        .LOW_MASK(4'h1),
        .PHASE_SHIFT(3),
        .TWIDDLE_MODE(3)
    ) u_stage4 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(stage3_valid),
        .stage_in_re(stage3_re),
        .stage_in_im(stage3_im),
        .valid_out(stage4_valid),
        .stage_out_re(stage4_re),
        .stage_out_im(stage4_im)
    );

    sdf_stage #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE5),
        .WF_TWIDDLE(WF_TWIDDLE),
        .DEPTH(1),
        .PERIOD(2),
        .CTR_BIT(0),
        .LOW_MASK(4'h0),
        .PHASE_SHIFT(0),
        .TWIDDLE_MODE(4)
    ) u_stage5 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(stage4_valid),
        .stage_in_re(stage4_re),
        .stage_in_im(stage4_im),
        .valid_out(stage5_valid),
        .stage_out_re(stage5_re),
        .stage_out_im(stage5_im)
    );

    assign sdf_valid_out = stage5_valid;
    assign SDFOutRe = stage5_re;
    assign SDFOutIm = stage5_im;
endmodule

module sdf_stage #(
    parameter DATA_W = 24,
    parameter FRAC_W = 16,
    parameter WF_STAGE = 9,
    parameter WF_TWIDDLE = 9,
    parameter DEPTH = 16,
    parameter PERIOD = 32,
    parameter CTR_BIT = 4,
    parameter LOW_MASK = 4'hf,
    parameter PHASE_SHIFT = 0,
    parameter TWIDDLE_MODE = 0
) (
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [DATA_W-1:0] stage_in_re,
    input  wire signed [DATA_W-1:0] stage_in_im,
    output wire valid_out,
    output wire signed [DATA_W-1:0] stage_out_re,
    output wire signed [DATA_W-1:0] stage_out_im
);
    reg signed [DATA_W-1:0] delay_re [0:DEPTH-1];
    reg signed [DATA_W-1:0] delay_im [0:DEPTH-1];
    reg [DEPTH-1:0] valid_pipe;
    reg [4:0] cnt;
    reg valid_out_r;
    reg signed [DATA_W-1:0] stage_out_re_r;
    reg signed [DATA_W-1:0] stage_out_im_r;

    wire active = valid_in || (|valid_pipe);
    wire ctr = cnt[CTR_BIT];
    wire [3:0] phase_base = cnt[3:0] & LOW_MASK;
    wire [3:0] tw_phase = phase_base << PHASE_SHIFT;

    wire signed [DATA_W-1:0] delay_out_re = delay_re[DEPTH-1];
    wire signed [DATA_W-1:0] delay_out_im = delay_im[DEPTH-1];

    wire signed [DATA_W-1:0] pe_upper_re;
    wire signed [DATA_W-1:0] pe_upper_im;
    wire signed [DATA_W-1:0] pe_lower_re;
    wire signed [DATA_W-1:0] pe_lower_im;

    wire signed [DATA_W-1:0] tw_result_re;
    wire signed [DATA_W-1:0] tw_result_im;

    wire signed [DATA_W-1:0] delay_in_re = ctr ? tw_result_re : pe_upper_re;
    wire signed [DATA_W-1:0] delay_in_im = ctr ? tw_result_im : pe_upper_im;

    assign valid_out = valid_out_r;
    assign stage_out_re = stage_out_re_r;
    assign stage_out_im = stage_out_im_r;

    pe #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE(WF_STAGE)
    ) u_pe (
        .ctr_i(ctr),
        .upper_re(delay_out_re),
        .upper_im(delay_out_im),
        .lower_re(stage_in_re),
        .lower_im(stage_in_im),
        .upper_out_re(pe_upper_re),
        .upper_out_im(pe_upper_im),
        .lower_out_re(pe_lower_re),
        .lower_out_im(pe_lower_im)
    );

    generate
        if (TWIDDLE_MODE == 0) begin : gen_twiddle_full
            wire signed [DATA_W-1:0] tw_re_full;
            wire signed [DATA_W-1:0] tw_im_full;
            wire signed [DATA_W-1:0] tw_re_q = trunc_to_wf(tw_re_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_im_q = trunc_to_wf(tw_im_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_prod_re;
            wire signed [DATA_W-1:0] tw_prod_im;

            twiddle_rom32 #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W)
            ) u_twiddle_rom32 (
                .phase(tw_phase),
                .tw_re(tw_re_full),
                .tw_im(tw_im_full)
            );

            complex_mult #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W),
                .OUT_WF(WF_STAGE)
            ) u_complex_mult (
                .a_re(pe_lower_re),
                .a_im(pe_lower_im),
                .b_re(tw_re_q),
                .b_im(tw_im_q),
                .y_re(tw_prod_re),
                .y_im(tw_prod_im)
            );

            assign tw_result_re = (tw_phase == 4'd0) ? pe_lower_re : tw_prod_re;
            assign tw_result_im = (tw_phase == 4'd0) ? pe_lower_im : tw_prod_im;
        end else if (TWIDDLE_MODE == 1) begin : gen_twiddle_stage2
            wire signed [DATA_W-1:0] tw_re_full;
            wire signed [DATA_W-1:0] tw_im_full;
            wire signed [DATA_W-1:0] tw_re_q = trunc_to_wf(tw_re_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_im_q = trunc_to_wf(tw_im_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_prod_re;
            wire signed [DATA_W-1:0] tw_prod_im;

            twiddle_rom32_stage2 #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W)
            ) u_twiddle_rom32_stage2 (
                .phase_idx(phase_base[2:0]),
                .tw_re(tw_re_full),
                .tw_im(tw_im_full)
            );

            complex_mult #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W),
                .OUT_WF(WF_STAGE)
            ) u_complex_mult (
                .a_re(pe_lower_re),
                .a_im(pe_lower_im),
                .b_re(tw_re_q),
                .b_im(tw_im_q),
                .y_re(tw_prod_re),
                .y_im(tw_prod_im)
            );

            assign tw_result_re = (phase_base[2:0] == 3'd0) ? pe_lower_re : tw_prod_re;
            assign tw_result_im = (phase_base[2:0] == 3'd0) ? pe_lower_im : tw_prod_im;
        end else if (TWIDDLE_MODE == 2) begin : gen_twiddle_stage3
            wire signed [DATA_W-1:0] tw_re_full;
            wire signed [DATA_W-1:0] tw_im_full;
            wire signed [DATA_W-1:0] tw_re_q = trunc_to_wf(tw_re_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_im_q = trunc_to_wf(tw_im_full, WF_TWIDDLE);
            wire signed [DATA_W-1:0] tw_prod_re;
            wire signed [DATA_W-1:0] tw_prod_im;

            twiddle_rom32_stage3 #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W)
            ) u_twiddle_rom32_stage3 (
                .phase_idx(phase_base[1:0]),
                .tw_re(tw_re_full),
                .tw_im(tw_im_full)
            );

            complex_mult #(
                .DATA_W(DATA_W),
                .FRAC_W(FRAC_W),
                .OUT_WF(WF_STAGE)
            ) u_complex_mult (
                .a_re(pe_lower_re),
                .a_im(pe_lower_im),
                .b_re(tw_re_q),
                .b_im(tw_im_q),
                .y_re(tw_prod_re),
                .y_im(tw_prod_im)
            );

            assign tw_result_re = (phase_base[1:0] == 2'd0) ? pe_lower_re : tw_prod_re;
            assign tw_result_im = (phase_base[1:0] == 2'd0) ? pe_lower_im : tw_prod_im;
        end else if (TWIDDLE_MODE == 3) begin : gen_twiddle_stage4
            wire phase8 = phase_base[0];

            assign tw_result_re = phase8 ? pe_lower_im : pe_lower_re;
            assign tw_result_im = phase8 ? -pe_lower_re : pe_lower_im;
        end else begin : gen_twiddle_stage5
            assign tw_result_re = pe_lower_re;
            assign tw_result_im = pe_lower_im;
        end
    endgenerate

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 5'd0;
            valid_pipe <= {DEPTH{1'b0}};
            valid_out_r <= 1'b0;
            stage_out_re_r <= {DATA_W{1'b0}};
            stage_out_im_r <= {DATA_W{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1) begin
                delay_re[i] <= {DATA_W{1'b0}};
                delay_im[i] <= {DATA_W{1'b0}};
            end
        end else if (active) begin
            valid_out_r <= valid_pipe[DEPTH-1];
            valid_pipe[0] <= valid_in;
            for (i = 1; i < DEPTH; i = i + 1) begin
                valid_pipe[i] <= valid_pipe[i-1];
            end

            stage_out_re_r <= ctr ? pe_upper_re : pe_lower_re;
            stage_out_im_r <= ctr ? pe_upper_im : pe_lower_im;

            delay_re[0] <= delay_in_re;
            delay_im[0] <= delay_in_im;
            for (i = 1; i < DEPTH; i = i + 1) begin
                delay_re[i] <= delay_re[i-1];
                delay_im[i] <= delay_im[i-1];
            end

            if (cnt == PERIOD - 1) begin
                cnt <= 5'd0;
            end else begin
                cnt <= cnt + 5'd1;
            end
        end else begin
            cnt <= 5'd0;
            valid_out_r <= 1'b0;
            valid_pipe <= {DEPTH{1'b0}};
        end
    end

    function automatic signed [DATA_W-1:0] trunc_to_wf;
        input signed [DATA_W-1:0] value;
        input integer wf;
        integer drop;
        reg signed [DATA_W-1:0] mag;
        begin
            drop = FRAC_W - wf;
            if (drop <= 0) begin
                trunc_to_wf = value;
            end else if (value < 0) begin
                mag = -value;
                trunc_to_wf = -((mag >>> drop) <<< drop);
            end else begin
                trunc_to_wf = (value >>> drop) <<< drop;
            end
        end
    endfunction
endmodule
