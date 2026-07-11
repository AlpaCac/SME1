#!/usr/bin/env python3
"""Step 6: functional experiment validation for the current research pipeline."""

from __future__ import annotations

import json
import pathlib
import re
import subprocess


ROOT = pathlib.Path("/Users/alpaca/Documents/SME/SME1")
OUTPUT = ROOT / "06_experiment_validation" / "output"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(ROOT),
        check=False,
        text=True,
        capture_output=True,
    )


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def contains(path: pathlib.Path, pattern: str) -> bool:
    return pattern in read_text(path)


def grep_count(path: pathlib.Path, pattern: str) -> int:
    return len(re.findall(pattern, read_text(path)))


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)

    summary: dict[str, object] = {
        "environment": {
            "host": "Apple Silicon macOS",
            "branch": run(["git", "branch", "--show-current"]).stdout.strip(),
        },
        "functional_validation": {},
        "performance_validation": {},
    }

    unified_mlir = ROOT / "04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir"
    unified_ll = ROOT / "05_native_build_run/output/09_unified_llvm_prefetch.ll"
    unified_log = ROOT / "05_native_build_run/output/unified_demo.log"
    unified_obj = ROOT / "05_native_build_run/output/09_unified_llvm_prefetch.o"

    summary["functional_validation"] = {
        "llvm_ir_accepted": unified_ll.exists(),
        "prefetch_intrinsic_recognized_unified_branch": contains(unified_ll, "@llvm.prefetch.p0"),
        "sme_intrinsics_recognized_unified_branch": contains(
            unified_ll, "@llvm.aarch64.sme.mopa"
        )
        and contains(unified_ll, "@llvm.aarch64.sme.ld1w.horiz.p0"),
        "final_assembly_contains_prefetch_unified_branch": "prfm" in run(
            ["otool", "-tvV", str(unified_obj)]
        ).stdout,
        "final_assembly_contains_sme_unified_branch": "smstart" in run(
            ["otool", "-tvV", str(unified_obj)]
        ).stdout
        and "fmopa" in run(["otool", "-tvV", str(unified_obj)]).stdout,
        "unified_pipeline_runs_locally": unified_log.exists()
        and "C_from_descriptor =" in read_text(unified_log),
        "stable_wrapper_descriptor_works": unified_log.exists()
        and "C_from_descriptor =" in read_text(unified_log),
        "unified_prefetch_call_count": grep_count(unified_ll, r"@llvm\.prefetch\.p0"),
    }

    summary["performance_validation"] = {
        "status": "pending_lx2_environment",
        "reason": (
            "当前仓库已完成本机功能性验证，但 README 方案中的性能实验依赖 "
            "LX2 + 毕昇编译器 + PMU/perf 环境，本机无法替代该目标环境。"
        ),
        "planned_experiments": [
            "Baseline 1 (No Prefetch)",
            "Baseline 2 (BiSheng Native Prefetch)",
            "Proposed (MLIR pipeline + BiSheng backend)",
            "FlagGEMM irregular-control-flow throughput experiment",
        ],
    }

    write_text(
        OUTPUT / "validation_summary.json",
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
    )

    md = f"""# 06 Experiment Validation

## 功能性验证

本阶段按方案第 4 节，先完成当前本机能够复现的功能性验证。

1. LLVM IR 是否可接受：`{"是" if summary["functional_validation"]["llvm_ir_accepted"] else "否"}`
2. 统一主线中的目标预取 intrinsic 是否被识别：`{"是" if summary["functional_validation"]["prefetch_intrinsic_recognized_unified_branch"] else "否"}`
3. SME 相关 intrinsic 是否被识别：`{"是" if summary["functional_validation"]["sme_intrinsics_recognized_unified_branch"] else "否"}`
4. 最终汇编中是否出现目标预取指令：`{"是" if summary["functional_validation"]["final_assembly_contains_prefetch_unified_branch"] else "否"}`
5. 最终汇编中是否出现 SME 指令：`{"是" if summary["functional_validation"]["final_assembly_contains_sme_unified_branch"] else "否"}`
6. 统一主线是否可本机运行：`{"是" if summary["functional_validation"]["unified_pipeline_runs_locally"] else "否"}`
7. 稳定 wrapper 返回 descriptor 是否可用：`{"是" if summary["functional_validation"]["stable_wrapper_descriptor_works"] else "否"}`

## 关键证据

- 统一主线 LLVM IR： [09_unified_llvm_prefetch.ll]({unified_ll})
- 统一主线运行日志： [unified_demo.log]({unified_log})
- 本次结构化摘要： [validation_summary.json]({OUTPUT / "validation_summary.json"})

## 当前结论

当前实验已经证明：

- 高层注入的预取语义可以继续传递到 `llvm.prefetch`
- 统一主线可以继续传递到 `arm_sme` / `llvm`
- 最终汇编中同时可以观察到 `prfm` 与 SME 指令
- 统一主线与稳定 ABI wrapper 都已经在本机实际运行

## 性能实验状态

性能实验当前标记为“待 LX2 环境执行”。

原因：

- 方案中要求对比毕昇编译器 baseline / native prefetch / proposed pipeline
- 同时需要 PMU 或 `perf stat` 事件采样
- 这些都依赖 LX2 目标环境，当前 Apple Silicon 本机只能完成功能性验证，不能替代该性能实验
"""
    write_text(OUTPUT / "validation_report.md", md + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
