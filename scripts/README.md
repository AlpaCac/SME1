# 服务器临时执行脚本

这些脚本用于独立 LLVM 部署流程，均假定独立 LLVM 已由
`tools/install_standalone_llvm.sh` 安装到仓库的 `tools/llvm-19.1.7`。

在仓库根目录按以下顺序执行：

```bash
./scripts/01_check_standalone_llvm_ir.sh
./scripts/02_build_and_test_pass.sh
./scripts/03_validate_server_runtime.sh
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

步骤 4 自动运行类别消融，并按每个算子的 `s1/s2` 共同表现选择 current-L1、
row-L1、plane-L1、plane-L2 组合。默认要求每个场景加速比不低于 0.98，两个场景
几何平均不低于 1.01；可用 `STENCIL_TUNE_MIN_CASE_SPEEDUP` 和
`STENCIL_TUNE_MIN_GEOMEAN` 覆盖。原始候选数据保存在：

```text
05_runtime_validation/output/server-profile-tuning/candidate_results.csv
05_runtime_validation/output/server-profile-tuning/profile_selection.csv
```

被选参数写入本地忽略文件 `profiles/server-sme.env`。当前自动选择负责按算子回写
预取类别；距离和 KEEP/STRM 默认保持分析模型的 `0/AUTO`，接口已经开放，可在该
Profile 中覆盖。步骤 5 加载 Profile 后重新执行全部正确性测试，并默认进行 2 次
预热和 7 次稳定性能采样。步骤 4 默认复用参数和样本数完全一致的已完成候选，
中断后可直接重跑；设置 `STENCIL_TUNE_RESUME=0` 可强制清除复用判定并重新测量。

步骤 4 默认 1 次预热、3 次样本，共执行 288 次相关用例。先检查自动化链路时可用：

```bash
STENCIL_TUNE_WARMUPS=0 STENCIL_TUNE_SAMPLES=1 \
  ./scripts/04_tune_server_profile.sh
```

快速模式执行 72 次，只用于确认脚本和候选选择能够完成，不能直接作为最终 Profile。
