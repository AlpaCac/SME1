# 04 Vector ArmSME LLVM

这个目录现在服务于同一条统一主线：从第三步已经带有预取语义的高层 MLIR 出发，继续向 `vector / arm_sme / llvm` 方向降级。

## 第四步的统一定义

第四步的研究目标不是长期保留“两条路线”，而是把下面这条主线尽量走通：

```text
高层 MLIR + 预取语义
-> vector
-> arm_sme
-> llvm
```

对应起点是第三步产物：

- [gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)

当前实现之所以还保留少量“证据型输出”，是因为 MLIR 官方 lowering 更擅长分别处理：

- `affine.prefetch -> memref.prefetch -> llvm.intr.prefetch`
- `linalg.matmul -> vector -> arm_sme -> llvm`

所以这里的做法不是把研究方案拆成两条平行路线，而是借助这些已有 lowering 片段，把统一主线逐步压实。当前仓库只保留总体方案真正需要的关键产物，不再保存所有过渡中间件。

## 目录结构

- [build_lowering_pipeline.py](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/build_lowering_pipeline.py)：第四步重构脚本

输出文件：

- [01_affine_prefetch_std.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_affine_prefetch_std.mlir)：把 `research.prefetch` 桥接为标准 `affine.prefetch`
- [03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)：预取语义继续降到 `llvm.intr.prefetch`
- [07_unified_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir)：把第三步预取决策注入 `vector` 计算主线后的统一中间结果
- [08_unified_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/08_unified_arm_sme_prefetch.mlir)：继续降到 `arm_sme` 后的统一中间结果
- [09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir)：去掉末端桥接残留后，可直接翻译为 LLVM IR 的统一主线结果

## 当前方法

当前脚本分三段推进，但对仓库只落必要结果：

1. 先把第三步中的研究版 `research.prefetch` 桥接成标准 `affine.prefetch`，证明预取语义能够继续稳定下沉。
2. 再利用官方 `linalg -> vector -> arm_sme -> llvm` lowering，在脚本内部生成临时计算中间件。
3. 最后把第三步的预取决策重新注入到 `vector` 计算主线中，得到 `07 -> 08 -> 09` 这组统一产物。
4. 对 `09` 的直接 lowering 结果补一轮 `convert-vector-to-llvm=enable-arm-sve`，让 `arm_sve.psel` 进一步落到可导出形态。
5. 对末端残留的 `i64 -> index -> i32` 桥接做一个很小的清理，把它规整成等价的 `llvm.trunc i64 -> i32`。

## 当前阶段结论

现在第四步已经具备了统一主线的骨架：

- 高层预取语义已经能落到 `llvm.intr.prefetch`
- 计算主线已经能落到 `arm_sme`
- 统一后的 `07 -> 08 -> 09` 产物已经形成

现在统一主线的 LLVM 侧已经收口到可导出状态：`09_unified_llvm_prefetch.mlir` 可以直接被 `mlir-translate` 转成 LLVM IR。

需要注意的是，末端仍然包含一个研究型的小后处理：它不是在改算法语义，而是在把官方 lowering 末端留下的少量桥接残留，规整成 LLVM 后端能直接接受的等价形式。

## 如何运行

在仓库根目录执行：

```bash
python3 04_vector_arm_sme_llvm/build_lowering_pipeline.py
```

## 你现在应该重点看什么

如果你要证明“第四步已经转入统一主线”，建议重点看五份文件：

1. [01_affine_prefetch_std.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_affine_prefetch_std.mlir)  
   说明预取语义已经进入标准高层 op

2. [03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)  
   说明预取语义已经能落到 LLVM 侧

3. [07_unified_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir)  
   说明预取决策已经重新进入统一计算主线

4. [08_unified_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/08_unified_arm_sme_prefetch.mlir)  
   说明统一后的计算与预取信息已经共同进入 `arm_sme` 阶段

5. [09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir)  
   说明统一主线已经可以被导出为 LLVM IR

## 下一步建议

完成这一阶段后，最关键的下一步是：

1. 把当前脚本式末端清理逐步替换成正式 pass。
2. 为统一主线补一个更直接的运行 harness，继续往可执行程序推进。
3. 让同一份带预取语义的高层 MLIR 真正稳定地一路走到 `vector / arm_sme / llvm` 而不丢失预取信息。
