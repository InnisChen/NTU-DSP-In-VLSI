// BF16_MUL.v  -  BF16 floating-point multiplier (truncation, no rounding)
//
// Format: [15] sign | [14:7] exponent (bias=127) | [6:0] fraction
// Rules:  subnormal (E=0) treated as zero; truncation; no NaN/Inf
//
// Operation order matches MATLAB bf16_mul.m exactly (bit-true).

module BF16_MUL (
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

// --- Subnormal -> zero ---
wire zero_out = (E_a == 8'd0) || (E_b == 8'd0);

// --- Result sign: XOR ---
wire S_r = S_a ^ S_b;

// --- Result exponent (10-bit signed to handle underflow/overflow) ---
// E_r = E_a + E_b - 127
wire [9:0] E_sum = {2'b00, E_a} + {2'b00, E_b};   // max 508
wire [9:0] E_pre = E_sum - 10'd127;                 // may be <= 0

// --- Mantissa product: 8-bit x 8-bit = up to 16 bits ---
wire [7:0]  M_a = {1'b1, F_a};
wire [7:0]  M_b = {1'b1, F_b};
wire [15:0] P   = M_a * M_b;   // range [16384, 65025]

// --- Normalize: implicit 1 at bit 15 or bit 14 ---
// P[15]==1 → shift right 8, E_r += 1
// P[15]==0 → shift right 7 (P[14] must be 1 since M_a,M_b >= 128)
wire        p15    = P[15];
wire [7:0]  M_norm = p15 ? P[15:8] : P[14:7];      // truncate lower bits
wire [9:0]  E_r    = p15 ? (E_pre + 10'd1) : E_pre;

// --- Underflow / overflow ---
// E_r is 10-bit; underflow if bit9 (sign) set or E_r==0; overflow if >= 255
wire        uflow  = E_r[9] | (E_r == 10'd0);
wire        oflow  = (E_r >= 10'd255);

wire [7:0]  E_out  = oflow ? 8'd254    : E_r[7:0];
wire [7:0]  M_out  = oflow ? 8'hFF     : M_norm;

// --- Fraction bits ---
wire [6:0]  F_r    = M_out[6:0];

assign result = zero_out          ? 16'd0
              : (uflow)           ? 16'd0
              : {S_r, E_out, F_r};

endmodule
