%PLOT_RTL_ERRORS Read RTL simulation output .dat files and draw error plots.
clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(script_dir);
fig_dir = fullfile(root_dir, 'figure');
result_dir = fullfile(script_dir, 'results');
dat_dir = fullfile(root_dir, 'RTL_Code', 'non_pipeline', '01_RTL', 'src');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(result_dir, 'dir'), mkdir(result_dir); end

addpath(script_dir);

param_file = fullfile(dat_dir, 'fft32_params.vh');
[data_w, frac_w] = read_param_file(param_file);

plot_pair(dat_dir, fig_dir, result_dir, data_w, frac_w, ...
          'rtl_sdf32', 'golden_sdf32', 32, ...
          'step8_rtl_sdf_error.png', 'step8_rtl_sdf_error.csv', ...
          'Step 8: RTL SDFOut error vs MATLAB fixed model');

plot_pair(dat_dir, fig_dir, result_dir, data_w, frac_w, ...
          'rtl_br32', 'golden_br32', 32, ...
          'step8_rtl_br_error.png', 'step8_rtl_br_error.csv', ...
          'Step 8: RTL BROut error vs MATLAB fixed model');

sqnr_sdf96 = plot_pair(dat_dir, fig_dir, result_dir, data_w, frac_w, ...
                       'rtl_sdf96', 'golden_sdf96', 96, ...
                       'step9_rtl_sdf_error.png', 'step9_rtl_sdf_error.csv', ...
                       'Step 9: RTL SDFOut error vs MATLAB fixed model');

sqnr_br96 = plot_pair(dat_dir, fig_dir, result_dir, data_w, frac_w, ...
                      'rtl_br96', 'golden_br96', 96, ...
                      'step9_rtl_br_error.png', 'step9_rtl_br_error.csv', ...
                      'Step 9: RTL BROut error vs MATLAB fixed model');

writematrix([sqnr_sdf96; sqnr_br96], fullfile(result_dir, 'rtl_error_sqnr.txt'));
fprintf('Step 9 RTL SDF SQNR vs fixed golden: %.2f dB\n', sqnr_sdf96);
fprintf('Step 9 RTL BR SQNR vs fixed golden: %.2f dB\n', sqnr_br96);

function sqnr_db = plot_pair(dat_dir, fig_dir, result_dir, data_w, frac_w, rtl_stem, golden_stem, expected_len, png_name, csv_name, plot_title)
    rtl = read_complex_dat(dat_dir, rtl_stem, data_w, frac_w);
    golden = read_complex_dat(dat_dir, golden_stem, data_w, frac_w);

    len = min([numel(rtl), numel(golden), expected_len]);
    rtl = rtl(1:len);
    golden = golden(1:len);
    err = rtl - golden;
    sqnr_db = calc_sqnr(golden, rtl);

    writematrix([(0:len-1).', real(err), imag(err)], fullfile(result_dir, csv_name));
    save_complex_error_plot(fullfile(fig_dir, png_name), 0:len-1, err, sprintf('%s, SQNR = %.2f dB', plot_title, sqnr_db));
end

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
