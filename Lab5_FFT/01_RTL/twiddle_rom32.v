`timescale 1ns/1ps

module twiddle_rom32 #(
    parameter DATA_W = 24,
    parameter FRAC_W = 16
) (
    input  wire [3:0] phase,
    output wire signed [DATA_W-1:0] tw_re,
    output wire signed [DATA_W-1:0] tw_im
);
    wire [4:0] mirror_phase_ext = 5'd16 - {1'b0, phase};
    wire [3:0] mirror_phase = mirror_phase_ext[3:0];
    wire q1 = (phase <= 4'd8);

    assign tw_re = q1 ? scale_const(base_cos(phase)) : -scale_const(base_cos(mirror_phase));
    assign tw_im = q1 ? -scale_const(base_sin(phase)) : -scale_const(base_sin(mirror_phase));

    function signed [31:0] base_cos;
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

    function signed [31:0] base_sin;
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

    function signed [DATA_W-1:0] scale_const;
        input signed [31:0] value;
        integer shift;
        reg signed [31:0] scaled;
        begin
            if (FRAC_W >= 18) begin
                shift = FRAC_W - 18;
                scaled = value <<< shift;
            end else begin
                shift = 18 - FRAC_W;
                scaled = value >>> shift;
            end
            scale_const = scaled[DATA_W-1:0];
        end
    endfunction
endmodule
