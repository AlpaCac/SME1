# 步骤 1：从服务器 C++ 输入生成 kernel-only IR

服务器上的 `stencil_all_sme.cpp` 同时包含多个 stencil 计算函数、测试和
`main`，但该文件不提交到仓库。步骤 1 先保留完整 LLVM IR，再用
`llvm-extract` 生成仅含计算函数的 kernel-only IR；步骤 2 以后只消费后者。

## 输入选择

默认输入是仓库根目录下被 `.gitignore` 排除的 `stencil_all_sme.cpp`：

```bash
./01_llvm_ir_analysis/generate_and_check.sh
```

默认 `MARCH` 包含 `+sme-f64f64`，以支持 `svmopa_za64_f64_m` 等双精度
SME 外积 intrinsic。若服务器源只使用单精度且目标 CPU 不支持该可选扩展，
可显式覆盖 `MARCH=armv9.2-a+sme+sve2`。

若源文件位于其他目录，指定绝对路径：

```bash
STENCIL_SOURCE=/data/stencil_all_sme.cpp \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

默认提取 IR 中名称以 `stencil_` 开头的所有未修饰函数。对于其他命名规则或
C++ 符号修饰，显式给出逗号分隔的 C ABI 函数名：

```bash
STENCIL_KERNEL_FUNCTIONS='stencil_1d3p_sme_f32,stencil_2d9p_sme_f32,stencil_3d27p_sme_f32' \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

运行时驱动通过 C 符号链接 kernel，因此计算函数应使用 `extern "C"` 导出，
或在 C++ 源中提供同名 C ABI 包装函数。`main` 和 test 函数不要加入
`STENCIL_KERNEL_FUNCTIONS`。

## 产物

| 路径 | 作用 |
|---|---|
| `output/stencil_all_sme.full.ll` | 完整模块，包含计算函数、test 和 `main` |
| `output/stencil_all_sme.kernels.ll` | 仅提取的计算函数，步骤 2 的唯一输入 |
| `output/analysis_report.md` | 各提取函数的循环、GEP、load/store、SVE/SME 指标 |

文件名会随 `STENCIL_SOURCE` 的基名变化。可用 `STENCIL_KERNEL_IR` 覆盖步骤
2/5 中默认的 kernel-only IR 路径。

## 算子范围

IR 报告可以记录任意被提取的函数。当前 pass 识别并可插入预取的 load 模式为：

1. 1D3P
2. 2D5P、2D9P
3. 3D7P、3D13P、3D25P、3D27P

识别要求最内层为 `cntsw()`（f32）或 `cntsd()`（f64）步长的 predicated SVE 循环，并且各 load/store
共享 `whilelo` 谓词。其他算子会保留在 kernel-only IR 中，但不会被错误地
插入预取。
