# 步骤 2 LLVM pass 插件测试报告

- 总体结果：**PASS**
- LLVM：`18.0.0git`
- Clang：`clang version 18.0.0 (git@github.com:AlpaCac/SME.git bb841d9cd7ece40037671bcc74ce31323ce39e27)`
- 插件：`build/StencilPrefetchPass.dylib`
- 输入：`../01_llvm_ir_analysis/output/stencil_sme_kernels.ll`
- 输出：`output/stencil_sme_kernels.after.ll`

## 验证内容

1. CMake 成功发现 LLVM 开发包并构建动态插件。
2. Clang 通过 `-fpass-plugin` 成功加载插件。
3. optimizer-early callback 对两个 stencil 函数运行。
4. pass 成功获取五项方案要求的 LLVM analysis。
5. pass 返回 `PreservedAnalyses::all()`，本步骤不修改 IR。

## Pass 输出

```text
StencilPrefetchPass: function=stencil_2d5p_sme_f32 loops=2 innermost-loops=1 computable-trip-counts=1 dom-tree-root=yes analyses=LoopInfo,ScalarEvolution,DominatorTree,TargetIR,AssumptionCache
StencilPrefetchPass: function=stencil_3d7p_sme_f32 loops=3 innermost-loops=1 computable-trip-counts=2 dom-tree-root=yes analyses=LoopInfo,ScalarEvolution,DominatorTree,TargetIR,AssumptionCache
```

步骤 3 的 stencil 识别由同一个 function pass 实现。
