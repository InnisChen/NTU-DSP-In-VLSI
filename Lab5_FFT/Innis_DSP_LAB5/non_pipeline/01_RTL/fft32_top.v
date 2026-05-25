`timescale 1ns/1ps

module fft32_top #(
    parameter DATA_W = 16,
    parameter FRAC_W = 9,
    parameter TWIDDLE_W = 11,
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
    reg valid_in_indff;
    reg signed [DATA_W-1:0] FFTInRe_indff;
    reg signed [DATA_W-1:0] FFTInIm_indff;

    wire sdf_valid_out_w;
    wire signed [DATA_W-1:0] SDFOutRe_w;
    wire signed [DATA_W-1:0] SDFOutIm_w;

    wire br_valid_out_w;
    wire signed [DATA_W-1:0] BROutRe_w;
    wire signed [DATA_W-1:0] BROutIm_w;

    reg sdf_valid_out_outdff;
    reg signed [DATA_W-1:0] SDFOutRe_outdff;
    reg signed [DATA_W-1:0] SDFOutIm_outdff;

    reg br_valid_out_outdff;
    reg signed [DATA_W-1:0] BROutRe_outdff;
    reg signed [DATA_W-1:0] BROutIm_outdff;

    wire [4:0] br_out_idx;
    wire wr_bank;
    wire rd_bank;
    wire [4:0] wr_addr;
    wire [4:0] rd_addr;

    assign sdf_valid_out = sdf_valid_out_outdff;
    assign SDFOutRe = SDFOutRe_outdff;
    assign SDFOutIm = SDFOutIm_outdff;
    assign br_valid_out = br_valid_out_outdff;
    assign BROutRe = BROutRe_outdff;
    assign BROutIm = BROutIm_outdff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_in_indff <= 1'b0;
            FFTInRe_indff <= {DATA_W{1'b0}};
            FFTInIm_indff <= {DATA_W{1'b0}};
        end else begin
            valid_in_indff <= valid_in;
            FFTInRe_indff <= FFTInRe;
            FFTInIm_indff <= FFTInIm;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdf_valid_out_outdff <= 1'b0;
            SDFOutRe_outdff <= {DATA_W{1'b0}};
            SDFOutIm_outdff <= {DATA_W{1'b0}};
            br_valid_out_outdff <= 1'b0;
            BROutRe_outdff <= {DATA_W{1'b0}};
            BROutIm_outdff <= {DATA_W{1'b0}};
        end else begin
            sdf_valid_out_outdff <= sdf_valid_out_w;
            SDFOutRe_outdff <= SDFOutRe_w;
            SDFOutIm_outdff <= SDFOutIm_w;
            br_valid_out_outdff <= br_valid_out_w;
            BROutRe_outdff <= BROutRe_w;
            BROutIm_outdff <= BROutIm_w;
        end
    end

    sdf_fft32 #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .TWIDDLE_W(TWIDDLE_W),
        .WF_STAGE1(WF_STAGE1),
        .WF_STAGE2(WF_STAGE2),
        .WF_STAGE3(WF_STAGE3),
        .WF_STAGE4(WF_STAGE4),
        .WF_STAGE5(WF_STAGE5),
        .WF_TWIDDLE(WF_TWIDDLE)
    ) u_sdf_fft32 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in_indff),
        .FFTInRe(FFTInRe_indff),
        .FFTInIm(FFTInIm_indff),
        .sdf_valid_out(sdf_valid_out_w),
        .SDFOutRe(SDFOutRe_w),
        .SDFOutIm(SDFOutIm_w)
    );

    bit_reverse_buffer #(
        .DATA_W(DATA_W)
    ) u_bit_reverse_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(sdf_valid_out_w),
        .SDFOutRe(SDFOutRe_w),
        .SDFOutIm(SDFOutIm_w),
        .br_valid_out(br_valid_out_w),
        .BROutRe(BROutRe_w),
        .BROutIm(BROutIm_w),
        .br_out_idx(br_out_idx),
        .wr_bank(wr_bank),
        .rd_bank(rd_bank),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr)
    );
endmodule
