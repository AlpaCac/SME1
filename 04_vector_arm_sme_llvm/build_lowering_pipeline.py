#!/usr/bin/env python3
"""Step 4: lower the prefetch-annotated high-level MLIR toward vector/ArmSME/LLVM."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import tempfile


MLIR_OPT = pathlib.Path("/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt")


def locality_to_hint(locality: str) -> int:
    return 3 if locality.upper() == "KEEP" else 0


def bridge_research_prefetch_to_affine(source: str) -> str:
    source = source.replace("研究版 `research.prefetch`", "桥接后的标准 `affine.prefetch`")
    source = source.replace("暂时不是 LLVM 官方方言 op", "它已经是 MLIR 标准 Affine 方言中的预取 op")
    source = source.replace(
        '"research.prefetch"(%b, %ko, %j, %jj, %kk) <{\n'
        '                        target = "B", kind = "read", priority = "high",\n'
        '                        cache = "L1", locality = "KEEP",\n'
        '                        distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"\n'
        '                      }> : (memref<?x?xf32>, index, index, index, index) -> ()',
        f"affine.prefetch %b[%ko + %kk, %j + %jj], read, locality<{locality_to_hint('KEEP')}>, data : memref<?x?xf32>",
    )
    source = source.replace(
        '"research.prefetch"(%a, %i, %ii, %ko, %kk) <{\n'
        '                        target = "A", kind = "read", priority = "medium",\n'
        '                        cache = "L1", locality = "KEEP",\n'
        '                        distance = "按未来 1 到 2 个 kk-cache-line"\n'
        '                      }> : (memref<?x?xf32>, index, index, index, index) -> ()',
        f"affine.prefetch %a[%i + %ii, %ko + %kk], read, locality<{locality_to_hint('KEEP')}>, data : memref<?x?xf32>",
    )
    return source


def inject_memref_prefetch_into_vector(text: str) -> str:
    old = """          %subview_7 = memref.subview %subview_5[0, 0] [%1, 1] [1, 1] : memref<?x1xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          %7 = vector.transfer_read %subview_7[%c0], %0, %2 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
          %subview_8 = memref.subview %subview_6[0, 0] [1, %3] [1, 1] : memref<1x?xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          %8 = vector.transfer_read %subview_8[%c0], %0, %4 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
"""
    new = """          %subview_7 = memref.subview %subview_5[0, 0] [%1, 1] [1, 1] : memref<?x1xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          // 从第三步的预取决策继续向下传递：A 在当前 kk 推进前做读预取。
          memref.prefetch %subview_7[%c0], read, locality<3>, data : memref<?xf32, #map1>
          %7 = vector.transfer_read %subview_7[%c0], %0, %2 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
          %subview_8 = memref.subview %subview_6[0, 0] [1, %3] [1, 1] : memref<1x?xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          // B 仍然是更高优先级的读流，因此同样在 transfer_read 之前发出预取。
          memref.prefetch %subview_8[%c0], read, locality<3>, data : memref<?xf32, #map1>
          %8 = vector.transfer_read %subview_8[%c0], %0, %4 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
"""
    if old not in text:
        raise ValueError("failed to locate vector-stage prefetch injection point")
    return text.replace(old, new, 1)


def repair_arm_sve_index_bridges(text: str) -> str:
    """Replace i64 -> index -> i32 bridge leftovers with direct LLVM truncation.

    After re-running `convert-vector-to-llvm=enable-arm-sve`, the remaining
    unsupported fragments have the shape:

      %x = builtin.unrealized_conversion_cast %src : i64 to index
      ...
      %y = arith.index_cast %x : index to i32

    For the current SME mask-slice pattern, this is equivalent to:

      %y = llvm.trunc %src : i64 to i32
    """

    lines = text.splitlines()
    pending_i64_to_index: dict[str, str] = {}
    output: list[str] = []

    for line in lines:
        cast_match = re.match(
            r"(\s*)(%\d+) = builtin\.unrealized_conversion_cast (%\d+) : i64 to index$",
            line,
        )
        if cast_match:
            pending_i64_to_index[cast_match.group(2)] = cast_match.group(3)
            continue

        index_cast_match = re.match(
            r"(\s*)(%\d+) = arith\.index_cast (%\d+) : index to i32$",
            line,
        )
        if index_cast_match and index_cast_match.group(3) in pending_i64_to_index:
            indent, dst, bridge = (
                index_cast_match.group(1),
                index_cast_match.group(2),
                index_cast_match.group(3),
            )
            output.append(
                f"{indent}{dst} = llvm.trunc {pending_i64_to_index[bridge]} : i64 to i32"
            )
            continue

        output.append(line)

    return "\n".join(output) + "\n"


def build_compute_input_mlir(tile_m: int, tile_n: int) -> str:
    return f"""// ============================================================================
