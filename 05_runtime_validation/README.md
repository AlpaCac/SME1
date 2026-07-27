# 步骤 5：运行时正确性与性能验证

步骤 4 已完成预取 pass。本目录提供真实 SME 机器上的数值正确性入口：

```bash
./05_runtime_validation/build_and_run.sh
```

脚本构建无插件基线和带插件版本。`stencil_correctness.c` 使用标量
2D5P/3D7P 作为参考，覆盖最小合法尺寸、非规则宽度和尾部。

Apple M5 支持 SME/SME2，但不提供普通 SVE。基线和预取版本均由步骤 4
从同一 LLVM 18 兼容 IR、同一 `-O1` 管线生成，唯一变量是是否加载 pass；
本目录再用系统 Clang 和 `-march=armv9.2-a+nosve+sme` 分别组装两份
汇编。测试驱动保持普通 arm64 目标，再分别与两个 kernel 对象链接。不能
对整个程序全局启用 `+sve2`，否则编译器可能在 `main` 或 `smstart` 之前
生成 `addvl/cntd`。

LLVM 18 前端在 `+nosve+sme` 下仍会拒绝源代码中的 SVE ACLE 类型，因此
步骤 4 保留 `+sme+sve2` 进行不执行的 IR/汇编检查；步骤 5 使用上述分离
方式执行插件产物。

脚本会查询 SME feature；受限环境无法读取 sysctl 时可设置
`FORCE_SME_RUN=1`。

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
```

参数分别是 `baseline|prefetch` 和 `2d|3d`。脚本通过 Xcode `xctrace`
保存 trace、TOC 和 `CountingModeSamples` XML；该操作需要系统允许访问
CPU Counters。默认模板主要给出模型化瓶颈采样，不等同于原始 L1D/L2
miss 计数。精确 cache 事件需要在 Instruments 中配置并保存自定义模板，
再通过 `CPU_COUNTERS_TEMPLATE=/path/to/template.tracetemplate` 传入。
