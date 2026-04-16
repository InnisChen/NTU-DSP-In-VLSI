# Lab4 CORDIC 實作計畫

## Context

本專案實作 CORDIC 演算法，將直角座標 (X, Y) 轉換為極座標（phase 和 magnitude）。作業包含 9 個步驟：MATLAB 分析（Steps 1-5）→ Verilog 設計與驗證（Steps 6-9）。

### 學生參數

- **I = 7**（學號末碼）
- **β = mod(7, 2) + 1 = 2**
- **α_m = (4m + 2)/20 × π**，m = 0, 1, ..., 9
- 測試角度覆蓋所有四個象限（0.1π ~ 1.9π）

---

## 專案目錄結構

```
Lab4_CORDIC/
  matlab/                        # MATLAB 分析腳本 (Steps 1-5)
    cordic_fixedpoint.m          # 共用 fixed-point CORDIC 模型
    step1_scaling_factor.m       # S(N) vs N 圖
    step2_wordlength.m           # word-length 分析
    step3_micro_rotations.m      # micro-rotation 數量 + angle word-length
    step4_magnitude_rotations.m  # magnitude 所需 micro-rotation 數
    step5_csd.m                  # CSD 表示與 shift-and-add 設計
    gen_testdata.m               # 產生 Verilog testbench 測試資料
  01_RTL/
    CORDIC.v                     # 主要 CORDIC 模組（iterative → unfolded → full）
  00_TESTBED/
    TESTBED.v                    # Testbench
  02_SYN/
    syn90.tcl                    # Design Compiler 合成腳本
    file.f
    02_run
  03_GATESIM/
    file.f
    03_run
  SIM/                           # Vivado xsim 專案
  figure/                        # MATLAB 產生的圖表
```

---

## 實作步驟

### Phase A：MATLAB 分析（Steps 1-5）

#### Step 1：Scaling Factor S(N) vs N

- 計算 `S(N) = 1 / ∏(i=0..N-1) sqrt(1 + 2^(-2i))`，N = 1..30
- S(N) 收斂至約 **0.6073**（CORDIC gain constant K）
- 繪圖並儲存
- **檔案**：`matlab/step1_scaling_factor.m`

#### Step 2：決定 fixed-point word-length

- X = cos(α_m)、Y = sin(α_m) 量化為 **(w+2) bits**：1 sign + 1 integer + w fractional
- 1 integer bit 可表示到 ±2.0，足以容納 CORDIC 增長（~1.6468）
- 掃描 w = 8..20，對 10 組輸入執行 fixed-point CORDIC，計算 average absolute phase error
- 找到滿足 **error < 2^(-9)** 的最小 w
- **注意**：theta 累加器需要 2 integer bits（因為 π ≈ 3.14），格式為 1 sign + 2 integer + fractional
- **圖表**：average absolute error vs w
- **檔案**：`matlab/step2_wordlength.m`、`matlab/cordic_fixedpoint.m`

#### Step 3：決定 arctangent micro-rotation 數量 S

- 掃描 S = 2, 4, 6, ..., 30（偶數），計算 10 組量化輸入的 average phase error
- 找到滿足 **error < 2^(-9)** 的最小偶數 S
- 同時掃描 elementary angle θ_e(i) = atan(2^(-i)) 的 word-length
- **兩張圖**：(1) error vs S、(2) error vs angle word-length
- **表格**：列出所有 elementary angles 的浮點值和 binary fixed-point 表示
- **檔案**：`matlab/step3_micro_rotations.m`

#### Step 4：決定 magnitude micro-rotation 數量

- 公式：error < 1 - 1/sqrt(1 + 2^(-2(N-1))) < 0.001 (0.1%)
- 預估 **N ≈ 6**
- **檔案**：`matlab/step4_magnitude_rotations.m`

#### Step 5：CSD Scaling Factor

- 將 S(N) ≈ 0.6073 轉為 CSD（Canonical Signed Digit）表示
- 掃描 CSD word-length，找到 error < 0.1% 的最短表示
- 計算所需 adder 數量 = (非零 CSD digits) - 1
- **圖表**：CSD 近似 error vs fractional word-length
- **檔案**：`matlab/step5_csd.m`

---

