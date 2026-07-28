# 断网 AArch64 服务器迁移指南

本文说明如何将 SME1 项目迁移到不能访问互联网的 AArch64 Linux 服务器。
迁移目标是让服务器能够从 `stencil_sme_kernels.c` 重新生成 Linux LLVM
IR、构建 `StencilPrefetchPass.so`、插入预取、运行正确性测试并重新测量
目标服务器上的性能。

最短迁移路径为：

```text
在兼容的联网 AArch64 Linux 机器准备源码和 LLVM 18 完整开发工具链
-> 生成 SHA-256 清单并打包
-> 传入断网服务器并校验
-> 设置 Linux target 和工具链环境变量
-> 重新生成 LLVM IR、.so 插件和 ELF 汇编
-> 先用 generic-sme 通过正确性测试
-> 在服务器上重新调优并建立新的目标 Profile
```

## 一、迁移前必须确认

### 1. AArch64 不等于支持 SME

服务器是 AArch64 只能说明它使用 64 位 Arm 指令集，不能说明 CPU 和 Linux
内核支持 SME。先在服务器执行：

```bash
uname -m
grep -m1 '^Features' /proc/cpuinfo
lscpu
```

至少应确认：

```text
uname -m 输出 aarch64
/proc/cpuinfo 的 Features 包含 sme
```

如果没有 `sme`：

1. 可以构建 LLVM pass 和交叉生成汇编。
2. 不能在该服务器执行 SME kernel。
3. 不能使用该服务器的墙钟或 PMU 数据评价 SME 预取性能。

还需要确认 Linux 内核和用户态允许保存、恢复 SME 线程状态。最直接的
验收方式不是只看 feature 字符串，而是最终成功运行
`05_runtime_validation/build/sme_runtime_info` 和正确性测试。

### 2. 不能直接复制当前 macOS 构建产物

当前仓库中已经生成的部分 LLVM IR 和汇编面向：

```text
arm64-apple-macos
Mach-O
Apple M5
```

例如汇编中可能包含 `.build_version macos`，LLVM IR 中也可能包含 Apple
target triple、Darwin 栈保护和 Apple CPU 属性。这些文件不能作为 Linux
服务器的最终输入。

迁移时可以复制源码和脚本，但必须在服务器上重新生成：

```text
01_llvm_ir_analysis/output/stencil_sme_kernels.ll
02_llvm_pass_plugin/build/StencilPrefetchPass.so
02_llvm_pass_plugin/output/*.ll
02_llvm_pass_plugin/output/*.s
05_runtime_validation/build/*
```

不要把本机的 `.dylib`、Mach-O `.o`、可执行文件或 Apple 汇编当作 Linux
产物使用。

### 3. `apple-m5` Profile 不能默认代表服务器

`apple-m5` Profile 是根据 Apple M5 的 64 B streaming VL、cache 行为和
实测性能得到的：

```text
2D5P：关闭软件预取
3D7P：front/back plane-L1 STRM，distance 1
```

另一款 AArch64 SME CPU 的 cache、内存延迟、streaming VL 和硬件预取器
可能完全不同。服务器迁移应分成两个阶段：

1. 用 `generic-sme` 验证编译器功能和数值正确性。
2. 在服务器上重新扫描距离和类别，再建立服务器专用 Profile。

`apple-m5` 只能作为对照候选，不能直接认定为服务器最优配置。

## 二、推荐的离线交付方式

离线包必须包含项目源码和 Linux AArch64 工具链。macOS 可执行文件不能在
Linux 上运行，因此最好在与目标服务器发行版、glibc 版本接近的联网
AArch64 Linux 机器上准备离线包。

推荐顺序为：

```text
同发行版 AArch64 联网准备机
    -> 下载或构建 LLVM 18、CMake、Ninja
    -> 验证工具链能够运行
    -> 打包源码和工具链
    -> 生成 SHA-256 清单
    -> 通过移动介质或内网传输
    -> 断网服务器校验并解包
```

如果没有联网 AArch64 机器，可以在联网 x86 Linux 机器上准备 ARM64
容器镜像；但最终性能测试必须在真实 AArch64 SME CPU 上原生执行，不能在
QEMU 中评价。

## 三、需要带入断网环境的内容

### 1. 项目源码

在联网机器上进入仓库：

