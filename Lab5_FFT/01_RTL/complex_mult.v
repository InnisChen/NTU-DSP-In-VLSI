`timescale 1ns/1ps

module complex_mult #(
    parameter DATA_W = 16,
    parameter FRAC_W = 9,
    parameter TWIDDLE_W = 11,
    parameter TWIDDLE_FRAC_W = 9,
    parameter OUT_WF = 9
) (
    input  wire signed [DATA_W-1:0] a_re,
    input  wire signed [DATA_W-1:0] a_im,
    input  wire signed [TWIDDLE_W-1:0] b_re,
    input  wire signed [TWIDDLE_W-1:0] b_im,
    output wire signed [DATA_W-1:0] y_re,
    output wire signed [DATA_W-1:0] y_im
);
    wire signed [DATA_W+TWIDDLE_W-1:0] arbr = a_re * b_re;
    wire signed [DATA_W+TWIDDLE_W-1:0] aibi = a_im * b_im;
    wire signed [DATA_W+TWIDDLE_W-1:0] arbi = a_re * b_im;
    wire signed [DATA_W+TWIDDLE_W-1:0] aibr = a_im * b_re;

    wire signed [DATA_W+TWIDDLE_W:0] prod_re =
        {arbr[DATA_W+TWIDDLE_W-1], arbr} - {aibi[DATA_W+TWIDDLE_W-1], aibi};
    wire signed [DATA_W+TWIDDLE_W:0] prod_im =
        {arbi[DATA_W+TWIDDLE_W-1], arbi} + {aibr[DATA_W+TWIDDLE_W-1], aibr};

    wire signed [DATA_W-1:0] prod_re_q = product_to_data_q(prod_re);
    wire signed [DATA_W-1:0] prod_im_q = product_to_data_q(prod_im);

    assign y_re = trunc_to_wf(prod_re_q, OUT_WF);
    assign y_im = trunc_to_wf(prod_im_q, OUT_WF);

    function automatic signed [DATA_W-1:0] product_to_data_q;
        input signed [DATA_W+TWIDDLE_W:0] product;
        reg signed [DATA_W+TWIDDLE_W:0] mag;
        begin
            if (product < 0) begin
                mag = -product;
                product_to_data_q = -(mag >>> TWIDDLE_FRAC_W);
            end else begin
                product_to_data_q = product >>> TWIDDLE_FRAC_W;
            end
        end
    endfunction

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
