#!/usr/bin/env python3
"""Step 5: build the unified step-4 result and keep one local validation artifact."""

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

    # 再保留一个“辅助验证工件”：
    # 它不代表另一条研究路线，只用于证明预取语义已经能下沉到本机可执行程序。
    prefetch_mlir = ROOT / "04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir"
    prefetch_ll = output / "03_llvm_prefetch.ll"
    prefetch_obj = output / "03_llvm_prefetch.o"
    prefetch_exe = output / "prefetch_demo"
    prefetch_log = output / "prefetch_demo.log"

    result = run(
        [str(MLIR_TRANSLATE), "--mlir-to-llvmir", str(prefetch_mlir), "-o", str(prefetch_ll)],
        ROOT,
    )
    if result.returncode != 0:
        write_text(output / "prefetch_translate.stderr", result.stderr)
        summary_lines.append("prefetch_aux_translate: failed")
    else:
        remove_if_exists(output / "prefetch_translate.stderr")
        summary_lines.append("prefetch_aux_translate: ok")
        result = run([str(LLC), str(prefetch_ll), "-filetype=obj", "-o", str(prefetch_obj)], ROOT)
        if result.returncode != 0:
            write_text(output / "prefetch_llc.stderr", result.stderr)
            summary_lines.append("prefetch_aux_object: failed")
        else:
            remove_if_exists(output / "prefetch_llc.stderr")
            summary_lines.append("prefetch_aux_object: ok")
            result = run(
                [str(CLANG), str(prefetch_obj), str(workdir / "prefetch_harness.c"), "-o", str(prefetch_exe)],
                ROOT,
            )
            if result.returncode != 0:
                write_text(output / "prefetch_link.stderr", result.stderr)
                summary_lines.append("prefetch_aux_link: failed")
            else:
                remove_if_exists(output / "prefetch_link.stderr")
                summary_lines.append("prefetch_aux_link: ok")
                result = run([str(prefetch_exe)], ROOT)
                write_text(prefetch_log, (result.stdout or "") + (result.stderr or ""))
                if result.returncode == 0:
                    summary_lines.append("prefetch_aux_run: ok")
                else:
                    summary_lines.append(f"prefetch_aux_run: failed ({result.returncode})")

    write_text(output / "summary.txt", "\n".join(summary_lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
