clear; clc; close all;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
proj_dir = fileparts(this_dir);
root_dir = fileparts(proj_dir);

load(fullfile(root_dir, 'Final11Pattern.mat'));

base.ITER_MAX = 7;
base.WO_EQUALS_WI = true;

wi_list = 16:20;
frac_list = 8:14;
stage_list = 8:16;
acc_guard_list = 10:14;

max_abs_input = max(abs(Matrix), [], 'all');
rows = [];

for wi = wi_list
    for frac_w = frac_list
        scale = 2^frac_w;
        max_representable = (2^(wi - 1) - 1) / scale;
        input_fits = max_abs_input <= max_representable;

        for acc_guard = acc_guard_list
            acc_w = wi + acc_guard;
            for stages = stage_list
                params.WI = wi;
                params.WO = wi;
                params.FRAC_W = frac_w;
                params.ACC_W = acc_w;
                params.CORDIC_STAGES = stages;
                params.ITER_MAX = base.ITER_MAX;
                params.SCALE = scale;

                if input_fits
                    [max_eig, max_vec, any_overflow] = sweep_error(Matrix, params);
                    pass = (max_eig < 1e-2) && (max_vec < 1e-2) && ~any_overflow;
                else
                    max_eig = inf;
                    max_vec = inf;
                    any_overflow = true;
                    pass = false;
                end

                area_proxy = area_estimate(params);
                cycle_proxy = cycle_estimate(params);
                at_proxy = area_proxy * cycle_proxy;

                rows = [rows; wi, wi, frac_w, acc_w, stages, ...
                    max_eig, max_vec, any_overflow, pass, area_proxy, cycle_proxy, at_proxy]; %#ok<AGROW>
            end
        end
    end
end

var_names = {'WI','WO','FRAC_W','ACC_W','CORDIC_STAGES', ...
    'max_eig_rmse','max_vec_rmse','overflow','pass','area_proxy','cycle_proxy','at_proxy'};
result_table = array2table(rows, 'VariableNames', var_names);

csv_path = fullfile(this_dir, 'wordlength_sweep.csv');
writetable(result_table, csv_path);

pass_table = result_table(result_table.pass == 1, :);
pass_table = sortrows(pass_table, {'at_proxy','area_proxy','cycle_proxy'});

summary_path = fullfile(this_dir, 'wordlength_sweep_summary.txt');
fid = fopen(summary_path, 'w');
fprintf(fid, 'Wordlength sweep summary\n');
fprintf(fid, 'Input max abs = %.10f\n', max_abs_input);
fprintf(fid, 'Candidate WI = %s\n', mat2str(wi_list));
fprintf(fid, 'Candidate FRAC_W = %s\n', mat2str(frac_list));
fprintf(fid, 'Candidate CORDIC_STAGES = %s\n', mat2str(stage_list));
fprintf(fid, 'Candidate ACC_W = WI + %s\n\n', mat2str(acc_guard_list));
fprintf(fid, 'Pass criterion: max eigenvalue RMSE < 1e-2, max eigenvector RMSE < 1e-2, no input/internal overflow.\n\n');
fprintf(fid, 'Area-time proxy formula:\n');
fprintf(fid, '  area_proxy = 18*ACC_W + 3*CORDIC_STAGES + 3*(2*ACC_W + CORDIC_STAGES + 8) + 3*2*ACC_W + 3*ACC_W*4 + 180\n');
fprintf(fid, '  cycle_proxy = 3 + ITER_MAX * 12 * (CORDIC_STAGES + 2) + 4\n');
fprintf(fid, '  at_proxy = area_proxy * cycle_proxy\n');
fprintf(fid, '  This is only a pre-synthesis ranking proxy; final AT must use DC area and timing reports.\n\n');

if isempty(pass_table)
    fprintf(fid, 'No passing candidate found.\n');
