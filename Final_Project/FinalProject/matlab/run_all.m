clear; clc; close all;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
proj_dir = fileparts(this_dir);
root_dir = fileparts(proj_dir);

params.WI = 17;
params.WO = 17;
params.FRAC_W = 12;
params.ACC_W = 27;
params.CORDIC_STAGES = 10;
params.ITER_MAX = 7;
params.SCALE = 2^params.FRAC_W;

load(fullfile(root_dir, 'Final11Pattern.mat'));

summary_path = fullfile(this_dir, 'rmse_summary.txt');
expected_path = fullfile(this_dir, 'expected_matrix8_q12.txt');
input_path = fullfile(this_dir, 'matrix8_input_q12.txt');
all_input_path = fullfile(this_dir, 'all11_input_q12.txt');
all_expected_path = fullfile(this_dir, 'all11_expected_q12.txt');

eig_rmse = zeros(11, 1);
vec_rmse = zeros(11, 1);
fixed_lambda = zeros(3, 11);
fixed_vec = zeros(3, 3, 11);

for set_idx = 1:11
    A = Matrix(:, :, set_idx);
    Aq = quantize_matrix(A, params);
    [lambda_q, V_q] = fixed_qr_evd(Aq, params);

    [lambda_ref, V_ref] = reference_evd(A);
    [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref);

    eig_rmse(set_idx) = sqrt(mean((lambda_aligned - lambda_ref).^2));
    vec_rmse(set_idx) = sqrt(sum((V_aligned - V_ref).^2, 'all') / 9);
    fixed_lambda(:, set_idx) = lambda_aligned;
    fixed_vec(:, :, set_idx) = V_aligned;
end

fid = fopen(summary_path, 'w');
fprintf(fid, 'FinalProject bit-true QR EVD summary\n');
fprintf(fid, 'WI=%d WO=%d FRAC_W=%d ACC_W=%d CORDIC_STAGES=%d ITER_MAX=%d\n', ...
    params.WI, params.WO, params.FRAC_W, params.ACC_W, params.CORDIC_STAGES, params.ITER_MAX);
fprintf(fid, 'set eig_rmse vec_rmse\n');
for set_idx = 1:11
    fprintf(fid, '%02d %.10g %.10g\n', set_idx, eig_rmse(set_idx), vec_rmse(set_idx));
end
fprintf(fid, 'max_eig_rmse %.10g\n', max(eig_rmse));
fprintf(fid, 'max_vec_rmse %.10g\n', max(vec_rmse));
fclose(fid);

A8q = quantize_matrix(Matrix(:, :, 8), params);
[lambda8_q, V8_q, out_rows8] = fixed_qr_evd(A8q, params);

fid = fopen(input_path, 'w');
for c = 1:3
    fprintf(fid, '%d %d %d\n', A8q(1, c), A8q(2, c), A8q(3, c));
end
fclose(fid);

fid = fopen(expected_path, 'w');
for r = 1:4
    fprintf(fid, '%d %d %d\n', out_rows8(r, 1), out_rows8(r, 2), out_rows8(r, 3));
end
fclose(fid);

fid_in = fopen(all_input_path, 'w');
fid_exp = fopen(all_expected_path, 'w');
for set_idx = 1:11
    Aq = quantize_matrix(Matrix(:, :, set_idx), params);
    [~, ~, out_rows] = fixed_qr_evd(Aq, params);

    for c = 1:3
        fprintf(fid_in, '%d %d %d\n', Aq(1, c), Aq(2, c), Aq(3, c));
    end

    for r = 1:4
        fprintf(fid_exp, '%d %d %d\n', out_rows(r, 1), out_rows(r, 2), out_rows(r, 3));
    end
end
fclose(fid_in);
fclose(fid_exp);

fig1 = figure('Visible', 'off');
plot(1:11, eig_rmse, '-o', 1:11, vec_rmse, '-s', 'LineWidth', 1.5);
yline(1e-2, '--r');
grid on;
xlabel('Set index');
ylabel('RMSE');
legend('Eigenvalue RMSE', 'Eigenvector RMSE', '1e-2 criterion', 'Location', 'best');
title('Bit-true RMSE versus set index');
saveas(fig1, fullfile(this_dir, 'rmse_vs_set.png'));

word_fracs = 8:12;
word_eig = zeros(size(word_fracs));
word_vec = zeros(size(word_fracs));
for n = 1:numel(word_fracs)
    p = params;
    p.FRAC_W = word_fracs(n);
    p.SCALE = 2^p.FRAC_W;
    [word_eig(n), word_vec(n)] = sweep_error(Matrix, p);
end

fig2 = figure('Visible', 'off');
plot(word_fracs, word_eig, '-o', word_fracs, word_vec, '-s', 'LineWidth', 1.5);
yline(1e-2, '--r');
grid on;
xlabel('FRAC_W');
ylabel('Worst-case RMSE');
legend('Eigenvalue RMSE', 'Eigenvector RMSE', '1e-2 criterion', 'Location', 'best');
title('Worst-case RMSE versus fractional wordlength');
saveas(fig2, fullfile(this_dir, 'rmse_vs_wordlength.png'));

stage_list = 10:16;
stage_eig = zeros(size(stage_list));
stage_vec = zeros(size(stage_list));
for n = 1:numel(stage_list)
    p = params;
    p.CORDIC_STAGES = stage_list(n);
    [stage_eig(n), stage_vec(n)] = sweep_error(Matrix, p);
end

fig3 = figure('Visible', 'off');
plot(stage_list, stage_eig, '-o', stage_list, stage_vec, '-s', 'LineWidth', 1.5);
yline(1e-2, '--r');
grid on;
xlabel('CORDIC_STAGES');
ylabel('Worst-case RMSE');
legend('Eigenvalue RMSE', 'Eigenvector RMSE', '1e-2 criterion', 'Location', 'best');
title('Worst-case RMSE versus CORDIC stages');
saveas(fig3, fullfile(this_dir, 'rmse_vs_stages.png'));

