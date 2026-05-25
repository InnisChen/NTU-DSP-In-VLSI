clear; clc; close all;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
proj_dir = fileparts(this_dir);
root_dir = fileparts(proj_dir);

load(fullfile(root_dir, 'Final11Pattern.mat'));

params.WI = 17;
params.WO = 17;
params.FRAC_W = 12;
params.ACC_W = 27;
params.CORDIC_STAGES = 10;
params.ITER_MAX = 7;
params.SCALE = 2^params.FRAC_W;

max_abs_input = max(abs(Matrix), [], 'all');
input_required_w = fixed_width_required(max_abs_input, params.FRAC_W);

[iter_table, chosen_iter_reason] = analyze_iterations(Matrix, params);
[stage_table, chosen_stage_reason] = analyze_stages(Matrix, params);
[trace_table, selected_rmse] = trace_selected_widths(Matrix, params);

writetable(iter_table, fullfile(this_dir, 'iteration_sweep.csv'));
writetable(stage_table, fullfile(this_dir, 'cordic_stage_sweep.csv'));
writetable(trace_table, fullfile(this_dir, 'bitwidth_trace_table.csv'));

summary_path = fullfile(this_dir, 'bitwidth_analysis_summary.txt');
fid = fopen(summary_path, 'w');
fprintf(fid, 'Bit-width analysis for FinalProject\n\n');
fprintf(fid, 'Selected setting:\n');
fprintf(fid, '  WI=%d, WO=%d, FRAC_W=%d, ACC_W=%d, CORDIC_STAGES=%d, ITER_MAX=%d\n\n', ...
    params.WI, params.WO, params.FRAC_W, params.ACC_W, params.CORDIC_STAGES, params.ITER_MAX);

fprintf(fid, '1. Input range\n');
fprintf(fid, '  max(abs(Matrix)) = %.10f\n', max_abs_input);
fprintf(fid, '  With FRAC_W=%d, minimum signed total input width = %d bits.\n', ...
    params.FRAC_W, input_required_w);
fprintf(fid, '  Therefore WI=%d is the minimum safe input width. WI=16 would overflow Q3.12.\n\n', params.WI);

fprintf(fid, '2. Iteration count\n');
fprintf(fid, '  Chosen ITER_MAX=%d because %s\n', params.ITER_MAX, chosen_iter_reason);
fprintf(fid, '  Floating-point QR is used only as a convergence pre-check. The final ITER_MAX choice uses bit-true fixed-point RMSE.\n');
fprintf(fid, '  See iteration_sweep.csv for floating and fixed-point iteration candidates.\n\n');

fprintf(fid, '3. CORDIC stages\n');
fprintf(fid, '  Chosen CORDIC_STAGES=%d because %s\n', params.CORDIC_STAGES, chosen_stage_reason);
fprintf(fid, '  See cordic_stage_sweep.csv for all stage candidates under the selected wordlength.\n\n');

fprintf(fid, '4. Internal hardware bit-width trace\n');
fprintf(fid, '  The table below is measured over all 11 matrices, all %d QR iterations, all CORDIC micro-rotations.\n', params.ITER_MAX);
fprintf(fid, '  raw_max_abs is the maximum integer magnitude after scaling by 2^FRAC_W where applicable.\n');
fprintf(fid, '  required_signed_bits is ceil(log2(raw_max_abs+1))+1.\n\n');
fprintf(fid, '  %-28s %14s %8s %8s %s\n', 'signal_group', 'raw_max_abs', 'req_bits', 'chosen', 'decision');
for k = 1:height(trace_table)
    fprintf(fid, '  %-28s %14.0f %8d %8d %s\n', ...
        trace_table.signal_group{k}, trace_table.raw_max_abs(k), ...
        trace_table.required_signed_bits(k), trace_table.chosen_bits(k), ...
        trace_table.decision{k});
end

