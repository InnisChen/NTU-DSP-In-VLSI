module SelectTopK (
    input clk, rst,
    input BlkIn,
    input signed [8:0] in1 , in2 , in3 , in4 , in5 , in6 , in7 , in8 ,
    output signed [8:0] sortout,
    output [1:0] outbank
);
    reg signed [8:0] block_0 [3:0]; // [2:0][3:0]
    reg signed [8:0] block_1 [3:0];
    reg signed [8:0] block_2 [3:0];

    reg signed [8:0] block2_0 [3:0];
    reg signed [8:0] block2_1 [3:0];
    reg signed [8:0] block2_2 [3:0];
    reg signed [8:0] block2_3 [3:0];

    wire [8:0] sort8out [3:0];

    reg [1:0] ptr [3:0];

    Sort8 Sort8_1(
    .in1(in1), .in2(in2), .in3(in3), .in4(in4), .in5(in5), .in6(in6), .in7(in7), .in8(in8),
    .out1(sort8out[0]), .out2(sort8out[1]), .out3(sort8out[2]), .out4(sort8out[3]), .out5(), .out6(), .out7(), .out8()
);
 
    reg [1:0] cnt;

    always @(posedge clk , posedge rst) begin
        if (rst) begin
            cnt <= 0;
        end 
        else begin
            if(BlkIn) cnt <= 1;
            else cnt <= cnt + 1;
        end
    end

    always @(posedge clk) begin
        case (cnt)
            0: begin
                block_0[0] <= sort8out[0];
                block_0[1] <= sort8out[1];
                block_0[2] <= sort8out[2];
                block_0[3] <= sort8out[3];
            end
            1: begin
                block_1[0] <= sort8out[0];
                block_1[1] <= sort8out[1];
                block_1[2] <= sort8out[2];
                block_1[3] <= sort8out[3];
            end
            2: begin
                block_2[0] <= sort8out[0];
                block_2[1] <= sort8out[1];
                block_2[2] <= sort8out[2];
                block_2[3] <= sort8out[3];
            end
        endcase
    end

    integer i;
    
    always @(posedge clk) begin
        if(cnt == 3) begin
            for(i=0;i<8;i=i+1) begin
                block2_0[i] <= block_0[i];
                block2_1[i] <= block_1[i];
                block2_2[i] <= block_2[i];
                block2_3[i] <= sort8out[i];
            end
        end
    end

    wire out_group1 [1:0];
    wire out_group2; 
    wire signed [8:0] max_stage1 [1:0];
    wire signed [8:0] max_stage2;


    Comparator comparator_1(block2_0[ptr[0]] , block2_1[ptr[1]] ,  max_stage1[0] , out_group1[0]);
    Comparator comparator_2(block2_2[ptr[2]] , block2_3[ptr[3]] ,  max_stage1[1] , out_group1[1]);

    Comparator comparator_3(max_stage1[0] , max_stage1[1] , max_stage2 , out_group2);

    wire [1:0] update_ptr_new;
    assign update_ptr_new = out_group2 ? (out_group1[1] ? ptr[3] : ptr[2]) : (out_group1[0] ? ptr[1] : ptr[0]) + 1;
    wire [1:0] win_group;
    assign win_group = out_group2 ? (out_group1[1] ? 2'b11 : 2'b10) : (out_group1[0] ? 2'b01 : 2'b00);

    always @(posedge clk) begin
        if(cnt == 3) begin
            ptr[0] <= 0;
            ptr[1] <= 0;
            ptr[2] <= 0;
            ptr[3] <= 0;
        end
        else ptr[win_group] <= ptr[win_group] + 1;
    end

    assign sortout = max_stage2;
    assign outbank = cnt;


endmodule


module Comparator (
    input signed [8:0] a , b,
    output signed [8:0] max , 
    output out_group
);

    assign max = (a > b) ? a : b;
    assign out_group = (a > b) ? 0 : 1;
endmodule