`timescale 1ns/1ps
// BF16_ADD.v  -  BF16 floating-point adder (truncation, no rounding)
//
// Format: [15] sign | [14:7] exponent (bias=127) | [6:0] fraction
// Rules:  subnormal (E=0) treated as zero; truncation; no NaN/Inf
//
// Operation order matches MATLAB bf16_add.m exactly (bit-true).

module BF16_ADD (
    input  [15:0] a,
    input  [15:0] b,
    output [15:0] result
);

// --- Extract fields ---
wire        S_a = a[15];
wire [7:0]  E_a = a[14:7];
wire [6:0]  F_a = a[6:0];

wire        S_b = b[15];
wire [7:0]  E_b = b[14:7];
wire [6:0]  F_b = b[6:0];

// --- Full mantissa with implicit leading 1 ---
wire [7:0]  M_a = {1'b1, F_a};
wire [7:0]  M_b = {1'b1, F_b};

// --- Sort: ensure big_E >= sml_E ---
wire swap = (E_a < E_b);

wire        S_big = swap ? S_b : S_a;
wire [7:0]  E_big = swap ? E_b : E_a;
wire [7:0]  M_big = swap ? M_b : M_a;

wire        S_sml = swap ? S_a : S_b;
wire [7:0]  E_sml = swap ? E_a : E_b;
wire [7:0]  M_sml = swap ? M_a : M_b;

// --- Align smaller operand (right-shift with truncation) ---
wire [7:0]  shift = E_big - E_sml;   // always >= 0 after sort

wire [7:0]  M_sml_aligned = (shift >= 8'd8) ? 8'd0 : (M_sml >> shift);

// --- Signed addition ---
// Represent magnitudes as 9-bit signed: positive if same sign as big
wire [8:0]  M_big_s = {1'b0, M_big};
wire [8:0]  M_sml_s = {1'b0, M_sml_aligned};

wire [8:0]  val = (S_big == S_sml) ? (M_big_s + M_sml_s)
                                   : (M_big_s - M_sml_s);
// val is always >= 0 (since M_big >= M_sml_aligned after sort and align)

wire        is_zero = (val == 9'd0);

// --- Result sign: same as big operand (or subtraction might need adjustment)
//     When E_big > E_sml: big dominates, sign = S_big
//     When E_big == E_sml and same sign: sign = S_big
//     When E_big == E_sml and diff sign: val = M_big - M_sml
//       if M_big > M_sml: sign = S_big (val > 0)
//       if M_big == M_sml: val = 0, handled by is_zero
//       if M_big < M_sml: can't happen after sort (E_big >= E_sml AND swap picks larger E)
//     So S_r = S_big is always correct.
wire        S_r = S_big;

// --- Overflow normalization: val up to 9 bits (max 255+255=510 but after align <= 255+255) ---
// If val >= 256: shift right 1 (truncate), E_r += 1
wire        ovf     = val[8];
wire [7:0]  M_ovf   = ovf ? val[8:1] : val[7:0];   // truncate LSB if overflow
wire [8:0]  E_ovf   = ovf ? ({1'b0, E_big} + 9'd1) : {1'b0, E_big};

// --- Leading-zero normalization ---
// Find leading-zero count in M_ovf[7:0]; shift left by lz, subtract lz from E
reg  [2:0]  lz;
always @(*) begin
    casex (M_ovf[7:0])
        8'b1xxx_xxxx: lz = 3'd0;
        8'b01xx_xxxx: lz = 3'd1;
        8'b001x_xxxx: lz = 3'd2;
        8'b0001_xxxx: lz = 3'd3;
        8'b0000_1xxx: lz = 3'd4;
        8'b0000_01xx: lz = 3'd5;
        8'b0000_001x: lz = 3'd6;
        default:      lz = 3'd7;   // 8'b0000_0001 or 0 (zero handled earlier)
    endcase
end

wire [7:0]  M_norm  = M_ovf << lz;
wire [8:0]  E_norm  = E_ovf - {6'b0, lz};          // may go negative (underflow)

// --- Underflow / overflow clamp ---
wire        uflow   = E_norm[8] | (E_norm == 9'd0);  // signed negative or zero
wire        oflow   = (E_norm >= 9'd255);

wire [7:0]  E_r     = oflow ? 8'd254 : E_norm[7:0];
wire [7:0]  M_r     = oflow ? 8'hFF  : M_norm;

// --- Truncate fraction (drop implicit leading 1) ---
wire [6:0]  F_r     = M_r[6:0];

// --- Mux output ---
// E=0 special cases: return the other operand unchanged
wire e_a_zero = (E_a == 8'd0);
wire e_b_zero = (E_b == 8'd0);

wire [15:0] normal_result = (is_zero | uflow) ? 16'd0
                          : {S_r, E_r, F_r};

assign result = (e_a_zero && e_b_zero) ? 16'd0
              : e_a_zero               ? b
              : e_b_zero               ? a
              : normal_result;

endmodule
