// ============================================================================
// 第三步 transform dialect 调度文件
// 目标：把第一步生成的 linalg 主线转换到 vector 层，作为预取注入 pass 的输入。
// ============================================================================

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%module : !transform.any_op) {
    %matmul = transform.structured.match ops{["linalg.matmul"]} in %module
      : (!transform.any_op) -> !transform.any_op

    %tiled_op, %loops:3 = transform.structured.tile_using_for %matmul tile_sizes [[16], [16], 1]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op, !transform.any_op)

    transform.structured.vectorize %tiled_op vector_sizes [[16], [16], 1]
      : !transform.any_op

    %func = transform.structured.match ops{["func.func"]} in %module
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

    %all_loops = transform.structured.match interface{LoopLikeInterface} in %module
      : (!transform.any_op) -> !transform.any_op
    transform.apply_licm to %all_loops : !transform.any_op
    transform.loop.hoist_loop_invariant_subsets %all_loops : !transform.any_op

    transform.yield
  }
}
