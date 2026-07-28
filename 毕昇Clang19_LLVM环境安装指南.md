# 毕昇 Clang 19 对应 LLVM 环境安装指南

本文面向可联网的 AArch64 Linux 服务器。服务器当前已有：

```text
BiSheng Enterprise 5.1.0.2
clang version 19.1.7
```

目标是在服务器上构建并加载本项目的 `StencilPrefetchPass.so`，从原始
SME/SVE C kernel 生成 LLVM IR、插入 `llvm.aarch64.prefetch`，最终检查
AArch64 汇编中的 `PRFM` 并运行正确性与性能测试。

## 一、关键结论

### 1. 只有 `clang` 可执行文件还不够

本项目的 `02_llvm_pass_plugin/CMakeLists.txt` 使用：

```cmake
find_package(LLVM REQUIRED CONFIG)
include(AddLLVM)
add_llvm_pass_plugin(StencilPrefetchPass ...)
```

因此构建插件至少还需要同一套 LLVM 的：

```text
llvm-config
LLVMConfig.cmake、AddLLVM.cmake
LLVM C++ 头文件
LLVM 库及导出目标
clang、clang++
opt、llc（建议安装，用于独立检查）
```

毕昇 5.1.0.2 发布包在 5.0.0.2 基础上裁剪了部分辅助工具，所以不能仅根据
`clang --version` 判断开发环境已经完整。必须先执行下一节的自检。

### 2. 插件和加载它的 Clang 必须来自同一套 LLVM

LLVM pass 插件直接使用 LLVM C++ API。即使两个编译器都显示
`19.1.7`，毕昇企业版、openEuler LLVM 和上游 LLVM 仍可能包含不同补丁、
C++ ABI、RTTI、异常处理或动态库配置。

优先顺序如下：

1. **最佳方案**：使用毕昇 Enterprise 5.1.0.2 配套的 LLVM 开发文件构建
   插件，并由同一安装目录中的 `clang` 加载。
2. **可控替代方案**：自行安装一套完整 LLVM 19.1.7，并让生成 IR、构建
   插件、加载插件、生成汇编全部使用该环境。
3. **不推荐**：用系统 LLVM 19 的头文件和库构建插件，再加载到毕昇
   Enterprise Clang。版本字符串相同也不能保证安全。

## 二、先检查现有毕昇环境

### 1. 定位安装目录

```bash
command -v clang
readlink -f "$(command -v clang)"
clang --version
clang -print-resource-dir

export BISHENG_CLANG="$(readlink -f "$(command -v clang)")"
export BISHENG_HOME="$(cd "$(dirname "${BISHENG_CLANG}")/.." && pwd)"
printf 'BISHENG_HOME=%s\n' "${BISHENG_HOME}"
```

如果 `command -v clang` 不是毕昇目录中的程序，先按照实际路径设置：

```bash
export BISHENG_HOME=/opt/compiler/BiShengCompiler-5.1.0.2-aarch64-linux
export PATH="${BISHENG_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${BISHENG_HOME}/lib:${BISHENG_HOME}/lib/aarch64-unknown-linux-gnu:${LD_LIBRARY_PATH:-}"
hash -r
```

### 2. 检查插件开发文件

```bash
for tool in clang clang++ llvm-config opt llc; do
  if [[ -x "${BISHENG_HOME}/bin/${tool}" ]]; then
    "${BISHENG_HOME}/bin/${tool}" --version | head -n 1
  else
    printf 'MISSING: %s\n' "${BISHENG_HOME}/bin/${tool}"
  fi
done

if [[ -x "${BISHENG_HOME}/bin/llvm-config" ]]; then
  "${BISHENG_HOME}/bin/llvm-config" --version
  "${BISHENG_HOME}/bin/llvm-config" --cmakedir
  "${BISHENG_HOME}/bin/llvm-config" --includedir
  "${BISHENG_HOME}/bin/llvm-config" --libdir
  test -f "$("${BISHENG_HOME}/bin/llvm-config" --cmakedir)/LLVMConfig.cmake"
fi

find "${BISHENG_HOME}" \
  \( -name LLVMConfig.cmake -o -name AddLLVM.cmake \
     -o -name PassBuilder.h -o -name libLLVM.so \) \
  -print
```

满足以下条件时，可以直接使用现有毕昇环境：

```text
llvm-config --version 输出 19.1.7
llvm-config --cmakedir 下存在 LLVMConfig.cmake
同一 CMake 目录体系中能找到 AddLLVM.cmake
includedir 下存在 llvm/Passes/PassBuilder.h
libdir 下存在 LLVM 库
clang、clang++、llvm-config 来自同一个 BISHENG_HOME
```

