# 服务器临时执行脚本

这些脚本用于独立 LLVM 部署流程，均假定独立 LLVM 已由
`tools/install_standalone_llvm.sh` 安装到仓库的 `tools/llvm-19.1.7`。

在仓库根目录按以下顺序执行：

```bash
./scripts/01_check_standalone_llvm_ir.sh
./scripts/02_build_and_test_pass.sh
./scripts/03_validate_server_runtime.sh
```

第一个脚本只验证独立 LLVM `opt` 能读取 BiSheng 在步骤 1 生成的完整 IR；它不改写
IR。第二个脚本用独立 LLVM 构建并回归测试预取 pass，默认使用步骤 1 生成的
kernel-only IR。

第三个脚本使用步骤 1 的完整 IR，保留服务器原始 `stencil_all_sme.cpp` 中的
test 和 `main`，分别构建无预取 baseline 与带预取版本，先运行正确性测试，
默认逐一向 `main` 传入六类算子的 `s1/s2` 参数，再进行逐用例预热和多轮墙钟
测量。执行前用 `BISHENG_CXX` 指向毕昇 `clang++`；建议用 `STENCIL_CPU`
绑定固定 CPU。

如需调整独立 LLVM 安装位置，可在执行前设置：

```bash
export STANDALONE_LLVM=/path/to/llvm-19.1.7
```
