%% Step 7: Verify S/2-Unfolded CORDIC from Verilog Simulation Results
% Reads step7_sim_results.dat written by TESTBED.v (USE_UNFOLDED mode).
% Required result: phase error vs index m (threshold 2^-9 rad).
% Test inputs: m = 0..9

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Parameters (must match Verilog)
aw       = 10;
TW       = 13;
SCALE_TH = 2^aw;   % 1024

%% Load simulation results from Verilog
dat_path = fullfile(fileparts(mfilename('fullpath')), ...
           '..', '00_TESTBED', 'src', 'step7_sim_results.dat');

fid = fopen(dat_path, 'r');
if fid < 0
    error('Cannot open %s\nRun Verilog simulation (USE_UNFOLDED) first.', dat_path);
end
raw = textscan(fid, '%x', 'CommentStyle', '#');
fclose(fid);

outTheta_int = double(raw{1});
% 11-bit 2's complement → signed
outTheta_int(outTheta_int >= 2^(TW-1)) = outTheta_int(outTheta_int >= 2^(TW-1)) - 2^TW;
N = length(outTheta_int);
fprintf('Loaded %d test cases from %s\n\n', N, dat_path);

% Test inputs (must match TESTBED.v, m = 0..9)
m_idx = (0:9)';

%% Compute reference and error
% Reference = true float alpha_m (consistent with step3 MATLAB analysis)
alpha_all = (4*(0:9) + 2) / 20 * pi;
theta_ref = alpha_all(m_idx + 1)';           % true floating-point angle (rad)
theta_out = outTheta_int / SCALE_TH;          % Verilog output (rad)
err_theta = theta_out - theta_ref;
err_theta = mod(err_theta + pi, 2*pi) - pi;   % wrap to [-pi, pi]

threshold = 2^-9;
avg_err   = mean(abs(err_theta));

%% Console table
fprintf('  m | theta_out (deg) | theta_ref (deg) | |err| (rad)\n');
fprintf('----|-----------------|-----------------|-------------\n');
for k = 1:N
    fprintf('  %d | %15.4f | %15.4f | %11.4e\n', ...
        m_idx(k), theta_out(k)*180/pi, theta_ref(k)*180/pi, abs(err_theta(k)));
end
pass = avg_err < threshold;
fprintf('\nAvg |error| = %.4e rad  (threshold 2^-9 = %.4e rad)  -> %s\n', ...
    avg_err, threshold, ternary(pass, 'PASS', 'FAIL'));

%% Figure: Phase error vs m
fs = 13;
figure('Name','Step7 - Phase Error vs m', 'Position',[100,100,900,450]);
bar(m_idx, abs(err_theta), 'FaceColor',[0.2 0.6 0.9]);
hold on;
yline(threshold, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Threshold $2^{-9}$');
yline(avg_err,   'g:',  'LineWidth', 1.5, 'DisplayName', sprintf('Avg = %.2e rad', avg_err));
hold off;
xlabel('Index $m$', 'FontSize', fs);
ylabel('$|\phi_{error}|$ (rad)', 'FontSize', fs);
title(sprintf('Step 7: Phase Error vs. $m$ ($S/2$-Unfolded CORDIC, $S=%d$)', 12), 'FontSize', fs);
legend('Phase error', 'Threshold $2^{-9}$ rad', 'Average error', 'Location', 'northeast', 'FontSize', fs-1);
xticks(m_idx); grid on; box on;
exportgraphics(gcf, fullfile(fig_dir,'step7_phase_error.png'), 'Resolution',150);

fprintf('\nFigure saved to %s\n', fig_dir);

%% Helper
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
