`timescale 1ns/1ps

module cordic_pe #(
    parameter W = 26,
    parameter STAGES = 16
)(
    input                       Clk,
    input                       Reset,
    input                       start,
    input                       vectoring,
    input  signed [W-1:0]       x_in,
    input  signed [W-1:0]       y_in,
    input  [STAGES-1:0]         dirs_in,
    output reg                  done,
    output reg signed [W-1:0]   x_out,
    output reg signed [W-1:0]   y_out,
    output reg [STAGES-1:0]     dirs_out
);

localparam IDLE = 1'b0;
localparam RUN  = 1'b1;

reg                       state;
reg                       vectoring_r;
reg                       pre_neg_r;
reg [4:0]                 iter;
reg signed [W-1:0]        x_r;
reg signed [W-1:0]        y_r;
reg [STAGES-1:0]          dirs_r;

wire signed [W-1:0] x_shift = x_r >>> iter;
wire signed [W-1:0] y_shift = y_r >>> iter;
wire                dir_sel = vectoring_r ? y_r[W-1] : dirs_r[iter];

wire signed [W-1:0] x_next = (dir_sel == 1'b0) ? (x_r + y_shift) : (x_r - y_shift);
wire signed [W-1:0] y_next = (dir_sel == 1'b0) ? (y_r - x_shift) : (y_r + x_shift);

reg [STAGES-1:0] dirs_next;

always @(*) begin
    dirs_next = dirs_r;
    if (vectoring_r) begin
        dirs_next[iter] = dir_sel;
    end
end

function signed [W-1:0] gain_comp;
    input signed [W-1:0] value;
    reg signed [W+17:0] product;
    begin
        product = value * 18'sd39797;
        if (product[W+17]) begin
            gain_comp = (product - 18'sd32768) >>> 16;
        end else begin
            gain_comp = (product + 18'sd32768) >>> 16;
        end
    end
endfunction

always @(posedge Clk) begin
    if (Reset) begin
        state      <= IDLE;
        vectoring_r <= 1'b0;
        pre_neg_r <= 1'b0;
        iter       <= 5'd0;
        x_r        <= {W{1'b0}};
        y_r        <= {W{1'b0}};
        dirs_r     <= {STAGES{1'b0}};
        done       <= 1'b0;
        x_out      <= {W{1'b0}};
        y_out      <= {W{1'b0}};
        dirs_out   <= {STAGES{1'b0}};
    end else begin
        done <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    vectoring_r <= vectoring;
                    dirs_r      <= dirs_in;
                    iter        <= 5'd0;

                    if (vectoring && x_in[W-1]) begin
                        x_r       <= -x_in;
                        y_r       <= -y_in;
                        pre_neg_r <= 1'b1;
                    end else begin
                        x_r       <= x_in;
                        y_r       <= y_in;
                        pre_neg_r <= 1'b0;
                    end

                    state <= RUN;
                end
            end

            RUN: begin
                x_r <= x_next;
                y_r <= y_next;

                if (vectoring_r) begin
                    dirs_r[iter] <= dir_sel;
                end

                if (iter == STAGES - 1) begin
                    done     <= 1'b1;
                    dirs_out <= vectoring_r ? dirs_next : dirs_in;

                    if (vectoring_r && pre_neg_r) begin
                        x_out <= -gain_comp(x_next);
                        y_out <= -gain_comp(y_next);
                    end else begin
                        x_out <= gain_comp(x_next);
                        y_out <= gain_comp(y_next);
                    end

                    state <= IDLE;
                end else begin
                    iter <= iter + 5'd1;
                end
            end
        endcase
    end
end

endmodule
