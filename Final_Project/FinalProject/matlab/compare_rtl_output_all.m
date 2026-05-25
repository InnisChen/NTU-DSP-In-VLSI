clear; clc;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

num_sets = 11;
rows_per_set = 4;

expected_path = fullfile(this_dir, 'all11_expected_q12.txt');
rtl_path = fullfile(this_dir, 'rtl_output_all11_q12.txt');
summary_path = fullfile(this_dir, 'rtl_all11_compare_summary.txt');

expected = readmatrix(expected_path);
rtl = readmatrix(rtl_path);

if ~isequal(size(expected), size(rtl))
    error('Output shape mismatch: expected %s, got %s', mat2str(size(expected)), mat2str(size(rtl)));
end

expected_rows = num_sets * rows_per_set;
if size(rtl, 1) ~= expected_rows || size(rtl, 2) ~= 3
    error('Unexpected all11 output shape: got %s, expected [%d 3]', mat2str(size(rtl)), expected_rows);
end

diff_val = rtl - expected;
overall_max_abs = max(abs(diff_val), [], 'all');

fid = fopen(summary_path, 'w');
if fid < 0
    error('Cannot open summary file: %s', summary_path);
end

fprintf('All-11 RTL fixed-point comparison\n');
fprintf('Overall max absolute fixed-point difference = %d\n', overall_max_abs);
fprintf(fid, 'All-11 RTL fixed-point comparison\n');
fprintf(fid, 'Overall max absolute fixed-point difference = %d\n', overall_max_abs);
fprintf(fid, '\nPer-set max absolute fixed-point difference:\n');

for set_idx = 1:num_sets
    row_range = (set_idx - 1) * rows_per_set + (1:rows_per_set);
    set_max_abs = max(abs(diff_val(row_range, :)), [], 'all');
    fprintf('  set%02d max_abs_diff = %d\n', set_idx, set_max_abs);
    fprintf(fid, 'set%02d max_abs_diff = %d\n', set_idx, set_max_abs);
end

fclose(fid);

if overall_max_abs ~= 0
    error('All-11 RTL output does not match bit-true expected output.');
end

fprintf('PASS: all 11 RTL outputs match bit-true expected data.\n');
fprintf('Generated: %s\n', summary_path);
