# 步骤 1：确认 Clang LLVM IR 可分析

本目录落实 `stencil预取优化实施方案.md` 第三部分的步骤 1。目标是证明原始 SME/SVE ACLE C kernel 经 Clang `-O1` 编译后，LLVM IR 仍保留后续 `StencilPrefetchPass` 所需的循环、地址和向量访存信息。

## 文件

| 文件 | 说明 |
|---|---|
| `generate_and_check.sh` | 从仓库根目录的 C kernel 生成 LLVM IR，并运行自动检查 |
| `check_ir.py` | 按函数检查循环、GEP、masked load/store、SVE/SME intrinsic 和函数属性 |
| `output/stencil_sme_kernels.ll` | 当前 Clang 生成的 LLVM IR |
| `output/analysis_report.md` | 自动检查结果和后续 pass 可使用的信息 |

## 运行

```bash
./01_llvm_ir_analysis/generate_and_check.sh
```

可覆盖编译器和目标参数：

```bash
CLANG=/path/to/clang \
TARGET=arm64-apple-macos15 \
MARCH=armv9.2-a+sme+sve2 \
./01_llvm_ir_analysis/generate_and_check.sh
```

脚本执行：

```text
stencil_sme_kernels.c
-> clang -O1 -S -emit-llvm
-> output/stencil_sme_kernels.ll
-> check_ir.py
-> output/analysis_report.md
```

## 验收条件

两个函数都必须满足：

1. 函数属性包含 `aarch64_pstate_sm_body`。
2. 调用 `llvm.aarch64.sme.cntsw`。
3. 存在 `phi i64` 和回边分支所表示的循环。
4. 存在 `getelementptr` 地址计算。
5. 存在 SVE 浮点算术和一个 masked store。

逻辑输入 load 数必须为：

1. `stencil_2d5p_sme_f32`：5 个 `llvm.masked.load`
2. `stencil_3d7p_sme_f32`：7 个 `llvm.masked.load`

检查工具不依赖 SSA 名称、基本块编号或固定源码行号。后续 LLVM pass 仍应使用 `LoopInfo`、ScalarEvolution 和 DominatorTree 完成正式识别。