### Phase B：Verilog RTL 設計（Steps 6-9）

#### Step 6：Iterative Architecture（arctangent only）

**模組 `CORDIC.v`（iterative 版本）：**

```
Ports: clk, rst_n, inX[W-1:0], inY[W-1:0], in_valid, outTheta[TW-1:0], out_valid
```

- **Initial Stage**：象限映射
  - 若 X < 0：X0 = -X, Y0 = -Y, θ_init = π（Y≥0）或 -π（Y<0）
  - 若 X ≥ 0：直接使用，θ_init = 0
- **FSM**：IDLE → LOAD → ITERATE (S cycles) → DONE
- **Micro-rotation**（每 cycle 一次迭代）：
  - μ_i = -sign(Y(i))
  - X(i+1) = X(i) - μ_i × (Y(i) >>> i)
  - Y(i+1) = Y(i) + μ_i × (X(i) >>> i)
  - θ(i+1) = θ(i) - μ_i × θ_e(i)
- **Angle LUT**：ROM 儲存 θ_e(i)
- 測試 α_0, α_3, α_6, α_9（四個象限各一）
- DFF 僅在 input/output

#### Step 7：S/2-Unfolding Architecture

- 將 S 次 micro-rotation 分為兩組，每組 S/2 級 combinational stages
- **Clock 1**：Initial stage + 前 S/2 級 → pipeline register
- **Clock 2**：後 S/2 級 → output register
- 每 2 個 clock cycles 完成一次計算
- 10 組輸入，behavioral + post-synthesis simulation
- **注意**：每個 stage 的 shift 量 i 是 hardcoded，不需 barrel shifter

#### Step 8：Area 比較

- 分別合成 iterative 和 unfolded 架構
- 使用相同 timing constraint（10ns clock）
- 比較 `Report/area.txt`

#### Step 9：完整 Magnitude 架構

- 在 unfolded 架構後接 **CSD shift-and-add** scaling module
- magnitude = S(N) × X(N)，用 CSD 表示的 shift-and-add 實現
- S 需 ≥ Step 4 + Step 5 所決定的 micro-rotation 數
- 10 組輸入，behavioral + post-synthesis simulation

---

### Phase C：合成與驗證流程

- **合成**：沿用 Lab3 的 `syn90.tcl`，修改 `toplevel` 和 `file.f`
- **Gate-level sim**：使用 `tsmc090.v` library，帶 SDF back-annotation
- **Vivado xsim**：用於 Windows 上的 behavioral simulation

---

## 關鍵設計注意事項

1. **Signed arithmetic**：全程使用 Verilog `signed` 型別，算術右移 `>>>` 保持符號
2. **Initial stage 象限映射**：CORDIC 收斂範圍 ±99°，Q2/Q3 的輸入必須先映射到 Q1/Q4
3. **Theta 格式**：需要比 X/Y 多 1 bit integer part（π ≈ 3.14 需要 2 integer bits）
4. **Timing**：S/2 級串聯 adder 的 critical path，10ns clock 應足夠（TSMC 90nm）
5. **CSD scaling**：每個非零 digit 對應一個 shifted copy，用 adder 累加

---

## 驗證方式

1. **MATLAB golden model**：`cordic_fixedpoint.m` 作為 reference，產生期望輸出
2. **Behavioral sim**：Vivado xsim 比對 Verilog 輸出 vs MATLAB golden
3. **Post-synthesis sim**：DC 合成後 gate-level sim 帶 SDF，驗證功能正確
4. **Error 分析**：計算每組輸入的 phase/magnitude error，繪製 error vs index m 圖

---

## 實作順序

```
Step 1 (MATLAB) ─→ Step 2 (MATLAB) ─→ Step 3 (MATLAB) ─┐
                                                         ├→ Step 6 (Verilog iterative)
Step 4 (MATLAB) ─→ Step 5 (MATLAB) ─────────────────────┤   ↓
                                                         ├→ Step 7 (Verilog unfolded)
                                                         │   ↓
                                                         ├→ Step 8 (Synthesis 比較)
                                                         │   ↓
                                                         └→ Step 9 (Verilog full + magnitude)
```

建議先完成所有 MATLAB 分析以確定設計參數，再進入 Verilog 實作。
