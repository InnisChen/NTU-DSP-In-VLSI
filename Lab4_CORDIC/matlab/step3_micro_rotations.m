%% Step 3: Determine Number of Micro-Rotations S and Angle Word-Length aw
% DSP in VLSI Lab 4 - CORDIC
% Student parameters: I=7, beta=2
%
% Inputs are quantized with w from Step 2 (loaded from step2_result.mat).
% Part A: sweep N = 1..20 to find minimum N meeting threshold,
%         then round up to even S for Step 7 S/2-unfolding.
% Part B: sweep aw = 4..20 with fixed S from Part A
%         to determine angle word-length.
% Metric: average |phase_error| over 10 quantized inputs.
% Goal:   both S and aw such that avg error < 2^(-9).

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Load w from Step 2
mat_path = fullfile(fileparts(mfilename('fullpath')), 'step2_result.mat');
load(mat_path, 'w_min');
w = w_min;
fprintf('=== Step 3: Micro-Rotations and Angle Word-Length ===\n');
fprintf('Using w = %d (from Step 2)\n\n', w);

%% Test inputs (quantized with w)
m_vec    = 0:9;
alpha_m  = (4*m_vec + 2) / 20 * pi;
X_true   = cos(alpha_m);
Y_true   = sin(alpha_m);
theta_ref = atan2(Y_true, X_true);

% Pre-quantize inputs to 1S+1I+wF (same as hardware will see)
X_q = floor(X_true * 2^w) / 2^w;
Y_q = floor(Y_true * 2^w) / 2^w;

threshold = 2^(-9);

%% Part A: Sweep N = 1..20, aw = Inf (floating-point angles)
S_vec   = 1:20;
err_S   = zeros(size(S_vec));

for si = 1:length(S_vec)
    S = S_vec(si);
    err_sum = 0;
    for m = 1:length(m_vec)
        [theta_out, ~] = cordic_fixedpoint(X_q(m), Y_q(m), S, w, Inf);
        err_sum = err_sum + abs(theta_out - theta_ref(m));
    end
    err_S(si) = err_sum / length(m_vec);
end

idx_S   = find(err_S < threshold, 1, 'first');
S_min   = S_vec(idx_S);
% Round up to even for Step 7 S/2-unfolding architecture.
S_min_even = S_min + mod(S_min, 2);

fprintf('--- Part A: N sweep (floating-point angles) ---\n');
fprintf('  N  | avg |phase_error| (rad)  | Pass?\n');
fprintf('-----|-------------------------|-------\n');
for si = 1:length(S_vec)
    pass_str = '';
    if err_S(si) < threshold, pass_str = '<-- OK'; end
    fprintf('  %2d | %22.6e  | %s\n', S_vec(si), err_S(si), pass_str);
end
fprintf('\n=> Minimum N = %d  =>  S = %d (rounded up to even for Step 7)\n\n', S_min, S_min_even);

%% Part B: Sweep aw, fixed S = S_min
aw_vec  = 4:20;
err_aw  = zeros(size(aw_vec));

for ai = 1:length(aw_vec)
    aw = aw_vec(ai);
    err_sum = 0;
    for m = 1:length(m_vec)
        [theta_out, ~] = cordic_fixedpoint(X_q(m), Y_q(m), S_min, w, aw);
        err_sum = err_sum + abs(theta_out - theta_ref(m));
    end
    err_aw(ai) = err_sum / length(m_vec);
end

idx_aw = find(err_aw < threshold, 1, 'first');
aw_min = aw_vec(idx_aw);

fprintf('--- Part B: aw sweep (S = %d) ---\n', S_min);
fprintf('  aw | avg |phase_error| (rad)  | Pass?\n');
fprintf('-----|-------------------------|-------\n');
for ai = 1:length(aw_vec)
    pass_str = '';
    if err_aw(ai) < threshold, pass_str = '<-- OK'; end
    fprintf('  %2d | %22.6e  | %s\n', aw_vec(ai), err_aw(ai), pass_str);
end
fprintf('\n=> Minimum aw = %d\n\n', aw_min);

