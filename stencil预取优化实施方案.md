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
  = ceil(transfer_latency_cycles(source -> level)
         / scaled_cycles_per_vector_iteration)
```

其中：

- `d_iterations`：预取领先真实 load 的向量迭代次数。
- `transfer_latency_cycles`：由相邻层级命中延迟差推导的数据提升时间；L1 使用
  L2 -> L1，L2 warming 使用 memory -> L2，而不是直接套用目标层命中延迟。
- `scaled_cycles_per_vector_iteration`：以最小 2D/3D stencil 的实测周期为基准，
  按当前循环的逻辑 load 数量缩放，避免 5P/9P 和 7P/27P 共用同一周期。
- `ceil`：向上取整，避免静态提前时间低于目标延迟。

该公式对一个“物理流 + 目标 cache 层级”直接产生一个具体距离；这里的“距离候选”
是指等待安全性和预算准入的一条模型决策，不是供调优脚本枚举的一组数值。

转换为未来地址偏移：

```text
d_elements = d_iterations * scalable_vector_step
future_x   = current_x + d_elements
```

对当前 `double` kernel，`scalable_vector_step` 对应 `svcntd()`；Pass 不把
streaming vector length 固定为编译期常量，而是复用 IR 中的可伸缩步长。

距离候选必须满足：

```text
transfer_latency_cycles > 0
scaled_cycles_per_vector_iteration > 0
d_iterations >= 1
future_x < inner_loop_end
inner_trip_count > 2 * d_iterations
```

如果无法静态证明未来地址仍在合法范围，Pass 必须用运行时条件跳过越界
`PRFM`，或者拒绝该候选；不能生成带 `inbounds` 承诺的越界未来地址。

### 2.4 Cache 层级模型

目标 cache 层级回答“数据先放到哪里”。当前模型不估算完整 row/plane 工作集，只
计算已经准入的预取前沿在数据被使用前可能占用的字节：

```text
prefetch_live_bytes(stream, level)
  = d_iterations(stream, level)
  * bytes_per_vector_iteration(stream)

prefetch_frontier_bytes(level)
  = base_frontier_bytes(level)
  + sum(prefetch_live_bytes(stream, level))
```

层级候选需满足：

```text
prefetch_frontier_bytes(level) <= effective_cache_budget(level)
```

初始规则：

1. row 邻域生成 L1 候选，plane 邻域可生成 L1 near 和 L2 warming 候选。
2. plane warming 的 L2 候选使用更长延迟计算距离，避免过早占用 L1。
3. 当前不默认使用 L3，因为服务器共享末级 cache 的可控性和竞争情况尚未测定。
4. 一条 plane 流可同时具有远距离 L2 和近距离 L1 两个候选。

### 2.5 KEEP/STRM 模型

KEEP/STRM 决策依据是 LLVM IR 中可证明的直接复用，不是“地址是否连续”，也不
依赖 row/plane 的具体字节数：

```text
policy(stream, level)
  = KEEP, if grouped_load_count(stream) > 1
  = STRM, otherwise
