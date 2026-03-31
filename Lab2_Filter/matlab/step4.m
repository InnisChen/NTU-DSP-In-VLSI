%% Step 4: Read Verilog Behavioral Simulation Output & Compare with MATLAB
fig_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 此檔案需在 step1.m、step2.m、step3.m 執行完畢後執行
% 依賴的 workspace 變數：y, n_in, b_add_opt
% 依賴的外部檔案：y_output.dat（由 Verilog testbench 產生）

% =========================================================================
% 讀取 Verilog 輸出
% y_output.dat：每行一個 signed 整數（21-bit fixed-point）
% 轉回浮點：除以 2^b_add_opt = 2^17
% =========================================================================
F_ADD = b_add_opt;   % 小數位元數，與 Verilog 中 F_ADD 一致（= 17）

y_hw_raw = load("C:\Project\DSP in VLSI\Lab2_Filter\matlab\y_output.dat");        % 讀入 signed 整數，column vector
y_hw     = y_hw_raw' / (2^F_ADD);      % 轉為浮點，轉成 row vector

% 確認輸出筆數
N_out = length(y_hw);
fprintf('y_output.dat 讀入 %d 筆\n', N_out);
if N_out ~= length(y)
    warning('y_hw 長度 (%d) 與浮點 y 不符 (%d)，請確認模擬是否完整輸出', ...
            N_out, length(y));
end
N_cmp = min(N_out, length(y));  % 比較用的有效長度

% =========================================================================
%% 計算誤差
% =========================================================================
error_hw = y_hw(1:N_cmp) - y(1:N_cmp);
rmse_hw  = sqrt(mean(error_hw.^2));
max_err  = max(abs(error_hw));

% 印出 RMSE
fprintf('Behavioral Sim vs Float RMSE = %.6e  (threshold = 2^-11 = %.6e)\n', ...
        rmse_hw, 2^(-11));
if rmse_hw < 2^(-11)
    fprintf('✓ RMSE 符合門檻\n');
else
    fprintf('✗ RMSE 超過門檻，請檢查 Verilog 實作\n');
end

% =========================================================================
%% 圖1：Direct Form — 上下兩張合併
% =========================================================================
figure('Name', 'Step 4: HW vs Float Output & Error', 'NumberTitle', 'off');

% 上圖：輸出比較
subplot(2, 1, 1);
plot(n_in(1:N_cmp), y(1:N_cmp), 'b', 'LineWidth', 1.5);
hold on;
plot(n_in(1:N_cmp), y_hw(1:N_cmp), 'r--', 'LineWidth', 1.5);
title('Direct Form FIR Output: Hardware vs MATLAB Floating-point (y[0] to y[143])');
xlabel('Index (n)'); ylabel('Amplitude');
legend('MATLAB Floating-point', 'HW Fixed-point (Verilog)');
grid on;

% 下圖：誤差
subplot(2, 1, 2);
plot(n_in(1:N_cmp), error_hw, 'k', 'LineWidth', 1.2);
title(sprintf('Error: HW vs MATLAB Float  |  RMSE = %.4e,  Max |error| = %.4e', ...
              rmse_hw, max_err));
xlabel('Index (n)'); ylabel('Error Amplitude');
grid on;
exportgraphics(gcf, fullfile(fig_dir, 'step4_hw_vs_float.png'), 'Resolution', 150);

% =========================================================================
%% 讀取 Parallel Verilog 輸出
% =========================================================================
y_hw_par_raw = load("C:\Project\DSP in VLSI\Lab2_Filter\matlab\y_parallel_output.dat");
y_hw_par     = y_hw_par_raw' / (2^F_ADD);

N_out_par = length(y_hw_par);
fprintf('y_parallel_output.dat 讀入 %d 筆\n', N_out_par);
if N_out_par ~= length(y)
    warning('y_hw_par 長度 (%d) 與浮點 y 不符 (%d)，請確認模擬是否完整輸出', ...
            N_out_par, length(y));
end
N_cmp_par = min(N_out_par, length(y));

error_hw_par = y_hw_par(1:N_cmp_par) - y(1:N_cmp_par);
rmse_hw_par  = sqrt(mean(error_hw_par.^2));
max_err_par  = max(abs(error_hw_par));

fprintf('Parallel Sim vs Float RMSE = %.6e  (threshold = 2^-11 = %.6e)\n', ...
        rmse_hw_par, 2^(-11));
if rmse_hw_par < 2^(-11)
    fprintf('✓ RMSE 符合門檻\n');
else
    fprintf('✗ RMSE 超過門檻，請檢查 Verilog 實作\n');
end

% =========================================================================
%% 圖2：Parallel Form — 上下兩張合併
% =========================================================================
figure('Name', 'Step 4: Parallel HW vs Float Output & Error', 'NumberTitle', 'off');

subplot(2, 1, 1);
plot(n_in(1:N_cmp_par), y(1:N_cmp_par), 'b', 'LineWidth', 1.5);
hold on;
plot(n_in(1:N_cmp_par), y_hw_par(1:N_cmp_par), 'r--', 'LineWidth', 1.5);
title('Parallel Form FIR Output: Hardware vs MATLAB Floating-point (y[0] to y[143])');
xlabel('Index (n)'); ylabel('Amplitude');
legend('MATLAB Floating-point', 'HW Fixed-point (Verilog)');
grid on;

subplot(2, 1, 2);
plot(n_in(1:N_cmp_par), error_hw_par, 'k', 'LineWidth', 1.2);
title(sprintf('Error: HW vs MATLAB Float  |  RMSE = %.4e,  Max |error| = %.4e', ...
              rmse_hw_par, max_err_par));
xlabel('Index (n)'); ylabel('Error Amplitude');
grid on;
exportgraphics(gcf, fullfile(fig_dir, 'step4_parallel_hw_vs_float.png'), 'Resolution', 150);