%% Step 2: Interpolator Verification - Typical Case (Smaller Amplitude)
% DSP in VLSI Homework 3
% Student ID last digit: 7  =>  phi = mod(7, 2) = 1
%
% Signal: x2[m] = 2^(-20) * [cos(2*pi*(m/4 + 1/3)) + j*sin(2*pi*(m/4 + 1/3))]
% Sampling frequency is 4x the sinusoidal frequency.
%
% Compare: Linear vs Piecewise Parabolic (alpha = 0.5)
% Region : 4 <= m <= 8, mu = 0, 1/8, 2/8, ..., 7/8  (TA correction)

clear; clc; close all;

% Output figure directory
fig_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% Set LaTeX as default interpreter for all text
set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Parameters
phi   = 1;           % mod(7, 2) = 1
alpha = 0.5;         % piecewise parabolic parameter

m_vec  = 4:8;        % interpolation base indices (TA correction: 4~8)
mu_vec = (0:7) / 8;  % fractional delay values: 0, 1/8, ..., 7/8

%% Signal definition
x2 = @(t) 2^(-20) * (cos(2*pi*(t/4 + phi/3)) + 1j*sin(2*pi*(t/4 + phi/3)));

%% Interpolation
n_m  = length(m_vec);
n_mu = length(mu_vec);

x2_true      = zeros(n_m, n_mu);
x2_linear    = zeros(n_m, n_mu);
x2_parabolic = zeros(n_m, n_mu);

for mi = 1:n_m
    m = m_vec(mi);
    for ui = 1:n_mu
        mu = mu_vec(ui);

        % True value
        x2_true(mi, ui) = x2(m + mu);

        % Linear: x(m+mu) = (1-mu)*x(m) + mu*x(m+1)
        x2_linear(mi, ui) = (1 - mu)*x2(m) + mu*x2(m + 1);

        % Piecewise Parabolic (alpha = 0.5)
        % x(m+mu) = C1*x(m-1) + C0*x(m) + Cm1*x(m+1) + Cm2*x(m+2)
        C1  = -alpha*mu + alpha*mu^2;
        C0  =  1 + (alpha - 1)*mu - alpha*mu^2;
        Cm1 =  (alpha + 1)*mu - alpha*mu^2;
        Cm2 = -alpha*mu + alpha*mu^2;
        x2_parabolic(mi, ui) = C1*x2(m-1) + C0*x2(m) + Cm1*x2(m+1) + Cm2*x2(m+2);
    end
end

%% Flatten to 1-D
t_axis        = reshape((m_vec.' + mu_vec).', [], 1);
true_vec      = reshape(x2_true.',      [], 1);
linear_vec    = reshape(x2_linear.',    [], 1);
parabolic_vec = reshape(x2_parabolic.', [], 1);

% Discrete sample points (mu = 0 only)
m_samples  = m_vec;
x2_samples = x2(m_samples);

%% Figure 1: Waveform
figure('Name', 'Step2 - Waveform', 'Position', [50, 50, 1100, 700]);
fs = 13;  % font size

% --- Real part ---
subplot(2, 1, 1);
hold on;
% True continuous reference (finer grid)
t_fine = linspace(3.5, 8.5, 500);
plot(t_fine, real(x2(t_fine)), 'k-', 'LineWidth', 1.2, 'DisplayName', 'True');
% Interpolated outputs
plot(t_axis, real(linear_vec),    'b-o', 'MarkerSize', 4, 'LineWidth', 1, 'DisplayName', 'Linear');
plot(t_axis, real(parabolic_vec), 'r-s', 'MarkerSize', 4, 'LineWidth', 1, 'DisplayName', 'Piecewise Parabolic');
% Discrete input samples
stem(m_samples, real(x2_samples), 'filled', 'k^', 'MarkerSize', 6, ...
     'LineStyle', 'none', 'DisplayName', 'Input samples $x_2[m]$');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Real part', 'FontSize', fs);
title('Step 2: Real Part of $\hat{x}_2[m+\mu]$ ($\phi=1$, $4\times$ sampling, $\alpha=0.5$)', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on;
xlim([3.8, 8.9]);

% --- Imaginary part ---
subplot(2, 1, 2);
hold on;
plot(t_fine, imag(x2(t_fine)), 'k-', 'LineWidth', 1.2, 'DisplayName', 'True');
plot(t_axis, imag(linear_vec),    'b-o', 'MarkerSize', 4, 'LineWidth', 1, 'DisplayName', 'Linear');
plot(t_axis, imag(parabolic_vec), 'r-s', 'MarkerSize', 4, 'LineWidth', 1, 'DisplayName', 'Piecewise Parabolic');
stem(m_samples, imag(x2_samples), 'filled', 'k^', 'MarkerSize', 6, ...
     'LineStyle', 'none', 'DisplayName', 'Input samples $x_2[m]$');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Imaginary part', 'FontSize', fs);
title('Step 2: Imaginary Part of $\hat{x}_2[m+\mu]$', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on;
xlim([3.8, 8.9]);

saveas(gcf, fullfile(fig_dir, 'step2_waveform.png'));

%% Figure 2: Absolute Error
err_linear    = abs(true_vec - linear_vec);
err_parabolic = abs(true_vec - parabolic_vec);

figure('Name', 'Step2 - Absolute Error', 'Position', [200, 200, 1100, 480]);
plot(t_axis, err_linear,          'b-o', 'MarkerSize', 4, 'LineWidth', 1, ...
         'DisplayName', 'Linear');
hold on;
plot(t_axis, err_parabolic, 'r-s', 'MarkerSize', 4, 'LineWidth', 1, ...
         'DisplayName', 'Piecewise Parabolic');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('$|x_2[m+\mu] - \hat{x}_2[m+\mu]|$', 'FontSize', fs);
title('Step 2: Absolute Error ($4 \leq m \leq 8$,  $\mu = 0, \frac{1}{8}, \ldots, \frac{7}{8}$)', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs);
grid on; box on;
xlim([3.8, 8.9]);

saveas(gcf, fullfile(fig_dir, 'step2_error.png'));

%% Console summary
fprintf('=== Step 2 Summary ===\n');
fprintf('Max error  (Linear)             : %.4e\n', max(err_linear));
fprintf('Max error  (Piecewise Parabolic): %.4e\n', max(err_parabolic));
fprintf('Mean error (Linear)             : %.4e\n', mean(err_linear));
fprintf('Mean error (Piecewise Parabolic): %.4e\n', mean(err_parabolic));
