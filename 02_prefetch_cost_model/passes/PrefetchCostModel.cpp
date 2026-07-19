//===- PrefetchCostModel.cpp ---------------------------------------------===//
//
// 第二步“预取 Cost Model”研究版 MLIR pass。
//
// 输入来自第一步生成的 linalg 主线：
//   gemm_fp32_linalg.mlir
//
// 推荐运行方式是先用官方 pass 把 linalg.matmul 展开成循环分析形态，
// 再运行本 pass：
//   mlir-opt input.mlir \
//     --convert-linalg-to-loops \
//     --canonicalize \
//     --load-pass-plugin=.../SMEPrefetchCostModelPass.dylib \
//     --step2-prefetch-cost-model
//
// 这样输出 IR 中已经包含 scf 循环、memref.load/store 和 affine.apply/min，
// 可以作为“affine/scf 分析层”观察访存结构。本 pass 不直接插入预取，
// 只做语义分析并生成结构化预取决策，供第三步注入 pass 使用。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"

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
  int64_t subviewCount = 0;
  int64_t loadCount = 0;
  int64_t storeCount = 0;
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
    if (isa<memref::SubViewOp>(op))
      ++summary.subviewCount;
    if (isa<memref::LoadOp>(op))
      ++summary.loadCount;
    if (isa<memref::StoreOp>(op))
      ++summary.storeCount;
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
                builder.getStringAttr("scf+affine-indexing"));
  func->setAttr("step2.analysis_note",
                builder.getStringAttr(
                    "linalg mainline lowered to loop form for affine/scf "
                    "prefetch analysis"));
  func->setAttr("step2.tile.mc", builder.getI64IntegerAttr(cfg.mc));
  func->setAttr("step2.tile.nc", builder.getI64IntegerAttr(cfg.nc));
  func->setAttr("step2.tile.kc", builder.getI64IntegerAttr(cfg.kc));
  func->setAttr("step2.tile.mr", builder.getI64IntegerAttr(cfg.mr));
  func->setAttr("step2.tile.nr", builder.getI64IntegerAttr(cfg.nr));
  func->setAttr("step2.count.scf_for",
                builder.getI64IntegerAttr(summary.scfForCount));
  func->setAttr("step2.count.memref_load",
                builder.getI64IntegerAttr(summary.loadCount));
  func->setAttr("step2.count.memref_store",
                builder.getI64IntegerAttr(summary.storeCount));
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
  os << "  \"analysis_layer\": \"scf+affine-indexing\",\n";
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
  os << "    \"memref_subview_count\": " << summary.subviewCount << ",\n";
  os << "    \"memref_load_count\": " << summary.loadCount << ",\n";
  os << "    \"memref_store_count\": " << summary.storeCount << "\n";
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
        "得到的 `scf + affine indexing` 循环形态。\n\n";
  os << "## 1. IR 结构摘要\n\n";
  os << "- `linalg.matmul` 数量：`" << summary.linalgMatmulCount << "`\n";
  os << "- `linalg.fill` 数量：`" << summary.linalgFillCount << "`\n";
  os << "- `scf.for` 数量：`" << summary.scfForCount << "`\n";
  os << "- `memref.subview` 数量：`" << summary.subviewCount << "`\n";
  os << "- `memref.load` 数量：`" << summary.loadCount << "`\n";
  os << "- `memref.store` 数量：`" << summary.storeCount << "`\n\n";
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

    if (summary.scfForCount == 0) {
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

void registerStep2Passes() { PassRegistration<PrefetchCostModelPass>(); }

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEPrefetchCostModelPass",
          LLVM_VERSION_STRING, []() { registerStep2Passes(); }};
}
