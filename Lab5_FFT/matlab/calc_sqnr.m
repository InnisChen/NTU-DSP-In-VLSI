function sqnr_db = calc_sqnr(reference, candidate)
%CALC_SQNR Compute SQNR in dB for complex-valued outputs.
    reference = reference(:);
    candidate = candidate(:);
    noise = reference - candidate;

    signal_power = mean(abs(reference).^2);
    noise_power = mean(abs(noise).^2);

    if noise_power == 0
        sqnr_db = Inf;
    else
        sqnr_db = 10 * log10(signal_power / noise_power);
    end
end
