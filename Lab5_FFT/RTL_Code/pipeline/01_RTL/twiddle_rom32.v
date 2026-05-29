`timescale 1ns/1ps

module twiddle_rom32 #(
    parameter TWIDDLE_W = 11,
    parameter TWIDDLE_FRAC_W = 9
) (
    input  wire [3:0] phase,
    output wire signed [TWIDDLE_W-1:0] tw_re,
    output wire signed [TWIDDLE_W-1:0] tw_im
);
    wire [4:0] mirror_phase_ext = 5'd16 - {1'b0, phase};
    wire [3:0] mirror_phase = mirror_phase_ext[3:0];
    wire q1 = (phase <= 4'd8);

    assign tw_re = q1 ? scale_const(base_cos(phase)) : -scale_const(base_cos(mirror_phase));
    assign tw_im = q1 ? -scale_const(base_sin(phase)) : -scale_const(base_sin(mirror_phase));

    function automatic signed [31:0] base_cos;
        input [3:0] k;
        begin
            case (k)
                4'd0: base_cos = 32'sd262144;
                4'd1: base_cos = 32'sd257107;
                4'd2: base_cos = 32'sd242189;
                4'd3: base_cos = 32'sd217965;
                4'd4: base_cos = 32'sd185364;
                4'd5: base_cos = 32'sd145639;
                4'd6: base_cos = 32'sd100318;
                4'd7: base_cos = 32'sd51142;
                4'd8: base_cos = 32'sd0;
                default: base_cos = 32'sd0;
            endcase
        end
    endfunction

    function automatic signed [31:0] base_sin;
        input [3:0] k;
        begin
            case (k)
                4'd0: base_sin = 32'sd0;
                4'd1: base_sin = 32'sd51142;
                4'd2: base_sin = 32'sd100318;
                4'd3: base_sin = 32'sd145639;
                4'd4: base_sin = 32'sd185364;
                4'd5: base_sin = 32'sd217965;
                4'd6: base_sin = 32'sd242189;
                4'd7: base_sin = 32'sd257107;
                4'd8: base_sin = 32'sd262144;
                default: base_sin = 32'sd0;
            endcase
        end
    endfunction

    function automatic signed [TWIDDLE_W-1:0] scale_const;
        input signed [31:0] value;
        integer shift;
        reg signed [31:0] scaled;
        reg signed [31:0] mag;
        begin
            if (TWIDDLE_FRAC_W >= 18) begin
                shift = TWIDDLE_FRAC_W - 18;
                scaled = value <<< shift;
            end else if (value < 0) begin
                shift = 18 - TWIDDLE_FRAC_W;
                mag = -value;
                scaled = -(mag >>> shift);
            end else begin
                shift = 18 - TWIDDLE_FRAC_W;
                scaled = value >>> shift;
            end
            scale_const = scaled[TWIDDLE_W-1:0];
        end
    endfunction
endmodule

module twiddle_rom32_stage2 #(
    parameter TWIDDLE_W = 11,
    parameter TWIDDLE_FRAC_W = 9
) (
    input  wire [2:0] phase_idx,
    output reg signed [TWIDDLE_W-1:0] tw_re,
    output reg signed [TWIDDLE_W-1:0] tw_im
);
    always @* begin
        case (phase_idx)
            3'd0: begin
                tw_re = scale_const(32'sd262144);
                tw_im = scale_const(32'sd0);
            end
            3'd1: begin
                tw_re = scale_const(32'sd242189);
                tw_im = scale_const(-32'sd100318);
            end
            3'd2: begin
                tw_re = scale_const(32'sd185364);
                tw_im = scale_const(-32'sd185364);
            end
            3'd3: begin
                tw_re = scale_const(32'sd100318);
                tw_im = scale_const(-32'sd242189);
            end
            3'd4: begin
                tw_re = scale_const(32'sd0);
                tw_im = scale_const(-32'sd262144);
            end
            3'd5: begin
                tw_re = scale_const(-32'sd100318);
                tw_im = scale_const(-32'sd242189);
            end
            3'd6: begin
                tw_re = scale_const(-32'sd185364);
                tw_im = scale_const(-32'sd185364);
            end
            default: begin
                tw_re = scale_const(-32'sd242189);
                tw_im = scale_const(-32'sd100318);
            end
        endcase
    end

    function automatic signed [TWIDDLE_W-1:0] scale_const;
        input signed [31:0] value;
        integer shift;
        reg signed [31:0] scaled;
        reg signed [31:0] mag;
        begin
            if (TWIDDLE_FRAC_W >= 18) begin
                shift = TWIDDLE_FRAC_W - 18;
                scaled = value <<< shift;
            end else if (value < 0) begin
                shift = 18 - TWIDDLE_FRAC_W;
                mag = -value;
                scaled = -(mag >>> shift);
            end else begin
                shift = 18 - TWIDDLE_FRAC_W;
                scaled = value >>> shift;
            end
            scale_const = scaled[TWIDDLE_W-1:0];
        end
    endfunction
endmodule

module twiddle_rom32_stage3 #(
    parameter TWIDDLE_W = 11,
    parameter TWIDDLE_FRAC_W = 9
) (
    input  wire [1:0] phase_idx,
    output reg signed [TWIDDLE_W-1:0] tw_re,
    output reg signed [TWIDDLE_W-1:0] tw_im
);
    always @* begin
        case (phase_idx)
            2'd0: begin
                tw_re = scale_const(32'sd262144);
                tw_im = scale_const(32'sd0);
            end
            2'd1: begin
                tw_re = scale_const(32'sd185364);
                tw_im = scale_const(-32'sd185364);
            end
            2'd2: begin
                tw_re = scale_const(32'sd0);
                tw_im = scale_const(-32'sd262144);
            end
            default: begin
                tw_re = scale_const(-32'sd185364);
                tw_im = scale_const(-32'sd185364);
            end
        endcase
    end

    function automatic signed [TWIDDLE_W-1:0] scale_const;
        input signed [31:0] value;
        integer shift;
        reg signed [31:0] scaled;
        reg signed [31:0] mag;
        begin
            if (TWIDDLE_FRAC_W >= 18) begin
                shift = TWIDDLE_FRAC_W - 18;
                scaled = value <<< shift;
            end else if (value < 0) begin
                shift = 18 - TWIDDLE_FRAC_W;
                mag = -value;
                scaled = -(mag >>> shift);
            end else begin
                shift = 18 - TWIDDLE_FRAC_W;
                scaled = value >>> shift;
            end
            scale_const = scaled[TWIDDLE_W-1:0];
        end
    endfunction
endmodule
