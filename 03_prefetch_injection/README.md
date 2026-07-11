# 03 Prefetch Injection

这个目录对应方案的第三步：根据第二步得到的分析结果和 `cost module` 决策，在 `affine` 层显式注入预取语义。

## 目标

这一阶段的重点不是立刻生成目标机器的真实预取指令，而是先把“高层预取决策”落到 `MLIR` 里，形成一个后续可被自定义 pass 继续处理的中间版本。

当前实现采用研究版 `research.prefetch` generic op，原因是：

- 现在仍处于研究阶段
- 预取策略还在演化
- 需要先表达“在哪里预取、对谁预取、预取属性是什么”
- 暂时不强绑定到 LLVM 官方方言或某个最终后端表示

## 目录结构

- [inject_prefetch.py](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/inject_prefetch.py)：预取注入脚本
- [output/gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)：带研究版预取语义的 `affine` MLIR

## 当前注入策略

脚本会读取：

- [gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)
- [prefetch_analysis.json](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.json)

然后按第二步的决策执行：

- 对 `B` 注入高优先级 `read` 预取
- 对 `A` 注入中优先级 `read` 预取
- 对 `C` 不注入预取

## 注入位置

当前把注入点放在：

- `affine.for %kk = 0 to 128`
- `scf.if %in_k_bound`

之后、真实 `affine.load` 之前。

这样做的原因是：

- 这里最接近实际的归约推进节奏
- 能直接对应第二步里关于 `A/B` 读流的判断
- 后续如果要做 lowering，更容易把它们重写成目标相关预取形式

## 预取语义形式

当前采用 generic op：

```mlir
"research.prefetch"(...) <{...}> : (...) -> ()
```

属性里会保留：

- `target`
- `kind`
- `priority`
- `cache`
- `locality`
- `distance`

这正好对应第二步 `cost module` 给出的决策字段。

## 如何运行

在仓库根目录执行：

```bash
python3 03_prefetch_injection/inject_prefetch.py
```

## 如何验证

因为当前使用的是研究版未注册方言 op，验证时需要允许未注册 dialect：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --allow-unregistered-dialect \
  03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir
```

## 下一步建议

完成这一阶段后，可以继续做三件事：

1. 把 `research.prefetch` 改成正式的自定义 MLIR dialect op。
2. 编写 pass，把 `research.prefetch` 从 `affine` 层继续传递到后续 lowering 链路。
3. 研究它如何映射到 `vector / arm_sme / llvm` 层的目标相关预取形式。
