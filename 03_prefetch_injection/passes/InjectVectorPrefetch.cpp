//===- InjectVectorPrefetch.cpp ------------------------------------------===//
//
// 第三步“vector 层预取注入”MLIR pass。
//
// 本 pass 假设输入已经由第一步 linalg 主线经过官方/transform pipeline
// 转成 vector 层，IR 中存在 vector.transfer_read。第二步 cost model 的
// 结构化决策以 JSON 文件形式存在，本 pass 读取其中 A/B/C 的 enable 与
// priority 等字段，然后在符合条件的 vector.transfer_read 前插入标准
// memref.prefetch。
//
// pass 不依赖函数名、SSA 名或固定循环变量名。当前用 rank-1 vector read
// 作为 A/B 读流候选，跳过 rank-2 C tile 读，避免误把输出累加块当成
// 预取对象。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/Vector/IR/VectorOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Builders.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/MemoryBuffer.h"

#include <optional>
#include <string>

using namespace mlir;

namespace {

struct PrefetchDecision {
  bool enable = false;
  std::string priority = "none";
  std::string cache = "none";
  std::string locality = "none";
  std::string distance = "none";
};

struct AnalysisDecisions {
  PrefetchDecision a;
  PrefetchDecision b;
  PrefetchDecision c;
};

static std::optional<std::string> extractStringField(StringRef object,
                                                     StringRef key) {
  std::string pattern = ("\"" + key + "\"").str();
  size_t keyPos = object.find(pattern);
  if (keyPos == StringRef::npos)
    return std::nullopt;

  size_t colon = object.find(':', keyPos);
  if (colon == StringRef::npos)
    return std::nullopt;

  size_t firstQuote = object.find('"', colon + 1);
  if (firstQuote == StringRef::npos)
    return std::nullopt;

  size_t secondQuote = object.find('"', firstQuote + 1);
  if (secondQuote == StringRef::npos)
    return std::nullopt;

  return object.slice(firstQuote + 1, secondQuote).str();
}

static bool extractBoolField(StringRef object, StringRef key) {
  std::string pattern = ("\"" + key + "\"").str();
  size_t keyPos = object.find(pattern);
  if (keyPos == StringRef::npos)
    return false;

  size_t colon = object.find(':', keyPos);
  if (colon == StringRef::npos)
    return false;

  StringRef tail = object.drop_front(colon + 1).ltrim();
  return tail.starts_with("true");
}

static std::optional<StringRef> findDecisionObject(StringRef json,
                                                   StringRef tensor) {
  std::string pattern = "\"tensor\": \"" + tensor.str() + "\"";
  size_t tensorPos = json.find(pattern);
  if (tensorPos == StringRef::npos)
    return std::nullopt;

  size_t objectStart = json.rfind('{', tensorPos);
  size_t objectEnd = json.find('}', tensorPos);
  if (objectStart == StringRef::npos || objectEnd == StringRef::npos ||
      objectEnd <= objectStart)
    return std::nullopt;

  return json.slice(objectStart, objectEnd + 1);
}

static PrefetchDecision parseDecision(StringRef json, StringRef tensor) {
  PrefetchDecision decision;
  std::optional<StringRef> object = findDecisionObject(json, tensor);
  if (!object)
    return decision;

  decision.enable = extractBoolField(*object, "enable");
  decision.priority =
      extractStringField(*object, "priority").value_or("none");
  decision.cache = extractStringField(*object, "target_cache").value_or("none");
  decision.locality = extractStringField(*object, "locality").value_or("none");
  decision.distance = extractStringField(*object, "distance").value_or("none");
  return decision;
}

static AnalysisDecisions loadAnalysisDecisions(StringRef path) {
  AnalysisDecisions decisions;
  auto bufferOrError = llvm::MemoryBuffer::getFile(path);
  if (!bufferOrError)
    return decisions;

  StringRef json = bufferOrError.get()->getBuffer();
  decisions.a = parseDecision(json, "A");
  decisions.b = parseDecision(json, "B");
  decisions.c = parseDecision(json, "C");
  return decisions;
}

static unsigned localityHintFor(const PrefetchDecision &decision) {
  if (decision.locality == "none")
    return 0;
  if (decision.locality == "STRM")
    return 0;
  return 3;
}

static bool isVectorReadPrefetchCandidate(vector::TransferReadOp read) {
  auto sourceType = dyn_cast<MemRefType>(read.getBase().getType());
  if (!sourceType)
    return false;

  // 当前第三步只对 rank-1 vector.transfer_read 插入读预取。rank-2 读通常
  // 对应 C tile 的累加读，不由第二步默认策略主动预取。
  if (read.getVectorType().getRank() != 1)
    return false;

  Operation *previous = read->getPrevNode();
  return !previous || !isa<memref::PrefetchOp>(previous);
}

struct InjectVectorPrefetchPass
    : public PassWrapper<InjectVectorPrefetchPass,
                         OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(InjectVectorPrefetchPass)

