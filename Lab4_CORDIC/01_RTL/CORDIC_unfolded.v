`timescale 1ns/1ps

// Step 7: S/2-Unfolded CORDIC - arctangent only
// Parameters: W=14 (1S+1I+12F), TW=13 (1S+2I+10F), S=12
// Architecture: Initial Stage -> Stage 0..5 (comb) -> [Pipeline FF] -> Stage 6..11 (comb) -> [Output FF]
// Latency: 2 clock cycles, Throughput: 1 input per 2 clock cycles

module CORDIC_unfolded #(
    parameter W  = 14,
    parameter TW = 13,
    parameter S  = 12
)(
    input                       clk,
    input                       rst_n,
    input  signed [W-1:0]      inX,
    input  signed [W-1:0]      inY,
    input                       in_valid,
    output reg signed [TW-1:0] outTheta,
    output reg                  out_valid
);

localparam signed [TW-1:0] PI_POS =  13'sd3217;   // round(pi * 2^10)
localparam signed [TW-1:0] PI_NEG = -13'sd3217;

// Elementary angles: round(atan(2^-i) * 2^10), zero-extended to TW bits (positive values)
localparam signed [TW-1:0] A0  = 13'd804;
localparam signed [TW-1:0] A1  = 13'd475;
localparam signed [TW-1:0] A2  = 13'd251;
localparam signed [TW-1:0] A3  = 13'd127;
localparam signed [TW-1:0] A4  = 13'd64;
localparam signed [TW-1:0] A5  = 13'd32;
localparam signed [TW-1:0] A6  = 13'd16;
localparam signed [TW-1:0] A7  = 13'd8;
localparam signed [TW-1:0] A8  = 13'd4;
localparam signed [TW-1:0] A9  = 13'd2;
localparam signed [TW-1:0] A10 = 13'd1;
localparam signed [TW-1:0] A11 = 13'd0;

// -----------------------------------------------------------------------
// input DFF
// -----------------------------------------------------------------------
reg signed [W-1:0]  X_indff, Y_indff;
reg                  v_indff;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        X_indff <= 0;
        Y_indff <= 0;
        v_indff <= 1'b0;
    end else begin
        X_indff <= inX;
        Y_indff <= inY;
        v_indff <= in_valid;
    end
end

// -----------------------------------------------------------------------
// Initial stage: quadrant mapping (combinational)
//   Q1/Q4 (X>=0): pass through, theta_init = 0
//   Q2    (X<0, Y>=0): negate both, theta_init = +pi
//   Q3    (X<0, Y<0):  negate both, theta_init = -pi
// -----------------------------------------------------------------------
wire signed [W-1:0]  X_init = X_indff[W-1] ? -X_indff : X_indff;
wire signed [W-1:0]  Y_init = X_indff[W-1] ? -Y_indff : Y_indff;
wire signed [TW-1:0] T_init = X_indff[W-1] ? (Y_indff[W-1] ? PI_NEG : PI_POS) : {TW{1'b0}};

// -----------------------------------------------------------------------
// First half: stages 0..5 (combinational)
// Rule: Y>=0 (Y[W-1]=0): X+=Y_sh, Y-=X_sh, T+=A_i
//       Y<0  (Y[W-1]=1): X-=Y_sh, Y+=X_sh, T-=A_i
// -----------------------------------------------------------------------
// Stage 0 (shift=0)
wire signed [W-1:0]  Xs0 = Y_init[W-1] ? X_init - Y_init       : X_init + Y_init;
wire signed [W-1:0]  Ys0 = Y_init[W-1] ? Y_init + X_init       : Y_init - X_init;
wire signed [TW-1:0] Ts0 = Y_init[W-1] ? T_init - A0           : T_init + A0;

// Stage 1 (shift=1)
wire signed [W-1:0]  Xs1 = Ys0[W-1] ? Xs0 - (Ys0 >>> 1) : Xs0 + (Ys0 >>> 1);
wire signed [W-1:0]  Ys1 = Ys0[W-1] ? Ys0 + (Xs0 >>> 1) : Ys0 - (Xs0 >>> 1);
wire signed [TW-1:0] Ts1 = Ys0[W-1] ? Ts0 - A1          : Ts0 + A1;

// Stage 2 (shift=2)
wire signed [W-1:0]  Xs2 = Ys1[W-1] ? Xs1 - (Ys1 >>> 2) : Xs1 + (Ys1 >>> 2);
wire signed [W-1:0]  Ys2 = Ys1[W-1] ? Ys1 + (Xs1 >>> 2) : Ys1 - (Xs1 >>> 2);
wire signed [TW-1:0] Ts2 = Ys1[W-1] ? Ts1 - A2          : Ts1 + A2;

// Stage 3 (shift=3)
wire signed [W-1:0]  Xs3 = Ys2[W-1] ? Xs2 - (Ys2 >>> 3) : Xs2 + (Ys2 >>> 3);
wire signed [W-1:0]  Ys3 = Ys2[W-1] ? Ys2 + (Xs2 >>> 3) : Ys2 - (Xs2 >>> 3);
wire signed [TW-1:0] Ts3 = Ys2[W-1] ? Ts2 - A3          : Ts2 + A3;

// Stage 4 (shift=4)
wire signed [W-1:0]  Xs4 = Ys3[W-1] ? Xs3 - (Ys3 >>> 4) : Xs3 + (Ys3 >>> 4);
wire signed [W-1:0]  Ys4 = Ys3[W-1] ? Ys3 + (Xs3 >>> 4) : Ys3 - (Xs3 >>> 4);
wire signed [TW-1:0] Ts4 = Ys3[W-1] ? Ts3 - A4          : Ts3 + A4;

// Stage 5 (shift=5)
wire signed [W-1:0]  Xs5 = Ys4[W-1] ? Xs4 - (Ys4 >>> 5) : Xs4 + (Ys4 >>> 5);
wire signed [W-1:0]  Ys5 = Ys4[W-1] ? Ys4 + (Xs4 >>> 5) : Ys4 - (Xs4 >>> 5);
wire signed [TW-1:0] Ts5 = Ys4[W-1] ? Ts4 - A5          : Ts4 + A5;

// -----------------------------------------------------------------------
// Pipeline register (between first and second half)
// -----------------------------------------------------------------------
reg signed [W-1:0]  X_pipe, Y_pipe;
reg signed [TW-1:0] T_pipe;
reg                  v_pipe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        X_pipe <= 0;
        Y_pipe <= 0;
        T_pipe <= 0;
        v_pipe <= 1'b0;
    end else begin
        X_pipe <= Xs5;
        Y_pipe <= Ys5;
        T_pipe <= Ts5;
        v_pipe <= v_indff;
    end
end

// -----------------------------------------------------------------------
// Second half: stages 6..11 (combinational, from pipeline register outputs)
// -----------------------------------------------------------------------
// Stage 6 (shift=6)
wire signed [W-1:0]  Xs6  = Y_pipe[W-1] ? X_pipe - (Y_pipe >>> 6)  : X_pipe + (Y_pipe >>> 6);
wire signed [W-1:0]  Ys6  = Y_pipe[W-1] ? Y_pipe + (X_pipe >>> 6)  : Y_pipe - (X_pipe >>> 6);
wire signed [TW-1:0] Ts6  = Y_pipe[W-1] ? T_pipe - A6              : T_pipe + A6;

// Stage 7 (shift=7)
wire signed [W-1:0]  Xs7  = Ys6[W-1] ? Xs6 - (Ys6 >>> 7) : Xs6 + (Ys6 >>> 7);
wire signed [W-1:0]  Ys7  = Ys6[W-1] ? Ys6 + (Xs6 >>> 7) : Ys6 - (Xs6 >>> 7);
wire signed [TW-1:0] Ts7  = Ys6[W-1] ? Ts6 - A7          : Ts6 + A7;

// Stage 8 (shift=8)
wire signed [W-1:0]  Xs8  = Ys7[W-1] ? Xs7 - (Ys7 >>> 8) : Xs7 + (Ys7 >>> 8);
wire signed [W-1:0]  Ys8  = Ys7[W-1] ? Ys7 + (Xs7 >>> 8) : Ys7 - (Xs7 >>> 8);
wire signed [TW-1:0] Ts8  = Ys7[W-1] ? Ts7 - A8          : Ts7 + A8;

// Stage 9 (shift=9)
wire signed [W-1:0]  Xs9  = Ys8[W-1] ? Xs8 - (Ys8 >>> 9) : Xs8 + (Ys8 >>> 9);
wire signed [W-1:0]  Ys9  = Ys8[W-1] ? Ys8 + (Xs8 >>> 9) : Ys8 - (Xs8 >>> 9);
wire signed [TW-1:0] Ts9  = Ys8[W-1] ? Ts8 - A9          : Ts8 + A9;

// Stage 10 (shift=10)
wire signed [W-1:0]  Xs10 = Ys9[W-1]  ? Xs9  - (Ys9  >>> 10) : Xs9  + (Ys9  >>> 10);
wire signed [W-1:0]  Ys10 = Ys9[W-1]  ? Ys9  + (Xs9  >>> 10) : Ys9  - (Xs9  >>> 10);
wire signed [TW-1:0] Ts10 = Ys9[W-1]  ? Ts9  - A10           : Ts9  + A10;

// Stage 11 (shift=11): A11=0, so theta does not change
wire signed [TW-1:0] Ts11 = Ts10;

// -----------------------------------------------------------------------
// Output register
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        outTheta  <= 0;
        out_valid <= 1'b0;
    end else begin
        outTheta  <= Ts11;
        out_valid <= v_pipe;
    end
end

endmodule
