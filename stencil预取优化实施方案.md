# SME Stencil 读预取优化实施方案

---

## 第一部分：Stencil 算子如何计算

### 1.1 共同约定

输入数组按 row-major 布局：

```text
1D: index(x)       = x
2D: index(y, x)    = y * W + x
3D: index(z, y, x) = z * H * W + y * W + x
```

其中：

- `W` 是行宽。

- `H` 是每个平面的行数。

- `row_stride = W`。

- `plane_stride = H * W`。

- `x` 是最内层连续维。

- `y` 是跨行维。

- `z` 是跨平面维。

  ![image-20260731143541837](C:\Users\AlpaCa\AppData\Roaming\Typora\typora-user-images\image-20260731143541837.png)

  ![image-20260731143502427](C:\Users\AlpaCa\AppData\Roaming\Typora\typora-user-images\image-20260731143502427.png)

  

### 1.2六类算子的流拓扑

| 算子 | 逻辑 load | 物理流 | 当前行 | 跨行 | 跨平面 |
|---|---:|---:|---:|---:|---:|
| 1D3P | 3 | 1 | 1 | 0 | 0 |
| 2D5P | 5 | 3 | 1 | 2 | 0 |
| 2D9P | 9 | 3 | 1 | 2 | 0 |
| 3D13P | 13 | 9 | 1 | 4 | 4 |
| 3D25P | 25 | 17 | 1 | 8 | 8 |
| 3D27P | 27 | 9 | 1 | 2 | 6 |

2D 与 3D 共用同一分析框架，但必须分开决策。3D 的额外困难包括：

1. 更多独立并发流。
2. `H * W` 平面跨度带来的 cache/TLB 压力。
3. 平面工作集通常大于 L1。
4. 编译器可能把 `H * W` 保存为不透明 SSA 值，使 SCEV 无法直接识别乘法。

---

## 第二部分：预取方案和决策模型

### 软件预取能够解决的SME的问题，提取SME计算的共性的问题

### 2.1 四类可用读预取

| 类别 | 适用范围 | 作用 | 当前实现状态 |
|---|---|---|---|
| A. 连续维前向预取 | 所有算子 | 预取未来 `x` 位置 | 1D 启用；2D/3D 通常由硬件覆盖 |
| B. 跨行邻域预取 | 2D/3D | 预取未来上下行或更远半径行 | 已实现 |
| C. 跨平面邻域预取 | 3D | 预取未来前后平面流 | 已实现 L1 near 和 L2 warming |
| D. 下一空间块预取 | 长行、平面、tile | 减少切换时的冷启动 | 作为后续增强，当前不默认插入 |

当前 Pass 的重点是 B/C 类。A 类只在收益可能超过硬件预取时启用，D 类需要更
高层的行/平面边界插入点和更完整的 cache profile，暂不作为结构验收条件。

### 2.2 物理流去重

预取对象是去重后的物理流，不是每一条 masked load：

```text
StreamInfo {
  representative_pointer
  grouped_loads
  kind              // current-row, row-neighbor, plane-neighbor
  address_expression
  reuse_count
}
```

去重原则：

1. 共享相同 base。
2. 对最内层 `x` 归纳变量具有相同步长。
3. 只相差小的常量 `x` 偏移时合并为同一 cache-line 流。
4. 行或平面不变量不同则保留为不同流。

### 2.3 预取距离模型

预取距离以“提前多少次向量迭代”表示：

```text
d_iterations(stream, level)
  = ceil(latency_cycles(level)
         / useful_cycles_per_vector_iteration)
```

其中：

- `d_iterations`：预取领先真实 load 的向量迭代次数。
- `latency_cycles(level)`：从预计数据来源到目标 cache 层级的延迟。
- `useful_cycles_per_vector_iteration`：一次向量迭代可用于隐藏延迟的计算周期。
- `ceil`：向上取整，避免静态提前时间低于目标延迟。

