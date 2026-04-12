function x = bf16_from_binstr(str)
%BF16_FROM_BINSTR  Parse a BF16 binary string into a uint16 value.
%
%  x = bf16_from_binstr(str)
%
%  Accepted formats (underscores and spaces are ignored):
%    'S/EEEEEEEE/FFFFFFF'
%    'S/EEEE_EEEE/FFFF_FFF'
%
%  Example:
%    bf16_from_binstr('1/1000_0011/0000_000')  ->  uint16(49536)

% Remove underscores and spaces, then split on '/'
str   = strrep(str, '_', '');
str   = strrep(str, ' ', '');
parts = strsplit(str, '/');

if numel(parts) ~= 3
    error('bf16_from_binstr: expected format S/EEEEEEEE/FFFFFFF, got "%s"', str);
end

S = bin2dec(parts{1});
E = bin2dec(parts{2});
F = bin2dec(parts{3});

x = uint16(S*32768 + E*128 + F);
end
