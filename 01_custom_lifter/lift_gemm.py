#!/usr/bin/env python3
"""Restricted GEMM lifter: Clang AST + annotations -> high-level MLIR files."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass


DEFAULT_CLANG = "clang"


@dataclass
class KernelAstSummary:
    function_name: str
    return_type: str
    parameters: list[tuple[str, str]]
    for_count: int
    array_subscript_count: int
    compound_assign_count: int
    binary_operator_count: int


def walk_ast(node: dict):
    yield node
    for child in node.get("inner", []):
        if isinstance(child, dict):
            yield from walk_ast(child)


def find_declared_functions(ast: dict) -> list[dict]:
    functions: list[dict] = []
    for node in walk_ast(ast):
        if node.get("kind") != "FunctionDecl":
            continue
        if node.get("isImplicit"):
            continue
        if not any(child.get("kind") == "CompoundStmt" for child in node.get("inner", [])):
            continue
        functions.append(node)
    return functions


def run_clang_ast_dump(
    input_path: pathlib.Path, clang: str, clang_args: list[str]
) -> dict:
    cmd = [
        clang,
        *clang_args,
        "-Xclang",
        "-ast-dump=json",
        "-fsyntax-only",
        str(input_path),
    ]
    result = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise ValueError("clang AST dump failed:\n" + result.stderr.strip())
    return json.loads(result.stdout)


def summarize_kernel_ast(ast: dict, expected_function: str | None = None) -> KernelAstSummary:
    functions = find_declared_functions(ast)
    if expected_function:
        functions = [item for item in functions if item.get("name") == expected_function]
    if not functions:
        if expected_function:
            raise ValueError(f"failed to locate function '{expected_function}' in Clang AST")
        raise ValueError("failed to locate a C function body in Clang AST")
    if len(functions) > 1:
        names = ", ".join(function.get("name", "<unnamed>") for function in functions)
        raise ValueError(
            "multiple function bodies found; pass --function to select one: " + names
        )

    function = functions[0]
    parameters = [
        (
            child.get("name", ""),
            child.get("type", {}).get("qualType", ""),
        )
        for child in function.get("inner", [])
        if child.get("kind") == "ParmVarDecl"
    ]
    body_nodes = list(walk_ast(function))
    return KernelAstSummary(
        function_name=function.get("name", ""),
        return_type=function.get("type", {}).get("qualType", "").split("(", 1)[0].strip(),
        parameters=parameters,
        for_count=sum(1 for node in body_nodes if node.get("kind") == "ForStmt"),
        array_subscript_count=sum(
            1 for node in body_nodes if node.get("kind") == "ArraySubscriptExpr"
        ),
        compound_assign_count=sum(
            1 for node in body_nodes if node.get("kind") == "CompoundAssignOperator"
        ),
        binary_operator_count=sum(
            1 for node in body_nodes if node.get("kind") == "BinaryOperator"
        ),
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


def validate_kernel_ast(summary: KernelAstSummary) -> None:
    if summary.return_type != "void":
        raise ValueError("only void C kernel functions are supported")
    if len(summary.parameters) != 9:
        raise ValueError(
            "expected 9 GEMM parameters: M, N, K, A, lda, B, ldb, C, ldc"
        )
    parameter_types = [item[1] for item in summary.parameters]
    expected_fragments = [
        "int",
        "int",
        "int",
        "float *",
        "int",
        "float *",
        "int",
        "float *",
        "int",
    ]
    for index, (actual, expected) in enumerate(zip(parameter_types, expected_fragments)):
        if expected not in actual:
            raise ValueError(
                f"parameter {index + 1} has unsupported type '{actual}', expected {expected}"
            )
    if summary.for_count < 6:
        raise ValueError("expected a blocked GEMM kernel with at least 6 for-loops")
    if summary.array_subscript_count < 3:
        raise ValueError("expected array subscripts for A/B/C or local accumulator")
    if summary.compound_assign_count < 1:
        raise ValueError("expected at least one compound assignment for reduction")


def validate_source_annotations(source: str) -> None:
    semantic = extract_required_annotation(source, "semantic")
    if semantic != "C = A * B":
        raise ValueError("this research lifter only supports '@semantic C = A * B'")
    extract_required_annotation(source, "kernel")
    extract_required_annotation(source, "layout")
    extract_required_annotation(source, "lift-target")


def emit_linalg_mlir(
    kernel: str,
    semantic: str,
    layout: str,
    lift_target: str,
    blocking: dict[str, int],
) -> str:
    mc = blocking["mc"]
    nc = blocking["nc"]
    kc = blocking["kc"]
    mr = blocking["mr"]
    nr = blocking["nr"]

    return f"""// ============================================================================ 
