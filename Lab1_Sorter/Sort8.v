module Sort8 (
    input signed [8:0] in1 , in2 , in3 , in4 , in5 , in6 , in7 , in8 ,
    output signed [8:0] out1 , out2 , out3 , out4 , out5 , out6 , out7 , out8
);

    wire signed [8:0] stage0 [7:0];
    wire signed [8:0] stage1 [7:0];
    wire signed [8:0] stage2 [7:0];
    wire signed [8:0] stage3 [7:0];
    wire signed [8:0] stage4 [7:0];
    wire signed [8:0] stage5 [7:0];


    // stage_0
    CAS cas0_0(in1, in2, stage0[0], stage0[1] );
    CAS cas0_1(in3, in4, stage0[3], stage0[2] );
    CAS cas0_2(in5, in6, stage0[4], stage0[5] );
    CAS cas0_3(in7, in8, stage0[7], stage0[6] );

    // stage_1
    CAS cas1_0(stage0[0], stage0[2], stage1[0], stage1[2] );
    CAS cas1_1(stage0[1], stage0[3], stage1[1], stage1[3] );
    CAS cas1_2(stage0[4], stage0[6], stage1[6], stage1[4] );
    CAS cas1_3(stage0[5], stage0[7], stage1[7], stage1[5] );

    // stage_2
    CAS cas2_0(stage1[0], stage1[1], stage2[0], stage2[1] );
    CAS cas2_1(stage1[2], stage1[3], stage2[2], stage2[3] );
    CAS cas2_2(stage1[4], stage1[5], stage2[5], stage2[4] );
    CAS cas2_3(stage1[6], stage1[7], stage2[7], stage2[6] );

    // stage_3
    CAS cas3_0(stage2[0], stage2[4], stage3[0], stage3[4] );
    CAS cas3_1(stage2[1], stage2[5], stage3[1], stage3[5] );
    CAS cas3_2(stage2[2], stage2[6], stage3[2], stage3[6] );
    CAS cas3_3(stage2[3], stage2[7], stage3[3], stage3[7] );

    // stage_4
    CAS cas4_0(stage3[0], stage3[2], stage4[0], stage4[2] );
    CAS cas4_1(stage3[1], stage3[3], stage4[1], stage4[3] );
    CAS cas4_2(stage3[4], stage3[6], stage4[4], stage4[6] );
    CAS cas4_3(stage3[5], stage3[7], stage4[5], stage4[7] );

    // stage_5
    CAS cas5_0(stage4[0], stage4[1], stage5[0], stage5[1] );
    CAS cas5_1(stage4[2], stage4[3], stage5[2], stage5[3] );
    CAS cas5_2(stage4[4], stage4[5], stage5[4], stage5[5] );
    CAS cas5_3(stage4[6], stage4[7], stage5[6], stage5[7] );

    // assign {out0, out1, out2, out3, out4, out5, out6, out7} = {stage5[0], stage5[1], stage5[2], stage5[3], stage5[4], stage5[5], stage5[6], stage5[7]};
    assign {out8, out7, out6, out5, out4, out3, out2, out1} = {stage5[0], stage5[1], stage5[2], stage5[3], stage5[4], stage5[5], stage5[6], stage5[7]};
endmodule


module CAS (
    input signed [8:0] a,b,
    output signed [8:0] min, max
);

    assign min = (a < b) ? a : b;
    assign max = (a < b) ? b : a;

endmodule