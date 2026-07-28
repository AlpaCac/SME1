#!/usr/bin/env python3
"""Report whether extracted SME stencil kernels retain analyzable IR."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--full-ir", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--clang-version", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--march", required=True)
    parser.add_argument("--functions", nargs="+", required=True)
    return parser.parse_args()


def extract_function(ir: str, name: str) -> tuple[str, str]:
    header_pattern = re.compile(
        rf"^define\b.*@{re.escape(name)}\(.*$", re.MULTILINE
    )
    match = header_pattern.search(ir)
    if match is None:
        raise ValueError(f"missing function: {name}")

    start = match.start()
    end_match = re.search(r"^}\s*$", ir[match.end() :], re.MULTILINE)
    if end_match is None:
        raise ValueError(f"unterminated function: {name}")
    return match.group(0), ir[start : match.end() + end_match.end()]


def has_streaming_attribute(ir: str, header: str) -> bool:
    attribute_ref = re.search(r"#(\d+)\s*\{\s*$", header)
    if attribute_ref is None:
        return False
    attributes = re.search(
        rf"^attributes #{attribute_ref.group(1)} = \{{.*\}}$",
        ir,
        re.MULTILINE,
    )
    return attributes is not None and "aarch64_pstate_sm_body" in attributes.group(0)


def metrics_for(ir: str, name: str) -> tuple[list[tuple[str, str, bool]], dict[str, int]]:
    header, body = extract_function(ir, name)
    metrics = {
        "masked_loads": body.count("llvm.masked.load."),
        "masked_stores": body.count("llvm.masked.store."),
        "phi_i64": body.count("phi i64"),
        "geps": body.count("getelementptr"),
        "sve_fadds": body.count("llvm.aarch64.sve.fadd."),
        "sve_fmuls": body.count("llvm.aarch64.sve.fmul."),
        "sve_fmlas": body.count("llvm.aarch64.sve.fmla."),
        "loop_backedges": body.count("!llvm.loop"),
        "whilelo_predicates": body.count("llvm.aarch64.sve.whilelo."),
        "integer_muls": body.count("mul i64"),
    }
    checks = [
        ("streaming-mode attribute", "`aarch64_pstate_sm_body`", has_streaming_attribute(ir, header)),
        ("streaming vector length", "`llvm.aarch64.sme.cntsw`", "llvm.aarch64.sme.cntsw" in body),
        ("logical masked loads", ">= 1", metrics["masked_loads"] >= 1),
        ("masked store", ">= 1", metrics["masked_stores"] >= 1),
        ("loop induction PHIs", ">= 1", metrics["phi_i64"] >= 1),
        ("loop backedges", "`!llvm.loop` present", metrics["loop_backedges"] >= 1),
        ("tail predicate", "`llvm.aarch64.sve.whilelo`", metrics["whilelo_predicates"] >= 1),
        ("GEP address calculations", ">= 1", metrics["geps"] >= 1),
    ]
    return checks, metrics


def classify(metrics: dict[str, int]) -> str:
    if metrics["masked_loads"] == 5:
        return "2D5P candidate"
    if metrics["masked_loads"] == 7:
        return "3D7P candidate"
    return "other stencil candidate"


def render_report(
    args: argparse.Namespace,
    results: list[tuple[str, list[tuple[str, str, bool]], dict[str, int]]],
) -> str:
    all_passed = all(passed for _, checks, _ in results for _, _, passed in checks)
    lines = [
        "# 步骤 1 LLVM IR 分析报告",
        "",
        f"- 总体结果：**{'PASS' if all_passed else 'FAIL'}**",
        f"- Clang：`{args.clang_version}`",
        f"- Target：`{args.target}`",
        f"- Architecture：`{args.march}`",
        f"- 输入：`{args.source}`",
        f"- 完整 IR：`output/{args.full_ir.name}`（含 test/main）",
        f"- Kernel IR：`output/{args.ir.name}`（仅配置的计算函数）",
        "",
    ]
    for name, checks, metrics in results:
        lines.extend([f"## `{name}`", "", f"- 分类：{classify(metrics)}", "", "| 检查项 | 期望 | 结果 |", "|---|---:|---:|"])
        for label, expected, passed in checks:
            lines.append(f"| {label} | {expected} | {'PASS' if passed else 'FAIL'} |")
        lines.extend(["", "观测计数：", "", "```text"])
        lines.extend(f"{key} = {value}" for key, value in metrics.items())
        lines.extend(["```", ""])
    lines.extend([
        "## 结论",
        "",
        "步骤 2 只接收上述 kernel-only IR，因此 test 与 main 不会进入预取 pass。",
        "当前 pass 仅对严格匹配 2D5P 或 3D7P 的函数插入预取；其他函数的",
        "指标会被保留在报告中，待新增相应的识别和决策模型后再启用。",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    ir = args.ir.read_text(encoding="utf-8")
    results = []
    failed = False
    for name in args.functions:
        checks, metrics = metrics_for(ir, name)
        results.append((name, checks, metrics))
        failed |= any(not passed for _, _, passed in checks)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(render_report(args, results), encoding="utf-8")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
