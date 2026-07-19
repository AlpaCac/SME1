# 03 Prefetch Injection

这个目录对应方案的第三步：根据第二步得到的分析结果和 `cost module` 决策，在 `affine` 层显式注入预取语义。

## 目标

这一阶段的重点不是立刻生成目标机器的真实预取指令，而是先把“高层预取决策”落到 `MLIR` 里，形成后续可继续 lowering 的中间版本。

当前第三步已经从早期 Python 文本替换方案，调整为 **MLIR pass 方案**：

```text
affine MLIR
-> inject-research-prefetch MLIR pass
-> 带 research.prefetch 的 affine MLIR
```

## 为什么改成 MLIR pass

早期 `inject_prefetch.py` 通过查找固定文本：

```mlir
scf.if %in_k_bound {
```

然后把 `research.prefetch` 字符串插进去。这个方式适合快速原型，但有明显问题：

- 依赖文本格式
- 对 SSA 名字和缩进敏感
- 不能直接使用 MLIR IR 结构
- 难以接入后续正式 lowering pipeline

现在的 pass 方案改为在 MLIR IR 上工作：

- 遍历 `func.func`
- 查找受限 GEMM affine 结构中的 `kk` 归约循环
- 定位 `scf.if` 边界保护
- 在 then block 中构造已注册的 `research.prefetch` op
- 给函数增加 `prefetch_injected = "true"` 属性

这更接近正式 MLIR 工作流，也为后续升级为完整自定义 dialect/pass 留出空间。

## 输入和输出

当前第三步的输入是第一步生成的 affine 层 MLIR：

- [../01_custom_lifter/output/gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)

这个输入文件表达的是：

- 一个 `func.func @gemm_fp32_affine`
- 三个矩阵参数，顺序是 `A, B, C`
- `memref<?x?xf32>` 类型的二维浮点矩阵
- `affine.for` 表达分块循环
- `affine.load` / `affine.store` 表达标量访存
- `arith.mulf` / `arith.addf` 表达 `C = A * B` 的标量累加语义

当前第三步的输出是注入预取语义后的 affine 层 MLIR：

- [output/gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)

输出文件相对输入文件只增加预取相关语义，不改变矩阵乘计算语义：

- 在函数属性中增加 `prefetch_injected = "true"`
- 在 `kk` 归约循环的边界保护 `scf.if` 内插入 `research.prefetch`
- 对 `B` 插入高优先级读预取
- 对 `A` 插入中优先级读预取
- 不对 `C` 插入预取

因此第三步的输入/输出关系可以理解为：

```text
gemm_fp32_affine.mlir
  保留 GEMM 的 affine 循环、索引和标量访存

-> inject-research-prefetch pass

gemm_fp32_affine_prefetch.mlir
  在相同计算结构上附加 A/B 预取语义
```

## 输入限制

当前 pass 是研究版结构匹配 pass，不是任意 C/MLIR 程序的通用预取注入器。它对输入有以下限制。

第一，输入必须是 MLIR affine 层文件，而不是 C 源码、LLVM IR 或已经完全 lowering 后的低层 MLIR。第三步默认第一步已经完成 C 到高层 MLIR 的提升。

第二，输入需要包含 `func.func`，并且目标函数至少有三个参数。当前实现默认：

```text
func argument 0 -> A
func argument 1 -> B
func argument 2 -> C
```

如果参数顺序变化，pass 仍然可能插入 op，但 `target = "A"` / `target = "B"` 对应的 memref 会不再准确。

第三，矩阵参数当前假设是二维 memref，研究示例中是：

```mlir
memref<?x?xf32>
```

当前 pass 不检查完整类型合法性，但后续预取语义、索引个数和文档解释都按二维矩阵理解。

第四，输入需要保留第一步生成的受限 GEMM affine 循环骨架。当前 pass 通过结构寻找 `kk` 归约循环，而不是通过变量名寻找。它期望祖先 induction variables 的顺序对应：

```text
i, j, ko, ii, jj, kk
```

也就是说，变量名可以变化，但循环层次和语义顺序不能随意变化。

第五，当前候选 `kk` 循环需要满足：

- 是 `affine.for`
- step 为 `1`
- upper bound 是较大的常量，当前示例中是 `128`
- 循环体内直接包含 `scf.if` 作为 `kk` 边界保护
- `scf.if` 的 then region 中存在真实 `affine.load`
- `scf.if` 的 then region 中存在嵌套 `affine.for`

