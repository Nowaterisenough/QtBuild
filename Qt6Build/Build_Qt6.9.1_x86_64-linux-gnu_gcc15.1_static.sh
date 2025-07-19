#!/bin/bash

# 设置编码
export LANG=en_US.UTF-8

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置Qt版本
QT_VERSION=6.9.1

# 设置GCC版本代号
GCC_VERSION=gcc15_64

# 设置编译器路径（使用自编译的 GCC 15.1）
GCC_PREFIX="/opt/gcc-15.1.0"
export CC="$GCC_PREFIX/bin/gcc"
export CXX="$GCC_PREFIX/bin/g++"
export PATH="$GCC_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$GCC_PREFIX/lib64:$LD_LIBRARY_PATH"

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
echo ""

# 根据需要进行全新构建
rm -rf "$BUILD_DIR"

# 定位到构建目录：
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# 检查configure是否成功
configure_qt() {
    "$SRC_QT/configure" \
        -static \
        -static-runtime \
        -release \
        -force-debug-info \
        -separate-debug-info \
        -headersclean \
        -prefix "$INSTALL_DIR" \
        -nomake examples \
        -nomake tests \
        -skip qtwebengine \
        -qt-doubleconversion \
        -opensource \
        -confirm-license \
        -bundled-xcb-xinput \
        -platform linux-g++ \
        -c++std c++20 \
        -linker gold \
        -no-libudev
}

# configure
echo "Configuring Qt..."
if ! configure_qt; then
    echo "Configure failed!"
    exit 1
fi

# 编译
echo "Starting build..."
if ! cmake --build . --parallel $(nproc); then
    echo "Build failed!"
    exit 1
fi

# 安装
echo "Installing..."
if ! cmake --install .; then
    echo "Install failed!"
    exit 1
fi

# 复制qt.conf
cp "$SCRIPT_DIR/qt.conf" "$INSTALL_DIR/bin/"

echo "Build completed successfully!"
echo "Installation directory: $INSTALL_DIR"

# 进入安装目录
cd "$INSTALL_DIR"