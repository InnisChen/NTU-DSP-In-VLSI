function y = bf16_half(x)
%BF16_HALF  BF16 x0.5 via exponent decrement (no multiplier).
%
%  y = bf16_half(x)
%
%  Equivalent to multiplying by 0.5: subtract 1 from the exponent field.
%  Underflow (E <= 1) -> uint16(0).  Sign and fraction bits are unchanged.

x = uint16(x);
S = double(bitshift(x, -15));
E = double(bitand(bitshift(x, -7), uint16(255)));
F = double(bitand(x, uint16(127)));

if E <= 1
    y = uint16(0); return;   % underflow -> zero
end

y = uint16(S*32768 + (E-1)*128 + F);
end
