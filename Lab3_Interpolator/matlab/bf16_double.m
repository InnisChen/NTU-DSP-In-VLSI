function y = bf16_double(x)
%BF16_DOUBLE  BF16 x2.0 via exponent increment (no multiplier).
%
%  y = bf16_double(x)
%
%  Equivalent to multiplying by 2.0: add 1 to the exponent field.
%  Overflow (E >= 254) -> clamped to max finite value.
%  Subnormal (E = 0)   -> uint16(0).  Sign and fraction bits are unchanged.

x = uint16(x);
S = double(bitshift(x, -15));
E = double(bitand(bitshift(x, -7), uint16(255)));
F = double(bitand(x, uint16(127)));

if E == 0
    y = uint16(0); return;   % subnormal -> zero
end

if E >= 254
    % overflow: clamp to largest finite value
    y = uint16(S*32768 + 254*128 + 127); return;
end

y = uint16(S*32768 + (E+1)*128 + F);
end
