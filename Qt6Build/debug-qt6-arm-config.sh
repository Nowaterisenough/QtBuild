#!/bin/bash

# Qt6 ARM交叉编译调试脚本
# 用于诊断和修复配置问题

set -e  # 遇到错误时退出

# 参数解析
QT_VERSION=${1:-"6.9.1"}
ARM_ARCH=${2:-"aarch64"}

echo "=== Qt6 ARM交叉编译调试脚本 ==="
echo "Qt版本: $QT_VERSION"
echo "ARM架构: $ARM_ARCH"
echo "================================"

# 设置基础路径
QTBUILD_ROOT="/opt/QtBuild"
CROSS_COMPILE_PATH="${QTBUILD_ROOT}/arm-gcc-toolchain/${ARM_ARCH}/bin"
QT_PATH="${QTBUILD_ROOT}/Qt"

# 根据ARM架构设置交叉编译器前缀
case "$ARM_ARCH" in
    "aarch64")
        CROSS_PREFIX="aarch64-linux-gnu-"
        QT_PLATFORM="linux-aarch64-gnu-g++"
        ;;
    "armv7l")
        CROSS_PREFIX="arm-linux-gnueabihf-"
        QT_PLATFORM="linux-arm-gnueabi-g++"
        ;;
    *)
        echo "错误: 不支持的ARM架构: $ARM_ARCH"
        exit 1
        ;;
esac

BUILD_PATH="${QTBUILD_ROOT}/build_arm_debug"
TEMP_INSTALL_DIR="${QTBUILD_ROOT}/temp_install_arm_debug"
ARM_SYSROOT="${QTBUILD_ROOT}/sysroot/${ARM_ARCH}"
SRC_QT="${QT_PATH}/${QT_VERSION}/qt-everywhere-src-${QT_VERSION}"
HOST_QT_PATH="${QT_PATH}/${QT_VERSION}-host"

echo "1. 检查目录结构..."
echo "   源码目录: $SRC_QT"
echo "   构建目录: $BUILD_PATH"
echo "   工具链目录: $CROSS_COMPILE_PATH"
echo "   Sysroot目录: $ARM_SYSROOT"
echo "   Host Qt目录: $HOST_QT_PATH"

# 检查Host Qt
if [ ! -d "$HOST_QT_PATH" ]; then
    echo "警告: Host Qt目录不存在: $HOST_QT_PATH"
    echo "尝试创建最小的host Qt..."
    
    mkdir -p "${HOST_QT_PATH}-build"
    cd "${HOST_QT_PATH}-build"
    
    echo "配置host Qt..."
    "$SRC_QT/configure" -static -prefix "$HOST_QT_PATH" \
      -nomake examples -nomake tests -no-gui -no-widgets \
      -opensource -confirm-license -release
    
    echo "构建host Qt..."
    make -j$(nproc) && make install
    
    cd "$QTBUILD_ROOT"
    rm -rf "${HOST_QT_PATH}-build"
fi

if [ -f "$HOST_QT_PATH/bin/qmake" ]; then
    echo "   ✓ Host Qt可用: $($HOST_QT_PATH/bin/qmake -query QT_VERSION)"
else
    echo "   ✗ Host Qt不可用"
fi

# 检查Qt源码
if [ ! -d "$SRC_QT" ]; then
    echo "错误: Qt源码目录不存在: $SRC_QT"
    echo "请确保Qt源码已正确下载和解压"
    exit 1
fi
echo "   ✓ Qt源码目录存在"

# 检查configure脚本
if [ ! -f "$SRC_QT/configure" ]; then
    echo "错误: configure脚本不存在: $SRC_QT/configure"
    exit 1
fi
echo "   ✓ configure脚本存在"

echo ""
echo "2. 检查交叉编译工具链..."

# 设置PATH
export PATH="${CROSS_COMPILE_PATH}:$PATH"

# 检查各个工具
TOOLS=("gcc" "g++" "ar" "strip" "objcopy" "objdump" "ld" "ranlib")
for tool in "${TOOLS[@]}"; do
    TOOL_PATH="${CROSS_COMPILE_PATH}/${CROSS_PREFIX}${tool}"
    if [ -f "$TOOL_PATH" ] || command -v "${CROSS_PREFIX}${tool}" >/dev/null 2>&1; then
        echo "   ✓ ${CROSS_PREFIX}${tool} 可用"
    else
        echo "   ✗ ${CROSS_PREFIX}${tool} 不可用"
        echo "     预期路径: $TOOL_PATH"
        echo "     或系统PATH中: ${CROSS_PREFIX}${tool}"
    fi
