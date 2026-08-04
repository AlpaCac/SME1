# 运行时正确性与性能验证

本目录验证步骤 4 生成的基线和预取 kernel。迁移到 AArch64 Linux 后，
应先完成正确性测试，再进行性能调优；历史机器的日志和结论不作为新服务器
的决策依据。

服务器私有的 `stencil_all_sme.cpp` 已包含计算函数、test 和 `main` 时，使用
`run_server_module.sh`。该脚本处理步骤 1 生成的完整 IR，baseline 和 prefetch
版本都会保留原始 test、`main` 及辅助函数，唯一差异是是否运行预取 Pass。

步骤 1/2 可以处理 1D3P、2D5P/9P、3D7P/13P/25P/27P。运行时验证不再维护
另一套固定 C ABI 驱动，而是直接复用服务器原程序的 test 和命令行入口，避免
测试规模、初始化方式或正确性判据与真实程序不一致。

## 文件说明

| 文件 | 作用 |
|---|---|
| `run_server_module.sh` | 用完整服务器 IR 中原有的 test/main 验证正确性和程序报告的 kernel 时间 |
| `server_results.csv`（本地忽略） | 汇总服务器各参数的 baseline/prefetch 中位时间和加速比 |
| `README.md` | 说明当前验证入口、运行模式、输出及调优方法 |

`build/` 和 `output/` 都是运行时生成目录，不提交到仓库。

## 推荐顺序

服务器多算子 C++ 输入优先运行：

```bash
BISHENG_CXX=/path/to/bisheng/bin/clang++ \
STENCIL_CPU=0 \
./scripts/03_validate_server_runtime.sh
```

`BISHENG_CXX` 或 `BISHENG_HOME` 必须显式指定；脚本不会从 `PATH` 回退到独立
LLVM 的 `clang++`，并会检查版本首行包含 BiSheng。最终链接计划保存在
`output/server-module/baseline_link_plan.log`。

脚本默认检查预取版本包含 29 个 intrinsic，随后分别向原始 `main` 传入
`--1d3p-s1`、`--1d3p-s2`、`--2d5p-s1`、`--2d5p-s2`，以及 2D9P、
3D13P、3D25P、3D27P 对应的 `s1/s2` 参数。默认使用单次复用模式：每个 test 的
baseline 和 prefetch 各执行一次，同一次执行既用于检查正确性，也记录性能时间，
因此 12 个用例总共执行 24 次。可用 `STENCIL_CASES` 覆盖参数列表，
`STENCIL_LINK_FLAGS` 可增加链接参数。脚本默认使用
`--rtlib=compiler-rt -lgcc_s`，由毕昇 compiler-rt 提供 SME ABI 所需的
`__arm_tpidr2_save` 等例程。如果原程序输出不含计时等非确定字段，可设置
`STENCIL_REQUIRE_IDENTICAL_OUTPUT=1`，要求 baseline 与 prefetch 的标准输出
和标准错误完全一致。

性能报告从每次原程序标准输出的 `Total Time: <seconds> s` 行提取时间，因此
比较的是原 test 定义的计时区间。脚本同时读取 Linux `/proc/uptime`，单独保存
整个进程的墙钟时间用于交叉检查，不依赖 GNU `/usr/bin/time`。冒号可以是 ASCII
或全角形式。

脚本默认在标准错误中打印当前正确性用例和性能样本进度。设置
`STENCIL_PROGRESS=0` 可关闭。只需确认完整链路能够运行时，使用：

```bash
STENCIL_SMOKE=1 ./scripts/03_validate_server_runtime.sh
```

smoke 模式只选择六类算子的 `s1`，每个版本执行 1 次，共运行 12 次；该结果只用于
检查流程，不用于判断稳定性能。

## 控制运行时间

默认单次复用模式会执行：

```text
12 个用例
* baseline/prefetch 各 1 次
= 24 次完整程序执行
```

每次执行同时承担正确性与性能验证，不再为了计时重复运行已经执行过的原始 test。
直接运行即可覆盖全部用例：

```bash
BISHENG_CXX=/path/to/bisheng/bin/clang++ \
STENCIL_CPU=0 \
STENCIL_TIMEOUT_SECONDS=1800 \
./scripts/03_validate_server_runtime.sh
```

得到的每个版本只有一个性能样本，可用于发现明显退化，但不能估计运行波动。需要
稳定性能数据时，显式关闭单次复用模式，再设置预热和样本数：

