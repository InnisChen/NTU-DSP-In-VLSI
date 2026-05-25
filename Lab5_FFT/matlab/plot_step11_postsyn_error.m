%PLOT_STEP11_POSTSYN_ERROR Draw Step 11 post-synthesis output error.
clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(script_dir);
fig_dir = fullfile(root_dir, 'figure');
dat_dir = fullfile(root_dir, 'Innis_DSP_LAB5', 'pipeline', '01_RTL', 'src');

if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

addpath(script_dir);

param_file = fullfile(dat_dir, 'fft32_params.vh');
[data_w, frac_w] = read_param_file(param_file);

rtl = read_complex_dat(dat_dir, 'rtl_br96', data_w, frac_w);
golden = read_complex_dat(dat_dir, 'golden_br96', data_w, frac_w);

sample_count = 96;
rtl = rtl(1:sample_count);
golden = golden(1:sample_count);
err = rtl - golden;

save_complex_error_plot(fullfile(fig_dir, 'step11_postsyn_real_imag_error.png'), ...
                        0:sample_count-1, err, ...
                        'Step 11: Post-synthesis BROut error vs MATLAB fixed model');

fprintf('Step 11 max real error: %.6g\n', max(abs(real(err))));
fprintf('Step 11 max imag error: %.6g\n', max(abs(imag(err))));
fprintf('Step 11 output SQNR vs fixed golden: %.2f dB\n', calc_sqnr(golden, rtl));

function x = read_complex_dat(dat_dir, stem, data_w, frac_w)
    re = read_dat_hex(fullfile(dat_dir, [stem '_re.dat']), data_w, frac_w);
    im = read_dat_hex(fullfile(dat_dir, [stem '_im.dat']), data_w, frac_w);
    x = complex(re, im);
end

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

function [data_w, frac_w] = read_param_file(filename)
    txt = fileread(filename);
    data_w = read_define(txt, 'FFT32_DATA_W');
    frac_w = read_define(txt, 'FFT32_FRAC_W');
end

function value = read_define(txt, name)
    token = regexp(txt, ['`define\s+' name '\s+(\d+)'], 'tokens', 'once');
    assert(~isempty(token), 'Cannot find parameter %s.', name);
    value = str2double(token{1});
end
