#!/bin/bash

# 设置编码
export LANG=en_US.UTF-8

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置Qt版本
QT_VERSION=6.9.1

# 设置交叉编译器版本代号
CROSS_VERSION=aarch64_gcc13_2

# 设置交叉编译工具链
CROSS_PREFIX="/opt/aarch64-linux-gnu"
export CC="$CROSS_PREFIX/bin/aarch64-linux-gnu-gcc"
export CXX="$CROSS_PREFIX/bin/aarch64-linux-gnu-g++"
export AR="$CROSS_PREFIX/bin/aarch64-linux-gnu-ar"
export STRIP="$CROSS_PREFIX/bin/aarch64-linux-gnu-strip"
export OBJCOPY="$CROSS_PREFIX/bin/aarch64-linux-gnu-objcopy"
export NM="$CROSS_PREFIX/bin/aarch64-linux-gnu-nm"
export RANLIB="$CROSS_PREFIX/bin/aarch64-linux-gnu-ranlib"

# 设置目标系统根目录
SYSROOT="$CROSS_PREFIX/aarch64-linux-gnu/sysroot"

# 设置交叉编译环境
export PATH="$CROSS_PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# 设置Qt文件夹路径
QT_PATH="/home/runner/work/QtBuild/Qt"

# 设置Qt源代码目录
SRC_QT="$QT_PATH/$QT_VERSION/qt-everywhere-src-$QT_VERSION"

# 设置安装文件夹目录
INSTALL_DIR="$QT_PATH/$QT_VERSION-static/$CROSS_VERSION"

# 设置build文件夹目录
BUILD_DIR="$QT_PATH/$QT_VERSION/build-$CROSS_VERSION"

# 显示交叉编译器版本信息
echo "Using cross-compiler:"
echo "Target: aarch64-linux-gnu"
echo "CC: $CC"
echo "CXX: $CXX"
echo "SYSROOT: $SYSROOT"
$CC --version
$CXX --version
echo ""

# 根据需要进行全新构建
rm -rf "$BUILD_DIR"

# 定位到构建目录：
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# 创建交叉编译配置文件
cat > cross-compile.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_SYSROOT $SYSROOT)
set(CMAKE_STAGING_PREFIX $INSTALL_DIR)

set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# 设置编译器标志
set(CMAKE_C_FLAGS "-march=armv8-a -mtune=cortex-a53 -O2")
set(CMAKE_CXX_FLAGS "-march=armv8-a -mtune=cortex-a53 -O2")
EOF

# 检查configure是否成功
configure_qt() {
    "$SRC_QT/configure" \
        -static \
        -release \
        -prefix "$INSTALL_DIR" \
        -extprefix "$INSTALL_DIR" \
        -sysroot "$SYSROOT" \
        -nomake examples \
        -nomake tests \
        -no-opengl \
        -no-egl \
        -no-vulkan \
        -linuxfb \
        -no-xcb \
        -no-kms \
        -opensource \
        -confirm-license \
        -qt-libpng \
        -qt-libjpeg \
        -qt-zlib \
        -qt-pcre \
        -qt-freetype \
        -no-openssl \
        -no-dbus \
        -no-glib \
        -silent \
        -platform linux-g++ \
        -xplatform linux-aarch64-gnu-g++ \
        -device-option CROSS_COMPILE=aarch64-linux-gnu- \
        -cmake-file-api
}

# configure
echo "Configuring Qt for ARM64..."
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

# 创建交叉编译信息文件
cat > "$INSTALL_DIR/cross-compile-info.txt" << EOF
Qt Cross-Compilation Information
================================
Qt Version: $QT_VERSION
Target Architecture: aarch64 (ARM64)
Target OS: Linux (Embedded)
Cross-Compiler: aarch64-linux-gnu-gcc
Build Type: Static Release
Features: Framebuffer, No X11, No OpenGL, No D-Bus

Deployment:
1. Copy the entire installation directory to target device
2. Set LD_LIBRARY_PATH if needed
3. Ensure target device has compatible glibc version

Cross-compilation completed on: $(date)
EOF

echo "Build completed successfully!"
echo "Installation directory: $INSTALL_DIR"
echo "Target: ARM64 Linux Embedded System"

# 进入安装目录
cd "$INSTALL_DIR"