第六，当前 pass 只处理第一处匹配到的 GEMM-like `kk` 循环。如果一个文件里有多个相同结构的函数或多个可预取循环，目前不会做全局多点注入。

第七，当前输出使用插件注册的 `research.prefetch` op，但文本上仍采用 MLIR generic assembly 格式：

```mlir
"research.prefetch"(...)
```

因此后续验证或继续处理时不再需要 `--allow-unregistered-dialect`，但需要加载提供 `research` dialect 的插件：

```text
--load-dialect-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib
```

如果不加载插件，MLIR 仍然无法知道 `research.prefetch` 的注册信息和 verifier。

## 目录结构

- [CMakeLists.txt](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/CMakeLists.txt)：外部 MLIR pass 插件构建入口
- [passes/InjectResearchPrefetch.cpp](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/passes/InjectResearchPrefetch.cpp)：第三步预取注入 pass
- [generic_op说明文档.md](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/generic_op说明文档.md)：说明 `research.prefetch` 的 generic assembly 形式、注册方式和 pass 迁移思路
- [output/gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)：带研究版预取语义的 `affine` MLIR

## 当前 pass 做了什么

当前 pass 名称是：

```text
inject-research-prefetch
```

它面向第一步生成的受限 affine GEMM 结构，执行以下逻辑：

1. 在 `func.func` 中查找候选 `affine.for`。
2. 选择形如 `kk` 归约循环的结构。
3. 找到循环体内的 `scf.if` 边界保护。
4. 收集外层 induction variables：

```text
i, j, ko, ii, jj, kk
```

5. 在 `scf.if` 的 then block 开头插入两个已注册的 `research.prefetch` op：

```mlir
"research.prefetch"(...)
"research.prefetch"(...)
```

6. 给函数增加：

```mlir
prefetch_injected = "true"
```

## 当前注入策略

当前 pass 内置了与第二步 cost module 一致的研究策略：

- 对 `B` 注入高优先级 `read` 预取
- 对 `A` 注入中优先级 `read` 预取
- 对 `C` 不注入预取

生成的语义仍然采用 generic assembly 打印形式，但 op 已经由插件中的 `research` dialect 注册：

```mlir
"research.prefetch"(%b, %ko, %j, %jj, %kk) <{
  target = "B",
  kind = "read",
  priority = "high",
  cache = "L1",
  locality = "KEEP",
  distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

后续可以把这些字段进一步改成 pass option、函数属性、外部 analysis result，或者从当前 DynamicDialect 版本升级为 TableGen/ODS 定义的正式自定义 dialect attribute。

## 如何构建 pass 插件

当前本机已经在 `external/llvm-project/build` 中构建了 MLIR，并导出了 CMake package：

- `MLIR_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/mlir`
- `LLVM_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/llvm`

因此可以在仓库根目录执行：

```bash
cmake -S 03_prefetch_injection \
  -B 03_prefetch_injection/build \
  -DMLIR_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/llvm

cmake --build 03_prefetch_injection/build
```

构建成功后，macOS 上会得到：

```text
03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib
```

`build/` 是本地编译产物目录，不提交到仓库。

## 如何运行 pass

构建出插件后，可以使用：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib \
  --pass-pipeline='builtin.module(func.func(inject-research-prefetch))' \
  01_custom_lifter/output/gemm_fp32_affine.mlir \
  -o 03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir
```

这里使用 `builtin.module(func.func(...))`，是因为当前 pass 是 `func.func` 级 pass，需要在 module 下面对每个函数运行。Linux 上插件后缀通常是 `.so`；macOS 上通常是 `.dylib`。

## 如何验证输出

因为 `research.prefetch` 已经由插件注册，验证输出时应加载 dialect 插件：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-dialect-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib \
  03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir
```

如果不加载 dialect 插件，MLIR 会报告 `research` 是未注册 dialect；这正好说明当前输出已经依赖正式注册信息，而不是裸 unknown op。

## 后续演进

下一步可以继续做三件事：

1. 把当前 DynamicDialect 版本的 `research.prefetch` 升级为 TableGen/ODS 定义的正式自定义 dialect op。
2. 把当前 pass 中硬编码的 A/B 预取策略改为读取第二步 analysis result。
3. 把注入点匹配从“受限 GEMM 形态”扩展为更通用的 affine 访存模式匹配。
