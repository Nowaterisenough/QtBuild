#!/bin/bash

# 设置编码
export LANG=en_US.UTF-8

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置Qt版本
QT_VERSION=6.9.1

# 设置GCC版本代号
GCC_VERSION=gcc15_64

# 设置编译器（使用系统安装的 GCC 15）
export CC="gcc-15"
export CXX="g++-15"

# 设置Qt文件夹路径
QT_PATH="/home/runner/work/QtBuild/Qt"

# 设置Qt源代码目录
SRC_QT="$QT_PATH/$QT_VERSION/qt-everywhere-src-$QT_VERSION"

# 设置安装文件夹目录
INSTALL_DIR="$QT_PATH/$QT_VERSION-static/$GCC_VERSION"

# 设置build文件夹目录
BUILD_DIR="$QT_PATH/$QT_VERSION/build-$GCC_VERSION"

# 显示编译器版本信息
echo "Using compiler:"
echo "CC: $CC"
echo "CXX: $CXX"
$CC --version
$CXX --version

# 根据需要进行全新构建
rm -rf "$BUILD_DIR"

# 定位到构建目录：
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# configure
"$SRC_QT/configure" \
    -static \
    -static-runtime \
    -release \
    -prefix "$INSTALL_DIR" \
    -nomake examples \
    -nomake tests \
    -skip qtwebengine \
    -opensource \
    -confirm-license \
    -qt-libpng \
    -qt-libjpeg \
    -qt-zlib \
    -qt-pcre \
    -qt-freetype \
    -openssl-linked \
    -xcb \
    -platform linux-g++

# 编译
cmake --build . --parallel $(nproc)

# 安装
cmake --install .

# 复制qt.conf
cp "$SCRIPT_DIR/qt.conf" "$INSTALL_DIR/bin/"

# 进入安装目录
cd "$INSTALL_DIR"