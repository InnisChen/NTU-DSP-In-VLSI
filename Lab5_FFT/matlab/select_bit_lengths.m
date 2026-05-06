function result = select_bit_lengths(x_stream, ref_fft_normal, wf_candidates, target_sqnr, margin_db)
%SELECT_BIT_LENGTHS Sequentially choose stage and twiddle fractional bits.
    if nargin < 5
        margin_db = 1.0;
    end

    x_stream = x_stream(:);
    ref_fft_normal = reshape(ref_fft_normal, 32, []);
    wf_stage = repmat(max(wf_candidates), 1, 5);
    stage_sqnr = zeros(5, numel(wf_candidates));
    chosen_stage_sqnr = zeros(1, 5);

    for stage = 1:5
        active = false(1, 5);
        active(1:stage) = true;

        for c = 1:numel(wf_candidates)
            trial_wf = wf_stage;
            trial_wf(stage) = wf_candidates(c);

            X_br = sdf_fft32_fixed(x_stream, trial_wf, max(wf_candidates), active, false);
            X_normal = bit_reverse_reorder(X_br);
            stage_sqnr(stage, c) = calc_sqnr(ref_fft_normal, X_normal);
        end

        chosen_idx = find(stage_sqnr(stage, :) >= target_sqnr + margin_db, 1, 'first');
        if isempty(chosen_idx)
            chosen_idx = find(stage_sqnr(stage, :) >= target_sqnr, 1, 'first');
        end
        if isempty(chosen_idx)
            [~, chosen_idx] = max(stage_sqnr(stage, :));
        end

        wf_stage(stage) = wf_candidates(chosen_idx);
        chosen_stage_sqnr(stage) = stage_sqnr(stage, chosen_idx);
    end

    twiddle_sqnr = zeros(1, numel(wf_candidates));
    for c = 1:numel(wf_candidates)
        X_br = sdf_fft32_fixed(x_stream, wf_stage, wf_candidates(c), true(1, 5), true);
        X_normal = bit_reverse_reorder(X_br);
        twiddle_sqnr(c) = calc_sqnr(ref_fft_normal, X_normal);
    end

    chosen_twiddle_idx = find(twiddle_sqnr >= target_sqnr + margin_db, 1, 'first');
    if isempty(chosen_twiddle_idx)
        chosen_twiddle_idx = find(twiddle_sqnr >= target_sqnr, 1, 'first');
    end
    if isempty(chosen_twiddle_idx)
        [~, chosen_twiddle_idx] = max(twiddle_sqnr);
    end

    result.wf_candidates = wf_candidates;
    result.target_sqnr = target_sqnr;
    result.margin_db = margin_db;
    result.wf_stage = wf_stage;
    result.stage_sqnr = stage_sqnr;
    result.chosen_stage_sqnr = chosen_stage_sqnr;
    result.wf_twiddle = wf_candidates(chosen_twiddle_idx);
    result.twiddle_sqnr = twiddle_sqnr;
    result.chosen_twiddle_sqnr = twiddle_sqnr(chosen_twiddle_idx);
end
