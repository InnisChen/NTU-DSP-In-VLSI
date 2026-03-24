%% Step 3: Quantization and Word-length Determination
% 學號尾數為奇數，RMSE 門檻設定為 2^-11
rmse_threshold = 2^(-11);
b_scan = 9:20; % 掃描字長 9 bits 到 20 bits
N_samples = length(y); % 144

% 定義作業要求的量化公式 (Truncation)
trunc_q = @(z, b) floor(z * (2^b)) / (2^b);

% 準備陣列來儲存四個階段的 RMSE
rmse_in = zeros(1, length(b_scan));
rmse_coef = zeros(1, length(b_scan));
rmse_mult = zeros(1, length(b_scan));
rmse_add = zeros(1, length(b_scan));

% =========================================================================
% 3(a) 掃描輸入端 (Input) 的最佳字長
% =========================================================================
for i = 1:length(b_scan)
    b = b_scan(i);
    x_q = trunc_q(x, b); % 只量化輸入
    y_tmp = filter(h_causal, 1, x_q); % 係數與運算保持浮點
    rmse_in(i) = sqrt(mean((y_tmp - y).^2));
end
% 找出符合門檻的最小字長
idx_in = find(rmse_in < rmse_threshold, 1, 'first');
b_in_opt = b_scan(idx_in);
fprintf('最佳輸入字長 (b_in): %d bits\n', b_in_opt);

% =========================================================================
% 3(b) 固定輸入字長，掃描濾波器係數 (Coefficient) 的最佳字長
% =========================================================================
x_opt = trunc_q(x, b_in_opt); % 固定第一階段的最佳量化輸入

for i = 1:length(b_scan)
    b = b_scan(i);
    h_q = trunc_q(h_causal, b); % 量化係數
    y_tmp = filter(h_q, 1, x_opt); % 使用量化後的 x 與 h
    rmse_coef(i) = sqrt(mean((y_tmp - y).^2));
end
idx_coef = find(rmse_coef < rmse_threshold, 1, 'first');
b_coef_opt = b_scan(idx_coef);
fprintf('最佳係數字長 (b_coef): %d bits\n', b_coef_opt);

% =========================================================================
% 3(c) 固定輸入與係數，掃描乘法器輸出 (Multiplier Output) 的最佳字長
% =========================================================================
h_opt = trunc_q(h_causal, b_coef_opt); % 固定最佳量化係數

for i = 1:length(b_scan)
    b = b_scan(i);
    % 呼叫下方自定義的直接型濾波器函數 (不量化加法器，設為 inf)
    y_tmp = my_direct_form_filter(x_opt, h_opt, b, inf); 
    rmse_mult(i) = sqrt(mean((y_tmp - y).^2));
end
idx_mult = find(rmse_mult < rmse_threshold, 1, 'first');
b_mult_opt = b_scan(idx_mult);
fprintf('最佳乘法器輸出字長 (b_mult): %d bits\n', b_mult_opt);

% =========================================================================
% 3(d) 固定前三者，掃描加法器輸出 (Adder Output) 的最佳字長
% =========================================================================
for i = 1:length(b_scan)
    b = b_scan(i);
    % 四個階段全部量化
    y_tmp = my_direct_form_filter(x_opt, h_opt, b_mult_opt, b); 
    rmse_add(i) = sqrt(mean((y_tmp - y).^2));
end
idx_add = find(rmse_add < rmse_threshold, 1, 'first');
b_add_opt = b_scan(idx_add);
fprintf('最佳加法器輸出字長 (b_add): %d bits\n', b_add_opt);

% 取得最終的 Fixed-point 時間域輸出
y_fixed = my_direct_form_filter(x_opt, h_opt, b_mult_opt, b_add_opt);

%% 繪製 4 張字長決策圖 (Q3 a~d)
figure('Name', 'Step 3: Word-length Decision', 'NumberTitle', 'off');

subplot(2,2,1);
plot(b_scan, rmse_in, '-o', 'LineWidth', 1.5);
yline(rmse_threshold, 'r--', 'Threshold (2^{-11})');
title('(a) RMSE vs Input Word-length');
xlabel('Word-length (bits)'); ylabel('RMSE'); grid on;

subplot(2,2,2);
plot(b_scan, rmse_coef, '-o', 'LineWidth', 1.5);
yline(rmse_threshold, 'r--', 'Threshold');
title('(b) RMSE vs Coef Word-length');
xlabel('Word-length (bits)'); ylabel('RMSE'); grid on;

subplot(2,2,3);
plot(b_scan, rmse_mult, '-o', 'LineWidth', 1.5);
yline(rmse_threshold, 'r--', 'Threshold');
title('(c) RMSE vs Multiplier Output Word-length');
xlabel('Word-length (bits)'); ylabel('RMSE'); grid on;

subplot(2,2,4);
plot(b_scan, rmse_add, '-o', 'LineWidth', 1.5);
yline(rmse_threshold, 'r--', 'Threshold');
title('(d) RMSE vs Adder Output Word-length');
xlabel('Word-length (bits)'); ylabel('RMSE'); grid on;

