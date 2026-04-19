%% Step 9: Verify Magnitude CORDIC from Verilog Simulation Results
% Reads step9_sim_results.dat written by TESTBED.v (USE_MAG mode).
% Required result: magnitude error vs index m.
%
% Reference: MATLAB cordic_fixedpoint model + CSD scaling (same fixed-point
%   truncation as hardware).  Verifies hardware matches the algorithm.
%   Total error vs true magnitude is also printed for analysis.

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Parameters (must match Verilog)
w        = 9;
aw       = 8;
S        = 10;
SCALE_XY = 2^w;    % 512
SCALE_TH = 2^aw;   % 256
W        = w + 2;          % X/Y word-length: 1S + 1I + wF = 11 bits
TW       = 1 + 2 + aw;    % theta word-length: 1S + 2I + awF = 11 bits

%% Load simulation results from Verilog
dat_path = fullfile(fileparts(mfilename('fullpath')), ...
           '..', '00_TESTBED', 'src', 'step9_sim_results.dat');

fid = fopen(dat_path, 'r');
if fid < 0
    error('Cannot open %s\nRun Verilog simulation (USE_MAG) first.', dat_path);
end
raw = textscan(fid, '%x %x', 'CommentStyle', '#');
fclose(fid);

outMag_int   = double(raw{1});
outTheta_int = double(raw{2});
% 11-bit 2's complement → signed
outMag_int(outMag_int     >= 2^(W-1))  = outMag_int(outMag_int     >= 2^(W-1))  - 2^W;
outTheta_int(outTheta_int >= 2^(TW-1)) = outTheta_int(outTheta_int >= 2^(TW-1)) - 2^TW;
N = length(outMag_int);
fprintf('Loaded %d test cases from %s\n\n', N, dat_path);

% Test inputs (must match TESTBED.v, m = 0..9)
m_idx   = (0:9)';
inX_int = [ 486;  300;    0; -301; -487; -487; -301;   -1;  300;  486];
inY_int = [ 158;  414;  512;  414;  158; -159; -415; -512; -415; -159];

mag_out   = outMag_int   / SCALE_XY;
theta_out = outTheta_int / SCALE_TH;

%% Reference 1: MATLAB fixed-point model + CSD (same algorithm as hardware)
% Both model and hardware use floor truncation -> should match within 1 LSB.
mag_model = zeros(N, 1);
for k = 1:N
    [~, Xi_frac] = cordic_fixedpoint(inX_int(k)/SCALE_XY, inY_int(k)/SCALE_XY, S, w, Inf);
    Xi_k = Xi_frac * SCALE_XY;   % Xi in integer domain (float)
    % CSD: A_N = 2^-1 + 2^-3 - 2^-6 - 2^-9  (same truncation as Verilog >>>)
    csd_k = floor(Xi_k/2) + floor(Xi_k/8) - floor(Xi_k/64) - floor(Xi_k/512);
    mag_model(k) = csd_k / SCALE_XY;
end

%% Reference 2: true magnitude of quantized inputs
mag_true = sqrt(inX_int.^2 + inY_int.^2) / SCALE_XY;

%% Error vs MATLAB model (hardware correctness)
err_model_lsb = round((mag_out - mag_model) * SCALE_XY);   % in LSBs

%% Error vs true magnitude (shows inherent truncation bias)
err_true_pct  = (mag_out - mag_true) ./ mag_true * 100;

%% Phase reference: alpha_m (consistent with step6/step7)
alpha_all = (4*(0:9) + 2) / 20 * pi;
theta_ref = alpha_all(m_idx + 1)';
err_theta = theta_out - theta_ref;
err_theta = mod(err_theta + pi, 2*pi) - pi;

%% Console table
fprintf('  m | mag_out  | mag_true | err_mag(%%) | theta_out(deg) | theta_ref(deg) | err_theta(rad)\n');
fprintf('----|----------|----------|------------|----------------|----------------|---------------\n');
for k = 1:N
    fprintf('  %d | %8.5f | %8.5f | %+10.4f | %14.4f | %14.4f | %+14.6e\n', ...
        m_idx(k), mag_out(k), mag_true(k), err_true_pct(k), ...
        theta_out(k)*180/pi, theta_ref(k)*180/pi, err_theta(k));
end

mag_pass   = all(abs(err_true_pct) < 0.1);
theta_pass = mean(abs(err_theta)) < 2^-9;
fprintf('\nMagnitude max err = %.4f%%  (threshold 0.1%%)  -> %s\n', ...
    max(abs(err_true_pct)), ternary(mag_pass,'PASS','FAIL'));
fprintf('Phase avg |error| = %.4e rad  (threshold 2^-9=%.4e rad)  -> %s\n\n', ...
    mean(abs(err_theta)), 2^-9, ternary(theta_pass,'PASS','FAIL'));

%% Figure: Magnitude error vs true magnitude
fs = 13;
figure('Name','Step9 - Magnitude Error vs m', 'Position',[100,100,900,450]);
bar(m_idx, abs(err_true_pct), 'FaceColor',[0.2 0.6 0.9]);
hold on;
yline(0.1, 'r--', 'LineWidth', 1.5, 'DisplayName', 'CSD threshold $0.1\%$');
hold off;
xlabel('Index $m$', 'FontSize', fs);
ylabel('Magnitude relative error vs true $(\%)$', 'FontSize', fs);
title(sprintf('Step 9: Magnitude Error vs. $m$ ($S=%d$, $w=%d$, CSD $f_w=9$)', 10, w), 'FontSize', fs);
legend('Magnitude error', 'CSD approx threshold $0.1\%$', 'Location', 'northeast', 'FontSize', fs-1);
xticks(m_idx); grid on; box on;
exportgraphics(gcf, fullfile(fig_dir,'step9_mag_error.png'), 'Resolution',150);

fprintf('\nFigure saved to %s\n', fig_dir);

%% Helper
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
