# 服务器临时执行脚本

这些脚本用于独立 LLVM 部署流程，均假定独立 LLVM 已由
`tools/install_standalone_llvm.sh` 安装到仓库的 `tools/llvm-19.1.7`。

在仓库根目录按以下顺序执行：

```bash
./scripts/01_check_standalone_llvm_ir.sh
./scripts/02_build_and_test_pass.sh
```

第一个脚本只验证独立 LLVM `opt` 能读取 BiSheng 在步骤 1 生成的完整 IR；它不改写
IR。第二个脚本用独立 LLVM 构建并回归测试预取 pass，默认使用步骤 1 生成的
kernel-only IR。

如需调整独立 LLVM 安装位置，可在执行前设置：

```bash
export STANDALONE_LLVM=/path/to/llvm-19.1.7
```
