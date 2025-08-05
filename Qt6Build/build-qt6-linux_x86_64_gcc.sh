#!/bin/bash

set -e

echo "Starting Qt Linux build script in WSL2..."

# 参数处理
QT_VERSION=${QT_VERSION:-"6.9.1"}
GCC_VERSION=${GCC_VERSION:-"13"}
BUILD_TYPE=${BUILD_TYPE:-"release"}
LINK_TYPE=${LINK_TYPE:-"shared"}
SEPARATE_DEBUG=${SEPARATE_DEBUG:-"false"}

echo "=== Build Parameters ==="
echo "Qt Version: $QT_VERSION"
echo "GCC Version: $GCC_VERSION"
echo "Build Type: $BUILD_TYPE"
echo "Link Type: $LINK_TYPE"
echo "Separate Debug: $SEPARATE_DEBUG"
echo "========================"

# 解压 Qt 源码
echo "Extracting Qt source..."
if [ -f "qt-everywhere-src-${QT_VERSION}.tar.xz" ]; then
    tar -xf qt-everywhere-src-${QT_VERSION}.tar.xz
    rm qt-everywhere-src-${QT_VERSION}.tar.xz
else
    echo "Error: Qt source file not found"
    exit 1
fi

# 设置路径
SRC_QT="$(pwd)/qt-everywhere-src-${QT_VERSION}"
BUILD_DIR="$(pwd)/build"
INSTALL_DIR="$(pwd)/output"

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"
cd "$BUILD_DIR"

# 构建配置选项
CFG_OPTIONS="-${LINK_TYPE} -prefix $INSTALL_DIR -nomake examples -nomake tests -c++std c++20 -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -openssl-linked -platform linux-g++ -opengl desktop"

if [ "$BUILD_TYPE" = "debug" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -debug"
else
    CFG_OPTIONS="$CFG_OPTIONS -release"
fi

if [ "$LINK_TYPE" = "shared" ] && [ "$SEPARATE_DEBUG" = "true" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -force-debug-info -separate-debug-info"
fi

# 配置
echo "Configuring Qt..."
"$SRC_QT/configure" $CFG_OPTIONS

# 构建
echo "Building Qt..."
PARALLEL_JOBS=$(nproc)
if [ $PARALLEL_JOBS -gt 6 ]; then
    PARALLEL_JOBS=6
fi

cmake --build . --parallel $PARALLEL_JOBS

# 安装
echo "Installing Qt..."
cmake --install .

# 清理
cd "$(pwd)/.."
rm -rf "$BUILD_DIR"
rm -rf "qt-everywhere-src-${QT_VERSION}"

echo "Qt build completed successfully!"