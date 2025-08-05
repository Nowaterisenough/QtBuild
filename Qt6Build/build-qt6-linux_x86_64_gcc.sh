#!/bin/bash

# build-qt6-linux_x86_64_gcc.sh

set -e  # 遇到错误立即退出

echo "Starting Qt Linux build script..."

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

# 更新系统并安装依赖
echo "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    build-essential \
    gcc-${GCC_VERSION} \
    g++-${GCC_VERSION} \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    pkg-config \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxcb1-dev \
    libxcb-util-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-render0-dev \
    libxcb-render-util0-dev \
    libxcb-randr0-dev \
    libxcb-xtest0-dev \
    libxcb-xinerama0-dev \
    libxcb-shape0-dev \
    libxcb-sync-dev \
    libxcb-xfixes0-dev \
    libxcb-icccm4-dev \
    libxcb-shm0-dev \
    libxcb-cursor-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libx11-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxrender-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxinerama-dev \
    libxss-dev \
    libglib2.0-dev \
    libegl1-mesa-dev \
    libwayland-dev \
    libssl-dev \
    libasound2-dev \
    libpulse-dev \
    libnss3-dev \
    libxcomposite-dev \
    libxdamage-dev \
    libdrm-dev \
    libxss1 \
    libgconf-2-4 \
    xz-utils \
    wget \
    curl

# 设置编译器
echo "Setting up compiler..."
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100

# 验证编译器版本
gcc --version
g++ --version
cmake --version
ninja --version

# 解压 Qt 源码
echo "Extracting Qt source..."
if [ -f "qt-everywhere-src-${QT_VERSION}.tar.xz" ]; then
    tar -xf qt-everywhere-src-${QT_VERSION}.tar.xz
    if [ ! -d "qt-everywhere-src-${QT_VERSION}" ]; then
        echo "Error: Failed to extract Qt source"
        exit 1
    fi
else
    echo "Error: Qt source file not found"
    exit 1
fi

# 设置路径
SRC_QT="/workspace/qt-everywhere-src-${QT_VERSION}"
BUILD_DIR="/workspace/build"
INSTALL_DIR="/workspace/output/qt-${QT_VERSION}-${LINK_TYPE}-gcc${GCC_VERSION}"

echo "Source directory: $SRC_QT"
echo "Build directory: $BUILD_DIR"
echo "Install directory: $INSTALL_DIR"

# 创建目录
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"
cd "$BUILD_DIR"

# 构建配置选项
CFG_OPTIONS="-${LINK_TYPE} -prefix $INSTALL_DIR -nomake examples -nomake tests -c++std c++20 -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -openssl-linked -platform linux-g++ -opengl desktop"

# 根据构建类型添加选项
if [ "$BUILD_TYPE" = "debug" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -debug"
else
    CFG_OPTIONS="$CFG_OPTIONS -release"
fi

# 处理分离调试信息（仅对 shared 构建有效）
if [ "$LINK_TYPE" = "shared" ] && [ "$SEPARATE_DEBUG" = "true" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -force-debug-info -separate-debug-info"
fi

echo "Configure options: $CFG_OPTIONS"

# 配置
echo "Configuring Qt..."
"$SRC_QT/configure" $CFG_OPTIONS
if [ $? -ne 0 ]; then
    echo "Configure failed with error code: $?"
    exit 1
fi

# 构建
echo "Building Qt..."
# 使用并行构建，但限制并发数以避免内存不足
PARALLEL_JOBS=$(nproc)
if [ $PARALLEL_JOBS -gt 4 ]; then
    PARALLEL_JOBS=4
fi
echo "Using $PARALLEL_JOBS parallel jobs"

cmake --build . --parallel $PARALLEL_JOBS
if [ $? -ne 0 ]; then
    echo "Build failed with error code: $?"
    exit 1
fi

# 安装
echo "Installing Qt..."
cmake --install .
if [ $? -ne 0 ]; then
    echo "Install failed with error code: $?"
    exit 1
fi

# 验证安装
echo "Verifying installation..."
if [ -d "$INSTALL_DIR" ]; then
    echo "Installation successful!"
    echo "Installation directory contents:"
    ls -la "$INSTALL_DIR"
    
    # 检查关键文件
    if [ -f "$INSTALL_DIR/bin/qmake" ]; then
        echo "qmake found: $INSTALL_DIR/bin/qmake"
        "$INSTALL_DIR/bin/qmake" -version
    else
        echo "Warning: qmake not found"
    fi
    
    if [ -d "$INSTALL_DIR/lib" ]; then
        echo "Libraries directory exists"
        echo "Library count: $(find $INSTALL_DIR/lib -name '*.so*' -o -name '*.a' | wc -l)"
    else
        echo "Warning: lib directory not found"
    fi
    
    # 显示安装大小
    du -sh "$INSTALL_DIR"
    
else
    echo "Error: Installation directory does not exist!"
    exit 1
fi

echo "Qt build completed successfully!"