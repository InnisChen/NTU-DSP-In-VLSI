function result = bf16_mul(a, b)
%BF16_MUL  BF16 floating-point multiplication with truncation (no rounding).
%
%  result = bf16_mul(a, b)
%
%  a, b   : BF16 values as uint16 (or any integer coercible to uint16)
%  result : BF16 result as uint16
%
%  Simplifications (per assignment):
%    - Subnormals (E = 0) are treated as exact zero.
%    - Truncation: extra mantissa bits from the product are discarded.
%    - No NaN / Infinity handling.
%
%  Mantissa product:
%    Both M_a, M_b are 8-bit integers (implicit 1 at bit 7, range [128,255]).
%    Product P = M_a * M_b is 14 or 15 bits:
%      P in [16384, 32767]  -> implicit 1 at bit 14: right-shift 7, E unchanged
%      P in [32768, 65025]  -> implicit 1 at bit 15: right-shift 8, E += 1

a = uint16(a);
b = uint16(b);

% --- Extract S / E / F ---
S_a = double(bitshift(a, -15));
E_a = double(bitand(bitshift(a, -7), uint16(255)));
F_a = double(bitand(a, uint16(127)));

S_b = double(bitshift(b, -15));
E_b = double(bitand(bitshift(b, -7), uint16(255)));
F_b = double(bitand(b, uint16(127)));

% --- Subnormal -> zero ---
if E_a == 0 || E_b == 0
    result = uint16(0); return;
end

% --- Result sign: XOR ---
S_r = double(xor(logical(S_a), logical(S_b)));

% --- Result exponent: add biased exponents and remove one bias ---
E_r = E_a + E_b - 127;

% --- Mantissa product (8-bit x 8-bit -> 14 or 15 bits) ---
M_a = 128 + F_a;
M_b = 128 + F_b;
P   = M_a * M_b;   % range: [16384, 65025]

% --- Normalise and truncate to 8-bit mantissa (implicit 1 at bit 7) ---
if P >= 32768          % implicit 1 at bit 15: right-shift 8 bits, E_r += 1
    M_r = floor(P / 256);
    E_r = E_r + 1;
else                   % implicit 1 at bit 14: right-shift 7 bits
    M_r = floor(P / 128);
end
% M_r: 8-bit value, bit7 = implicit 1, bits[6:0] = 7 fraction bits

% --- Underflow -> zero ---
if E_r <= 0
    result = uint16(0); return;
end

% --- Overflow clamp ---
if E_r >= 255
    E_r = 254;
    M_r = 255;
end

% --- Extract 7 fraction bits ---
F_r = mod(M_r, 128);

result = uint16(S_r*32768 + E_r*128 + F_r);
end