转换为未来地址偏移：

```text
d_elements = d_iterations * scalable_vector_step
future_x   = current_x + d_elements
```

对当前 `double` kernel，`scalable_vector_step` 对应 `svcntd()`；Pass 不把
streaming vector length 固定为编译期常量，而是复用 IR 中的可伸缩步长。

距离候选必须满足：

```text
latency_cycles > 0
useful_cycles_per_vector_iteration > 0
d_iterations >= 1
future_x < inner_loop_end
inner_trip_count > 2 * d_iterations
```

如果无法证明未来地址仍在合法范围，Pass 必须增加条件 guard 或拒绝该候选。

### 2.4 Cache 层级模型

目标 cache 层级回答“数据先放到哪里”。估算预取数据在使用前的在途占用：

```text
prefetch_live_bytes(stream, level)
  = d_iterations(stream, level)
  * bytes_per_vector_iteration(stream)

required_bytes(level)
  = active_working_set(level)
  + sum(prefetch_live_bytes(stream, level))
```

层级候选需满足：

```text
required_bytes(level) <= effective_cache_budget(level)
```

初始规则：

1. 即将使用的 row/plane 前沿可预取到 L1。
2. 距离较远的 plane warming 优先进入 L2，避免过早污染 L1。
3. 当前不默认使用 L3，因为服务器共享末级 cache 的可控性和竞争情况尚未测定。
4. 一条 plane 流可同时具有远距离 L2 和近距离 L1 两个候选。

### 2.5 KEEP/STRM 模型

KEEP/STRM 决策依据是复用，不是“地址是否连续”：

```text
reuse_fits(stream, level)
  = reuse_count(stream) > 1
  && reuse_distance_bytes(stream)
       <= effective_cache_budget(level)

policy(stream, level)
  = KEEP, if reuse_fits
  = STRM, otherwise
```

当前原则：

1. 单次使用或复用距离过大时选择 STRM。
2. 同一 cache line 在有效 cache 容量内会被多次使用时选择 KEEP。
3. 2D9P 和 3D27P 的同一物理流包含更多相邻逻辑 load，复用计数高于 5P/star
   中的单邻居流。
4. 平面流即使随 `z` 推进会再次出现，完整平面过大时仍可能选择 STRM。
5. L1 与 L2 对同一流可以得到不同 policy。

### 2.6 联合决策

每个候选保存：

```text
PrefetchDecision {
  enable
  stream
  distance_iterations
  cache_level
  policy
  reject_reason
}
```

决策顺序：

1. 计算距离候选。
2. 选择 cache 层级。
3. 根据该层级的复用窗口选择 KEEP/STRM。
4. 按优先级执行流预算和指令预算准入。
5. 对未准入候选保留拒绝原因，但不插入 IR。

联合约束：

```text
enabled_streams <= max_streams
inserted_prefetches <= instruction_budget
required_bytes(L1) <= L1_budget
required_bytes(L2) <= L2_budget
future_address_is_safe == true
```

因此“预取决策数”不是最终插入数。例如当前服务器报告：

```text
候选预取决策：45
启用决策：29
实际 IR 插入：29
最终 PRFM：29
```

其余 16 个候选通常因 `StreamBudgetReject` 或
`InstructionBudgetReject` 被拒绝。这是资源裁剪，不是插入失败。结构验收要求：

```text
enabled decisions == inserted IR prefetches == assembly PRFM
```

### 2.7 当前默认优先级

| 算子类别 | 初始准入优先级 |
|---|---|
| 1D | 当前连续流 |
| 2D | 跨行流；当前连续流通常交给硬件预取器 |
| 3D star | plane L1、row L1、plane L2 warming |
| 3D box | 按预算选择高复用 row/plane 流，再考虑 L2 warming |

这些优先级是确定性的初始模型，不是最终服务器最优参数。最终距离、层级和策略
必须通过第三部分的逐算子性能实验回写。

