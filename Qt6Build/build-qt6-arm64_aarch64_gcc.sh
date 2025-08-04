#!/bin/bash

# ARM交叉编译Qt6构建脚本 (Linux Host)
# 用法: ./build-qt6-arm64_aarch64_gcc.sh <Qt版本> <GCC版本> <BUILD_TYPE> <LINK_TYPE> <SEPARATE_DEBUG> <ARM_ARCH>
# 例如: ./build-qt6-arm64_aarch64_gcc.sh 6.9.1 13.2.0 release static false aarch64

set -e  # 遇到错误时退出

# 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, ARM_ARCH
QT_VERSION=$1
GCC_VERSION=$2
BUILD_TYPE=$3
LINK_TYPE=$4
SEPARATE_DEBUG=$5
ARM_ARCH=$6

# 参数验证
if [ $# -ne 6 ]; then
    echo "用法: $0 <Qt版本> <GCC版本> <BUILD_TYPE> <LINK_TYPE> <SEPARATE_DEBUG> <ARM_ARCH>"
    echo "例如: $0 6.9.1 13.2.0 release static false aarch64"
    echo "ARM_ARCH 支持: aarch64, armv7l, armv6l"
    exit 1
fi

# 例如: 6.9.1  13.2.0  release  static  false  aarch64
# ARM_ARCH 支持: aarch64, armv7l, armv6l

QT_VERSION2=${QT_VERSION:0:3}

# 设置ARM GCC交叉编译器版本标识
ARM_GCC_VERSION="arm_gcc${GCC_VERSION//./_}_${ARM_ARCH}"

# 设置基础路径
QTBUILD_ROOT="/opt/QtBuild"
CROSS_COMPILE_PATH="${QTBUILD_ROOT}/arm-gcc-toolchain/${ARM_ARCH}/bin"
QT_PATH="${QTBUILD_ROOT}/Qt"

# 根据ARM架构设置交叉编译器前缀和Qt平台
case "$ARM_ARCH" in
    "aarch64")
        CROSS_PREFIX="aarch64-linux-gnu-"
        QT_PLATFORM="linux-aarch64-gnu-g++"
        ;;
    "armv7l")
        CROSS_PREFIX="arm-linux-gnueabihf-"
        QT_PLATFORM="linux-arm-gnueabi-g++"
        ;;
    "armv6l")
        CROSS_PREFIX="arm-linux-gnueabihf-"
        QT_PLATFORM="linux-arm-gnueabi-g++"
        ;;
    *)
        echo "不支持的ARM架构: $ARM_ARCH"
        echo "支持的架构: aarch64, armv7l, armv6l"
        exit 1
        ;;
esac

# 设置PATH
export PATH="${CROSS_COMPILE_PATH}:${QTBUILD_ROOT}/ninja:${QTBUILD_ROOT}/protoc/bin:$PATH"

# 构建目录路径
BUILD_PATH="${QTBUILD_ROOT}/build_arm"
TEMP_INSTALL_DIR="${QTBUILD_ROOT}/temp_install_arm"

# 设置sysroot路径（需要提前准备目标系统的根文件系统）
ARM_SYSROOT="${QTBUILD_ROOT}/sysroot/${ARM_ARCH}"

# 路径和文件名定义
SRC_QT="${QT_PATH}/${QT_VERSION}/qt-everywhere-src-${QT_VERSION}"
HOST_QT_PATH="${QT_PATH}/${QT_VERSION}-host"
FINAL_INSTALL_DIR="${QT_PATH}/${QT_VERSION}-${LINK_TYPE}/${ARM_GCC_VERSION}"

# Host Qt下载URL
HOST_QT_URL="https://github.com/yuanpeirong/buildQt/releases/download/Qt6.9.1_rev0/Qt_6.9.1-static-Release_gcc13_2_0_64_linux.tar.gz"

echo "Starting Qt ARM cross-compilation build..."
echo "Qt Version: $QT_VERSION"
echo "GCC Version: $GCC_VERSION"
echo "Build Type: $BUILD_TYPE"
echo "Link Type: $LINK_TYPE"
echo "Separate Debug: $SEPARATE_DEBUG"
echo "ARM Architecture: $ARM_ARCH"
echo "Cross Compiler Prefix: $CROSS_PREFIX"
echo "Qt Platform: $QT_PLATFORM"
echo "Sysroot: $ARM_SYSROOT"
echo "Source: $SRC_QT"
echo "Host Qt: $HOST_QT_PATH"
echo "Final Install Dir: $FINAL_INSTALL_DIR"