```

当前原则：

1. 去重后只有一个 cache-line 内逻辑 load 的单调流选择 STRM。
2. 只有 SCEV 能证明多个 load 位于同一 cache line 时，row/current 流才选择 KEEP。
3. 2D9P 和 3D27P 的同一物理流包含更多相邻逻辑 load，复用计数高于 5P/star
   中的单邻居流。
4. 不能仅凭跨外层循环“可能再次出现”选择 KEEP，因为 LLVM IR 层尚未证明其复用
   窗口；这类平面流保守选择 STRM。
5. plane-L1 和 plane-L2 均强制 STRM；显式 Profile 覆盖仍可用于受控实验，但
   AUTO 不在缺少外层复用窗口和驻留证明时选择 KEEP。

### 2.6 联合决策

每个候选保存：

```text
PrefetchDecision {
  enable
  stream
  distance_iterations
  cache_level
  policy
  hidden_cycles
  benefit_score
  cost_score
  profit_score
  confidence_percent
  reject_reason
}
```

决策顺序：

1. 计算距离候选。
2. 选择 cache 层级。
3. 根据物理流内的直接复用证据选择 KEEP/STRM。
4. 根据隐藏延迟和复用计算收益，根据发射、cache 压力、带宽及未知 trip count 计算
   成本。
5. 检查全局最低收益和最低置信度。
6. 候选先按收益分数、置信度排序，结构优先级只用于同分候选，再执行容量、流、
   指令和字节预算准入。
7. 对未准入候选保留 `LowConfidence`、`Unprofitable` 或资源拒绝原因，但不插入 IR。

联合约束：

```text
enabled_streams <= max_streams
inserted_prefetches <= instruction_budget
prefetch_frontier_bytes(L1) <= L1_budget
prefetch_frontier_bytes(L2) <= L2_budget
future_address_is_safe == true
profit_score >= min_profit_score
confidence_percent >= min_confidence
```

因此“预取决策数”不是最终插入数。以下是引入统一评分模型前的历史服务器报告，
更新后的数量必须在服务器重新执行步骤 04 后确认：

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

这些优先级是确定性的初始模型，不依赖具体矩阵大小。距离和 AUTO 策略由分析模型
产生；第三部分的逐算子性能实验只验证并关闭无收益类别，不用示例尺寸替换模型。

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
3. 计算一次 `future_x < loop_end` 条件；相同距离的候选在支配关系允许时共享该条件。
4. 用 `select(in_range, future_address, current_address)` 形成安全地址并无条件发出
   intrinsic，不在最内层循环中为每条预取拆分条件基本块。
5. 保持原 masked load/store 和数值计算不变。
6. 已存在相同预取时不重复插入，保证幂等。

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
05_runtime_validation/output/server-module/program_time_seconds.tsv
05_runtime_validation/output/server-module/wall_time_seconds.tsv
```

逐算子加速比为：

```text
speedup = median_time(baseline) / median_time(prefetch)
```

`speedup > 1` 表示预取版本更快。





### 3.8 性能结果的解释和 Profile 回写

当前 29 条 `PRFM` 只证明插入链路正确，不证明全部预取都有收益。性能分析按以下
顺序进行：

1. 检查原始 main/test 的数值正确性。
2. 从 `program_time_seconds.tsv` 读取原程序 `Total Time`，分别计算 baseline 和
   prefetch 的中位数。
3. 使用全部已知 `s1/s2` 场景联合选择候选，任何一个规模退化都拒绝候选。
4. 重新运行全部已知场景，检查组合 Profile 的正确性和稳定性。
5. 最后再使用 PMU 检查 cache miss、TLB miss、内存带宽和预取有效性。

#### 3.8.1 用例清单

`profiles/tuning_cases.csv` 是调优和验证的共同输入：

```text
argument,kind,size_class,role,weight
```

| 列 | 含义 |
|---|---|
| `argument` | 传给原始 `main` 的单个测试参数 |
| `kind` | stencil 类型 |
| `size_class` | 用例规模类别，例如 L1、L2、DRAM |
| `role` | `train` 参与联合选择；`validate` 保留给未来独立留出场景 |
| `weight` | 该训练场景在综合得分中的权重 |

当前服务器入口只有固定的 `s1/s2` 参数，而且两个规模差异明显。若只用 `s1` 选择、
只用 `s2` 验收，训练数据只覆盖一种规模，容易得到明显偏向 `s1` 的策略。因此默认
将二者都标记为 `train`，共同选择一个覆盖已知工作负载的 Profile。服务器 `main`
增加可变尺寸入口后，应为每种算子补充 L1、L2、DRAM 等更多规模；只有规模数量足够
时，才划出独立 `validate` 场景检验未知规模泛化。

#### 3.8.2 统一收益模型和阈值范围

Pass 对每个结构候选计算：

```text
hidden_cycles = min(transfer_latency, distance * scaled_cycles)
benefit = hidden_cycles * reuse_multiplier * confidence_percent / 100

cost = issue_cost
     + cache_pressure_percent * cache_pressure_weight
     + bandwidth_percent * bandwidth_weight
     + unknown_trip_count_penalty

profit_score = benefit - cost
```