---

## 第三部分：在毕昇和独立 LLVM 19 流程中实现

### 3.1 工具职责边界

| 工具/层级 | 职责 |
|---|---|
| 毕昇 Clang 前端 | 解析原 C++ 和 `arm_sme.h`/`arm_sve.h`，生成 AArch64 LLVM IR |
| 独立 LLVM 19 工具 | 提取 kernel、构建并运行 Pass、校验改写后的 IR |
| StencilPrefetchPass | 在 LLVM IR 层识别 stencil、决策并插入预取 |
| 毕昇 AArch64 后端 | 将完整 IR 生成目标机器码 |
| 毕昇链接驱动/目标运行库 | 链接 C++、系统库和 AArch64 SME ABI 例程 |
| Linux 服务器 | 使用原始 `main/test` 运行正确性和性能测试 |

独立 LLVM 19 只负责 IR 变换，不负责最终程序运行库。最终二进制仍遵循 AArch64
SME ABI，例如保留的非 streaming/streaming 函数边界可能需要
`__arm_tpidr2_save`。该例程属于 Arm SME ABI，不是预取 Pass 的依赖。

### 3.2 步骤 1：从 C++ 生成 IR

用途：

1. `full.ll` 保留 kernel、test、`main`，用于最终运行验证。
2. `kernels.ll` 只包含匹配到的计算函数，用于 Pass 结构验证。
3. 报告记录函数、循环、GEP（根据数组下表或者结构体字段计算内存地址）、masked load/store 和可伸缩步长特征。

### 3.3 步骤 2：构建 LLVM Pass

使用仓库 `tools/llvm-19.1.7` 中的：

```text
llvm-config
clang
clang++
opt
LLVMConfig.cmake
LLVM headers
```

Pass 是 LLVM new-pass-manager function plugin，获取：

| Analysis | 用途 |
|---|---|
| `LoopAnalysis` | 找最内层向量循环 |
| `ScalarEvolutionAnalysis` | 解析归纳变量和地址步长 |
| `DominatorTreeAnalysis` | 选择合法插入位置 |
| `TargetIRAnalysis` | 目标相关代价接口 |
| `AssumptionAnalysis` | 使用范围和对齐假设 |

### 3.4 步骤 3：识别循环和物理流

Pass 对每个最内层循环执行以下检查。

#### 3.4.1 向量循环

1. 存在可识别的归纳变量（按照固定规律变化的变量，比如循环变量）。
2. 步长来自可伸缩向量长度（SVE/SME的向量寄存器长度可变，llvm中通常用vscale表示）。
3. load/store 使用兼容的 SVE 谓词（谓词即掩码，决定向量中哪些参与运算）。

#### 3.4.2 地址规范化

SCEV（标量演化分析），用于描述一个标量值如何随循环迭代变化。

```text
for(x=1; x<end; x+=svcntd())
{1,+,2*vscale}<loop>

input[ y * width + x ]
center = base + y*W + {1,+,VL}
```

可以用于计算地址差，确定物理流

#### 3.4.3 中心流

中心流必须：

1. 至少包含中心及左右 `x` 邻居。
2. 能证明存在负、零、正三个 `x` 偏移。
3. 与最多的其它流形成对称关系，或满足已知拓扑的中心约束。

#### 3.4.4 3D 拓扑回退

| 算子 | 精确物理流 | 预期跨行 | 预期跨平面 |
|---|---:|---:|---:|
| 3D13P | 9 | 4 | 4 |
| 3D25P | 17 | 8 | 8 |
| 3D27P | 9 | 2 | 6 |

回退前仍要求：

1. 逻辑 load 数精确对应算子点数。
2. 物理流数精确匹配。
3. 中心流已经通过左右/中心偏移验证。

其余流按地址表达式结构复杂度排序。row stride 通常依赖 `W`，plane stride
通常依赖 `H * W`，因此较简单的前若干流归为 row，其余归为 plane。