若这些文件缺失，应先向毕昇软件提供方获取 **Enterprise 5.1.0.2 对应的
完整开发包、SDK 或源码构建包**。这是保持毕昇插件 ABI 一致的首选方式。

## 三、安装基础依赖

项目要求 CMake 3.20 或更高版本、支持 C++17 的编译器、Ninja 和 Python
3。LLVM 官方文档目前列出的构建基础要求包括 CMake 3.20 以上和 Python
3.8 以上。

### 1. openEuler、EulerOS、RHEL 系

```bash
sudo dnf install -y \
  gcc gcc-c++ glibc-devel libstdc++-devel \
  cmake ninja-build python3 git make \
  zlib-devel zstd-devel libxml2-devel ncurses-devel libffi-devel \
  tar xz patch pkgconf-pkg-config \
  perf numactl util-linux
```

不同系统的软件包名可能不同，可先检查：

```bash
dnf search ninja
dnf search perf
```

如果软件源中的 CMake 低于 3.20，应使用系统提供的新版仓库、Kitware
软件包或下载 CMake 官方 AArch64 二进制包，不要覆盖系统自带 CMake。

### 2. Ubuntu、Debian 系

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build python3 git \
  zlib1g-dev libzstd-dev libxml2-dev libedit-dev libncurses-dev libffi-dev \
  tar xz-utils patch pkg-config \
  linux-tools-common numactl util-linux
```

`perf` 的实际包名通常和内核版本相关；若 `perf` 命令仍不存在，执行：

```bash
apt-cache search "linux-tools-$(uname -r)"
```

### 3. 验证基础工具

```bash
cmake --version
ninja --version
python3 --version
git --version
gcc --version | head -n 1
perf --version
```

## 四、方案 A：使用完整的毕昇 5.1.0.2 环境

如果第二节检查全部通过，不需要再安装另一套 LLVM。设置：

```bash
export LLVM_HOME="${BISHENG_HOME}"
export LLVM_CONFIG="${LLVM_HOME}/bin/llvm-config"
export LLVM_CLANG="${LLVM_HOME}/bin/clang"
export PLUGIN_CC="${LLVM_HOME}/bin/clang"
export PLUGIN_CXX="${LLVM_HOME}/bin/clang++"
export RUNTIME_CLANG="${LLVM_HOME}/bin/clang"
export CLANG="${LLVM_HOME}/bin/clang"
export CMAKE="$(command -v cmake)"
export NINJA="$(command -v ninja)"
```

检查 CMake 能否消费这套 LLVM：

```bash
cmake \
  -S 02_llvm_pass_plugin \
  -B /tmp/stencil-prefetch-cmake-check \
  -G Ninja \
  -DLLVM_DIR="$("${LLVM_CONFIG}" --cmakedir)" \
  -DCMAKE_C_COMPILER="${PLUGIN_CC}" \
  -DCMAKE_CXX_COMPILER="${PLUGIN_CXX}"
```

配置输出必须显示 LLVM 19.1.7，且不能引用另一套 `/usr/lib/llvm-*`。

## 五、方案 B：安装独立的完整 LLVM 19.1.7

仅当无法获得毕昇 5.1.0.2 配套开发文件时使用本方案。此后项目整个编译
链都使用新环境，不把生成的插件加载到毕昇 Enterprise Clang。

### 1. 获取上游 LLVM 19.1.7

```bash
mkdir -p "${HOME}/src"
cd "${HOME}/src"
git clone --depth 1 \
  --branch llvmorg-19.1.7 \
  https://github.com/llvm/llvm-project.git \
  llvm-project-19.1.7
```

也可以从 LLVM 19.1.7 release 页面下载并校验源码压缩包。若必须保留毕昇
或 openEuler 补丁，应改用软件提供方指定的 19.1.7 源码标签，而不是上游
标签。

### 2. 配置、构建和安装

以下配置只构建 AArch64 所需的 LLVM、Clang 和 LLD，安装到用户目录：

```bash
export LLVM_SRC="${HOME}/src/llvm-project-19.1.7"
export LLVM_BUILD="${HOME}/build/llvm-19.1.7"
export LLVM_HOME="${HOME}/opt/llvm-19.1.7"

cmake \
  -S "${LLVM_SRC}/llvm" \
  -B "${LLVM_BUILD}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LLVM_HOME}" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF

cmake --build "${LLVM_BUILD}" --parallel "$(nproc)"
cmake --install "${LLVM_BUILD}"
```

如果链接阶段内存不足，可限制并行数：

```bash
cmake --build "${LLVM_BUILD}" --parallel 4
```

### 3. 固定独立 LLVM 环境

```bash
export PATH="${LLVM_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${LLVM_HOME}/lib:${LD_LIBRARY_PATH:-}"
hash -r

