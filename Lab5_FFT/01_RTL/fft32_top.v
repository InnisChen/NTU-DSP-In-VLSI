`timescale 1ns/1ps

module fft32_top #(
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

    output wire br_valid_out,
    output wire signed [DATA_W-1:0] BROutRe,
    output wire signed [DATA_W-1:0] BROutIm
);
    wire [4:0] sdf_out_idx_br;
    wire [4:0] br_out_idx;
    wire wr_bank;
    wire rd_bank;
    wire [4:0] wr_addr;
    wire [4:0] rd_addr;

    sdf_fft32 #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .WF_STAGE1(WF_STAGE1),
        .WF_STAGE2(WF_STAGE2),
        .WF_STAGE3(WF_STAGE3),
        .WF_STAGE4(WF_STAGE4),
        .WF_STAGE5(WF_STAGE5),
        .WF_TWIDDLE(WF_TWIDDLE)
    ) u_sdf_fft32 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .FFTInRe(FFTInRe),
        .FFTInIm(FFTInIm),
        .sdf_valid_out(sdf_valid_out),
        .SDFOutRe(SDFOutRe),
        .SDFOutIm(SDFOutIm),
        .sdf_out_idx_br(sdf_out_idx_br)
    );

    bit_reverse_buffer #(
        .DATA_W(DATA_W)
    ) u_bit_reverse_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(sdf_valid_out),
        .SDFOutRe(SDFOutRe),
        .SDFOutIm(SDFOutIm),
        .br_valid_out(br_valid_out),
        .BROutRe(BROutRe),
        .BROutIm(BROutIm),
        .br_out_idx(br_out_idx),
        .wr_bank(wr_bank),
        .rd_bank(rd_bank),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr)
    );
endmodule
