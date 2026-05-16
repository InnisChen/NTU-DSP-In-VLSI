`timescale 1ns/1ps

module bit_reverse_buffer #(
    parameter DATA_W = 24
) (
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [DATA_W-1:0] SDFOutRe,
    input  wire signed [DATA_W-1:0] SDFOutIm,

    output wire br_valid_out,
    output wire signed [DATA_W-1:0] BROutRe,
    output wire signed [DATA_W-1:0] BROutIm,
    output wire [4:0] br_out_idx,

    output wire wr_bank,
    output wire rd_bank,
    output wire [4:0] wr_addr,
    output wire [4:0] rd_addr
);
    reg signed [DATA_W-1:0] bank0_re [0:31];
    reg signed [DATA_W-1:0] bank0_im [0:31];
    reg signed [DATA_W-1:0] bank1_re [0:31];
    reg signed [DATA_W-1:0] bank1_im [0:31];

    reg wr_bank_r;
    reg rd_bank_r;
    reg [4:0] wr_count;
    reg [4:0] rd_count;
    reg bank0_ready;
    reg bank1_ready;
    reg reading;

    reg br_valid_out_r;
    reg signed [DATA_W-1:0] BROutRe_r;
    reg signed [DATA_W-1:0] BROutIm_r;

    wire [4:0] wr_addr_w = bit_reverse5(wr_count);
    wire write_done = valid_in && (wr_count == 5'd31);
    wire other_ready = rd_bank_r ? bank0_ready : bank1_ready;

    assign br_valid_out = br_valid_out_r;
    assign BROutRe = BROutRe_r;
    assign BROutIm = BROutIm_r;
    assign br_out_idx = rd_count;
    assign wr_bank = wr_bank_r;
    assign rd_bank = rd_bank_r;
    assign wr_addr = wr_addr_w;
    assign rd_addr = rd_count;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bank_r <= 1'b0;
            rd_bank_r <= 1'b0;
            wr_count <= 5'd0;
            rd_count <= 5'd0;
            bank0_ready <= 1'b0;
            bank1_ready <= 1'b0;
            reading <= 1'b0;
            br_valid_out_r <= 1'b0;
            BROutRe_r <= {DATA_W{1'b0}};
            BROutIm_r <= {DATA_W{1'b0}};
            for (i = 0; i < 32; i = i + 1) begin
                bank0_re[i] <= {DATA_W{1'b0}};
                bank0_im[i] <= {DATA_W{1'b0}};
                bank1_re[i] <= {DATA_W{1'b0}};
                bank1_im[i] <= {DATA_W{1'b0}};
            end
        end else begin
            br_valid_out_r <= 1'b0;

            if (valid_in) begin
                if (wr_bank_r == 1'b0) begin
                    bank0_re[wr_addr_w] <= SDFOutRe;
                    bank0_im[wr_addr_w] <= SDFOutIm;
                end else begin
                    bank1_re[wr_addr_w] <= SDFOutRe;
                    bank1_im[wr_addr_w] <= SDFOutIm;
                end

                if (write_done) begin
                    if (wr_bank_r == 1'b0) begin
                        bank0_ready <= 1'b1;
                    end else begin
                        bank1_ready <= 1'b1;
                    end
                    wr_bank_r <= ~wr_bank_r;
                    wr_count <= 5'd0;
                end else begin
                    wr_count <= wr_count + 5'd1;
                end
            end

            if (reading) begin
                br_valid_out_r <= 1'b1;
                if (rd_bank_r == 1'b0) begin
                    BROutRe_r <= bank0_re[rd_count];
                    BROutIm_r <= bank0_im[rd_count];
                end else begin
                    BROutRe_r <= bank1_re[rd_count];
                    BROutIm_r <= bank1_im[rd_count];
                end

                if (rd_count == 5'd31) begin
                    if (rd_bank_r == 1'b0) begin
                        bank0_ready <= 1'b0;
                    end else begin
                        bank1_ready <= 1'b0;
                    end

                    if (other_ready || (write_done && (wr_bank_r != rd_bank_r))) begin
                        rd_bank_r <= ~rd_bank_r;
                        rd_count <= 5'd0;
                        reading <= 1'b1;
                    end else begin
                        rd_count <= 5'd0;
                        reading <= 1'b0;
                    end
                end else begin
                    rd_count <= rd_count + 5'd1;
                end
            end else begin
                if (bank0_ready) begin
                    rd_bank_r <= 1'b0;
                    rd_count <= 5'd0;
                    reading <= 1'b1;
                end else if (bank1_ready) begin
                    rd_bank_r <= 1'b1;
                    rd_count <= 5'd0;
                    reading <= 1'b1;
                end else if (write_done) begin
                    rd_bank_r <= wr_bank_r;
                    rd_count <= 5'd0;
                    reading <= 1'b1;
                end
            end
        end
    end

    function automatic [4:0] bit_reverse5;
        input [4:0] value;
        begin
            bit_reverse5 = {value[0], value[1], value[2], value[3], value[4]};
        end
    endfunction
endmodule