```bash
git status --short
git log -1 --oneline
git bundle create SME1.gitbundle --all
```

`git bundle` 包含提交历史和分支，离线服务器不需要连接 GitHub。也可以
同时生成一份纯源码归档：

```bash
git archive \
  --format=tar.gz \
  --prefix=SME1/ \
  -o SME1-source.tar.gz \
  codex/stencil-sme-kernels
```

如果只需要复现当前分支，源码归档最简单；如果后续还要在离线服务器提交
和切换分支，使用 `git bundle`。

### 2. LLVM/Clang 18 开发工具链

仅有 `clang` 可执行文件不够。构建 pass 至少需要：

```text
bin/clang
bin/clang++
bin/opt
bin/llvm-config
include/llvm/
include/llvm-c/
lib/libLLVM*
lib/cmake/llvm/
LLVM 的运行时共享库
```

LLVM pass 插件必须由与加载它的 Clang/LLVM ABI 兼容的开发包构建。不要
使用 LLVM 18 的头文件构建插件，再用另一主版本 Clang 加载。

建议把完整 LLVM 安装前缀打包，例如：

```bash
tar -C /opt -czf llvm18-aarch64-linux.tar.gz llvm-18
```

在联网准备机上先检查：

```bash
/opt/llvm-18/bin/clang --version
/opt/llvm-18/bin/llvm-config --version
/opt/llvm-18/bin/llvm-config --cmakedir
ldd /opt/llvm-18/bin/clang
```

`ldd` 输出中的动态库也必须存在于断网服务器，或者一并放入工具链目录。
为了避免 glibc 不兼容，准备机与目标服务器应尽量使用相同发行版和版本。

### 3. 构建和运行依赖

还需要：

```text
CMake >= 3.20
Ninja
Python 3
Bash
GNU grep、sed、awk、sort、cmp
Linux C/C++ 开发头文件
pthread
链接器和 libstdc++ 或 libc++
可选：perf、taskset、numactl
```

不要只复制 `/usr/bin/cmake`。独立 CMake 发行包通常还需要同目录下的
`share/cmake-*`。Ninja 通常是单一可执行文件，但仍应在准备机验证。

建议的离线目录结构：

```text
SME1-offline/
  source/
    SME1.gitbundle
    SME1-source.tar.gz
  toolchain/
    llvm-18/
    cmake/
    ninja
  manifest/
    SHA256SUMS
    versions.txt
```

### 4. 记录版本和校验值

在联网准备机执行：

```bash
{
  uname -a
  /opt/llvm-18/bin/clang --version
  /opt/llvm-18/bin/llvm-config --version
  /opt/cmake/bin/cmake --version
  /opt/ninja/ninja --version
  python3 --version
  git -C /path/to/SME1 log -1 --oneline
} > SME1-offline/manifest/versions.txt

cd SME1-offline
find source toolchain -type f -print0 |
  sort -z |
  xargs -0 sha256sum > manifest/SHA256SUMS
```

最后打包：

```bash
cd ..
tar -czf SME1-offline-aarch64-linux.tar.gz SME1-offline
sha256sum SME1-offline-aarch64-linux.tar.gz \
  > SME1-offline-aarch64-linux.tar.gz.sha256
```

## 四、在断网服务器上安装

### 1. 校验离线包

```bash
sha256sum -c SME1-offline-aarch64-linux.tar.gz.sha256
tar -xzf SME1-offline-aarch64-linux.tar.gz
cd SME1-offline
sha256sum -c manifest/SHA256SUMS
```

如果校验失败，应重新传输，不要继续使用损坏的工具链。

### 2. 恢复源码

使用 Git bundle：

```bash
git clone source/SME1.gitbundle SME1
cd SME1
git switch codex/stencil-sme-kernels
```

或者使用源码归档：

```bash
tar -xzf source/SME1-source.tar.gz
cd SME1
```

### 3. 配置离线工具链环境

假设离线包解压到 `/opt/SME1-offline`：

