#!/usr/bin/env python3
"""Step 5: build and run the unified step-4 result locally."""

from __future__ import annotations

import pathlib
import subprocess


ROOT = pathlib.Path("/Users/alpaca/Documents/SME/SME1")
MLIR_TRANSLATE = pathlib.Path("/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-translate")
LLC = pathlib.Path("/Users/alpaca/Documents/SME/external/llvm-project/build/bin/llc")
CLANG = pathlib.Path("/usr/bin/clang")


def run(cmd: list[str], cwd: pathlib.Path, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        check=False,
        text=True,
        capture_output=capture,
    )


def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def remove_if_exists(path: pathlib.Path) -> None:
    if path.exists():
        path.unlink()


def main() -> int:
    workdir = ROOT / "05_native_build_run"
    output = workdir / "output"
    output.mkdir(parents=True, exist_ok=True)

    summary_lines: list[str] = []

    # 先尝试统一主线最终产物；这是第五步真正关心的对象。
    unified_mlir = ROOT / "04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir"
    unified_ll = output / "09_unified_llvm_prefetch.ll"
    unified_obj = output / "09_unified_llvm_prefetch.o"
    unified_exe = output / "unified_demo"
    unified_log = output / "unified_demo.log"

    result = run(
        [str(MLIR_TRANSLATE), "--mlir-to-llvmir", str(unified_mlir), "-o", str(unified_ll)],
        ROOT,
    )
    if result.returncode != 0:
        write_text(output / "unified_translate.stderr", result.stderr)
        summary_lines.append("unified_mainline_translate: failed")
    else:
        remove_if_exists(output / "unified_translate.stderr")
        summary_lines.append("unified_mainline_translate: ok")
        result = run(
            [str(LLC), "-mattr=+sme", str(unified_ll), "-filetype=obj", "-o", str(unified_obj)],
            ROOT,
        )
        if result.returncode != 0:
            write_text(output / "unified_llc.stderr", result.stderr)
            summary_lines.append("unified_mainline_object: failed")
        else:
            remove_if_exists(output / "unified_llc.stderr")
            summary_lines.append("unified_mainline_object: ok")
            result = run(
                [
                    str(CLANG),
                    str(unified_obj),
                    str(workdir / "unified_wrapper.c"),
                    str(workdir / "unified_harness.c"),
                    "-o",
                    str(unified_exe),
                ],
                ROOT,
            )
            if result.returncode != 0:
                write_text(output / "unified_link.stderr", result.stderr)
                summary_lines.append("unified_mainline_link: failed")
            else:
                remove_if_exists(output / "unified_link.stderr")
                summary_lines.append("unified_mainline_link: ok")
                result = run([str(unified_exe)], ROOT)
                write_text(unified_log, (result.stdout or "") + (result.stderr or ""))
                if result.returncode == 0:
                    summary_lines.append("unified_mainline_run: ok")
                else:
                    summary_lines.append(
                        f"unified_mainline_run: failed ({result.returncode})"
                    )

    write_text(output / "summary.txt", "\n".join(summary_lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
