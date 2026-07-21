#!/usr/bin/env python3
"""Analyze a Transform dialect schedule.

The script only needs one positional argument: the path of a Transform dialect
MLIR file. It performs a lightweight text-level analysis and emits a Chinese
report describing what the transform schedule is intended to do.
"""

from __future__ import annotations

import argparse
import pathlib
import re
from dataclasses import dataclass


TILE_RE = re.compile(r"tile_sizes\s+\[\[([^\]]+)\],\s*\[([^\]]+)\],\s*([^\]]+)\]")
VECTOR_RE = re.compile(r"vector_sizes\s+\[\[([^\]]+)\],\s*\[([^\]]+)\],\s*([^\]]+)\]")
MATCH_OP_RE = re.compile(r'transform\.structured\.match\s+ops\{\["([^"]+)"\]\}')
MATCH_INTERFACE_RE = re.compile(r"transform\.structured\.match\s+interface\{([^}]+)\}")
LOWER_CONTRACTION_RE = re.compile(r'lower_contraction\s+lowering_strategy\s*=\s*"([^"]+)"')


@dataclass(frozen=True)
class TransformStep:
    line: int
    text: str
    kind: str
    effect: str


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def classify_transform_step(text: str) -> tuple[str, str]:
    if "transform.named_sequence" in text:
        return "入口", "定义 transform 主调度序列，通常由 transform-interpreter 执行。"
    if "transform.structured.match ops" in text:
        match = MATCH_OP_RE.search(text)
        target = match.group(1) if match else "指定 op"
        return "匹配", f"在输入 IR 中查找 `{target}`，作为后续变换的 handle。"
    if "transform.structured.match interface" in text:
        match = MATCH_INTERFACE_RE.search(text)
        target = match.group(1) if match else "指定接口"
        return "匹配", f"查找实现 `{target}` 的 op，常用于统一处理循环类结构。"
    if "tile_using_for" in text:
        tile = TILE_RE.search(text)
        if tile:
            size = f"{tile.group(1).strip()} x {tile.group(2).strip()} x {tile.group(3).strip()}"
            return "分块", f"对结构化算子进行 tiling，tile sizes 为 `{size}`，并生成循环承载 tile 计算。"
        return "分块", "对结构化算子进行 tiling，并生成循环承载 tile 计算。"
    if "structured.vectorize" in text:
        vector = VECTOR_RE.search(text)
        if vector:
            size = f"{vector.group(1).strip()} x {vector.group(2).strip()} x {vector.group(3).strip()}"
            return "向量化", f"将 tile 内部计算转换成 vector 层表示，vector sizes 为 `{size}`。"
        return "向量化", "将 tile 内部计算转换成 vector 层表示。"
    if "apply_patterns.vector.lower_masked_transfers" in text:
        return "vector pattern", "降低带 mask 的 vector transfer 读写。"
    if "apply_patterns.vector.transfer_permutation_patterns" in text:
        return "vector pattern", "规整 vector transfer 中的置换和布局模式。"
    if "apply_patterns.vector.reduction_to_contract" in text:
        return "vector pattern", "把 reduction 形式规整为 vector contraction。"
    if "apply_patterns.vector.sink_ops" in text:
        return "vector pattern", "下沉可移动 op，使 vector IR 更适合后续规范化和 lowering。"
    if "apply_patterns.vector.lower_contraction" in text:
        contraction = LOWER_CONTRACTION_RE.search(text)
        strategy = contraction.group(1) if contraction else "指定策略"
        return "vector lowering", f"把 vector contraction 降低为 `{strategy}` 形式。"
    if "apply_patterns.vector.lower_masks" in text:
        return "vector lowering", "降低 vector mask 相关结构。"
    if "apply_patterns.vector.rank_reducing_subview_patterns" in text:
        return "memref/vector pattern", "规整 rank-reducing subview，便于 vector transfer 和后续 lowering。"
    if "apply_patterns.canonicalization" in text:
        return "规范化", "执行通用 canonicalization，清理冗余 IR。"
    if "transform.apply_patterns" in text:
        return "pattern 应用", "对指定 handle 应用一组 rewrite pattern。"
    if "transform.apply_licm" in text:
        return "循环优化", "执行 LICM，提升循环不变代码。"
    if "transform.loop.hoist_loop_invariant_subsets" in text:
        return "循环优化", "提升循环不变 subset，减少循环体中的重复子视图计算。"
    if "transform.yield" in text:
        return "结束", "结束 transform named sequence。"
    return "辅助语句", "Transform dialect 类型、region 或辅助语句。"


def collect_steps(text: str) -> list[TransformStep]:
    steps: list[TransformStep] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        if stripped.startswith(":") or stripped.startswith("}"):
            continue
        if "transform." not in stripped:
            continue
        kind, effect = classify_transform_step(stripped)
        steps.append(TransformStep(line_no, stripped, kind, effect))
    return steps