%% Elementary angle table
% LUT entries are all in (0, pi/4] < 1: only fractional bits needed.
% Format: unsigned aw_min bits  (no sign, no integer bits)
% Theta accumulator uses 1S+2I+awF; LUT values are zero-extended when added.
fprintf('--- Elementary Angles atan(2^(-i)) ---\n');
fprintf('LUT format : unsigned %dF  (all values < pi/4 < 1, no integer bits needed)\n', aw_min);
fprintf('Accumulator: 1S + 2I + %dF  (range [-pi, pi] needs 2 integer bits)\n\n', aw_min);
fprintf('  i  | Float (rad)        | Unsigned int | Binary (0.FFFF...)\n');
fprintf('-----|--------------------|--------------|-----------------------\n');

angles_fp  = atan(2.^(-(0:S_min-1)));
angles_int = round(angles_fp * 2^aw_min);   % all positive integers

for i = 0:S_min-1
    a_fp  = angles_fp(i+1);
    a_int = angles_int(i+1);   % always positive
    bin_str = dec2bin(a_int, aw_min);
    % Format as 0.FFFF... (unsigned fractional)
    bin_fmt = ['0.', bin_str];
    fprintf('  %2d | %18.15f | %12d | %s\n', i, a_fp, a_int, bin_fmt);
end

%% Final verification: S_min + aw_min combined
err_sum = 0;
for m = 1:length(m_vec)
    [theta_out, ~] = cordic_fixedpoint(X_q(m), Y_q(m), S_min, w, aw_min);
    err_sum = err_sum + abs(theta_out - theta_ref(m));
end
err_combined = err_sum / length(m_vec);

fprintf('--- Final verification (S=%d, w=%d, aw=%d) ---\n', S_min, w, aw_min);
fprintf('Combined avg error = %.4e rad  (threshold = %.4e)\n', err_combined, threshold);
if err_combined < threshold
    fprintf('=> PASS\n\n');
else
    fprintf('=> FAIL: increase S or aw\n\n');
end

%% Generate Verilog test vectors (use final S_min_even, w, aw_min)
% inX_int, inY_int : quantized inputs  (1S+1I+wF integer domain)
% theta_ref_int    : fixed-point CORDIC output (1S+2I+awF integer domain)
inX_int       = zeros(1, length(m_vec));
inY_int       = zeros(1, length(m_vec));
theta_ref_int = zeros(1, length(m_vec));

max_int =  2^(w+1) - 1;
min_int = -2^(w+1);

for k = 1:length(m_vec)
    Xi = floor(X_true(k) * 2^w);
    Yi = floor(Y_true(k) * 2^w);
    Xi = max(min_int, min(max_int, Xi));
    Yi = max(min_int, min(max_int, Yi));
    inX_int(k) = Xi;
    inY_int(k) = Yi;

    [theta_out, ~]    = cordic_fixedpoint(X_true(k), Y_true(k), S_min_even, w, aw_min);
    theta_ref_int(k)  = round(theta_out * 2^aw_min);
end

% Write text file for Verilog $fscanf
% Format: one line per test case -> inX_int  inY_int  theta_ref_int (signed decimal)
tv_dir  = fullfile(fileparts(mfilename('fullpath')), '..', '00_TESTBED', 'src');
if ~exist(tv_dir, 'dir'), mkdir(tv_dir); end
tv_path = fullfile(tv_dir, 'test_vectors.dat');
fid = fopen(tv_path, 'w');
for k = 1:length(m_vec)
    fprintf(fid, '%d %d %d\n', inX_int(k), inY_int(k), theta_ref_int(k));
end
fclose(fid);
fprintf('Written test_vectors.dat (S=%d, w=%d, aw=%d)\n', S_min_even, w, aw_min);

%% Save results
save(fullfile(fileparts(mfilename('fullpath')), 'step3_result.mat'), ...
     'S_min', 'S_min_even', 'aw_min', 'inX_int', 'inY_int', 'theta_ref_int', 'm_vec');
fprintf('Saved S_min=%d, S_min_even=%d, aw_min=%d to step3_result.mat\n', S_min, S_min_even, aw_min);

%% Generate golden answers for TESTBED comparison (Step 6, 7, theta part of Step 9)
% All three share the same arctangent algorithm; S and aw are now determined.
golden_dir = fullfile(fileparts(mfilename('fullpath')), '..', '00_TESTBED', 'src');
if ~exist(golden_dir, 'dir'), mkdir(golden_dir); end

