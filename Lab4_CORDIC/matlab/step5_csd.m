%% Step 5: CSD Representation of CORDIC Scaling Factor S(N)
% DSP in VLSI Lab 4 - CORDIC
% Student parameters: I=7, beta=2
%
% Goal: find minimum CSD fractional word-length fw such that
%       |S_csd - S_true| / S_true < 0.1% (0.001)
%
% CSD (Canonical Signed Digit): digits in {-1, 0, +1}, no two adjacent
% non-zero digits. Minimizes number of non-zero digits for a given precision.
%
% shift-and-add: each non-zero CSD digit = one shifted copy of X(N)
%                adders = (number of non-zero digits) - 1

clear; clc; close all;

fig_dir = setup_figure_dir();

set(groot, 'defaultTextInterpreter',          'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',        'latex');

%% Load N_mag_min from Step 4
mat4 = fullfile(fileparts(mfilename('fullpath')), 'step4_result.mat');
load(mat4, 'N_mag_min');

% N_mag can be set larger than N_mag_min for a more converged S(N).
% Step 9 only requires S >= N_mag_min, so any N >= N_mag_min is valid.
% A larger N gives S(N) closer to S(inf) ~= 0.6073, reducing CSD error.
N_mag = 10;   % design choice: >= N_mag_min (= 6)

fprintf('=== Step 5: CSD Scaling Factor ===\n');
fprintf('N_mag_min (Step 4) = %d,  using N_mag = %d\n\n', N_mag_min, N_mag);

%% Compute true scaling factor S(N_mag)
S_true = prod(1 ./ sqrt(1 + 2.^(-2*(0:N_mag-1))));
fprintf('S_true = S(%d) = %.15f\n\n', N_mag, S_true);

threshold = 0.001;   % 0.1%

%% Sweep fw = 4..20
fw_vec  = 4:20;
err_csd = zeros(size(fw_vec));

for fi = 1:length(fw_vec)
    fw = fw_vec(fi);
    n  = round(S_true * 2^fw);          % integer representation
    csd = dec2csd(n, fw + 2);           % CSD digits (LSB first), extra bits for carry
    S_csd = sum(csd .* 2.^((0:length(csd)-1) - fw));
    err_csd(fi) = abs(S_csd - S_true) / S_true;
end

idx_ok = find(err_csd < threshold, 1, 'first');
fw_min = fw_vec(idx_ok);

%% Console output: sweep table
fprintf('  fw | CSD relative error      | Pass?\n');
fprintf('-----|-------------------------|-------\n');
for fi = 1:length(fw_vec)
    pass_str = '';
    if err_csd(fi) < threshold, pass_str = '<-- OK'; end
    fprintf('  %2d | %22.6e  | %s\n', fw_vec(fi), err_csd(fi), pass_str);
end
fprintf('\n=> Minimum fw = %d\n\n', fw_min);

%% Detailed CSD representation at fw_min
n_opt  = round(S_true * 2^fw_min);
csd    = dec2csd(n_opt, fw_min + 2);
S_csd  = sum(csd .* 2.^((0:length(csd)-1) - fw_min));
rel_err = abs(S_csd - S_true) / S_true;

% Identify non-zero digits and their bit positions (relative to binary point)
% bit position k means digit × 2^(-k), k = fw_min - bit_index
nonzero_idx = find(csd ~= 0);   % 1-based index in csd array (LSB first)
bit_pos     = fw_min - (nonzero_idx - 1);   % negative = fractional

fprintf('--- CSD representation at fw = %d ---\n', fw_min);
fprintf('S_true    = %.15f\n', S_true);
fprintf('S_csd     = %.15f\n', S_csd);
fprintf('Rel error = %.6e\n\n', rel_err);

fprintf('Non-zero CSD digits:\n');
fprintf('  Bit index | Position (2^k) | Digit\n');
fprintf('------------|----------------|------\n');
for k = 1:length(nonzero_idx)
    bidx = nonzero_idx(k) - 1;   % 0-based bit index
    bpos = bidx - fw_min;         % actual power of 2
    fprintf('  %3d       | 2^(%3d)        |  %+d\n', bidx, bpos, csd(nonzero_idx(k)));
end

n_nonzero = length(nonzero_idx);
n_adders  = n_nonzero - 1;
fprintf('\nNon-zero digits : %d\n', n_nonzero);
fprintf('Adders needed   : %d\n\n', n_adders);

%% Print CSD binary string (format: 0.ddd..., MSB first)
% S_true < 1, so integer part is always 0; print fractional bits only.
csd_msb = csd(fw_min:-1:1);   % bits at positions 2^(-1)..2^(-fw_min), MSB first

