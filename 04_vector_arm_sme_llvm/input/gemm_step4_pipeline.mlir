// ============================================================================
// 自动生成文件：gemm_step4_pipeline.mlir
// 目标：构造一份最适合进入官方 lowering 路线的高层 GEMM MLIR
//
// 说明：
// 1. 第一步产出的 linalg/scf 版本适合研究“从 C 提升到高层 MLIR”。
// 2. 第四步需要一条更直接、可运行的 lowering 主线，因此这里整理成
//    tensor + linalg.matmul + Transform Dialect 的形式。
// 3. 这条主线对应官方推荐路线：
//      linalg.matmul -> vector -> arm_sme -> llvm
// ============================================================================
func.func @gemm_step4(%A : tensor<?x?xf32>,
                      %B : tensor<?x?xf32>,
                      %C : tensor<?x?xf32>) -> tensor<?x?xf32> {
  // 这里保留最核心的高层算子语义，便于后续直接进入向量化和 ArmSME lowering。
  %res = linalg.matmul ins(%A, %B : tensor<?x?xf32>, tensor<?x?xf32>)
                       outs(%C : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %res : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%module : !transform.any_op {transform.consumed}) {
    %matmul = transform.structured.match ops{["linalg.matmul"]} in %module
      : (!transform.any_op) -> !transform.any_op

    // 第一步：按研究中的 mr/nr 规模做 tile。
    %tiled_op, %loops:3 = transform.structured.tile_using_for %matmul tile_sizes [[16], [16], 1]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op, !transform.any_op)

    // 第二步：把局部 matmul 向量化。
    transform.structured.vectorize %tiled_op vector_sizes [[16], [16], 1]
      : !transform.any_op

    // 第三步：bufferize，给后续 vector lowering 和 ArmSME lowering 准备 memref 形式。
    %bufferized = transform.bufferization.one_shot_bufferize %module
      {bufferize_function_boundaries=true} : (!transform.any_op) -> !transform.any_op

    %func = transform.structured.match ops{["func.func"]} in %bufferized
      : (!transform.any_op) -> !transform.any_op

    // 第四步：把 vector.multi_reduction 等形式规整到更适合 contraction lowering 的状态。
    transform.apply_patterns to %func {
      transform.apply_patterns.vector.lower_masked_transfers
      transform.apply_patterns.vector.transfer_permutation_patterns
      transform.apply_patterns.vector.reduction_to_contract
      transform.apply_patterns.vector.sink_ops
    } : !transform.any_op

    // 第五步：把 vector.contract 进一步降到 vector.outerproduct，为 ArmSME 做准备。
    transform.apply_patterns to %func {
      transform.apply_patterns.vector.lower_contraction lowering_strategy = "outerproduct"
      transform.apply_patterns.vector.lower_masks
      transform.apply_patterns.vector.rank_reducing_subview_patterns
      transform.apply_patterns.canonicalization
    } : !transform.any_op

    // 第六步：做一点简单的 hoist/LICM，让中间 IR 更整洁。
    %all_loops = transform.structured.match interface{LoopLikeInterface} in %bufferized
      : (!transform.any_op) -> !transform.any_op
    transform.apply_licm to %all_loops : !transform.any_op
    transform.loop.hoist_loop_invariant_subsets %all_loops : !transform.any_op
    transform.yield
  }
}
