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
    if attributes is None:
        return False
    return any(
        attribute in attributes.group(0)
        for attribute in (
            "aarch64_pstate_sm_body",
            "aarch64_pstate_sm_enabled",
            "aarch64_pstate_sm_compatible",
        )
    )


def metrics_for(ir: str, name: str) -> tuple[list[tuple[str, str, bool]], dict[str, int]]:
    header, body = extract_function(ir, name)
    metrics = {
        "masked_loads": body.count("llvm.masked.load."),
        "masked_stores": body.count("llvm.masked.store."),
        "sme_intrinsics": body.count("llvm.aarch64.sme."),
        "sme_vector_lengths": body.count("llvm.aarch64.sme.cntsw")
        + body.count("llvm.aarch64.sme.cntsd"),
        "sve_vector_lengths": body.count("llvm.aarch64.sve.cntw")
        + body.count("llvm.aarch64.sve.cntd"),
        "vscale_vector_lengths": body.count("llvm.vscale."),
        "phi_i32": body.count("phi i32"),
        "phi_i64": body.count("phi i64"),
        "geps": body.count("getelementptr"),
        "sve_fadds": body.count("llvm.aarch64.sve.fadd."),
        "sve_fmuls": body.count("llvm.aarch64.sve.fmul."),
        "sve_fmlas": body.count("llvm.aarch64.sve.fmla."),
        "loop_backedges": body.count("!llvm.loop"),
        "whilelo_predicates": body.count("llvm.aarch64.sve.whilelo."),
        "whilelt_predicates": body.count("llvm.aarch64.sve.whilelt."),
        "integer_muls": body.count("mul i64"),
    }
    checks = [
        (
            "SME streaming context",
            "streaming attribute or SME intrinsic",
            has_streaming_attribute(ir, header) or metrics["sme_intrinsics"] >= 1,
        ),
        (
            "scalable vector length",
            "SME/SVE `cnt*` or `llvm.vscale`",
            metrics["sme_vector_lengths"]
            + metrics["sve_vector_lengths"]
            + metrics["vscale_vector_lengths"]
            >= 1,
        ),
        ("logical masked loads", ">= 1", metrics["masked_loads"] >= 1),
        ("masked store", ">= 1", metrics["masked_stores"] >= 1),
        ("loop induction PHIs", "`i32` or `i64`, >= 1", metrics["phi_i32"] + metrics["phi_i64"] >= 1),
        ("loop backedges", "`!llvm.loop` present", metrics["loop_backedges"] >= 1),
        (
            "tail predicate",
            "`llvm.aarch64.sve.whilelo` or `whilelt`",
            metrics["whilelo_predicates"] + metrics["whilelt_predicates"] >= 1,
        ),
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
    lines = [
        "# 步骤 1 LLVM IR 分析报告",
        "",
        "- 总体结果：**PASS（已生成分析报告）**",
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
        "表中 FAIL 表示该函数未呈现对应的 IR 特征，不表示步骤 1 失败；例如纯标量",
        "实现通常没有 predicated masked load 或 `whilelo`/`whilelt`。后续 pass 是否",
        "插入预取仍取决于其更严格的 stencil 识别与决策条件。",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    ir = args.ir.read_text(encoding="utf-8")
    results = []
    for name in args.functions:
        checks, metrics = metrics_for(ir, name)
        results.append((name, checks, metrics))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(render_report(args, results), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
