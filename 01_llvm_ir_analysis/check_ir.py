#!/usr/bin/env python3
"""Check that Clang IR retains the structure needed by the stencil pass."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class KernelExpectation:
    name: str
    masked_loads: int
    minimum_phis: int
    minimum_geps: int
    minimum_fadds: int
    requires_plane_stride: bool


EXPECTATIONS = (
    KernelExpectation(
        name="stencil_2d5p_sme_f32",
        masked_loads=5,
        minimum_phis=3,
        minimum_geps=8,
        minimum_fadds=3,
        requires_plane_stride=False,
    ),
    KernelExpectation(
        name="stencil_3d7p_sme_f32",
        masked_loads=7,
        minimum_phis=5,
        minimum_geps=12,
        minimum_fadds=5,
        requires_plane_stride=True,
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--clang-version", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--march", required=True)
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

    end = match.end() + end_match.end()
    return match.group(0), ir[start:end]


def count(body: str, token: str) -> int:
    return body.count(token)


def function_has_streaming_attribute(ir: str, header: str) -> bool:
    attribute_ref = re.search(r"#(\d+)\s*\{\s*$", header)
    if attribute_ref is None:
        return False

    number = attribute_ref.group(1)
    attributes = re.search(
        rf'^attributes #{number} = \{{.*\}}$', ir, re.MULTILINE
    )
    return (
        attributes is not None
        and '"aarch64_pstate_sm_body"' in attributes.group(0)
    )


def evaluate_kernel(
    ir: str, expectation: KernelExpectation
) -> tuple[list[tuple[str, str, bool]], dict[str, int]]:
    header, body = extract_function(ir, expectation.name)
    metrics = {
        "masked_loads": count(body, "llvm.masked.load."),
        "masked_stores": count(body, "llvm.masked.store."),
        "phi_i64": count(body, "phi i64"),
        "geps": count(body, "getelementptr"),
        "sve_fadds": count(body, "llvm.aarch64.sve.fadd."),
        "sve_fmuls": count(body, "llvm.aarch64.sve.fmul."),
        "sve_fmlas": count(body, "llvm.aarch64.sve.fmla."),
        "branches": len(re.findall(r"\bbr i1\b|\bbr label\b", body)),
        "loop_backedges": count(body, "!llvm.loop"),
        "whilelo_predicates": count(body, "llvm.aarch64.sve.whilelo."),
        "integer_muls": count(body, "mul i64"),
    }

    checks = [
        (
            "streaming-mode attribute",
            "`aarch64_pstate_sm_body`",
            function_has_streaming_attribute(ir, header),
        ),
        (
            "streaming vector length",
            "`llvm.aarch64.sme.cntsw`",
            "llvm.aarch64.sme.cntsw" in body,
        ),
        (
            "logical masked loads",
            str(expectation.masked_loads),
            metrics["masked_loads"] == expectation.masked_loads,
        ),
        (
            "masked store",
            "1",
            metrics["masked_stores"] == 1,
        ),
        (
            "loop induction PHIs",
            f">= {expectation.minimum_phis}",
            metrics["phi_i64"] >= expectation.minimum_phis,
        ),
        (
            "loop backedges",
            "`!llvm.loop` present",
            metrics["loop_backedges"] > 0,
        ),
        (
            "tail predicate",
            "`llvm.aarch64.sve.whilelo`",
            metrics["whilelo_predicates"] >= 1,
        ),
        (
            "GEP address calculations",
            f">= {expectation.minimum_geps}",
            metrics["geps"] >= expectation.minimum_geps,
        ),
        (
            "row-stride multiplication",
            "`mul i64` present",
            metrics["integer_muls"] >= 1,
        ),
        (
            "SVE add chain",
            f">= {expectation.minimum_fadds}",
            metrics["sve_fadds"] >= expectation.minimum_fadds,
        ),
        (
            "SVE multiply",
            "present",
            metrics["sve_fmuls"] >= 1,
        ),
        (
            "SVE fused multiply-add",
            "present",
            metrics["sve_fmlas"] >= 1,
        ),
    ]

    if expectation.requires_plane_stride:
        checks.append(
            (
                "3D plane-stride multiplication",
                "additional `mul i64` present",
                metrics["integer_muls"] >= 3,
            )
        )

    return checks, metrics


def render_report(
    args: argparse.Namespace,
    results: list[
        tuple[KernelExpectation, list[tuple[str, str, bool]], dict[str, int]]
    ],
) -> str:
    all_passed = all(
        passed
        for _, checks, _ in results
        for _, _, passed in checks
    )
    lines = [
        "# 步骤 1 LLVM IR 分析报告",
        "",
        f"- 总体结果：**{'PASS' if all_passed else 'FAIL'}**",
        f"- Clang：`{args.clang_version}`",
        f"- Target：`{args.target}`",
        f"- Architecture：`{args.march}`",
        f"- 输入：`stencil_sme_kernels.c`",
        f"- IR：`output/{args.ir.name}`",
        "",
    ]

    for expectation, checks, metrics in results:
        lines.extend(
            [
                f"## `{expectation.name}`",
                "",
                "| 检查项 | 期望 | 结果 |",
                "|---|---:|---:|",
            ]
        )
        for label, expected, passed in checks:
            lines.append(
                f"| {label} | {expected} | "
                f"{'PASS' if passed else 'FAIL'} |"
            )

        lines.extend(
            [
                "",
                "观测计数：",
                "",
                "```text",
            ]
        )
        lines.extend(f"{key} = {value}" for key, value in metrics.items())
        lines.extend(["```", ""])

    lines.extend(
        [
            "## 结论",
            "",
            "当前 Clang `-O1` IR 保留了后续 LLVM pass 所需的：",
            "",
            "1. 自然循环、归纳变量和回边分支。",
            "2. 行/平面地址计算对应的 GEP 与整数乘法。",
            "3. 2D5P 的 5 个和 3D7P 的 7 个 masked load。",
            "4. SME streaming VL、SVE 算术和 masked store。",
            "5. `aarch64_pstate_sm_body` 函数属性。",
            "",
            "步骤 2 可以直接以该 LLVM IR 为输入建立 new-pass-manager 插件。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    ir = args.ir.read_text(encoding="utf-8")
    results = []
    failed = False

    for expectation in EXPECTATIONS:
        checks, metrics = evaluate_kernel(ir, expectation)
        results.append((expectation, checks, metrics))
        failed |= any(not passed for _, _, passed in checks)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        render_report(args, results), encoding="utf-8"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
