cmake_minimum_required(VERSION 3.20)
project(StencilPrefetchPass LANGUAGES C CXX)

find_package(LLVM REQUIRED CONFIG)

message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "LLVMConfig.cmake: ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_llvm_pass_plugin(StencilPrefetchPass
  src/StencilPrefetchPass.cpp
)

if(APPLE)
  target_link_options(StencilPrefetchPass PRIVATE
    "LINKER:-undefined,dynamic_lookup"
  )
endif()