```bash
export OFFLINE_ROOT=/opt/SME1-offline
export LLVM_HOME="${OFFLINE_ROOT}/toolchain/llvm-18"
export CMAKE_HOME="${OFFLINE_ROOT}/toolchain/cmake"

export PATH="${LLVM_HOME}/bin:${CMAKE_HOME}/bin:${OFFLINE_ROOT}/toolchain:${PATH}"
export LD_LIBRARY_PATH="${LLVM_HOME}/lib:${LD_LIBRARY_PATH:-}"

export CLANG="${LLVM_HOME}/bin/clang"
export LLVM_CONFIG="${LLVM_HOME}/bin/llvm-config"
export LLVM_CLANG="${LLVM_HOME}/bin/clang"
export PLUGIN_CC="${LLVM_HOME}/bin/clang"
export PLUGIN_CXX="${LLVM_HOME}/bin/clang++"
export CMAKE="${CMAKE_HOME}/bin/cmake"
export NINJA="${OFFLINE_ROOT}/toolchain/ninja"
export RUNTIME_CLANG="${LLVM_HOME}/bin/clang"
```

验证所有工具来自离线目录：

```bash
command -v clang
command -v llvm-config
command -v cmake
command -v ninja
clang --version
llvm-config --version
llvm-config --cmakedir
python3 --version
```

如果服务器已有兼容工具，也可以直接设置这些变量指向系统路径。

## 五、AArch64 Linux 必须修改或覆盖的默认值

### 1. 步骤 1 的 target triple

`01_llvm_ir_analysis/generate_and_check.sh` 当前默认：

```text
arm64-apple-macos15
```

在 Linux 服务器必须覆盖为：

```bash
export TARGET=aarch64-unknown-linux-gnu
export MARCH=armv9.2-a+sme+sve2
```

然后运行：

```bash
CLANG="${LLVM_HOME}/bin/clang" \
TARGET=aarch64-unknown-linux-gnu \
MARCH=armv9.2-a+sme+sve2 \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

这一步必须重新生成 Linux IR，不能继续使用仓库中从 Apple Clang 生成的
IR。

### 2. 步骤 2～4 的工具默认路径

`02_llvm_pass_plugin/build_and_test.sh` 默认引用当前开发机工作区中的
Polygeist、CMake.app 和 Ninja。Linux 服务器应显式传入：

```bash
LLVM_CONFIG="${LLVM_HOME}/bin/llvm-config" \
LLVM_CLANG="${LLVM_HOME}/bin/clang" \
PLUGIN_CC="${LLVM_HOME}/bin/clang" \
PLUGIN_CXX="${LLVM_HOME}/bin/clang++" \
CMAKE="${CMAKE_HOME}/bin/cmake" \
NINJA="${OFFLINE_ROOT}/toolchain/ninja" \
  ./02_llvm_pass_plugin/build_and_test.sh
```

Linux 上插件输出应为：

```text
02_llvm_pass_plugin/build/StencilPrefetchPass.so
```

而不是 macOS 的 `.dylib`。

### 3. 必须重新生成 Linux 汇编

步骤 2～4 成功后检查：

```bash
head -n 10 02_llvm_pass_plugin/output/stencil_sme_kernels.ir-baseline.s
head -n 10 02_llvm_pass_plugin/output/stencil_sme_kernels.s
file 02_llvm_pass_plugin/build/StencilPrefetchPass.so
```

Linux 汇编不应再包含：

```text
.build_version macos
```

LLVM IR 的 target triple 应为：

```text
aarch64-unknown-linux-gnu
```

### 4. 当前回归脚本的已知可移植性风险

`build_and_test.sh` 中的短循环 fixture 通过替换当前 IR 的特定 SSA 文本
构造。不同 Clang 版本或 Linux target 可能改变 SSA 编号，使该回归用例
失败，即使 pass 主功能是正确的。

遇到这种情况时应区分：

1. 插件构建、正例识别和预取插入失败：属于真正的迁移阻塞。
2. 只有短循环 fixture 的文本替换失败：属于测试 fixture 可移植性问题。

不要为了让测试通过而直接使用旧的 Apple IR。正式迁移前，推荐把短循环
fixture 改成独立、固定的 Linux 无关 LLVM IR 测试。

## 六、在服务器上的推荐运行顺序

### 1. 清理本机生成物

不要复用从 macOS 带来的构建目录：

```bash
rm -rf 02_llvm_pass_plugin/build
rm -rf 05_runtime_validation/build
```

如果离线介质中的 `output/` 包含 Apple 产物，可以保留作为历史参考，但
后续必须由服务器脚本覆盖生成。

### 2. 生成 Linux LLVM IR

```bash
CLANG="${LLVM_HOME}/bin/clang" \
TARGET=aarch64-unknown-linux-gnu \
MARCH=armv9.2-a+sme+sve2 \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

