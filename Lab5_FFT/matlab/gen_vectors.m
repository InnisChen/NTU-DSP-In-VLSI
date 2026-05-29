function vector_info = gen_vectors(root_dir, x32, x96, wf_stage, wf_twiddle, data_w, frac_w, twiddle_w)
%GEN_VECTORS Generate RTL input and golden .dat files.
    if nargin < 8
        twiddle_w = data_w;
    end
    rtl_roots = {
        fullfile(root_dir, 'RTL_Code', 'non_pipeline')
        fullfile(root_dir, 'RTL_Code', 'pipeline')
    };

    x32_q = quantize_trunc(x32(:), frac_w);
    x96_q = quantize_trunc(x96(:), frac_w);

    [golden_sdf32, idx_br] = sdf_fft32_fixed(x32_q, wf_stage, wf_twiddle, true(1, 5), true);
    golden_br32 = bit_reverse_reorder(golden_sdf32);

    golden_sdf96 = sdf_fft32_fixed(x96_q, wf_stage, wf_twiddle, true(1, 5), true);
    golden_br96 = bit_reverse_reorder(golden_sdf96);

    twiddle = exp(-1j * 2 * pi * (0:15).' / 32);
    twiddle_q = quantize_trunc(twiddle, wf_twiddle);

    dat_dirs = cell(size(rtl_roots));
    for r = 1:numel(rtl_roots)
        flow_root = rtl_roots{r};
        dat_dir = fullfile(flow_root, '01_RTL', 'src');
        if ~exist(dat_dir, 'dir')
            mkdir(dat_dir);
        end

        write_complex_dat(fullfile(dat_dir, 'fftinput32'), x32_q, data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'stream96'), x96_q, data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'golden_sdf32'), golden_sdf32(:), data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'golden_br32'), golden_br32(:), data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'golden_sdf96'), golden_sdf96(:), data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'golden_br96'), golden_br96(:), data_w, frac_w);
        write_complex_dat(fullfile(dat_dir, 'twiddle_rom32'), twiddle_q, twiddle_w, wf_twiddle);

        write_params(fullfile(dat_dir, 'fft32_params.vh'), data_w, frac_w, twiddle_w, wf_stage, wf_twiddle, '../01_RTL/src');

        tb_param = fullfile(flow_root, '00_TESTBED', 'fft32_params.vh');
        if exist(fileparts(tb_param), 'dir')
            write_params(tb_param, data_w, frac_w, twiddle_w, wf_stage, wf_twiddle, '../01_RTL/src');
        end

        dat_dirs{r} = dat_dir;
    end

    vector_info.dat_dirs = dat_dirs;
    vector_info.idx_br = idx_br;
    vector_info.golden_sdf32 = golden_sdf32;
    vector_info.golden_br32 = golden_br32;
    vector_info.golden_sdf96 = golden_sdf96;
    vector_info.golden_br96 = golden_br96;
    vector_info.twiddle_w = twiddle_w;
end

function write_complex_dat(stem, x, data_w, frac_w)
    write_dat_hex([stem '_re.dat'], real(x), data_w, frac_w);
    write_dat_hex([stem '_im.dat'], imag(x), data_w, frac_w);
end

function write_params(filename, data_w, frac_w, twiddle_w, wf_stage, wf_twiddle, dat_dir)
    fid = fopen(filename, 'w');
    assert(fid > 0, 'Cannot open output file: %s', filename);
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '`ifndef FFT32_PARAMS_VH\n');
    fprintf(fid, '`define FFT32_PARAMS_VH\n');
    fprintf(fid, '`define FFT32_DATA_W %d\n', data_w);
    fprintf(fid, '`define FFT32_FRAC_W %d\n', frac_w);
    fprintf(fid, '`define FFT32_TWIDDLE_W %d\n', twiddle_w);
    dat_dir_v = strrep(dat_dir, '\', '/');
    fprintf(fid, '`define FFT32_DAT_DIR "%s"\n', dat_dir_v);
    for s = 1:5
        fprintf(fid, '`define FFT32_WF_STAGE%d %d\n', s, wf_stage(s));
    end
    fprintf(fid, '`define FFT32_WF_TWIDDLE %d\n', wf_twiddle);
    fprintf(fid, '`endif\n');
end
