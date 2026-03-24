% DSP in VLSI - Homework 2
% Step 1: 25-tap Causal FIR Filter Design (使用內建 fft 替代 freqz)

clear; clc; close all;

%% 1. 產生濾波器係數
Ts = 1/6;                  % 取樣週期
n_orig = -12:12;           % 原始指標從 -12 到 12
t = n_orig * Ts;           % 時間變數 t = n*Ts

% 計算 Sinc 函數: sync(t) = sin(pi*t) / (pi*t)
% 遇到 t=0 時會有 0/0 (NaN) 的問題，需將極限值設為 1
h_noncausal = sin(pi*t) ./ (pi*t);
h_noncausal(t == 0) = 1;

% 轉換為因果濾波器 (Causal Filter)
h_causal = h_noncausal; 
n_causal = 0:24;           % 因果系統的 index: 0 到 24

%% 2. 畫出脈衝響應 (Impulse Response)
figure('Name', 'Impulse Response', 'NumberTitle', 'off');
stem(n_causal, h_causal, 'filled');
title('Impulse Response of 25-tap FIR Filter');
xlabel('Index (n)');
ylabel('Amplitude h[n]');
grid on;

%% 3. 畫出頻率響應 (Frequency Response) - 使用 FFT
N_fft = 1024;                     % 取 1024 個點做 FFT 使曲線平滑 (Zero-padding)
H_full = fft(h_causal, N_fft);    

% 因為實數訊號的頻譜是對稱的，我們只需要取前半段 (0 到 pi)
H = H_full(1:N_fft/2+1);
% 建立對應的頻率軸 (0 到 pi)
W = (0:N_fft/2) * (2*pi / N_fft); 
norm_freq = W / pi;               % 將角頻率轉換為正規化頻率 (Normalized frequency)

% 計算 Magnitude (以 dB 為單位)
mag_dB = 20 * log10(abs(H));
peak_mag = max(mag_dB);            % 找出峰值

% 計算 Phase (以 radian 為單位)
phase_rad = unwrap(angle(H));

% 尋找 3dB 頻寬 (由峰值衰減 3dB 的位置)
idx_3db = find(mag_dB <= (peak_mag - 3), 1, 'first');
bw_3db_freq = norm_freq(idx_3db);
bw_3db_mag = mag_dB(idx_3db);

% 繪製 Magnitude Response
figure('Name', 'Frequency Response', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(norm_freq, mag_dB, 'LineWidth', 1.5);
hold on;
% 標示 3dB 頻寬
plot(bw_3db_freq, bw_3db_mag, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
text(bw_3db_freq + 0.05, bw_3db_mag, sprintf('3dB BW \\approx %.3f\\pi', bw_3db_freq), 'Color', 'red');

% 設定 Y 軸範圍為 60dB 區間，以便觀察衰減效果
ylim([peak_mag - 60, peak_mag + 5]); 
title('Magnitude Response');
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
grid on;

% 繪製 Phase Response
subplot(2, 1, 2);
plot(norm_freq, phase_rad, 'LineWidth', 1.5);
title('Phase Response');
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Phase (radian)');
grid on;