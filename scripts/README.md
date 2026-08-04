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

步骤 4 从 `profiles/tuning_cases.csv` 读取用例，自动运行类别消融。只有 `train`
场景参与 current-L1、row-L1、plane-L1、plane-L2 组合选择；`validate` 场景留给
步骤 5。默认要求每个训练场景不退化、加权几何平均至少 1.03，任一版本的相对
MAD 不超过 0.03。可用 `STENCIL_TUNE_MIN_CASE_SPEEDUP`、
`STENCIL_TUNE_MIN_GEOMEAN` 和 `STENCIL_TUNE_MAX_RELATIVE_MAD` 覆盖。原始数据保存在：

```text
05_runtime_validation/output/server-profile-tuning/candidate_results.csv
05_runtime_validation/output/server-profile-tuning/profile_selection.csv
```

被选参数写入本地忽略文件 `profiles/server-sme.env`。当前自动选择负责按算子回写
预取类别；距离和 KEEP/STRM 默认保持分析模型的 `0/AUTO`，接口已经开放，可在该
Profile 中覆盖。步骤 5 加载 Profile 后重新执行全部正确性测试和性能采样，并以
清单中的 `validate` 场景作为独立验收门槛。步骤 4 默认复用清单、参数和样本数
完全一致的已完成候选，中断后可直接重跑；设置 `STENCIL_TUNE_RESUME=0` 强制重测。

步骤 4 会自动探测 Linux sysfs 中的 L1/L2 容量和 cache line，并把所有实际采用的
硬件与模型参数纳入候选缓存签名，避免修改参数后错误复用旧数据。无法自动探测的
streaming VL 和延迟参数可在运行脚本前通过 `SME_PREFETCH_*` 显式设置。

默认清单将 `s1` 用于训练、`s2` 用于留出验证。步骤 4 默认 2 次预热、7 次样本，
共执行 324 次训练用例。先检查自动化链路时可用：

```bash
STENCIL_TUNE_WARMUPS=0 STENCIL_TUNE_SAMPLES=1 \
  ./scripts/04_tune_server_profile.sh
```

快速模式执行 36 次，只用于确认脚本和候选选择能够完成，不能直接作为最终 Profile。
