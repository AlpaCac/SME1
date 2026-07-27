# 步骤 4 预取决策与安全地址测试报告

- 总体结果：**PASS**
- Profile：`generic-sme`
- 修改后 IR：`output/stencil_sme_kernels.after.ll`
- 正例决策数：8
- 非 stencil 负例决策数：0
- 结构负例决策数：6，仅保留 3D7P

## 默认决策

| 算子 | 物理流 | 距离 | 层级 | 策略 | 数量 |
|---|---|---:|---|---|---:|
| 2D5P | north/south row | 4 | L1 | KEEP | 2 |
| 3D7P | north/south row | 4 | L1 | KEEP | 2 |
| 3D7P | front/back plane near | 4 | L1 | STRM | 2 |
| 3D7P | front/back plane far | 10 | L2 | KEEP | 2 |

连续 current-row 默认关闭，避免与硬件连续流预取重复。

## 安全性与预算

1. 每个候选经过 cache 容量、独立流、指令数和字节预算检查。
2. 未来位置使用 `x + distance * cntsw()` 构造。
3. 按距离合并 guard，仅在 `future_x < interior_end` 时执行预取。
4. 未来地址使用非 `inbounds` GEP。
5. left/center/right 已合并，不生成重复 current-row 预取。

6. `SME_PREFETCH_MAX_STREAMS=0` 时 8 个候选均以 `StreamBudgetReject` 拒绝，且不插入 intrinsic。

7. `apple-m5` Profile 只保留 2 条 3D plane-L1 STRM，距离为 1；2D、row 和 plane-L2 均关闭。

8. 零容量、零指令预算和零字节预算分别覆盖 `CapacityReject`、`InstructionBudgetReject` 和 `BandwidthReject`，均不插入 intrinsic。

9. 固定短 width 的真实 2D stencil 以 assumed VL 估算为 2 次向量迭代，两条候选均以 `ShortTripCount` 拒绝。

## 端到端编译

1. 修改后 IR 成功降为 8 条 `PRFM/PRFUM`：4 条 L1 KEEP、2 条 L1 STRM、2 条 L2 KEEP。
2. 原始 C 通过 `-fpass-plugin` 直接生成带预取汇编。
3. 不加载插件的基线汇编不含软件预取。
4. 对已插入 IR 再次运行插件仍为 8 条，两个函数报告 `AlreadyPrefetched`。

## 决策诊断

```text
StencilDecision: function=stencil_2d5p_sme_f32 kind=2D5P stream=north-row enable=yes distance=4 level=L1 policy=KEEP live-bytes=256 reuse-count=3 reuse-distance=12288 reason=Admitted
StencilDecision: function=stencil_2d5p_sme_f32 kind=2D5P stream=south-row enable=yes distance=4 level=L1 policy=KEEP live-bytes=256 reuse-count=3 reuse-distance=12288 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=front-plane enable=yes distance=4 level=L1 policy=STRM live-bytes=256 reuse-count=3 reuse-distance=131072 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=back-plane enable=yes distance=4 level=L1 policy=STRM live-bytes=256 reuse-count=3 reuse-distance=131072 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=north-row enable=yes distance=4 level=L1 policy=KEEP live-bytes=256 reuse-count=3 reuse-distance=20480 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=south-row enable=yes distance=4 level=L1 policy=KEEP live-bytes=256 reuse-count=3 reuse-distance=20480 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=front-plane enable=yes distance=10 level=L2 policy=KEEP live-bytes=640 reuse-count=3 reuse-distance=131072 reason=Admitted
StencilDecision: function=stencil_3d7p_sme_f32 kind=3D7P stream=back-plane enable=yes distance=10 level=L2 policy=KEEP live-bytes=640 reuse-count=3 reuse-distance=131072 reason=Admitted
```
