# 步骤 3 Stencil 识别测试报告

- 总体结果：**PASS**
- 正例输入：`../01_llvm_ir_analysis/output/stencil_sme_kernels.ll`
- 负例输入：`tests/non_stencil.ll`
- 结构负例：保留 5 个 load，但破坏 2D 的 `±row` stride 配对
- IR 修改：无

## 识别条件

1. 最内层循环包含共同谓词的 5 或 7 个 masked load。
2. 循环包含一个使用同一谓词的 masked store。
3. 谓词由 `llvm.aarch64.sve.whilelo` 生成。
4. `x` PHI 的 SCEV step 来自 `llvm.aarch64.sme.cntsw`。
5. left/center/right 通过 `0/±sizeof(float)` 合并为 current-row。
6. 其余 GEP stride 通过 SCEV 相反数配对为 row/plane 流。
7. 包含外部调用或普通 store 的候选循环被拒绝。

## 正例结果

```text
StencilAnalysis: function=stencil_2d5p_sme_f32 kind=2D5P logical-loads=5 physical-streams=3 vector-step=cntsw streams=current-row:3,north-row:1,south-row:1
StencilAnalysis: function=stencil_3d7p_sme_f32 kind=3D7P logical-loads=7 physical-streams=5 vector-step=cntsw streams=current-row:3,north-row:1,south-row:1,front-plane:1,back-plane:1
```

## 负例结果

`stencil_vector_copy` 进入 pass，但没有产生 `StencilAnalysis` 结果，证明识别不只依赖函数名前缀。

结构负例中的 2D 函数仍有原始 load 框架，但 south 与 north 使用同一基址，因此没有被识别；同模块的 3D7P 仍被正确识别。
