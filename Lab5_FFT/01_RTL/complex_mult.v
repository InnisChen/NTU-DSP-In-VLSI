`timescale 1ns/1ps

module complex_mult #(
    parameter DATA_W = 24,
    parameter FRAC_W = 16,
    parameter OUT_WF = 16
) (
    input  wire signed [DATA_W-1:0] a_re,
    input  wire signed [DATA_W-1:0] a_im,
    input  wire signed [DATA_W-1:0] b_re,
    input  wire signed [DATA_W-1:0] b_im,
    output wire signed [DATA_W-1:0] y_re,
    output wire signed [DATA_W-1:0] y_im
);
    wire signed [DATA_W-1:0] arbr = mult_q(a_re, b_re);
    wire signed [DATA_W-1:0] aibi = mult_q(a_im, b_im);
    wire signed [DATA_W-1:0] arbi = mult_q(a_re, b_im);
    wire signed [DATA_W-1:0] aibr = mult_q(a_im, b_re);

    assign y_re = trunc_to_wf(arbr - aibi, OUT_WF);
    assign y_im = trunc_to_wf(arbi + aibr, OUT_WF);

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
endmodule
