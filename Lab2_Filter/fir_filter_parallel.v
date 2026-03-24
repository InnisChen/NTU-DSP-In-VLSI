// =============================================================================
// Module: fir_filter_parallel
// Description: 25-tap Direct Form FIR Low-Pass Filter, 2x Parallel Speedup
//
// Block processing: 2 input samples per clock -> 2 output samples per clock
// Throughput = 2x compared to fir_filter.v at the same clock rate
//
// Word-length (same as fir_filter.v):
//   Input  x : 16 bits signed [1 Sign + 2 Int + 13 Frac]  b_in   = 13
//   Coeff  h : 17 bits signed [1 Sign + 1 Int + 15 Frac]  b_coef = 15
//   Mult out : 20 bits signed [1 Sign + 2 Int + 17 Frac]  b_mult = 17
//   Add  out : 21 bits signed [1 Sign + 3 Int + 17 Frac]  b_add  = 17
//   Output y : 21 bits signed (same as adder output)
//
// Parallel derivation (shift_reg has TAPS+1 = 26 entries after update):
//   shift_reg[0]  = FilterIn1  (x[2n+1], newest)
//   shift_reg[1]  = FilterIn0  (x[2n])
//   shift_reg[k]  = old shift_reg[k-2], k=2..25
//
//   FilterOut1 = y[2n+1] = SUM h[k] * shift_reg[k],   k=0..24
//   FilterOut0 = y[2n]   = SUM h[k] * shift_reg[k+1], k=0..24
// =============================================================================

module fir_filter_parallel (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [15:0] FilterIn0,  // x[2n]   even sample (older)
    input  wire signed [15:0] FilterIn1,  // x[2n+1] odd  sample (newer)
    input  wire        ValidIn,
    output reg  signed [20:0] FilterOut0, // y[2n]
    output reg  signed [20:0] FilterOut1, // y[2n+1]
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
// Shift Register: TAPS+1 = 26 entries
// shift_reg[0]  = FilterIn1 (newest)
// shift_reg[1]  = FilterIn0
// shift_reg[k]  = old shift_reg[k-2], k=2..25
// =============================================================================
reg signed [W_IN-1:0] shift_reg [0:TAPS];  // 0..25
reg valid_pipe;

integer si;
always @(posedge clk) begin
    if (!rst_n) begin
        for (si = 0; si <= TAPS; si = si + 1)
            shift_reg[si] <= 0;
        valid_pipe <= 0;
    end else begin
        valid_pipe <= ValidIn;
        if (ValidIn) begin
            shift_reg[0] <= FilterIn1;
            shift_reg[1] <= FilterIn0;
            for (si = 2; si <= TAPS; si = si + 1)
                shift_reg[si] <= shift_reg[si-2];
        end
    end
end

// =============================================================================
// Stage 1: Two sets of 25 multipliers + truncation
// Out1 uses shift_reg[0..24], Out0 uses shift_reg[1..25]
// full = 33 bits, discard 11 LSBs -> keep [32:11] = 20 bits
// =============================================================================
wire signed [W_MULT_FULL-1:0] mult_full1  [0:TAPS-1];
wire signed [W_MULT_FULL-1:0] mult_full0  [0:TAPS-1];
wire signed [W_MULT-1:0]      mult_trunc1 [0:TAPS-1];
wire signed [W_MULT-1:0]      mult_trunc0 [0:TAPS-1];

genvar gi;
generate
    for (gi = 0; gi < TAPS; gi = gi + 1) begin : MULT_STAGE
        assign mult_full1[gi]  = shift_reg[gi]   * h_coef[gi];
        assign mult_full0[gi]  = shift_reg[gi+1] * h_coef[gi];
        assign mult_trunc1[gi] = mult_full1[gi][W_MULT_FULL-1 : MULT_DISCARD];
        assign mult_trunc0[gi] = mult_full0[gi][W_MULT_FULL-1 : MULT_DISCARD];
    end
endgenerate

// =============================================================================
// Stage 2: Two chained accumulators
// Sign-extend mult_trunc (20-bit) to 21-bit, accumulate
// =============================================================================
reg signed [W_ADD-1:0] acc1 [0:TAPS-1];
reg signed [W_ADD-1:0] acc0 [0:TAPS-1];

integer ai;
always @(*) begin
    acc1[0] = {{(W_ADD-W_MULT){mult_trunc1[0][W_MULT-1]}}, mult_trunc1[0]};
    acc0[0] = {{(W_ADD-W_MULT){mult_trunc0[0][W_MULT-1]}}, mult_trunc0[0]};
    for (ai = 1; ai < TAPS; ai = ai + 1) begin
        acc1[ai] = acc1[ai-1] + {{(W_ADD-W_MULT){mult_trunc1[ai][W_MULT-1]}}, mult_trunc1[ai]};
        acc0[ai] = acc0[ai-1] + {{(W_ADD-W_MULT){mult_trunc0[ai][W_MULT-1]}}, mult_trunc0[ai]};
    end
end

// =============================================================================
// Output DFF
// =============================================================================
always @(posedge clk) begin
    if (!rst_n) begin
        FilterOut0 <= 0;
        FilterOut1 <= 0;
        ValidOut   <= 0;
    end else begin
        ValidOut <= valid_pipe;
        if (valid_pipe) begin
            FilterOut0 <= acc0[TAPS-1];
            FilterOut1 <= acc1[TAPS-1];
        end
    end
end

endmodule