已知 trip count 的候选置信度为 100；未知 trip count 的候选降低为 70，L2 warming
候选再降低 10。置信度不仅是准入门槛，还直接折减预测收益。候选只有满足
`profit_score >= min_profit_score`、
`confidence >= min_confidence`，并继续通过容量、流数、指令数和字节预算时才插入。

`scripts/04_tune_server_profile.sh` 不再枚举 current/row/plane 类别组合，也不生成
算子 mask。它先以阈值 0 仅编译一次，从 `pass_run.log` 收集分析模型实际产生的整数
score。若唯一 score 为 `s1 < s2 < ...`，实测阈值集合自动构造为：

```text
0, s1 + 1, s2 + 1, ...
```

每个边界只会排除一组由模型判为更低收益的候选，因此候选值来自分析模型，而不是
脚本人为定义。最高 score 加一对应统一关闭全部候选，可作为安全 baseline 回退。

#### 3.8.3 统计选择条件

每个场景先计算：

```text
speedup(case) = median(baseline_time) / median(prefetch_time)

relative_mad(case)
  = max(MAD(baseline) / median(baseline),
        MAD(prefetch) / median(prefetch))

weighted_geomean(candidate)
  = exp(sum(weight_i * ln(speedup_i)) / sum(weight_i))
```

每个全局阈值默认必须同时满足：

```text
每个训练场景 speedup >= 1.00
加权几何平均 speedup >= 1.03
最大 relative_mad <= 0.03
```

对应覆盖变量为 `STENCIL_TUNE_MIN_CASE_SPEEDUP`、
`STENCIL_TUNE_MIN_GEOMEAN` 和 `STENCIL_TUNE_MAX_RELATIVE_MAD`。单样本运行时
MAD 恒为 0，只能验证自动化链路，不能作为稳定性能结论。

#### 3.8.4 硬件参数和结果复用

调优脚本在 Linux sysfs 中读取 L1/L2 容量和 cache line，并从
`/proc/sys/abi/sme_default_vector_length` 读取进程 exec 后采用的 streaming VL。
任一硬件值无法读取时必须显式提供实测值，脚本不再静默回退。以下硬件与分析输入
直接提供给分析模型，用于逐函数生成具体距离和准入结果：

```text
streaming VL
L1/L2/内存预取延迟
L1/L2 有效容量占比
每次向量迭代的有效计算周期
初始最大距离、流预算、指令预算和字节预算
```

这些输入按来源分为两类：Cache 容量、cache line 和 streaming VL 从 Linux 接口
自动读取；latency 和 useful cycles 由目标机微基准或 PMU 校准。容量比例与资源预算
是模型约束，不是可从 sysfs 读取的硬件事实，
必须在服务器模型文件中明确记录其依据和值。模板为
`profiles/server-model.env.example`，本地结果写入被忽略的 `profiles/server-model.env`。
任何必需输入缺失时步骤 4 直接停止，不再使用 generic SME 回退值。

`scripts/calibrate_server_model.sh` 实现一次性自动校准：随机依赖加载在 L1、L2 和
超过末级 cache 的工作集上通过 `perf_event_open` 测量 CPU cycles；代表性 2D5P
和 3D7P SVE 循环测量每个向量迭代的有效周期。选择同维度中较轻的 stencil 是为了
得到计算周期下界，避免距离模型低估所需提前量。L1/L2 有效容量按相联度各保留一个
cache way。资源微基准扫描 1 至 17 条独立随机内存流，记录每条 cache line 的周期，
并选择达到扫描中近峰值吞吐（最佳值 5% 内）所需的最小流数作为 `max_streams`；
指令和字节预算再由该实测流数及 `ceil(streaming_VL/cache_line)` 推导。因此 17 只是
扫描上限，不再作为预算默认值。流扫描次数可通过
`SME_CALIBRATION_STREAM_ACCESSES` 独立控制，避免显著放大已有延迟测试的运行时间。
PMU 不可访问时校准失败，不回退墙钟估算。