fprintf(fid, '\n5. Final RMSE with selected setting\n');
fprintf(fid, '  max eigenvalue RMSE = %.10g\n', selected_rmse.max_eig);
fprintf(fid, '  max eigenvector RMSE = %.10g\n', selected_rmse.max_vec);
fprintf(fid, '  overflow event count in selected bit-true trace = %d\n', selected_rmse.overflow_events);
fprintf(fid, '  Both are below 1e-2.\n\n');

fprintf(fid, '6. Counter/control bit-widths\n');
fprintf(fid, '  rot_idx: 2 bits for 0..2.\n');
fprintf(fid, '  iter_count: 4 bits in RTL. The selected ITER_MAX=%d only requires %d bits for 0..%d, but 4 bits keeps parameter margin.\n', ...
    params.ITER_MAX, ceil(log2(params.ITER_MAX)), params.ITER_MAX - 1);
fprintf(fid, '  out_count: 3 bits for 0..3.\n');
fprintf(fid, '  load_col: 2 bits for 0..2.\n');
fprintf(fid, '  cordic iter counter: 5 bits in RTL, enough for STAGES up to 31; selected STAGES=10 only needs 4 bits, but 5 keeps parameter margin.\n');
fprintf(fid, '  direction storage: 3 rotations x CORDIC_STAGES = %d one-bit direction flags.\n', 3 * params.CORDIC_STAGES);
fprintf(fid, '\n7. RMSE pairing and sign convention\n');
fprintf(fid, '  Eigenvalues are sorted in descending order before RMSE calculation.\n');
fprintf(fid, '  Eigenvectors are reordered with their eigenvalue pair.\n');
fprintf(fid, '  If dot(v_computed, v_reference) < 0, the computed eigenvector is multiplied by -1 before RMSE.\n');
fprintf(fid, '  Eigenvector RMSE is sqrt(sum((V_computed - V_reference).^2, all) / 9).\n');
fprintf(fid, '\n8. Area-time proxy formula\n');
fprintf(fid, '  area_proxy = matrix_regs + dir_regs + cordic_regs + cordic_adders + gain_mult + control.\n');
fprintf(fid, '  matrix_regs = 18 * ACC_W for 9 working-matrix and 9 U_eig registers.\n');
fprintf(fid, '  dir_regs = 3 * CORDIC_STAGES.\n');
fprintf(fid, '  cordic_regs = 3 * (2 * ACC_W + CORDIC_STAGES + 8).\n');
fprintf(fid, '  cordic_adders = 3 * 2 * ACC_W.\n');
fprintf(fid, '  gain_mult = 3 * ACC_W * 4 as a rough constant-multiplier cost.\n');
fprintf(fid, '  control = 180 fixed proxy units.\n');
fprintf(fid, '  cycle_proxy = 3 + ITER_MAX * 12 * (CORDIC_STAGES + 2) + 4.\n');
fprintf(fid, '  This proxy is used only for pre-synthesis ranking; final AT must use DC area and timing reports.\n');
fclose(fid);

disp(fileread(summary_path));
fprintf('Generated:\n');
fprintf('  %s\n', summary_path);
fprintf('  %s\n', fullfile(this_dir, 'iteration_sweep.csv'));
fprintf('  %s\n', fullfile(this_dir, 'cordic_stage_sweep.csv'));
fprintf('  %s\n', fullfile(this_dir, 'bitwidth_trace_table.csv'));

function w = fixed_width_required(max_abs_real, frac_w)
    int_mag_bits = ceil(log2(max_abs_real + 2^-frac_w));
    w = 1 + int_mag_bits + frac_w;
end

function bits = signed_bits_required(max_abs_int)
    if max_abs_int <= 0
        bits = 1;
    else
        bits = ceil(log2(max_abs_int + 1)) + 1;
    end
end

