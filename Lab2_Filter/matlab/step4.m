%% Step 4: Read Verilog Behavioral Simulation Output & Compare with MATLAB
% 此檔案需在 step1.m、step2.m、step3.m 執行完畢後執行
% 依賴的 workspace 變數：y, n_in, b_add_opt
% 依賴的外部檔案：y_output.dat（由 Verilog testbench 產生）

% =========================================================================
% 讀取 Verilog 輸出
% y_output.dat：每行一個 signed 整數（21-bit fixed-point）
% 轉回浮點：除以 2^b_add_opt = 2^17
% =========================================================================
F_ADD = b_add_opt;   % 小數位元數，與 Verilog 中 F_ADD 一致（= 17）

y_hw_raw = load("C:\Project\DSP in VLSI\Lab2_Filter\rtl\FIR_FILTER\FIR_FILTER.sim\sim_1\behav\xsim\y_output.dat");        % 讀入 signed 整數，column vector
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
%% 圖1：全部 144 筆輸出比較（HW vs MATLAB float）
% =========================================================================
figure('Name', 'Step 4: HW vs Float Output (All 144 samples)', 'NumberTitle', 'off');
plot(n_in(1:N_cmp), y(1:N_cmp), 'b', 'LineWidth', 1.5);
hold on;
plot(n_in(1:N_cmp), y_hw(1:N_cmp), 'r--', 'LineWidth', 1.5);
title('Direct Form FIR Output: Hardware vs MATLAB Floating-point (y[0] to y[143])');
xlabel('Index (n)'); ylabel('Amplitude');
legend('MATLAB Floating-point', 'HW Fixed-point (Verilog)');
grid on;

% =========================================================================
%% 圖2：全部 144 筆的誤差（Hardware output - MATLAB float）
% =========================================================================
error_hw = y_hw(1:N_cmp) - y(1:N_cmp);

figure('Name', 'Step 4: Error - HW vs Float (All 144 samples)', 'NumberTitle', 'off');
plot(n_in(1:N_cmp), error_hw, 'k', 'LineWidth', 1.2);
title('Error: Hardware Output vs MATLAB Floating-point (y[0] to y[143])');
xlabel('Index (n)'); ylabel('Error Amplitude');
grid on;

% 印出 RMSE
rmse_hw = sqrt(mean(error_hw.^2));
fprintf('Behavioral Sim vs Float RMSE = %.6e  (threshold = 2^-11 = %.6e)\n', ...
        rmse_hw, 2^(-11));
if rmse_hw < 2^(-11)
    fprintf('✓ RMSE 符合門檻\n');
else
    fprintf('✗ RMSE 超過門檻，請檢查 Verilog 實作\n');
end