验收：

```bash
grep 'Target' 01_llvm_ir_analysis/output/analysis_report.md
grep 'target triple' 01_llvm_ir_analysis/output/stencil_sme_kernels.ll
```

### 3. 构建并测试 pass

```bash
LLVM_CONFIG="${LLVM_HOME}/bin/llvm-config" \
LLVM_CLANG="${LLVM_HOME}/bin/clang" \
PLUGIN_CC="${LLVM_HOME}/bin/clang" \
PLUGIN_CXX="${LLVM_HOME}/bin/clang++" \
CMAKE="${CMAKE_HOME}/bin/cmake" \
NINJA="${OFFLINE_ROOT}/toolchain/ninja" \
  ./02_llvm_pass_plugin/build_and_test.sh
```

验收：

```bash
test -f 02_llvm_pass_plugin/build/StencilPrefetchPass.so
grep -F '总体结果：**PASS**' \
  02_llvm_pass_plugin/output/plugin_test_report.md
grep -E 'prfm|prfum' \
  02_llvm_pass_plugin/output/stencil_sme_kernels.s
```

### 4. 先运行 generic Profile 正确性

服务器 CPU 未经调优时先使用 `generic-sme`：

```bash
SME_RUNTIME_PROFILE=generic-sme \
RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/build_and_run.sh
```

如果脚本未能从 `/proc/cpuinfo` 检测到 SME，但已经通过其他方式确认 CPU
和内核支持 SME，可以临时加入：

```bash
FORCE_SME_RUN=1
```

不要在 CPU 不支持 SME 时强制运行，否则会触发非法指令。

验收：

```bash
cat 05_runtime_validation/output/runtime_info.log
cat 05_runtime_validation/output/correctness_report.md
```

必须确认：

```text
正确性状态为 PASS
baseline 与 prefetch 都通过
streaming_vl_bytes 是有效正数
```

### 5. 运行配对性能基线

```bash
SME_RUNTIME_PROFILE=generic-sme \
RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/run_paired_benchmark.sh
```

固定 CPU 和 NUMA 节点后再做正式测量，例如：

```bash
taskset -c 0 \
  env SME_RUNTIME_PROFILE=generic-sme \
      RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/run_paired_benchmark.sh
```

具体 CPU 编号应根据服务器拓扑选择，不应机械使用 CPU 0。

### 6. 为服务器重新调优

依次运行：

```bash
RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
LLVM_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/run_profile_sweep.sh

RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
LLVM_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/run_ablation.sh
```

根据以下数据建立服务器 Profile：

```text
实际 streaming VL
L1/L2 cache 容量
row 和 plane 大小
最佳预取距离
KEEP/STRM 策略
单线程与多线程结果
PMU cache miss 和带宽变化
```

在服务器 Profile 固化之前，实验参数可以通过现有
`SME_PREFETCH_USEFUL_CYCLES_*`、`SME_PREFETCH_ENABLE_*` 和预算环境变量
覆盖。

## 七、Linux PMU 替代方案

以下脚本不能迁移到 Linux：

```text
05_runtime_validation/collect_cpu_counters.sh
05_runtime_validation/run_cpu_counter_comparison.sh
```

它们依赖 macOS Xcode `xctrace` 和 Instruments 用户模板。Linux 服务器应
使用 `perf` 或服务器厂商提供的 PMU 工具。

先构建供 `perf` 启动的两个独立可执行文件：

```bash
SME_RUNTIME_PROFILE=generic-sme \
STENCIL_BUILD_ONLY=1 \
RUNTIME_CLANG="${LLVM_HOME}/bin/clang" \
  ./05_runtime_validation/run_benchmark.sh
```

先查看可用事件：

```bash
perf list
perf stat -- true
```

可以从通用事件开始：

```bash
perf stat \
  -e cycles,instructions,cache-references,cache-misses \
  -- ./05_runtime_validation/build/stencil_benchmark.baseline \
  3d 512 32 1024 32 7
```

然后对预取版本使用完全相同的事件、规模和线程绑定：

```bash
perf stat \
  -e cycles,instructions,cache-references,cache-misses \
  -- ./05_runtime_validation/build/stencil_benchmark.prefetch \
  3d 512 32 1024 32 7
```