fprintf('CSD binary (MSB first, format 0.bb...):\n  0.');
for k = 1:length(csd_msb)
    if csd_msb(k) == 1
        fprintf('P');   % +1
    elseif csd_msb(k) == -1
        fprintf('N');   % -1
    else
        fprintf('0');
    end
end
fprintf('\n  (P=+1, N=-1, 0=0)\n\n');

%% Save result (include CSD shift parameters for golden generation)
% csd_digits_nz / csd_shifts_nz encode the shift-and-add formula applied to
% integer Xi in the hardware: mag = sum(csd_digits_nz .* floor(Xi ./ 2.^csd_shifts_nz))
csd_digits_nz = csd(nonzero_idx);             % +1 or -1 for each non-zero term
csd_shifts_nz = fw_min - (nonzero_idx - 1);  % right-shift amount for each term

save(fullfile(fileparts(mfilename('fullpath')), 'step5_result.mat'), ...
     'fw_min', 'N_mag', 'S_true', 'S_csd', 'n_nonzero', 'n_adders', ...
     'csd_digits_nz', 'csd_shifts_nz');
fprintf('Saved fw_min=%d, n_adders=%d to step5_result.mat\n', fw_min, n_adders);

%% Generate golden_step9_mag.dat (magnitude golden, determinable only after CSD is fixed)
mat2 = fullfile(fileparts(mfilename('fullpath')), 'step2_result.mat');
mat3 = fullfile(fileparts(mfilename('fullpath')), 'step3_result.mat');
load(mat2, 'w_min');
load(mat3, 'S_min_even', 'inX_int', 'inY_int');
w_xy = w_min;            % fractional bits for X/Y path
W_xy = w_xy + 2;         % total X/Y word-length: 1S + 1I + wF

golden_dir = fullfile(fileparts(mfilename('fullpath')), '..', '00_TESTBED', 'src');
if ~exist(golden_dir, 'dir'), mkdir(golden_dir); end

fid = fopen(fullfile(golden_dir, 'golden_step9_mag.dat'), 'w');
for m = 0:9
    % aw=Inf: X path is independent of angle quantization
    [~, Xi_frac] = cordic_fixedpoint(inX_int(m+1) / 2^w_xy, ...
                                      inY_int(m+1) / 2^w_xy, ...
                                      S_min_even, w_xy, Inf);
    Xi_int_k = Xi_frac * 2^w_xy;   % convert back to integer domain
    mg_int = 0;
    for t = 1:length(csd_digits_nz)
        mg_int = mg_int + csd_digits_nz(t) * floor(Xi_int_k / 2^csd_shifts_nz(t));
    end
    fprintf(fid, '%03X\n', mod(mg_int, 2^W_xy));
end
fclose(fid);
fprintf('Written golden_step9_mag.dat  (10 entries)\n');

%% Figure: CSD error vs fw
fs = 13;
figure('Name', 'Step5 - CSD Error vs fw', 'Position', [100, 100, 900, 500]);

semilogy(fw_vec, err_csd, 'b-o', 'MarkerSize', 6, 'LineWidth', 1.5, ...
         'DisplayName', 'CSD relative error $|S_{csd} - S_{true}| / S_{true}$');
hold on;
yline(threshold, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', 'Threshold $0.1\%$');
semilogy(fw_min, err_csd(idx_ok), 'gs', 'MarkerSize', 10, 'LineWidth', 2, ...
         'DisplayName', sprintf('Min $f_w = %d$', fw_min));
hold off;

xlabel('CSD fractional word-length $f_w$ (bits)', 'FontSize', fs);
ylabel('Relative error of $S(N)$ approximation', 'FontSize', fs);
title(sprintf('Step 5: CSD Approximation Error vs. Word-Length ($N=%d$, $S_{true}=%.4f$)', ...
      N_mag, S_true), 'FontSize', fs);
legend('Location', 'southwest', 'FontSize', fs-1);
grid on; box on;
xlim([fw_vec(1)-0.5, fw_vec(end)+0.5]);
exportgraphics(gcf, fullfile(fig_dir, 'step5_csd_error.png'), 'Resolution', 150);

%% -----------------------------------------------------------------------
function csd = dec2csd(n, nbits)
% DEC2CSD  Convert non-negative integer n to CSD representation.
%   csd = dec2csd(n, nbits)
%   Returns nbits-element row vector, csd(1) = LSB, csd(end) = MSB.
%   Digits are in {-1, 0, +1}; no two adjacent elements are both non-zero.
csd = zeros(1, nbits);
for i = 1:nbits
    if mod(n, 2) == 0
        csd(i) = 0;
    elseif mod(n, 4) == 3
        csd(i) = -1;
        n = n + 1;
    else
        csd(i) = 1;
    end
    n = floor(n / 2);
end
end