else
    best = pass_table(1, :);
    fprintf(fid, 'Best candidate by AT proxy:\n');
    fprintf(fid, 'WI=%d WO=%d FRAC_W=%d ACC_W=%d CORDIC_STAGES=%d ITER_MAX=%d\n', ...
        best.WI, best.WO, best.FRAC_W, best.ACC_W, best.CORDIC_STAGES, base.ITER_MAX);
    fprintf(fid, 'max_eig_rmse=%.10g max_vec_rmse=%.10g area_proxy=%.0f cycle_proxy=%.0f at_proxy=%.0f\n\n', ...
        best.max_eig_rmse, best.max_vec_rmse, best.area_proxy, best.cycle_proxy, best.at_proxy);

    fprintf(fid, 'Top 12 passing candidates:\n');
    fprintf(fid, 'WI WO FRAC_W ACC_W STAGES eig_rmse vec_rmse area_proxy cycle_proxy at_proxy\n');
    for k = 1:min(12, height(pass_table))
        row = pass_table(k, :);
        fprintf(fid, '%d %d %d %d %d %.10g %.10g %.0f %.0f %.0f\n', ...
            row.WI, row.WO, row.FRAC_W, row.ACC_W, row.CORDIC_STAGES, ...
            row.max_eig_rmse, row.max_vec_rmse, row.area_proxy, row.cycle_proxy, row.at_proxy);
    end
end
fclose(fid);

fig = figure('Visible', 'off');
pass_plot = result_table(result_table.WI == 18 & result_table.ACC_W == 30 & result_table.CORDIC_STAGES == 10, :);
plot(pass_plot.FRAC_W, pass_plot.max_eig_rmse, '-o', ...
     pass_plot.FRAC_W, pass_plot.max_vec_rmse, '-s', 'LineWidth', 1.5);
yline(1e-2, '--r');
grid on;
xlabel('FRAC_W');
ylabel('Worst-case RMSE');
legend('Eigenvalue RMSE', 'Eigenvector RMSE', '1e-2 criterion', 'Location', 'best');
title('Wordlength sweep slice: WI=18, ACC_W=30, CORDIC_STAGES=10');
saveas(fig, fullfile(this_dir, 'wordlength_sweep_slice.png'));

disp(fileread(summary_path));
fprintf('Generated:\n');
fprintf('  %s\n', csv_path);
fprintf('  %s\n', summary_path);
fprintf('  %s\n', fullfile(this_dir, 'wordlength_sweep_slice.png'));

function [max_eig, max_vec, any_overflow] = sweep_error(Matrix, params)
    eig_rmse = zeros(11, 1);
    vec_rmse = zeros(11, 1);
    overflow_flags = false(11, 1);

    for set_idx = 1:11
        A = Matrix(:, :, set_idx);
        Aq = quantize_matrix(A, params);
        [lambda_q, V_q, overflow_flags(set_idx)] = fixed_qr_evd(Aq, params);
        [lambda_ref, V_ref] = reference_evd(A);
        [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref);

        eig_rmse(set_idx) = sqrt(mean((lambda_aligned - lambda_ref).^2));
        vec_rmse(set_idx) = sqrt(sum((V_aligned - V_ref).^2, 'all') / 9);
    end

    max_eig = max(eig_rmse);
    max_vec = max(vec_rmse);
    any_overflow = any(overflow_flags);
end

function Aq = quantize_matrix(A, params)
    Aq = round(A * params.SCALE);
    Aq = min(max(Aq, -2^(params.WI - 1)), 2^(params.WI - 1) - 1);
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

function [lambda_q, V_q, any_overflow] = fixed_qr_evd(Aq, params)
    A = double(Aq);
    U = eye(3) * params.SCALE;
    dir_store = zeros(3, params.CORDIC_STAGES);
    any_overflow = false;

    [A, of] = wrap_matrix(A, params);
    any_overflow = any_overflow || of;

    for iter = 1:params.ITER_MAX
        [A, dir_store(1, :), of] = qr_left_rotation(A, 1, 2, 1, params);
        any_overflow = any_overflow || of;
        [A, dir_store(2, :), of] = qr_left_rotation(A, 1, 3, 1, params);
        any_overflow = any_overflow || of;
        [A, dir_store(3, :), of] = qr_left_rotation(A, 2, 3, 2, params);
        any_overflow = any_overflow || of;

        for r = 1:3
            [A(r, 1), A(r, 2), ~, of] = cordic_run(A(r, 1), A(r, 2), 0, dir_store(1, :), params);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [A(r, 1), A(r, 3), ~, of] = cordic_run(A(r, 1), A(r, 3), 0, dir_store(2, :), params);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [A(r, 2), A(r, 3), ~, of] = cordic_run(A(r, 2), A(r, 3), 0, dir_store(3, :), params);
            any_overflow = any_overflow || of;
        end

        for r = 1:3
            [U(r, 1), U(r, 2), ~, of] = cordic_run(U(r, 1), U(r, 2), 0, dir_store(1, :), params);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [U(r, 1), U(r, 3), ~, of] = cordic_run(U(r, 1), U(r, 3), 0, dir_store(2, :), params);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [U(r, 2), U(r, 3), ~, of] = cordic_run(U(r, 2), U(r, 3), 0, dir_store(3, :), params);
            any_overflow = any_overflow || of;
        end
    end

    lambda_q = diag(A) / params.SCALE;
    V_q = U / params.SCALE;