export LLVM_CONFIG="${LLVM_HOME}/bin/llvm-config"
export LLVM_CLANG="${LLVM_HOME}/bin/clang"
export PLUGIN_CC="${LLVM_HOME}/bin/clang"
export PLUGIN_CXX="${LLVM_HOME}/bin/clang++"
export RUNTIME_CLANG="${LLVM_HOME}/bin/clang"
export CLANG="${LLVM_HOME}/bin/clang"
export CMAKE="$(command -v cmake)"
export NINJA="$(command -v ninja)"
```

不要把这些变量永久写入全局 `/etc/profile`。建议保存成项目专用环境脚本，
需要时手工 `source`，避免影响系统和毕昇编译器。

### 4. 验证版本和路径一致

```bash
for tool in clang clang++ llvm-config opt llc; do
  command -v "${tool}"
  "${tool}" --version | head -n 1
done

test "$(llvm-config --version)" = "19.1.7"
test -f "$(llvm-config --cmakedir)/LLVMConfig.cmake"
printf 'LLVM cmake: %s\n' "$(llvm-config --cmakedir)"
printf 'LLVM include: %s\n' "$(llvm-config --includedir)"
printf 'LLVM lib: %s\n' "$(llvm-config --libdir)"
```

## 六、验证 AArch64 SME 编译与运行环境

### 1. 编译器是否接受 SME/SVE ACLE

```bash
cat >/tmp/check_sme.c <<'EOF'
#include <arm_sme.h>
#include <arm_sve.h>

__arm_locally_streaming
unsigned long check_streaming_vl(void) {
  return svcntb();
}
EOF

"${CLANG}" \
  -target aarch64-unknown-linux-gnu \
  -march=armv9.2-a+sme+sve2 \
  -fsyntax-only /tmp/check_sme.c
```

`arm_sme.h` 和 `arm_sve.h` 属于 Clang resource headers，不需要另外安装
一个名为 `arm_sme` 或 `arm_sve` 的库。检查实际头文件位置：

```bash
resource_dir="$("${CLANG}" -print-resource-dir)"
printf 'resource_dir=%s\n' "${resource_dir}"
test -f "${resource_dir}/include/arm_sme.h"
test -f "${resource_dir}/include/arm_sve.h"
```

### 2. 操作系统是否允许执行 SME

```bash
uname -m
uname -r
lscpu
grep -m1 '^Features' /proc/cpuinfo
grep -qw sme /proc/cpuinfo && echo "SME advertised by Linux"
cat /proc/sys/abi/sme_default_vector_length 2>/dev/null || true
```

硬件支持 SME 不等于操作系统一定向用户态开放 SME。Linux 通过
`HWCAP2_SME` 和 `/proc/cpuinfo` 中的 `sme` 报告用户态 SME 支持，并通过
`/proc/sys/abi/sme_default_vector_length` 管理默认 streaming vector
length。若这些接口不存在，应先确认服务器内核和固件，而不是继续安装
用户态 LLVM。

### 3. 验证预取能降低为 `PRFM`

完成插件构建后，至少检查：

```bash
grep -c 'llvm.aarch64.prefetch' \
  02_llvm_pass_plugin/output/stencil_sme_kernels.after.ll

grep -Ei '^[[:space:]]*prf(m|um)[[:space:]]' \
  02_llvm_pass_plugin/output/stencil_sme_kernels.s