// 自动生成文件：gemm_step4_compute_mainline.mlir
// 目标：保留第四步中的计算主 lowering 线，用于观察 vector -> arm_sme -> llvm
// ============================================================================
func.func @gemm_step4_compute(%A : tensor<?x?xf32>,
                              %B : tensor<?x?xf32>,
                              %C : tensor<?x?xf32>) -> tensor<?x?xf32> {{
  %res = linalg.matmul ins(%A, %B : tensor<?x?xf32>, tensor<?x?xf32>)
                       outs(%C : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %res : tensor<?x?xf32>
}}

module attributes {{transform.with_named_sequence}} {{
  transform.named_sequence @__transform_main(%module : !transform.any_op {{transform.consumed}}) {{
    %matmul = transform.structured.match ops{{["linalg.matmul"]}} in %module
      : (!transform.any_op) -> !transform.any_op
    %tiled_op, %loops:3 = transform.structured.tile_using_for %matmul tile_sizes [[{tile_m}], [{tile_n}], 1]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op, !transform.any_op)
    transform.structured.vectorize %tiled_op vector_sizes [[{tile_m}], [{tile_n}], 1]
      : !transform.any_op
    %bufferized = transform.bufferization.one_shot_bufferize %module
      {{bufferize_function_boundaries=true}} : (!transform.any_op) -> !transform.any_op
    %func = transform.structured.match ops{{["func.func"]}} in %bufferized
      : (!transform.any_op) -> !transform.any_op
    transform.apply_patterns to %func {{
      transform.apply_patterns.vector.lower_masked_transfers
      transform.apply_patterns.vector.transfer_permutation_patterns
      transform.apply_patterns.vector.reduction_to_contract
      transform.apply_patterns.vector.sink_ops
    }} : !transform.any_op
    transform.apply_patterns to %func {{
      transform.apply_patterns.vector.lower_contraction lowering_strategy = "outerproduct"
      transform.apply_patterns.vector.lower_masks
      transform.apply_patterns.vector.rank_reducing_subview_patterns
      transform.apply_patterns.canonicalization
    }} : !transform.any_op
    %all_loops = transform.structured.match interface{{LoopLikeInterface}} in %bufferized
      : (!transform.any_op) -> !transform.any_op
    transform.apply_licm to %all_loops : !transform.any_op
    transform.loop.hoist_loop_invariant_subsets %all_loops : !transform.any_op
    transform.yield
  }}
}}
"""


def run_pipeline(input_path: pathlib.Path, output_path: pathlib.Path, passes: list[str]) -> None:
    cmd = [str(MLIR_OPT), str(input_path), *passes]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    output_path.write_text(result.stdout, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build step-4 prefetch-preserving and compute-lowering artifacts."
    )
    parser.add_argument(
        "--analysis",
        type=pathlib.Path,
        default=pathlib.Path("02_prefetch_cost_model/output/prefetch_analysis.json"),
    )
    parser.add_argument(
        "--prefetch-input",
        type=pathlib.Path,
        default=pathlib.Path("03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir"),
    )
    parser.add_argument(
        "--workdir",
        type=pathlib.Path,
        default=pathlib.Path("04_vector_arm_sme_llvm"),
    )
    args = parser.parse_args()

    analysis = json.loads(args.analysis.read_text(encoding="utf-8"))
    cfg = analysis["tile_config"]
    prefetch_input_text = args.prefetch_input.read_text(encoding="utf-8")

    output_dir = args.workdir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="step4_", dir=str(args.workdir)) as temp_dir_str:
        temp_dir = pathlib.Path(temp_dir_str)

        # 先把第三步中的预取语义桥接到标准 MLIR prefetch op，确保语义可以继续下沉。
        affine_prefetch_std = output_dir / "01_affine_prefetch_std.mlir"
        affine_prefetch_std.write_text(
            bridge_research_prefetch_to_affine(prefetch_input_text),
            encoding="utf-8",
        )

        memref_prefetch_tmp = temp_dir / "02_memref_prefetch.mlir"
        run_pipeline(
            affine_prefetch_std,
            memref_prefetch_tmp,
            ["-lower-affine", "-canonicalize", "-cse"],
        )
        run_pipeline(
            memref_prefetch_tmp,
            output_dir / "03_llvm_prefetch.mlir",
            [
                "-convert-scf-to-cf",
                "-expand-strided-metadata",
                "-finalize-memref-to-llvm",
                "-convert-arith-to-llvm",
                "-convert-func-to-llvm",
                "-convert-cf-to-llvm",
                "-reconcile-unrealized-casts",
            ],
        )

        # 再构造官方计算 lowering 主线，并把预取决策重新注入这条主线，形成统一产物。
        compute_input = temp_dir / "gemm_step4_compute_mainline.mlir"
        compute_input.write_text(
            build_compute_input_mlir(cfg["mr"], cfg["nr"]),
            encoding="utf-8",
        )
        common = ["-transform-interpreter", "-test-transform-dialect-erase-schedule"]
        compute_vector_tmp = temp_dir / "04_compute_vector.mlir"
        run_pipeline(compute_input, compute_vector_tmp, common)

        unified_vector = output_dir / "07_unified_vector_prefetch.mlir"
        unified_vector.write_text(
            inject_memref_prefetch_into_vector(
                compute_vector_tmp.read_text(encoding="utf-8")
            ),
            encoding="utf-8",
        )
        run_pipeline(
            unified_vector,
            output_dir / "08_unified_arm_sme_prefetch.mlir",
            ["-test-lower-to-arm-sme"],
        )
        pre_legalize_tmp = temp_dir / "09_unified_llvm_prefetch_pre_legalize.mlir"
        run_pipeline(
            unified_vector,
            pre_legalize_tmp,
            ["-test-lower-to-arm-sme", "-test-lower-to-llvm"],
        )
        legalized_tmp = temp_dir / "09_unified_llvm_prefetch_legalized.mlir"
        run_pipeline(
            pre_legalize_tmp,
            legalized_tmp,
            ["-convert-vector-to-llvm=enable-arm-sve", "-reconcile-unrealized-casts"],
        )
        (output_dir / "09_unified_llvm_prefetch.mlir").write_text(
            repair_arm_sve_index_bridges(
                legalized_tmp.read_text(encoding="utf-8")
            ),
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
