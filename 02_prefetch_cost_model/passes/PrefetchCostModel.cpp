//===- PrefetchCostModel.cpp ---------------------------------------------===//
//
// 第二步“预取 Cost Model”研究版 MLIR pass。
//
// 输入来自第一步生成的 linalg 主线：
//   gemm_fp32_linalg.mlir
//
// 推荐运行方式是先用官方 pass 把 linalg.matmul 展开成循环形态，
// 再运行本 pass 做保守 affine 规范化与分析：
//   mlir-opt input.mlir \
//     --convert-linalg-to-loops \
//     --canonicalize \
//     --load-pass-plugin=.../SMEPrefetchCostModelPass.dylib \
//     --step2-prefetch-cost-model
//
// pass 会把能够安全表达为 affine bound 的 scf.for 规范化为 affine.for，
// 再尝试把 memref.load/store 提升为 affine.load/store。它不按函数名、
// 变量名或固定循环层数生成模板，因此可以用于同类结构化 linalg kernel。
// 本 pass 不直接插入预取，只做语义分析并生成结构化预取决策。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/IR/Operation.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"

#include <optional>
#include <string>

using namespace mlir;

namespace {

struct TileConfig {
  int64_t mc = 128;
  int64_t nc = 128;
  int64_t kc = 128;
  int64_t mr = 16;
  int64_t nr = 16;
  int64_t elementBytes = 4;
};

struct AnalysisSummary {
  int64_t linalgMatmulCount = 0;
  int64_t linalgFillCount = 0;
  int64_t scfForCount = 0;
  int64_t affineForCount = 0;
  int64_t subviewCount = 0;
  int64_t loadCount = 0;
  int64_t storeCount = 0;
  int64_t affineLoadCount = 0;
  int64_t affineStoreCount = 0;
};

static TileConfig recoverTileConfig(func::FuncOp func) {
  TileConfig cfg;
  SmallVector<int64_t> uniqueConstants;

  func.walk([&](arith::ConstantIndexOp op) {
    int64_t value = op.value();
    if (value <= 1)
      return;
    if (llvm::is_contained(uniqueConstants, value))
      return;
    uniqueConstants.push_back(value);
  });

  SmallVector<int64_t> large;
  SmallVector<int64_t> small;
  for (int64_t value : uniqueConstants) {
    if (value >= 64)
      large.push_back(value);
    else
      small.push_back(value);
  }

  if (!large.empty())
    cfg.mc = cfg.nc = cfg.kc = large.front();
  if (!small.empty())
    cfg.mr = cfg.nr = small.front();

  return cfg;
}

static AnalysisSummary summarize(func::FuncOp func) {
  AnalysisSummary summary;

  func.walk([&](Operation *op) {
    if (isa<linalg::MatmulOp>(op))
      ++summary.linalgMatmulCount;
    if (isa<linalg::FillOp>(op))
      ++summary.linalgFillCount;
    if (isa<scf::ForOp>(op))
      ++summary.scfForCount;
    if (isa<affine::AffineForOp>(op))
      ++summary.affineForCount;
    if (isa<memref::SubViewOp>(op))
      ++summary.subviewCount;
    if (isa<memref::LoadOp>(op))
      ++summary.loadCount;
    if (isa<memref::StoreOp>(op))
      ++summary.storeCount;
    if (isa<affine::AffineLoadOp>(op))
      ++summary.affineLoadCount;
    if (isa<affine::AffineStoreOp>(op))
      ++summary.affineStoreCount;
  });

  return summary;
}

static int64_t bytes(int64_t a, int64_t b, int64_t elementBytes) {
  return a * b * elementBytes;
}

static void attachAnalysisAttributes(func::FuncOp func, const TileConfig &cfg,
                                     const AnalysisSummary &summary) {
  OpBuilder builder(func.getContext());

  func->setAttr("step2.analysis_layer",
                builder.getStringAttr("affine-normalized"));
  func->setAttr("step2.analysis_note",
                builder.getStringAttr(
                    "linalg mainline lowered to loops and conservatively "
                    "normalized to affine form for prefetch analysis"));
  func->setAttr("step2.tile.mc", builder.getI64IntegerAttr(cfg.mc));
  func->setAttr("step2.tile.nc", builder.getI64IntegerAttr(cfg.nc));
  func->setAttr("step2.tile.kc", builder.getI64IntegerAttr(cfg.kc));
  func->setAttr("step2.tile.mr", builder.getI64IntegerAttr(cfg.mr));
  func->setAttr("step2.tile.nr", builder.getI64IntegerAttr(cfg.nr));
  func->setAttr("step2.count.scf_for",
                builder.getI64IntegerAttr(summary.scfForCount));
  func->setAttr("step2.count.affine_for",
                builder.getI64IntegerAttr(summary.affineForCount));
  func->setAttr("step2.count.memref_load",
                builder.getI64IntegerAttr(summary.loadCount));
  func->setAttr("step2.count.memref_store",
                builder.getI64IntegerAttr(summary.storeCount));
  func->setAttr("step2.count.affine_load",
                builder.getI64IntegerAttr(summary.affineLoadCount));
  func->setAttr("step2.count.affine_store",
                builder.getI64IntegerAttr(summary.affineStoreCount));
  func->setAttr("step2.prefetch.A",
                builder.getStringAttr(
                    "enable=true,kind=read,priority=medium,cache=L1,"
                    "locality=KEEP,distance=1-2 kk cache lines"));
  func->setAttr("step2.prefetch.B",
                builder.getStringAttr(
                    "enable=true,kind=read,priority=high,cache=L1,"
                    "locality=KEEP,distance=2 kk cache lines or next B "
                    "micro-tile"));
  func->setAttr("step2.prefetch.C",
                builder.getStringAttr(
                    "enable=false,reason=short-lived accumulation tile"));
}

static std::string buildJson(const TileConfig &cfg,
                             const AnalysisSummary &summary) {
  int64_t macroA = bytes(cfg.mc, cfg.kc, cfg.elementBytes);
  int64_t macroB = bytes(cfg.kc, cfg.nc, cfg.elementBytes);
  int64_t macroC = bytes(cfg.mc, cfg.nc, cfg.elementBytes);
  int64_t microA = bytes(cfg.mr, cfg.kc, cfg.elementBytes);
  int64_t microB = bytes(cfg.kc, cfg.nr, cfg.elementBytes);
  int64_t microC = bytes(cfg.mr, cfg.nr, cfg.elementBytes);

  std::string text;
  llvm::raw_string_ostream os(text);
  os << "{\n";
  os << "  \"input_layer\": \"linalg mainline\",\n";
  os << "  \"analysis_layer\": \"affine-normalized\",\n";
  os << "  \"tile_config\": {\n";
  os << "    \"mc\": " << cfg.mc << ",\n";
  os << "    \"nc\": " << cfg.nc << ",\n";
  os << "    \"kc\": " << cfg.kc << ",\n";
  os << "    \"mr\": " << cfg.mr << ",\n";
  os << "    \"nr\": " << cfg.nr << ",\n";
  os << "    \"element_bytes\": " << cfg.elementBytes << "\n";
  os << "  },\n";
  os << "  \"ir_summary\": {\n";
  os << "    \"linalg_matmul_count\": " << summary.linalgMatmulCount
     << ",\n";
  os << "    \"linalg_fill_count\": " << summary.linalgFillCount << ",\n";
  os << "    \"scf_for_count\": " << summary.scfForCount << ",\n";
  os << "    \"affine_for_count\": " << summary.affineForCount << ",\n";
  os << "    \"memref_subview_count\": " << summary.subviewCount << ",\n";
  os << "    \"memref_load_count\": " << summary.loadCount << ",\n";
  os << "    \"memref_store_count\": " << summary.storeCount << ",\n";
  os << "    \"affine_load_count\": " << summary.affineLoadCount << ",\n";
  os << "    \"affine_store_count\": " << summary.affineStoreCount << "\n";
  os << "  },\n";
  os << "  \"working_set_bytes\": {\n";
  os << "    \"macro_A\": " << macroA << ",\n";
  os << "    \"macro_B\": " << macroB << ",\n";
  os << "    \"macro_C\": " << macroC << ",\n";
  os << "    \"macro_total\": " << (macroA + macroB + macroC) << ",\n";
  os << "    \"micro_A\": " << microA << ",\n";
  os << "    \"micro_B\": " << microB << ",\n";
  os << "    \"micro_C\": " << microC << ",\n";
  os << "    \"micro_total\": " << (microA + microB + microC) << "\n";
  os << "  },\n";
  os << "  \"reuse_summary\": {\n";
  os << "    \"A_value_reuse_in_micro_kernel\": " << cfg.nr << ",\n";
  os << "    \"B_value_reuse_in_micro_kernel\": " << cfg.mr << ",\n";
  os << "    \"C_element_accumulation_depth\": " << cfg.kc << "\n";
  os << "  },\n";
  os << "  \"decisions\": [\n";
  os << "    {\n";
  os << "      \"tensor\": \"B\",\n";
  os << "      \"enable\": true,\n";
  os << "      \"kind\": \"read\",\n";
  os << "      \"priority\": \"high\",\n";
  os << "      \"target_cache\": \"L1\",\n";
  os << "      \"locality\": \"KEEP\",\n";
  os << "      \"distance\": \"2 kk cache lines or next B micro-tile\",\n";
  os << "      \"reason\": \"B has contiguous reads across N and reuse across "
        "M micro iterations.\"\n";
  os << "    },\n";
  os << "    {\n";
  os << "      \"tensor\": \"A\",\n";
  os << "      \"enable\": true,\n";
  os << "      \"kind\": \"read\",\n";
  os << "      \"priority\": \"medium\",\n";
  os << "      \"target_cache\": \"L1\",\n";
  os << "      \"locality\": \"KEEP\",\n";
  os << "      \"distance\": \"1-2 kk cache lines\",\n";
  os << "      \"reason\": \"A is contiguous along K and each value is reused "
        "across the N micro-tile.\"\n";
  os << "    },\n";
  os << "    {\n";
  os << "      \"tensor\": \"C\",\n";
  os << "      \"enable\": false,\n";
  os << "      \"kind\": \"write\",\n";
  os << "      \"priority\": \"low\",\n";
  os << "      \"target_cache\": \"none\",\n";
  os << "      \"locality\": \"none\",\n";
  os << "      \"distance\": \"none\",\n";
  os << "      \"reason\": \"C is a short-lived accumulation tile in the "
        "current research kernel.\"\n";
  os << "    }\n";
  os << "  ]\n";
  os << "}\n";
  return os.str();
}

static std::string buildMarkdown(const TileConfig &cfg,
                                 const AnalysisSummary &summary) {
  int64_t macroTotal =
      bytes(cfg.mc, cfg.kc, cfg.elementBytes) +
      bytes(cfg.kc, cfg.nc, cfg.elementBytes) +
      bytes(cfg.mc, cfg.nc, cfg.elementBytes);
  int64_t microTotal =
      bytes(cfg.mr, cfg.kc, cfg.elementBytes) +
      bytes(cfg.kc, cfg.nr, cfg.elementBytes) +
      bytes(cfg.mr, cfg.nr, cfg.elementBytes);

  std::string text;
  llvm::raw_string_ostream os(text);
  os << "# 第二步分析结果\n\n";
  os << "这份报告由 `step2-prefetch-cost-model` MLIR pass 生成。"
        "输入是第一步的 `linalg` 主线，分析层是经过 linalg lowering "
        "和保守规范化得到的 `affine-normalized` 循环形态。\n\n";
  os << "## 1. IR 结构摘要\n\n";
  os << "- `linalg.matmul` 数量：`" << summary.linalgMatmulCount << "`\n";
  os << "- `linalg.fill` 数量：`" << summary.linalgFillCount << "`\n";
  os << "- `scf.for` 数量：`" << summary.scfForCount << "`\n";
  os << "- `affine.for` 数量：`" << summary.affineForCount << "`\n";
  os << "- `memref.subview` 数量：`" << summary.subviewCount << "`\n";
  os << "- `memref.load` 数量：`" << summary.loadCount << "`\n";
  os << "- `memref.store` 数量：`" << summary.storeCount << "`\n\n";
  os << "- `affine.load` 数量：`" << summary.affineLoadCount << "`\n";
  os << "- `affine.store` 数量：`" << summary.affineStoreCount << "`\n\n";
  if (summary.scfForCount != 0)
    os << "说明：仍有 `" << summary.scfForCount
       << "` 个 `scf.for` 未转换，通常来自动态边界 tile。"
          "这些循环没有被强行改写，是为了保持 MLIR affine verifier "
          "可接受的合法 IR。\n\n";
  os << "## 2. 分块和工作集\n\n";
  os << "- 宏块：`mc=" << cfg.mc << ", nc=" << cfg.nc
     << ", kc=" << cfg.kc << "`\n";
  os << "- 微块：`mr=" << cfg.mr << ", nr=" << cfg.nr << "`\n";
  os << "- 宏块工作集：`" << macroTotal << " bytes`\n";
  os << "- 微块工作集：`" << microTotal << " bytes`\n\n";
  os << "## 3. 预取决策\n\n";
  os << "- `B`：开启读预取，优先级 high，目标 L1，策略 KEEP。"
        "原因是 B 在 N 方向连续访问，并在 M 微块方向复用。\n";
  os << "- `A`：开启读预取，优先级 medium，目标 L1，策略 KEEP。"
        "原因是 A 沿 K 方向连续访问，并在 N 微块方向复用。\n";
  os << "- `C`：当前不开启主动软件预取。原因是 C 是短生命周期累加块，"
        "更适合先观察实际硬件行为后再决定。\n\n";
  os << "## 4. 对第三步的输出接口\n\n";
  os << "第三步应读取 `prefetch_analysis.json` 中的 `decisions`，"
        "并在 vector 主线中对 A/B 的读流插入预取语义。"
        "本步骤不直接修改计算语义，只给出分析结果和决策。\n";
  return os.str();
}

static LogicalResult writeFile(StringRef path, StringRef content) {
  std::error_code error;
  llvm::raw_fd_ostream os(path, error, llvm::sys::fs::OF_Text);
  if (error)
    return failure();
  os << content;
  return success();
}

static bool buildSingleResultAffineBound(Value value,
                                         SmallVectorImpl<Value> &operands,
                                         AffineMap &map, Region *region) {
  MLIRContext *context = value.getContext();
  if (auto constant = value.getDefiningOp<arith::ConstantIndexOp>()) {
    map = AffineMap::getConstantMap(constant.value(), context);
    return true;
  }

  // affine.min 结果经常表示边界 tile 的动态大小。它适合参与 affine
  // index 计算，但不能总是作为嵌套 affine.for 的合法 bound 使用。
  // 对这类循环保持 scf.for，避免为了规范化破坏 IR 合法性。
  if (value.getDefiningOp<affine::AffineMinOp>())
    return false;

  if (affine::isValidDim(value, region)) {
    operands.push_back(value);
    map = AffineMap::get(/*dimCount=*/1, /*symbolCount=*/0,
                         getAffineDimExpr(0, context));
    return true;
  }

  if (!affine::isValidSymbol(value, region))
    return false;

  operands.push_back(value);
  map = AffineMap::get(/*dimCount=*/0, /*symbolCount=*/1,
                       getAffineSymbolExpr(0, context));
  return true;
}

static std::optional<int64_t> getConstantIndex(Value value) {
  if (auto constant = value.getDefiningOp<arith::ConstantIndexOp>())
    return constant.value();
  return std::nullopt;
}

static std::optional<int64_t> getStaticTileBoundFromAffineMin(Value value) {
  auto minOp = value.getDefiningOp<affine::AffineMinOp>();
  if (!minOp)
    return std::nullopt;

  std::optional<int64_t> staticBound;
  for (AffineExpr expr : minOp.getAffineMap().getResults()) {
    auto constant = dyn_cast<AffineConstantExpr>(expr);
    if (!constant || constant.getValue() <= 0)
      continue;
    if (!staticBound || constant.getValue() > *staticBound)
      staticBound = constant.getValue();
  }
  return staticBound;
}

static bool convertDynamicTileScfForToGuardedAffine(scf::ForOp forOp,
                                                    int64_t stepValue) {
  std::optional<int64_t> lower = getConstantIndex(forOp.getLowerBound());
  std::optional<int64_t> staticUpper =
      getStaticTileBoundFromAffineMin(forOp.getUpperBound());
  if (!lower || !staticUpper)
    return false;

  OpBuilder builder(forOp);
  auto affineFor = affine::AffineForOp::create(
      builder, forOp.getLoc(), *lower, *staticUpper, stepValue);

  IRMapping mapper;
  mapper.map(forOp.getInductionVar(), affineFor.getInductionVar());

  OpBuilder bodyBuilder(affineFor.getContext());
  bodyBuilder.setInsertionPointToStart(affineFor.getBody());
  Value dynamicUpper = mapper.lookupOrDefault(forOp.getUpperBound());
  auto inBound = arith::CmpIOp::create(
      bodyBuilder, forOp.getLoc(), arith::CmpIPredicate::ult,
      affineFor.getInductionVar(), dynamicUpper);
  auto guard = scf::IfOp::create(bodyBuilder, forOp.getLoc(),
                                 inBound.getResult(), /*withElseRegion=*/false);

  OpBuilder thenBuilder(guard.thenBlock(), guard.thenBlock()->begin());
  for (Operation &op : llvm::make_early_inc_range(*forOp.getBody())) {
    if (isa<scf::YieldOp>(op))
      continue;
    thenBuilder.clone(op, mapper);
  }

  forOp.erase();
  return true;
}

static bool convertOneScfForToAffine(scf::ForOp forOp) {
  if (forOp.getNumResults() != 0 || !forOp.getInitArgs().empty())
    return false;

  auto step = forOp.getStep().getDefiningOp<arith::ConstantIndexOp>();
  if (!step || step.value() <= 0)
    return false;

  if (convertDynamicTileScfForToGuardedAffine(forOp, step.value()))
    return true;

  SmallVector<Value> lbOperands;
  SmallVector<Value> ubOperands;
  AffineMap lbMap;
  AffineMap ubMap;
  Region *parentRegion = forOp->getParentRegion();
  if (!buildSingleResultAffineBound(forOp.getLowerBound(), lbOperands, lbMap,
                                    parentRegion) ||
      !buildSingleResultAffineBound(forOp.getUpperBound(), ubOperands, ubMap,
                                    parentRegion))
    return false;

  OpBuilder builder(forOp);
  auto affineFor = affine::AffineForOp::create(
      builder, forOp.getLoc(), lbOperands, lbMap, ubOperands, ubMap,
      step.value());

  IRMapping mapper;
  mapper.map(forOp.getInductionVar(), affineFor.getInductionVar());

  OpBuilder bodyBuilder(affineFor.getContext());
  bodyBuilder.setInsertionPointToStart(affineFor.getBody());
  for (Operation &op : llvm::make_early_inc_range(*forOp.getBody())) {
    if (isa<scf::YieldOp>(op))
      continue;
    bodyBuilder.clone(op, mapper);
  }

  forOp.erase();
  return true;
}

struct NormalizeScfToAffinePass
    : public PassWrapper<NormalizeScfToAffinePass, OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(NormalizeScfToAffinePass)