```bash
STENCIL_SINGLE_RUN=0 \
STENCIL_WARMUPS=2 \
STENCIL_SAMPLES=7 \
./scripts/03_validate_server_runtime.sh
```

原始 `test` 如果内部还包含大网格或多次迭代，即使 24 次也可能较慢。以下选项用于
诊断或中断异常用例，不是默认验证方式。

第一阶段只构建两个版本，不执行测试：

```bash
STENCIL_BUILD_ONLY=1 \
./scripts/03_validate_server_runtime.sh
```

选择一个用例，只执行预取版本的原始正确性测试，并限制单次最多 10 分钟：

```bash
STENCIL_CASES='--2d5p-s1' \
STENCIL_CORRECTNESS_VARIANTS=prefetch \
STENCIL_SKIP_PERFORMANCE=1 \
STENCIL_TIMEOUT_SECONDS=600 \
./scripts/03_validate_server_runtime.sh
```

也可以只运行某个算子的 baseline/prefetch：

```bash
STENCIL_CASES='--3d13p-s1' \
STENCIL_SKIP_PERFORMANCE=1 \
STENCIL_TIMEOUT_SECONDS=1800 \
./scripts/03_validate_server_runtime.sh
```

若要跳过正确性并单独重复测量某个用例，脚本会自动关闭单次复用模式：

```bash
STENCIL_CASES='--3d13p-s1' \
STENCIL_SKIP_CORRECTNESS=1 \
STENCIL_WARMUPS=0 \
STENCIL_SAMPLES=3 \
STENCIL_TIMEOUT_SECONDS=1800 \
./scripts/03_validate_server_runtime.sh
```

最后只对确认有希望的策略执行 2 次预热和 7 次正式测量。`STENCIL_TIMEOUT_SECONDS`
依赖 Linux coreutils 的 `timeout` 命令；超时时返回状态 124。正确性阶段会保留对应
`.out/.err` 文件，用于判断是正常慢还是程序卡住。

如果单个原始 test 本身就需要几十分钟，外层脚本无法在保持同一 test 语义的同时
缩短它。此时应让服务器私有 C++ 的 test 接受网格尺寸和内部重复次数参数，或者将
原始 test 只用于一次正确性验证，另写可调规模 benchmark driver 做性能测试。

主要输出位于 `output/server-module/`：

| 输出 | 内容 |
|---|---|
| `runtime_validation_report.md` | 本次构建、正确性和性能结果总览 |
| `correctness_summary.tsv` | 每个命令行用例和版本的退出状态及输出比较结果 |
| `program_time_seconds.tsv` | 从每次 `Total Time` 提取的逐样本时间，也是报告和加速比的数据源 |
| `wall_time_seconds.tsv` | 同一次运行的完整进程墙钟时间，仅用于交叉检查 |
| `performance_*_sample_*.out/.err` | 每次性能样本的原始输出，用于核对内部与外层时间 |
| `pass_run.log` | Pass 的识别、决策、跳过原因和插入日志 |
| `baseline_link_plan.log` | BiSheng 实际链接计划，用于排查 SME ABI 运行时问题 |

正确性覆盖范围由服务器私有 C++ 中原有的 test 决定。性能模式支持通过
`STENCIL_*` 环境变量覆盖用例、预热、样本数、CPU 绑定和超时。

## 自动回写 Profile

完成步骤 2 插件重建后运行：

```bash
BISHENG_CXX=/path/to/bisheng/bin/clang++ \
STENCIL_CPU=0 \
./scripts/04_tune_server_profile.sh
```

脚本只运行与候选类别相关的用例，读取 `program_time_seconds.tsv`，按每个算子的
`s1/s2` 最差加速比和几何平均选择类别，并生成 `profiles/server-sme.env`。该文件
为服务器本地结果，不提交到仓库。选择完成后执行：

```bash
./scripts/05_validate_tuned_profile.sh
```

最终验收重新覆盖全部用例的正确性和稳定性能。若调优结果关闭了全部软件预取，
最终脚本允许预取数为 0，并将其视为“该服务器不采用软件预取”，而不是插入失败。

迁移时必须先适配脚本中的编译器路径、插件扩展名、链接参数和目标特性。
服务器 Profile 应在固定 CPU 亲和性、频率策略、streaming VL 和问题规模下，
通过环境变量逐组覆盖距离、类别开关和预算后重新建立。Linux PMU 归因建议使用
`perf` 或服务器厂商工具；本目录不再保留与当前完整模块入口脱节的旧扫描、消融、
多线程脚本和固定 C ABI 驱动。
