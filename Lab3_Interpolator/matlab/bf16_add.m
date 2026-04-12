function result = bf16_add(a, b)
%BF16_ADD  BF16 floating-point addition with truncation (no rounding).
%
%  result = bf16_add(a, b)
%
%  a, b   : BF16 values as uint16 (or any integer coercible to uint16)
%  result : BF16 result as uint16
%
%  Simplifications (per assignment):
%    - Subnormals (E = 0) are treated as exact zero.
%    - Truncation: shifted-out bits and extra mantissa bits are discarded.
%    - No NaN / Infinity handling.

a = uint16(a);
b = uint16(b);

% --- Extract S / E / F ---
S_a = double(bitshift(a, -15));
E_a = double(bitand(bitshift(a, -7), uint16(255)));
F_a = double(bitand(a, uint16(127)));

S_b = double(bitshift(b, -15));
E_b = double(bitand(bitshift(b, -7), uint16(255)));
F_b = double(bitand(b, uint16(127)));

% --- Subnormal (E = 0) -> treat as zero ---
if E_a == 0 && E_b == 0
    result = uint16(0); return;
end
if E_a == 0, result = b; return; end
if E_b == 0, result = a; return; end

% --- Full mantissa with implicit leading 1: integer in [128, 255] ---
M_a = 128 + F_a;
M_b = 128 + F_b;

% --- Sort so that E_a >= E_b (swap if needed) ---
if E_a < E_b
    [S_a, E_a, M_a, S_b, E_b, M_b] = deal(S_b, E_b, M_b, S_a, E_a, M_a);
end

% --- Align M_b: right-shift with truncation ---
shift = E_a - E_b;
if shift >= 8
    M_b = 0;          % all mantissa bits shifted out
else
    M_b = floor(M_b / 2^shift);
end

% --- Signed addition ---
val = (1 - 2*S_a)*M_a + (1 - 2*S_b)*M_b;

if val == 0
    result = uint16(0); return;
end

% --- Result sign and magnitude ---
S_r = double(val < 0);
M_r = abs(val);
E_r = E_a;

% --- Normalise: overflow (9-bit result >= 256) ---
if M_r >= 256
    M_r = floor(M_r / 2);   % truncate LSB
    E_r = E_r + 1;
end

% --- Normalise: leading zeros (< 128) ---
while M_r < 128 && E_r > 0
    M_r = M_r * 2;
    E_r = E_r - 1;
end

% --- Underflow -> zero ---
if E_r <= 0
    result = uint16(0); return;
end

% --- Overflow clamp (no Inf required by assignment) ---
if E_r >= 255
    E_r = 254;
    M_r = 255;
end

% --- Truncate: keep only 7 fraction bits (drop implicit leading 1) ---
F_r = mod(M_r, 128);

result = uint16(S_r*32768 + E_r*128 + F_r);
end
