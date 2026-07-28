#ifndef SME1_STENCIL_ANALYSIS_H
#define SME1_STENCIL_ANALYSIS_H

#include "llvm/ADT/SmallVector.h"

namespace llvm {
class CallBase;
class DominatorTree;
class Function;
class Loop;
class LoopInfo;
class PHINode;
class ScalarEvolution;
class SCEV;
class Value;
} // namespace llvm

namespace sme1 {

enum class StencilKind {
  Stencil1D3P,
  Stencil2D5P,
  Stencil2D9P,
  Stencil3D7P,
  Stencil3D13P,
  Stencil3D25P,
  Stencil3D27P,
};

enum class StreamKind {
  CurrentRow,
  RowNeighbor,
  PlaneNeighbor,
};

struct StreamInfo {
  StreamKind Kind;
  llvm::Value *Base = nullptr;
  llvm::Value *RepresentativePointer = nullptr;
  const llvm::SCEV *Address = nullptr;
  llvm::SmallVector<llvm::CallBase *, 9> Loads;
};

struct StencilInfo {
  StencilKind Kind;
  llvm::Loop *InnerLoop = nullptr;
  llvm::PHINode *Induction = nullptr;
  llvm::Value *Predicate = nullptr;
  llvm::Value *VectorStep = nullptr;
  unsigned LogicalLoadCount = 0;
  llvm::SmallVector<StreamInfo, 27> Streams;
};

llvm::SmallVector<StencilInfo, 8>
analyzeStencilFunction(llvm::Function &F, llvm::LoopInfo &LI,
                       llvm::ScalarEvolution &SE, llvm::DominatorTree &DT);

const char *toString(StencilKind Kind);
const char *toString(StreamKind Kind);

} // namespace sme1

#endif