### 3.5 步骤 4：边分析边决策并插入

分析和插入在同一个 Pass invocation 中完成：

```text
识别一条物理流
-> 生成距离/层级/policy 候选
-> 执行容量、流和指令预算检查
-> 启用则立即构造未来地址
-> 插入 llvm.aarch64.prefetch
```

插入时：

1. 从代表 load 的指针表达式构造未来地址。
2. 使用 `distance_iterations * vector_step` 前移 `x`。
3. 增加 `future_x < loop_end` guard，避免尾部越界预取。
4. 保持原 masked load/store 和数值计算不变。
5. 已存在相同预取时不重复插入，保证幂等。

`llvm.aarch64.prefetch` 携带：

```text
读/写类型
cache level
KEEP/STRM policy
是否为数据预取
```

AArch64 后端最终选择为 `PRFM`。步骤 2 的结构验证同时检查：

```text
启用决策数
IR 插入日志数
IR intrinsic 数
汇编 PRFM 数
```

当前服务器结果为：

```text
识别算子：1D3P、2D5P、2D9P、3D13P、3D25P、3D27P
候选决策：45
启用/实际插入：29 / 29
最终 PRFM：29
```

这表示步骤 1-4 已通过结构验收。





### 3.6 步骤 5.1：使用原 main/test 验证正确性

消费 `full.ll`：

```text
full.ll
├─ opt -passes=verify
│  -> stencil_all_sme.baseline.ll
└─ opt -passes=function(stencil-prefetch),verify
   -> stencil_all_sme.prefetch.ll
```

两个完整 IR 均保留服务器原始 test 和 `main`。随后使用明确指定的毕昇
`clang++` 生成：

```text
stencil_all_sme.baseline
stencil_all_sme.prefetch
```

默认逐一运行：

```text
--1d3p-s1   --1d3p-s2
--2d5p-s1   --2d5p-s2
--2d9p-s1   --2d9p-s2
--3d13p-s1  --3d13p-s2
--3d25p-s1  --3d25p-s2
--3d27p-s1  --3d27p-s2
```

每次参数只执行对应 test。正确性门槛：

1. baseline test 返回 0。
2. prefetch test 返回 0。
3. 保存双方 stdout/stderr。
4. 输出不含计时时，可启用严格文本一致检查。
5. 输出含计时时，应比较原 test 的校验值或 PASS/FAIL，而不是要求时间文本相同。

### 3.7 步骤 5.2：逐算子性能测试

默认单次复用模式中，同一次执行同时承担正确性检查和性能记录。每个参数执行：

```text
baseline 正确性运行 1 次
prefetch 正确性运行 1 次
```

六类算子的 `s1/s2` 共 12 个参数，因此完整流程运行：

```text
正确性：12 * 2     = 24 次
总计：              24 次
```

稳定性能模式显式设置 `STENCIL_SINGLE_RUN=0`。使用 2 次预热和 7 次样本时仍需
额外运行 216 次，加上正确性共 240 次。正式样本中 baseline/prefetch 按奇偶
轮次交换先后顺序，减少频率、温度和系统漂移造成的偏差。

快速模式：

```bash
STENCIL_SKIP_PERFORMANCE=1 \
  ./scripts/03_validate_server_runtime.sh
```

```bash
STENCIL_SINGLE_RUN=0 STENCIL_WARMUPS=1 STENCIL_SAMPLES=3 \
  ./scripts/03_validate_server_runtime.sh
```

其中 `WARMUPS=1/SAMPLES=3` 仍需运行 120 次程序。只验证执行链路时可使用：

```bash
STENCIL_SMOKE=1 \
  ./scripts/03_validate_server_runtime.sh
```

smoke 模式只运行六类算子的 `s1`，不预热且每个版本执行 1 次，共运行 12 次；
它不能替代正式性能测试。脚本会实时打印当前用例、版本和样本进度。

