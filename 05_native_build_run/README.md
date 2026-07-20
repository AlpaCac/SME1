# 05 Native Build Run

本目录对应总体方案的第五步：将第四步生成的 LLVM dialect MLIR 继续导出为 LLVM IR，并编译成汇编、目标文件和本机可执行文件。

当前主线是：

```text
04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir
-> output/step4_llvm_prefetch.ll
-> output/step4_llvm_prefetch.s
-> output/step4_llvm_prefetch.o
-> output/step4_llvm_prefetch_demo
```

## 1. 输入

输入文件是第四步最终产物：

- [../04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir)

该文件已经包含：

- `llvm.func`
- `llvm.intr.prefetch`
- `arm_sme.intr.*`
- `arm_sve.intr.*`

## 2. 输出

第五步会生成：

- [output/step4_llvm_prefetch.ll](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/step4_llvm_prefetch.ll)：LLVM IR 文本
- [output/step4_llvm_prefetch.s](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/step4_llvm_prefetch.s)：AArch64 汇编
- `output/step4_llvm_prefetch.o`：目标文件
- `output/step4_llvm_prefetch_demo`：最小可执行文件
- [output/step4_llvm_prefetch_demo.log](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/step4_llvm_prefetch_demo.log)：运行输出
- [output/summary.txt](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/summary.txt)：构建摘要

## 3. 工具

当前使用本机已有工具：

- `mlir-translate`：把 LLVM dialect MLIR 导出为 LLVM IR `.ll`
- `llc -mattr=+sme`：把 `.ll` 编译成汇编和目标文件
- `/usr/bin/clang`：把目标文件和最小 harness 链接成可执行文件

其中 `-mattr=+sme` 是必要的，因为第四步输出中包含 Arm SME intrinsic。

## 4. 如何运行

在仓库根目录执行：

```bash
python3 05_native_build_run/build_and_run.py
```

脚本会依次执行：

```bash
mlir-translate --mlir-to-llvmir
llc -mattr=+sme -filetype=asm
llc -mattr=+sme -filetype=obj
clang step4_llvm_prefetch.o native_harness.c
```

## 5. Harness 说明

[native_harness.c](/Users/alpaca/Documents/SME/SME1/05_native_build_run/native_harness.c) 提供一个最小 `main` 函数。

它构造 4x4 的 A、B、C 矩阵，然后调用第四步导出的函数：

```c
gemm_fp32_linalg(...)
```

调用参数采用 MLIR memref descriptor 展开形式：

```text
allocated pointer, aligned pointer, offset, size0, size1, stride0, stride1
```

这样可以让没有 `main` 的 LLVM IR kernel 被链接成可执行文件。

## 6. 验证点

生成 `.ll` 后检查：

```llvm
call void @llvm.prefetch.p0(...)
```

生成 `.s` 后检查：

```asm
prfm
fmopa
smstart
```

其中：

- `prfm` 说明预取 intrinsic 被后端选择为 AArch64 预取指令
- `fmopa` 说明 SME matrix outer product intrinsic 被后端选择为 SME 指令
- `smstart` 说明函数进入 SME streaming/ZA 相关状态

## 7. 一句话总结

第五步把第四步的 LLVM dialect 产物推进到本机可执行层，验证预取语义和 SME 计算语义可以继续进入 LLVM IR、汇编和可执行文件。
