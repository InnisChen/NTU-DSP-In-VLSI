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
% Goal: Draw S(N) vs N for N = 1..30 and observe the saturation phenomenon.

clear; clc; close all;

fig_dir = setup_figure_dir();

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

%% Console summary
fprintf('=== Step 1: CORDIC Scaling Factor ===\n');
fprintf('S(N) converged value : %.10f\n', S_converged);
fprintf('Theoretical limit    : %.10f\n', 0.6072529350088814);
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
hold off;

xlabel('Number of micro-rotations $N$', 'FontSize', fs);
ylabel('$S(N)$', 'FontSize', fs);
title('Step 1: CORDIC Cumulative Scaling Factor $S(N)$', 'FontSize', fs);
legend('Location', 'northeast', 'FontSize', fs-1);
grid on; box on;
xlim([0, N_max+1]);

% Annotate saturation value (placed below the line to avoid overlap)
text(2, S_converged - 0.025, ...
     sprintf('$S(\\infty) = %.6f$', S_converged), ...
     'Interpreter', 'latex', 'FontSize', fs-1, 'Color', 'r');

exportgraphics(gcf, fullfile(fig_dir, 'step1_scaling_factor.png'), 'Resolution', 150);

%% Save result for subsequent steps
save(fullfile(fileparts(mfilename('fullpath')), 'step1_result.mat'), 'S_converged');
fprintf('\nSaved S_converged=%.10f to step1_result.mat\n', S_converged);
