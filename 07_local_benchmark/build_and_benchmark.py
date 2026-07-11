#!/usr/bin/env python3
"""Step 7: local benchmark comparison on the current machine."""

from __future__ import annotations

import json
import pathlib
import re
import subprocess


ROOT = pathlib.Path("/Users/alpaca/Documents/SME/SME1")
LLVM_BIN = pathlib.Path("/Users/alpaca/Documents/SME/external/llvm-project/build/bin")
MLIR_TRANSLATE = LLVM_BIN / "mlir-translate"
LLC = LLVM_BIN / "llc"
CLANG = pathlib.Path("/usr/bin/clang")
OUT = ROOT / "07_local_benchmark" / "output"


def run(cmd: list[str], cwd: pathlib.Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd or ROOT),
        check=False,
        text=True,
        capture_output=True,
    )


def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def remove_prefetch_calls(src: pathlib.Path, dst: pathlib.Path) -> None:
    lines = src.read_text(encoding="utf-8").splitlines()
    filtered = [line for line in lines if "@llvm.prefetch.p0" not in line]
    dst.write_text("\n".join(filtered) + "\n", encoding="utf-8")


def parse_metrics(text: str) -> dict[str, float]:
    metrics: dict[str, float] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.strip().split("=", 1)
        metrics[key] = float(value)
    return metrics


