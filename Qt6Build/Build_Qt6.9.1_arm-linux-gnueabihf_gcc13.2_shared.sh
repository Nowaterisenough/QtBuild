#!/bin/bash

# 设置编码
export LANG=en_US.UTF-8

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置Qt版本
QT_VERSION=6.9.1

# 设置交叉编译器版本代号
CROSS_VERSION=armhf_gcc13_2

# 设置交叉编译工具链
CROSS_PREFIX="/opt/arm-linux-gnueabihf"
export CC="$CROSS_PREFIX/bin/arm-linux-gnueabihf-gcc"
export CXX="$CROSS_PREFIX/bin/arm-linux-gnueabihf-g++"
export AR="$CROSS_PREFIX/bin/arm-linux-gnueabihf-ar"
export STRIP="$CROSS_PREFIX/bin/arm-linux-gnueabihf-strip"
export OBJCOPY="$CROSS_PREFIX/bin/arm-linux-gnueabihf-objcopy"
export NM="$CROSS_PREFIX/bin/arm-linux-gnueabihf-nm"
export RANLIB="$CROSS_PREFIX/bin/arm-linux-gnueabihf-ranlib"

# 设置目标系统根目录
SYSROOT="$CROSS_PREFIX/arm-linux-gnueabihf/sysroot"

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
INSTALL_DIR="$QT_PATH/$QT_VERSION-shared/$CROSS_VERSION"

# 设置build文件夹目录
BUILD_DIR="$QT_PATH/$QT_VERSION/build-shared-$CROSS_VERSION"

# 显示交叉编译器版本信息
echo "Using cross-compiler:"
echo "Target: arm-linux-gnueabihf"
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

# 检查configure是否成功
configure_qt() {
    "$SRC_QT/configure" \
        -shared \
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
        -xplatform linux-arm-gnueabihf-g++ \
        -device-option CROSS_COMPILE=arm-linux-gnueabihf- \
        -cmake-file-api
}

# configure
echo "Configuring Qt for ARM32 (shared)..."
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

# 创建部署脚本
cat > "$INSTALL_DIR/deploy.sh" << 'EOF'
#!/bin/bash
# Qt ARM32 部署脚本

TARGET_DIR="/opt/qt6"
QTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying Qt to target device..."
echo "Source: $QTDIR"
echo "Target: $TARGET_DIR"

# 创建目标目录
sudo mkdir -p "$TARGET_DIR"

# 复制Qt文件
sudo cp -r "$QTDIR"/* "$TARGET_DIR/"

# 设置权限
sudo chmod -R 755 "$TARGET_DIR"

# 创建环境设置脚本
sudo tee "$TARGET_DIR/setup_env.sh" > /dev/null << 'ENVEOF'
#!/bin/bash
export QTDIR="/opt/qt6"
export PATH="$QTDIR/bin:$PATH"
export LD_LIBRARY_PATH="$QTDIR/lib:$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="$QTDIR/plugins"
export QML_IMPORT_PATH="$QTDIR/qml"
export QT_QPA_PLATFORM="linuxfb"
export QT_QPA_FONTDIR="$QTDIR/lib/fonts"
ENVEOF

sudo chmod +x "$TARGET_DIR/setup_env.sh"

echo "Deployment completed!"
echo "Run 'source /opt/qt6/setup_env.sh' on target device to set up environment"
EOF

chmod +x "$INSTALL_DIR/deploy.sh"

# 创建交叉编译信息文件
cat > "$INSTALL_DIR/cross-compile-info.txt" << EOF
Qt Cross-Compilation Information
================================
Qt Version: $QT_VERSION
Target Architecture: ARM32 (armhf)
Target OS: Linux (Embedded)
Cross-Compiler: arm-linux-gnueabihf-gcc
Build Type: Shared Release
CPU Optimization: Cortex-A7, NEON, Hard Float
Features: Framebuffer, No X11, No OpenGL, No D-Bus

Common Target Devices:
- Raspberry Pi 2/3/4 (32-bit mode)
- BeagleBone Black
- i.MX6/i.MX7 based boards
- AllWinner H3/H5 based boards

Deployment Instructions:
1. Copy files to target device using deploy.sh script
2. Run 'source /opt/qt6/setup_env.sh' on target device
3. Ensure target device has compatible glibc version

Libraries will be installed to: $INSTALL_DIR/lib

Cross-compilation completed on: $(date)
EOF

# 列出生成的动态库
echo ""
echo "Generated Qt libraries:"
find "$INSTALL_DIR/lib" -name "libQt6*.so*" -type f | sort

echo "Build completed successfully!"
echo "Installation directory: $INSTALL_DIR"
echo "Target: ARM32 Linux Embedded System (Shared)"
echo "Use deploy.sh script to deploy to target device"

# 进入安装目录
cd "$INSTALL_DIR"