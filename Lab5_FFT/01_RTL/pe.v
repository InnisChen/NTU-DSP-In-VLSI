`timescale 1ns/1ps

module pe #(
    parameter DATA_W = 24,
    parameter FRAC_W = 16,
    parameter WF_STAGE = 16
) (
    input  wire ctr_i,
    input  wire signed [DATA_W-1:0] upper_re,
    input  wire signed [DATA_W-1:0] upper_im,
    input  wire signed [DATA_W-1:0] lower_re,
    input  wire signed [DATA_W-1:0] lower_im,
    output wire signed [DATA_W-1:0] upper_out_re,
    output wire signed [DATA_W-1:0] upper_out_im,
    output wire signed [DATA_W-1:0] lower_out_re,
    output wire signed [DATA_W-1:0] lower_out_im
);
    wire signed [DATA_W-1:0] sum_re  = trunc_to_wf(upper_re + lower_re, WF_STAGE);
    wire signed [DATA_W-1:0] sum_im  = trunc_to_wf(upper_im + lower_im, WF_STAGE);
    wire signed [DATA_W-1:0] diff_re = trunc_to_wf(upper_re - lower_re, WF_STAGE);
    wire signed [DATA_W-1:0] diff_im = trunc_to_wf(upper_im - lower_im, WF_STAGE);

    assign upper_out_re = ctr_i ? sum_re : lower_re;
    assign upper_out_im = ctr_i ? sum_im : lower_im;
    assign lower_out_re = ctr_i ? diff_re : upper_re;
    assign lower_out_im = ctr_i ? diff_im : upper_im;

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
endmodule