# 下载并设置Host Qt
if [ ! -d "$HOST_QT_PATH" ]; then
    echo "下载Host Qt用于交叉编译..."
    mkdir -p "$HOST_QT_PATH"
    cd "$HOST_QT_PATH"
    
    echo "从以下地址下载: $HOST_QT_URL"
    if wget -q -O host-qt.tar.gz "$HOST_QT_URL"; then
        echo "解压Host Qt..."
        tar -xzf host-qt.tar.gz --strip-components=1
        rm host-qt.tar.gz
        echo "Host Qt设置完成。"
    else
        echo "Host Qt下载失败，将构建最小的host工具..."
        cd "$QT_PATH"
        rm -rf "$QT_VERSION-host"
        
        # 创建最小的host Qt构建
        mkdir -p "$QT_VERSION-host-build"
        cd "$QT_VERSION-host-build"
        
        echo "构建最小的host Qt工具..."
        "$SRC_QT/configure" -static -prefix "$HOST_QT_PATH" \
          -nomake examples -nomake tests -no-gui -no-widgets \
          -opensource -confirm-license -release
        make -j$(nproc) && make install
        cd "$QT_PATH"
        rm -rf "$QT_VERSION-host-build"
    fi
else
    echo "Host Qt已存在: $HOST_QT_PATH"
fi

# 验证host Qt
if [ -f "$HOST_QT_PATH/bin/qmake" ]; then
    echo "Host Qt工具可用: $($HOST_QT_PATH/bin/qmake -query QT_VERSION)"
else
    echo "错误: Host Qt工具未找到"
    exit 1
fi

# 检查交叉编译器是否存在
if [ ! -f "${CROSS_COMPILE_PATH}/${CROSS_PREFIX}gcc" ]; then
    echo "错误: 交叉编译器未找到: ${CROSS_COMPILE_PATH}/${CROSS_PREFIX}gcc"
    echo "请安装ARM GCC交叉编译工具链"
    echo "Ubuntu/Debian: sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
    exit 1
fi

# 检查Qt源码是否存在
if [ ! -d "$SRC_QT" ]; then
    echo "错误: Qt源码目录未找到: $SRC_QT"
    echo "请下载并解压Qt源码到指定目录"
    exit 1
fi

# 检查sysroot是否存在
if [ ! -d "$ARM_SYSROOT" ]; then
    echo "警告: ARM sysroot未找到: $ARM_SYSROOT"
    echo "建议准备目标系统根文件系统以获得更好的兼容性"
    # 创建最小sysroot目录结构
    mkdir -p "$ARM_SYSROOT"/{lib,usr/lib,usr/include}
fi

# 清理并创建build目录
rm -rf "$BUILD_PATH" "$TEMP_INSTALL_DIR"
mkdir -p "$BUILD_PATH" "$TEMP_INSTALL_DIR"
cd "$BUILD_PATH"

# 配置参数 - 针对ARM嵌入式设备优化
CFG_OPTIONS="-${LINK_TYPE} -prefix $TEMP_INSTALL_DIR -nomake examples -nomake tests -c++std c++17 -headersclean -skip qtwebengine -skip qtwebkit -skip qtmultimedia -skip qtlocation -skip qtspeech -skip qtserialport -skip qtnetworkauth -skip qtremoteobjects -skip qtscxml -skip qtvirtualkeyboard -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -no-openssl -no-dbus -no-glib -no-icu -platform $QT_PLATFORM -device-option CROSS_COMPILE=$CROSS_PREFIX -no-feature-getentropy -qt-host-path $HOST_QT_PATH"

