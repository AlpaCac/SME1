# Script 工具说明

本目录存放仓库辅助脚本。

## `analyze_transform_mlir.py`

用途：读取一个 transform dialect 调度文件，生成中文分析报告，说明该 transform 文件的调度目标、执行顺序和预期 IR 效果。

它可以回答：

- transform dialect 中匹配了什么 op
- 是否进行了 tiling / vectorization
- contraction 是否降成 outerproduct
- 每条 transform 语句大致承担什么功能
- 该 transform 文件预期把输入 IR 推向哪类结构

示例：

```bash
python3 script/analyze_transform_mlir.py \
  03_prefetch_injection/input/linalg_to_vector_transform.mlir \
  --output script/transform_vector_report.md
```

如果不指定 `--output`，报告会直接打印到终端。

说明：该脚本是文本级分析工具，只分析 transform 文件本身，不读取被变换的目标 MLIR，也不执行 transform-interpreter 或 MLIR verifier。transform 是否能成功应用、输出 IR 是否符合预期，仍应使用 `mlir-opt` 检查。
