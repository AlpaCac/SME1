#!/usr/bin/env python3
"""Step 5: translate, assemble, link, and run the step-4 LLVM output."""

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

    # 第五步从第四步最终 MLIR 产物继续生成 LLVM IR、汇编、目标文件和可执行文件。
    unified_mlir = ROOT / "04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir"
    unified_ll = output / "step4_llvm_prefetch.ll"
    unified_asm = output / "step4_llvm_prefetch.s"
    unified_obj = output / "step4_llvm_prefetch.o"
    unified_exe = output / "step4_llvm_prefetch_demo"
    unified_log = output / "step4_llvm_prefetch_demo.log"

    for stale_path in [
        unified_ll,
        unified_asm,
        unified_obj,
        unified_exe,
        unified_log,
        output / "unified_translate.stderr",
        output / "unified_asm.stderr",
        output / "unified_obj.stderr",
        output / "unified_link.stderr",
        output / "unified_run.stderr",
    ]:
        remove_if_exists(stale_path)

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
            [
                str(LLC),
                "-mattr=+sme",
                str(unified_ll),
                "-filetype=asm",
                "-o",
                str(unified_asm),
            ],
            ROOT,
        )
        if result.returncode != 0:
            write_text(output / "unified_asm.stderr", result.stderr)
            summary_lines.append("unified_mainline_asm: failed")
        else:
            summary_lines.append("unified_mainline_asm: ok")
            result = run(
                [
                    str(LLC),
                    "-mattr=+sme",
                    str(unified_ll),
                    "-filetype=obj",
                    "-o",
                    str(unified_obj),
                ],
                ROOT,
            )
            if result.returncode != 0:
                write_text(output / "unified_obj.stderr", result.stderr)
                summary_lines.append("unified_mainline_object: failed")
            else:
                summary_lines.append("unified_mainline_object: ok")
                result = run(
                    [
                        str(CLANG),
                        str(unified_obj),
                        str(workdir / "native_harness.c"),
                        "-o",
                        str(unified_exe),
                    ],
                    ROOT,
                )
                if result.returncode != 0:
                    write_text(output / "unified_link.stderr", result.stderr)
                    summary_lines.append("unified_mainline_link: failed")
                else:
                    summary_lines.append("unified_mainline_link: ok")
                    result = run([str(unified_exe)], ROOT)
                    write_text(unified_log, (result.stdout or "") + (result.stderr or ""))
                    if result.returncode != 0:
                        write_text(output / "unified_run.stderr", result.stderr)
                        summary_lines.append(
                            f"unified_mainline_run: failed ({result.returncode})"
                        )
                    else:
                        summary_lines.append("unified_mainline_run: ok")

    write_text(output / "summary.txt", "\n".join(summary_lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
