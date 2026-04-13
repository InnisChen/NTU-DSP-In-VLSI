%% Step 6: Hardware Error Analysis (Points 8 and 9)
% DSP in VLSI Homework 3
%
% Point 9: Verilog behavior sim output vs. BF16 bit-true model (exp_out.dat)
%          Expected: all 88 errors = 0 (bit-true verification)
%
% Point 8: BF16 hardware output vs. double-precision true value
%          Also supports post-synthesis: place sim_out_postsyn.dat in src/
%
% sim_out.dat capture order (TB out_cnt = 0..87):
%   k     = floor(out_cnt / 8)     -> m group (m = 10+k)
%   mu_v  = mod(6 + out_cnt%8, 8)  -> mu index
% exp_out.dat order: exp_i = 8*k + mu_v  (m=10..20, mu=0..7/8)
%
% Reorder formula: out_cnt = 8*k + mod(mu_v+2, 8)  ->  exp_i = 8*k + mu_v

clear; clc; close all;

% Output figure directory
fig_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Paths
src_dir     = fullfile(fileparts(fileparts(mfilename('fullpath'))), '00_TESTBED', 'src');
SIM_DAT     = fullfile(src_dir, 'sim_out.dat');
EXP_DAT     = fullfile(src_dir, 'exp_out.dat');
POSTSYN_DAT = fullfile(src_dir, 'sim_out_postsyn.dat');

%% Parameters
phi    = 1;
m_vec  = 10:20;
mu_vec = (0:7) / 8;
n_m    = numel(m_vec);
n_mu   = numel(mu_vec);
N      = n_m * n_mu;      % 88
fs     = 13;

x1 = @(t) cos(2*pi*(t/10 + phi/2)) + 1j*sin(2*pi*(t/10 + phi/2));

%% t-axis in (m, mu) order: m changes slowly, mu changes fast
[M_grid, MU_grid] = meshgrid(m_vec, mu_vec);   % (8x11)
t_axis      = reshape(M_grid + MU_grid, [], 1); % 88x1
true_double = arrayfun(x1, t_axis);             % 88x1 double-precision true values

%% Read and reorder simulation outputs
sim_reordered = reorder_by_exp(read_dat(SIM_DAT));
exp_double    = read_dat(EXP_DAT);

%% =========================================================
%% Figure 1 - Point 9: Verilog behavior vs. BF16 bit-true model
%% =========================================================
err9_re = real(sim_reordered) - real(exp_double);
err9_im = imag(sim_reordered) - imag(exp_double);

fprintf('=== Point 9: Verilog behav sim vs. BF16 bit-true model ===\n');
fprintf('Max |Re error|: %.4e  (expected 0)\n', max(abs(err9_re)));
fprintf('Max |Im error|: %.4e  (expected 0)\n', max(abs(err9_im)));
fprintf('Non-zero count: %d / %d\n', nnz(err9_re ~= 0) + nnz(err9_im ~= 0), 2*N);

figure('Name', 'Point9 - Verilog behav vs BF16 bit-true', 'Position', [50, 50, 1100, 700]);

