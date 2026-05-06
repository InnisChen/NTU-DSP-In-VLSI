function x = read_dat_hex(filename, data_w, frac_w)
%READ_DAT_HEX Read two's-complement hex fixed-point values.
    lines = readlines(filename);
    lines = strip(lines);
    lines(lines == "") = [];

    raw = zeros(numel(lines), 1);
    for n = 1:numel(lines)
        raw(n) = hex2dec(char(lines(n)));
    end

    sign_threshold = 2^(data_w - 1);
    modulo = 2^data_w;
    signed_val = raw;
    signed_val(raw >= sign_threshold) = raw(raw >= sign_threshold) - modulo;
    x = signed_val / 2^frac_w;
end
