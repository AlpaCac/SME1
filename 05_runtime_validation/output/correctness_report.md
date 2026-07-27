# 步骤 5 数值正确性状态

- 状态：**PASS**
- 说明：baseline and prefetch binaries passed all 2D/3D cases
- 运行平台：`Darwin arm64`（Apple M5，SME/SME2）
- 运行编译器：`Apple clang version 21.0.0 (clang-2100.1.1.101)`
- 基线 kernel：步骤 4 同输入/同优化管线生成的无插件汇编
- 预取 kernel：步骤 4 生成的 `stencil_sme_kernels.s`
- 基线二进制：`../build/stencil_correctness.baseline`
- 预取二进制：`../build/stencil_correctness.prefetch`

测试覆盖 2D/3D 空内部区域、最小合法尺寸、非规则宽度和较大尾部 case。在 SME 机器上运行时，两个二进制都必须与标量参考逐元素一致。