不同 Arm CPU 的 L1D、L2、LLC 和内存控制器原始事件编号不同。不要直接把
Apple M5 的 `ARM_L1D_CACHE_*` 或 `PL2_CACHE_*` 名称照搬到服务器。
应以 `perf list`、CPU 技术参考手册和服务器厂商文档为准。

如果 `perf_event_paranoid` 或容器权限阻止 PMU 访问，需要服务器管理员在
离线部署前配置权限。不要在没有 PMU 权限时把全零计数解释为 cache miss
为零。

## 八、容器迁移方案

如果服务器允许 Docker 或 Podman，容器通常比手工复制共享库更可靠。

在联网机器构建 `linux/arm64` 镜像，镜像中包含：

```text
LLVM/Clang 18 开发包
CMake
Ninja
Python 3
Git
项目源码
Linux 开发头文件
```

示意流程：

```bash
docker buildx build \
  --platform linux/arm64 \
  --load \
  -t sme1-offline:llvm18 .

docker save sme1-offline:llvm18 |
  gzip > sme1-offline-llvm18-arm64.tar.gz

sha256sum sme1-offline-llvm18-arm64.tar.gz \
  > sme1-offline-llvm18-arm64.tar.gz.sha256
```

断网服务器：

```bash
sha256sum -c sme1-offline-llvm18-arm64.tar.gz.sha256
gzip -dc sme1-offline-llvm18-arm64.tar.gz |
  docker load
docker run --rm -it \
  -v "$PWD/results:/work/SME1/05_runtime_validation/output" \
  sme1-offline:llvm18
```

注意：

1. 镜像必须是 `linux/arm64`，不能把 macOS 镜像或 x86 镜像当作目标环境。
2. 正确性和性能测试必须在真实 SME CPU 上原生执行。
3. 容器运行时不能屏蔽 SME 指令状态。
4. PMU 测量可能需要额外 capability 或直接在宿主机运行。
5. 为获得稳定性能，仍需固定 CPU、NUMA 节点和频率策略。

## 九、正式迁移前建议修改的代码

当前代码可以通过环境变量覆盖大部分路径，但为了长期在 Linux 服务器使用，
建议后续完成以下改动：

1. 把步骤 1 默认 target 从 Apple 常量改为根据 `uname` 选择。
2. 把步骤 2～4 的 CMake/Ninja/LLVM 默认路径改为优先使用 `PATH`。
3. 将短循环 fixture 从 SSA 文本替换改为固定测试 IR。
4. 将运行报告中的“Apple M5”改为自动读取 CPU 型号。
5. 增加 Linux `perf` 采集和报告脚本。
6. 为服务器新增独立 Profile，不复用 `apple-m5` 名称。
7. 在联网准备机增加一键生成离线包和 SHA-256 清单的脚本。

这些改动不会改变预取分析算法，但会显著降低迁移时的人工操作和误用风险。

## 十、迁移验收清单

### 文件和工具

- [ ] 离线包 SHA-256 校验通过。
- [ ] `clang`、`clang++`、`llvm-config` 来自同一 LLVM 版本。
- [ ] `llvm-config --cmakedir` 指向有效 LLVM CMake 配置。
- [ ] CMake、Ninja、Python 3 和 Linux 开发头文件可用。

### 目标机器

- [ ] `uname -m` 为 `aarch64`。
- [ ] CPU 和 Linux 内核实际支持 SME。
- [ ] `sme_runtime_info` 能执行并返回 streaming VL。
- [ ] 性能测试固定了 CPU/NUMA 和问题规模。

### 项目流水线

- [ ] 步骤 1 重新生成 `aarch64-unknown-linux-gnu` LLVM IR。
- [ ] Linux 上重新构建 `StencilPrefetchPass.so`。
- [ ] Linux 上重新生成基线和预取汇编。
- [ ] 汇编中不存在 `.build_version macos`。
- [ ] 插件、识别和预取决策测试通过。
- [ ] 正确性报告为 `PASS`。
- [ ] baseline/prefetch checksum 一致。
- [ ] 先完成配对墙钟测试，再解释 PMU 数据。
- [ ] 服务器 Profile 经过距离、类别和多线程复测。

完成以上检查后，才可以认为当前方案已经从 Apple M5 开发环境可靠迁移到
断网 AArch64 Linux 服务器。
