#!/bin/bash
# ============================================================================
# WSL2 Environment Setup for Qt LLVM Build
# Parameters: LLVM_VERSION VULKAN_SDK
# ============================================================================

set -e

LLVM_VERSION="${1}"
VULKAN_SDK="${2}"

echo "=== WSL2 LLVM ${LLVM_VERSION} Environment Setup ==="

export DEBIAN_FRONTEND=noninteractive

# === Enable Universe Repository ===
echo "Enabling Ubuntu Universe repository..."
sudo add-apt-repository universe -y >/dev/null 2>&1
sudo apt-get update -qq

# === Install Base Build Tools ===
echo "Installing base build tools..."
sudo apt-get install -y -qq --no-install-recommends \
    build-essential cmake ninja-build python3 pkg-config \
    wget curl xz-utils

# === Install LLVM Compiler ===
echo "Adding LLVM APT repository..."
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc >/dev/null
echo "deb http://apt.llvm.org/noble/ llvm-toolchain-noble-${LLVM_VERSION} main" | sudo tee /etc/apt/sources.list.d/llvm.list
sudo apt-get update -qq

echo "Installing LLVM/Clang-${LLVM_VERSION} toolchain..."
sudo apt-get install -y -qq --no-install-recommends \
    clang-${LLVM_VERSION} clang++-${LLVM_VERSION} lld-${LLVM_VERSION} \
    libc++-${LLVM_VERSION}-dev libc++abi-${LLVM_VERSION}-dev \
    libclang-${LLVM_VERSION}-dev llvm-${LLVM_VERSION}-dev

# Qt Tools 需要 libclang,可能会找到系统的旧版本,同时安装系统版本的开发包
echo "Installing system LLVM development libraries for Qt Tools..."
sudo apt-get install -y -qq --no-install-recommends \
    libclang-dev llvm-dev || true

# === Setup Alternatives ===
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${LLVM_VERSION} 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${LLVM_VERSION} 100
sudo update-alternatives --install /usr/bin/lld lld /usr/bin/lld-${LLVM_VERSION} 100

# === Install Qt Dependencies ===
echo "Installing X11/OpenGL libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libgl1-mesa-dev libglu1-mesa-dev libx11-dev libxext-dev \
    libxrender-dev libxrandr-dev libxcursor-dev

echo "Installing XCB libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libxcb1-dev libxcb-util-dev libxcb-image0-dev libxcb-keysyms1-dev \
    libxcb-render0-dev libxcb-render-util0-dev libxcb-randr0-dev libxcb-cursor-dev

echo "Installing Wayland libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libwayland-dev libwayland-egl1-mesa libwayland-cursor0 \
    wayland-protocols libxkbcommon-dev

echo "Installing remaining dependencies..."
sudo apt-get install -y -qq --no-install-recommends \
    libxkbcommon-x11-dev libfontconfig1-dev \
    libfreetype6-dev libglib2.0-dev libegl1-mesa-dev libssl-dev

# === Install Database Development Libraries ===
echo "Installing PostgreSQL development libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libpq-dev postgresql-server-dev-all

echo "Installing MySQL development libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libmysqlclient-dev

# === Install JeMalloc for Memory Allocator ===
echo "Installing JeMalloc memory allocator..."
sudo apt-get install -y -qq --no-install-recommends \
    libjemalloc-dev

# Set environment variables for Qt configure
export PostgreSQL_ROOT=/usr
export MYSQL_ROOT=/usr
echo "PostgreSQL: /usr (libpq-dev installed)"
echo "MySQL: /usr (libmysqlclient-dev installed)"

# === Compiler Verification ===
echo "=== Compiler Verification ==="
clang-${LLVM_VERSION} --version | head -1
clang++-${LLVM_VERSION} --version | head -1
lld-${LLVM_VERSION} --version | head -1

# === Install Vulkan SDK ===
if [ "$VULKAN_SDK" != "none" ]; then
    echo "Installing Vulkan runtime library..."
    sudo apt-get install -y -qq --no-install-recommends libvulkan-dev

    vulkan_version=$(echo "$VULKAN_SDK" | sed 's/runtime-//')

    if [ "$vulkan_version" = "1.4.335.0" ] || [ "$vulkan_version" = "1.3.290.0" ]; then
        echo "Installing Vulkan SDK headers: $vulkan_version"
        cd /tmp
        wget -q https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-${vulkan_version}.tar.gz
        tar -xzf vulkan-sdk-${vulkan_version}.tar.gz
        cd Vulkan-Headers-vulkan-sdk-${vulkan_version}
        sudo cp -r include/vulkan /usr/local/include/
        sudo cp -r include/vk_video /usr/local/include/ 2>/dev/null || true
        cd /tmp
        rm -rf Vulkan-Headers-* vulkan-sdk-*.tar.gz
        echo "Vulkan headers updated to: $vulkan_version"
    fi
fi

# === Cleanup ===
sudo apt-get clean >/dev/null 2>&1
sudo rm -rf /var/lib/apt/lists/*

echo "=== WSL2 LLVM Environment Setup Completed ==="
