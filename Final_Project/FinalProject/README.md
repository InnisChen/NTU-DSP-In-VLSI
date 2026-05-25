# FinalProject

This folder contains the implementation package for the DSP in VLSI final project.

## Structure

- `01_RTL/FinalProject.v`: top-level iterative QR eigensolver.
- `01_RTL/cordic_pe.v`: sequential CORDIC processing element.
- `00_TESTBED/tb_FinalProject.v`: behavioral simulation testbench for `Matrix(:,:,8)`.
- `00_TESTBED/tb_FinalProject_all.v`: behavioral batch testbench for all 11 provided matrices against bit-true expected outputs.
- `matlab/run_all.m`: bit-true model, RMSE analysis, and expected-output generation.
- `matlab/sweep_wordlength.m`: full wordlength and CORDIC-stage sweep used to justify the selected fixed-point setting.
- `matlab/analyze_bitwidth.m`: step-by-step bit-width analysis for input, CORDIC internals, gain product, matrix registers, output, counters, stages, and iteration count.
- `matlab/compare_rtl_output.m`: Matrix 8 RTL output versus bit-true expected-output check.
- `matlab/compare_rtl_output_all.m`: all-11 RTL output versus bit-true expected-output check.
- `matlab/iteration_sweep.csv`: floating and fixed-point RMSE versus `ITER_MAX`.
- `matlab/bitwidth_analysis_summary.txt`: report-ready explanation of the final bit-width decision.
- `02_SYN/syn90.tcl`: Design Compiler synthesis script.
- `Report/architecture_notes.md`: notes for the final report.

## Default Fixed-Point Setting

- `WI = 17`
- `WO = 17`
- `FRAC_W = 12`
- `ACC_W = 27`
- `CORDIC_STAGES = 10`
- `ITER_MAX = 7`

The default I/O format is Q4.12. The original 16-bit Q3.12 plan cannot represent the largest provided matrix values, so the default was widened to 17 bits to satisfy the assignment RMSE requirement while keeping area lower than an 18-bit datapath.

## Validation Notes

- `run_all.m` generates bit-true expected outputs for `Matrix(:,:,8)` and all 11 matrices.
- `tb_FinalProject.v` checks the assignment-required hardware pattern `Matrix(:,:,8)`.
- `tb_FinalProject_all.v` checks all 11 matrices against the same bit-true model to reduce RTL/model mismatch risk.
- `compare_rtl_output_all.m` summarizes per-set RTL-vs-bit-true fixed-point differences after batch simulation.
- `analyze_bitwidth.m` reports both floating-point and fixed-point iteration sweeps; the final `ITER_MAX` decision is based on fixed-point results.