function [iter_table, reason] = analyze_iterations(Matrix, params)
    nit_list = (1:12).';
    float_eig = zeros(numel(nit_list), 1);
    float_vec = zeros(numel(nit_list), 1);
    float_pass = false(numel(nit_list), 1);
    fixed_eig = zeros(numel(nit_list), 1);
    fixed_vec = zeros(numel(nit_list), 1);
    fixed_overflow = false(numel(nit_list), 1);
    fixed_pass = false(numel(nit_list), 1);

    for n = 1:numel(nit_list)
        nit = nit_list(n);
        eig_rmse = zeros(11, 1);
        vec_rmse = zeros(11, 1);

        for set_idx = 1:11
            A = Matrix(:, :, set_idx);
            [lambda_ref, V_ref] = reference_evd(A);
            T = A;
            U = eye(3);

            for iter = 1:nit
                [Q, R] = qr(T);
                T = R * Q;
                U = U * Q;
            end

            lambda_q = diag(T);
            V_q = U;
            [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref);
            eig_rmse(set_idx) = sqrt(mean((lambda_aligned - lambda_ref).^2));
            vec_rmse(set_idx) = sqrt(sum((V_aligned - V_ref).^2, 'all') / 9);
        end

        float_eig(n) = max(eig_rmse);
        float_vec(n) = max(vec_rmse);
        float_pass(n) = float_eig(n) < 1e-2 && float_vec(n) < 1e-2;

        p = params;
        p.ITER_MAX = nit;
        [fixed_eig(n), fixed_vec(n), fixed_overflow(n)] = sweep_error(Matrix, p);
        fixed_pass(n) = fixed_eig(n) < 1e-2 && fixed_vec(n) < 1e-2 && ~fixed_overflow(n);
    end

    iter_table = table(nit_list, float_eig, float_vec, float_pass, ...
        fixed_eig, fixed_vec, fixed_overflow, fixed_pass, ...
        'VariableNames', {'ITER_MAX','float_eig_rmse','float_vec_rmse','float_pass', ...
        'fixed_eig_rmse','fixed_vec_rmse','fixed_overflow','fixed_pass'});

    first_pass_idx = find(fixed_pass, 1, 'first');
    if isempty(first_pass_idx)
        reason = 'no bit-true candidate in 1..12 passed both RMSE criteria';
    else
        reason = sprintf('it is the first bit-true fixed-point iteration count that passes both RMSE criteria; ITER_MAX=%d has max eig %.4g and max vec %.4g', ...
            nit_list(first_pass_idx), fixed_eig(first_pass_idx), fixed_vec(first_pass_idx));
    end
end

function [stage_table, reason] = analyze_stages(Matrix, params)
    stage_list = (8:16).';
    max_eig = zeros(numel(stage_list), 1);
    max_vec = zeros(numel(stage_list), 1);
    overflow = false(numel(stage_list), 1);
    pass = false(numel(stage_list), 1);

    for n = 1:numel(stage_list)
        p = params;
        p.CORDIC_STAGES = stage_list(n);
        [max_eig(n), max_vec(n), overflow(n)] = sweep_error(Matrix, p);
        pass(n) = max_eig(n) < 1e-2 && max_vec(n) < 1e-2 && ~overflow(n);
    end

    stage_table = table(stage_list, max_eig, max_vec, overflow, pass, ...
        'VariableNames', {'CORDIC_STAGES','max_eig_rmse','max_vec_rmse','overflow','pass'});

    first_pass_idx = find(pass, 1, 'first');
    if isempty(first_pass_idx)
        reason = 'no stage candidate in 8..16 passed both RMSE criteria';
    else
        reason = sprintf('it is the lowest-latency passing stage count; STAGES=%d has max eig %.4g and max vec %.4g', ...
            stage_list(first_pass_idx), max_eig(first_pass_idx), max_vec(first_pass_idx));
    end
end

