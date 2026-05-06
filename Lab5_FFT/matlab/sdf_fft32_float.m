function [X_br, idx_br, stage_data] = sdf_fft32_float(x)
%SDF_FFT32_FLOAT 32-point radix-2 DIF FFT model with bit-reversed output.
    N = 32;
    x = x(:);
    assert(mod(numel(x), N) == 0, 'Input length must be a multiple of 32.');

    num_symbols = numel(x) / N;
    x = reshape(x, N, num_symbols);
    X_br = zeros(N, num_symbols);
    stage_data = cell(5, 1);
    for s = 1:5
        stage_data{s} = zeros(N, num_symbols);
    end

    for sym = 1:num_symbols
        y = x(:, sym);
        for stage = 1:5
            span = N / 2^(stage - 1);
            half = span / 2;
            step = N / span;

            for block = 1:span:N
                for n = 0:half-1
                    i_upper = block + n;
                    i_lower = i_upper + half;

                    a = y(i_upper);
                    b = y(i_lower);
                    twiddle = exp(-1j * 2 * pi * (n * step) / N);

                    y(i_upper) = a + b;
                    y(i_lower) = (a - b) * twiddle;
                end
            end
            stage_data{stage}(:, sym) = y;
        end
        X_br(:, sym) = y;
    end

    idx_br = bit_reverse_indices(N);
end
