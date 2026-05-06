function [X_br, idx_br, stage_data] = sdf_fft32_fixed(x, wf_stage, wf_twiddle, quant_stage, quant_twiddle)
%SDF_FFT32_FIXED Fixed-point 32-point DIF FFT model aligned to RTL.
    N = 32;
    x = x(:);
    assert(mod(numel(x), N) == 0, 'Input length must be a multiple of 32.');

    if isscalar(wf_stage)
        wf_stage = repmat(wf_stage, 1, 5);
    end
    if nargin < 4 || isempty(quant_stage)
        quant_stage = true(1, 5);
    end
    if nargin < 5 || isempty(quant_twiddle)
        quant_twiddle = true;
    end

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

                    sum_v = a + b;
                    diff_v = a - b;
                    if quant_stage(stage)
                        sum_v = quantize_trunc(sum_v, wf_stage(stage));
                        diff_v = quantize_trunc(diff_v, wf_stage(stage));
                    end

                    twiddle = exp(-1j * 2 * pi * (n * step) / N);
                    if quant_twiddle
                        twiddle = quantize_trunc(twiddle, wf_twiddle);
                    end

                    prod_v = diff_v * twiddle;
                    if quant_stage(stage)
                        prod_v = quantize_trunc(prod_v, wf_stage(stage));
                    end

                    y(i_upper) = sum_v;
                    y(i_lower) = prod_v;
                end
            end
            stage_data{stage}(:, sym) = y;
        end
        X_br(:, sym) = y;
    end

    idx_br = bit_reverse_indices(N);
end