%% 繪製時域訊號與誤差比較圖 (Q4 Time-domain)
figure('Name', 'Step 3: Time-domain Comparison', 'NumberTitle', 'off');
subplot(2,1,1);
plot(n_in, y, 'b', 'LineWidth', 1.5); hold on;
plot(n_in, y_fixed, 'r--', 'LineWidth', 1.5);
title('Time Domain Output: Floating-point vs Fixed-point');
xlabel('Index (n)'); ylabel('Amplitude');
legend('Floating-point', 'Fixed-point'); grid on;

subplot(2,1,2);
error_time = y_fixed - y;
plot(n_in, error_time, 'k', 'LineWidth', 1.2);
title('Time Domain Error (Fixed - Float)');
xlabel('Index (n)'); ylabel('Error Amplitude'); grid on;

%% 繪製頻域響應與 Passband 誤差比較圖 (Q4 Frequency-domain)
% 針對最終決定的量化係數 h_opt 進行 FFT
H_fixed = fft(h_opt, N_fft);
H_fixed = H_fixed(1:N_fft/2+1);
mag_fixed_dB = 20 * log10(abs(H_fixed));

figure('Name', 'Step 3: Frequency-domain Comparison', 'NumberTitle', 'off');
subplot(2,1,1);
plot(norm_freq, mag_dB, 'b', 'LineWidth', 1.5); hold on;
plot(norm_freq, mag_fixed_dB, 'r--', 'LineWidth', 1.5);
ylim([peak_mag - 60, peak_mag + 5]);
title('Magnitude Response: Floating vs Fixed-point');
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
legend('Floating-point', 'Fixed-point'); grid on;

% 計算 3dB Passband 內的誤差
passband_idx = find(norm_freq <= bw_3db_freq); 
mag_error_dB = mag_fixed_dB(passband_idx) - mag_dB(passband_idx);

subplot(2,1,2);
plot(norm_freq(passband_idx), mag_error_dB, 'k', 'LineWidth', 1.5);
title('Magnitude Response Error in Passband (within 3dB BW)');
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Error (dB)'); grid on;

%% 計算整數部分與總字長 (Total Word-length for Verilog)
disp('--- Verilog 硬體總字長計算 ---');

% 1. 輸入訊號
max_x = max(abs(x));
% 使用 floor(log2)+1 確保 2 的次方數（如 2.0）不會溢位
% （ceil(log2(2.0))=1，但 2.0 需要 2 個整數位）
int_bits_x = floor(log2(max_x)) + 1;
if int_bits_x < 0, int_bits_x = 0; end
total_bits_in = 1 + int_bits_x + b_in_opt;
fprintf('輸入端 (x): 最大絕對值=%.3f -> 需 1(Sign) + %d(Int) + %d(Frac) = 總共 %d bits\n', max_x, int_bits_x, b_in_opt, total_bits_in);

% 2. 濾波器係數
max_h = max(abs(h_causal));
% 使用 floor(log2)+1 確保 max_h=1.0 時整數位為 1
% （ceil(log2(1.0))=0 會導致 W_coef=16，h[12]=1.0 溢位變成 7FFF）
int_bits_h = floor(log2(max_h)) + 1;
if int_bits_h < 0, int_bits_h = 0; end
total_bits_coef = 1 + int_bits_h + b_coef_opt;
fprintf('係數端 (h): 最大絕對值=%.3f -> 需 1(Sign) + %d(Int) + %d(Frac) = 總共 %d bits\n', max_h, int_bits_h, b_coef_opt, total_bits_coef);

% 3. 乘法器輸出與加法器輸出（遍歷所有樣本找最大值）
L = length(h_causal);
N = length(x);
max_mult = 0;
max_add  = 0;

for n = 1:N
    mult_out = zeros(1, L);
    for k = 1:L
        if (n - k + 1) > 0
            val = x_opt(n - k + 1) * h_opt(k);
            if abs(val) > max_mult, max_mult = abs(val); end
            mult_out(k) = trunc_q(val, b_mult_opt);
        end
    end
    
    sum_val = mult_out(1);
    for k = 2:L
        sum_val = sum_val + mult_out(k);
        if abs(sum_val) > max_add, max_add = abs(sum_val); end
        sum_val = trunc_q(sum_val, b_add_opt);
    end
end

% 乘法器字長：根據實際最大值計算整數位（與 x、h 計算方式一致）
int_bits_mult = floor(log2(max_mult)) + 1;
if int_bits_mult < 0, int_bits_mult = 0; end
total_bits_mult = 1 + int_bits_mult + b_mult_opt;
fprintf('乘法器輸出: 最大絕對值=%.3f -> 需 1(Sign) + %d(Int) + %d(Frac) = 總共 %d bits\n', ...
        max_mult, int_bits_mult, b_mult_opt, total_bits_mult);

