`timescale 1ns/1ps

module FinalProject #(
    parameter WI = 17,
    parameter WO = 17,
    parameter FRAC_W = 12,
    parameter ACC_W = 27,
    parameter CORDIC_STAGES = 10,
    parameter ITER_MAX = 7
)(
    input Clk,
    input Reset,
    input InValid,
    input signed [WI-1:0] InData1,
    input signed [WI-1:0] InData2,
    input signed [WI-1:0] InData3,
    output reg OutValid,
    output reg signed [WO-1:0] OutData1,
    output reg signed [WO-1:0] OutData2,
    output reg signed [WO-1:0] OutData3
);

localparam signed [ACC_W-1:0] ONE_ACC = {{(ACC_W-FRAC_W-1){1'b0}}, 1'b1, {FRAC_W{1'b0}}};

localparam S_IDLE          = 4'd0;
localparam S_LOAD          = 4'd1;
localparam S_QR_VEC_START  = 4'd2;
localparam S_QR_VEC_WAIT   = 4'd3;
localparam S_QR_ROT_START  = 4'd4;
localparam S_QR_ROT_WAIT   = 4'd5;
localparam S_RQ_START      = 4'd6;
localparam S_RQ_WAIT       = 4'd7;
localparam S_U_START       = 4'd8;
localparam S_U_WAIT        = 4'd9;
localparam S_OUTPUT        = 4'd10;

reg [3:0] state;
reg [1:0] load_col;
reg [1:0] rot_idx;
reg [3:0] iter_count;
reg [2:0] out_count;

reg signed [ACC_W-1:0] mat [0:8];
reg signed [ACC_W-1:0] eig_u [0:8];
reg [CORDIC_STAGES-1:0] dirs [0:2];

wire signed [ACC_W-1:0] in1_acc = {{(ACC_W-WI){InData1[WI-1]}}, InData1};
wire signed [ACC_W-1:0] in2_acc = {{(ACC_W-WI){InData2[WI-1]}}, InData2};
wire signed [ACC_W-1:0] in3_acc = {{(ACC_W-WI){InData3[WI-1]}}, InData3};

reg signed [ACC_W-1:0] pe0_x;
reg signed [ACC_W-1:0] pe0_y;
reg signed [ACC_W-1:0] pe1_x;
reg signed [ACC_W-1:0] pe1_y;
reg signed [ACC_W-1:0] pe2_x;
reg signed [ACC_W-1:0] pe2_y;
reg [CORDIC_STAGES-1:0] pe_dirs;
reg pe_vectoring;

wire pe0_start = (state == S_QR_VEC_START) || (state == S_RQ_START) || (state == S_U_START);
wire pe1_start = (state == S_QR_ROT_START) || (state == S_RQ_START) || (state == S_U_START);
wire pe2_start = ((state == S_QR_ROT_START) && (rot_idx != 2'd2)) ||
                 (state == S_RQ_START) || (state == S_U_START);

wire pe0_done;
wire pe1_done;
wire pe2_done;
wire signed [ACC_W-1:0] pe0_x_out;
wire signed [ACC_W-1:0] pe0_y_out;
wire signed [ACC_W-1:0] pe1_x_out;
wire signed [ACC_W-1:0] pe1_y_out;
wire signed [ACC_W-1:0] pe2_x_out;
wire signed [ACC_W-1:0] pe2_y_out;
wire [CORDIC_STAGES-1:0] pe0_dirs_out;
wire [CORDIC_STAGES-1:0] pe1_dirs_out;
wire [CORDIC_STAGES-1:0] pe2_dirs_out;

cordic_pe #(.W(ACC_W), .STAGES(CORDIC_STAGES)) u_pe0 (
    .Clk(Clk),
    .Reset(Reset),
    .start(pe0_start),
    .vectoring(pe_vectoring),
    .x_in(pe0_x),
    .y_in(pe0_y),
    .dirs_in(pe_dirs),
    .done(pe0_done),
    .x_out(pe0_x_out),
    .y_out(pe0_y_out),
    .dirs_out(pe0_dirs_out)
);

cordic_pe #(.W(ACC_W), .STAGES(CORDIC_STAGES)) u_pe1 (
    .Clk(Clk),
    .Reset(Reset),
    .start(pe1_start),
    .vectoring(1'b0),
    .x_in(pe1_x),
    .y_in(pe1_y),
    .dirs_in(pe_dirs),
    .done(pe1_done),
    .x_out(pe1_x_out),
    .y_out(pe1_y_out),
    .dirs_out(pe1_dirs_out)
);

cordic_pe #(.W(ACC_W), .STAGES(CORDIC_STAGES)) u_pe2 (
    .Clk(Clk),
    .Reset(Reset),
    .start(pe2_start),
    .vectoring(1'b0),
    .x_in(pe2_x),
    .y_in(pe2_y),
    .dirs_in(pe_dirs),
    .done(pe2_done),
    .x_out(pe2_x_out),
    .y_out(pe2_y_out),
    .dirs_out(pe2_dirs_out)
);

function signed [WO-1:0] sat_out;
    input signed [ACC_W-1:0] value;
    reg signed [ACC_W-1:0] max_val;
    reg signed [ACC_W-1:0] min_val;
    begin
        max_val = {{(ACC_W-WO){1'b0}}, {1'b0, {(WO-1){1'b1}}}};
        min_val = {{(ACC_W-WO){1'b1}}, {1'b1, {(WO-1){1'b0}}}};

        if (value > max_val) begin
            sat_out = {1'b0, {(WO-1){1'b1}}};
        end else if (value < min_val) begin
            sat_out = {1'b1, {(WO-1){1'b0}}};
        end else begin
            sat_out = value[WO-1:0];
        end
    end
endfunction

integer i;

always @(*) begin
    pe0_x = {ACC_W{1'b0}};
    pe0_y = {ACC_W{1'b0}};
    pe1_x = {ACC_W{1'b0}};
    pe1_y = {ACC_W{1'b0}};
    pe2_x = {ACC_W{1'b0}};
    pe2_y = {ACC_W{1'b0}};
    pe_dirs = dirs[rot_idx];
    pe_vectoring = 1'b0;

    case (state)
        S_QR_VEC_START: begin
            pe_vectoring = 1'b1;
            case (rot_idx)
                2'd0: begin
                    pe0_x = mat[0]; pe0_y = mat[3];
                end
                2'd1: begin
                    pe0_x = mat[0]; pe0_y = mat[6];
                end
                default: begin
                    pe0_x = mat[4]; pe0_y = mat[7];
                end
            endcase
        end

        S_QR_ROT_START: begin
            case (rot_idx)
                2'd0: begin
                    pe1_x = mat[1]; pe1_y = mat[4];
                    pe2_x = mat[2]; pe2_y = mat[5];
                end
                2'd1: begin
                    pe1_x = mat[1]; pe1_y = mat[7];
                    pe2_x = mat[2]; pe2_y = mat[8];
                end
                default: begin
                    pe1_x = mat[5]; pe1_y = mat[8];
                end
            endcase
        end

        S_RQ_START: begin
            case (rot_idx)
                2'd0: begin
                    pe0_x = mat[0]; pe0_y = mat[1];
                    pe1_x = mat[3]; pe1_y = mat[4];
                    pe2_x = mat[6]; pe2_y = mat[7];
                end
                2'd1: begin
                    pe0_x = mat[0]; pe0_y = mat[2];
                    pe1_x = mat[3]; pe1_y = mat[5];
                    pe2_x = mat[6]; pe2_y = mat[8];
                end
                default: begin
                    pe0_x = mat[1]; pe0_y = mat[2];
                    pe1_x = mat[4]; pe1_y = mat[5];
                    pe2_x = mat[7]; pe2_y = mat[8];
                end
            endcase
        end

        S_U_START: begin
            case (rot_idx)
                2'd0: begin
                    pe0_x = eig_u[0]; pe0_y = eig_u[1];
                    pe1_x = eig_u[3]; pe1_y = eig_u[4];
                    pe2_x = eig_u[6]; pe2_y = eig_u[7];
                end
                2'd1: begin
                    pe0_x = eig_u[0]; pe0_y = eig_u[2];
                    pe1_x = eig_u[3]; pe1_y = eig_u[5];
                    pe2_x = eig_u[6]; pe2_y = eig_u[8];
                end
                default: begin
                    pe0_x = eig_u[1]; pe0_y = eig_u[2];
                    pe1_x = eig_u[4]; pe1_y = eig_u[5];
                    pe2_x = eig_u[7]; pe2_y = eig_u[8];
                end
            endcase
        end
    endcase
end

always @(posedge Clk) begin
    if (Reset) begin
        state      <= S_IDLE;
        load_col   <= 2'd0;
        rot_idx    <= 2'd0;
        iter_count <= 4'd0;
        out_count  <= 3'd0;
        OutValid   <= 1'b0;
        OutData1   <= {WO{1'b0}};
        OutData2   <= {WO{1'b0}};
        OutData3   <= {WO{1'b0}};

        for (i = 0; i < 9; i = i + 1) begin
            mat[i] <= {ACC_W{1'b0}};
            eig_u[i] <= {ACC_W{1'b0}};
        end

        for (i = 0; i < 3; i = i + 1) begin
            dirs[i] <= {CORDIC_STAGES{1'b0}};
        end
    end else begin
        OutValid <= 1'b0;

        case (state)
            S_IDLE: begin
                if (InValid) begin
                    for (i = 0; i < 9; i = i + 1) begin
                        mat[i] <= {ACC_W{1'b0}};
                        eig_u[i] <= {ACC_W{1'b0}};
                    end

                    mat[0] <= in1_acc;
                    mat[3] <= in2_acc;
                    mat[6] <= in3_acc;
                    eig_u[0] <= ONE_ACC;
                    eig_u[4] <= ONE_ACC;
                    eig_u[8] <= ONE_ACC;

                    load_col <= 2'd1;
                    state <= S_LOAD;
                end
            end

            S_LOAD: begin
                if (InValid) begin
                    case (load_col)
                        2'd1: begin
                            mat[1] <= in1_acc;
                            mat[4] <= in2_acc;
                            mat[7] <= in3_acc;
                            load_col <= 2'd2;
                        end
                        default: begin
                            mat[2] <= in1_acc;
                            mat[5] <= in2_acc;
                            mat[8] <= in3_acc;
                            iter_count <= 4'd0;
                            rot_idx <= 2'd0;
                            state <= S_QR_VEC_START;
                        end
                    endcase
                end
            end

            S_QR_VEC_START: begin
                state <= S_QR_VEC_WAIT;
            end

            S_QR_VEC_WAIT: begin
                if (pe0_done) begin
                    dirs[rot_idx] <= pe0_dirs_out;

                    case (rot_idx)
                        2'd0: begin
                            mat[0] <= pe0_x_out;
                            mat[3] <= {ACC_W{1'b0}};
                        end
                        2'd1: begin
                            mat[0] <= pe0_x_out;
                            mat[6] <= {ACC_W{1'b0}};
                        end
                        default: begin
                            mat[4] <= pe0_x_out;
                            mat[7] <= {ACC_W{1'b0}};
                        end
                    endcase

                    state <= S_QR_ROT_START;
                end
            end

            S_QR_ROT_START: begin
                state <= S_QR_ROT_WAIT;
            end

            S_QR_ROT_WAIT: begin
                if ((rot_idx == 2'd2 && pe1_done) ||
                    (rot_idx != 2'd2 && pe1_done && pe2_done)) begin
                    case (rot_idx)
                        2'd0: begin
                            mat[1] <= pe1_x_out; mat[4] <= pe1_y_out;
                            mat[2] <= pe2_x_out; mat[5] <= pe2_y_out;
                        end
                        2'd1: begin
                            mat[1] <= pe1_x_out; mat[7] <= pe1_y_out;
                            mat[2] <= pe2_x_out; mat[8] <= pe2_y_out;
                        end
                        default: begin
                            mat[5] <= pe1_x_out; mat[8] <= pe1_y_out;
                        end
                    endcase

                    if (rot_idx == 2'd2) begin
                        rot_idx <= 2'd0;
                        state <= S_RQ_START;
                    end else begin
                        rot_idx <= rot_idx + 2'd1;
                        state <= S_QR_VEC_START;
                    end
                end
            end

            S_RQ_START: begin
                state <= S_RQ_WAIT;
            end

            S_RQ_WAIT: begin
                if (pe0_done && pe1_done && pe2_done) begin
                    case (rot_idx)
                        2'd0: begin
                            mat[0] <= pe0_x_out; mat[1] <= pe0_y_out;
                            mat[3] <= pe1_x_out; mat[4] <= pe1_y_out;
                            mat[6] <= pe2_x_out; mat[7] <= pe2_y_out;
                        end
                        2'd1: begin
                            mat[0] <= pe0_x_out; mat[2] <= pe0_y_out;
                            mat[3] <= pe1_x_out; mat[5] <= pe1_y_out;
                            mat[6] <= pe2_x_out; mat[8] <= pe2_y_out;
                        end
                        default: begin
                            mat[1] <= pe0_x_out; mat[2] <= pe0_y_out;
                            mat[4] <= pe1_x_out; mat[5] <= pe1_y_out;
                            mat[7] <= pe2_x_out; mat[8] <= pe2_y_out;
                        end
                    endcase

                    state <= S_U_START;
                end
            end

            S_U_START: begin
                state <= S_U_WAIT;
            end

            S_U_WAIT: begin
                if (pe0_done && pe1_done && pe2_done) begin
                    case (rot_idx)
                        2'd0: begin
                            eig_u[0] <= pe0_x_out; eig_u[1] <= pe0_y_out;
                            eig_u[3] <= pe1_x_out; eig_u[4] <= pe1_y_out;
                            eig_u[6] <= pe2_x_out; eig_u[7] <= pe2_y_out;
                        end
                        2'd1: begin
                            eig_u[0] <= pe0_x_out; eig_u[2] <= pe0_y_out;
                            eig_u[3] <= pe1_x_out; eig_u[5] <= pe1_y_out;
                            eig_u[6] <= pe2_x_out; eig_u[8] <= pe2_y_out;
                        end
                        default: begin
                            eig_u[1] <= pe0_x_out; eig_u[2] <= pe0_y_out;
                            eig_u[4] <= pe1_x_out; eig_u[5] <= pe1_y_out;
                            eig_u[7] <= pe2_x_out; eig_u[8] <= pe2_y_out;
                        end
                    endcase

                    if (rot_idx == 2'd2) begin
                        if (iter_count == ITER_MAX - 1) begin
                            out_count <= 3'd0;
                            state <= S_OUTPUT;
                        end else begin
                            iter_count <= iter_count + 4'd1;
                            rot_idx <= 2'd0;
                            state <= S_QR_VEC_START;
                        end
                    end else begin
                        rot_idx <= rot_idx + 2'd1;
                        state <= S_RQ_START;
                    end
                end
            end

            S_OUTPUT: begin
                OutValid <= 1'b1;

                case (out_count)
                    3'd0: begin
                        OutData1 <= sat_out(mat[0]);
                        OutData2 <= sat_out(mat[4]);
                        OutData3 <= sat_out(mat[8]);
                    end
                    3'd1: begin
                        OutData1 <= sat_out(eig_u[0]);
                        OutData2 <= sat_out(eig_u[1]);
                        OutData3 <= sat_out(eig_u[2]);
                    end
                    3'd2: begin
                        OutData1 <= sat_out(eig_u[3]);
                        OutData2 <= sat_out(eig_u[4]);
                        OutData3 <= sat_out(eig_u[5]);
                    end
                    default: begin
                        OutData1 <= sat_out(eig_u[6]);
                        OutData2 <= sat_out(eig_u[7]);
                        OutData3 <= sat_out(eig_u[8]);
                    end
                endcase

                if (out_count == 3'd3) begin
                    state <= S_IDLE;
                    out_count <= 3'd0;
                end else begin
                    out_count <= out_count + 3'd1;
                end
            end
        endcase
    end
end

endmodule