// 自动生成文件：gemm_fp32_linalg.mlir
// 来源：gemm_mlir_kernel.c
// 目标：保留 GEMM 的高层算子语义，作为后续 vector / arm_sme lowering 的输入
//
// 阅读建议：
// 1. 先看外层 scf.for，它们对应 C kernel 中的 mc / nc / kc 分块。
// 2. 再看内层 scf.for，它们对应 mr / nr 微块切分。
// 3. 最后看 linalg.matmul，它是从 C 中恢复出的核心矩阵乘语义。
// ============================================================================
#tile_outer = affine_map<(d0, d1) -> ({mc}, d0 - d1)>
#tile_inner_m = affine_map<(d0, d1) -> ({mr}, d0 - d1)>
#tile_inner_n = affine_map<(d0, d1) -> ({nr}, d0 - d1)>

module {{
  // 这个函数不是逐条模拟 C 语句，而是把 C kernel 提升为“块级 matmul 语义”。
  func.func @gemm_fp32_linalg(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {{
    c_kernel = "{kernel}",
    semantic = "{semantic}",
    layout = "{layout}",
    lift_target = "{lift_target}",
    mlir_level = "linalg+scf"
  }} {{
    // 动态维度来自输入 memref，本文件保留的是“高层结构”，不是固定形状特化版本。
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst_0 = arith.constant 0.0 : f32
    %mc0 = arith.constant {mc} : index
    %nc0 = arith.constant {nc} : index
    %kc0 = arith.constant {kc} : index
    %mr0 = arith.constant {mr} : index
    %nr0 = arith.constant {nr} : index

    // 通过 memref.dim 恢复矩阵问题规模。
    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 外层三层循环保持论文中的 mc / nc / kc 分块结构。
    scf.for %i = %c0 to %m step %mc0 {{
      %mc = affine.min #tile_outer(%m, %i)

      scf.for %j = %c0 to %n step %nc0 {{
        %nc = affine.min #tile_outer(%n, %j)

        scf.for %ko = %c0 to %k step %kc0 {{
          %kc = affine.min #tile_outer(%k, %ko)

          // subview 把整矩阵裁成当前 tile，便于后续继续做向量化和 ArmSME lowering。
          %a_tile = memref.subview %a[%i, %ko] [%mc, %kc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %b_tile = memref.subview %b[%ko, %j] [%kc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %c_tile = memref.subview %c[%i, %j] [%mc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>

          // 内层两层循环保留 mr / nr 微块信息。
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

              // 研究版语义只保留 C = A * B，所以每个输出微块先清零。
              linalg.fill ins(%cst_0 : f32)
                          outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)

              // 这里是最关键的提升结果：把标量乘加模式恢复成 linalg.matmul。
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


def emit_affine_mlir(
    kernel: str,
    semantic: str,
    layout: str,
    blocking: dict[str, int],
) -> str:
    mc = blocking["mc"]
    nc = blocking["nc"]
    kc = blocking["kc"]
    mr = blocking["mr"]
    nr = blocking["nr"]

    return f"""// ============================================================================ 
// 自动生成文件：gemm_fp32_affine.mlir
// 来源：gemm_mlir_kernel.c
// 目标：保留规则循环、索引关系和标量访存，作为后续 affine 分析与预取研究的输入
//
// 阅读建议：
// 1. 先看 affine.for，它们对应论文中的分块循环层次。
// 2. 再看 affine.load / affine.store，它们暴露了最直接的访存行为。
// 3. 这里故意不使用 linalg.matmul，而是保留标量归约结构，方便研究 reuse distance、
//    working set、stride 和预取距离。
// ============================================================================
#tile_outer = affine_map<(d0, d1) -> ({mc}, d0 - d1)>
#row_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
#col_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>

module {{
  // 这个函数保留的是“规则循环 + 标量访存 + 标量归约”形式，适合做 affine 层分析。
  func.func @gemm_fp32_affine(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {{
    c_kernel = "{kernel}",
    semantic = "{semantic}",
    layout = "{layout}",
    mlir_level = "affine"
  }} {{
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant {mc} : index
    %c128_n = arith.constant {nc} : index
    %c128_k = arith.constant {kc} : index
    %c16 = arith.constant {mr} : index
    %c16_n = arith.constant {nr} : index
    %f0 = arith.constant 0.0 : f32

    // 从输入矩阵中恢复问题规模。
    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 外层三层 affine.for 对应论文中的 mc / nc / kc。
    affine.for %i = 0 to %m step {mc} {{
      %mc = affine.min #tile_outer(%m, %i)

      affine.for %j = 0 to %n step {nc} {{
        %nc = affine.min #tile_outer(%n, %j)

        affine.for %ko = 0 to %k step {kc} {{
          %kc = affine.min #tile_outer(%k, %ko)

          // 这里把 ii / jj / kk 都固定在论文给定的块大小上，
          // 再用条件判断裁掉边界块。这样既保留 affine 结构，
          // 又避免动态上界在嵌套 affine.for 中触发符号约束。
          affine.for %ii = 0 to {mc} step {mr} {{
            %ii_in_bound = arith.cmpi ult, %ii, %mc : index
            scf.if %ii_in_bound {{
              affine.for %jj = 0 to {nc} step {nr} {{
                %jj_in_bound = arith.cmpi ult, %jj, %nc : index
                scf.if %jj_in_bound {{
                  // 第一步：对当前输出微块清零。
                  affine.for %i_inner = 0 to {mr} {{
                    %c_row_offset = affine.apply #row_index(%ii, %c0, %i_inner)
                    %row_valid = arith.cmpi ult, %c_row_offset, %mc : index
                    scf.if %row_valid {{
                      %c_row = affine.apply #row_index(%i, %ii, %i_inner)

                      affine.for %j_inner = 0 to {nr} {{
                        %c_col_offset = affine.apply #col_index(%jj, %c0, %j_inner)
                        %col_valid = arith.cmpi ult, %c_col_offset, %nc : index
                        scf.if %col_valid {{
                          %c_col = affine.apply #col_index(%j, %jj, %j_inner)
                          affine.store %f0, %c[%c_row, %c_col] : memref<?x?xf32>
                        }}
                      }}
                    }}
                  }}

                  // 第二步：显式保留 kk 归约循环和标量乘加模式。
                  affine.for %kk = 0 to {kc} {{
                    %in_k_bound = arith.cmpi ult, %kk, %kc : index
                    scf.if %in_k_bound {{
                      affine.for %i_inner = 0 to {mr} {{
                        %a_row_offset = affine.apply #row_index(%ii, %c0, %i_inner)
                        %row_valid = arith.cmpi ult, %a_row_offset, %mc : index
                        scf.if %row_valid {{
                          %a_row = affine.apply #row_index(%i, %ii, %i_inner)
                          %a_col = affine.apply #col_index(%ko, %c0, %kk)
                          %a_val = affine.load %a[%a_row, %a_col] : memref<?x?xf32>

                          affine.for %j_inner = 0 to {nr} {{
                            %b_col_offset = affine.apply #col_index(%jj, %c0, %j_inner)
                            %col_valid = arith.cmpi ult, %b_col_offset, %nc : index
                            scf.if %col_valid {{
                              %b_row = affine.apply #row_index(%ko, %c0, %kk)
                              %b_col = affine.apply #col_index(%j, %jj, %j_inner)
                              %c_row = affine.apply #row_index(%i, %ii, %i_inner)
                              %c_col = affine.apply #col_index(%j, %jj, %j_inner)

                              %b_val = affine.load %b[%b_row, %b_col] : memref<?x?xf32>
                              %c_old = affine.load %c[%c_row, %c_col] : memref<?x?xf32>
                              %prod = arith.mulf %a_val, %b_val : f32
                              %sum = arith.addf %c_old, %prod : f32
                              affine.store %sum, %c[%c_row, %c_col] : memref<?x?xf32>
                            }}
                          }}
                        }}
                      }}
                    }}
                  }}
                }}
              }}
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
        description="Lift a restricted GEMM C kernel into linalg and affine MLIR."
    )
    parser.add_argument("input", type=pathlib.Path, help="path to the restricted C kernel")
    parser.add_argument(
        "--clang",
        default=DEFAULT_CLANG,
        help="clang executable used to produce the JSON AST dump",
    )
    parser.add_argument(
        "--clang-arg",
        action="append",
        default=[],
        help="extra argument forwarded to clang; may be repeated",
    )
    parser.add_argument(
        "--function",
        help="C function name to lift when the source file contains multiple functions",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=pathlib.Path,
        default=pathlib.Path("01_custom_lifter/output"),
        help="directory used to store generated MLIR files",
    )
    args = parser.parse_args()

    source = args.input.read_text(encoding="utf-8")
    validate_source_annotations(source)
    ast = run_clang_ast_dump(args.input, args.clang, args.clang_arg)
    summary = summarize_kernel_ast(ast, args.function)
    validate_kernel_ast(summary)

    kernel = extract_required_annotation(source, "kernel")
    semantic = extract_required_annotation(source, "semantic")
    layout = extract_required_annotation(source, "layout")
    lift_target = extract_required_annotation(source, "lift-target")
    blocking = extract_blocking(source)

    args.output_dir.mkdir(parents=True, exist_ok=True)

    linalg_path = args.output_dir / "gemm_fp32_linalg.mlir"
    affine_path = args.output_dir / "gemm_fp32_affine.mlir"

    linalg_path.write_text(
        emit_linalg_mlir(kernel, semantic, layout, lift_target, blocking),
        encoding="utf-8",
    )
    affine_path.write_text(
        emit_affine_mlir(kernel, semantic, layout, blocking),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
