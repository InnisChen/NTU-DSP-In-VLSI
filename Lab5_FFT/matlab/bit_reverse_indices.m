function idx = bit_reverse_indices(N)
%BIT_REVERSE_INDICES Return zero-based bit-reversed indices for N points.
    m = log2(N);
    assert(abs(m - round(m)) < eps, 'N must be a power of two.');
    m = round(m);

    idx = zeros(N, 1);
    for n = 0:N-1
        r = 0;
        v = n;
        for b = 1:m
            r = bitshift(r, 1) + bitand(v, 1);
            v = bitshift(v, -1);
        end
        idx(n + 1) = r;
    end
end
