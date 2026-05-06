%RUN_ALL Generate Homework 5 MATLAB results and RTL vectors.
clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(script_dir);
fig_dir = fullfile(root_dir, 'figure');
result_dir = fullfile(script_dir, 'results');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(result_dir, 'dir'), mkdir(result_dir); end

addpath(script_dir);

input_mat = fullfile(root_dir, 'FFTInput32.mat');
load(input_mat, 'FFTIn32');
x32 = FFTIn32(:);

% Step 1 and Step 2: floating SDF FFT and bit-reversal check.
[X32_br, idx_br] = sdf_fft32_float(x32);
[X32_normal, ~] = bit_reverse_reorder(X32_br);
X32_ref = fft(x32);
step2_abs_err = abs(X32_normal - X32_ref);

assert(max(step2_abs_err) < 1e-10, 'Floating SDF FFT error is too large.');

step1_array = [(idx_br(:)), real(X32_br(:)), imag(X32_br(:))];
writematrix(step1_array, fullfile(result_dir, 'step1_bit_reversed_outputs.csv'));

fig = figure('Visible', 'off');
subplot(2, 1, 1);
stem(0:31, real(X32_normal), 'filled');
grid on; xlabel('Frequency index'); ylabel('Real');
title('Step 2: Real part of reordered X_0 to X_31');
subplot(2, 1, 2);
stem(0:31, imag(X32_normal), 'filled');
grid on; xlabel('Frequency index'); ylabel('Imag');
title('Step 2: Imaginary part of reordered X_0 to X_31');
saveas(fig, fullfile(fig_dir, 'step2_real_imag.png'));
close(fig);

fig = figure('Visible', 'off');
stem(0:31, step2_abs_err, 'filled');
grid on; xlabel('Frequency index'); ylabel('Absolute error');
title('Step 2: Absolute error against MATLAB fft');
saveas(fig, fullfile(fig_dir, 'step2_abs_error.png'));
close(fig);

% Step 3: generate 96 samples from QPSK-like frequency-domain symbols.
rng(20260506);
alphabet = [1 + 1j; 1 - 1j; -1 + 1j; -1 - 1j];
A96 = zeros(32, 3);
x96 = zeros(32, 3);
for sym = 1:3
    A96(:, sym) = alphabet(randi(numel(alphabet), 32, 1));
    x96(:, sym) = ifft(A96(:, sym));
end

wf_candidates = 9:18;
target_sqnr = 35;
margin_db = 1.5;
bit_result = select_bit_lengths(x96(:), A96, wf_candidates, target_sqnr, margin_db);

writematrix(bit_result.stage_sqnr, fullfile(result_dir, 'step3_stage_sqnr.csv'));
writematrix([wf_candidates(:), bit_result.twiddle_sqnr(:)], fullfile(result_dir, 'step3_twiddle_sqnr.csv'));
writematrix([bit_result.wf_stage(:); bit_result.wf_twiddle], fullfile(result_dir, 'chosen_fraction_bits.txt'));
save(fullfile(result_dir, 'matlab_results.mat'), ...
     'x32', 'X32_br', 'X32_normal', 'X32_ref', 'step2_abs_err', ...
     'A96', 'x96', 'bit_result');

for stage = 1:5
    fig = figure('Visible', 'off');
    plot(wf_candidates, bit_result.stage_sqnr(stage, :), '-o', 'LineWidth', 1.5);
    yline(target_sqnr, '--r', '35 dB');
    grid on; xlabel('Fractional word length');
    ylabel('SQNR (dB)');
    title(sprintf('Step 3: Stage %d SQNR sweep', stage));
    saveas(fig, fullfile(fig_dir, sprintf('step3_stage%d_sqnr.png', stage)));
    close(fig);
end

fig = figure('Visible', 'off');
plot(wf_candidates, bit_result.twiddle_sqnr, '-o', 'LineWidth', 1.5);
yline(target_sqnr, '--r', '35 dB');
grid on; xlabel('Twiddle fractional word length');
ylabel('SQNR (dB)');
title('Step 3: Twiddle ROM SQNR sweep');
saveas(fig, fullfile(fig_dir, 'step3_twiddle_sqnr.png'));
close(fig);

% RTL vectors use a stable global binary point. Stage truncation still uses
% the selected per-stage fractional bits.
data_w = 24;
frac_w = 18;

% Step 8 and Step 9 model-side error plots.  These are the expected
% fixed-point quantization errors before comparing RTL waveforms.
x32_q = quantize_trunc(x32, frac_w);
x96_q = quantize_trunc(x96(:), frac_w);
[X32_fixed_br, ~] = sdf_fft32_fixed(x32_q, bit_result.wf_stage, bit_result.wf_twiddle, true(1, 5), true);
step8_sdf_error = X32_fixed_br(:) - X32_br(:);
writematrix([(0:31).', real(step8_sdf_error), imag(step8_sdf_error)], ...
            fullfile(result_dir, 'step8_model_sdf_error.csv'));
save_complex_error_plot(fullfile(fig_dir, 'step8_model_sdf_error.png'), ...
                        0:31, step8_sdf_error, ...
                        'Step 8: MATLAB fixed-point SDF error vs floating SDF');

[X96_fixed_br, ~] = sdf_fft32_fixed(x96_q, bit_result.wf_stage, bit_result.wf_twiddle, true(1, 5), true);
X96_fixed_normal = bit_reverse_reorder(X96_fixed_br);
step9_br_error = X96_fixed_normal(:) - A96(:);
step9_model_sqnr = calc_sqnr(A96(:), X96_fixed_normal(:));
writematrix([(0:95).', real(step9_br_error), imag(step9_br_error)], ...
            fullfile(result_dir, 'step9_model_br_error.csv'));
writematrix(step9_model_sqnr, fullfile(result_dir, 'step9_model_sqnr.txt'));
save_complex_error_plot(fullfile(fig_dir, 'step9_model_br_error.png'), ...
                        0:95, step9_br_error, ...
                        sprintf('Step 9: MATLAB fixed-point BR error, SQNR = %.2f dB', step9_model_sqnr));

vector_info = gen_vectors(root_dir, x32, x96(:), bit_result.wf_stage, bit_result.wf_twiddle, data_w, frac_w);
save(fullfile(result_dir, 'rtl_vector_info.mat'), 'vector_info', 'data_w', 'frac_w');

fprintf('Step 2 max floating error: %.3e\n', max(step2_abs_err));
fprintf('Chosen wf_stage: [%s]\n', num2str(bit_result.wf_stage));
fprintf('Chosen wf_twiddle: %d\n', bit_result.wf_twiddle);
fprintf('RTL vectors generated in: %s\n', vector_info.dat_dir);

function save_complex_error_plot(filename, sample_idx, err, plot_title)
    fig = figure('Visible', 'off');
    subplot(2, 1, 1);
    stem(sample_idx, real(err(:)), 'filled');
    grid on; xlabel('Sample index'); ylabel('Real error');
    title(plot_title);
    subplot(2, 1, 2);
    stem(sample_idx, imag(err(:)), 'filled');
    grid on; xlabel('Sample index'); ylabel('Imag error');
    saveas(fig, filename);
    close(fig);
end
