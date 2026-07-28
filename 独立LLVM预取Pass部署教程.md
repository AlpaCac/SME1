# 独立 LLVM 预取 Pass 部署教程

## 1. 目的与边界

服务器上的 BiSheng 编译器发布包缺少 `llvm/ADT/SmallVector.h` 等 LLVM C++ 开发
头文件，因而不能在 BiSheng Clang 进程内构建或加载本项目的 `.so` pass 插件。

本教程改用两个工具链：

1. **独立 upstream LLVM 19.1.7**：构建 `StencilPrefetchPass.so`，用 `opt` 分析
   和改写 LLVM IR。
2. **BiSheng Clang**：生成初始 AArch64/SME IR，并将改写后的 IR 编译为汇编、
   目标文件或可执行文件。

这不是 `-fpass-plugin` 的进程内集成。预取 pass 在独立 `opt` 进程中运行，两个
工具链之间只传递文本 LLVM IR。这样不依赖 BiSheng 私有 LLVM C++ ABI，也不要求
BiSheng 安装提供 LLVM 开发头文件。

独立 LLVM 19.1.7 是为了尽量接近服务器 BiSheng `clang 19.1.7` 的 LLVM IR
版本。开始前必须执行第 4 节的兼容性探针；若独立 `opt` 不能读取 BiSheng IR，
不能继续使用该组合。

## 2. 前置条件

服务器需要以下命令：

```text
curl, tar, xz, cmake, make, cc, c++, python3
```

BiSheng 仍需能执行以下命令：

```text
clang, clang++, llvm-extract
```

本教程不会使用 BiSheng 的 `llvm-config` 构建插件。它可以存在，但不参与独立
LLVM pass 的构建。

## 3. 用 curl 构建独立 LLVM 19.1.7

以下以 `~/toolchains/llvm-19.1.7` 为安装位置。LLVM 官方源码归档 URL 是固定的
release URL；`curl -fL` 会跟随 GitHub 的临时下载重定向。

若源码压缩包已位于仓库的 `tools/llvm-project-19.1.7.src.tar.xz`，优先直接运行
仓库提供的安装脚本。脚本默认将源码、构建目录和安装目录都放在 `tools/` 下：

```bash
./tools/install_standalone_llvm.sh
```

编译内存不足时限制并行度：

```bash
JOBS=1 ./tools/install_standalone_llvm.sh
```

脚本结束后会打印 `STANDALONE_LLVM` 的导出命令。下面的手动命令仅用于需要自定义
安装目录时的参考：

```bash
mkdir -p ~/src ~/toolchains
cd ~/src

curl -fL --retry 3 --retry-delay 3 \
  -o llvm-project-19.1.7.src.tar.xz \
  https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.7/llvm-project-19.1.7.src.tar.xz

tar -xf llvm-project-19.1.7.src.tar.xz

cmake -S llvm-project-19.1.7.src/llvm -B llvm-project-19.1.7.build \
  -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/toolchains/llvm-19.1.7" \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF

cmake --build llvm-project-19.1.7.build --parallel "$(getconf _NPROCESSORS_ONLN)"
cmake --install llvm-project-19.1.7.build
```

验证独立工具链必须同时包含开发头文件、CMake 配置、`opt` 和 `llvm-config`：

```bash
export STANDALONE_LLVM="$HOME/toolchains/llvm-19.1.7"

"${STANDALONE_LLVM}/bin/llvm-config" --version
"${STANDALONE_LLVM}/bin/opt" --version
test -f "${STANDALONE_LLVM}/include/llvm/ADT/SmallVector.h" && echo 'LLVM headers: OK'
test -f "${STANDALONE_LLVM}/lib/cmake/llvm/LLVMConfig.cmake" && echo 'LLVM CMake config: OK'
```

预期版本为 `19.1.7`。若编译内存不足，可将 `--parallel` 后的并行度改为 `1` 或
较小值。

## 4. BiSheng IR 兼容性探针

先在仓库根目录由 BiSheng 重新执行步骤 1：

```bash
./01_llvm_ir_analysis/generate_and_check.sh
```

步骤 1 生成的完整 IR 默认位于：

```text
01_llvm_ir_analysis/output/stencil_all_sme.full.ll
```

先让独立 `opt` 只读取并校验该 IR，不运行任何 pass：

```bash
"${STANDALONE_LLVM}/bin/opt" \
  -disable-output \
  01_llvm_ir_analysis/output/stencil_all_sme.full.ll
```

此命令必须返回 `0`。若报告未知 intrinsic、IR 版本不兼容或 verifier 错误，停止
后续步骤，保留完整报错；不要尝试通过删除 SME intrinsic 修复，因为会改变 kernel
语义。

## 5. 用独立 LLVM 构建并回归测试 pass

步骤 1 通过后，使用独立 LLVM 的 `llvm-config`、Clang、CMake 构建插件。这里仍可
复用仓库脚本；脚本会在缺少 Ninja 时自动使用 `Unix Makefiles`。

