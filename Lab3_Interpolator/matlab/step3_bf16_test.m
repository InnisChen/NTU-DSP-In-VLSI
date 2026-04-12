%% Step 3: BF16 Bit-True Model - 4 Test Cases
% DSP in VLSI Homework 3
%
% BF16 format: [S:1][E:8][F:7], bias = 127
% Simplifications: subnormals -> 0, truncation (no rounding), no NaN/Inf
%
% Operands are specified directly as binary strings (underscores optional).
% bf16_from_binstr() parses them; no manual decimal conversion needed.

clear; clc;

%% Helper: BF16 uint16 -> binary string "S/EEEE_EEEE/FFFF_FFF"
function str = bf16_binstr(x)
    x = uint16(x);
    S = double(bitshift(x, -15));
    E = double(bitand(bitshift(x, -7), uint16(255)));
    F = double(bitand(x, uint16(127)));
    e = dec2bin(E, 8);
    f = dec2bin(F, 7);
    str = sprintf('%d/%s_%s/%s_%s', S, e(1:4), e(5:8), f(1:4), f(5:7));
end

%% Define operands directly from the assignment binary strings
% Case (a) - Addition
a_op1 = bf16_from_binstr('1/1000_0011/0000_000');
a_op2 = bf16_from_binstr('0/1000_1011/0000_011');

% Case (b) - Addition  (near-subnormal boundary)
b_op1 = bf16_from_binstr('1/0000_0001/0000_011');
b_op2 = bf16_from_binstr('0/0000_0001/1111_010');

% Case (c) - Multiplication
c_op1 = bf16_from_binstr('1/0000_0010/1100_000');
c_op2 = bf16_from_binstr('0/0111_1100/0000_110');

% Case (d) - Multiplication
d_op1 = bf16_from_binstr('0/0110_0011/1011_110');
d_op2 = bf16_from_binstr('0/1001_0011/0101_000');

%% Run operations
a_res = bf16_add(a_op1, a_op2);
b_res = bf16_add(b_op1, b_op2);
c_res = bf16_mul(c_op1, c_op2);
d_res = bf16_mul(d_op1, d_op2);

op1_list = {a_op1, b_op1, c_op1, d_op1};
op2_list = {a_op2, b_op2, c_op2, d_op2};
res_list = {a_res, b_res, c_res, d_res};
op_names = {'Addition', 'Addition', 'Multiplication', 'Multiplication'};
case_ids = {'(a)', '(b)', '(c)', '(d)'};

%% Print results
fprintf('=== Step 3: BF16 Bit-True Test Cases ===\n\n');
for k = 1:4
    op1 = op1_list{k};
    op2 = op2_list{k};
    res = res_list{k};

    v1 = bf16_to_double(op1);
    v2 = bf16_to_double(op2);
    vr = bf16_to_double(res);

    fprintf('Case %s : %s\n', case_ids{k}, op_names{k});
    fprintf('  Op1 : %s  =  %+.6g\n', bf16_binstr(op1), v1);
    fprintf('  Op2 : %s  =  %+.6g\n', bf16_binstr(op2), v2);
    fprintf('  Res : %s  =  %+.6g\n', bf16_binstr(res), vr);
    fprintf('\n');
end
