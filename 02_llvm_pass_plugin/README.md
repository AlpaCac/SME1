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

识别器按 masked load 数、共同 `whilelo`/`whilelt`、可缩放
`cnt*`/`llvm.vscale` 步长及 SCEV 地址差进行判断。地址差为常量的 load 会合并为
同一条连续 x 流，再根据成对的行/平面地址差选择中心流并验证维度拓扑。这一规则
不依赖 Clang 是否把行偏移和向量 IV 折叠进同一个 GEP。2D9P 与
3D25P/27P 的对角邻域会合并到相应 row 或 plane 流；当候选流多于硬件预算时，
决策器按 L1/L2 容量、流数、指令数与带宽预算筛选。

1D3P 的 current-row L1 预取默认开启，以便在服务器上与其余算子一起验证。若硬件
流预取器已经覆盖该连续流，可在性能实验中关闭：

```bash
SME_PREFETCH_ENABLE_CURRENT_L1=0
```

## Profile 调优接口

自动调优脚本通过环境变量覆盖默认分析模型，不修改 C++ 源文件：

| 类别 | 开关 | 算子掩码 | 距离 | 策略 |
|---|---|---|---|---|
| current L1 | `SME_PREFETCH_ENABLE_CURRENT_L1` | `SME_PREFETCH_MASK_CURRENT_L1` | `SME_PREFETCH_DISTANCE_CURRENT_L1` | `SME_PREFETCH_POLICY_CURRENT_L1` |
| row L1 | `SME_PREFETCH_ENABLE_ROW_L1` | `SME_PREFETCH_MASK_ROW_L1` | `SME_PREFETCH_DISTANCE_ROW_L1` | `SME_PREFETCH_POLICY_ROW_L1` |
| plane L1 | `SME_PREFETCH_ENABLE_PLANE_L1` | `SME_PREFETCH_MASK_PLANE_L1` | `SME_PREFETCH_DISTANCE_PLANE_L1` | `SME_PREFETCH_POLICY_PLANE_L1` |
| plane L2 | `SME_PREFETCH_ENABLE_PLANE_L2` | `SME_PREFETCH_MASK_PLANE_L2` | `SME_PREFETCH_DISTANCE_PLANE_L2` | `SME_PREFETCH_POLICY_PLANE_L2` |

距离为 0、策略为 `AUTO` 时保留分析模型。策略覆盖接受 `AUTO`、`KEEP`、`STRM`。
掩码按 `StencilKind` 位编号组合：

```text
1D3P=1, 2D5P=2, 2D9P=4, 3D7P=8,
3D13P=16, 3D25P=32, 3D27P=64
```

例如仅对 2D9P 启用 row-L1：

```bash
SME_PREFETCH_ENABLE_ROW_L1=1 \
SME_PREFETCH_MASK_ROW_L1=4 \
SME_PREFETCH_DISTANCE_ROW_L1=6 \
SME_PREFETCH_POLICY_ROW_L1=STRM
```

分析模型的硬件与工作集输入也可由服务器 Profile 覆盖：

```text
SME_PREFETCH_CACHE_LINE_BYTES
SME_PREFETCH_STREAMING_VL_BYTES
SME_PREFETCH_L1_CAPACITY_BYTES / SME_PREFETCH_L2_CAPACITY_BYTES
SME_PREFETCH_L1_CAPACITY_PERCENT / SME_PREFETCH_L2_CAPACITY_PERCENT
SME_PREFETCH_L1_LATENCY_CYCLES / SME_PREFETCH_L2_LATENCY_CYCLES
SME_PREFETCH_MEMORY_LATENCY_CYCLES
SME_PREFETCH_EXPECTED_ROW_BYTES / SME_PREFETCH_EXPECTED_PLANE_BYTES
SME_PREFETCH_USEFUL_CYCLES_2D / SME_PREFETCH_USEFUL_CYCLES_3D
SME_PREFETCH_MAX_DISTANCE
```

这些量用于归一化距离、容量和复用模型。不能把一台机器生成的值直接复制到另一台
机器，也不能把单个示例尺寸的 row/plane 大小当作所有运行时输入的真实大小。

## 构建与运行

步骤 1 成功后：

若服务器 PATH 中有同一 LLVM 安装的 `llvm-config`、`clang`、`clang++` 和 CMake，
脚本会从 `llvm-config` 自动定位 Clang 与 LLVM CMake 配置，不需要设置
`LLVM_HOME`：

```bash
command -v clang clang++ llvm-config cmake
llvm-config --version
llvm-config --bindir
llvm-config --cmakedir
test -f "$(llvm-config --cmakedir)/LLVMConfig.cmake" && echo 'LLVM CMake config: OK'

./02_llvm_pass_plugin/build_and_test.sh
```

脚本优先使用该 LLVM 安装中的 `bin/opt`，在步骤 1 已生成的 `-O1` IR 上显式运行
`function(stencil-prefetch),verify`。这样统计的是 Pass 直接输出，不会被后续
Clang 优化提前合并或删除。可用 `LLVM_OPT=/path/to/opt` 覆盖；只有裁剪版开发
环境确实没有 `opt` 时才回退到 `-fpass-plugin`。

检测到 Ninja 时脚本使用 Ninja；未安装时自动回退到 CMake `Unix Makefiles`，只需
系统提供 `make`。也可用 `CMAKE_GENERATOR` 显式指定生成器。

`llvm-config --version` 应与 `clang --version` 的 LLVM 主版本一致。若
`llvm-config` 不在 PATH，先通过其绝对路径推导 LLVM 安装前缀：

```bash
export LLVM_CONFIG=/path/to/llvm-config
export LLVM_HOME="$(dirname "$(dirname "$(readlink -f "${LLVM_CONFIG}")")")"
export PATH="${LLVM_HOME}/bin:${PATH}"
```

只有 `clang` 而找不到 `llvm-config` 或 `LLVMConfig.cmake` 时，当前安装不包含
pass 开发文件，不能构建插件；需要获取与加载插件的 Clang ABI 兼容的完整 LLVM
开发包。

同样确认 LLVM 头文件实际存在：

```bash
llvm-config --includedir
test -f "$(llvm-config --includedir)/llvm/ADT/SmallVector.h" && echo 'LLVM headers: OK'
```

若此检查失败，不能通过添加 CMake include 参数修复；应安装匹配版本的 LLVM
development/devel 包，或将 `LLVM_CONFIG` 指向包含 `include/llvm` 的完整 BiSheng
LLVM 安装。

```bash
LLVM_CONFIG=/path/to/llvm-config \
LLVM_CLANG=/path/to/clang \
LLVM_OPT=/path/to/opt \
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

如果提取的函数中没有任何一个匹配当前 stencil 模型，脚本默认失败以避免把“没有
优化”误报为成功。仅检查提取流程时可设置 `STENCIL_REQUIRE_RECOGNIZED=0`。