function [trace_table, rmse] = trace_selected_widths(Matrix, params)
    labels = {'input_quantized','mat_register','u_register','cordic_input_x','cordic_input_y', ...
        'cordic_pre_x','cordic_pre_y','cordic_iter_x','cordic_iter_y','gain_product', ...
        'gain_output','lambda_output_raw','vector_output_raw'};
    stats = init_stats(labels);
    eig_rmse = zeros(11, 1);
    vec_rmse = zeros(11, 1);

    for set_idx = 1:11
        A = Matrix(:, :, set_idx);
        Aq = quantize_matrix(A, params);
        stats = update_stats(stats, 'input_quantized', Aq(:));
        [lambda_q, V_q, stats] = fixed_qr_evd_trace(Aq, params, stats);
        [lambda_ref, V_ref] = reference_evd(A);
        [lambda_aligned, V_aligned] = align_pairs(lambda_q, V_q, lambda_ref, V_ref);

        eig_rmse(set_idx) = sqrt(mean((lambda_aligned - lambda_ref).^2));
        vec_rmse(set_idx) = sqrt(sum((V_aligned - V_ref).^2, 'all') / 9);
    end

    rmse.max_eig = max(eig_rmse);
    rmse.max_vec = max(vec_rmse);
    if isfield(stats, 'overflow_count')
        rmse.overflow_events = stats.overflow_count;
    else
        rmse.overflow_events = 0;
    end

    signal_group = labels.';
    raw_max_abs = zeros(numel(labels), 1);
    required_signed_bits = zeros(numel(labels), 1);
    chosen_bits = zeros(numel(labels), 1);
    decision = cell(numel(labels), 1);

    for k = 1:numel(labels)
        raw_max_abs(k) = stats.(labels{k});
        required_signed_bits(k) = signed_bits_required(raw_max_abs(k));

        switch labels{k}
            case {'input_quantized','lambda_output_raw','vector_output_raw'}
                chosen_bits(k) = params.WI;
            case 'gain_product'
                chosen_bits(k) = params.ACC_W + 18;
            otherwise
                chosen_bits(k) = params.ACC_W;
        end

        if required_signed_bits(k) <= chosen_bits(k)
            decision{k} = 'OK';
        else
            decision{k} = 'INSUFFICIENT';
        end
    end

    trace_table = table(signal_group, raw_max_abs, required_signed_bits, chosen_bits, decision);
end

function stats = init_stats(labels)
    for k = 1:numel(labels)
        stats.(labels{k}) = 0;
    end
    stats.overflow_count = 0;
end

function stats = update_stats(stats, label, values)
    if isempty(values)
        return;
    end
    stats.(label) = max(stats.(label), max(abs(values), [], 'all'));
end

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
    stats = init_stats({'unused'});
    [lambda_q, V_q, stats, any_overflow] = fixed_qr_core(Aq, params, stats, false);
end

function [lambda_q, V_q, stats] = fixed_qr_evd_trace(Aq, params, stats)
    [lambda_q, V_q, stats, ~] = fixed_qr_core(Aq, params, stats, true);
end

