# Script 工具说明

本目录存放仓库辅助脚本。

## `analyze_transform_mlir.py`

用途：读取一个 transform dialect 调度文件和一个 MLIR 文件，生成中文分析报告。

它可以回答：

- transform dialect 中匹配了什么 op
- 是否进行了 tiling / vectorization
- contraction 是否降成 outerproduct
- 目标 MLIR 中有哪些 dialect
- 关键 op 出现了多少次
- 当前 MLIR 大致处于 linalg / vector / Arm SME / LLVM 哪一层

示例：

```bash
python3 script/analyze_transform_mlir.py \
  --transform 03_prefetch_injection/input/linalg_to_vector_transform.mlir \
  --mlir 03_prefetch_injection/output/02_vector_prefetch.mlir \
  --output script/transform_vector_report.md
```

如果不指定 `--output`，报告会直接打印到终端。

说明：该脚本是文本级分析工具，不依赖 MLIR Python binding，也不执行 MLIR verifier。语法合法性仍应使用 `mlir-opt` 检查。
