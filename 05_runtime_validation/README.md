# 运行时正确性与性能验证

本目录验证步骤 4 生成的基线和预取 kernel。迁移到 AArch64 Linux 后，
应先完成正确性测试，再进行性能调优；历史机器的日志和结论不作为新服务器
的决策依据。

步骤 1/2 可以处理 1D3P、2D5P/9P、3D7P/13P/25P/27P 的 kernel-only IR。
本目录现有 C 驱动只定义了 `stencil_2d5p_sme_f32` 和
`stencil_3d7p_sme_f32` 的参考实现与函数原型，因此当前只能运行这两个算子
的正确性和性能测试。为其他服务器 kernel 建立性能数据前，需要按其 C ABI
签名新增对应的参考函数和 benchmark driver。

## 文件说明

| 文件 | 作用 |
|---|---|
| `build_and_run.sh` | 构建基线/预取版本，探测 SME 与 streaming VL，并运行正确性测试 |
| `run_benchmark.sh` | 分进程运行 2D5P、3D7P 墙钟基准 |
| `run_paired_benchmark.sh` | 同进程交替测量基线与预取版本，降低系统漂移 |
| `run_profile_sweep.sh` | 分别扫描 2D row-L1 和 3D plane-L1 预取距离 |
| `run_ablation.sh` | 关闭或单独保留 row、plane-L1、plane-L2，测量各类预取贡献 |
| `run_threaded_benchmark.sh` | 测试共享 cache 和内存带宽竞争下的多线程收益 |
| `stencil_correctness.c` | 标量参考与 guard-page 正确性驱动 |
| `stencil_benchmark.c` | 独立进程 2D5P/3D7P 基准驱动 |
| `stencil_paired_benchmark.c` | 单进程配对基准驱动 |
| `stencil_threaded_benchmark.c` | pthread 多线程 3D7P 配对驱动 |
| `sme_runtime_info.c` | 在 locally-streaming 函数中读取 streaming vector length |

`build/` 和 `output/` 都是运行时生成目录，不提交到仓库。

## 推荐顺序

```bash
./05_runtime_validation/build_and_run.sh
./05_runtime_validation/run_paired_benchmark.sh
./05_runtime_validation/run_profile_sweep.sh
./05_runtime_validation/run_ablation.sh
./05_runtime_validation/run_threaded_benchmark.sh
```

正确性测试覆盖空内部区域、最小尺寸、不规则宽度、谓词尾部和前后
guard page。性能测试支持通过 `STENCIL_*` 环境变量覆盖网格规模、重复
次数、样本数和轮数。

迁移时必须先适配脚本中的目标三元组、编译器路径、插件扩展名、链接参数和
SME feature 探测方式。服务器 Profile 应在固定 CPU 亲和性、频率策略、
streaming VL 和问题规模下通过距离扫描与类别消融重新建立。Linux PMU
归因建议在联网环境预先准备 `perf`，或使用服务器厂商提供的离线性能工具；
本仓库不保留 macOS `xctrace` 专用脚本。
