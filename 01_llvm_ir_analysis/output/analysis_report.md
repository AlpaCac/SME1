# 步骤 1 LLVM IR 分析报告

- 总体结果：**PASS**
- Clang：`Apple clang version 21.0.0 (clang-2100.1.1.101)`
- Target：`arm64-apple-macos15`
- Architecture：`armv9.2-a+sme+sve2`
- 输入：`stencil_sme_kernels.c`
- IR：`output/stencil_sme_kernels.ll`

## `stencil_2d5p_sme_f32`

| 检查项 | 期望 | 结果 |
|---|---:|---:|
| streaming-mode attribute | `aarch64_pstate_sm_body` | PASS |
| streaming vector length | `llvm.aarch64.sme.cntsw` | PASS |
| logical masked loads | 5 | PASS |
| masked store | 1 | PASS |
| loop induction PHIs | >= 3 | PASS |
| loop backedges | `!llvm.loop` present | PASS |
| tail predicate | `llvm.aarch64.sve.whilelo` | PASS |
| GEP address calculations | >= 8 | PASS |
| row-stride multiplication | `mul i64` present | PASS |
| SVE add chain | >= 3 | PASS |
| SVE multiply | present | PASS |
| SVE fused multiply-add | present | PASS |

观测计数：

```text
masked_loads = 5
masked_stores = 1
phi_i64 = 3
geps = 10
sve_fadds = 3
sve_fmuls = 1
sve_fmlas = 1
branches = 6
loop_backedges = 2
whilelo_predicates = 1
integer_muls = 1
```

## `stencil_3d7p_sme_f32`

| 检查项 | 期望 | 结果 |
|---|---:|---:|
| streaming-mode attribute | `aarch64_pstate_sm_body` | PASS |
| streaming vector length | `llvm.aarch64.sme.cntsw` | PASS |
| logical masked loads | 7 | PASS |
| masked store | 1 | PASS |
| loop induction PHIs | >= 5 | PASS |
| loop backedges | `!llvm.loop` present | PASS |
| tail predicate | `llvm.aarch64.sve.whilelo` | PASS |
| GEP address calculations | >= 12 | PASS |
| row-stride multiplication | `mul i64` present | PASS |
| SVE add chain | >= 5 | PASS |
| SVE multiply | present | PASS |
| SVE fused multiply-add | present | PASS |
| 3D plane-stride multiplication | additional `mul i64` present | PASS |

观测计数：

```text
masked_loads = 7
masked_stores = 1
phi_i64 = 5
geps = 14
sve_fadds = 5
sve_fmuls = 1
sve_fmlas = 1
branches = 8
loop_backedges = 3
whilelo_predicates = 1
integer_muls = 3
```

## 结论

当前 Clang `-O1` IR 保留了后续 LLVM pass 所需的：

1. 自然循环、归纳变量和回边分支。
2. 行/平面地址计算对应的 GEP 与整数乘法。
3. 2D5P 的 5 个和 3D7P 的 7 个 masked load。
4. SME streaming VL、SVE 算术和 masked store。
5. `aarch64_pstate_sm_body` 函数属性。

步骤 2 可以直接以该 LLVM IR 为输入建立 new-pass-manager 插件。