S   = S_min_even;
TW  = 1 + 2 + aw_min;   % theta word-length: 1S + 2I + awF

% golden_step6.dat: 4 entries for USE_ITERATIVE (m = 0, 3, 6, 9)
m_step6 = [0; 3; 6; 9];
fid = fopen(fullfile(golden_dir, 'golden_step6.dat'), 'w');
for k = 1:length(m_step6)
    m = m_step6(k);
    [th, ~] = cordic_fixedpoint(inX_int(m+1) / 2^w, inY_int(m+1) / 2^w, S, w, aw_min);
    fprintf(fid, '%03X\n', mod(round(th * 2^aw_min), 2^TW));
end
fclose(fid);
fprintf('Written golden_step6.dat  (4 entries, m=0,3,6,9)\n');

% golden_step7.dat: 10 entries for USE_UNFOLDED (m = 0..9)
fid = fopen(fullfile(golden_dir, 'golden_step7.dat'), 'w');
for m = 0:9
    [th, ~] = cordic_fixedpoint(inX_int(m+1) / 2^w, inY_int(m+1) / 2^w, S, w, aw_min);
    fprintf(fid, '%03X\n', mod(round(th * 2^aw_min), 2^TW));
end
fclose(fid);
fprintf('Written golden_step7.dat  (10 entries, m=0..9)\n');

% golden_step9_theta.dat: 10 entries, identical algorithm to step7
fid = fopen(fullfile(golden_dir, 'golden_step9_theta.dat'), 'w');
for m = 0:9
    [th, ~] = cordic_fixedpoint(inX_int(m+1) / 2^w, inY_int(m+1) / 2^w, S, w, aw_min);
    fprintf(fid, '%03X\n', mod(round(th * 2^aw_min), 2^TW));
end
fclose(fid);
fprintf('Written golden_step9_theta.dat  (10 entries, m=0..9)\n');

%% Figure A: avg phase error vs N
fs = 13;
figure('Name', 'Step3 - Error vs N', 'Position', [100, 100, 900, 500]);
semilogy(S_vec, err_S, 'b-o', 'MarkerSize', 6, 'LineWidth', 1.5, ...
         'DisplayName', 'Avg $|\phi_{err}|$');
hold on;
yline(threshold, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Threshold $2^{-9}$'));
semilogy(S_min, err_S(idx_S), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
         'DisplayName', sprintf('Min $N=%d$, $S=%d$ (even)', S_min, S_min_even));
hold off;
xlabel('Number of micro-rotations $N$', 'FontSize', fs);
ylabel('Average $|\phi_{error}|$ (rad)', 'FontSize', fs);
title(sprintf('Step 3A: Phase Error vs. $N$ ($w=%d$, floating-point angles)', w), 'FontSize', fs);
legend('Location', 'southwest', 'FontSize', fs-1);
grid on; box on;
xlim([S_vec(1)-0.5, S_vec(end)+0.5]);
exportgraphics(gcf, fullfile(fig_dir, 'step3_error_vs_N.png'), 'Resolution', 150);

%% Figure B: avg error vs aw
figure('Name', 'Step3 - Error vs aw', 'Position', [150, 150, 900, 500]);
semilogy(aw_vec, err_aw, 'b-o', 'MarkerSize', 6, 'LineWidth', 1.5, ...
         'DisplayName', 'Avg $|\phi_{err}|$');
hold on;
yline(threshold, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Threshold $2^{-9}$'));
semilogy(aw_min, err_aw(idx_aw), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
         'DisplayName', sprintf('Min $a_w = %d$', aw_min));
hold off;
xlabel('Angle word-length $a_w$ (fractional bits)', 'FontSize', fs);
ylabel('Average $|\phi_{error}|$ (rad)', 'FontSize', fs);
title(sprintf('Step 3B: Phase Error vs. Angle Word-Length ($w=%d$, $S=%d$)', w, S_min), 'FontSize', fs);
legend('Location', 'southwest', 'FontSize', fs-1);
grid on; box on;
xlim([aw_vec(1)-0.5, aw_vec(end)+0.5]);
exportgraphics(gcf, fullfile(fig_dir, 'step3_error_vs_aw.png'), 'Resolution', 150);
