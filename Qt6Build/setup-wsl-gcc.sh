#!/bin/bash
# ============================================================================
# WSL2 Environment Setup for Qt GCC Build
# Parameters: GCC_VERSION VULKAN_SDK
# ============================================================================

set -e

GCC_VERSION="${1}"
VULKAN_SDK="${2}"

echo "=== WSL2 GCC ${GCC_VERSION} Environment Setup ==="

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

# === Install GCC Compiler ===
if [ "$GCC_VERSION" = "15.2" ]; then
    GCC_PREFIX=/opt/gcc-15.2
    CACHE_FILE="$(pwd)/gcc-15.2-install.tar.xz"

    if [ -f "$CACHE_FILE" ]; then
        echo "Restoring GCC 15.2 from cache..."
        sudo mkdir -p $GCC_PREFIX
        sudo tar -xJf "$CACHE_FILE" -C /
    else
        echo "Building GCC 15.2 from source (60-90 minutes)..."
        sudo apt-get install -y -qq libgmp-dev libmpfr-dev libmpc-dev flex
        cd /tmp
        wget -q https://ftp.gnu.org/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz
        tar -xf gcc-15.2.0.tar.xz
        cd gcc-15.2.0
        ./configure --prefix=$GCC_PREFIX --enable-languages=c,c++ --disable-multilib --disable-bootstrap
        make -j$(nproc)
        sudo make install
        cd ..
        rm -rf gcc-15.2.0*
        sudo tar -cJf "$CACHE_FILE" -C / opt/gcc-15.2
    fi

    sudo ln -sf $GCC_PREFIX/bin/gcc /usr/local/bin/gcc
    sudo ln -sf $GCC_PREFIX/bin/g++ /usr/local/bin/g++
    export PATH="$GCC_PREFIX/bin:$PATH"
    export LD_LIBRARY_PATH="$GCC_PREFIX/lib64:$LD_LIBRARY_PATH"
    echo "export PATH=$GCC_PREFIX/bin:\$PATH" | sudo tee -a /etc/environment
    echo "export LD_LIBRARY_PATH=$GCC_PREFIX/lib64:\$LD_LIBRARY_PATH" | sudo tee -a /etc/environment
else
    echo "Installing GCC-${GCC_VERSION} from repository..."
    sudo apt-get install -y -qq --no-install-recommends \
        gcc-${GCC_VERSION} g++-${GCC_VERSION}
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100
fi

# === Install Qt Dependencies ===
echo "Installing X11/OpenGL libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libgl1-mesa-dev libglu1-mesa-dev libx11-dev libxext-dev \
    libxrender-dev libxrandr-dev libxcursor-dev

echo "Installing XCB libraries..."
sudo apt-get install -y -qq --no-install-recommends \
    libxcb1-dev libxcb-util-dev libxcb-image0-dev libxcb-keysyms1-dev \
    libxcb-render0-dev libxcb-render-util0-dev libxcb-randr0-dev libxcb-cursor-dev

echo "Installing remaining dependencies..."
sudo apt-get install -y -qq --no-install-recommends \
    libxkbcommon-dev libxkbcommon-x11-dev libfontconfig1-dev \
    libfreetype6-dev libglib2.0-dev libegl1-mesa-dev libssl-dev

# === Compiler Verification ===
echo "=== Compiler Verification ==="
gcc --version | head -1
g++ --version | head -1

# === Install Vulkan SDK ===
if [ "$VULKAN_SDK" != "none" ]; then
    echo "Installing Vulkan SDK headers..."
    vulkan_version=$(echo "$VULKAN_SDK" | sed 's/runtime-//')

    if [ "$vulkan_version" = "1.4.321.0" ] || [ "$vulkan_version" = "1.3.290.0" ]; then
        cd /tmp
        wget -q https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-${vulkan_version}.tar.gz
        tar -xzf vulkan-sdk-${vulkan_version}.tar.gz
        cd Vulkan-Headers-vulkan-sdk-${vulkan_version}
        sudo mkdir -p /usr/local/include
        sudo cp -r include/vulkan /usr/local/include/
        sudo cp -r include/vk_video /usr/local/include/ 2>/dev/null || true
        cd /tmp
        rm -rf Vulkan-Headers-* vulkan-sdk-*.tar.gz
        echo "Vulkan SDK headers installed: $vulkan_version"
    else
        sudo apt-get install -y -qq libvulkan-dev || echo "Warning: libvulkan-dev not available"
    fi
fi

# === Cleanup ===
sudo apt-get clean >/dev/null 2>&1
sudo rm -rf /var/lib/apt/lists/*

echo "=== WSL2 GCC Environment Setup Completed ==="