```

插件文件在 Linux 上应为：

```text
02_llvm_pass_plugin/build/StencilPrefetchPass.so
```

可使用以下命令检查动态依赖是否全部解析到同一 LLVM 环境：

```bash
ldd 02_llvm_pass_plugin/build/StencilPrefetchPass.so
readelf -d 02_llvm_pass_plugin/build/StencilPrefetchPass.so | grep NEEDED
```

## 七、项目还需要安装什么

### 必需

| 组件 | 用途 |
|---|---|
| 完整 LLVM/Clang 19.1.7 开发环境 | 生成 IR、编译和加载 pass、生成 AArch64 汇编 |
| CMake 3.20 以上 | 读取 `LLVMConfig.cmake` 并构建插件 |
| Ninja | 当前构建脚本指定的生成器 |
| Python 3.8 以上 | 步骤 1 的 LLVM IR 结构检查 |
| C/C++ 构建环境与 glibc 开发文件 | 构建插件及运行时测试程序 |
| Git、tar、xz、patch | 拉取源码和处理安装包 |

### 性能验证建议安装

| 组件 | 用途 |
|---|---|
| `perf` | cycles、instructions、cache/PMU、采样归因 |
| `numactl` | 固定 NUMA 节点和内存分配策略 |
| `taskset`（通常来自 `util-linux`） | 固定 CPU 亲和性 |
| `lscpu` | 记录 CPU、cache 和 NUMA 拓扑 |

`perf` 能否读取原始 PMU 事件还取决于服务器权限和
`kernel.perf_event_paranoid`：

```bash
perf list
cat /proc/sys/kernel/perf_event_paranoid
```

### 当前不需要

```text
MLIR
Polygeist
OpenMP
CUDA/ROCm
单独的 arm_sme 或 arm_sve 运行库
macOS Xcode、Instruments、xctrace
JSON 分析结果传递工具
```

本项目直接在 Clang 生成的 LLVM IR 上分析并插入预取，运行时测试使用
POSIX C 和 pthread；只有以后把单网格测试改成 OpenMP 并行时才需要额外
安装 OpenMP runtime。

## 八、与当前脚本的衔接

安装环境后，步骤 1 应使用 Linux 目标：

```bash
CLANG="${LLVM_CLANG}" \
TARGET=aarch64-unknown-linux-gnu \
MARCH=armv9.2-a+sme+sve2 \
  ./01_llvm_ir_analysis/generate_and_check.sh
```

步骤 2 使用同一套 LLVM：

```bash
LLVM_CONFIG="${LLVM_CONFIG}" \
LLVM_CLANG="${LLVM_CLANG}" \
PLUGIN_CC="${PLUGIN_CC}" \
PLUGIN_CXX="${PLUGIN_CXX}" \
CMAKE="${CMAKE}" \
NINJA="${NINJA}" \
  ./02_llvm_pass_plugin/build_and_test.sh
```

步骤 5 同样固定编译器：

```bash
RUNTIME_CLANG="${RUNTIME_CLANG}" \
SME_RUNTIME_PROFILE=generic-sme \
  ./05_runtime_validation/build_and_run.sh
```

当前原分支脚本仍包含 Apple 开发机路径、LLVM 18 兼容转换、`.dylib`
回退和 `apple-m5` 报告标签。完成上述环境安装只能证明工具链可用，不能
保证脚本原样在 Linux 上全部通过。迁移分支还需完成：

1. 把工具默认路径改为 `command -v` 或统一的 `LLVM_HOME`。
2. 去掉 Apple Clang 21 到 LLVM 18 的文本 IR 兼容转换。
3. 将基于固定 SSA 编号的负例改成独立、稳定的 `.ll` fixture。
4. 将平台标签、动态库后缀和 CPU feature 探测改为 Linux 逻辑。
5. 新建服务器 CPU Profile，不直接复用 `apple-m5` 参数。

## 九、最终验收清单

```text
[ ] clang、clang++、llvm-config、opt、llc 都来自同一 LLVM_HOME
[ ] clang 和 llvm-config 均报告 19.1.7
[ ] LLVMConfig.cmake、AddLLVM.cmake、LLVM 头文件和库存在
[ ] CMake 3.20+、Ninja、Python 3.8+ 可用
[ ] arm_sme.h、arm_sve.h 语法检查通过
[ ] Linux 向用户态报告 SME，能读取实际 streaming VL
[ ] StencilPrefetchPass.so 构建成功，ldd 无未解析依赖
[ ] 插件由构建它的同一套 clang 加载
[ ] 插入后 IR 包含 llvm.aarch64.prefetch
[ ] AArch64 汇编包含目标层级和 KEEP/STRM 对应的 PRFM
[ ] 基线和预取版本均通过 2D5P、3D7P 数值正确性测试
[ ] perf、taskset、numactl 可用于后续服务器 Profile 标定
```

## 参考资料

1. [毕昇 Compiler 5.1.0.2 软件包安装说明](https://www.hikunpeng.com/document/detail/en/kunpengdevps/compilation/cm-bisheng/kunpengbisheng_06_0005.html)
2. [鲲鹏 DevKit 毕昇编译器下载页](https://www.hikunpeng.com/zh/developer/devkit/download/exagear)
3. [openEuler LLVM 19.1.7 源码标签](https://gitee.com/openeuler/llvm-project/tags)
4. [LLVM Getting Started：依赖和 CMake 构建](https://llvm.org/docs/GettingStarted.html)
5. [LLVM New Pass Manager 插件构建说明](https://llvm.org/docs/WritingAnLLVMNewPMPass.html)
6. [Linux AArch64 SME 用户态接口](https://cdn.kernel.org/doc/html/latest/arch/arm64/sme.html)
7. [Linux perf 事件与权限说明](https://man7.org/linux/man-pages/man1/perf-list.1.html)