end

function [A, dirs, any_overflow] = qr_left_rotation(A, r1, r2, col, params)
    any_overflow = false;
    [x0, ~, dirs, of] = cordic_run(A(r1, col), A(r2, col), 1, zeros(1, params.CORDIC_STAGES), params);
    any_overflow = any_overflow || of;
    A(r1, col) = x0;
    A(r2, col) = 0;

    for c = col + 1:3
        [A(r1, c), A(r2, c), ~, of] = cordic_run(A(r1, c), A(r2, c), 0, dirs, params);
        any_overflow = any_overflow || of;
    end
end

function [x_out, y_out, dirs, any_overflow] = cordic_run(x_in, y_in, vectoring, dirs_in, params)
    x = x_in;
    y = y_in;
    dirs = dirs_in;
    pre_neg = false;
    any_overflow = false;

    if vectoring && x < 0
        x = -x;
        y = -y;
        pre_neg = true;
    end

    [x, of_x] = wrap_signed(x, params.ACC_W);
    [y, of_y] = wrap_signed(y, params.ACC_W);
    any_overflow = any_overflow || of_x || of_y;

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

        [x, of_x] = wrap_signed(nx, params.ACC_W);
        [y, of_y] = wrap_signed(ny, params.ACC_W);
        any_overflow = any_overflow || of_x || of_y;
    end

    [x_out, of_x] = gain_comp(x, params);
    [y_out, of_y] = gain_comp(y, params);
    any_overflow = any_overflow || of_x || of_y;

    if vectoring && pre_neg
        [x_out, of_x] = wrap_signed(-x_out, params.ACC_W);
        [y_out, of_y] = wrap_signed(-y_out, params.ACC_W);
        any_overflow = any_overflow || of_x || of_y;
    end
end

function [y, any_overflow] = gain_comp(x, params)
    product = x * 39797;
    if product < 0
        raw = floor((product - 32768) / 2^16);
    else
        raw = floor((product + 32768) / 2^16);
    end
    [y, any_overflow] = wrap_signed(raw, params.ACC_W);
end

function [M, any_overflow] = wrap_matrix(M, params)
    any_overflow = false;
    for i = 1:numel(M)
        [M(i), of] = wrap_signed(M(i), params.ACC_W);
        any_overflow = any_overflow || of;
    end
end

function [y, any_overflow] = wrap_signed(x, width)
    min_val = -2^(width - 1);
    max_val = 2^(width - 1) - 1;
    any_overflow = (x < min_val) || (x > max_val);
    modulus = 2^width;
    y = mod(x + 2^(width - 1), modulus) - 2^(width - 1);
end

function y = ashift(x, n)
    y = floor(x / 2^n);
end

function area = area_estimate(params)
    matrix_regs = 18 * params.ACC_W;
    dir_regs = 3 * params.CORDIC_STAGES;
    cordic_regs = 3 * (2 * params.ACC_W + params.CORDIC_STAGES + 8);
    cordic_adders = 3 * 2 * params.ACC_W;
    gain_mult = 3 * params.ACC_W * 4;
    control = 180;
    area = matrix_regs + dir_regs + cordic_regs + cordic_adders + gain_mult + control;
end

function cycles = cycle_estimate(params)
    rotations_per_iter = 3 + 3 + 3 + 3;
    cycles_per_rotation_group = params.CORDIC_STAGES + 2;
    load_cycles = 3;
    output_cycles = 4;
    cycles = load_cycles + params.ITER_MAX * rotations_per_iter * cycles_per_rotation_group + output_cycles;
end
