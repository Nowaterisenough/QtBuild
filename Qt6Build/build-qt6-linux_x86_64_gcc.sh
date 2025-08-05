#!/bin/bash

# build-qt6-linux_x86_64_gcc_wsl2.sh
# 针对 WSL2 环境优化的版本

set -e  # 遇到错误立即退出

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

# 显示系统信息
echo "=== System Information ==="
echo "WSL Version: $(cat /proc/version)"
echo "Distribution: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "========================="

# 显示磁盘使用情况
echo "=== Disk usage before build ==="
df -h

# 验证编译器和工具
echo "Verifying tools..."
gcc --version | head -1
g++ --version | head -1
cmake --version | head -1
ninja --version

# 解压 Qt 源码
echo "Extracting Qt source..."
if [ -f "qt-everywhere-src-${QT_VERSION}.tar.xz" ]; then
    echo "Extracting qt-everywhere-src-${QT_VERSION}.tar.xz..."
    tar -xf qt-everywhere-src-${QT_VERSION}.tar.xz
    if [ ! -d "qt-everywhere-src-${QT_VERSION}" ]; then
        echo "Error: Failed to extract Qt source"
        exit 1
    fi
    # 删除压缩包以节省空间
    echo "Removing source archive to save space..."
    rm qt-everywhere-src-${QT_VERSION}.tar.xz
else
    echo "Error: Qt source file not found"
    exit 1
fi

# 设置路径
SRC_QT="$(pwd)/qt-everywhere-src-${QT_VERSION}"
BUILD_DIR="$(pwd)/build"
INSTALL_DIR="$(pwd)/output/qt-${QT_VERSION}-${LINK_TYPE}-gcc${GCC_VERSION}"

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

# 显示磁盘使用情况
echo "=== Disk usage before configure ==="
df -h

# 配置
echo "Configuring Qt..."
"$SRC_QT/configure" $CFG_OPTIONS
if [ $? -ne 0 ]; then
    echo "Configure failed with error code: $?"
    exit 1
fi

# 显示磁盘使用情况
echo "=== Disk usage after configure ==="
df -h

# 构建
echo "Building Qt..."
# WSL2 可以使用更多的并行作业，因为有更大的磁盘空间
PARALLEL_JOBS=$(nproc)
if [ $PARALLEL_JOBS -gt 6 ]; then
    PARALLEL_JOBS=6
fi
echo "Using $PARALLEL_JOBS parallel jobs"

# 监控磁盘空间
(
    while true; do
        sleep 300  # 每5分钟检查一次
        echo "=== Disk usage during build ($(date)) ==="
        df -h
        # 如果磁盘使用率超过90%，发出警告
        usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$usage" -gt 90 ]; then
            echo "WARNING: Disk usage is at ${usage}%"
        fi
    done
) &
monitor_pid=$!

cmake --build . --parallel $PARALLEL_JOBS
build_result=$?

# 停止磁盘监控
kill $monitor_pid 2>/dev/null || true

if [ $build_result -ne 0 ]; then
    echo "Build failed with error code: $build_result"
    echo "=== Disk usage when build failed ==="
    df -h
    exit $build_result
fi

# 显示磁盘使用情况
echo "=== Disk usage after build ==="
df -h

# 安装
echo "Installing Qt..."
cmake --install .
if [ $? -ne 0 ]; then
    echo "Install failed with error code: $?"
    exit 1
fi

# 清理构建目录以节省空间
echo "Cleaning up build directory..."
cd "$(pwd)/.."
rm -rf "$BUILD_DIR"
rm -rf "qt-everywhere-src-${QT_VERSION}"

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

echo "=== Final disk usage ==="
df -h

echo "Qt build completed successfully in WSL2!"