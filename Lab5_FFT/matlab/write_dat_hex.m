function write_dat_hex(filename, values, data_w, frac_w)
%WRITE_DAT_HEX Write signed fixed-point values as two's-complement hex.
    q = fixed_to_int(values(:), data_w, frac_w);
    width = ceil(data_w / 4);
    modulo = int64(2)^data_w;

    fid = fopen(filename, 'w');
    assert(fid > 0, 'Cannot open output file: %s', filename);
    cleaner = onCleanup(@() fclose(fid));

    for n = 1:numel(q)
        v = q(n);
        if v < 0
            v = v + modulo;
        end
        fprintf(fid, ['%0' num2str(width) 'X\n'], v);
    end
end