done

# 测试编译器
echo ""
echo "3. 测试交叉编译器..."
export CC="${CROSS_PREFIX}gcc"
export CXX="${CROSS_PREFIX}g++"

if command -v "$CC" >/dev/null 2>&1; then
    echo "   测试C编译器: $CC"
    $CC --version | head -1
    
    # 简单编译测试
    cat > /tmp/test.c << 'EOF'
#include <stdio.h>
int main() { printf("Hello\n"); return 0; }
EOF
    
    if $CC /tmp/test.c -o /tmp/test_arm 2>/dev/null; then
        echo "   ✓ C编译器工作正常"
        file /tmp/test_arm | grep -E "(ARM|aarch64)" && echo "   ✓ 生成正确的ARM目标文件"
        rm -f /tmp/test.c /tmp/test_arm
    else
        echo "   ✗ C编译器编译失败"
    fi
else
    echo "   ✗ C编译器不可用: $CC"
fi

echo ""
echo "4. 检查和创建必要目录..."

# 清理并创建构建目录
rm -rf "$BUILD_PATH" "$TEMP_INSTALL_DIR"
mkdir -p "$BUILD_PATH" "$TEMP_INSTALL_DIR"
echo "   ✓ 构建目录已创建: $BUILD_PATH"

# 检查并创建sysroot
if [ ! -d "$ARM_SYSROOT" ]; then
    echo "   警告: Sysroot不存在，创建最小结构..."
    mkdir -p "$ARM_SYSROOT"/{lib,usr/lib,usr/include}
    echo "   ✓ 最小sysroot已创建"
else
    echo "   ✓ Sysroot存在: $ARM_SYSROOT"
fi

echo ""
echo "5. 生成简化配置..."

cd "$BUILD_PATH"

# 最小化配置选项 - 只包含必须的模块
MINIMAL_CFG_OPTIONS=(
    "-static"
    "-prefix" "$TEMP_INSTALL_DIR"
    "-nomake" "examples"
    "-nomake" "tests"
    "-no-gui"
    "-no-widgets" 
    "-no-dbus"
    "-no-openssl"
    "-no-icu"
    "-opensource"
    "-confirm-license"
    "-platform" "$QT_PLATFORM"
    "-device-option" "CROSS_COMPILE=$CROSS_PREFIX"
    "-qt-zlib"
    "-qt-libpng"
    "-qt-libjpeg"
    "-release"
    "-optimize-size"
    "-no-feature-concurrent"
    "-no-feature-sql"
    "-no-feature-network"
    "-no-feature-xml"
    "-no-feature-testlib"
    "-qt-host-path" "$HOST_QT_PATH"
)

# 如果sysroot有内容，添加sysroot选项
if [ -d "$ARM_SYSROOT" ] && [ "$(ls -A "$ARM_SYSROOT" 2>/dev/null)" ]; then
    MINIMAL_CFG_OPTIONS+=("-sysroot" "$ARM_SYSROOT")
    echo "   使用sysroot: $ARM_SYSROOT"
else
    echo "   不使用sysroot"
fi

echo ""
echo "6. 配置命令:"
echo "   $SRC_QT/configure ${MINIMAL_CFG_OPTIONS[*]}"

echo ""
echo "7. 开始配置..."

# 设置环境变量
export AR="${CROSS_PREFIX}ar"
export STRIP="${CROSS_PREFIX}strip"
export OBJCOPY="${CROSS_PREFIX}objcopy"
export OBJDUMP="${CROSS_PREFIX}objdump"
export RANLIB="${CROSS_PREFIX}ranlib"
export LD="${CROSS_PREFIX}ld"

# 运行configure
"$SRC_QT/configure" "${MINIMAL_CFG_OPTIONS[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ 配置成功完成！"
    echo ""
    echo "现在可以运行以下命令进行构建:"
    echo "   cd $BUILD_PATH"
    echo "   cmake --build . --parallel \$(nproc)"
    echo "   cmake --install ."
else
    echo ""
    echo "✗ 配置失败"
    echo ""
    echo "请检查上面的输出信息，常见问题："
    echo "1. 交叉编译工具链未正确安装"
    echo "2. 缺少必要的开发库"
    echo "3. Sysroot配置问题"
    echo "4. Qt源码不完整或损坏"
    echo ""
    echo "建议:"
    echo "1. 安装交叉编译工具链:"
    echo "   sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
    echo "2. 安装构建依赖:"
    echo "   sudo apt-get install build-essential cmake ninja-build"
    echo "3. 重新下载Qt源码"
    
    exit 1
fi
