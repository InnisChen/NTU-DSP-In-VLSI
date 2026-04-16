%% Step 2: Word-Length Selection for X/Y Data Path
% DSP in VLSI Lab 4 - CORDIC
% Student parameters: I=7, beta=2
%
% Test inputs: alpha_m = (4m+2)/20 * pi,  m = 0..9
%   X_m = cos(alpha_m),  Y_m = sin(alpha_m)
%   True phase = atan2(Y_m, X_m),  inputs span all 4 quadrants
%
% First determine integer word-length from max signal growth.
% Then sweep w = 8..20 (fractional bits for X/Y).
% Fix S=30, aw=20 (so these don't limit accuracy).
% Metric: average |phase_error| over 10 inputs.
% Goal: find minimum w such that avg error < 2^(-9) = 1/512.

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Test inputs
m_vec    = 0:9;
alpha_m  = (4*m_vec + 2) / 20 * pi;   % angles in (0, pi), spanning all quadrants
X_true   = cos(alpha_m);
Y_true   = sin(alpha_m);
theta_ref = atan2(Y_true, X_true);     % = alpha_m (reference)

%% Integer word-length analysis
% During CORDIC, vector (X,Y) is rotated without scaling.
% After N micro-rotations: X(N) = sqrt(X^2+Y^2) * prod(sqrt(1+2^(-2i)))
%                                = |Z| / S(N)
% For unit-circle inputs |Z|=1, the maximum value of X(N) is 1/S(N).
% With N=30 (sufficient for convergence):
S_growth = 30;
growth_indices = 0:(S_growth-1);
S_converged = prod(1 ./ sqrt(1 + 2.^(-2 .* growth_indices)));
max_growth   = 1 / S_converged;   % ~1.6468

fprintf('=== Step 2: X/Y Word-Length Selection ===\n');
fprintf('--- Integer word-length analysis ---\n');
fprintf('Max signal growth after %d micro-rotations: 1/S(%d) = %.6f\n', ...
        S_growth, S_growth, max_growth);
fprintf('=> Max |X(i)|, |Y(i)| = %.4f  (for unit-circle input)\n', max_growth);
fprintf('=> 1 integer bit sufficient: range [-2, 2) covers %.4f\n', max_growth);
fprintf('=> Format: 1S + 1I + wF  =  (w+2) bits total\n\n');

fprintf('Test angles alpha_m (deg): ');
fprintf('%.1f  ', alpha_m * 180/pi);
fprintf('\n\n');

%% Fixed parameters for this sweep
S_fix  = 30;   % enough micro-rotations
aw_fix = 20;   % enough angle precision

%% Sweep w = 8..20
w_vec    = 8:20;
avg_err  = zeros(size(w_vec));
threshold = 2^(-9);

for wi = 1:length(w_vec)
    w = w_vec(wi);
    err_sum = 0;
    for m = 1:length(m_vec)
        [theta_out, ~] = cordic_fixedpoint(X_true(m), Y_true(m), S_fix, w, aw_fix);
        err_sum = err_sum + abs(theta_out - theta_ref(m));
    end
    avg_err(wi) = err_sum / length(m_vec);
end

% Find minimum w meeting the threshold
idx_ok = find(avg_err < threshold, 1, 'first');
if isempty(idx_ok)
    w_min = NaN;
    fprintf('[WARNING] No w in %d..%d achieves avg error < 2^(-9)\n', w_vec(1), w_vec(end));
else
    w_min = w_vec(idx_ok);
end

%% Console output
fprintf('Threshold: 2^(-9) = %.6f rad\n', threshold);
fprintf('\n  w  | avg |phase_error| (rad)  | Pass?\n');
fprintf('-----|-------------------------|-------\n');
for wi = 1:length(w_vec)
    pass_str = '';
    if avg_err(wi) < threshold, pass_str = '<-- OK'; end
    fprintf('  %2d | %22.6e  | %s\n', w_vec(wi), avg_err(wi), pass_str);
end
fprintf('\n=> Minimum w = %d  (avg error = %.4e rad)\n', w_min, avg_err(idx_ok));

%% Figure: avg error vs w
fs = 13;
figure('Name', 'Step2 - Word Length', 'Position', [100, 100, 900, 500]);

semilogy(w_vec, avg_err, 'b-o', 'MarkerSize', 6, 'LineWidth', 1.5, ...
         'DisplayName', 'Avg $|\phi_{err}|$');
hold on;
yline(threshold, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Threshold $2^{-9} = %.4f$', threshold));
if ~isnan(w_min)
    semilogy(w_min, avg_err(idx_ok), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
             'DisplayName', sprintf('Min $w = %d$', w_min));
end
hold off;

xlabel('Fractional word-length $w$ (bits)', 'FontSize', fs);
ylabel('Average $|\phi_{error}|$ (rad)', 'FontSize', fs);
title('Step 2: Phase Error vs. X/Y Word-Length ($S=30$, $a_w=20$)', 'FontSize', fs);
legend('Location', 'southwest', 'FontSize', fs-1);
grid on; box on;
xlim([w_vec(1)-0.5, w_vec(end)+0.5]);

% Annotate selected w
if ~isnan(w_min)
    text(w_min + 0.3, avg_err(idx_ok) * 1.5, ...
         sprintf('$w = %d$', w_min), ...
         'Interpreter', 'latex', 'FontSize', fs-1, 'Color', [0.1 0.6 0.1]);
end

exportgraphics(gcf, fullfile(fig_dir, 'step2_wordlength.png'), 'Resolution', 150);

%% Save result for subsequent steps
save(fullfile(fileparts(mfilename('fullpath')), 'step2_result.mat'), 'w_min');
fprintf('\nSaved w_min=%d to step2_result.mat\n', w_min);
