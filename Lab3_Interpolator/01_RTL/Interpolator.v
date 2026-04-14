`timescale 1ns/1ps
// Interpolator.v  -  2nd-order Farrow structure BF16 interpolator
//
// Signal  : x1[m] = cos(2*pi*(m/10+0.5)) + j*sin(...)
// IntpIn  : {re[15:0], im[15:0]}  BF16 complex, updates every 8 clock cycles
// mu      : [15:0] BF16 fractional delay, updates every clock cycle (0,1/8,...,7/8)
// IntpOut : {re[15:0], im[15:0]}  BF16 complex interpolated output
//
// All flip-flops: posedge clk, active-low async rst_n
//
// Farrow coefficients (hardware-sharing, zero multipliers in coeff block):
//   0.5*x(m)   via exponent-1
//   0.5*x(m+2) via exponent-1
//   v2 = (0.5*x(m) - x(m+1)) + 0.5*x(m+2)
//   v1 = -(x(m) + 0.5*x(m)) + 2*x(m+1) + (-0.5*x(m+2))   [2*x via exponent+1]
//   v0 = x(m)
// Horner: out = v0 + mu*(v1 + mu*v2)   [2x BF16_MUL + 2x BF16_ADD]

module Interpolator (
    input         clk,
    input         rst_n,       // active-low async reset
    input  [31:0] IntpIn,      // {re[15:0], im[15:0]}
    input  [15:0] mu,
    output [31:0] IntpOut,
    output        IntpOut_valid
);

// =========================================================
// 1. Input registers
// =========================================================
reg [31:0] InReg;
reg [15:0] mu_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        InReg  <= 32'd0;
        mu_reg <= 16'd0;
    end else begin
        InReg  <= IntpIn;
        mu_reg <= mu;
    end
end

// =========================================================
// 2. 3-bit mod-8 counter
// =========================================================
reg [2:0] cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 3'd0;
    else        cnt <= cnt + 3'd1;
end

// =========================================================
// 3. x shift register  (shift when cnt == 7, i.e., on the 8th cycle)
//    x0 = x[m+2]  (newest),  x1 = x[m+1],  x2 = x[m]  (oldest)
// =========================================================
reg [31:0] x0, x1, x2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x0 <= 32'd0;
        x1 <= 32'd0;
        x2 <= 32'd0;
    end else if (cnt == 3'd7) begin
        x2 <= x1;
        x1 <= x0;
        x0 <= InReg;
    end
end

// =========================================================
// 4. Coefficient wires
//    s0 = x[m] = x2,  s1 = x[m+1] = x1,  s2 = x[m+2] = x0
// =========================================================
wire [15:0] s0_re = x2[31:16];  wire [15:0] s0_im = x2[15:0];
wire [15:0] s1_re = x1[31:16];  wire [15:0] s1_im = x1[15:0];
wire [15:0] s2_re = x0[31:16];  wire [15:0] s2_im = x0[15:0];

// --- bf16_half: exponent - 1 (0.5 * x) ---
wire [15:0] h0_re = (s0_re[14:7] <= 8'd1) ? 16'd0 : {s0_re[15], s0_re[14:7]-8'd1, s0_re[6:0]};
wire [15:0] h0_im = (s0_im[14:7] <= 8'd1) ? 16'd0 : {s0_im[15], s0_im[14:7]-8'd1, s0_im[6:0]};
wire [15:0] h2_re = (s2_re[14:7] <= 8'd1) ? 16'd0 : {s2_re[15], s2_re[14:7]-8'd1, s2_re[6:0]};
wire [15:0] h2_im = (s2_im[14:7] <= 8'd1) ? 16'd0 : {s2_im[15], s2_im[14:7]-8'd1, s2_im[6:0]};

// --- bf16_double: exponent + 1 (2.0 * x) ---
wire [15:0] dbl_s1_re = (s1_re[14:7] == 8'd0)   ? 16'd0                          :
                        (s1_re[14:7] >= 8'd254)  ? {s1_re[15], 8'd254, 7'h7F}    :
                                                   {s1_re[15], s1_re[14:7]+8'd1, s1_re[6:0]};
wire [15:0] dbl_s1_im = (s1_im[14:7] == 8'd0)   ? 16'd0                          :
                        (s1_im[14:7] >= 8'd254)  ? {s1_im[15], 8'd254, 7'h7F}    :
                                                   {s1_im[15], s1_im[14:7]+8'd1, s1_im[6:0]};

// --- bf16_neg: flip sign bit ---
wire [15:0] neg_s1_re   = {~s1_re[15],     s1_re[14:0]};
wire [15:0] neg_s1_im   = {~s1_im[15],     s1_im[14:0]};
wire [15:0] neg_h2_re   = {~h2_re[15],     h2_re[14:0]};
wire [15:0] neg_h2_im   = {~h2_im[15],     h2_im[14:0]};

// --- v2 = (h0 + (-s1)) + h2 ---
wire [15:0] v2_re_tmp, v2_re, v2_im_tmp, v2_im;

BF16_ADD u_v2re_1 (.a(h0_re),     .b(neg_s1_re), .result(v2_re_tmp));
BF16_ADD u_v2re_2 (.a(v2_re_tmp), .b(h2_re),     .result(v2_re));
BF16_ADD u_v2im_1 (.a(h0_im),     .b(neg_s1_im), .result(v2_im_tmp));
BF16_ADD u_v2im_2 (.a(v2_im_tmp), .b(h2_im),     .result(v2_im));

// --- s0 + h0 (intermediate for -1.5*x(m)) ---
wire [15:0] s0h0_re, s0h0_im;

BF16_ADD u_s0h0_re (.a(s0_re), .b(h0_re), .result(s0h0_re));
BF16_ADD u_s0h0_im (.a(s0_im), .b(h0_im), .result(s0h0_im));

wire [15:0] neg_s0h0_re = {~s0h0_re[15], s0h0_re[14:0]};
wire [15:0] neg_s0h0_im = {~s0h0_im[15], s0h0_im[14:0]};

// --- v1 = (-(s0+h0) + 2*s1) + (-h2) ---
wire [15:0] v1_re_tmp, v1_re, v1_im_tmp, v1_im;

BF16_ADD u_v1re_1 (.a(neg_s0h0_re), .b(dbl_s1_re), .result(v1_re_tmp));
BF16_ADD u_v1re_2 (.a(v1_re_tmp),   .b(neg_h2_re), .result(v1_re));
BF16_ADD u_v1im_1 (.a(neg_s0h0_im), .b(dbl_s1_im), .result(v1_im_tmp));
BF16_ADD u_v1im_2 (.a(v1_im_tmp),   .b(neg_h2_im), .result(v1_im));

// --- v0 = s0 (wire) ---
wire [15:0] v0_re = s0_re;
wire [15:0] v0_im = s0_im;

// =========================================================
// 5. Horner evaluation: out = v0 + mu_reg*(v1 + mu_reg*v2)
// =========================================================
wire [15:0] t1_re, t1_im;   // mu * v2
wire [15:0] t2_re, t2_im;   // v1 + t1
wire [15:0] t3_re, t3_im;   // mu * t2
wire [15:0] out_re, out_im;  // v0 + t3

BF16_MUL u_t1re (.a(mu_reg), .b(v2_re), .result(t1_re));
BF16_MUL u_t1im (.a(mu_reg), .b(v2_im), .result(t1_im));

BF16_ADD u_t2re (.a(v1_re),  .b(t1_re), .result(t2_re));
BF16_ADD u_t2im (.a(v1_im),  .b(t1_im), .result(t2_im));

BF16_MUL u_t3re (.a(mu_reg), .b(t2_re), .result(t3_re));
BF16_MUL u_t3im (.a(mu_reg), .b(t2_im), .result(t3_im));

BF16_ADD u_outre (.a(v0_re), .b(t3_re), .result(out_re));
BF16_ADD u_outim (.a(v0_im), .b(t3_im), .result(out_im));

// =========================================================
// 6. Output register
// =========================================================
reg [31:0] IntpOut_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) IntpOut_reg <= 32'd0;
    else        IntpOut_reg <= {out_re, out_im};
end

assign IntpOut = IntpOut_reg;

// =========================================================
// 7. IntpOut_valid: assert after 3 x-shifts (pipeline filled)
// =========================================================
reg [1:0] shift_cnt;  // saturates at 3

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) shift_cnt <= 2'd0;
    else if (cnt == 3'd7 && shift_cnt != 2'd3)
        shift_cnt <= shift_cnt + 2'd1;
end

reg valid_reg;  // pipelined 1 cycle to align with IntpOut_reg

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) valid_reg <= 1'b0;
    else        valid_reg <= (shift_cnt == 2'd3);
end

assign IntpOut_valid = valid_reg;

endmodule
