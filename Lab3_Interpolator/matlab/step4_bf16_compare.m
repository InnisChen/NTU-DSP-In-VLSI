%% Step 4: BF16 vs Double Precision Comparison
% DSP in VLSI Homework 3
%
% Signal : x1[m] = cos(2*pi*(m/10 + 1/2)) + j*sin(2*pi*(m/10 + 1/2))
% Method : 2nd-order Farrow structure
% Range  : 10 <= m <= 20, mu = 0, 1/8, ..., 7/8
%
% Farrow structure:
%   v2 =  0.5*x(m) - x(m+1) + 0.5*x(m+2)
%   v1 = -1.5*x(m) + 2*x(m+1) - 0.5*x(m+2)
%   v0 =  x(m)
%   out = v0 + mu*(v1 + mu*v2)          <- Horner's method
%
% Hardware sharing applied:
%   half_x0 = 0.5*x(m),  half_x2 = 0.5*x(m+2)  (exponent-1, no multiplier)
%   -0.5*x(m+2) in v1 reuses half_x2 with sign flip (no extra multiply)
%   -1.5*x(m)   = -(x(m) + half_x0)  -> adder only, no multiplier
%    2.0*x(m+1) via exponent+1        -> no multiplier
% => coefficient block has zero multipliers; only Horner path uses bf16_mul

clear; clc; close all;

% Output figure directory
fig_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Parameters
phi    = 1;
m_vec  = 10:20;
mu_vec = (0:7) / 8;
n_m    = length(m_vec);
n_mu   = length(mu_vec);
fs     = 13;   % font size

%% Signal
x1 = @(t) cos(2*pi*(t/10 + phi/2)) + 1j*sin(2*pi*(t/10 + phi/2));

% Exact sign flip: flip bit 15 (no multiplication needed)
bf16_neg = @(x) bitxor(uint16(x), uint16(32768));

%% Interpolation
out_double = complex(zeros(n_m, n_mu));
out_bf16   = complex(zeros(n_m, n_mu));

for mi = 1:n_m
    m = m_vec(mi);

    % --- Input samples (double) ---
    s0d = x1(m);  s1d = x1(m+1);  s2d = x1(m+2);

    % --- Input samples -> BF16 (real / imag separated) ---
    s0_re = double_to_bf16(real(s0d));  s0_im = double_to_bf16(imag(s0d));
    s1_re = double_to_bf16(real(s1d));  s1_im = double_to_bf16(imag(s1d));
    s2_re = double_to_bf16(real(s2d));  s2_im = double_to_bf16(imag(s2d));

    % --- Farrow coefficients in BF16 (computed once per m) ---
    % Shared terms: half_x0 = 0.5*x0,  half_x2 = 0.5*x2  (exponent-1, no multiplier)
    h0_re = bf16_half(s0_re);
    h0_im = bf16_half(s0_im);
    h2_re = bf16_half(s2_re);
    h2_im = bf16_half(s2_im);

    % v2 = 0.5*x0 + (-x1) + 0.5*x2
    v2_re = bf16_add(bf16_add(h0_re, bf16_neg(s1_re)), h2_re);
    v2_im = bf16_add(bf16_add(h0_im, bf16_neg(s1_im)), h2_im);

    % v1 = -(x0 + 0.5*x0) + (2*x1) + (-0.5*x2)
    %      -(x0 + half_x0) replaces -1.5*x0  -> adder only
    %      2*x1 via exponent+1               -> no multiplier
    %      (-0.5*x2) reuses h2 with sign flip
    v1_re = bf16_add(bf16_add(bf16_neg(bf16_add(s0_re, h0_re)), ...
                              bf16_double(s1_re)), bf16_neg(h2_re));
    v1_im = bf16_add(bf16_add(bf16_neg(bf16_add(s0_im, h0_im)), ...
                              bf16_double(s1_im)), bf16_neg(h2_im));

    % v0 = x0  (no operation)
    v0_re = s0_re;
    v0_im = s0_im;

    for ui = 1:n_mu
        mu    = mu_vec(ui);
        mu_bf = double_to_bf16(mu);

        % --- Double precision (direct 2nd-order polynomial) ---
        C0 = (1 - mu) * (2 - mu) / 2;
        C1 =  mu      * (2 - mu);
        C2 = -mu      * (1 - mu) / 2;
        out_double(mi, ui) = C0*s0d + C1*s1d + C2*s2d;

        % --- BF16 Farrow: Horner's method ---
        %  step 1: mu * v2
        %  step 2: v1 + step1
        %  step 3: mu * step2
        %  step 4: v0 + step3

        % Real part
        t1_re  = bf16_mul(mu_bf, v2_re);
        t2_re  = bf16_add(v1_re, t1_re);
        t3_re  = bf16_mul(mu_bf, t2_re);
        out_re = bf16_add(v0_re, t3_re);

        % Imaginary part
        t1_im  = bf16_mul(mu_bf, v2_im);
        t2_im  = bf16_add(v1_im, t1_im);
        t3_im  = bf16_mul(mu_bf, t2_im);
        out_im = bf16_add(v0_im, t3_im);

        out_bf16(mi, ui) = bf16_to_double(out_re) + 1j*bf16_to_double(out_im);
    end
