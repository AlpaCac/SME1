# 步骤 2-4：多算子 LLVM 预取插件

步骤 2 构建 `StencilPrefetchPass`，步骤 3 在 kernel-only IR 中识别 stencil
流，步骤 4 决策并插入 `llvm.aarch64.prefetch`。完整 C++ 模块中的 `main` 和
test 已在步骤 1 被排除，因此 pass 不依赖函数名前缀，也不会分析运行时驱动。

## 支持的识别模式

| 维度 | 算子 |
|---|---|
| 1D | 3P |
| 2D | 5P、9P |
| 3D | 7P、13P、25P、27P |

识别器按 masked load 数、中心连续 x 流、共同 `whilelo`、`cntsw`/`cntsd` 步长及相对
行/平面地址归并进行判断。2D9P 与 3D25P/27P 的对角邻域会合并到相应 row 或
plane 流；当候选流多于硬件预算时，决策器按 L1/L2 容量、流数、指令数与带宽
预算筛选。

1D3P 的 current-row 预取默认关闭，因为它是连续流。需要实验时设置：

```bash
SME_PREFETCH_ENABLE_CURRENT_L1=1
```

## 构建与运行

步骤 1 成功后：

```bash
LLVM_CONFIG=/path/to/llvm-config \
LLVM_CLANG=/path/to/clang \
PLUGIN_CC=/path/to/clang \
PLUGIN_CXX=/path/to/clang++ \
  ./02_llvm_pass_plugin/build_and_test.sh
```

默认输入是 `01_llvm_ir_analysis/output/stencil_all_sme.kernels.ll`。使用非默认
源文件基名时，显式传入：

```bash
STENCIL_KERNEL_IR=/path/to/output/custom.kernels.ll \
  ./02_llvm_pass_plugin/build_and_test.sh
```

主要产物为：

```text
output/stencil_kernels.after.ll      # 插入预取后的 kernel-only IR
output/stencil_kernels.baseline.s    # kernel-only 无插件汇编
output/stencil_kernels.s             # kernel-only 带 PRFM 的汇编
output/stencil_recognition_report.md
output/stencil_prefetch_decision_report.md
```

如果提取的函数中没有任何一个匹配当前 7 类模型，脚本默认失败以避免把“没有
优化”误报为成功。仅检查提取流程时可设置 `STENCIL_REQUIRE_RECOGNIZED=0`。