  StringRef getArgument() const final { return "step3-inject-vector-prefetch"; }

  StringRef getDescription() const final {
    return "Insert memref.prefetch before vector.transfer_read according to "
           "step-2 cost-model decisions";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<func::FuncDialect, memref::MemRefDialect,
                    vector::VectorDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    AnalysisDecisions decisions = loadAnalysisDecisions(
        "02_prefetch_cost_model/output/prefetch_analysis.json");

    SmallVector<vector::TransferReadOp> reads;
    func.walk([&](vector::TransferReadOp read) {
      if (isVectorReadPrefetchCandidate(read))
        reads.push_back(read);
    });

    if (reads.empty()) {
      func.emitError("expected vector.transfer_read candidates in vector IR");
      signalPassFailure();
      return;
    }

    unsigned inserted = 0;
    for (auto [index, read] : llvm::enumerate(reads)) {
      const PrefetchDecision *decision = nullptr;
      StringRef tensor;
      if (index % 2 == 0) {
        decision = &decisions.a;
        tensor = "A";
      } else {
        decision = &decisions.b;
        tensor = "B";
      }

      if (!decision->enable)
        continue;

      OpBuilder builder(read);
      memref::PrefetchOp::create(builder, read.getLoc(), read.getBase(),
                                 read.getIndices(), /*isWrite=*/false,
                                 localityHintFor(*decision),
                                 /*isDataCache=*/true);
      ++inserted;

      (void)tensor;
    }

    if (inserted == 0) {
      func.emitError("step-2 analysis disabled all vector read prefetches");
      signalPassFailure();
      return;
    }

    OpBuilder builder(func.getContext());
    func->setAttr("step3.prefetch_injected",
                  builder.getStringAttr("vector.memref.prefetch"));
    func->setAttr("step3.prefetch_count", builder.getI64IntegerAttr(inserted));
    func->setAttr("step3.prefetch.A",
                  builder.getStringAttr("enable=" +
                                        std::string(decisions.a.enable ? "true"
                                                                        : "false") +
                                        ",priority=" + decisions.a.priority +
                                        ",cache=" + decisions.a.cache +
                                        ",locality=" + decisions.a.locality +
                                        ",distance=" + decisions.a.distance));
    func->setAttr("step3.prefetch.B",
                  builder.getStringAttr("enable=" +
                                        std::string(decisions.b.enable ? "true"
                                                                        : "false") +
                                        ",priority=" + decisions.b.priority +
                                        ",cache=" + decisions.b.cache +
                                        ",locality=" + decisions.b.locality +
                                        ",distance=" + decisions.b.distance));
  }
};

void registerStep3Passes() { PassRegistration<InjectVectorPrefetchPass>(); }

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEPrefetchInjectionPass",
          LLVM_VERSION_STRING, []() { registerStep3Passes(); }};
}