也可以通过 `STENCIL_CASES` 只测部分参数。

报告位于：

```text
05_runtime_validation/output/server-module/runtime_validation_report.md
05_runtime_validation/output/server-module/correctness_summary.tsv
05_runtime_validation/output/server-module/wall_time_seconds.tsv
```

逐算子加速比为：

```text
speedup = median_time(baseline) / median_time(prefetch)
```

`speedup > 1` 表示预取版本更快。





### 3.8 性能结果的解释和 Profile 回写

当前 29 条 `PRFM` 只证明插入链路正确，不证明全部预取都有收益。性能报告完成后
按以下顺序分析：

1. 先检查 12 个 test 的数值正确性。
2. 分别比较每个 `s1/s2` 的中位数，不只看总时间。
3. 同一算子两个场景都受益，才认为策略具有初步稳定性。
4. 若某类算子退化，按 current/row/plane-L1/plane-L2 做消融。
5. 再扫描距离，不同时改变距离、层级和 policy。
6. 最后使用 PMU 检查 cache miss、TLB miss、内存带宽和预取有效性。

推荐实验顺序：

```text
关闭所有软件预取
-> 仅 row L1
-> 仅 plane L1
-> 仅 plane L2
-> plane L1 + L2
-> 当前 29 条组合
```

对每个有效组合扫描：

```text
distance
cache level
KEEP/STRM
stream budget
instruction budget
```

最终服务器 Profile 至少应区分：

```text
1D current
2D row
3D row
3D plane near
3D plane far
```

类别回写由 `scripts/04_tune_server_profile.sh` 自动执行。脚本分别测量 current-L1、
row-L1、plane-L1、plane-L2 及组合，对每一种 stencil 独立比较 `s1/s2`：单个
场景加速比低于门槛时拒绝候选，两个场景的几何平均达到收益门槛时才允许写入。
最终通过 stencil 位掩码生成 `profiles/server-sme.env`，不直接修改 Pass 源码。

当前自动回写选择预取类别；距离和 KEEP/STRM 仍由第二部分的分析模型给出，并以
`0/AUTO` 写入 Profile。Pass 已开放四类预取的距离与策略覆盖接口，后续距离扫描
可以更新同一 Profile，而不需要重新设计插入流程。生成后必须使用
`scripts/05_validate_tuned_profile.sh` 对组合 Profile 重新进行完整正确性和稳定
性能验证，避免单独候选的收益在组合后消失。

不能把 Apple M5 的历史参数直接作为服务器结论，也不能把 2D 的 row 策略直接
用于 3D plane。

### 3.9 当前完成情况和剩余工作

已完成：

1. 服务器 C++ 完整 IR 和 kernel-only IR 生成。
2. 六类函数发现与 C++ 修饰名处理。
3. 可伸缩步长、尾归纳变量、GEP base 和中心流识别。
4. 3D13P/25P/27P 不透明 plane stride 拓扑回退。
5. 距离、cache 层级、KEEP/STRM 联合决策。
6. 同一 Pass 内边分析边插入。
7. 29 个 IR intrinsic 与 29 条 `PRFM` 一致。
8. 使用原始 `main/test` 的 baseline/prefetch 运行脚本。
9. 12 个 `s1/s2` 场景的初始正确性与三样本性能运行。
10. 按算子执行类别消融并生成服务器 Profile 的自动脚本。

正在进行：

1. 在服务器重建带 Profile 覆盖接口的 Pass。
2. 运行自动类别消融并生成 `profiles/server-sme.env`。

后续工作：

1. 对有效类别扫描距离和 KEEP/STRM。
2. 使用组合 Profile 完成 2 次预热和 7 轮正式测量。
3. 在固定 CPU、频率和系统负载条件下复测。
4. 有条件时加入 PMU 归因和多线程带宽测试。

### 
