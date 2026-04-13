%% Step 1: Interpolator Verification - Over-sampled Case
% DSP in VLSI Homework 3
% Student ID last digit: 7  =>  phi = mod(7, 2) = 1
%
% Signal: x1[m] = cos(2*pi*(m/10 + 1/2)) + j*sin(2*pi*(m/10 + 1/2))
% Sampling frequency is 10x the sinusoidal frequency.
%
% Compare: Linear vs Second-order polynomial interpolator
% Region : 10 <= m <= 20, mu = 0, 1/8, 2/8, ..., 7/8

clear; clc; close all;

% Output figure directory
fig_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% Set LaTeX as default interpreter for all text
set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Parameters
phi    = 1;          % mod(7, 2) = 1
m_vec  = 10:20;      % interpolation base indices
mu_vec = (0:7) / 8;  % fractional delay values: 0, 1/8, ..., 7/8

%% Signal definition
x1 = @(t) cos(2*pi*(t/10 + phi/2)) + 1j*sin(2*pi*(t/10 + phi/2));

%% Interpolation
n_m  = length(m_vec);
n_mu = length(mu_vec);

x1_true   = zeros(n_m, n_mu);
x1_linear = zeros(n_m, n_mu);
x1_2nd    = zeros(n_m, n_mu);

for mi = 1:n_m
    m = m_vec(mi);
    for ui = 1:n_mu
        mu = mu_vec(ui);

        % True value
        x1_true(mi, ui) = x1(m + mu);

        % Linear: x(m+mu) = (1-mu)*x(m) + mu*x(m+1)
        x1_linear(mi, ui) = (1 - mu)*x1(m) + mu*x1(m + 1);

        % Second-order: C0*x(m) + C1*x(m+1) + C2*x(m+2)
        C0 = (1 - mu) * (2 - mu) / 2;
        C1 = mu * (2 - mu);
        C2 = -mu * (1 - mu) / 2;
        x1_2nd(mi, ui) = C0*x1(m) + C1*x1(m+1) + C2*x1(m+2);
    end
end

%% Flatten to 1-D
t_axis     = reshape((m_vec.' + mu_vec).', [], 1);
true_vec   = reshape(x1_true.',   [], 1);
linear_vec = reshape(x1_linear.', [], 1);
sec_vec    = reshape(x1_2nd.',    [], 1);

% Discrete sample points (mu = 0 only)
m_samples  = m_vec;
x1_samples = x1(m_samples);

%% Figure 1: Waveform
figure('Name', 'Step1 - Waveform', 'Position', [50, 50, 1100, 700]);
fs = 13;  % font size

% --- Real part ---
subplot(2, 1, 1);
hold on;
% True continuous reference (finer grid)
t_fine = linspace(10, 20, 500);
plot(t_fine, real(x1(t_fine)), 'k-', 'LineWidth', 1.2, 'DisplayName', 'True');
% Interpolated outputs
plot(t_axis, real(linear_vec), 'b-o', 'MarkerSize', 4, 'LineWidth', 1,   'DisplayName', 'Linear');
plot(t_axis, real(sec_vec),    'r-s', 'MarkerSize', 4, 'LineWidth', 1,   'DisplayName', '2nd-order');
% Discrete input samples
stem(m_samples, real(x1_samples), 'filled', 'k^', 'MarkerSize', 6, ...
     'LineStyle', 'none', 'DisplayName', 'Input samples $x_1[m]$');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Real part', 'FontSize', fs);
title('Step 1: Real Part of $\hat{x}_1[m+\mu]$ ($\phi=1$, $10\times$ oversampling)', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on;
xlim([9.8, 20.2]);

% --- Imaginary part ---
subplot(2, 1, 2);
hold on;
plot(t_fine, imag(x1(t_fine)), 'k-', 'LineWidth', 1.2, 'DisplayName', 'True');
plot(t_axis, imag(linear_vec), 'b-o', 'MarkerSize', 4, 'LineWidth', 1,  'DisplayName', 'Linear');
plot(t_axis, imag(sec_vec),    'r-s', 'MarkerSize', 4, 'LineWidth', 1,  'DisplayName', '2nd-order');
stem(m_samples, imag(x1_samples), 'filled', 'k^', 'MarkerSize', 6, ...
     'LineStyle', 'none', 'DisplayName', 'Input samples $x_1[m]$');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Imaginary part', 'FontSize', fs);
title('Step 1: Imaginary Part of $\hat{x}_1[m+\mu]$', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on;
xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step1_waveform.png'));

%% Figure 2: Absolute Error
err_linear = abs(true_vec - linear_vec);
err_2nd    = abs(true_vec - sec_vec);

figure('Name', 'Step1 - Absolute Error', 'Position', [200, 200, 1100, 480]);
plot(t_axis, err_linear, 'b-o', 'MarkerSize', 4, 'LineWidth', 1, ...
     'DisplayName', 'Linear');
hold on;
plot(t_axis, err_2nd, 'r-s', 'MarkerSize', 4, 'LineWidth', 1, ...
     'DisplayName', '2nd-order');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('$|x_1[m+\mu] - \hat{x}_1[m+\mu]|$', 'FontSize', fs);
title('Step 1: Absolute Error ($10 \leq m \leq 20$,  $\mu = 0, \frac{1}{8}, \ldots, \frac{7}{8}$)', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs);
grid on; box on;
xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step1_error.png'));

%% Console summary
fprintf('=== Step 1 Summary ===\n');
fprintf('Max error  (Linear)    : %.4e\n', max(err_linear));
fprintf('Max error  (2nd-order) : %.4e\n', max(err_2nd));
fprintf('Mean error (Linear)    : %.4e\n', mean(err_linear));
fprintf('Mean error (2nd-order) : %.4e\n', mean(err_2nd));
