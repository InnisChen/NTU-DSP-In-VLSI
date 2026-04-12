function val = bf16_to_double(x)
%BF16_TO_DOUBLE  Convert BF16 value(s) to double. Accepts scalar or array.
%
%  val = bf16_to_double(x)
%
%  Rule (per assignment): subnormals (E = 0) are treated as exact zero.

x = uint16(x);
S = double(bitshift(x, -15));
E = double(bitand(bitshift(x, -7), uint16(255)));
F = double(bitand(x, uint16(127)));

val = (-1).^S .* 2.^(double(E) - 127) .* (1 + F / 128);
val(E == 0) = 0;
end
