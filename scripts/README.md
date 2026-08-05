# 服务器临时执行脚本

这些脚本用于独立 LLVM 部署流程，均假定独立 LLVM 已由
`tools/install_standalone_llvm.sh` 安装到仓库的 `tools/llvm-19.1.7`。

在仓库根目录按以下顺序执行：

```bash
./scripts/01_check_standalone_llvm_ir.sh
./scripts/02_build_and_test_pass.sh
./scripts/03_validate_server_runtime.sh
./scripts/calibrate_server_model.sh
./scripts/04_tune_server_profile.sh
./scripts/05_validate_tuned_profile.sh
```

第一个脚本只验证独立 LLVM `opt` 能读取 BiSheng 在步骤 1 生成的完整 IR；它不改写
IR。第二个脚本用独立 LLVM 构建并回归测试预取 pass，默认使用步骤 1 生成的
kernel-only IR。

第三个脚本使用步骤 1 的完整 IR，保留服务器原始 `stencil_all_sme.cpp` 中的
test 和 `main`，分别构建无预取 baseline 与带预取版本，先运行正确性测试，
默认逐一向 `main` 传入六类算子的 `s1/s2` 参数，每个版本执行一次，并从原程序
输出提取 `Total Time`。显式关闭单次模式后才进行预热和多轮测量。执行前用
`BISHENG_CXX` 指向毕昇 `clang++`；建议用 `STENCIL_CPU` 绑定固定 CPU。

如需调整独立 LLVM 安装位置，可在执行前设置：

```bash
export STANDALONE_LLVM=/path/to/llvm-19.1.7
```

步骤 4 从 `profiles/tuning_cases.csv` 读取用例。它先用阈值 0 仅编译一次，从
`pass_run.log` 收集分析模型实际生成的 score，并以每个唯一 score 的下一整数作为
全局阈值边界。随后在全部训练场景上测试这些边界，不再枚举预取类别组合。要求每个
已知场景不退化、加权几何平均至少 1.03，任一版本的相对 MAD 不
超过 0.03。可用 `STENCIL_TUNE_MIN_CASE_SPEEDUP`、
`STENCIL_TUNE_MIN_GEOMEAN` 和 `STENCIL_TUNE_MAX_RELATIVE_MAD` 覆盖。原始数据保存在：

```text
05_runtime_validation/output/server-profile-tuning/candidate_results.csv
05_runtime_validation/output/server-profile-tuning/profile_selection.csv
05_runtime_validation/output/server-profile-tuning/decision_inventory.csv
05_runtime_validation/output/server-profile-tuning/threshold_diagnostics.csv
05_runtime_validation/output/server-profile-tuning/diagnostic_report.md
```

`decision_inventory.csv` 保存阈值 0 时每条候选的 stream、层级、距离、score、置信度、
收益和成本；`threshold_diagnostics.csv` 关联每个 threshold 的实际 PRFM、admitted
决策、四类流数量和逐用例改善/退化计数。`diagnostic_report.md` 自动检查：0 预取版本
是否仍偏离 baseline、admitted 与 IR PRFM 是否一致、同一 threshold 是否同时改善和
退化不同用例，以及同一 score 是否混入不同 stream/cache 结构。该报告采用紧凑的
`SEL/SCORE/THR/ALERT` 单行格式，便于无法导出服务器文件时手工抄写；`SCORE`
还包含距离范围 `D` 和策略 `P`，详细数据仍保留在两个 CSV 中。变化分类默认使用
1% 容差，0 预取一致性默认使用 2% 容差，可分别通过
`STENCIL_DIAGNOSTIC_CHANGE_TOLERANCE` 和
`STENCIL_DIAGNOSTIC_ZERO_PREFETCH_TOLERANCE` 覆盖。

获胜的全局 `SME_PREFETCH_MIN_PROFIT_SCORE` 与硬件校准得到的成本参数写入本地
忽略文件 `profiles/server-sme.env`。Profile 不包含算子 mask 或类别开关。距离保持
`0`、策略保持 `AUTO`，Pass 在每次编译时根据当前函数的循环、物理流、cache 和 VL
计算具体距离与 KEEP/STRM。步骤 5 加载 Profile 后重新执行全部正确性测试和性能采样。默认
清单没有独立留出行，因此复测全部 `train` 场景；未来存在 `validate` 行时则自动
只用留出场景决定性能是否通过。步骤 4 默认复用清单、参数和样本数完全一致的已
完成候选，中断后可直接重跑；设置 `STENCIL_TUNE_RESUME=0` 强制重测。

步骤 4 会自动探测 Linux sysfs 中的 L1/L2 容量和 cache line，并把所有实际采用的
硬件与模型参数纳入候选缓存签名。SME streaming VL 从
`/proc/sys/abi/sme_default_vector_length` 读取。四项硬件值检测失败时脚本直接停止，
必须通过 `SME_PREFETCH_*` 提供实测值，不再静默回退 generic 默认值。

其余模型输入从服务器本地 `profiles/server-model.env` 加载，模板为
`profiles/server-model.env.example`。缺少 latency、useful cycles、容量比例或资源
预算时脚本会列出全部缺项并停止，不再使用内建初始值继续运行。矩阵 row/plane
字节数不再是模型输入，也不需要人工填写或校准。

`calibrate_server_model.sh` 可自动生成该文件。它通过 `perf_event_open` 读取真实 CPU
cycle PMU：随机依赖加载分别使用 L1、L2 和超过末级 cache 的工作集；2D5P/3D7P
SVE 循环测量每次向量迭代周期。轻量 stencil 给出同维算子的周期下界，使距离模型
不会因使用较重算子而低估提前量。Cache 有效占比按相联度保留一个 way；资源预算
扫描 1 至 17 条独立随机流，选择达到近峰值单 cache-line 吞吐（最佳值 5% 内）所需
的最小流数，再按 `ceil(VL/cache_line)` 推导指令和字节上限。PMU 权限不足时脚本停止，不使用
墙钟时间伪造周期。运行前必须设置 `BISHENG_CXX`，可用
`SME_CALIBRATION_SAMPLES`、`SME_CALIBRATION_ACCESSES` 和
`SME_CALIBRATION_STREAM_ACCESSES`、`SME_CALIBRATION_MAX_MEMORY_BYTES` 控制校准
开销；流扫描默认每个并发度共执行 100 万次访问。容器未暴露 cache 相联度或末级
cache 时，可显式提供 `SME_CALIBRATION_L1_WAYS`、`SME_CALIBRATION_L2_WAYS` 和
`SME_CALIBRATION_LAST_CACHE_BYTES`，但这些值应来自服务器硬件资料。

脚本不再人为定义距离、策略、容量比例或预算候选，也不枚举这些参数的组合。快速
检查可以使用单样本：

```bash
STENCIL_TUNE_WARMUPS=0 STENCIL_TUNE_SAMPLES=1 ./scripts/04_tune_server_profile.sh
```

单样本只用于确认阈值发现和写回链路，正式 Profile 必须使用多样本稳定性门槛。
`tmp2.sh` 默认开启候选复用；样本数、模型输入或评分边界发生变化时签名会
自动失效，因此无需用 `STENCIL_TUNE_RESUME=0` 来保证正式数据的新鲜度。
