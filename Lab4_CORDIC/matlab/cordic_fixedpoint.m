function [theta_out, mag_out] = cordic_fixedpoint(X, Y, S, w, aw)
% CORDIC_FIXEDPOINT  Fixed-point CORDIC: Cartesian (X,Y) -> polar (theta, mag)
%
%  [theta_out, mag_out] = cordic_fixedpoint(X, Y, S, w, aw)
%
%  Inputs:
%    X, Y  : scalar float inputs (quantized internally to 1S+1I+wF)
%    S     : number of micro-rotations
%    w     : fractional bits for X/Y data path
%    aw    : fractional bits for angle accumulator (theta)
%            Pass Inf to use floating-point angles (Step 2: isolate X/Y word-length)
%
%  Formats:
%    X/Y   : 1S + 1I + wF  ->  integer scale = 2^w,  range [-2, 2)
%    theta : 1S + 2I + awF ->  integer scale = 2^aw, range [-4, 4)  (pi < 4)
%            when aw=Inf: floating-point accumulator, no angle quantization
%
%  Outputs:
%    theta_out : phase in radians (floating-point)
%    mag_out   : magnitude before S(N) scaling (quantized to w frac bits)
%                = sqrt(X^2+Y^2) / S(N)

% --- Quantize inputs to 1S+1I+wF (integer domain) ---
Xi_int  = floor(X * 2^w);
Yi_int  = floor(Y * 2^w);

% Clamp to representable range: -(2^(w+1)) .. (2^(w+1)-1)
max_int =  (2^(w+1) - 1);
min_int = -(2^(w+1));
Xi_int  = max(min_int, min(max_int, Xi_int));
Yi_int  = max(min_int, min(max_int, Yi_int));

% --- Angle LUT: atan(2^(-i)) ---
% aw=Inf -> floating-point, isolates X/Y quantization effect (Step 2)
% aw finite -> quantized to 1S+2I+awF integer domain (Step 3 onwards)
float_angle = isinf(aw);
angles_fp = atan(2.^(-(0:S-1)));   % floating-point reference always computed
if ~float_angle
    lut_int = round(angles_fp * 2^aw);   % quantized integer LUT
end

% --- Quadrant mapping (CORDIC converges only for |theta| <= pi/2) ---
% Reflect Q2/Q3 inputs to Q1/Q4 by negating both X and Y,
% then offset theta_init by +pi (Y>=0) or -pi (Y<0).
if Xi_int < 0
    if Yi_int >= 0
        theta_init =  pi;
    else
        theta_init = -pi;
    end
    Xi_int = -Xi_int;
    Yi_int = -Yi_int;
else
    theta_init = 0;
end

% Quantize theta_init if angle path is fixed-point
if float_angle
    theta = theta_init;
else
    theta = round(theta_init * 2^aw);   % integer domain
end

% --- CORDIC iterations ---
for i = 0:S-1
    % Rotation direction: drive Yi toward 0
    mu = -sign(Yi_int);
    if mu == 0, mu = 1; end

    % Arithmetic right shift of X/Y by i
    dX_int = floor(Yi_int / 2^i);
    dY_int = floor(Xi_int / 2^i);

    Xi_new = Xi_int - mu * dX_int;
    Yi_new = Yi_int + mu * dY_int;

    % Angle accumulation
    if float_angle
        theta = theta - mu * angles_fp(i+1);
    else
        theta = theta - mu * lut_int(i+1);
    end

    % Clamp X/Y to 1S+1I+wF range after each stage
    Xi_int = max(min_int, min(max_int, Xi_new));
    Yi_int = max(min_int, min(max_int, Yi_new));
end

% --- Convert back to floating-point ---
if float_angle
    theta_out = theta;
else
    theta_out = theta / 2^aw;
end
mag_out = Xi_int / 2^w;
end