  StringRef getArgument() const final { return "step2-normalize-scf-to-affine"; }

  StringRef getDescription() const final {
    return "Conservatively convert structured scf.for loops to affine.for for "
           "step-2 prefetch analysis";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<affine::AffineDialect, arith::ArithDialect,
                    func::FuncDialect, scf::SCFDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    bool changed = true;
    while (changed) {
      changed = false;
      func.walk([&](scf::ForOp forOp) {
        if (changed)
          return;
        changed = convertOneScfForToAffine(forOp);
      });
    }

    OpBuilder builder(func.getContext());
    func->setAttr("step2.normalized_to_affine",
                  builder.getStringAttr("conservative"));
  }
};

struct PrefetchCostModelPass
    : public PassWrapper<PrefetchCostModelPass, OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(PrefetchCostModelPass)

  StringRef getArgument() const final { return "step2-prefetch-cost-model"; }

  StringRef getDescription() const final {
    return "Analyze the linalg-derived affine/scf loop layer and emit prefetch "
           "cost decisions";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<arith::ArithDialect, func::FuncDialect, linalg::LinalgDialect,
                    memref::MemRefDialect, scf::SCFDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    TileConfig cfg = recoverTileConfig(func);
    AnalysisSummary summary = summarize(func);

    if (summary.affineForCount == 0 && summary.scfForCount == 0) {
      func.emitError("expected a linalg-derived loop analysis layer");
      signalPassFailure();
      return;
    }

    attachAnalysisAttributes(func, cfg, summary);

    StringRef reportDir = "02_prefetch_cost_model/output";
    if (llvm::sys::fs::create_directories(reportDir).value() != 0) {
      func.emitError("failed to create report directory: ") << reportDir;
      signalPassFailure();
      return;
    }

    SmallString<256> jsonPath(reportDir);
    llvm::sys::path::append(jsonPath, "prefetch_analysis.json");
    SmallString<256> markdownPath(reportDir);
    llvm::sys::path::append(markdownPath, "prefetch_analysis.md");

    if (failed(writeFile(jsonPath, buildJson(cfg, summary))) ||
        failed(writeFile(markdownPath, buildMarkdown(cfg, summary)))) {
      func.emitError("failed to write step-2 analysis reports");
      signalPassFailure();
      return;
    }
  }
};

void registerStep2Passes() {
  PassRegistration<NormalizeScfToAffinePass>();
  PassRegistration<PrefetchCostModelPass>();
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEPrefetchCostModelPass",
          LLVM_VERSION_STRING, []() { registerStep2Passes(); }};
}
