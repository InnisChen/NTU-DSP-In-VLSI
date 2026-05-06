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
    output wire signed [DATA_W-1:0] SDFOutIm,
    output wire [4:0] sdf_out_idx_br
);
    reg signed [DATA_W-1:0] in_buf_re [0:31];
    reg signed [DATA_W-1:0] in_buf_im [0:31];
    reg signed [DATA_W-1:0] out_buf_re [0:31];
    reg signed [DATA_W-1:0] out_buf_im [0:31];

    reg signed [DATA_W-1:0] calc_re [0:31];
    reg signed [DATA_W-1:0] calc_im [0:31];

    reg [4:0] wr_count;
    reg [4:0] out_count;
    reg out_active;

    reg sdf_valid_out_r;
    reg signed [DATA_W-1:0] SDFOutRe_r;
    reg signed [DATA_W-1:0] SDFOutIm_r;
    reg [4:0] sdf_out_idx_br_r;

    assign sdf_valid_out = sdf_valid_out_r;
    assign SDFOutRe = SDFOutRe_r;
    assign SDFOutIm = SDFOutIm_r;
    assign sdf_out_idx_br = sdf_out_idx_br_r;

    integer ci;
    integer cstage;
    integer cspan;
    integer chalf;
    integer cstep;
    integer cblock;
    integer cn;
    integer cupper;
    integer clower;
    integer cwf;

    reg signed [DATA_W-1:0] a_re;
    reg signed [DATA_W-1:0] a_im;
    reg signed [DATA_W-1:0] b_re;
    reg signed [DATA_W-1:0] b_im;
    reg signed [DATA_W-1:0] sum_re;
    reg signed [DATA_W-1:0] sum_im;
    reg signed [DATA_W-1:0] diff_re;
    reg signed [DATA_W-1:0] diff_im;
    reg signed [DATA_W-1:0] tw_re;
    reg signed [DATA_W-1:0] tw_im;
    reg signed [DATA_W-1:0] prod_re;
    reg signed [DATA_W-1:0] prod_im;

    always @* begin
        for (ci = 0; ci < 32; ci = ci + 1) begin
            calc_re[ci] = in_buf_re[ci];
            calc_im[ci] = in_buf_im[ci];
        end

        if (valid_in) begin
            calc_re[wr_count] = FFTInRe;
            calc_im[wr_count] = FFTInIm;
        end

        for (cstage = 0; cstage < 5; cstage = cstage + 1) begin
            cspan = 32 >> cstage;
            chalf = cspan >> 1;
            cstep = 32 / cspan;
            cwf = get_stage_wf(cstage);

            for (cblock = 0; cblock < 32; cblock = cblock + cspan) begin
                for (cn = 0; cn < chalf; cn = cn + 1) begin
                    cupper = cblock + cn;
                    clower = cupper + chalf;

                    a_re = calc_re[cupper];
                    a_im = calc_im[cupper];
                    b_re = calc_re[clower];
                    b_im = calc_im[clower];

                    sum_re = trunc_to_wf(a_re + b_re, cwf);
                    sum_im = trunc_to_wf(a_im + b_im, cwf);
                    diff_re = trunc_to_wf(a_re - b_re, cwf);
                    diff_im = trunc_to_wf(a_im - b_im, cwf);

                    tw_re = trunc_to_wf(twiddle_re(cn * cstep), WF_TWIDDLE);
                    tw_im = trunc_to_wf(twiddle_im(cn * cstep), WF_TWIDDLE);

                    prod_re = trunc_to_wf(mult_q(diff_re, tw_re) - mult_q(diff_im, tw_im), cwf);
                    prod_im = trunc_to_wf(mult_q(diff_re, tw_im) + mult_q(diff_im, tw_re), cwf);

                    calc_re[cupper] = sum_re;
                    calc_im[cupper] = sum_im;
                    calc_re[clower] = prod_re;
                    calc_im[clower] = prod_im;
                end
            end
        end
    end

    integer si;
    wire symbol_done = valid_in && (wr_count == 5'd31);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_count <= 5'd0;
            out_count <= 5'd0;
            out_active <= 1'b0;
            sdf_valid_out_r <= 1'b0;
            SDFOutRe_r <= {DATA_W{1'b0}};
            SDFOutIm_r <= {DATA_W{1'b0}};
            sdf_out_idx_br_r <= 5'd0;
            for (si = 0; si < 32; si = si + 1) begin
                in_buf_re[si] <= {DATA_W{1'b0}};
                in_buf_im[si] <= {DATA_W{1'b0}};
                out_buf_re[si] <= {DATA_W{1'b0}};
                out_buf_im[si] <= {DATA_W{1'b0}};
            end
        end else begin
            sdf_valid_out_r <= 1'b0;

            if (valid_in) begin
                in_buf_re[wr_count] <= FFTInRe;
                in_buf_im[wr_count] <= FFTInIm;
                if (symbol_done) begin
                    wr_count <= 5'd0;
                    for (si = 0; si < 32; si = si + 1) begin
                        out_buf_re[si] <= calc_re[si];
                        out_buf_im[si] <= calc_im[si];
                    end
                end else begin
                    wr_count <= wr_count + 5'd1;
                end
            end

            if (out_active) begin
                sdf_valid_out_r <= 1'b1;
                SDFOutRe_r <= out_buf_re[out_count];
                SDFOutIm_r <= out_buf_im[out_count];
                sdf_out_idx_br_r <= bit_reverse5(out_count);

                if (out_count == 5'd31) begin
                    out_count <= 5'd0;
                    out_active <= symbol_done;
                end else begin
                    out_count <= out_count + 5'd1;
                end
            end else if (symbol_done) begin
                out_count <= 5'd0;
                out_active <= 1'b1;
            end
        end
    end

    function integer get_stage_wf;
        input integer stage;
        begin
            case (stage)
                0: get_stage_wf = WF_STAGE1;
                1: get_stage_wf = WF_STAGE2;
                2: get_stage_wf = WF_STAGE3;
                3: get_stage_wf = WF_STAGE4;
                default: get_stage_wf = WF_STAGE5;
            endcase
        end
    endfunction

    function [4:0] bit_reverse5;
        input [4:0] value;
        begin
            bit_reverse5 = {value[0], value[1], value[2], value[3], value[4]};
        end
    endfunction

    function signed [DATA_W-1:0] mult_q;
        input signed [DATA_W-1:0] x;
        input signed [DATA_W-1:0] y;
        reg signed [2*DATA_W-1:0] product;
        reg signed [2*DATA_W-1:0] mag;
        begin
            product = x * y;
            if (product < 0) begin
                mag = -product;
                mult_q = -(mag >>> FRAC_W);
            end else begin
                mult_q = product >>> FRAC_W;
            end
        end
    endfunction

    function signed [DATA_W-1:0] trunc_to_wf;
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

    function signed [DATA_W-1:0] twiddle_re;
        input integer k;
        begin
            case (k[3:0])
                4'd0:  twiddle_re = scale_const(32'sd262144);
                4'd1:  twiddle_re = scale_const(32'sd257107);
                4'd2:  twiddle_re = scale_const(32'sd242189);
                4'd3:  twiddle_re = scale_const(32'sd217965);
                4'd4:  twiddle_re = scale_const(32'sd185364);
                4'd5:  twiddle_re = scale_const(32'sd145639);
                4'd6:  twiddle_re = scale_const(32'sd100318);
                4'd7:  twiddle_re = scale_const(32'sd51142);
                4'd8:  twiddle_re = scale_const(32'sd0);
                4'd9:  twiddle_re = scale_const(-32'sd51142);
                4'd10: twiddle_re = scale_const(-32'sd100318);
                4'd11: twiddle_re = scale_const(-32'sd145639);
                4'd12: twiddle_re = scale_const(-32'sd185364);
                4'd13: twiddle_re = scale_const(-32'sd217965);
                4'd14: twiddle_re = scale_const(-32'sd242189);
                default: twiddle_re = scale_const(-32'sd257107);
            endcase
        end
    endfunction

    function signed [DATA_W-1:0] twiddle_im;
        input integer k;
        begin
            case (k[3:0])
                4'd0:  twiddle_im = scale_const(32'sd0);
                4'd1:  twiddle_im = scale_const(-32'sd51142);
                4'd2:  twiddle_im = scale_const(-32'sd100318);
                4'd3:  twiddle_im = scale_const(-32'sd145639);
                4'd4:  twiddle_im = scale_const(-32'sd185364);
                4'd5:  twiddle_im = scale_const(-32'sd217965);
                4'd6:  twiddle_im = scale_const(-32'sd242189);
                4'd7:  twiddle_im = scale_const(-32'sd257107);
                4'd8:  twiddle_im = scale_const(-32'sd262144);
                4'd9:  twiddle_im = scale_const(-32'sd257107);
                4'd10: twiddle_im = scale_const(-32'sd242189);
                4'd11: twiddle_im = scale_const(-32'sd217965);
                4'd12: twiddle_im = scale_const(-32'sd185364);
                4'd13: twiddle_im = scale_const(-32'sd145639);
                4'd14: twiddle_im = scale_const(-32'sd100318);
                default: twiddle_im = scale_const(-32'sd51142);
            endcase
        end
    endfunction

    function signed [DATA_W-1:0] scale_const;
        input signed [31:0] value;
        integer shift;
        reg signed [31:0] scaled;
        begin
            if (FRAC_W >= 18) begin
                shift = FRAC_W - 18;
                scaled = value <<< shift;
            end else begin
                shift = 18 - FRAC_W;
                scaled = value >>> shift;
            end
            scale_const = scaled[DATA_W-1:0];
        end
    endfunction
endmodule
