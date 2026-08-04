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
| `row_bytes` | 该场景实际 row 字节数，未知填 0 |
| `plane_bytes` | 该场景实际 plane 字节数，未知填 0 |
| `working_set_bytes` | 总工作集字节数，未知填 0 |

默认清单将 `s1/s2` 都标记为 `train`，共同选择一个已知工作负载 Profile。每个
候选必须在两个规模上都不退化，避免只针对其中一个规模。当前结果属于部署调优，
不构成未知规模的泛化验证。服务器 `main` 增加更多尺寸参数后，只需追加清单行；
拥有足够的 L1、L2、DRAM 场景后，再保留独立的 `validate` 行做真正的留出验收。
`profile_selection.csv` 的 `outcome` 会区分正常选中、候选均不合格和缺少训练数据。

调优脚本在 Linux 上从 `/sys/devices/system/cpu/cpu0/cache/` 自动读取 L1/L2
容量和 cache line 大小；读取失败时才使用保守默认值。SME streaming VL、预取
延迟等无法可靠自动推导的参数可用 `SME_PREFETCH_*` 环境变量覆盖，所有有效值会
写入 `hardware_metadata.txt` 和最终 Profile。清单中非零的 `row_bytes`、
`plane_bytes` 会按训练权重形成代表值；显式环境变量优先级更高。

当前 Profile 对同一种 stencil 仍生成一套静态决策。联合调优只保证已知 `s1/s2`
的共同表现，不会在程序运行时根据尺寸切换版本。若不同尺寸需要不同 cache 层级或
策略，后续应在 Pass 中恢复运行时行宽、平面大小和工作集范围，再通过 loop
versioning 生成带条件分派的多个版本。
