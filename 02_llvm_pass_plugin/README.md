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

## Profile 调优接口

Pass 不再提供按算子或按类别启用的 mask。current-L1、row-L1、plane-L1、plane-L2
候选都由 IR 物理流结构产生，然后统一计算隐藏周期、复用收益、发射成本、cache
压力、带宽成本和置信度。候选只有同时满足全局收益与置信度阈值并通过资源预算才会
插入；资源不足时优先保留 score 和置信度更高的候选。全局接口为：

```text
SME_PREFETCH_MIN_PROFIT_SCORE
SME_PREFETCH_MIN_CONFIDENCE
SME_PREFETCH_ISSUE_COST
SME_PREFETCH_CACHE_PRESSURE_WEIGHT
SME_PREFETCH_BANDWIDTH_WEIGHT
SME_PREFETCH_UNKNOWN_TRIP_PENALTY
```

距离为 0、策略为 `AUTO` 时保留分析模型；显式距离和策略覆盖仅用于受控实验。

分析模型的硬件输入也可由服务器 Profile 覆盖：

```text
SME_PREFETCH_CACHE_LINE_BYTES
SME_PREFETCH_STREAMING_VL_BYTES
SME_PREFETCH_L1_CAPACITY_BYTES / SME_PREFETCH_L2_CAPACITY_BYTES
SME_PREFETCH_L1_CAPACITY_PERCENT / SME_PREFETCH_L2_CAPACITY_PERCENT
SME_PREFETCH_L1_LATENCY_CYCLES / SME_PREFETCH_L2_LATENCY_CYCLES
SME_PREFETCH_MEMORY_LATENCY_CYCLES
SME_PREFETCH_USEFUL_CYCLES_2D / SME_PREFETCH_USEFUL_CYCLES_3D
SME_PREFETCH_MAX_DISTANCE
```

这些量用于推导层级传输延迟、按逻辑 load 数缩放迭代周期，并计算预取前沿容量。
KEEP/STRM 根据 SCEV 可证明的 cache-line 内直接复用决定；缺少外层驻留证据的
plane-L1/L2 在 AUTO 下均使用 STRM。模型不读取或猜测具体 row/plane 大小。
不能把一台机器生成的硬件值直接复制到
另一台机器。

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