矩阵 row/plane/working-set 字节数不再出现在清单、校准输入或最终 Profile 中。
校准还根据实测周期和流数生成 `issue_cost`、`cache_pressure_weight`、
`bandwidth_weight` 和 `unknown_trip_count_penalty`。这些参数与其余硬件参数同时用于
候选编译、候选缓存签名和最终 Profile，避免
“调优时一组参数、最终编译另一组参数”。实际硬件信息和有效值记录在：

```text
issue_cost = ceil(min(useful_cycles_2d, useful_cycles_3d) / max_streams)
cache_pressure_weight = l1_latency
bandwidth_weight = ceil(memory_latency / max_streams)
unknown_trip_count_penalty = ceil(l2_latency / 2)
```

```text
05_runtime_validation/output/server-profile-tuning/hardware_metadata.txt
```

默认启用 `STENCIL_TUNE_RESUME=1`。只有清单校验和、全局阈值、硬件模型参数、用例、
预热次数和样本数全部相同，才复用已有测量。正式重测可设置
`STENCIL_TUNE_RESUME=0`。

#### 3.8.5 Profile 生成和最终复测

调优输出包括：

```text
05_runtime_validation/output/server-profile-tuning/candidate_results.csv
05_runtime_validation/output/server-profile-tuning/profile_selection.csv
05_runtime_validation/output/server-profile-tuning/decision_inventory.csv
05_runtime_validation/output/server-profile-tuning/threshold_diagnostics.csv
05_runtime_validation/output/server-profile-tuning/diagnostic_report.md
profiles/server-sme.env
```

诊断报告自动关联 score、stream/cache 结构、threshold、admitted 数、IR PRFM 数和逐用例
性能。默认告警包括：最高 threshold 已无预取但仍明显偏离 baseline、决策与实际插入
数量不一致、一个 threshold 同时改善和退化不同训练用例，以及同一 score 桶包含多种
结构而无法被全局 threshold 分离。终端打印版本使用紧凑的 `SEL/SCORE/THR/ALERT`
单行格式，便于手工抄写；CSV 保留完整数据。该报告用于判断下一步应先修复测量链路、
插入链路还是评分模型，不能用来放宽正式性能门槛。

`server-sme.env` 回写全局 `min_profit_score`、`min_confidence` 和硬件校准得到的成本
参数，不包含算子 mask 或类别开关。距离保持 `0`、策略保持 `AUTO`，Pass 对每个函数
和每条物理流计算具体距离、策略和评分。调优不人为提供距离、策略、容量比例或类别
组合，只在模型自身形成的 score 边界中选择一个全局阈值。因此分析模型是决策主体，
实测只校准统一准入边界。

搜索期间先写 `server-sme.env.tuning`，全局阈值选择成功后才原子替换最终 Profile，
因此中断不会破坏已有结果。具体模型决策可在每次构建输出的 `pass_run.log` 中查看，
其中包含 function、stream、distance、level、policy 和准入原因。

`scripts/05_validate_tuned_profile.sh` 加载组合 Profile，重新执行清单中的全部正确性
测试和性能采样。默认清单没有 `validate` 行，因此全部 `train` 场景共同决定性能
是否通过；未来加入独立 `validate` 行后，脚本会自动只使用留出场景执行性能门槛：

```text
speedup >= 1.00
relative_mad <= 0.03
```

任一场景不满足条件时脚本返回非零。结果保存在：

```text
05_runtime_validation/output/server-profile-final/profile_validation.csv
05_runtime_validation/output/server-profile-final/runtime_validation_report.md
```

若最终全局阈值关闭全部软件预取，验证流程允许 IR 中预取数为 0，这代表该服务器
选择 baseline，而不是 Pass 插入失败；结果状态记为 `BASELINE`，不再用两个等价
版本的计时噪声触发性能失败。

#### 3.8.6 当前泛化边界

