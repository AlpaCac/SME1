# 服务器预取 Profile

`server-sme.env` 由 `scripts/04_tune_server_profile.sh` 在目标服务器生成，包含
按 stencil 算子选择的预取类别掩码、距离、策略和预算。该文件依赖具体服务器，
已加入 `.gitignore`，不会覆盖其他机器的结果。

生成后使用：

```bash
./scripts/05_validate_tuned_profile.sh
```

`server-sme.env.example` 仅说明文件格式，不代表推荐参数。

`tuning_cases.csv` 是可扩展用例清单：

| 列 | 含义 |
|---|---|
| `argument` | 传给服务器原始 `main` 的单个参数 |
| `kind` | stencil 类型 |
| `size_class` | 人工定义的规模类别，如 L1、L2、DRAM |
| `role` | `train` 参与联合选择；未来新增的 `validate` 可做独立留出验收 |
| `weight` | 训练集加权几何平均的权重 |

默认清单将 `s1/s2` 都标记为 `train`，共同选择一个已知工作负载 Profile。每个
候选必须在两个规模上都不退化，避免只针对其中一个规模。当前结果属于部署调优，
不构成未知规模的泛化验证。服务器 `main` 增加更多尺寸参数后，只需追加清单行；
拥有足够的 L1、L2、DRAM 场景后，再保留独立的 `validate` 行做真正的留出验收。
`profile_selection.csv` 的 `outcome` 会区分正常选中和没有合格全局阈值；清单没有
训练数据时脚本会在运行候选前直接停止。

调优脚本在 Linux 上从 `/sys/devices/system/cpu/cpu0/cache/` 自动读取 L1/L2
容量和 cache line 大小，并从 `/proc/sys/abi/sme_default_vector_length` 读取
streaming VL；读取失败时必须显式提供实测值。距离和 KEEP/STRM 在 Profile 中保持
`0/AUTO`，表示由 Pass 根据每个函数的分析结果计算。实测从 Pass 输出的 score 自动
构造全局阈值边界，并只选择一个适用于全部 stencil 的最低收益阈值，不生成算子
mask。所有有效硬件输入会写入 `hardware_metadata.txt`。用例清单不再保存
row/plane/working-set 字节数，Pass 决策不依赖具体矩阵大小。

搜索过程先使用 `server-sme.env.tuning`，全局阈值选择成功后才原子替换
`server-sme.env`，中断不会破坏已有 Profile。

`server-model.env` 是服务器本地模型输入，格式见 `server-model.env.example`。脚本
不再为 latency、useful cycles、容量比例或资源预算提供 generic 回退值。缺失项会在
调优开始前一次性报告。
推荐使用 `scripts/calibrate_server_model.sh` 生成：硬件周期来自 PMU 微基准，容量
比例由 cache 相联度推导，最大流数来自 1 至 17 条独立随机流的 PMU 吞吐扫描，
指令和字节预算再由实测流数、cache line 和 VL 推导。
原始测量保存在 `05_runtime_validation/output/server-model-calibration/`。

当前 Profile 只保存硬件模型输入和一个全局收益阈值。分析模型使用流类型、复用
证据、延迟距离和资源预算逐候选决策，不会按算子名称或矩阵尺寸切换版本。
