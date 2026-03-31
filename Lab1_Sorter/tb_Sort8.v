`timescale 1ns/1ps

module tb_Sort8;

reg signed [8:0] in1,in2,in3,in4,in5,in6,in7,in8;

wire signed [8:0] out1,out2,out3,out4,out5,out6,out7,out8;

integer file;
integer r;
integer i;

reg signed [8:0] data_block [0:31];


// DUT
Sort8 uut(
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .in4(in4),
    .in5(in5),
    .in6(in6),
    .in7(in7),
    .in8(in8),
    .out1(out1),
    .out2(out2),
    .out3(out3),
    .out4(out4),
    .out5(out5),
    .out6(out6),
    .out7(out7),
    .out8(out8)
);

initial begin

// 開檔
file = $fopen("C:/Project/DSP in VLSI/HW1_sorting/input.txt","r");

if(file == 0) begin
    $display("ERROR: cannot open input.txt");
    $finish;
end


while(!$feof(file)) begin

    // 讀一行 32 numbers
    r = $fscanf(file,
    "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
    data_block[0],data_block[1],data_block[2],data_block[3],
    data_block[4],data_block[5],data_block[6],data_block[7],
    data_block[8],data_block[9],data_block[10],data_block[11],
    data_block[12],data_block[13],data_block[14],data_block[15],
    data_block[16],data_block[17],data_block[18],data_block[19],
    data_block[20],data_block[21],data_block[22],data_block[23],
    data_block[24],data_block[25],data_block[26],data_block[27],
    data_block[28],data_block[29],data_block[30],data_block[31]);


    // 分成4個cycle送進Sort8
    for(i=0;i<4;i=i+1) begin

        #9;

        in1 = data_block[i*8+0];
        in2 = data_block[i*8+1];
        in3 = data_block[i*8+2];
        in4 = data_block[i*8+3];
        in5 = data_block[i*8+4];
        in6 = data_block[i*8+5];
        in7 = data_block[i*8+6];
        in8 = data_block[i*8+7];

        #1;

        $display("INPUT : %d %d %d %d %d %d %d %d",
        in1,in2,in3,in4,in5,in6,in7,in8);

        $display("OUTPUT: %d %d %d %d %d %d %d %d\n",
        out1,out2,out3,out4,out5,out6,out7,out8);

    end

end

$fclose(file);

#10 $finish;

end

endmodule