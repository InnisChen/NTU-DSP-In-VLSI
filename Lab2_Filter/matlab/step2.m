%% Step 2: 時域訊號濾波測試 (Time-domain Filtering)
fig_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end


% 1. 產生輸入訊號 x[n]
n_in = 0:143; % 產生 144 個 samples (0 到 143)

% 依照作業規定的公式產生輸入訊號：包含低頻的 sin 與高頻的 cos
x = sin(-2*pi*n_in/128) - cos(2*pi*n_in/4);

% 2. 進行濾波
% 使用 MATLAB 內建的 filter 函數，將 x[n] 通過我們在 Step 1 設計的 h_causal
y = filter(h_causal, 1, x);

% 3. 畫出輸入與輸出的時域波形
figure('Name', 'Step 2: Time-Domain Filtering Effect', 'NumberTitle', 'off');

% 繪製輸入訊號波形
subplot(2, 1, 1);
plot(n_in, x, 'LineWidth', 1.5);
title('Input Signal x[n]');
xlabel('Index (n)');
ylabel('Amplitude');
grid on;

% 繪製輸出訊號波形
subplot(2, 1, 2);
plot(n_in, y, 'LineWidth', 1.5, 'Color', '#D95319'); % 使用不同顏色方便區分
title('Output Signal y[n] after 25-tap Low-Pass FIR Filter');
xlabel('Index (n)');
ylabel('Amplitude');
grid on;
exportgraphics(gcf, fullfile(fig_dir, 'step2_time_domain.png'), 'Resolution', 150);