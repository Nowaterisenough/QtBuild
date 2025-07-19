# QtBuild - 从源代码自动构建Qt

[![License](https://img.shields.io/badge/License-Educational%20Use%20Only-red.svg)](LICENSE)
[![Qt Version](https://img.shields.io/badge/Qt-6.9.1%20%7C%205.15.17-blue.svg)](https://qt.io)

## 免责声明

**本项目仅供学习研究使用，严禁将静态构建版本用于商业用途！**

- 允许用途：个人学习、研究、开发测试
- 禁止用途：商业项目、分发、销售

使用Qt静态构建版本进行商业开发需要购买Qt商业许可证。详情请参考 [Qt许可证说明](https://www.qt.io/licensing/)。

---

## 支持的构建配置

### Qt 6.9.1 x64

| 编译器 | 版本 | 状态 | 下载链接 |
|--------|------|------|----------|
| **MSVC 2022** | v17.13.2 | 支持 | Visual Studio 2022 Developer Command Prompt |
| **MinGW** | 13.1.0 (官方默认) | 支持 | [mingw1310.7z](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_mingw1310/qt.tools.win64_mingw1310/13.1.0-202407240918mingw1310.7z) |
| **MinGW** | 15.1.0 (UCRT) | 支持 | [x86_64-15.1.0-ucrt.7z](https://github.com/niXman/mingw-builds-binaries/releases/download/15.1.0-rt_v12-rev0/x86_64-15.1.0-release-posix-seh-ucrt-rt_v12-rev0.7z) |
| **LLVM-MinGW** | 17.0.6 (官方默认) | 支持 | [llvm_mingw1706.7z](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_llvm_mingw1706/qt.tools.win64_llvm_mingw1706/17.0.6-202409091150llvm_mingw1706.7z) |
| **LLVM-MinGW** | 20.1.6 (UCRT) | 支持 | [llvm-mingw-20250528-ucrt.zip](https://github.com/mstorsjo/llvm-mingw/releases/download/20250528/llvm-mingw-20250528-ucrt-x86_64.zip) |

### Qt 5.15.17 x64

| 编译器 | 版本 | 状态 | 下载链接 |
|--------|------|------|----------|
| **MSVC 2022** | v17.13.2 | 支持 | Visual Studio 2022 Developer Command Prompt |
| **MinGW** | 8.1.0 (官方默认) | 支持 | [mingw810.7z](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_mingw81/qt.tools.win64_mingw810/8.1.0-1-202411201005x86_64-8.1.0-gdb-11.2.0-release-posix-seh-rt_v6-rev0.7z) |

---

## 使用方法

### 自动构建 (GitHub Actions)

1. Fork 本仓库
2. 进入 Actions 页面
3. 选择对应的工作流
4. 点击 "Run workflow" 开始构建
5. 构建完成后下载 Artifacts

### 本地构建

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/QtBuild.git
cd QtBuild

# 2. 选择对应的构建脚本
# Windows (cmd)
.\Qt6Build\Build_Qt6.9.1_x86_64-windows-msvc_2022.cmd

# Linux (bash)
./Qt6Build/Build_Qt6.9.1_x86_64-linux-gnu_gcc15.1.sh
```

---

## 构建选项

### 通用配置
- **构建类型**：静态库 (Static)
- **配置模式**：Release
- **跳过模块**：WebEngine (减少构建时间)
- **包含模块**：Core, GUI, Widgets, Network, SQL 等核心模块

### 平台特定配置

#### Windows
- 静态运行时链接
- 使用 Schannel (Windows原生SSL)
- 支持 DirectWrite

#### Linux
- 使用 OpenSSL
- XCB 平台支持
- FontConfig 支持

#### WebAssembly
- Emscripten 工具链
- 禁用多线程功能
- 精简模块集合

---

## 许可证

本项目遵循以下许可证：

- **构建脚本**：MIT License
- **Qt源代码**：遵循Qt官方许可证 (LGPL v3 / GPL v3)

**重要提醒**：静态链接Qt库的应用程序必须遵循相应的许可证要求。商业用途请购买Qt商业许可证。

---

<div align="center">

**仅供学习研究使用 | 禁止商业用途**

Made with love for Qt developers

</div>