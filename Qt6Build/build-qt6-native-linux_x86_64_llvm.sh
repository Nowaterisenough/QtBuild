#!/bin/bash
# ============================================================================
# Qt 6 Linux LLVM Build Script
# Parameters: QT_VERSION LLVM_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG VULKAN_SDK TEST_MODE
# ============================================================================

set -e

# === Parameter Extraction ===
QT_VERSION="${1}"
LLVM_VERSION="${2}"
BUILD_TYPE="${3}"
LINK_TYPE="${4}"
SEPARATE_DEBUG="${5}"
VULKAN_SDK="${6}"
TEST_MODE="${7}"

# === Parameter Validation ===
if [ -z "$QT_VERSION" ]; then
    echo "ERROR: QT_VERSION not provided"
    exit 1
fi
if [ -z "$LLVM_VERSION" ]; then
    echo "ERROR: LLVM_VERSION not provided"
    exit 1
fi

BUILD_TYPE="${BUILD_TYPE:-release}"
LINK_TYPE="${LINK_TYPE:-shared}"
SEPARATE_DEBUG="${SEPARATE_DEBUG:-false}"
VULKAN_SDK="${VULKAN_SDK:-none}"
TEST_MODE="${TEST_MODE:-false}"

# === Compiler Environment ===
export CC=clang-${LLVM_VERSION}
export CXX=clang++-${LLVM_VERSION}
export LLVM_INSTALL_DIR=/usr/lib/llvm-${LLVM_VERSION}

# === Path Setup ===
SRC_QT="$(pwd)/qt-everywhere-src-${QT_VERSION}"
BUILD_DIR="$(pwd)/build"
INSTALL_DIR="$(pwd)/output"

echo "=== Qt ${QT_VERSION} Linux LLVM ${LLVM_VERSION} Build ==="
echo "Build Type: ${BUILD_TYPE}"
echo "Link Type: ${LINK_TYPE}"
echo "Test Mode: ${TEST_MODE}"
echo "Vulkan: ${VULKAN_SDK}"
echo "Compiler: ${CC} / ${CXX}"
echo "Install: ${INSTALL_DIR}"

# === Extract Qt Source ===
if [ ! -f "qt-everywhere-src-${QT_VERSION}.tar.xz" ]; then
    echo "ERROR: Qt source file not found"
    exit 1
fi

echo "Extracting Qt source..."
tar -xf "qt-everywhere-src-${QT_VERSION}.tar.xz"
rm "qt-everywhere-src-${QT_VERSION}.tar.xz"

# === Directory Preparation ===
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"
cd "$BUILD_DIR"

# === Base Configuration ===
CFG_OPTIONS="-${LINK_TYPE} -prefix ${INSTALL_DIR} -nomake examples -nomake tests -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -openssl-linked -platform linux-clang -opengl desktop"

# === Module Selection ===
if [ "$TEST_MODE" = "true" ]; then
    CFG_OPTIONS="${CFG_OPTIONS} -submodules qtbase"
    echo "Module: qtbase only"
else
    CFG_OPTIONS="${CFG_OPTIONS} -skip qtwebengine"
    echo "Module: all except qtwebengine"
fi

# === Build Type Configuration ===
if [ "$BUILD_TYPE" = "debug" ]; then
    CFG_OPTIONS="${CFG_OPTIONS} -debug"
else
    CFG_OPTIONS="${CFG_OPTIONS} -release"
fi

# === Debug Info Configuration ===
if [ "$LINK_TYPE" = "shared" ] && [ "$SEPARATE_DEBUG" = "true" ]; then
    CFG_OPTIONS="${CFG_OPTIONS} -force-debug-info -separate-debug-info"
fi

# === Vulkan Configuration ===
if [ "$VULKAN_SDK" = "none" ]; then
    CFG_OPTIONS="${CFG_OPTIONS} -no-feature-vulkan"
    echo "Vulkan: disabled"
else
    echo "Vulkan: enabled (runtime)"
fi

# === SQL Driver Configuration (only non-test mode) ===
if [ "$TEST_MODE" = "false" ]; then
    # SQLite is built-in
    CFG_OPTIONS="${CFG_OPTIONS} -sql-sqlite"

    # PostgreSQL - 必须存在
    if [ -z "$PostgreSQL_ROOT" ]; then
        echo "ERROR: PostgreSQL_ROOT not defined"
        exit 1
    fi
    if [ ! -d "$PostgreSQL_ROOT" ]; then
        echo "ERROR: PostgreSQL_ROOT not found: $PostgreSQL_ROOT"
        exit 1
    fi
    CFG_OPTIONS="${CFG_OPTIONS} -sql-psql"
    export PostgreSQL_INCLUDE_DIRS="${PostgreSQL_ROOT}/include"
    export PostgreSQL_LIBRARY_DIRS="${PostgreSQL_ROOT}/lib"
    echo "SQL: SQLite + PostgreSQL"

    # MySQL - 必须存在
    if [ -z "$MYSQL_ROOT" ]; then
        echo "ERROR: MYSQL_ROOT not defined"
        exit 1
    fi
    if [ ! -d "$MYSQL_ROOT" ]; then
        echo "ERROR: MYSQL_ROOT not found: $MYSQL_ROOT"
        exit 1
    fi
    CFG_OPTIONS="${CFG_OPTIONS} -sql-mysql"
    export MySQL_INCLUDE_DIRS="${MYSQL_ROOT}/include"
    export MySQL_LIBRARY_DIRS="${MYSQL_ROOT}/lib"
    echo "SQL: SQLite + PostgreSQL + MySQL"
fi

echo "Configure: ${CFG_OPTIONS}"

# === Compiler Flags ===
export CFLAGS="-fuse-ld=lld -fno-lto"
export CXXFLAGS="-fuse-ld=lld -stdlib=libc++ -fno-lto"
export LDFLAGS="-fuse-ld=lld -stdlib=libc++ -Wl,--no-keep-memory"

# === Configure ===
"${SRC_QT}/configure" ${CFG_OPTIONS}

# === Build ===
PARALLEL_JOBS=$(nproc)
if [ $PARALLEL_JOBS -gt 2 ]; then
    PARALLEL_JOBS=2
fi

echo "Building with ${PARALLEL_JOBS} parallel jobs (LLVM needs more memory)..."
cmake --build . --parallel ${PARALLEL_JOBS}

# === Install ===
cmake --install .

# === Cleanup ===
cd ..
rm -rf "$BUILD_DIR"
rm -rf "qt-everywhere-src-${QT_VERSION}"

echo "=== Build Completed ==="
echo "Install: ${INSTALL_DIR}"
if [ "$TEST_MODE" = "true" ]; then
    echo "NOTE: Test mode - qtbase only"
fi
