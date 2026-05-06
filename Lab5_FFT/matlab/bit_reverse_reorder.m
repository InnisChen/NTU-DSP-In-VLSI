function [x_normal, idx_br] = bit_reverse_reorder(x_br)
%BIT_REVERSE_REORDER Convert DIF FFT bit-reversed output to normal order.
    N = size(x_br, 1);
    idx_br = bit_reverse_indices(N);

    x_normal = zeros(size(x_br));
    for p = 1:N
        x_normal(idx_br(p) + 1, :) = x_br(p, :);
    end
end
