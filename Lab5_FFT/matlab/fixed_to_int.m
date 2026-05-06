function q = fixed_to_int(x, data_w, frac_w)
%FIXED_TO_INT Convert fixed-point real values to signed integers.
    scale = 2^frac_w;
    q = fix(x * scale);

    min_q = -2^(data_w - 1);
    max_q = 2^(data_w - 1) - 1;
    q = min(max(q, min_q), max_q);
    q = int64(q);
end
