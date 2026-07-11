# 06 Experiment Validation

这个目录对应方案中的第六部分实验验证，重点把“当前本机能完成的功能性验证”正式落成可复现实验。

## 当前范围

根据 [README.md](/Users/alpaca/Documents/SME/SME1/README.md) 中第 4 节定义，本目录当前先覆盖：

1. 生成的 LLVM IR 是否可接受
2. 目标预取 intrinsic 是否被识别
3. 预取语义是否保留到 LLVM / 汇编
4. 最终汇编中是否出现目标预取指令
5. 统一 SME 主线是否能在本机真实运行
6. 稳定 ABI wrapper 返回的 descriptor 是否可被普通 C 安全读取

这里的验证对象现在统一收口为“统一 SME 主线”，不再额外维护一个独立的辅助运行分支。

## 为什么先做功能性验证

方案中的性能实验要求：

- LX2 目标机器
- 毕昇编译器
- PMU / `perf stat` 计数器环境

当前仓库所在环境是 Apple Silicon macOS，本机不能替代 LX2 的性能结论，因此这里先把本机能够确定完成的功能性实验做扎实。

## 目录结构

- [run_validation.py](/Users/alpaca/Documents/SME/SME1/06_experiment_validation/run_validation.py)：自动检查功能性验证项并生成报告
- [output/validation_summary.json](/Users/alpaca/Documents/SME/SME1/06_experiment_validation/output/validation_summary.json)：结构化验证结果
- [output/validation_report.md](/Users/alpaca/Documents/SME/SME1/06_experiment_validation/output/validation_report.md)：面向阅读的验证报告

## 如何运行

在仓库根目录执行：

```bash
python3 06_experiment_validation/run_validation.py
```

## 当前预期

当前预期结论是：

- 统一主线已经完成本机功能性验证
- 性能实验仍然等待 LX2 + 毕昇环境补齐
