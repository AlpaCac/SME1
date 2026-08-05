# SME Stencil 软件预取迁移

本分支用于把 SME stencil 软件预取方案迁移到断网 AArch64 Linux
服务器。仓库只保留可重新构建或验证方案所需的源码、脚本、测试输入和
维护文档，不提交本机生成的 LLVM IR、汇编、日志及性能报告。

仓库提供可复现的 `stencil_all_sme_fixture.cpp`，包含与服务器同名、同参数数量
的六个双精度 SME/SVE 算子以及 test、`main`。服务器私有输入仍使用
`stencil_all_sme.cpp`，并由 `.gitignore` 排除。步骤 1 会生成完整 IR 后提取
计算函数，后续步骤不链接或分析 `main`/test。当前 pass 支持：

1. 1D 3-point（1D3P）
2. 2D 5-point、9-point（2D5P、2D9P）
3. 3D 7-point、13-point、25-point、27-point（3D7P、3D13P、3D25P、3D27P）

## 保留内容

| 路径 | 作用 |
|---|---|
| `stencil_all_sme_fixture.cpp` | 本地多算子回归 fixture；函数名和参数数量对应服务器输入 |
| `stencil_sme_kernels.c` | 本地 2D5P、3D7P 回归 fixture |
| `01_llvm_ir_analysis/` | 从 C++ 生成完整 IR，提取 kernel-only IR 并检查向量访存结构 |
| `02_llvm_pass_plugin/` | LLVM pass 源码、决策模型、测试输入和构建脚本 |
| `05_runtime_validation/` | 复用服务器原始 test/main 的全模块正确性与性能验证 |
| `scripts/` | 服务器上依次执行的独立 LLVM IR 检查与 pass 构建脚本 |
| `stencil预取优化实施方案.md` | 预取模型、决策算法和 LLVM 实施步骤 |
| `断网AArch64服务器迁移指南.md` | 离线工具链准备、服务器适配与验收方法 |
| `独立LLVM预取Pass部署教程.md` | 用独立 LLVM `opt` 改写 IR、再交回 BiSheng 编译的服务器流程 |

`01_llvm_ir_analysis/output/`、`02_llvm_pass_plugin/output/`、
`05_runtime_validation/output/` 和各级 `build/` 均由脚本创建，并已加入
`.gitignore`。

## 编译链路

```text
stencil_all_sme.cpp
-> Clang 生成完整 LLVM IR（含 test/main）
-> llvm-extract 提取 kernel-only LLVM IR
-> StencilPrefetchPass 分析循环并作出预取决策
-> 插入 llvm.aarch64.prefetch
-> AArch64 后端生成 SME/SVE 计算指令和 PRFM
-> 正确性与性能驱动验证
```

分析与插入在同一个 LLVM pass 中完成，不使用 JSON，不依赖 MLIR，也不
改写原始 C kernel。

## 迁移顺序

1. 按 `独立LLVM预取Pass部署教程.md` 准备 upstream LLVM 19.1.7 开发工具链、
   CMake、make 和系统依赖；BiSheng 发布包不承担 pass 开发环境角色。
2. 将步骤 1、2、5 的目标三元组、工具路径、动态库后缀和 CPU Profile
   适配到服务器。
3. 将服务器私有的 `stencil_all_sme.cpp` 放在仓库根目录或设置
   `STENCIL_SOURCE`，运行 `./01_llvm_ir_analysis/generate_and_check.sh`。
4. 用独立 LLVM 构建 pass 并通过 `opt` 改写完整 IR，再由 BiSheng 生成汇编；
   检查 IR 中的预取 intrinsic 和汇编中的 `prfm`。
5. 运行 `./scripts/03_validate_server_runtime.sh`，使用服务器原始 C++ 完整
   模块中的 test 和 `main` 验证数值正确性，并记录 baseline/prefetch 输出的
   `Total Time`。
6. 在清单中填写真实 row/plane 字节数后运行
   `./scripts/calibrate_server_model.sh`，自动探测 Cache/VL、使用 PMU 微基准校准
   latency/useful cycles，并生成本地 `profiles/server-model.env`。
7. 正确性通过后，运行 `./scripts/04_tune_server_profile.sh` 自动执行类别消融，
   使用全部已知工作负载选择需要启用的预取类别并生成本地
   `profiles/server-sme.env`；距离和 KEEP/STRM 仍由分析模型逐函数计算。
8. 运行 `./scripts/05_validate_tuned_profile.sh` 加载 Profile，重新执行全部正确性
   和稳定性能复测；需要 PMU 或多线程实验时再补充工具。

当前默认将 `s1/s2` 联合用于稳健调优，要求同一候选在两个已知规模上都不退化。
这会生成覆盖已知工作负载的静态 Profile，但不代表对未知规模具有泛化能力。若
服务器不同尺寸需要不同方案，下一阶段应增加 LLVM loop versioning 和基于实际
维度的运行时分派。

迁移前不要直接沿用 `apple-m5` Profile；必须把服务器的 cache、SME streaming
VL 等输入提供给分析模型，并用服务器实测确认模型选择的预取类别确实有效。