end

%% Flatten to 1-D
t_axis     = reshape((m_vec.' + mu_vec).', [], 1);
true_vec   = arrayfun(x1, t_axis);
double_vec = reshape(out_double.', [], 1);
bf16_vec   = reshape(out_bf16.',   [], 1);

% BF16 vs double difference (real / imag separated)
diff_re = real(double_vec) - real(bf16_vec);
diff_im = imag(double_vec) - imag(bf16_vec);

%% Figure 1: Waveform
figure('Name', 'Step4 - Waveform', 'Position', [50, 50, 1100, 700]);

subplot(2, 1, 1);
hold on;
t_fine = linspace(10, 20, 500);
plot(t_fine, real(x1(t_fine)), 'k-',  'LineWidth', 1.2, 'DisplayName', 'True');
plot(t_axis, real(double_vec),  'b-o', 'MarkerSize', 3,  'LineWidth', 1, ...
     'DisplayName', 'Double (2nd-order)');
plot(t_axis, real(bf16_vec),    'r-s', 'MarkerSize', 3,  'LineWidth', 1, ...
     'DisplayName', 'BF16 Farrow');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Real part', 'FontSize', fs);
title('Step 4: Real Part of $\hat{x}_1[m+\mu]$ --- BF16 vs Double', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on; xlim([9.8, 20.2]);

subplot(2, 1, 2);
hold on;
plot(t_fine, imag(x1(t_fine)), 'k-',  'LineWidth', 1.2, 'DisplayName', 'True');
plot(t_axis, imag(double_vec),  'b-o', 'MarkerSize', 3,  'LineWidth', 1, ...
     'DisplayName', 'Double (2nd-order)');
plot(t_axis, imag(bf16_vec),    'r-s', 'MarkerSize', 3,  'LineWidth', 1, ...
     'DisplayName', 'BF16 Farrow');
hold off;
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Imaginary part', 'FontSize', fs);
title('Step 4: Imaginary Part of $\hat{x}_1[m+\mu]$', 'FontSize', fs);
legend('Location', 'best', 'FontSize', fs-1);
grid on; box on; xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step4_waveform.png'));

%% Figure 2: BF16 vs Double difference (real / imag separated)
figure('Name', 'Step4 - BF16 vs Double Error', 'Position', [200, 200, 1100, 700]);

subplot(2, 1, 1);
plot(t_axis, diff_re, 'r-o', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Real part difference', 'FontSize', fs);
title('Step 4: Real Part --- Double $-$ BF16 ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

subplot(2, 1, 2);
plot(t_axis, diff_im, 'r-o', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Imaginary part difference', 'FontSize', fs);
title('Step 4: Imaginary Part --- Double $-$ BF16 ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step4_error.png'));

%% Console summary
fprintf('=== Step 4 Summary ===\n');
fprintf('Max |diff| real : %.4e\n', max(abs(diff_re)));
fprintf('Max |diff| imag : %.4e\n', max(abs(diff_im)));
fprintf('Mean |diff| real: %.4e\n', mean(abs(diff_re)));
fprintf('Mean |diff| imag: %.4e\n', mean(abs(diff_im)));

%% Write .dat files for Verilog testbench ($readmemh format)
% Output directory: 00_TESTBED/src/
src_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), '00_TESTBED', 'src');

mu_labels = {'0', '1/8', '2/8', '3/8', '4/8', '5/8', '6/8', '7/8'};

% --- IntpIn.dat: x1[m] for m=10..22, {re[15:0], im[15:0]} as 8-char hex ---
fid = fopen(fullfile(src_dir, 'IntpIn.dat'), 'w');
for m = 10:22
    re_hex = double(double_to_bf16(real(x1(m))));
    im_hex = double(double_to_bf16(imag(x1(m))));
    fprintf(fid, '%04X%04X  // m=%d  re=%.6f  im=%.6f\n', ...
        re_hex, im_hex, m, real(x1(m)), imag(x1(m)));
end
fclose(fid);

% --- exp_out.dat: expected output for m=10..20, mu=0..7/8 (88 entries) ---
fid = fopen(fullfile(src_dir, 'exp_out.dat'), 'w');
for mi = 1:n_m
    for ui = 1:n_mu
        re_hex = double(double_to_bf16(real(out_bf16(mi, ui))));
        im_hex = double(double_to_bf16(imag(out_bf16(mi, ui))));
        fprintf(fid, '%04X%04X  // m=%d  mu=%s\n', ...
            re_hex, im_hex, m_vec(mi), mu_labels{ui});
    end
end
fclose(fid);

fprintf('\n.dat files written to: %s\n', src_dir);
fprintf('  IntpIn.dat  : 13 entries (m=10..22)\n');
fprintf('  exp_out.dat : 88 entries (m=10..20, mu=0..7/8)\n');
