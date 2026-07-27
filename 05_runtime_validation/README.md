# 步骤 5：运行时正确性与性能验证

## 目录结构与文件说明

### 顶层文件

| 文件 | 作用 |
|---|---|
| `README.md` | 说明步骤 5 的验证目标、运行方法、文件结构和当前实验结论。 |
| `build_and_run.sh` | 正确性验证主入口。组装步骤 4 生成的基线/预取汇编，构建测试程序，探测 SME 和 streaming VL，并运行 2D5P/3D7P 正确性测试。 |
| `run_benchmark.sh` | 分别启动基线和预取可执行文件，建立初始独立进程墙钟性能基线。 |
| `run_paired_benchmark.sh` | 将基线与预取 kernel 链接到同一进程，交替执行并计算配对加速比，降低启动、温度和调度漂移。 |
| `run_profile_sweep.sh` | 扫描 2D row-L1 和 3D plane-L1 的预取距离，并跨 row/plane 大小复测候选参数。 |
| `run_ablation.sh` | 分别关闭或只保留 row、plane-L1、plane-L2 预取，判断每一类预取的独立贡献。 |
| `collect_cpu_counters.sh` | 使用 Xcode `xctrace` 对一个基线或预取程序采集 CPU Counters，导出 XML 并累加目标进程事件。 |
| `run_cpu_counter_comparison.sh` | 交替采集基线和预取版本的 L1D/PL2 事件，汇总多轮 PMU 相对变化。 |
| `run_threaded_benchmark.sh` | 运行 1/2/4/8 个独立 3D7P 网格的多线程配对测试，检查共享 cache 和内存带宽竞争下的预取收益。 |
| `stencil_correctness.c` | 标量参考与正确性驱动，覆盖空内部区域、最小尺寸、不规则宽度、谓词尾部和前后 guard page。 |
| `stencil_benchmark.c` | 独立进程 2D5P/3D7P 墙钟基准驱动，输出中位时间、GUP/s 和 checksum。 |
| `stencil_paired_benchmark.c` | 同一进程内的基线/预取配对驱动，奇偶样本交换执行顺序。 |
| `stencil_threaded_benchmark.c` | pthread 多线程 3D7P 配对驱动，每个线程使用独立输入输出网格。 |
| `sme_runtime_info.c` | 在 locally-streaming 函数中调用 `svcntb()`，读取目标机实际 SME streaming vector length。 |

### 生成目录与报告

| 路径 | 作用 |
|---|---|
| `build/` | 本地构建目录，包含对象文件、重命名汇编、LLVM IR 和测试可执行文件；由脚本重新生成，不提交到仓库。 |
| `output/correctness_report.md` | Apple M5 数值正确性、编译器、Profile、streaming VL 和 guard-page 覆盖结果。 |
| `output/benchmark_report.md` | 独立进程初始墙钟性能结果。 |
| `output/paired_benchmark_report.md` | 单进程配对性能中位数和轮间范围，是当前单线程性能判断的主要依据。 |
| `output/profile_sweep_report.md` | 2D/3D 距离扫描和跨尺寸复测结果。 |
| `output/ablation_report.md` | row、plane-L1、plane-L2 类别消融结果。 |
| `output/pmu_comparison_report.md` | Apple M5 L1D/PL2 原始归因采样的基线/预取对比。 |
| `output/threaded_benchmark_report.md` | 1/2/4/8 线程独立网格的配对性能结果。 |
| `output/runtime_info.log` | 目标机 SME feature 和实际 streaming VL 探测结果。 |
| `output/*.log` | 各次正确性、性能和消融运行的原始文本输出；汇总报告由这些日志生成。 |
| `output/pmu_*/` | Instruments trace、TOC、原始 XML 和计数器累加值；文件较大，仅保存在本地，不提交到仓库。 |

除 README 外，顶层 `.sh` 文件是实验入口，顶层 `.c` 文件是对应的测试
驱动。通常不应手工修改 `build/` 内容；重新运行相应脚本即可重建。

步骤 4 已完成预取 pass。本目录提供真实 SME 机器上的数值正确性入口：

```bash
./05_runtime_validation/build_and_run.sh
```

脚本构建无插件基线和带插件版本。`stencil_correctness.c` 使用标量
2D5P/3D7P 作为参考，覆盖最小合法尺寸、非规则宽度和尾部。每个 case
分别贴近前后 `PROT_NONE` guard page 执行，检查真实 load/store 不越界。
`PRFM` 是非故障型提示，guard page 不替代 IR 中未来地址 guard 和
非 `inbounds` GEP 的结构检查。

Apple M5 支持 SME/SME2，但不提供普通 SVE。基线和预取版本均由步骤 4
从同一 LLVM 18 兼容 IR、同一 `-O1` 管线生成，唯一变量是是否加载 pass；
本目录再用系统 Clang 和 `-march=armv9.2-a+nosve+sme` 分别组装两份
汇编。测试驱动保持普通 arm64 目标，再分别与两个 kernel 对象链接。不能
对整个程序全局启用 `+sve2`，否则编译器可能在 `main` 或 `smstart` 之前
生成 `addvl/cntd`。

LLVM 18 前端在 `+nosve+sme` 下仍会拒绝源代码中的 SVE ACLE 类型，因此
步骤 4 保留 `+sme+sve2` 进行不执行的 IR/汇编检查；步骤 5 使用上述分离
方式执行插件产物。

`sme_runtime_info.c` 在 locally-streaming 函数中调用 `svcntb()`，记录
目标机实际 streaming VL，用于核对 Profile 的 assumed VL。