def summarize_function(text: str, steps: list[TransformStep]) -> list[str]:
    summary: list[str] = []

    matched_ops = MATCH_OP_RE.findall(text)
    if matched_ops:
        summary.append("匹配目标 op：" + ", ".join(f"`{op}`" for op in matched_ops))

    matched_interfaces = MATCH_INTERFACE_RE.findall(text)
    if matched_interfaces:
        summary.append("匹配接口：" + ", ".join(f"`{item}`" for item in matched_interfaces))

    tile = TILE_RE.search(text)
    if tile:
        summary.append(
            f"分块策略：`{tile.group(1).strip()} x {tile.group(2).strip()} x {tile.group(3).strip()}`"
        )

    vector = VECTOR_RE.search(text)
    if vector:
        summary.append(
            f"向量化策略：`{vector.group(1).strip()} x {vector.group(2).strip()} x {vector.group(3).strip()}`"
        )

    contraction = LOWER_CONTRACTION_RE.search(text)
    if contraction:
        summary.append(f"contraction lowering 策略：`{contraction.group(1)}`")

    kinds = {step.kind for step in steps}
    if "循环优化" in kinds:
        summary.append("包含循环优化：LICM / loop invariant subset hoisting。")
    if "vector pattern" in kinds or "vector lowering" in kinds:
        summary.append("包含 vector 规范化和 lowering pattern。")

    return summary


def infer_expected_effect(text: str) -> list[str]:
    effects: list[str] = []
    if "linalg.matmul" in text and "structured.vectorize" in text:
        effects.append("预期把 `linalg.matmul` 推进到 `vector.transfer_read / vector.outerproduct / vector.transfer_write` 形式。")
    if "tile_using_for" in text:
        effects.append("预期在目标 IR 中引入或保留 tile 循环结构，用于表达分块计算。")
    if 'lowering_strategy = "outerproduct"' in text:
        effects.append("预期将矩阵乘 contraction 表达成 outerproduct，这适合继续衔接 SME matrix outer product。")
    if "lower_masked_transfers" in text or "lower_masks" in text:
        effects.append("预期处理动态边界 tile 的 mask，使尾块访问和向量计算保持合法。")
    if "rank_reducing_subview_patterns" in text:
        effects.append("预期把部分二维/一维 subview 关系规整成更适合 vector transfer 的形式。")
    if "apply_licm" in text or "hoist_loop_invariant_subsets" in text:
        effects.append("预期减少循环体内不必要的重复计算，使 IR 更规整。")
    return effects


def emit_report(transform_path: pathlib.Path) -> str:
    text = read_text(transform_path)
    steps = collect_steps(text)
    summary = summarize_function(text, steps)
    expected_effects = infer_expected_effect(text)

    lines: list[str] = []
    lines.append("# Transform Dialect 功能分析报告")
    lines.append("")
    lines.append(f"- Transform 文件：`{transform_path}`")
    lines.append("")

    lines.append("## 1. 功能概览")
    if summary:
        for item in summary:
            lines.append(f"- {item}")
    else:
        lines.append("- 未识别到常见 transform structured 调度模式。")
    lines.append("")

    lines.append("## 2. 执行顺序")
    if steps:
        for index, step in enumerate(steps, start=1):
            lines.append(f"{index}. 第 {step.line} 行 `{step.text}`")
            lines.append(f"   类型：{step.kind}")
            lines.append(f"   作用：{step.effect}")
    else:
        lines.append("- 未找到 transform dialect 语句。")
    lines.append("")

    lines.append("## 3. 预期 IR 效果")
    if expected_effects:
        for item in expected_effects:
            lines.append(f"- {item}")
    else:
        lines.append("- 无法根据当前文本推断明确的 IR 效果。")
    lines.append("")

    lines.append("## 4. 当前调度定位")
    if "linalg.matmul" in text and "structured.vectorize" in text:
        lines.append("- 该 transform 文件的核心定位是：把高层 `linalg.matmul` 主线转换成适合后续预取注入和 Arm SME lowering 的 vector 层 IR。")
    else:
        lines.append("- 该 transform 文件的定位需要结合输入 IR 和具体 matched op 进一步判断。")
    lines.append("")

    lines.append("## 5. 使用注意")
    lines.append("- 该脚本只分析 transform 文件本身，不读取目标 MLIR，也不验证 transform 是否能成功应用。")
    lines.append("- 是否真正产生预期 IR，需要继续使用 `mlir-opt ... transform-interpreter` 执行并检查输出。")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze a Transform dialect MLIR file.")
    parser.add_argument("transform", type=pathlib.Path, help="Transform dialect MLIR file")
    parser.add_argument("--output", type=pathlib.Path, help="Optional markdown report path")
    args = parser.parse_args()

    report = emit_report(args.transform)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
