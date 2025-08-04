# Qt6 ARM交叉编译构建指南

本项目提供了在Windows和Linux环境下为ARM设备交叉编译Qt6的构建脚本。

## 支持的ARM架构

- **aarch64** (ARM64): 适用于64位ARM处理器，如树莓派4、Jetson Nano等
- **armv7l** (ARM32 v7): 适用于32位ARMv7处理器，如树莓派3等
- **armv6l** (ARM32 v6): 适用于老版本32位ARM处理器，如树莓派1等

## 前期准备

### 1. 交叉编译工具链安装

#### Windows环境
下载并安装ARM GCC交叉编译工具链：

1. **AArch64 (ARM64)工具链**：
   - 下载: [Arm GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
   - 解压到: `D:\a\QtBuild\arm-gcc-toolchain\aarch64\`

2. **ARM32工具链**：
   - 下载: [Arm GNU Toolchain for A-profile](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
   - 解压到: `D:\a\QtBuild\arm-gcc-toolchain\armv7l\` 或 `D:\a\QtBuild\arm-gcc-toolchain\armv6l\`

#### Linux环境
```bash
# Ubuntu/Debian 安装交叉编译工具链
sudo apt-get update

# AArch64 (ARM64) 工具链
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# ARM32 工具链
sudo apt-get install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

# 或者从官方下载到指定目录
# 创建工具链目录
sudo mkdir -p /opt/QtBuild/arm-gcc-toolchain/{aarch64,armv7l,armv6l}
```

### 2. Sysroot准备（推荐）

Sysroot是目标系统的根文件系统副本，包含库文件和头文件，用于更精确的交叉编译。

#### 从目标设备获取sysroot
```bash
# 从树莓派或其他ARM设备同步sysroot
rsync -avz --rsync-path="sudo rsync" --delete pi@raspberrypi.local:/{lib,usr} ./sysroot/aarch64/

# 或者使用scp
scp -r pi@192.168.1.100:/lib ./sysroot/aarch64/
scp -r pi@192.168.1.100:/usr/lib ./sysroot/aarch64/usr/
scp -r pi@192.168.1.100:/usr/include ./sysroot/aarch64/usr/
```

#### 目录结构
```
D:\a\QtBuild\sysroot\aarch64\
├── lib/
├── usr/
│   ├── lib/
│   └── include/
└── opt/
```

## 使用方法

### Windows环境

```cmd
# 构建AArch64版本的Qt6
build-qt6-arm64_aarch64_gcc.cmd 6.9.1 13.2.0 release static false aarch64

# 构建ARM32版本的Qt6
build-qt6-arm64_aarch64_gcc.cmd 6.9.1 13.2.0 release static false armv7l
```

### Linux环境

```bash
# 设置可执行权限
chmod +x build-qt6-arm64_aarch64_gcc.sh

# 构建AArch64版本的Qt6
./build-qt6-arm64_aarch64_gcc.sh 6.9.1 13.2.0 release static false aarch64

# 构建ARM32版本的Qt6
./build-qt6-arm64_aarch64_gcc.sh 6.9.1 13.2.0 release static false armv7l
```

## 参数说明

1. **Qt版本**: 如 `6.9.1`
2. **GCC版本**: 如 `13.2.0`
3. **构建类型**: `release` 或 `debug`
4. **链接类型**: `static` 或 `shared`
5. **分离调试信息**: `true` 或 `false`
6. **ARM架构**: `aarch64`, `armv7l`, 或 `armv6l`

## 优化配置

针对ARM嵌入式设备，构建脚本包含以下优化：

### 编译优化
- 使用 `-optimize-size` 减小二进制大小
- 禁用不必要的模块（WebEngine, WebKit, Multimedia等）
- 启用静态编译减少依赖
- 使用C++17标准平衡功能和兼容性

### 功能裁剪
- 禁用GUI和Widgets（可根据需要启用）
- 禁用OpenGL（可根据需要启用）
- 禁用数据库驱动（PostgreSQL, ODBC）
- 禁用网络安全模块（OpenSSL, DBUS）

### 运行时优化
- 配置无头模式运行
- 优化内存使用
- 禁用磁盘缓存

## 部署到ARM设备

### 1. 复制Qt构建结果
```bash
# 将整个Qt安装目录复制到ARM设备
scp -r /opt/QtBuild/Qt/6.9.1-static/arm_gcc13_2_0_aarch64 pi@192.168.1.100:/opt/qt6
```

### 2. 设置环境变量
在ARM设备上设置环境变量：

```bash
# 添加到 ~/.bashrc 或 ~/.profile
export QTDIR=/opt/qt6
export PATH=$QTDIR/bin:$PATH
export LD_LIBRARY_PATH=$QTDIR/lib:$LD_LIBRARY_PATH
export QT_QPA_PLATFORM_PLUGIN_PATH=$QTDIR/plugins/platforms
export QT_QPA_PLATFORM=linuxfb
```

### 3. 测试安装
```bash
# 检查Qt版本
qmake --version

# 运行简单的Qt应用测试
echo '#include <QCoreApplication>
#include <QDebug>
int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    qDebug() << "Qt version:" << QT_VERSION_STR;
    return 0;
}' > test.cpp

qmake -project
qmake
make
./test
```

## 常见问题解决

### 1. 编译器找不到
确保交叉编译工具链正确安装并在PATH中。

### 2. Sysroot相关错误
- 确保sysroot目录存在
- 检查sysroot中的库文件是否完整
- 可以尝试不使用sysroot进行编译

### 3. 链接错误
- 检查目标设备的库文件版本
- 确保使用正确的ARM架构
- 对于静态编译，确保所有依赖都可用

### 4. 运行时错误
- 检查ARM设备的运行时库
- 确保Qt插件路径正确
- 检查设备的图形系统配置

## 性能优化建议

### 对于嵌入式设备：
1. 使用静态编译减少启动时间
2. 禁用不必要的Qt模块
3. 使用软件渲染而非硬件加速
4. 优化内存使用配置
5. 考虑使用Qt for MCUs（对于资源极其有限的设备）

### 对于高性能ARM设备：
1. 启用硬件加速
2. 使用共享库减少内存占用
3. 启用多线程优化
4. 考虑使用GPU加速的Qt Quick

## 支持的设备示例

- **树莓派系列**: Pi 1 (armv6l), Pi 2/3 (armv7l), Pi 4/5 (aarch64)
- **NVIDIA Jetson**: Nano, Xavier, Orin (aarch64)
- **BeagleBone**: Black, AI (armv7l)
- **Orange Pi**: 各种型号 (armv7l/aarch64)
- **Rock Pi**: 各种型号 (aarch64)
- **工控机**: 基于ARM的工业计算机

根据具体设备调整构建参数和部署配置。