脚本会查询 SME feature；受限环境无法读取 sysctl 时可设置
`FORCE_SME_RUN=1`。

运行命名的 Apple M5 Profile：

```bash
SME_RUNTIME_PROFILE=apple-m5 FORCE_SME_RUN=1 \
  ./05_runtime_validation/build_and_run.sh
SME_RUNTIME_PROFILE=apple-m5 FORCE_SME_RUN=1 \
  ./05_runtime_validation/run_paired_benchmark.sh
```

性能和 PMU 测量必须在确定的目标 CPU、streaming VL、线程绑定和问题规模
下完成，不能使用当前非 SME 主机的数据代替。

初始墙钟性能对比：

```bash
FORCE_SME_RUN=1 ./05_runtime_validation/run_benchmark.sh
```

默认使用约 64 MiB 输入、7 个样本的中位数；规模、重复次数和样本数可由
`STENCIL_2D_HEIGHT`、`STENCIL_2D_WIDTH`、`STENCIL_3D_DEPTH`、
`STENCIL_3D_HEIGHT`、`STENCIL_3D_WIDTH`、`STENCIL_REPETITIONS` 和
`STENCIL_SAMPLES` 覆盖。结果写入 `output/benchmark_report.md`。该基准
只建立墙钟基线，不能替代后续的 Profile 消融和 PMU 归因。

同进程配对性能对比：

```bash
FORCE_SME_RUN=1 ./05_runtime_validation/run_paired_benchmark.sh
```

该脚本重命名两份汇编中的 kernel 符号并链接到同一驱动，奇偶样本交换
基线/预取的执行顺序，报告每对样本加速比的中位数。它用于降低独立进程
测试中的启动、温度和调度漂移。默认再执行 3 个外层轮次并报告轮间中位数
与范围，可用 `STENCIL_ROUNDS` 覆盖。

2D/3D 分算子距离扫描：

```bash
FORCE_SME_RUN=1 ./05_runtime_validation/run_profile_sweep.sh
```

该脚本扫描距离 `1/2/4/8`：2D 测量 row-L1 KEEP，3D 测量
plane-L1 STRM-only。每个配置都和同管线无预取基线进行同进程配对，结果
写入 `output/profile_sweep_report.md`。

预取类别消融：

```bash
FORCE_SME_RUN=1 ./05_runtime_validation/run_ablation.sh
```

该脚本用环境 Profile 覆盖生成 row/plane L1/L2 的关闭和单类别版本，分别
测量 2D 与 3D，结果写入 `output/ablation_report.md`。所有版本均从同一
LLVM 18 IR 和 `-O1` 管线生成。

Apple M5 CPU Counters 采集：

```bash
./05_runtime_validation/collect_cpu_counters.sh baseline 3d
./05_runtime_validation/collect_cpu_counters.sh prefetch 3d
./05_runtime_validation/run_cpu_counter_comparison.sh 3d
```

参数分别是 `baseline|prefetch` 和 `2d|3d`。脚本通过 Xcode `xctrace`
保存 trace 和 TOC；该操作需要系统允许访问 CPU Counters。若本机存在
`SME Stencil Cache Counters` 用户模板，脚本默认使用其中的
`ARM_L1D_CACHE_RD`、`ARM_L1D_CACHE_LMISS_RD`、`PL2_CACHE_ACCESS` 和
`PL2_CACHE_MISS_LD`，导出 `counters-profile` 并按目标进程累加。否则回退
到系统 `CPU Counters` 模板。`run_cpu_counter_comparison.sh` 交替采集两种
版本并生成 `output/pmu_comparison_report.md`；可用 `PMU_ROUNDS` 调整轮数。

自定义模板在 Instruments 中由 `CPU Counters -> Configuration: Manual`
创建。原始事件表使用 1 ms 归因采样，因此结果适合在相同模板和规模下做
相对比较，不是无采样误差的架构事件总数。

当前 3D 三轮结果中，预取/基线的 PL2 access 比值为 `12.25x`
（逐轮 `8.59-16.27x`），PL2 load miss 为 `50.85x`
（逐轮 `30.09-55.65x`），增长方向稳定；L1D read 和 long-latency miss
的中位数比值约为 `0.91x/0.89x`，但逐轮范围跨过 `1.0` 且波动较大，
暂不能断言 L1D miss 已稳定下降。这说明 distance-1 plane 预取用明显增加
的 PL2 流量换取约 `2.8%` 的配对墙钟收益，多线程和带宽竞争场景仍需验证。

3D 多线程带宽竞争测试：

```bash
FORCE_SME_RUN=1 ./05_runtime_validation/run_threaded_benchmark.sh
```

该脚本用 1/2/4/8 个线程分别处理独立网格，链接同一份基线和 `apple-m5`
预取 kernel，并在同一进程内交替测量。它不模拟域分解通信，只用于判断
额外 PRFM/PL2 流量在共享缓存和内存带宽竞争下是否仍有收益。

当前每线程 `256x32x1024`、8 次重复、9 个交替样本和 3 个外层轮次的
结果为：1/2/4/8 线程配对中位数分别 `1.043x/1.107x/1.114x/1.095x`，
各自轮间范围均保持在 `1.0` 以上。因而在本机独立网格压力下，额外 PL2
流量尚未抵消收益；8 线程范围扩大到 `1.047-1.129x`，仍需在真实域分解、
线程亲和性和系统负载可控的应用中复测。
