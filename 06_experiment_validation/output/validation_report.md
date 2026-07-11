# 06 Experiment Validation

## 功能性验证

本阶段按方案第 4 节，先完成当前本机能够复现的功能性验证。

1. LLVM IR 是否可接受：`是`
2. 统一主线中的目标预取 intrinsic 是否被识别：`是`
3. SME 相关 intrinsic 是否被识别：`是`
4. 最终汇编中是否出现目标预取指令：`是`
5. 最终汇编中是否出现 SME 指令：`是`
6. 统一主线是否可本机运行：`是`
7. 稳定 wrapper 返回 descriptor 是否可用：`是`

## 关键证据

- 统一主线 LLVM IR： [09_unified_llvm_prefetch.ll](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/09_unified_llvm_prefetch.ll)
- 统一主线运行日志： [unified_demo.log](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/unified_demo.log)
- 本次结构化摘要： [validation_summary.json](/Users/alpaca/Documents/SME/SME1/06_experiment_validation/output/validation_summary.json)

## 当前结论

当前实验已经证明：

- 高层注入的预取语义可以继续传递到 `llvm.prefetch`
- 统一主线可以继续传递到 `arm_sme` / `llvm`
- 最终汇编中同时可以观察到 `prfm` 与 SME 指令
- 统一主线与稳定 ABI wrapper 都已经在本机实际运行

## 性能实验状态

性能实验当前标记为“待 LX2 环境执行”。

原因：

- 方案中要求对比毕昇编译器 baseline / native prefetch / proposed pipeline
- 同时需要 PMU 或 `perf stat` 事件采样
- 这些都依赖 LX2 目标环境，当前 Apple Silicon 本机只能完成功能性验证，不能替代该性能实验

