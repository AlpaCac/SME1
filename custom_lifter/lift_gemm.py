#!/usr/bin/env python3
"""Restricted C GEMM lifter: C kernel -> high-level MLIR.

This lifter is intentionally narrow:
1. It only accepts the annotated GEMM kernel used in this repository.
2. It recovers block sizes from structured comments.
3. It emits high-level MLIR with scf + memref + linalg, suitable for
   later vector/arm_sme research.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


FUNCTION_RE = re.compile(
    r"void\s+(?P<name>gemm_fp32_mlir_kernel)\s*\(\s*int\s+M\s*,\s*int\s+N\s*,\s*int\s+K\s*,",
    re.MULTILINE,
)


def extract_required_annotation(source: str, key: str) -> str:
    pattern = re.compile(rf"@{re.escape(key)}\s+(?P<value>.+)")
    match = pattern.search(source)
    if not match:
        raise ValueError(f"missing required annotation '@{key}'")
    return match.group("value").strip()


def extract_blocking(source: str) -> dict[str, int]:
    text = extract_required_annotation(source, "blocking")
    values: dict[str, int] = {}
    for item in text.split():
        if "=" not in item:
            continue
        name, value = item.split("=", 1)
        values[name.strip()] = int(value.strip())

    required = ("mc", "nc", "kc", "mr", "nr")
    missing = [name for name in required if name not in values]
    if missing:
        raise ValueError(
            "blocking annotation is incomplete, missing: " + ", ".join(missing)
        )
    return values


def validate_source(source: str) -> None:
    if not FUNCTION_RE.search(source):
        raise ValueError("only the restricted gemm_fp32_mlir_kernel signature is supported")
    semantic = extract_required_annotation(source, "semantic")
    if semantic != "C = A * B":
        raise ValueError("this research lifter only supports '@semantic C = A * B'")
    extract_required_annotation(source, "kernel")
    extract_required_annotation(source, "layout")
    extract_required_annotation(source, "lift-target")


def emit_mlir(kernel: str, semantic: str, layout: str, lift_target: str, blocking: dict[str, int]) -> str:
    mc = blocking["mc"]
    nc = blocking["nc"]
    kc = blocking["kc"]
    mr = blocking["mr"]
    nr = blocking["nr"]

    return f"""#tile_outer = affine_map<(d0, d1) -> ({mc}, d0 - d1)>
#tile_inner_m = affine_map<(d0, d1) -> ({mr}, d0 - d1)>
#tile_inner_n = affine_map<(d0, d1) -> ({nr}, d0 - d1)>

module {{
  func.func @gemm_fp32_lifted(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {{
    c_kernel = "{kernel}",
    semantic = "{semantic}",
    layout = "{layout}",
    lift_target = "{lift_target}"
  }} {{
    // 从输入 memref 中恢复矩阵维度，作为高层 MLIR 的动态边界。
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst_0 = arith.constant 0.0 : f32
    %mc0 = arith.constant {mc} : index
    %nc0 = arith.constant {nc} : index
    %kc0 = arith.constant {kc} : index
    %mr0 = arith.constant {mr} : index
    %nr0 = arith.constant {nr} : index

    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 这组 affine.min 保留了 C kernel 中的 mc/nc/kc/mr/nr 分块语义。
    scf.for %i = %c0 to %m step %mc0 {{
      %mc = affine.min #tile_outer(%m, %i)

      scf.for %j = %c0 to %n step %nc0 {{
        %nc = affine.min #tile_outer(%n, %j)

        scf.for %ko = %c0 to %k step %kc0 {{
          %kc = affine.min #tile_outer(%k, %ko)

          %a_tile = memref.subview %a[%i, %ko] [%mc, %kc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %b_tile = memref.subview %b[%ko, %j] [%kc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %c_tile = memref.subview %c[%i, %j] [%mc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>

          // 外层大块内部继续切分为 mr x nr 微块。
          scf.for %ii = %c0 to %mc step %mr0 {{
            %mr = affine.min #tile_inner_m(%mc, %ii)

            scf.for %jj = %c0 to %nc step %nr0 {{
              %nr = affine.min #tile_inner_n(%nc, %jj)

              %a_block = memref.subview %a_tile[%ii, %c0] [%mr, %kc] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
              %b_block = memref.subview %b_tile[%c0, %jj] [%kc, %nr] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
              %c_block = memref.subview %c_tile[%ii, %jj] [%mr, %nr] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>

              // 当前研究版只保留 C = A * B，因此每个输出块先清零再做 matmul。
              linalg.fill ins(%cst_0 : f32)
                          outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)

              // 这里显式恢复矩阵乘高层语义，后续可以继续进入 vector/arm_sme。
              linalg.matmul
                ins(%a_block, %b_block : memref<?x?xf32, strided<[?, ?], offset: ?>>,
                                         memref<?x?xf32, strided<[?, ?], offset: ?>>)
                outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)
            }}
          }}
        }}
      }}
    }}

    return
  }}
}}
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Lift the repository GEMM C kernel into high-level MLIR."
    )
    parser.add_argument("input", type=pathlib.Path, help="path to the restricted C kernel")
    parser.add_argument(
        "-o",
        "--output",
        type=pathlib.Path,
        required=True,
        help="path to the generated MLIR file",
    )
    args = parser.parse_args()

    source = args.input.read_text(encoding="utf-8")
    validate_source(source)

    kernel = extract_required_annotation(source, "kernel")
    semantic = extract_required_annotation(source, "semantic")
    layout = extract_required_annotation(source, "layout")
    lift_target = extract_required_annotation(source, "lift-target")
    blocking = extract_blocking(source)

    mlir = emit_mlir(kernel, semantic, layout, lift_target, blocking)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(mlir, encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
