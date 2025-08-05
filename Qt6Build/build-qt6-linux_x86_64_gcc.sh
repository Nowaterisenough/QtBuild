#!/usr/bin/env bash
set -e

# -------- 参数 --------
QT_VERSION=${QT_VERSION:-6.9.1}
GCC_VERSION=${GCC_VERSION:-13}
BUILD_TYPE=${BUILD_TYPE:-release}     # release | debug
LINK_TYPE=${LINK_TYPE:-shared}        # shared  | static
SEPARATE_DEBUG=${SEPARATE_DEBUG:-false}

# -------- 解压源码 --------
tar -xf qt-everywhere-src-${QT_VERSION}.tar.xz
rm  -f qt-everywhere-src-${QT_VERSION}.tar.xz

SRC_QT=$PWD/qt-everywhere-src-${QT_VERSION}
BUILD_DIR=$PWD/build
INSTALL_DIR=$PWD/output/qt-${QT_VERSION}-${LINK_TYPE}-gcc${GCC_VERSION}

mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"
cd "${BUILD_DIR}"

# -------- 配置 --------
CFG="-${LINK_TYPE} -prefix ${INSTALL_DIR} \
     -nomake examples -nomake tests -c++std c++20 -skip qtwebengine \
     -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre \
     -openssl-linked -platform linux-g++ -opengl desktop"

[[ "${BUILD_TYPE}" == debug ]] && CFG="${CFG} -debug" || CFG="${CFG} -release"
if [[ "${LINK_TYPE}" == shared && "${SEPARATE_DEBUG}" == true ]]; then
    CFG="${CFG} -force-debug-info -separate-debug-info"
fi

"${SRC_QT}/configure" ${CFG}
cmake --build . --parallel $(nproc)
cmake --install .

# -------- 打包 --------
ARCHIVE_NAME="qt${QT_VERSION}-linux-x86_64-gcc${GCC_VERSION}-${LINK_TYPE}_${BUILD_TYPE}.tar.xz"
tar -cJf "${ARCHIVE_NAME}" -C "${INSTALL_DIR}" .

# 返回给 GitHub Actions（可选）
[ -n "${GITHUB_ENV}" ] && echo "ARCHIVE_NAME=${ARCHIVE_NAME}" >> "${GITHUB_ENV}"