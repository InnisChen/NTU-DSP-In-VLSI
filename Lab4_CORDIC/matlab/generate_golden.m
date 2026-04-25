%% generate_golden.m
% Generates bit-exact golden answer files for TESTBED.v comparison.
% Run this ONCE before simulation to enable bit-exact mismatch detection.
%
% Output files written to 00_TESTBED/src/:
%   golden_step6.dat       -- outTheta (m=0,3,6,9)
%   golden_step7.dat       -- outTheta (m=0..9)
%   golden_step9_theta.dat -- outTheta (m=0..9)
%   golden_step9_mag.dat   -- outMag   (m=0..9)

clear; clc;

%% Parameters (must match Verilog)
w        = 12;
aw       = 10;
S        = 12;
SCALE_XY = 2^w;         % 4096
SCALE_TH = 2^aw;        % 1024
W        = w + 2;       % 14 bits  (1S+1I+12F)
TW       = 1 + 2 + aw;  % 13 bits  (1S+2I+10F)

%% Test inputs (must match TESTBED.v, m = 0..9)
inX_int = [ 3896;  2408;     0; -2408; -3896; -3896; -2408;     0;  2408;  3896];
inY_int = [ 1266;  3314;  4096;  3314;  1266; -1266; -3314; -4096; -3314; -1266];

%% Output directory
out_dir = fullfile(fileparts(mfilename('fullpath')), '..', '00_TESTBED', 'src');

%% Run MATLAB fixed-point model for each test input
golden_theta = zeros(10, 1, 'int32');
golden_mag   = zeros(10, 1, 'int32');

for k = 1:10
    [theta_f, mag_f] = cordic_fixedpoint( ...
        inX_int(k) / SCALE_XY, inY_int(k) / SCALE_XY, S, w, aw);

    % theta: raw integer = theta_f * SCALE_TH (already integer internally)
    theta_int = round(theta_f * SCALE_TH);
    theta_int = max(-(2^(TW-1)), min(2^(TW-1)-1, theta_int));
    golden_theta(k) = theta_int;

    % mag: Xi_int -> CSD scaling (matches hardware Verilog >>> shifts)
    Xi_int  = round(mag_f * SCALE_XY);
    mag_int = floor(Xi_int/2)   + floor(Xi_int/8) ...
            - floor(Xi_int/64)  - floor(Xi_int/512);
    mag_int = max(-(2^(W-1)), min(2^(W-1)-1, mag_int));
    golden_mag(k) = mag_int;
end

%% Write files (TW-bit or W-bit 2's complement hex, one value per line)
write_hex(fullfile(out_dir, 'golden_step9_theta.dat'), golden_theta, TW);
write_hex(fullfile(out_dir, 'golden_step9_mag.dat'),   golden_mag,   W);
write_hex(fullfile(out_dir, 'golden_step7.dat'),       golden_theta, TW);

% step6: m=0,3,6,9 -> indices 1,4,7,10
write_hex(fullfile(out_dir, 'golden_step6.dat'), golden_theta([1,4,7,10]), TW);

%% Print summary
fprintf('Golden files written to:\n  %s\n\n', out_dir);
fprintf('  m | theta_int | outMag_int\n');
fprintf('----|-----------|------------\n');
for k = 1:10
    fprintf('  %d | %9d | %10d\n', k-1, golden_theta(k), golden_mag(k));
end

%% -----------------------------------------------------------------------
function write_hex(path, vals, N)
% Write signed integer array as N-bit 2's complement hex, one per line.
    fid = fopen(path, 'w');
    if fid < 0
        error('Cannot open %s for writing.', path);
    end
    for i = 1:length(vals)
        v = double(vals(i));
        if v < 0
            v = v + 2^N;
        end
        fprintf(fid, '%0*X\n', ceil(N/4), v);
    end
    fclose(fid);
end