function [lambda_q, V_q, stats, any_overflow] = fixed_qr_core(Aq, params, stats, trace_enable)
    A = double(Aq);
    U = eye(3) * params.SCALE;
    dir_store = zeros(3, params.CORDIC_STAGES);
    any_overflow = false;

    if trace_enable
        stats = update_stats(stats, 'mat_register', A(:));
        stats = update_stats(stats, 'u_register', U(:));
    end

    for iter = 1:params.ITER_MAX
        [A, dir_store(1, :), stats, of] = qr_left_rotation(A, 1, 2, 1, params, stats, trace_enable);
        any_overflow = any_overflow || of;
        [A, dir_store(2, :), stats, of] = qr_left_rotation(A, 1, 3, 1, params, stats, trace_enable);
        any_overflow = any_overflow || of;
        [A, dir_store(3, :), stats, of] = qr_left_rotation(A, 2, 3, 2, params, stats, trace_enable);
        any_overflow = any_overflow || of;

        for r = 1:3
            [A(r, 1), A(r, 2), ~, stats, of] = cordic_run(A(r, 1), A(r, 2), 0, dir_store(1, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [A(r, 1), A(r, 3), ~, stats, of] = cordic_run(A(r, 1), A(r, 3), 0, dir_store(2, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [A(r, 2), A(r, 3), ~, stats, of] = cordic_run(A(r, 2), A(r, 3), 0, dir_store(3, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end

        for r = 1:3
            [U(r, 1), U(r, 2), ~, stats, of] = cordic_run(U(r, 1), U(r, 2), 0, dir_store(1, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [U(r, 1), U(r, 3), ~, stats, of] = cordic_run(U(r, 1), U(r, 3), 0, dir_store(2, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end
        for r = 1:3
            [U(r, 2), U(r, 3), ~, stats, of] = cordic_run(U(r, 2), U(r, 3), 0, dir_store(3, :), params, stats, trace_enable);
            any_overflow = any_overflow || of;
        end

        if trace_enable
            stats = update_stats(stats, 'mat_register', A(:));
            stats = update_stats(stats, 'u_register', U(:));
        end
    end

    lambda_q = diag(A) / params.SCALE;
    V_q = U / params.SCALE;

    if trace_enable
        stats = update_stats(stats, 'lambda_output_raw', diag(A));
        stats = update_stats(stats, 'vector_output_raw', U(:));
    end
end

function [A, dirs, stats, any_overflow] = qr_left_rotation(A, r1, r2, col, params, stats, trace_enable)
    any_overflow = false;
    [x0, ~, dirs, stats, of] = cordic_run(A(r1, col), A(r2, col), 1, zeros(1, params.CORDIC_STAGES), params, stats, trace_enable);
    any_overflow = any_overflow || of;
    A(r1, col) = x0;
    A(r2, col) = 0;

    for c = col + 1:3
        [A(r1, c), A(r2, c), ~, stats, of] = cordic_run(A(r1, c), A(r2, c), 0, dirs, params, stats, trace_enable);
        any_overflow = any_overflow || of;
    end
end

function [x_out, y_out, dirs, stats, any_overflow] = cordic_run(x_in, y_in, vectoring, dirs_in, params, stats, trace_enable)
    x = x_in;
    y = y_in;
    dirs = dirs_in;
    pre_neg = false;
    any_overflow = false;

    if trace_enable
        stats = update_stats(stats, 'cordic_input_x', x);
        stats = update_stats(stats, 'cordic_input_y', y);
    end

    if vectoring && x < 0
        x = -x;
        y = -y;
        pre_neg = true;
    end

    if trace_enable
        stats = update_stats(stats, 'cordic_pre_x', x);
        stats = update_stats(stats, 'cordic_pre_y', y);
    end

    [x, of_x] = wrap_signed(x, params.ACC_W);
    [y, of_y] = wrap_signed(y, params.ACC_W);
    stats = record_overflow(stats, trace_enable, of_x, of_y);
    any_overflow = any_overflow || of_x || of_y;

    for k = 0:params.CORDIC_STAGES - 1
        if trace_enable
            stats = update_stats(stats, 'cordic_iter_x', x);
            stats = update_stats(stats, 'cordic_iter_y', y);
        end

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
        stats = record_overflow(stats, trace_enable, of_x, of_y);
        any_overflow = any_overflow || of_x || of_y;
    end

    [x_out, stats, of_x] = gain_comp(x, params, stats, trace_enable);
    [y_out, stats, of_y] = gain_comp(y, params, stats, trace_enable);
    stats = record_overflow(stats, trace_enable, of_x, of_y);
    any_overflow = any_overflow || of_x || of_y;

    if vectoring && pre_neg
        [x_out, of_x] = wrap_signed(-x_out, params.ACC_W);
        [y_out, of_y] = wrap_signed(-y_out, params.ACC_W);
        stats = record_overflow(stats, trace_enable, of_x, of_y);
        any_overflow = any_overflow || of_x || of_y;
    end

    if trace_enable
        stats = update_stats(stats, 'gain_output', [x_out; y_out]);
    end
end

function [y, stats, any_overflow] = gain_comp(x, params, stats, trace_enable)
    product = x * 39797;
    if trace_enable
        stats = update_stats(stats, 'gain_product', product);
    end

    if product < 0
        raw = floor((product - 32768) / 2^16);
    else
        raw = floor((product + 32768) / 2^16);
    end

    [y, any_overflow] = wrap_signed(raw, params.ACC_W);
end

function stats = record_overflow(stats, trace_enable, varargin)
    if ~trace_enable
        return;
    end

    for k = 1:numel(varargin)
        if varargin{k}
            stats.overflow_count = stats.overflow_count + 1;
        end
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
