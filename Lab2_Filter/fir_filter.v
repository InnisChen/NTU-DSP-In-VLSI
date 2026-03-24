// =============================================================================
// Module: fir_filter
// Description: 25-tap Direct Form FIR Low-Pass Filter
//
// Word-length from MATLAB Step 3 (corrected):
//   Input  x : 16 bits signed [1 Sign + 2 Int + 13 Frac]  b_in   = 13
//   Coeff  h : 17 bits signed [1 Sign + 1 Int + 15 Frac]  b_coef = 15
//   Mult out : 20 bits signed [1 Sign + 2 Int + 17 Frac]  b_mult = 17
//   Add  out : 21 bits signed [1 Sign + 3 Int + 17 Frac]  b_add  = 17
//   Output y : 21 bits signed (same as adder output)
//
// Truncation:
//   mult full: W_IN+W_COEF = 33 bits, frac = F_IN+F_COEF = 28 bits
//   discard 28-17 = 11 LSBs -> keep [32:11] -> 20 bits (W_MULT)
//   add: frac stays at 17 bits, W_ADD=21 limits integer growth naturally
// =============================================================================

module fir_filter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [15:0] FilterIn,   // 16-bit [1S+2I+13F]
    input  wire        ValidIn,
    output reg  signed [20:0] FilterOut,  // 21-bit [1S+3I+17F]
    output reg         ValidOut
);

parameter TAPS   = 25;
parameter W_IN   = 16;
parameter W_COEF = 17;
parameter W_MULT = 20;
parameter W_ADD  = 21;
parameter F_IN   = 13;
parameter F_COEF = 15;
parameter F_MULT = 17;
parameter F_ADD  = 17;

localparam MULT_DISCARD = F_IN + F_COEF - F_MULT;  // 13+15-17 = 11
localparam W_MULT_FULL  = W_IN + W_COEF;            // 16+17    = 33

// =============================================================================
// Coefficient ROM [1S+1I+15F, 17-bit signed]
// =============================================================================
reg signed [W_COEF-1:0] h_coef [0:TAPS-1];

initial $readmemh("C:/Project/DSP in VLSI/Lab2_Filter/matlab/h_coef.dat", h_coef);

// =============================================================================
// Input DFF + Shift Register
// =============================================================================
reg signed [W_IN-1:0] shift_reg [0:TAPS-1];
reg valid_pipe;

integer si;
always @(posedge clk) begin
    if (!rst_n) begin
        for (si = 0; si < TAPS; si = si + 1)
            shift_reg[si] <= 0;
        valid_pipe <= 0;
    end else begin
        valid_pipe <= ValidIn;
        if (ValidIn) begin
            shift_reg[0] <= FilterIn;
            for (si = 1; si < TAPS; si = si + 1)
                shift_reg[si] <= shift_reg[si-1];
        end
    end
end

// =============================================================================
// Stage 1: 25 Parallel Multipliers + Truncation
// full = 33 bits, discard 11 LSBs -> keep [32:11] = 20 bits
// =============================================================================
wire signed [W_MULT_FULL-1:0] mult_full  [0:TAPS-1];
wire signed [W_MULT-1:0]      mult_trunc [0:TAPS-1];

genvar gi;
generate
    for (gi = 0; gi < TAPS; gi = gi + 1) begin : MULT_STAGE
        assign mult_full[gi]  = shift_reg[gi] * h_coef[gi];
        assign mult_trunc[gi] = mult_full[gi][W_MULT_FULL-1 : MULT_DISCARD];
    end
endgenerate

// =============================================================================
// Stage 2: 24 Chained Adders + Truncation
// Sign-extend mult_trunc (20-bit) to acc (21-bit), accumulate
// W_ADD=21 bits naturally truncates integer growth (max add value ~6.4)
// =============================================================================
reg signed [W_ADD-1:0] acc [0:TAPS-1];

integer ai;
always @(*) begin
    acc[0] = {{(W_ADD-W_MULT){mult_trunc[0][W_MULT-1]}}, mult_trunc[0]};
    for (ai = 1; ai < TAPS; ai = ai + 1)
        acc[ai] = acc[ai-1] + {{(W_ADD-W_MULT){mult_trunc[ai][W_MULT-1]}}, mult_trunc[ai]};
end

// =============================================================================
// Output DFF
// =============================================================================
always @(posedge clk) begin
    if (!rst_n) begin
        FilterOut <= 0;
        ValidOut  <= 0;
    end else begin
        ValidOut  <= valid_pipe;
        if (valid_pipe)
            FilterOut <= acc[TAPS-1];
    end
end

endmodule   