% 加法器字長：根據實際最大值計算整數位（與 x、h 計算方式一致）
int_bits_add = floor(log2(max_add)) + 1;
if int_bits_add < 0, int_bits_add = 0; end
total_bits_add = 1 + int_bits_add + b_add_opt;
fprintf('加法器輸出: 最大絕對值=%.3f -> 需 1(Sign) + %d(Int) + %d(Frac) = 總共 %d bits\n', ...
        max_add, int_bits_add, b_add_opt, total_bits_add);
fprintf('  （實際最大值推算，非保守估計）\n');
fprintf('           （乘法器整數位 %d + 累加擴展位 ceil(log2(%d))=%d）\n', ...
        int_bits_mult, L, extra_bits_add);

fprintf('\n--- Verilog 各節點位元寬總結 ---\n');
fprintf('W_IN   = %d  (x  : 1Sign + %dInt + %dFrac)\n', total_bits_in,   int_bits_x,    b_in_opt);
fprintf('W_COEF = %d  (h  : 1Sign + %dInt + %dFrac)\n', total_bits_coef,  int_bits_h,    b_coef_opt);
fprintf('W_MULT = %d  (x*h: 1Sign + %dInt + %dFrac)\n', total_bits_mult,  int_bits_mult, b_mult_opt);
fprintf('W_ADD  = %d  (acc: 1Sign + %dInt + %dFrac)\n', total_bits_add,   int_bits_add,  b_add_opt);

% =========================================================================
%% 匯出輸入測試向量為 x_input.dat（供 Verilog Testbench 使用）
% 使用 step3 決定的最佳輸入字長 b_in_opt
% 格式：每行一個 4 位 hex 值（15-bit signed，以 unsigned 表示）
% =========================================================================
scale_x = 2^b_in_opt;
W_in = 1 + int_bits_x + b_in_opt;   % 總位元數（含符號位）
max_val =  2^(W_in - 1) - 1;        % signed 最大值
min_val = -2^(W_in - 1);            % signed 最小值

fileID = fopen('x_input.dat', 'w');
for i = 1:length(x)
    xi = x(i);
    q = floor(xi * scale_x);           % truncation 量化
    q = max(min_val, min(max_val, q)); % clamp 防止溢位
    if q < 0
        q = q + 2^W_in;               % 轉為 unsigned 表示（two's complement）
    end
    fprintf(fileID, '%04X\n', q);      % 寫入 4 位 hex（與 W_in=15 對應）
end
fclose(fileID);
fprintf('已匯出 x_input.dat（%d 筆，%d-bit，b_in_opt=%d）\n', length(x), W_in, b_in_opt);

% =========================================================================
%% 匯出係數為 h_coef.dat（供 Verilog initial 區塊參考，或 $readmemh 使用）
% 使用 step3 決定的最佳係數字長 b_coef_opt
% 格式：每行一個 hex 值（W_coef-bit signed，以 unsigned two's complement 表示）
% =========================================================================
W_coef   = 1 + int_bits_h + b_coef_opt;  % 總位元數（含符號位）
scale_h  = 2^b_coef_opt;
max_h_val =  2^(W_coef-1) - 1;           % signed 最大值
min_h_val = -2^(W_coef-1);               % signed 最小值
hex_digits = ceil(W_coef / 4);           % hex 字元數

fileID = fopen('h_coef.dat', 'w');
fprintf('\n--- Verilog 係數宣告（%d-bit signed，貼入 initial 區塊）---\n', W_coef);
for i = 1:length(h_causal)
    q = floor(h_causal(i) * scale_h);        % truncation 量化（與 h_opt 一致）
    q = max(min_h_val, min(max_h_val, q));   % clamp 防止溢位
    if q < 0
        q_unsigned = q + 2^W_coef;           % 轉為 unsigned two's complement
    else
        q_unsigned = q;
    end
    hex_str = dec2hex(q_unsigned, hex_digits);
    fprintf(fileID, '%s\n', hex_str);         % 寫入 dat 檔
    fprintf("    h_coef[%2d] = %d'sh%s; // %12.8f\n", i-1, W_coef, hex_str, h_causal(i));
end
fclose(fileID);
fprintf('已匯出 h_coef.dat（%d 筆，%d-bit，b_coef_opt=%d）\n', length(h_causal), W_coef, b_coef_opt);


%% 必須加在腳本最下方的 Local Function
function y_out = my_direct_form_filter(x, h, b_mult, b_add)
    N = length(x);
    L = length(h);
    y_out = zeros(1, N);
    
    trunc = @(z, b) floor(z * (2^b)) / (2^b);
    
    for n = 1:N
        mult_out = zeros(1, L);
        for k = 1:L
            if (n - k + 1) > 0
                val = x(n - k + 1) * h(k);
                if ~isinf(b_mult)
                    val = trunc(val, b_mult);
                end
                mult_out(k) = val;
            end
        end
        
        sum_val = mult_out(1);
        for k = 2:L
            sum_val = sum_val + mult_out(k);
            if ~isinf(b_add)
                sum_val = trunc(sum_val, b_add);
            end
        end
        y_out(n) = sum_val;
    end
end