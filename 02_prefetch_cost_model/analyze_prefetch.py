#!/usr/bin/env python3
"""Step 2: analyze linalg/affine MLIR and build a simple prefetch cost module."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
from dataclasses import asdict, dataclass


CONST_RE = re.compile(r"arith\.constant\s+(?P<value>\d+)\s+:\s+index")


@dataclass
class TileConfig:
    mc: int
    nc: int
    kc: int
    mr: int
    nr: int
    element_bytes: int = 4


def parse_tile_config(linalg_text: str) -> TileConfig:
    values = [int(match.group("value")) for match in CONST_RE.finditer(linalg_text)]
    unique = []
    for value in values:
        if value <= 1:
            continue
        if value not in unique:
            unique.append(value)
    if len(unique) < 2:
        raise ValueError("failed to recover tile sizes from linalg MLIR")

    large = [value for value in unique if value >= 64]
    small = [value for value in unique if value < 64]
    if not large or not small:
        raise ValueError("unexpected tile distribution in linalg MLIR")

    mc = nc = kc = large[0]
    mr = nr = small[0]
    return TileConfig(mc=mc, nc=nc, kc=kc, mr=mr, nr=nr)


def analyze_linalg(linalg_text: str, cfg: TileConfig) -> dict:
    has_matmul = "linalg.matmul" in linalg_text
    has_fill = "linalg.fill" in linalg_text
    subviews = len(re.findall(r"memref\.subview", linalg_text))
    loops = len(re.findall(r"scf\.for", linalg_text))

    macro_a = cfg.mc * cfg.kc * cfg.element_bytes
    macro_b = cfg.kc * cfg.nc * cfg.element_bytes
    macro_c = cfg.mc * cfg.nc * cfg.element_bytes
    micro_a = cfg.mr * cfg.kc * cfg.element_bytes
    micro_b = cfg.kc * cfg.nr * cfg.element_bytes
    micro_c = cfg.mr * cfg.nr * cfg.element_bytes

    return {
        "operator_summary": {
            "has_linalg_matmul": has_matmul,
            "has_linalg_fill": has_fill,
            "subview_count": subviews,
            "scf_loop_count": loops,
        },
        "dataflow_roles": {
            "A": "只读输入，提供 MxK 左操作数",
            "B": "只读输入，提供 KxN 右操作数",
            "C": "输出块，先 fill 再 matmul 累加写回",
            "reduction_dim": "K / ko / kk",
            "spatial_dims": ["M / i / ii", "N / j / jj"],
        },
        "tile_bytes": {
            "macro_tile": {
                "A_bytes": macro_a,
                "B_bytes": macro_b,
                "C_bytes": macro_c,
                "total_bytes": macro_a + macro_b + macro_c,
            },
            "micro_tile": {
                "A_bytes": micro_a,
                "B_bytes": micro_b,
                "C_bytes": micro_c,
                "total_bytes": micro_a + micro_b + micro_c,
            },
        },
        "reuse_summary": {
            "A_value_reuse_in_micro_kernel": cfg.nr,
            "B_value_reuse_in_micro_kernel": cfg.mr,
            "C_element_accumulation_depth": cfg.kc,
            "interpretation": "A 在 j_inner 方向复用，B 在 i_inner 方向复用，C 在 kk 方向持续累加。",
        },
    }


def analyze_affine(affine_text: str, cfg: TileConfig) -> dict:
    affine_loops = len(re.findall(r"affine\.for", affine_text))
    affine_loads = len(re.findall(r"affine\.load", affine_text))
    affine_stores = len(re.findall(r"affine\.store", affine_text))
    affine_ifs = len(re.findall(r"scf\.if", affine_text))

    return {
        "operator_summary": {
            "affine_loop_count": affine_loops,
            "affine_load_count": affine_loads,
            "affine_store_count": affine_stores,
            "boundary_guard_count": affine_ifs,
        },
        "access_patterns": {
            "A": {
                "pattern": "a[a_row, a_col]",
                "inner_locality": "kk 连续推进，A 沿行方向按 stride-1 访问",
                "cross_tile_reuse": "同一 A 微块在 j_inner 上被重复使用",
            },
            "B": {
                "pattern": "b[b_row, b_col]",
                "inner_locality": "j_inner 连续推进，B 沿列块内呈 stride-1 访问",
                "cross_tile_reuse": "同一 B 微块在 i_inner 上被重复使用",
            },
            "C": {
                "pattern": "c[c_row, c_col]",
                "inner_locality": "j_inner 连续写，kk 上反复读改写",
                "cross_tile_reuse": "当前实现中主要局限于单个微块生命周期",
            },
        },
        "prefetch_relevant_metrics": {
            "micro_tile_shape": [cfg.mr, cfg.nr, cfg.kc],
            "macro_tile_shape": [cfg.mc, cfg.nc, cfg.kc],
            "A_stream_bytes_per_micro_tile": cfg.mr * cfg.kc * cfg.element_bytes,
            "B_stream_bytes_per_micro_tile": cfg.kc * cfg.nr * cfg.element_bytes,
            "C_write_bytes_per_micro_tile": cfg.mr * cfg.nr * cfg.element_bytes,
            "interpretation": "A/B 是主要读流；C 更像短生命周期的累加输出块。",
        },
    }


def build_cost_model(cfg: TileConfig) -> dict:
    a_stream = cfg.mr * cfg.kc * cfg.element_bytes
    b_stream = cfg.kc * cfg.nr * cfg.element_bytes
    c_write = cfg.mr * cfg.nr * cfg.element_bytes
    total_macro = (cfg.mc * cfg.kc + cfg.kc * cfg.nc + cfg.mc * cfg.nc) * cfg.element_bytes

    decisions = [
        {
            "tensor": "B",
            "enable": True,
            "kind": "read",
            "priority": "high",
            "target_cache": "L1",
            "distance": "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界",
            "policy": "KEEP",
            "reason": "B 在 j_inner 上连续访问，同时在 i_inner 上复用，既有良好流式特征又有明显重用价值。",
        },
        {
            "tensor": "A",
            "enable": True,
            "kind": "read",
            "priority": "medium",
            "target_cache": "L1",
            "distance": "按未来 1 到 2 个 kk-cache-line",
            "policy": "KEEP",
            "reason": "A 在 kk 上连续，单个 a_val 在 j_inner 上被重复消费，适合较短距离读预取。",
        },
        {
            "tensor": "C",
            "enable": False,
            "kind": "write",
            "priority": "low",
            "target_cache": "none",
            "distance": "none",
            "policy": "none",
            "reason": "当前研究版中 C 微块较小，且生命周期局限在单微块内，主动软件预取收益预期较弱。",
        },
    ]

    return {
        "assumptions": {
            "element_type": "f32",
            "element_bytes": cfg.element_bytes,
            "cache_line_bytes": 64,
            "macro_working_set_bytes": total_macro,
            "micro_read_stream_bytes": {
                "A": a_stream,
                "B": b_stream,
                "C_write": c_write,
            },
        },
        "decision_policy": {
            "guideline": "优先预取读流且优先选择同时具备连续访问和跨迭代复用的数据对象。",
            "expected_benefit_order": ["B", "A", "C"],
        },
        "decisions": decisions,
        "prefetch_op_suggestions": [
            {
                "level": "affine",
                "target": "B",
                "suggested_form": "custom.prefetch %b[...] {{cache = \"L1\", rw = \"read\", locality = \"keep\"}}",
            },
            {
                "level": "affine",
                "target": "A",
                "suggested_form": "custom.prefetch %a[...] {{cache = \"L1\", rw = \"read\", locality = \"keep\"}}",
            },
        ],
    }


def build_markdown(linalg_result: dict, affine_result: dict, cost_result: dict) -> str:
    decisions = cost_result["decisions"]
    lines = [
        "# 第二步分析结果",
        "",
        "这份文档由 `analyze_prefetch.py` 自动生成，目标是把第一步得到的 `linalg` 与 `affine` 两个 MLIR 文件进一步整理为预取研究可用的分析结果。",
        "",
        "## 1. Linalg 层整体数据流性质",
        "",
        f"- 核心算子：`linalg.matmul` = `{linalg_result['operator_summary']['has_linalg_matmul']}`",
        f"- 块初始化：`linalg.fill` = `{linalg_result['operator_summary']['has_linalg_fill']}`",
        f"- `memref.subview` 数量：`{linalg_result['operator_summary']['subview_count']}`",
        f"- `scf.for` 数量：`{linalg_result['operator_summary']['scf_loop_count']}`",
        "- 数据流角色：A 为左输入，B 为右输入，C 为输出累加块。",
        f"- 归约维：`{linalg_result['dataflow_roles']['reduction_dim']}`",
        f"- 空间维：`{', '.join(linalg_result['dataflow_roles']['spatial_dims'])}`",
        f"- 宏块工作集：`{linalg_result['tile_bytes']['macro_tile']['total_bytes']}` bytes",
        f"- 微块工作集：`{linalg_result['tile_bytes']['micro_tile']['total_bytes']}` bytes",
        f"- 复用摘要：{linalg_result['reuse_summary']['interpretation']}",
        "",
        "## 2. Affine 层预取相关分析",
        "",
        f"- `affine.for` 数量：`{affine_result['operator_summary']['affine_loop_count']}`",
        f"- `affine.load` 数量：`{affine_result['operator_summary']['affine_load_count']}`",
        f"- `affine.store` 数量：`{affine_result['operator_summary']['affine_store_count']}`",
        f"- 边界保护 `scf.if` 数量：`{affine_result['operator_summary']['boundary_guard_count']}`",
        "- A：沿 `kk` 呈连续读，适合短距离读预取。",
        "- B：沿 `j_inner` 呈连续读，并在 `i_inner` 方向复用，是优先级最高的预取对象。",
        "- C：主要表现为微块内读改写，主动软件预取价值相对较低。",
        "",
        "## 3. Cost Module 决策",
        "",
        f"- 决策原则：{cost_result['decision_policy']['guideline']}",
        f"- 预计收益排序：`{' > '.join(cost_result['decision_policy']['expected_benefit_order'])}`",
    ]

    for decision in decisions:
        status = "开启" if decision["enable"] else "关闭"
        lines.extend(
            [
                f"- `{decision['tensor']}`：{status} `{decision['kind']}` 预取，缓存目标 `{decision['target_cache']}`，策略 `{decision['policy']}`。",
                f"  说明：{decision['reason']}",
            ]
        )

    lines.extend(
        [
            "",
            "## 4. 对后续 MLIR 注入的含义",
            "",
            "- 在 `affine` 层优先对 `B` 注入读预取，再考虑 `A`。",
            "- `C` 目前建议不主动注入预取，而是观察后续真实硬件行为后再决定。",
            "- 如果下一步要设计自定义预取 op，可以先只覆盖 `A/B` 两个输入流。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze linalg/affine MLIR and emit prefetch cost reports."
    )
    parser.add_argument(
        "--linalg",
        type=pathlib.Path,
        default=pathlib.Path("01_custom_lifter/output/gemm_fp32_linalg.mlir"),
    )
    parser.add_argument(
        "--affine",
        type=pathlib.Path,
        default=pathlib.Path("01_custom_lifter/output/gemm_fp32_affine.mlir"),
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=pathlib.Path("02_prefetch_cost_model/output"),
    )
    args = parser.parse_args()

    linalg_text = args.linalg.read_text(encoding="utf-8")
    affine_text = args.affine.read_text(encoding="utf-8")
    cfg = parse_tile_config(linalg_text)

    linalg_result = analyze_linalg(linalg_text, cfg)
    affine_result = analyze_affine(affine_text, cfg)
    cost_result = build_cost_model(cfg)

    result = {
        "tile_config": asdict(cfg),
        "linalg_analysis": linalg_result,
        "affine_analysis": affine_result,
        "cost_module": cost_result,
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "prefetch_analysis.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (args.output_dir / "prefetch_analysis.md").write_text(
        build_markdown(linalg_result, affine_result, cost_result),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