def bench_case(exe: pathlib.Path, m: int, n: int, k: int, iters: int) -> dict[str, float]:
    result = run([str(exe), str(m), str(n), str(k), str(iters)])
    if result.returncode != 0:
        raise RuntimeError(f"{exe.name} failed: {result.stderr}")
    metrics = parse_metrics(result.stdout)
    elapsed = metrics["elapsed_sec"]
    metrics["gflops"] = (2.0 * m * n * k * iters) / elapsed / 1e9
    return metrics


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    affine_prefetch_mlir = ROOT / "04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir"
    affine_prefetch_ll = OUT / "03_llvm_prefetch.ll"
    unified_prefetch_mlir = ROOT / "04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir"
    unified_prefetch_ll = OUT / "09_unified_llvm_prefetch.ll"

    result = run(
        [str(MLIR_TRANSLATE), "--mlir-to-llvmir", str(affine_prefetch_mlir), "-o", str(affine_prefetch_ll)]
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    result = run(
        [str(MLIR_TRANSLATE), "--mlir-to-llvmir", str(unified_prefetch_mlir), "-o", str(unified_prefetch_ll)]
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)

    affine_nopf_ll = OUT / "03_llvm_no_prefetch.ll"
    unified_nopf_ll = OUT / "09_unified_no_prefetch.ll"
    remove_prefetch_calls(affine_prefetch_ll, affine_nopf_ll)
    remove_prefetch_calls(unified_prefetch_ll, unified_nopf_ll)

    affine_prefetch_obj = OUT / "affine_prefetch.o"
    affine_nopf_obj = OUT / "affine_no_prefetch.o"
    unified_prefetch_obj = OUT / "unified_prefetch.o"
    unified_nopf_obj = OUT / "unified_no_prefetch.o"
    baseline_obj = OUT / "c_baseline.o"

    for src, obj, extra in [
        (affine_prefetch_ll, affine_prefetch_obj, []),
        (affine_nopf_ll, affine_nopf_obj, []),
        (unified_prefetch_ll, unified_prefetch_obj, ["-mattr=+sme"]),
        (unified_nopf_ll, unified_nopf_obj, ["-mattr=+sme"]),
    ]:
        result = run([str(LLC), *extra, str(src), "-filetype=obj", "-o", str(obj)])
        if result.returncode != 0:
            raise RuntimeError(result.stderr)

    result = run(
        [str(CLANG), "-O3", "-c", str(ROOT / "gemm_mlir_kernel.c"), "-o", str(baseline_obj)]
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)

    exe_specs = {
        "c_baseline": [baseline_obj, ROOT / "07_local_benchmark/c_baseline_benchmark.c"],
        "affine_no_prefetch": [affine_nopf_obj, ROOT / "07_local_benchmark/affine_benchmark.c"],
        "affine_prefetch": [affine_prefetch_obj, ROOT / "07_local_benchmark/affine_benchmark.c"],
        "unified_no_prefetch": [
            unified_nopf_obj,
            ROOT / "05_native_build_run/unified_wrapper.c",
            ROOT / "07_local_benchmark/unified_benchmark.c",
        ],
        "unified_prefetch": [
            unified_prefetch_obj,
            ROOT / "05_native_build_run/unified_wrapper.c",
            ROOT / "07_local_benchmark/unified_benchmark.c",
        ],
    }

    executables: dict[str, pathlib.Path] = {}
    for name, sources in exe_specs.items():
        exe = OUT / name
        result = run([str(CLANG), *[str(x) for x in sources], "-o", str(exe)])
        if result.returncode != 0:
            raise RuntimeError(f"{name} link failed: {result.stderr}")
        executables[name] = exe

    # 这里刻意只选 K <= 128 的 case。
    # 当前研究版 C kernel / affine kernel 会在每个 kc 块开始时重新清零输出块，
    # 因而在 K > 128 时保留的是“最后一个 kc 块”的结果，而 unified 主线保持的是
    # 完整 matmul 语义。为了让本地对比聚焦在 lowering / prefetch 本身，而不是语义差异，
    # 这里先使用语义一致的规模。
    cases = [
        {"m": 128, "n": 128, "k": 128, "iters": 10},
        {"m": 256, "n": 256, "k": 128, "iters": 3},
    ]
    results: dict[str, object] = {"cases": []}

    for case in cases:
        case_result = {"config": case, "variants": {}}
        checksums: dict[str, float] = {}
        for name, exe in executables.items():
            metrics = bench_case(exe, case["m"], case["n"], case["k"], case["iters"])
            case_result["variants"][name] = metrics
            if "checksum" in metrics:
                checksums[name] = metrics["checksum"]
            if "checksum_c" in metrics:
                checksums[name] = metrics["checksum_c"]
        case_result["checksum_reference"] = checksums
        case_result["comparisons"] = {
            "affine_prefetch_speedup_vs_no_prefetch": (
                case_result["variants"]["affine_no_prefetch"]["avg_ms"]
                / case_result["variants"]["affine_prefetch"]["avg_ms"]
            ),
            "unified_prefetch_speedup_vs_no_prefetch": (
                case_result["variants"]["unified_no_prefetch"]["avg_ms"]
                / case_result["variants"]["unified_prefetch"]["avg_ms"]
            ),
            "unified_prefetch_speedup_vs_c_baseline": (
                case_result["variants"]["c_baseline"]["avg_ms"]
                / case_result["variants"]["unified_prefetch"]["avg_ms"]
            ),
        }
        results["cases"].append(case_result)

    write_text(OUT / "benchmark_results.json", json.dumps(results, ensure_ascii=False, indent=2) + "\n")

    lines = [
        "# 07 Local Benchmark",
        "",
        "## 说明",
        "",
        "- 当前本地对比只选择 `K <= 128` 的 case，用来保证 `c_baseline` / `affine` / `unified` 三组语义一致。",
        "- 若直接使用 `K > 128`，当前研究版 `gemm_mlir_kernel.c` 及其 affine 路线会体现为“按 kc 分块覆盖写回”的语义，而 unified 主线保留的是完整 `linalg.matmul` 语义，因此不能直接拿来做性能结论。",
        "",
        "## 配置",
        "",
    ]
    for case in results["cases"]:
        cfg = case["config"]
        lines.append(f"### M={cfg['m']} N={cfg['n']} K={cfg['k']} iterations={cfg['iters']}")
        lines.append("")
        for name, metrics in case["variants"].items():
            checksum = metrics.get("checksum", metrics.get("checksum_c"))
            lines.append(
                f"- `{name}`: avg_ms={metrics['avg_ms']:.6f}, gflops={metrics['gflops']:.3f}, checksum={checksum:.9f}"
            )
        lines.append(
            f"- `affine_prefetch / affine_no_prefetch` speedup={case['comparisons']['affine_prefetch_speedup_vs_no_prefetch']:.4f}"
        )
        lines.append(
            f"- `unified_prefetch / unified_no_prefetch` speedup={case['comparisons']['unified_prefetch_speedup_vs_no_prefetch']:.4f}"
        )
        lines.append(
            f"- `unified_prefetch / c_baseline` speedup={case['comparisons']['unified_prefetch_speedup_vs_c_baseline']:.4f}"
        )
        lines.append("")

    write_text(OUT / "benchmark_report.md", "\n".join(lines).strip() + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