# 如果sysroot存在且不为空，添加sysroot选项
if [ -d "$ARM_SYSROOT" ] && [ "$(ls -A $ARM_SYSROOT 2>/dev/null)" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -sysroot $ARM_SYSROOT"
else
    echo "警告: 使用系统默认库路径，可能导致兼容性问题"
fi

# 根据构建类型添加相应选项
if [ "$BUILD_TYPE" = "debug" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -debug"
else
    CFG_OPTIONS="$CFG_OPTIONS -release -optimize-size"
fi

# static 不能分离调试信息
if [ "$LINK_TYPE" = "shared" ] && [ "$SEPARATE_DEBUG" = "true" ]; then
    CFG_OPTIONS="$CFG_OPTIONS -force-debug-info -separate-debug-info"
fi

# 设置交叉编译环境变量
export CC="${CROSS_PREFIX}gcc"
export CXX="${CROSS_PREFIX}g++"
export AR="${CROSS_PREFIX}ar"
export STRIP="${CROSS_PREFIX}strip"
export OBJCOPY="${CROSS_PREFIX}objcopy"
export OBJDUMP="${CROSS_PREFIX}objdump"
export PKG_CONFIG="${CROSS_PREFIX}pkg-config"
export RANLIB="${CROSS_PREFIX}ranlib"
export LD="${CROSS_PREFIX}ld"

# 设置编译器标志
export CFLAGS="-O2"
export CXXFLAGS="-O2"
export LDFLAGS=""

# 如果有sysroot，设置PKG_CONFIG_PATH
if [ -d "$ARM_SYSROOT" ]; then
    export PKG_CONFIG_PATH="$ARM_SYSROOT/usr/lib/pkgconfig:$ARM_SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_LIBDIR="$ARM_SYSROOT/usr/lib/pkgconfig:$ARM_SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR="$ARM_SYSROOT"
fi

echo "Configure options: $CFG_OPTIONS"
echo "Cross-compilation environment:"
echo "  CC=$CC"
echo "  CXX=$CXX"
echo "  AR=$AR"
echo "  PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

# 验证交叉编译器工作正常
echo "验证交叉编译器..."
$CC --version || { echo "错误: 交叉编译器 $CC 不可用"; exit 1; }
$CXX --version || { echo "错误: 交叉编译器 $CXX 不可用"; exit 1; }

# 创建简单的测试程序验证编译器
echo "测试交叉编译器..."
cat > test_compiler.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello ARM World!\n");
    return 0;
}
EOF

if $CC test_compiler.c -o test_compiler_arm; then
    echo "交叉编译器测试成功"
    file test_compiler_arm
    rm -f test_compiler.c test_compiler_arm
else
    echo "错误: 交叉编译器测试失败"
    exit 1
fi

# configure
echo "开始配置Qt..."
echo "Configuring Qt..."
"$SRC_QT/configure" $CFG_OPTIONS
if [ $? -ne 0 ]; then
    echo "Configure失败，错误码: $?"
    exit 1
fi

# 构建
echo "开始交叉编译构建..."
cmake --build . --parallel $(nproc)
if [ $? -ne 0 ]; then
    echo "构建失败，错误码: $?"
    exit 1
fi

# 安装到临时目录
echo "安装到临时目录..."
cmake --install .
if [ $? -ne 0 ]; then
    echo "安装失败，错误码: $?"
    exit 1
fi

# 创建最终安装目录的父目录
mkdir -p "$(dirname "$FINAL_INSTALL_DIR")"

# 移动文件到最终目录
echo "移动文件到最终目录..."
if [ -d "$TEMP_INSTALL_DIR" ]; then
    mv "$TEMP_INSTALL_DIR" "$FINAL_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo "移动到最终目录失败，尝试复制..."
        cp -r "$TEMP_INSTALL_DIR"/* "$FINAL_INSTALL_DIR"/
        if [ $? -ne 0 ]; then
            echo "复制也失败了"
            exit 1
        fi
        rm -rf "$TEMP_INSTALL_DIR"
    fi
else
    echo "错误: 临时安装目录不存在"
    exit 1
fi

# 复制qt.conf (如果存在)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/qt.conf" ]; then
    cp "$SCRIPT_DIR/qt.conf" "$FINAL_INSTALL_DIR/bin/"
fi

# 创建ARM设备专用的qt.conf
cat > "$FINAL_INSTALL_DIR/bin/qt.conf" << EOF
[Paths]
Prefix = .
LibraryExecutables = bin
Binaries = bin
Libraries = lib
Headers = include
EOF

# 设置可执行权限
chmod +x "$FINAL_INSTALL_DIR/bin"/*

echo "ARM交叉编译构建成功完成！"
echo "安装目录: $FINAL_INSTALL_DIR"
echo "目标架构: $ARM_ARCH"
echo ""
echo "要在ARM设备上使用此Qt构建："
echo "1. 将整个安装目录复制到ARM设备"
echo "2. 设置PATH包含Qt bin目录"
echo "3. 设置LD_LIBRARY_PATH包含Qt lib目录（共享构建）"
echo "4. 确保目标设备有相应的运行时库"

# 验证安装目录存在
if [ -d "$FINAL_INSTALL_DIR" ]; then
    echo "最终安装目录验证成功。"
    ls -la "$FINAL_INSTALL_DIR"
else
    echo "错误: 最终安装目录不存在！"
    exit 1
fi

echo "构建脚本执行完成。"