subplot(2, 1, 1);
stem(t_axis, err9_re, 'r', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Re error', 'FontSize', fs);
title('Point 9: Re$\{$Verilog$\}$ $-$ Re$\{$BF16 bit-true$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

subplot(2, 1, 2);
stem(t_axis, err9_im, 'b', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Im error', 'FontSize', fs);
title('Point 9: Im$\{$Verilog$\}$ $-$ Im$\{$BF16 bit-true$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step6_point9.png'));

%% =========================================================
%% Figure 2 - Point 8 (behav): BF16 output vs. double-precision true
%% =========================================================
err8_re = real(exp_double) - real(true_double);
err8_im = imag(exp_double) - imag(true_double);

fprintf('\n=== Point 8: BF16 output vs. double-precision true ===\n');
fprintf('Max |Re error|: %.4e\n', max(abs(err8_re)));
fprintf('Max |Im error|: %.4e\n', max(abs(err8_im)));

figure('Name', 'Point8 - BF16 behav vs double-precision', 'Position', [100, 100, 1100, 700]);

subplot(2, 1, 1);
plot(t_axis, err8_re, 'r-o', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Re error', 'FontSize', fs);
title('Point 8 (Behav): Re$\{$BF16 hardware$\}$ $-$ Re$\{$double-precision$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

subplot(2, 1, 2);
plot(t_axis, err8_im, 'b-o', 'MarkerSize', 3, 'LineWidth', 1);
xlabel('$m + \mu$', 'FontSize', fs);
ylabel('Im error', 'FontSize', fs);
title('Point 8 (Behav): Im$\{$BF16 hardware$\}$ $-$ Im$\{$double-precision$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
grid on; box on; xlim([9.8, 20.2]);

saveas(gcf, fullfile(fig_dir, 'step6_point8_behav.png'));

%% =========================================================
%% Figure 3 - Point 8 (post-syn): same analysis for post-synthesis
%% =========================================================
if isfile(POSTSYN_DAT)
    postsyn_reordered = reorder_by_exp(read_dat(POSTSYN_DAT));

    err8ps_re = real(postsyn_reordered) - real(true_double);
    err8ps_im = imag(postsyn_reordered) - imag(true_double);

    fprintf('\n=== Point 8 (Post-syn): BF16 output vs. double-precision true ===\n');
    fprintf('Max |Re error|: %.4e\n', max(abs(err8ps_re)));
    fprintf('Max |Im error|: %.4e\n', max(abs(err8ps_im)));

    figure('Name', 'Point8 - BF16 post-syn vs double-precision', 'Position', [150, 150, 1100, 700]);

    subplot(2, 1, 1);
    plot(t_axis, err8ps_re, 'r-o', 'MarkerSize', 3, 'LineWidth', 1);
    xlabel('$m + \mu$', 'FontSize', fs);
    ylabel('Re error', 'FontSize', fs);
    title('Point 8 (Post-syn): Re$\{$BF16 hardware$\}$ $-$ Re$\{$double-precision$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
    grid on; box on; xlim([9.8, 20.2]);

    subplot(2, 1, 2);
    plot(t_axis, err8ps_im, 'b-o', 'MarkerSize', 3, 'LineWidth', 1);
    xlabel('$m + \mu$', 'FontSize', fs);
    ylabel('Im error', 'FontSize', fs);
    title('Point 8 (Post-syn): Im$\{$BF16 hardware$\}$ $-$ Im$\{$double-precision$\}$  ($10 \leq m \leq 20$)', 'FontSize', fs);
    grid on; box on; xlim([9.8, 20.2]);
    saveas(gcf, fullfile(fig_dir, 'step6_point8_postsyn.png'));
else
    fprintf('\n[INFO] %s not found. Run post-synthesis simulation first,\n', POSTSYN_DAT);
    fprintf('       then copy sim_out.dat to sim_out_postsyn.dat.\n');
end

% =========================================================
% Local functions (must be after all script code in MATLAB)
% =========================================================

function cvec = read_dat(filepath)
% Read a {re[15:0], im[15:0]} BF16 hex .dat file -> Nx1 complex double.
    fid = fopen(filepath, 'r');
    if fid == -1, error('Cannot open file: %s', filepath); end
    raw = textscan(fid, '%8s %*[^\n]');
    fclose(fid);
    hex_vals = uint32(hex2dec(raw{1}));
    re_u16   = uint16(bitshift(hex_vals, -16));
    im_u16   = uint16(bitand(hex_vals, uint32(65535)));
    cvec = bf16_to_double(re_u16) + 1j * bf16_to_double(im_u16);
end

function reordered = reorder_by_exp(raw)
% Reorder from TB out_cnt order to (m, mu) exp_out order.
% TB phase offset: first valid output is mu_i=6, so out_cnt=0 -> mu_v=6.
% Inverse mapping: out_cnt = 8*k + mod(mu_v+2, 8)
    N      = numel(raw);
    exp_i  = (0:N-1)';
    k      = floor(exp_i / 8);
    mu_v   = mod(exp_i, 8);
    out_cnt = 8*k + mod(mu_v + 2, 8);
    reordered = raw(out_cnt + 1);
end