当前 Profile 已不再记忆 stencil 类型，只保存硬件参数和统一评分阈值，因此新增算子
只要能被物理流分析识别，就可直接使用同一规则。但阈值仍由已知 `s1/s2` 用例选择，
最终复测也使用参与选择的数据，所以不能据此证明未知规模或跨机器泛化。扩展泛化
能力仍应优先增加不同规模、边界形态和新算子的 `validate` 用例，而不是重新引入
矩阵具体尺寸或按算子位图。

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
9. 12 个 `s1/s2` 场景的原始 main/test 正确性和性能运行入口。
10. 基于 manifest 的已知工作负载联合调优和可选留出接口。
11. 从 Pass score 自动生成全局阈值边界并自动生成无算子 mask 的服务器 Profile。
12. 中位数、加权几何平均、最差场景和相对 MAD 联合门槛。
13. Linux cache 参数探测、完整决策输入回写和候选签名恢复。
14. 组合 Profile 的正确性与稳定性能复测。
15. Pass 的 cache、VL、延迟、容量比例和距离覆盖接口；具体矩阵大小已移除。
16. 服务器快速与正式调优临时脚本 `tmp0.sh` 至 `tmp3.sh`。
17. 分析模型主导的距离、策略、收益和置信度决策与全局阈值写回。
18. 预取尾部使用条件发射，越界时真正跳过 `PRFM`，不再重定向为当前地址。
19. 流、指令和字节预算改由目标机独立流 PMU 扫描测量，不再固定采用 17 条拓扑上限。
20. 距离按层级传输延迟和循环逻辑 load 数缩放，置信度直接折减收益。
21. plane-L1/L2 AUTO 策略均为 STRM，并拒绝距离重叠的 L1/L2 分级候选。
22. streaming VL 跨越多条 cache line 时，一条决策发出对应数量的 `PRFM`。

服务器当前待执行：

1. 拉取最新迁移分支并重新构建带扩展 Profile 接口的 Pass。
2. 运行快速调优和快速复测，确认自动化链路。
3. 运行正式调优，生成服务器本地 `profiles/server-sme.env`。
4. 完成正式复测并检查所有场景是否为 PASS。

后续工作：

1. 为每种算子增加 L1、L2、DRAM 多规模用例，再恢复独立留出集。
2. 在固定 CPU、频率和系统负载条件下复测。
3. 有条件时加入 PMU 归因和多线程带宽测试。
4. 若静态 Profile 无法跨规模稳定获益，实现 loop versioning 和运行时分派。

### 3.10 服务器执行顺序

服务器拉取 `codex/offline-aarch64-migration` 后，先设置毕昇 C++ 驱动：

```bash
export BISHENG_CXX=/path/to/bisheng/bin/clang++
```

若步骤 1 生成的完整 IR 仍然存在且原 C++ 未变化，只需重新构建 Pass：

```bash
./scripts/01_check_standalone_llvm_ir.sh
./scripts/02_build_and_test_pass.sh
```

随后按顺序执行：

```bash
./scripts/tmp0.sh  # 0 次预热、1 个样本的快速全局阈值调优
./scripts/tmp1.sh  # 单样本链路和正确性检查，不执行正式性能门槛
./scripts/tmp2.sh  # 1 次预热、3 个样本的正式调优
./scripts/tmp3.sh  # 1 次预热、3 个样本的正式稳定性能复测
```

`tmp0.sh/tmp2.sh` 只测试分析模型自动生成的 score 边界，不扫描距离、策略、类别组合
或资源参数。`tmp2.sh`
默认启用候选签名复用，样本数或模型输入改变时会自动失效，因此中断后可以直接
续跑。

正式验收依次检查：

1. `profile_selection.csv` 中全局收益阈值和预取数量是否合理。
2. `hardware_metadata.txt` 中 cache 和有效模型参数是否符合服务器。
3. `server-sme.env` 中全局评分参数是否与选择结果一致，且不存在算子 mask。
4. `profile_validation.csv` 是否为 `PASS`，或明确回退为 `BASELINE`。
5. `runtime_validation_report.md` 中 baseline/prefetch 正确性是否通过。

只有上述检查全部满足，生成的 `profiles/server-sme.env` 才作为当前服务器的可用
Profile。该文件是服务器本地结果并已加入 `.gitignore`，不应提交为通用默认值。