disp(fileread(summary_path));
fprintf('Generated:\n');
fprintf('  %s\n', summary_path);
fprintf('  %s\n', expected_path);
fprintf('  %s\n', input_path);
fprintf('  %s\n', all_input_path);
fprintf('  %s\n', all_expected_path);
fprintf('  %s\n', fullfile(this_dir, 'rmse_vs_set.png'));
fprintf('  %s\n', fullfile(this_dir, 'rmse_vs_wordlength.png'));
fprintf('  %s\n', fullfile(this_dir, 'rmse_vs_stages.png'));

function Aq = quantize_matrix(A, params)
    Aq = round(A * params.SCALE);
    Aq = min(max(Aq, -2^(params.WI - 1)), 2^(params.WI - 1) - 1);
end

function [max_eig, max_vec] = sweep_error(Matrix, params)
    eig_rmse = zeros(11, 1);
    vec_rmse = zeros(11, 1);

    for set_idx = 1:11
        A = Matrix(:, :, set_idx);
        Aq = quantize_matrix(A, params);
        [lambda_q, V_q] = fixed_qr_evd(Aq, params);
        [lambda_ref, V_ref] = reference_evd(A);
        [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref);

        eig_rmse(set_idx) = sqrt(mean((lambda_aligned - lambda_ref).^2));
        vec_rmse(set_idx) = sqrt(sum((V_aligned - V_ref).^2, 'all') / 9);
    end

    max_eig = max(eig_rmse);
    max_vec = max(vec_rmse);
end

function [lambda_ref, V_ref] = reference_evd(A)
    [V_ref, D_ref] = eig(A);
    [lambda_ref, idx] = sort(diag(D_ref), 'descend');
    V_ref = V_ref(:, idx);
end

function [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref)
    [lambda_aligned, idx] = sort(lambda_q, 'descend');
    V_aligned = V_q(:, idx);

    for c = 1:3
        if dot(V_aligned(:, c), V_ref(:, c)) < 0
            V_aligned(:, c) = -V_aligned(:, c);
        end
    end
end

function [lambda_q, V_q, out_rows] = fixed_qr_evd(Aq, params)
    A = double(Aq);
    U = eye(3) * params.SCALE;
    dir_store = zeros(3, params.CORDIC_STAGES);

    for iter = 1:params.ITER_MAX
        [A, dir_store(1, :)] = qr_left_rotation(A, 1, 2, 1, params);
        [A, dir_store(2, :)] = qr_left_rotation(A, 1, 3, 1, params);
        [A, dir_store(3, :)] = qr_left_rotation(A, 2, 3, 2, params);

        for r = 1:3
            [A(r, 1), A(r, 2)] = cordic_run(A(r, 1), A(r, 2), 0, dir_store(1, :), params);
        end
        for r = 1:3
            [A(r, 1), A(r, 3)] = cordic_run(A(r, 1), A(r, 3), 0, dir_store(2, :), params);
        end
        for r = 1:3
            [A(r, 2), A(r, 3)] = cordic_run(A(r, 2), A(r, 3), 0, dir_store(3, :), params);
        end

        for r = 1:3
            [U(r, 1), U(r, 2)] = cordic_run(U(r, 1), U(r, 2), 0, dir_store(1, :), params);
        end
        for r = 1:3
            [U(r, 1), U(r, 3)] = cordic_run(U(r, 1), U(r, 3), 0, dir_store(2, :), params);
        end
        for r = 1:3
            [U(r, 2), U(r, 3)] = cordic_run(U(r, 2), U(r, 3), 0, dir_store(3, :), params);
        end
    end

    lambda_q = diag(A) / params.SCALE;
    V_q = U / params.SCALE;
    out_rows = [diag(A).'; U];
    out_rows = min(max(round(out_rows), -2^(params.WO - 1)), 2^(params.WO - 1) - 1);
end

function [A, dirs] = qr_left_rotation(A, r1, r2, col, params)
    [x0, ~, dirs] = cordic_run(A(r1, col), A(r2, col), 1, zeros(1, params.CORDIC_STAGES), params);
    A(r1, col) = x0;
    A(r2, col) = 0;

    for c = col + 1:3
        [A(r1, c), A(r2, c)] = cordic_run(A(r1, c), A(r2, c), 0, dirs, params);
    end
end

function [x_out, y_out, dirs] = cordic_run(x_in, y_in, vectoring, dirs_in, params)
    x = x_in;
    y = y_in;
    dirs = dirs_in;
    pre_neg = false;

    if vectoring && x < 0
        x = -x;
        y = -y;
        pre_neg = true;
    end

    for k = 0:params.CORDIC_STAGES - 1
        x_shift = ashift(x, k);
        y_shift = ashift(y, k);

        if vectoring
            dir = y < 0;
            dirs(k + 1) = dir;
        else
            dir = dirs(k + 1);
        end

        if dir == 0
            nx = x + y_shift;
            ny = y - x_shift;
        else
            nx = x - y_shift;
            ny = y + x_shift;
        end

        x = nx;
        y = ny;
    end

    x_out = gain_comp(x);
    y_out = gain_comp(y);

    if vectoring && pre_neg
        x_out = -x_out;
        y_out = -y_out;
    end
end

function y = gain_comp(x)
    product = x * 39797;
    if product < 0
        y = floor((product - 32768) / 2^16);
    else
        y = floor((product + 32768) / 2^16);
    end
end

function y = ashift(x, n)
    y = floor(x / 2^n);
end
