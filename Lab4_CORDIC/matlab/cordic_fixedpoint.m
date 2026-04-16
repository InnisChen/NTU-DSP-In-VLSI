function [theta_out, mag_out] = cordic_fixedpoint(X, Y, S, w, aw)
% CORDIC_FIXEDPOINT  Fixed-point CORDIC: Cartesian (X,Y) -> polar (theta, mag)
%
%  [theta_out, mag_out] = cordic_fixedpoint(X, Y, S, w, aw)
%
%  Inputs:
%    X, Y  : scalar float inputs in [-1, 1] (quantized internally to 1S+1I+wF)
%    S     : number of micro-rotations
%    w     : fractional bits for X/Y data path
%    aw    : fractional bits for angle accumulator (theta)
%
%  Formats:
%    X/Y   : 1S + 1I + wF  ->  integer scale = 2^w,  range [-2, 2)
%    theta : 1S + 2I + awF ->  integer scale = 2^aw, range [-4, 4)  (pi < 4)
%
%  Outputs:
%    theta_out : phase in radians (floating-point, quantized to aw frac bits)
%    mag_out   : magnitude before S(N) scaling (quantized to w frac bits)
%                = sqrt(X^2+Y^2) / S(N)

% --- Quantize inputs to 1S+1I+wF (integer domain) ---
Xi_int = round(X * 2^w);
Yi_int = round(Y * 2^w);

% Clamp to representable range: -(2^(w+1)) .. (2^(w+1)-1)
max_int =  (2^(w+1) - 1);
min_int = -(2^(w+1));
Xi_int  = max(min_int, min(max_int, Xi_int));
Yi_int  = max(min_int, min(max_int, Yi_int));

% --- Angle LUT: atan(2^(-i)) quantized to 1S+2I+awF ---
lut_int = round(atan(2.^(-(0:S-1))) * 2^aw);

% --- Quadrant mapping (CORDIC converges only for |theta| <= pi/2) ---
% Reflect Q2/Q3 inputs to Q1/Q4 by negating both X and Y,
% then offset theta_init by +pi (Y>=0) or -pi (Y<0).
pi_int = round(pi * 2^aw);

if Xi_int < 0
    if Yi_int >= 0
        theta_init_int =  pi_int;   % +pi
    else
        theta_init_int = -pi_int;   % -pi
    end
    Xi_int = -Xi_int;
    Yi_int = -Yi_int;
else
    theta_init_int = 0;
end

% --- CORDIC iterations ---
theta_int = theta_init_int;

for i = 0:S-1
    % Rotation direction: drive Yi toward 0
    mu = -sign(Yi_int);
    if mu == 0, mu = 1; end  % if Yi==0, keep rotating (converged)

    % Arithmetic right shift by i: floor(val / 2^i)
    dX_int = floor(Yi_int / 2^i);
    dY_int = floor(Xi_int / 2^i);

    Xi_new    = Xi_int - mu * dX_int;
    Yi_new    = Yi_int + mu * dY_int;
    theta_int = theta_int - mu * lut_int(i+1);

    % Clamp to 1S+1I+wF range after each stage (simulate register saturation)
    Xi_int = max(min_int, min(max_int, Xi_new));
    Yi_int = max(min_int, min(max_int, Yi_new));
end

% --- Convert back to floating-point ---
theta_out = theta_int / 2^aw;
mag_out   = Xi_int   / 2^w;
end
