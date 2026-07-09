### 2.**MLIR 语义层**

把输入的c代码转换成以下层级的mlir

`linalg` 层

`affine/scf` 层

`vector` 层

`arm_sme`层

gpt给的方案：

```
这份 gemm_mlir_kernel.c 提供规则循环和矩阵乘语义。
你自己的工具识别注释和循环结构，把它变成高层 MLIR。
再复用 LLVM/MLIR 现有的 vector / ArmSME pass 往下走。

具体流程如下：
C kernel
-> 自定义提升器
-> 高层 MLIR（linalg / scf / affine）
-> vector 化
-> ArmSME lowering
-> LLVM
```

### 3.**高层语义分析**

在 `linalg` 层 IR 上判断数据流的整体性质。

```
当前数据是小而热，还是大而冷？
是规则密集计算，还是稀疏/条件计算？
是适合保留在缓存，还是应该流式处理？
哪些数据流可能污染 L2/LLC？
例如：
小块矩阵、多次复用的数据：倾向 KEEP
大数组顺序扫描、只用一次的数据：倾向 STRM
稀疏 gather 数据：倾向低保留、低污染策略
Stencil 中短距重用数据：可能不需要预取
这一阶段产生的是粗粒度策略，比如：某个数据流应该走 KEEP，某个数据流应该走 STRM。

KEEP 和 STRM 是 Arm 预取指令里的 缓存保留策略 hint，用来告诉硬件：预取进来的数据，应该“尽量留着”，还是“用完就别污染缓存”。
```

### 4.**中层循环与多面体分析**

在 `affine` 层分析循环、访存函数和重用距离

```
提取循环迭代空间
提取访存表达式，如 A[i][j]、A[i+1][j]
计算 stride、reuse distance、working set
判断访问是否跨 cache line、跨行、跨平面
判断硬件自动预取器是否能覆盖
计算预取距离 D

D = ceil(Memory_Latency_Cycles / SME_Compute_Cycles_Per_Block)
如果一次内存访问要等很多周期，而 SME 处理一个 block 需要若干周期，那么就提前 D 个 block 发出预取，让访存延迟被计算覆盖。
```

### 







### 5.**Transform Dialect 决策与 IR 注入**

定义Transform Dialect ，Transform Dialect 相当于编译器的优化插件，根据前面的信息，对原始MLIR IR进行改写

输入：

```
原始 MLIR IR
+ 预取策略
+ 硬件画像
+ Transform Dialect 控制脚本
```

输出：

```
插入了预取、地址计算、掩码和边界保护的新 MLIR IR
```

### 6.**Vector/SVE/LLVM 降级**

输入是阶段 6 产出的 **带预取操作的 MLIR IR**

输出是带 LLVM/SVE intrinsic 的 LLVM IR

需要保留上层的预取信息，但是通用llvm的预取指令没有 目标缓存层级 预取策略：`KEEP / STRM` Predicate mask：用于条件预取或 gather prefetch 等信息

```
declare void @llvm.prefetch.p0.i32(i8* <addr>, i32 <rw>, i32 <locality>, i32 <cache_type>)


addr：要预取的内存地址（任意指针类型需 bitcast 到 i8*）
rw：
	0 = 读预取
	1 = 写预取
locality：局部性提示（0～3）
	0 = 无局部性（一次性使用）
	3 = 高局部性（很快会再次访问）
cache_type：
	0 = 数据缓存
	1 = 指令缓存
	（但多数后端只使用 0）
```

```
gemini：
语义信息无损传递（Zero-Semantic-Loss）：
MLIR 的高级属性（如 vector.gather_prefetch 中绑定的掩码和特定架构参数）可以直接完美映射为标准 LLVM IR 中的 Target-specific Intrinsics（例如 @llvm.aarch64.sve.prfw）。毕昇编译器在读入这种形式的 LLVM IR 时，能够无缝识别其完整的硬件语义（包括寄存器约束和掩码关系）。
```

Target-specific Intrinsic 是专门服务某个硬件架构的 intrinsic。

```
@llvm.aarch64.sve.prfw
```

直接使用 `mlir-opt + mlir-translate`无法实现，需要人工编写Pass让mliropt调用，从而将之前的mlir编译成llvmir

### 7.**毕昇编译与 LX2 实机验证**

需要验证：

1. 毕昇能不能正确编译出目标预取指令

2. 这些预取指令在 LX2 真实硬件上有没有性能收益

将llvm ir编译成汇编，确定：

```
LLVM IR 能否被毕昇接受
SVE intrinsic 是否被识别
predicate/gather 语义是否保留
KEEP/STRM 是否映射到正确 prfop
最终汇编中是否出现 PRFW/svprfw
```

```
-O3：开启毕昇最激进的全局优化。
-march=armv9-a：激活 SVE2 和 SME 的硬件指令集支持（确保 svprfw 不会被退化为标量操作）。
-mllvm -enable-implicit-prefetching=false（或相关选项）：重要！ 论文中如果想单纯验证你的“多面体分析模型”的效能，建议通过此项或类似参数关闭毕昇自带的纯启发式硬件/软件预取猜测，从而实现对你自己的多面体模型的“净效果”评测，排除毕昇原生软件预取的干扰。
```



实验一：利用毕昇编译器编译三个版本并在 LX2 上运行，配合 ARM PMU 计数器（如 `perf stat -e r0004` 等硬件事件）抓取 L2D 缺失率：

1. **Baseline 1 (No Prefetch)**：原始代码，纯靠硬件自动预取。
2. **Baseline 2 (BiSheng Native Prefetch)**：开启毕昇编译器自研的软件预取优化。
3. **Proposed (MLIR Polyhedral Model + BiSheng)**：关闭毕昇自带预取，由你的多面体模型控制发射

实验二：不规则控制流下的带宽与吞吐表现（FlagGEMM）

在不同的 Flag 稀疏度（0.1 到 0.9）下，对比性能（GFLOPS）