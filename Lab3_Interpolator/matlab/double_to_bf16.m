function x = double_to_bf16(val)
%DOUBLE_TO_BF16  Convert a double scalar to BF16 with truncation (no rounding).
%
%  x = double_to_bf16(val)
%
%  Method: reinterpret the 64-bit IEEE 754 double bit pattern directly.
%    - Sign     : bit 63  (same for double and BF16)
%    - Exponent : double bias 1023 -> BF16 bias 127  (difference = 896)
%    - Mantissa : top 7 bits of the 52-bit double mantissa (truncation)
%
%  Special cases (per assignment):
%    - val == 0 or double subnormal (E_d = 0)  -> uint16(0)
%    - BF16 underflow  (E_bf16 <= 0)           -> uint16(0)
%    - BF16 overflow   (E_bf16 >= 255)         -> clamped to max finite value

if val == 0
    x = uint16(0); return;
end

% Get 64-bit representation of the double value
d = typecast(double(val), 'uint64');

S   = double(bitshift(d, -63));                          % sign bit
E_d = double(bitand(bitshift(d, -52), uint64(2047)));   % exponent (11 bits)
F_d = bitand(d, uint64(4503599627370495));              % mantissa (52 bits)

% Double subnormal (E_d == 0) -> treated as zero
if E_d == 0
    x = uint16(0); return;
end

% Exponent conversion: double bias 1023, BF16 bias 127
E_bf16 = E_d - 896;

if E_bf16 <= 0
    x = uint16(0); return;   % BF16 underflow
end

if E_bf16 >= 255
    % BF16 overflow: clamp to largest finite value
    x = uint16(S*32768 + 254*128 + 127); return;
end

% Truncate mantissa: take top 7 bits of the 52-bit double mantissa
F_bf16 = double(bitshift(F_d, -45));   % bits [51:45]

x = uint16(S*32768 + E_bf16*128 + F_bf16);
end
