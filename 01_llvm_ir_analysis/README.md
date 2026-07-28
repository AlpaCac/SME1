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

默认提取源码名以 `stencil_` 或 `stencil` 后紧接数字开头的函数，支持命名空间和
类作用域，例如 `stencil1D_3point_sme()`、`kernels::stencil1D_3point_sme()`。
脚本会同时匹配 LLVM 原始符号和解修饰后的 C++ 名称；优先使用同一 LLVM 安装中的
`llvm-cxxfilt`，缺失时回退到系统的 `c++filt`。若使用其他命名规则，可显式给出
逗号分隔的 IR 函数名：

生成 IR 时脚本使用 `-O1 -fno-inline`。这会保留被 `main` 或测试代码调用的
`static` stencil 函数的独立 `define`，否则它们可能在函数发现前已被内联移除。

```bash
STENCIL_KERNEL_FUNCTIONS='stencil_1d3p_sme_f32,stencil_2d9p_sme_f32,stencil_3d27p_sme_f32' \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

也可以覆盖自动发现正则。例如以下规则匹配全部以 `stencil` 开头的函数：

```bash
STENCIL_KERNEL_PATTERN='stencil' ./01_llvm_ir_analysis/generate_and_check.sh
```

自动发现失败时，脚本会打印 IR 原始符号与对应的解修饰名称。根据该输出可设置
`STENCIL_KERNEL_PATTERN`，或用 `STENCIL_KERNEL_FUNCTIONS` 精确指定需要提取的
IR 符号。

`analysis_report.md` 的检查项用于描述 IR 特征而非拒绝输入。不同 Clang 版本可将
等价循环降低为 `i32` PHI、`whilelt`（有符号尾掩码）、SVE `cnt*` 或通用的
`llvm.vscale`，这些形式都会被报告识别。某项为 `FAIL` 只表示未观察到该特征，
步骤 1 仍会成功生成 kernel-only IR；步骤 2 的预取 pass 会独立应用更严格的
可插入判定。

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
