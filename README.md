# SME Stencil 软件预取迁移

本分支用于把 SME stencil 软件预取方案迁移到断网 AArch64 Linux
服务器。仓库只保留可重新构建或验证方案所需的源码、脚本、测试输入和
维护文档，不提交本机生成的 LLVM IR、汇编、日志及性能报告。

当前支持两个单时间步、常系数算子：

1. 2D 5-point stencil（2D5P）
2. 3D 7-point stencil（3D7P）

## 保留内容

| 路径 | 作用 |
|---|---|
| `stencil_sme_kernels.c` | 使用 SME/SVE ACLE 实现的 2D5P、3D7P kernel |
| `01_llvm_ir_analysis/` | 从 C 生成 LLVM IR，并检查循环、地址和向量访存结构 |
| `02_llvm_pass_plugin/` | LLVM pass 源码、决策模型、测试输入和构建脚本 |
| `05_runtime_validation/` | 正确性、配对性能、距离扫描、消融和多线程测试 |
| `stencil预取优化实施方案.md` | 预取模型、决策算法和 LLVM 实施步骤 |
| `断网AArch64服务器迁移指南.md` | 离线工具链准备、服务器适配与验收方法 |

`01_llvm_ir_analysis/output/`、`02_llvm_pass_plugin/output/`、
`05_runtime_validation/output/` 和各级 `build/` 均由脚本创建，并已加入
`.gitignore`。

## 编译链路

```text
stencil_sme_kernels.c
-> Clang 生成 LLVM IR
-> StencilPrefetchPass 分析循环并作出预取决策
-> 插入 llvm.aarch64.prefetch
-> AArch64 后端生成 SME/SVE 计算指令和 PRFM
-> 正确性与性能驱动验证
```

分析与插入在同一个 LLVM pass 中完成，不使用 JSON，不依赖 MLIR，也不
改写原始 C kernel。

## 迁移顺序

1. 按 `断网AArch64服务器迁移指南.md` 准备可离线安装的 Clang/LLVM、
   CMake、Ninja 和系统依赖。
2. 将步骤 1、2、5 的目标三元组、工具路径、动态库后缀和 CPU Profile
   适配到服务器。
3. 运行 `./01_llvm_ir_analysis/generate_and_check.sh` 验证 C 到 IR。
4. 运行 `./02_llvm_pass_plugin/build_and_test.sh` 构建 pass，并检查 IR
   中的预取 intrinsic 和汇编中的 `prfm`。
5. 运行 `./05_runtime_validation/build_and_run.sh` 验证数值正确性。
6. 依次运行配对基准、距离扫描、类别消融和多线程测试，建立服务器专用
   Profile。

迁移前不要直接沿用 `apple-m5` Profile；预取距离、cache 层级和
KEEP/STRM 策略必须依据服务器的 cache、SME streaming VL、内存带宽和
实测结果重新选择。
