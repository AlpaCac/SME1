#!/usr/bin/env python3
"""Analyze a Transform dialect schedule and an MLIR file.

This script is intentionally lightweight: it does not require MLIR Python
bindings. It reads MLIR text, extracts common operation patterns, and emits a
human-readable Chinese report that explains how the transform schedule relates
to the target MLIR.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
from dataclasses import dataclass


QUOTED_OP_RE = re.compile(r'"([A-Za-z_][\w.-]*)"\s*\(')
UNQUOTED_OP_RE = re.compile(r'(?<![#\w.])([A-Za-z_][\w]*\.[A-Za-z_][\w.]*)\b')
STRING_RE = re.compile(r'"[^"]*"')
TILE_RE = re.compile(r"tile_sizes\s+\[\[([^\]]+)\],\s*\[([^\]]+)\],\s*([^\]]+)\]")
VECTOR_RE = re.compile(r"vector_sizes\s+\[\[([^\]]+)\],\s*\[([^\]]+)\],\s*([^\]]+)\]")
MATCH_RE = re.compile(r'transform\.structured\.match\s+ops\{\["([^"]+)"\]\}')
LOWER_CONTRACTION_RE = re.compile(r'lower_contraction\s+lowering_strategy\s*=\s*"([^"]+)"')


@dataclass(frozen=True)
class OpHit:
    line: int
    op: str
    text: str


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_ops(text: str) -> list[OpHit]:
    hits: list[OpHit] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue

        # Generic assembly ops look like `"dialect.op"(...)`. Keep these before
        # removing ordinary string attributes.
        for match in QUOTED_OP_RE.finditer(line):
            hits.append(OpHit(line_no, match.group(1), stripped))

        # Remove string attributes such as `lift_target = "linalg.matmul -> ..."`
        # so they are not mistaken for real operations.
        line_without_strings = STRING_RE.sub('""', line)
        for match in UNQUOTED_OP_RE.finditer(line_without_strings):
            op = match.group(1)
            if op and "." in op:
                hits.append(OpHit(line_no, op, stripped))
    return hits


def count_by_prefix(ops: list[OpHit]) -> collections.Counter[str]:
    counter: collections.Counter[str] = collections.Counter()
    for hit in ops:
        counter[hit.op.split(".", 1)[0]] += 1
    return counter


def count_ops(ops: list[OpHit]) -> collections.Counter[str]:
    return collections.Counter(hit.op for hit in ops)


def first_lines(ops: list[OpHit], names: set[str], limit: int = 8) -> list[OpHit]:
    selected: list[OpHit] = []
    for hit in ops:
        if hit.op in names:
            selected.append(hit)
            if len(selected) >= limit:
                break
    return selected


def parse_transform(text: str) -> list[str]:
    lines: list[str] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if "transform." in stripped:
            lines.append(f"{line_no}: {stripped}")
    return lines


def summarize_transform(text: str) -> list[str]:
    summary: list[str] = []

    matches = MATCH_RE.findall(text)
    if matches:
        summary.append("匹配目标 op：" + ", ".join(f"`{item}`" for item in matches))

    tile = TILE_RE.search(text)
    if tile:
        summary.append(
            f"分块策略：M/N/K 方向 tile sizes = `{tile.group(1).strip()} x "
            f"{tile.group(2).strip()} x {tile.group(3).strip()}`"
        )

    vector = VECTOR_RE.search(text)
    if vector:
        summary.append(
            f"向量化策略：vector sizes = `{vector.group(1).strip()} x "
            f"{vector.group(2).strip()} x {vector.group(3).strip()}`"
        )

    contraction = LOWER_CONTRACTION_RE.search(text)
    if contraction:
        summary.append(f"vector contraction lowering 策略：`{contraction.group(1)}`")

    if "transform.apply_licm" in text:
        summary.append("包含 LICM：会尝试提升循环不变操作。")
    if "transform.loop.hoist_loop_invariant_subsets" in text:
        summary.append("包含 loop invariant subset hoisting：会尝试提升循环不变 subset。")

    return summary


def explain_transform_op(line: str) -> str:
    if "structured.match" in line:
        return "查找后续变换要作用的 IR 对象。"
    if "tile_using_for" in line:
        return "把结构化算子切分成 tile，并生成循环承载 tile 计算。"
    if "structured.vectorize" in line:
        return "把 tile 内部计算转换成 `vector.*` 表示。"
    if "apply_patterns.vector.lower_masked_transfers" in line:
        return "降低带 mask 的 vector transfer 读写。"
    if "transfer_permutation_patterns" in line:
        return "规整 vector transfer 中的置换/布局模式。"
    if "reduction_to_contract" in line:
        return "把 reduction 形式规整为 vector contraction。"
    if "lower_contraction" in line:
        return "把 vector contraction 继续降低为指定策略，例如 outerproduct。"
    if "lower_masks" in line:
        return "降低 vector mask 相关结构。"
    if "rank_reducing_subview_patterns" in line:
        return "规整 rank-reducing subview，便于后续 lowering。"
    if "canonicalization" in line:
        return "执行通用规范化，清理冗余 IR。"
    if "apply_licm" in line:
        return "提升循环不变代码。"
    if "hoist_loop_invariant_subsets" in line:
        return "提升循环不变 subset。"
    if "yield" in line:
        return "结束 transform named sequence。"
    return "Transform dialect 调度语句。"


def emit_report(transform_path: pathlib.Path, mlir_path: pathlib.Path) -> str:
    transform_text = read_text(transform_path)
    mlir_text = read_text(mlir_path)

    transform_ops = extract_ops(transform_text)
    mlir_ops = extract_ops(mlir_text)
    mlir_op_counts = count_ops(mlir_ops)
    dialect_counts = count_by_prefix(mlir_ops)
    transform_steps = parse_transform(transform_text)
    transform_summary = summarize_transform(transform_text)

    lines: list[str] = []
    lines.append("# Transform Dialect 与 MLIR 分析报告")
    lines.append("")
    lines.append(f"- Transform 文件：`{transform_path}`")
    lines.append(f"- MLIR 文件：`{mlir_path}`")
    lines.append("")

    lines.append("## 1. Transform Dialect 调度概览")
    if transform_summary:
        for item in transform_summary:
            lines.append(f"- {item}")
    else:
        lines.append("- 未识别到常见 transform structured 调度模式。")
    lines.append("")

    lines.append("## 2. Transform Dialect 逐句解释")
    if transform_steps:
        for step in transform_steps:
            lines.append(f"- `{step}`")
            lines.append(f"  作用：{explain_transform_op(step)}")
    else:
        lines.append("- 未找到以 `transform.` 开头的调度语句。")
    lines.append("")

    lines.append("## 3. MLIR Dialect 分布")
    if dialect_counts:
        for dialect, count in dialect_counts.most_common():
            lines.append(f"- `{dialect}`：{count}")
    else:
        lines.append("- 未识别到 dialect op。")
    lines.append("")

    important_ops = [
        "linalg.matmul",
        "linalg.fill",
        "scf.for",
        "affine.min",
        "memref.subview",
        "memref.prefetch",
        "vector.transfer_read",
        "vector.outerproduct",
        "vector.transfer_write",
        "arm_sme.intr.mopa",
        "llvm.intr.prefetch",
    ]
    lines.append("## 4. 关键 op 统计")
    for op in important_ops:
        count = mlir_op_counts.get(op, 0)
        lines.append(f"- `{op}`：{count}")
    lines.append("")

    lines.append("## 5. 关键语句示例")
    examples = first_lines(mlir_ops, set(important_ops), limit=12)
    if examples:
        for hit in examples:
            lines.append(f"- 第 {hit.line} 行 `{hit.op}`：`{hit.text}`")
    else:
        lines.append("- 当前 MLIR 中未找到预设关键 op 示例。")
    lines.append("")

    lines.append("## 6. 解释结论")
    if mlir_op_counts.get("linalg.matmul", 0):
        lines.append("- 当前 MLIR 仍保留 `linalg.matmul`，说明它处于较高层矩阵语义表示。")
    if mlir_op_counts.get("vector.outerproduct", 0):
        lines.append("- 当前 MLIR 已包含 `vector.outerproduct`，说明矩阵乘核心已经进入 vector 层外积形式。")
    if mlir_op_counts.get("memref.prefetch", 0):
        lines.append("- 当前 MLIR 已包含 `memref.prefetch`，说明预取语义已经进入标准 MLIR 表示。")
    if mlir_op_counts.get("arm_sme.intr.mopa", 0):
        lines.append("- 当前 MLIR 已包含 `arm_sme.intr.mopa`，说明计算已经进入 Arm SME 相关表示。")
    if mlir_op_counts.get("llvm.intr.prefetch", 0):
        lines.append("- 当前 MLIR 已包含 `llvm.intr.prefetch`，说明预取已经降低到 LLVM dialect。")
    if not any(
        mlir_op_counts.get(op, 0)
        for op in [
            "linalg.matmul",
            "vector.outerproduct",
            "memref.prefetch",
            "arm_sme.intr.mopa",
            "llvm.intr.prefetch",
        ]
    ):
        lines.append("- 未识别到本项目预设的关键计算或预取 op，需要检查输入 MLIR 是否属于当前研究主线。")

    lines.append("")
    lines.append("## 7. 使用说明")
    lines.append("该脚本是文本级分析工具，适合快速解释 IR 结构；它不执行 MLIR verifier，也不替代 `mlir-opt`。")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze a Transform dialect schedule and an MLIR file."
    )
    parser.add_argument("--transform", required=True, type=pathlib.Path, help="Transform dialect MLIR file")
    parser.add_argument("--mlir", required=True, type=pathlib.Path, help="Target MLIR file to analyze")
    parser.add_argument("--output", type=pathlib.Path, help="Optional markdown report path")
    args = parser.parse_args()

    report = emit_report(args.transform, args.mlir)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
