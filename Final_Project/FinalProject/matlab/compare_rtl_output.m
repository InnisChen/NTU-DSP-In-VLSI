clear; clc;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

expected_path = fullfile(this_dir, 'expected_matrix8_q12.txt');
rtl_path = fullfile(this_dir, 'rtl_output_matrix8_q12.txt');

expected = readmatrix(expected_path);
rtl = readmatrix(rtl_path);

if ~isequal(size(expected), size(rtl))
    error('Output shape mismatch: expected %s, got %s', mat2str(size(expected)), mat2str(size(rtl)));
end

diff_val = rtl - expected;
max_abs = max(abs(diff_val), [], 'all');

fprintf('Max absolute fixed-point difference = %d\n', max_abs);
disp('RTL output:');
disp(rtl);
disp('Expected output:');
disp(expected);

if max_abs ~= 0
    error('RTL output does not match bit-true expected output.');
end

fprintf('PASS: RTL output matches bit-true expected Matrix(:,:,8).\n');
