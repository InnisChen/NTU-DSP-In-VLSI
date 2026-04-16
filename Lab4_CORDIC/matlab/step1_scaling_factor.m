%% Step 1: CORDIC Scaling Factor Analysis
% DSP in VLSI Lab 4 - CORDIC
% Student parameters: I=7, beta=2
%
% The CORDIC algorithm introduces a scaling factor at each micro-rotation:
%   K_i = 1 / sqrt(1 + 2^(-2i)),  i = 0, 1, 2, ...
%
% After N micro-rotations, the cumulative scaling factor is:
%   S(N) = prod(K_i, i=0..N-1) = 1 / prod(sqrt(1 + 2^(-2i)), i=0..N-1)
%
% Goal: Find the minimum N at which S(N) converges (|S(N) - S(N-1)| < 1e-6),
%       and report the converged value.

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Compute S(N) for N = 1..30
N_max = 30;
N_vec = 1:N_max;
S     = zeros(1, N_max);

for N = N_vec
    % S(N) = prod_{i=0}^{N-1}  1/sqrt(1 + 2^(-2i))
    indices = 0:(N-1);
    S(N) = prod(1 ./ sqrt(1 + 2.^(-2 .* indices)));
end

S_converged = S(end);

% Find minimum N where |S(N) - S_converged| < 1e-6
conv_tol = 1e-6;
conv_idx = find(abs(S - S_converged) < conv_tol, 1, 'first');

%% Console summary
fprintf('=== Step 1: CORDIC Scaling Factor ===\n');
fprintf('S(N) converged value : %.10f\n', S_converged);
fprintf('Theoretical limit    : %.10f\n', 0.6072529350088814);
fprintf('Converged at N       : %d  (|S(N)-S_inf| < %.0e)\n', conv_idx, conv_tol);
fprintf('\nS(N) table:\n');
fprintf('  N  |  S(N)\n');
fprintf('-----|------------------\n');
for N = [1:10, 15, 20, 25, 30]
    fprintf('  %2d | %.10f\n', N, S(N));
end

%% Figure: S(N) vs N
fs = 13;
figure('Name', 'Step1 - Scaling Factor', 'Position', [100, 100, 900, 500]);

plot(N_vec, S, 'b-o', 'MarkerSize', 5, 'LineWidth', 1.5, 'DisplayName', '$S(N)$');
hold on;
yline(S_converged, 'r--', 'LineWidth', 1.2, 'DisplayName', ...
      sprintf('$S(\\infty) \\approx %.4f$', S_converged));
plot(conv_idx, S(conv_idx), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
     'DisplayName', sprintf('Converged at $N=%d$', conv_idx));
hold off;

xlabel('Number of micro-rotations $N$', 'FontSize', fs);
ylabel('$S(N)$', 'FontSize', fs);
title('Step 1: CORDIC Cumulative Scaling Factor $S(N)$', 'FontSize', fs);
legend('Location', 'southeast', 'FontSize', fs-1);
grid on; box on;
xlim([0, N_max+1]);
%ylim([0.55, 1.05]);

% Annotate convergence line
text(N_max - 5, S_converged + 0.015, ...
     sprintf('$S(\\infty) = %.6f$', S_converged), ...
     'Interpreter', 'latex', 'FontSize', fs-1, 'Color', 'r');

exportgraphics(gcf, fullfile(fig_dir, 'step1_scaling_factor.png'), 'Resolution', 150);

%% Figure 2: log-scale convergence (how fast S(N) stabilises)
diff_S = abs(diff(S));  % |S(N) - S(N-1)|, length = N_max-1

figure('Name', 'Step1 - Convergence Rate', 'Position', [150, 150, 900, 450]);
semilogy(2:N_max, diff_S, 'b-o', 'MarkerSize', 5, 'LineWidth', 1.5);
hold on;
yline(conv_tol, 'r--', 'LineWidth', 1.2, ...
      'Label', sprintf('tol = %.0e', conv_tol), 'LabelVerticalAlignment', 'bottom');
hold off;

xlabel('$N$', 'FontSize', fs);
ylabel('$|S(N) - S(N-1)|$', 'FontSize', fs);
title('Step 1: Convergence Rate of $S(N)$', 'FontSize', fs);
grid on; box on;
xlim([1, N_max+1]);

exportgraphics(gcf, fullfile(fig_dir, 'step1_convergence.png'), 'Resolution', 150);
