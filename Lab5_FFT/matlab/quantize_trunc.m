function y = quantize_trunc(x, wf)
%QUANTIZE_TRUNC Truncate real and imaginary parts toward zero.
    if isempty(wf) || isinf(wf)
        y = x;
        return;
    end

    scale = 2^wf;
    y = complex(fix(real(x) * scale) / scale, fix(imag(x) * scale) / scale);
end