```bash
LLVM_CONFIG="${STANDALONE_LLVM}/bin/llvm-config" \
LLVM_CLANG="${STANDALONE_LLVM}/bin/clang" \
PLUGIN_CC="${STANDALONE_LLVM}/bin/clang" \
PLUGIN_CXX="${STANDALONE_LLVM}/bin/clang++" \
CMAKE_GENERATOR="Unix Makefiles" \
  ./02_llvm_pass_plugin/build_and_test.sh
```

该脚本的输入是 kernel-only IR，默认路径为：

```text
01_llvm_ir_analysis/output/stencil_all_sme.kernels.ll
```

它会构建插件、运行识别/决策、检查插入的 `llvm.aarch64.prefetch` 数量，并生成
`02_llvm_pass_plugin/output/stencil_kernels.s`。若当前输入没有任何函数匹配已有
识别模型，可临时加 `STENCIL_REQUIRE_RECOGNIZED=0` 只验证插件构建与 IR 可读性；
这不表示已经插入预取。

## 6. 用 opt 改写完整 IR

构建成功后，插件位置通常为：

```bash
PLUGIN=02_llvm_pass_plugin/build/StencilPrefetchPass.so
test -f "${PLUGIN}" || PLUGIN=02_llvm_pass_plugin/build/StencilPrefetchPass.dylib
test -f "${PLUGIN}"
```

独立 `opt` 显式运行本项目注册的 `stencil-prefetch` 函数 pass。输入使用完整 IR，
而不是 kernel-only IR，这样改写后的模块仍保留原始 `main`、测试和辅助函数，可
交回 BiSheng 生成可运行程序：

```bash
INPUT_IR=01_llvm_ir_analysis/output/stencil_all_sme.full.ll
OUTPUT_IR=01_llvm_ir_analysis/output/stencil_all_sme.prefetch.ll
PASS_LOG=02_llvm_pass_plugin/output/standalone_opt.log

"${STANDALONE_LLVM}/bin/opt" \
  -load-pass-plugin="${PLUGIN}" \
  -passes='function(stencil-prefetch)' \
  -S "${INPUT_IR}" \
  -o "${OUTPUT_IR}" \
  2> "${PASS_LOG}"
```

检查 pass 识别和插入结果：

```bash
grep '^StencilAnalysis:' "${PASS_LOG}"
grep '^StencilDecision:' "${PASS_LOG}"
grep -c 'call void @llvm.aarch64.prefetch' "${OUTPUT_IR}"
```

若最后一个计数为 `0`，先查看 `StencilDecision` 中的拒绝原因；不要仅因 `opt`
成功返回就认为预取已启用。

## 7. 交回 BiSheng 生成汇编和目标文件

设置 BiSheng 编译器根目录，然后从改写后的完整 IR 生成汇编：

```bash
export BISHENG_HOME=/path/to/BiShengCompiler-5.1.0.2-aarch64-linux
export BISHENG_CLANG="${BISHENG_HOME}/bin/clang"

"${BISHENG_CLANG}" \
  -x ir -O3 -S -Wno-override-module \
  -march=armv9.2-a+sme+sve2+sme-f64f64 \
  "${OUTPUT_IR}" \
  -o 01_llvm_ir_analysis/output/stencil_all_sme.prefetch.s

grep -En '^[[:space:]]*prf(m|um)[[:space:]]' \
  01_llvm_ir_analysis/output/stencil_all_sme.prefetch.s
```

再生成目标文件或可执行文件时，使用同一个 BiSheng Clang 和同一个改写后 IR：

```bash
"${BISHENG_CLANG}" \
  -x ir -O3 -c -Wno-override-module \
  -march=armv9.2-a+sme+sve2+sme-f64f64 \
  "${OUTPUT_IR}" \
  -o 01_llvm_ir_analysis/output/stencil_all_sme.prefetch.o
```

完整 IR 包含 `main` 时，可将上例的 `-c` 改为正常链接参数生成可执行文件。不要把
仅含计算函数的 `.kernels.ll` 单独链接为程序，因为它不包含原始 `main` 和测试代码。

## 8. 结果判定与限制

成功至少需要同时满足：

1. 独立 `opt -disable-output` 能校验 BiSheng 生成的完整 IR。
2. `opt` 输出包含预取 intrinsic，且决策日志中存在 `enable=yes`。
3. BiSheng 能读取改写后的 IR 并生成汇编。
4. 汇编中存在对应 `prfm`/`prfum` 指令。
5. 改写前后的可执行文件通过相同正确性测试。

本方式的优势是避免 BiSheng C++ API/ABI 依赖；代价是预取插入成为显式的 IR
处理步骤，而非单条源文件编译命令中的 `-fpass-plugin`。如果未来获得与 BiSheng
发行版严格匹配的 LLVM pass 开发 SDK，才可再评估切回进程内插件方式。
