%% Step 4: Determine Number of Micro-Rotations for Magnitude Function
% DSP in VLSI Lab 4 - CORDIC
% Student parameters: I=7, beta=2
%
% Goal: find minimum N such that magnitude error < 0.1% (0.001)
%
% Error bound (Eq. 12):
%   error <= 1 - cos(theta_e(N-1)) = 1 - 1/sqrt(1 + 2^(-2(N-1)))

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

fprintf('=== Step 4: Magnitude Micro-Rotations ===\n\n');

threshold = 0.001;   % 0.1%

%% Analytical error bound vs N
N_vec     = 1:20;
err_bound = 1 - 1 ./ sqrt(1 + 2.^(-2*(N_vec - 1)));

idx_ok    = find(err_bound < threshold, 1, 'first');
N_mag_min = N_vec(idx_ok);

fprintf('  N  | Error bound             | Pass?\n');
fprintf('-----|-------------------------|-------\n');
for ni = 1:length(N_vec)
    pass_str = '';
    if err_bound(ni) < threshold, pass_str = '<-- OK'; end
    fprintf('  %2d | %22.6e  | %s\n', N_vec(ni), err_bound(ni), pass_str);
end
fprintf('\n=> Minimum N_mag = %d\n\n', N_mag_min);

%% Save result
save(fullfile(fileparts(mfilename('fullpath')), 'step4_result.mat'), 'N_mag_min');
fprintf('Saved N_mag_min=%d to step4_result.mat\n', N_mag_min);

%% Figure: analytical bound vs N
fs = 13;
figure('Name', 'Step4 - Magnitude Error vs N', 'Position', [100, 100, 900, 500]);

semilogy(N_vec, err_bound, 'b-o', 'MarkerSize', 6, 'LineWidth', 1.5, ...
         'DisplayName', '$1 - \frac{1}{\sqrt{1+2^{-2(N-1)}}}$');
hold on;
yline(threshold, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', 'Threshold $0.1\%$');
semilogy(N_mag_min, err_bound(idx_ok), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
         'DisplayName', sprintf('Min $N = %d$', N_mag_min));
hold off;

xlabel('Number of micro-rotations $N$', 'FontSize', fs);
ylabel('Magnitude error upper bound', 'FontSize', fs);
title('Step 4: Magnitude Error Bound vs. $N$', 'FontSize', fs);
legend('Location', 'southwest', 'FontSize', fs-1);
grid on; box on;
xlim([N_vec(1)-0.5, N_vec(end)+0.5]);
exportgraphics(gcf, fullfile(fig_dir, 'step4_magnitude_error.png'), 'Resolution', 150);
