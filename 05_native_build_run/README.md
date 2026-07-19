# 05 Native Build Run

这个目录对应第五步：把第四步统一主线的结果继续编译，并在本机环境中实际运行。

## 目标

第五步现在只有一个主目标：

1. 把第四步的统一产物 [03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir) 继续翻译、编译，并在本机实际运行。

研究主线只有一条，即：

```text
高层 MLIR
-> 预取分析
-> 预取注入
-> vector / arm_sme / llvm
-> 本机编译验证
```

## 当前状态

当前脚本会先尝试统一主线：

```text
03_llvm_prefetch.mlir
-> mlir-translate --mlir-to-llvmir
-> llc -mattr=+sme
-> clang 链接 unified_harness.c
-> 本机运行
```

这里显式加上 `-mattr=+sme`，是因为统一主线里已经包含 streaming SME 相关属性；如果不打开 SME 目标特性，LLVM 后端会拒绝生成目标对象。

这里的统一主线运行现在由两层组成：

- [unified_wrapper.c](/Users/alpaca/Documents/SME/SME1/05_native_build_run/unified_wrapper.c)
  - 直接调用原始 lowering 导出的 `_gemm_step4_compute`
  - 不再把它的原始返回 ABI 直接暴露给普通 C 调用者
  - 明确按“结果就是输出缓冲区 C”来重建稳定的 `memref` 返回描述符

- [unified_harness.c](/Users/alpaca/Documents/SME/SME1/05_native_build_run/unified_harness.c)
  - 调用 `gemm_step4_compute_stable`
  - 同时验证“原地写回的 C”与“wrapper 返回的 descriptor”是否一致

这样做的原因是：

- 统一主线函数本身已经可以运行
- 但原始 lowering 直接导出的返回 ABI，在 Darwin + 当前 llc 产物上不适合作为稳定的普通 C 接口
- 因此第五步单独增加一层稳定 wrapper，把“执行语义”和“研究接口 ABI”解耦

## 当前阶段结论

现在第五步已经可以把统一主线推进到“生成 LLVM IR、编译、链接，并实际运行”：

- `03_llvm_prefetch.mlir` 可以成功翻译为 LLVM IR
- `llc -mattr=+sme` 可以成功生成目标文件
- `clang` 可以成功链接统一主线最小 harness
- `unified_demo` 可以在本机实际运行
- 稳定 wrapper 返回的 `memref descriptor` 也可以被本机 C 代码安全读取

当前运行结果见：

- [output/unified_demo.log](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/unified_demo.log)

当前统一主线输出为：

```text
C =
  12.0   13.0   12.0   13.0
  28.0   29.0   28.0   29.0
  44.0   45.0   44.0   45.0
  60.0   61.0   60.0   61.0
C_from_descriptor =
  12.0   13.0   12.0   13.0
  28.0   29.0   28.0   29.0
  44.0   45.0   44.0   45.0
  60.0   61.0   60.0   61.0
```

因此第五步现在已经完成了“实际运行级验证”。

不过需要明确：

1. 现在验证的是“统一主线函数体 + SME lowering + 预取相关代码”已经能运行。
2. 对外稳定接口使用的是 `unified_wrapper.c` 重建后的 descriptor，而不是直接暴露原始 lowering 产物的返回 ABI。

## 目录结构

- [build_and_run.py](/Users/alpaca/Documents/SME/SME1/05_native_build_run/build_and_run.py)：第五步自动化脚本
- [unified_wrapper.c](/Users/alpaca/Documents/SME/SME1/05_native_build_run/unified_wrapper.c)：统一主线的稳定 ABI wrapper
- [unified_harness.c](/Users/alpaca/Documents/SME/SME1/05_native_build_run/unified_harness.c)：运行统一主线 `gemm_step4_compute` 的最小本机 C harness
- [output/summary.txt](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/summary.txt)：本次构建和运行摘要
- [output/unified_demo.log](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/unified_demo.log)：统一主线本机运行输出

## 如何运行

在仓库根目录执行：

```bash
python3 05_native_build_run/build_and_run.py
```

## 当前预期

根据现在的中间结果：

- 统一主线已经能走到“LLVM IR -> 目标对象 -> 可执行文件 -> 本机运行”

所以第五步现在记录的是“统一主线已经完成运行级验证”。
