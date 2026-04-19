`timescale 1ns/1ps

// Step 6: Iterative CORDIC - arctangent only
// Parameters: w=9, S=10, aw=8
//   X/Y  : 1S + 1I + 9F = 11 bits  (scale 2^9 = 512)
//   theta: 1S + 2I + 8F = 11 bits  (scale 2^8 = 256)
//
// FSM: IDLE -> ITERATE (S cycles) -> DONE
// Latency: S+1 cycles after in_valid

module CORDIC #(
    parameter W  = 11,   // X/Y word-length  : 1S+1I+9F
    parameter TW = 11,   // theta word-length : 1S+2I+8F
    parameter S  = 10    // micro-rotations
)(
    input                       clk,
    input                       rst_n,
    input  signed [W-1:0]      inX,
    input  signed [W-1:0]      inY,
    input                       in_valid,
    output reg signed [TW-1:0] outTheta,
    output reg                  out_valid
);

// -----------------------------------------------------------------------
// Input DFF
// -----------------------------------------------------------------------
reg signed [W-1:0] X_indff, Y_indff;
reg                 v_indff;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        X_indff <= 0; Y_indff <= 0; v_indff <= 1'b0;
    end else begin
        X_indff <= inX; Y_indff <= inY; v_indff <= in_valid;
    end
end

// -----------------------------------------------------------------------
// LUT: round(atan(2^-i) * 2^8) for i = 0..9  (unsigned, all positive)
// -----------------------------------------------------------------------
reg [7:0] lut_val;
always @(*) begin
    case (iter)
        4'd0: lut_val = 8'd201;   // atan(2^0)  * 256 = 201
        4'd1: lut_val = 8'd119;   // atan(2^-1) * 256 = 119
        4'd2: lut_val = 8'd63;    // atan(2^-2) * 256 = 63
        4'd3: lut_val = 8'd32;    // atan(2^-3) * 256 = 32
        4'd4: lut_val = 8'd16;    // atan(2^-4) * 256 = 16
        4'd5: lut_val = 8'd8;     // atan(2^-5) * 256 = 8
        4'd6: lut_val = 8'd4;     // atan(2^-6) * 256 = 4
        4'd7: lut_val = 8'd2;     // atan(2^-7) * 256 = 2
        4'd8: lut_val = 8'd1;     // atan(2^-8) * 256 = 1
        4'd9: lut_val = 8'd0;     // atan(2^-9) * 256 = 0 (rounds to 0)
        default: lut_val = 8'd0;
    endcase
end

// Zero-extend unsigned LUT value to theta word-length for accumulation
wire signed [TW-1:0] lut_ext = {{(TW-8){1'b0}}, lut_val};

// pi in 1S+2I+8F: round(pi * 2^8) = 804
localparam signed [TW-1:0] PI_POS =  11'sd804;
localparam signed [TW-1:0] PI_NEG = -11'sd804;

// -----------------------------------------------------------------------
// FSM
// -----------------------------------------------------------------------
localparam IDLE    = 2'd0;
localparam ITERATE = 2'd1;
localparam DONE    = 2'd2;

reg [1:0] state;
reg [3:0] iter;   // iteration index 0..S-1

// Datapath registers
reg signed [W-1:0]  X_r, Y_r;
reg signed [TW-1:0] th_r;

// Combinational micro-rotation inputs (based on current X_r, Y_r, iter)
wire signed [W-1:0]  X_sh = X_r >>> iter;   // arithmetic right shift by i
wire signed [W-1:0]  Y_sh = Y_r >>> iter;
wire                  Y_neg = Y_r[W-1];       // 1 if Y < 0

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= IDLE;
        iter      <= 4'd0;
        X_r       <= 0;
        Y_r       <= 0;
        th_r      <= 0;
        outTheta  <= 0;
        out_valid <= 1'b0;
    end else begin
        out_valid <= 1'b0;   // default: deassert each cycle

        case (state)
            // ----------------------------------------------------------
            IDLE: begin
                if (v_indff) begin
                    // Initial stage: map Q2/Q3 inputs to Q1/Q4
                    if (X_indff[W-1]) begin
                        // X < 0: reflect (X,Y) -> (-X,-Y), offset theta by +/-pi
                        X_r  <= -X_indff;
                        Y_r  <= -Y_indff;
                        th_r <= Y_indff[W-1] ? PI_NEG : PI_POS;
                    end else begin
                        X_r  <= X_indff;
                        Y_r  <= Y_indff;
                        th_r <= {TW{1'b0}};
                    end
                    iter  <= 4'd0;
                    state <= ITERATE;
                end
            end

            // ----------------------------------------------------------
            ITERATE: begin
                // Direction: mu = -sign(Y)
                //   Y >= 0 (Y_neg=0): mu=-1, rotate clockwise
                //   Y <  0 (Y_neg=1): mu=+1, rotate counter-clockwise
                if (!Y_neg) begin
                    X_r  <= X_r + Y_sh;
                    Y_r  <= Y_r - X_sh;
                    th_r <= th_r + lut_ext;
                end else begin
                    X_r  <= X_r - Y_sh;
                    Y_r  <= Y_r + X_sh;
                    th_r <= th_r - lut_ext;
                end

                if (iter == S - 1) begin
                    state <= DONE;
                end else begin
                    iter <= iter + 4'd1;
                end
            end

            // ----------------------------------------------------------
            DONE: begin
                outTheta  <= th_r;
                out_valid <= 1'b1;
                state     <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
