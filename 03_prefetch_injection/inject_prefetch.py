#!/usr/bin/env python3
"""Step 3: inject research prefetch ops into affine MLIR."""

from __future__ import annotations

import argparse
import json
import pathlib


def build_prefetch_ops(cost_module: dict) -> list[str]:
    decisions = {item["tensor"]: item for item in cost_module["decisions"]}
    ops: list[str] = []

    b_decision = decisions.get("B")
    if b_decision and b_decision["enable"]:
        ops.extend(
            [
                "                      // 根据第二步 cost module 的决策，优先对 B 注入高优先级读预取。",
                "                      \"research.prefetch\"(%b, %ko, %j, %jj, %kk) <{",
                f"                        target = \"B\", kind = \"{b_decision['kind']}\", priority = \"{b_decision['priority']}\",",
                f"                        cache = \"{b_decision['target_cache']}\", locality = \"{b_decision['policy']}\",",
                f"                        distance = \"{b_decision['distance']}\"",
                "                      }> : (memref<?x?xf32>, index, index, index, index) -> ()",
            ]
        )

    a_decision = decisions.get("A")
    if a_decision and a_decision["enable"]:
        ops.extend(
            [
                "                      // A 的预取次于 B，但仍然在 kk 归约推进前发出，以覆盖后续读取延迟。",
                "                      \"research.prefetch\"(%a, %i, %ii, %ko, %kk) <{",
                f"                        target = \"A\", kind = \"{a_decision['kind']}\", priority = \"{a_decision['priority']}\",",
                f"                        cache = \"{a_decision['target_cache']}\", locality = \"{a_decision['policy']}\",",
                f"                        distance = \"{a_decision['distance']}\"",
                "                      }> : (memref<?x?xf32>, index, index, index, index) -> ()",
            ]
        )

    return ops


def inject_prefetch(affine_text: str, cost_module: dict) -> str:
    marker = "                    scf.if %in_k_bound {\n"
    if marker not in affine_text:
        raise ValueError("failed to locate kk-guard injection point in affine MLIR")

    prefetch_lines = build_prefetch_ops(cost_module)
    if not prefetch_lines:
        return affine_text

    annotated_header = (
        "// ============================================================================ \n"
        "// 自动生成文件：gemm_fp32_affine_prefetch.mlir\n"
        "// 来源：gemm_fp32_affine.mlir + 第二步 cost module 决策\n"
        "// 目标：在 affine 层显式注入研究版预取语义，为后续自定义 pass 提供输入\n"
        "//\n"
        "// 说明：\n"
        "// 1. 这里注入的是研究版 `research.prefetch`，暂时不是 LLVM 官方方言 op。\n"
        "// 2. 采用 generic op 形式，便于后续自定义 pass 识别与重写。\n"
        "// 3. 预取注入点放在 kk 归约循环内部，紧贴真实读流发生之前。\n"
        "// ============================================================================\n"
    )

    body = affine_text

    injection = marker + "\n".join(prefetch_lines) + "\n"
    body = body.replace(marker, injection, 1)
    body = body.replace(
        '    mlir_level = "affine"\n',
        '    mlir_level = "affine",\n    prefetch_injected = "true"\n',
        1,
    )
    return annotated_header + body


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inject research prefetch ops into affine MLIR."
    )
    parser.add_argument(
        "--affine",
        type=pathlib.Path,
        default=pathlib.Path("01_custom_lifter/output/gemm_fp32_affine.mlir"),
    )
    parser.add_argument(
        "--analysis",
        type=pathlib.Path,
        default=pathlib.Path("02_prefetch_cost_model/output/prefetch_analysis.json"),
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir"),
    )
    args = parser.parse_args()

    affine_text = args.affine.read_text(encoding="utf-8")
    analysis = json.loads(args.analysis.read_text(encoding="utf-8"))
    output_text = inject_prefetch(affine_text, analysis["cost_module"])

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
