`timescale 1ns/1ps

// Step 9: S/2-Unfolded CORDIC - arctangent + magnitude
// Parameters: W=11 (1S+1I+9F), TW=11 (1S+2I+8F), S=10
// Pipeline: Initial -> Stage 0..4 (comb) -> [FF] -> Stage 5..9 (comb) -> [FF]
// Latency: 2 clock cycles
//
// Magnitude output: outMag = Xs9 * A_N (CSD scaling, fw=9)
//   A_N = 1/K_N = 2^(-1) + 2^(-3) - 2^(-6) - 2^(-9) = 0.607422
//   True A_10   = 0.607253,  rel_err = 0.028% < 0.1%
// Assumes input magnitude <= 1.0 (no overflow).

module CORDIC_mag #(
    parameter W  = 11,
    parameter TW = 11,
    parameter S  = 10
)(
    input                        clk,
    input                        rst_n,
    input  signed [W-1:0]       inX,
    input  signed [W-1:0]       inY,
    input                        in_valid,
    output reg signed [TW-1:0]  outTheta,
    output reg signed [W-1:0]   outMag,
    output reg                   out_valid
);

localparam signed [TW-1:0] PI_POS =  11'sd804;
localparam signed [TW-1:0] PI_NEG = -11'sd804;

localparam signed [TW-1:0] A0 = 11'd201;
localparam signed [TW-1:0] A1 = 11'd119;
localparam signed [TW-1:0] A2 = 11'd63;
localparam signed [TW-1:0] A3 = 11'd32;
localparam signed [TW-1:0] A4 = 11'd16;
localparam signed [TW-1:0] A5 = 11'd8;
localparam signed [TW-1:0] A6 = 11'd4;
localparam signed [TW-1:0] A7 = 11'd2;
localparam signed [TW-1:0] A8 = 11'd1;
localparam signed [TW-1:0] A9 = 11'd0;

// -----------------------------------------------------------------------
// Initial stage: quadrant mapping
// -----------------------------------------------------------------------
wire signed [W-1:0]  X_init = inX[W-1] ? -inX : inX;
wire signed [W-1:0]  Y_init = inX[W-1] ? -inY : inY;
wire signed [TW-1:0] T_init = inX[W-1] ? (inY[W-1] ? PI_NEG : PI_POS) : {TW{1'b0}};

// -----------------------------------------------------------------------
// First half: stages 0..4 (combinational)
// Y>=0: X+=Y_sh, Y-=X_sh, T+=A_i
// Y<0 : X-=Y_sh, Y+=X_sh, T-=A_i
// -----------------------------------------------------------------------
wire signed [W-1:0]  Xs0 = Y_init[W-1] ? X_init - Y_init       : X_init + Y_init;
wire signed [W-1:0]  Ys0 = Y_init[W-1] ? Y_init + X_init       : Y_init - X_init;
wire signed [TW-1:0] Ts0 = Y_init[W-1] ? T_init - A0           : T_init + A0;

wire signed [W-1:0]  Xs1 = Ys0[W-1] ? Xs0 - (Ys0 >>> 1) : Xs0 + (Ys0 >>> 1);
wire signed [W-1:0]  Ys1 = Ys0[W-1] ? Ys0 + (Xs0 >>> 1) : Ys0 - (Xs0 >>> 1);
wire signed [TW-1:0] Ts1 = Ys0[W-1] ? Ts0 - A1          : Ts0 + A1;

wire signed [W-1:0]  Xs2 = Ys1[W-1] ? Xs1 - (Ys1 >>> 2) : Xs1 + (Ys1 >>> 2);
wire signed [W-1:0]  Ys2 = Ys1[W-1] ? Ys1 + (Xs1 >>> 2) : Ys1 - (Xs1 >>> 2);
wire signed [TW-1:0] Ts2 = Ys1[W-1] ? Ts1 - A2          : Ts1 + A2;

wire signed [W-1:0]  Xs3 = Ys2[W-1] ? Xs2 - (Ys2 >>> 3) : Xs2 + (Ys2 >>> 3);
wire signed [W-1:0]  Ys3 = Ys2[W-1] ? Ys2 + (Xs2 >>> 3) : Ys2 - (Xs2 >>> 3);
wire signed [TW-1:0] Ts3 = Ys2[W-1] ? Ts2 - A3          : Ts2 + A3;

wire signed [W-1:0]  Xs4 = Ys3[W-1] ? Xs3 - (Ys3 >>> 4) : Xs3 + (Ys3 >>> 4);
wire signed [W-1:0]  Ys4 = Ys3[W-1] ? Ys3 + (Xs3 >>> 4) : Ys3 - (Xs3 >>> 4);
wire signed [TW-1:0] Ts4 = Ys3[W-1] ? Ts3 - A4          : Ts3 + A4;

// -----------------------------------------------------------------------
// Pipeline register
// -----------------------------------------------------------------------
reg signed [W-1:0]  X_pipe, Y_pipe;
reg signed [TW-1:0] T_pipe;
reg                  v_pipe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        X_pipe <= 0; Y_pipe <= 0; T_pipe <= 0; v_pipe <= 1'b0;
    end else begin
        X_pipe <= Xs4; Y_pipe <= Ys4; T_pipe <= Ts4; v_pipe <= in_valid;
    end
end

// -----------------------------------------------------------------------
// Second half: stages 5..9 (combinational)
// -----------------------------------------------------------------------
wire signed [W-1:0]  Xs5 = Y_pipe[W-1] ? X_pipe - (Y_pipe >>> 5) : X_pipe + (Y_pipe >>> 5);
wire signed [W-1:0]  Ys5 = Y_pipe[W-1] ? Y_pipe + (X_pipe >>> 5) : Y_pipe - (X_pipe >>> 5);
wire signed [TW-1:0] Ts5 = Y_pipe[W-1] ? T_pipe - A5             : T_pipe + A5;

wire signed [W-1:0]  Xs6 = Ys5[W-1] ? Xs5 - (Ys5 >>> 6) : Xs5 + (Ys5 >>> 6);
wire signed [W-1:0]  Ys6 = Ys5[W-1] ? Ys5 + (Xs5 >>> 6) : Ys5 - (Xs5 >>> 6);
wire signed [TW-1:0] Ts6 = Ys5[W-1] ? Ts5 - A6          : Ts5 + A6;

wire signed [W-1:0]  Xs7 = Ys6[W-1] ? Xs6 - (Ys6 >>> 7) : Xs6 + (Ys6 >>> 7);
wire signed [W-1:0]  Ys7 = Ys6[W-1] ? Ys6 + (Xs6 >>> 7) : Ys6 - (Xs6 >>> 7);
wire signed [TW-1:0] Ts7 = Ys6[W-1] ? Ts6 - A7          : Ts6 + A7;

wire signed [W-1:0]  Xs8 = Ys7[W-1] ? Xs7 - (Ys7 >>> 8) : Xs7 + (Ys7 >>> 8);
wire signed [W-1:0]  Ys8 = Ys7[W-1] ? Ys7 + (Xs7 >>> 8) : Ys7 - (Xs7 >>> 8);
wire signed [TW-1:0] Ts8 = Ys7[W-1] ? Ts7 - A8          : Ts7 + A8;

wire signed [W-1:0]  Xs9 = Ys8[W-1] ? Xs8 - (Ys8 >>> 9) : Xs8 + (Ys8 >>> 9);
wire signed [W-1:0]  Ys9 = Ys8[W-1] ? Ys8 + (Xs8 >>> 9) : Ys8 - (Xs8 >>> 9);
wire signed [TW-1:0] Ts9 = Ys8[W-1] ? Ts8 - A9          : Ts8 + A9;

// -----------------------------------------------------------------------
// CSD scaling: outMag = Xs9 * A_N
//   A_N = 2^(-1) + 2^(-3) - 2^(-6) - 2^(-9)  (fw=9, rel_err=0.028%)
// -----------------------------------------------------------------------
wire signed [W+2:0] Xs9_ext = {{3{Xs9[W-1]}}, Xs9};
wire signed [W+2:0] mag_comb = (Xs9_ext >>> 1) + (Xs9_ext >>> 3)
                              - (Xs9_ext >>> 6) - (Xs9_ext >>> 9);

// -----------------------------------------------------------------------
// Output register
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        outTheta  <= 0;
        outMag    <= 0;
        out_valid <= 1'b0;
    end else begin
        outTheta  <= Ts9;
        outMag    <= mag_comb[W-1:0];
        out_valid <= v_pipe;
    end
end

endmodule
