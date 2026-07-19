// ============================================================================
// 固定输入文件：gemm_step4_compute_mainline.mlir
// 目标：作为第四步计算主 lowering 线的稳定输入，用于观察 linalg -> vector -> arm_sme -> llvm
// ============================================================================

func.func @gemm_step4_compute(%A : tensor<?x?xf32>,
                              %B : tensor<?x?xf32>,
                              %C : tensor<?x?xf32>) -> tensor<?x?xf32> {
  %res = linalg.matmul ins(%A, %B : tensor<?x?xf32>, tensor<?x?xf32>)
                       outs(%C : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %res : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%module : !transform.any_op {transform.consumed}) {
    %matmul = transform.structured.match ops{["linalg.matmul"]} in %module
      : (!transform.any_op) -> !transform.any_op
    %tiled_op, %loops:3 = transform.structured.tile_using_for %matmul tile_sizes [[16], [16], 1]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op, !transform.any_op)
    transform.structured.vectorize %tiled_op vector_sizes [[16], [16], 1]
      : !transform.any_op
    %bufferized = transform.bufferization.one_shot_bufferize %module
      {bufferize_function_boundaries=true} : (!transform.any_op) -> !transform.any_op
    %func = transform.structured.match ops{["func.func"]} in %bufferized
      : (!transform.any_op) -> !transform.any_op
    transform.apply_patterns to %func {
      transform.apply_patterns.vector.lower_masked_transfers
      transform.apply_patterns.vector.transfer_permutation_patterns
      transform.apply_patterns.vector.reduction_to_contract
      transform.apply_patterns.vector.sink_ops
    } : !transform.any_op
    transform.apply_patterns to %func {
      transform.apply_patterns.vector.lower_contraction lowering_strategy = "outerproduct"
      transform.apply_patterns.vector.lower_masks
      transform.apply_patterns.vector.rank_reducing_subview_patterns
      transform.apply_patterns.canonicalization
    } : !transform.any_op
    %all_loops = transform.structured.match interface{LoopLikeInterface} in %bufferized
      : (!transform.any_op) -> !transform.any_op
    transform.apply_licm to %all_loops : !transform.any_op
    transform.loop.hoist_loop_invariant_subsets %all_loops : !transform.any_op
    transform.yield
  }
}
