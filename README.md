# QtBuild - Qt源代码自动构建系统

> Fork自 yuanpeirong/buildQt 基于 GitHub Actions 的 Qt 自动构建项目

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Qt Version](https://img.shields.io/badge/Qt-6.9.2%20%7C%205.15.17-blue.svg)](https://qt.io)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20WebAssembly-green.svg)](https://github.com)
[![Build Status](https://img.shields.io/badge/Build-Automated-brightgreen.svg)](https://github.com/features/actions)

## 重要声明

**本项目仅供学习研究使用，严禁将静态构建版本用于商业用途！**

- 允许用途：个人学习、研究、开发测试、开源项目
- 禁止用途：商业项目、分发、销售、闭源商业应用

使用Qt静态构建版本进行商业开发需要购买Qt商业许可证。详情请参考 [Qt官方许可证说明](https://www.qt.io/licensing/)。

---

## 支持的构建配置

### Qt 6.9.2 完整支持

#### Windows x64 平台

| 编译器类型 | 版本选项 | 静态链接 | 动态链接 | Debug支持 | 工作流文件 |
|-----------|----------|----------|----------|-----------|------------|
| **MSVC** | 2019/2022 | 支持 | 支持 | 支持 | `build-qt6-windows_x86_64_msvc_matrix.yml` |
| **MinGW-GCC** | 13.1.0/15.1.0 | 支持 | 支持 | 支持 | `build-qt6-windows_x86_64_mingw_gcc_martrix.yml` |
| **LLVM-Clang** | 17.0.6/20.1.6 | 支持 | 支持 | 支持 | `build-qt6-windows_x86_64_llvm_clang_matrix.yml` |

**编译器获取方式**：
- **MSVC 2019/2022**: Visual Studio Community/Professional/Enterprise
- **MinGW 13.1.0**: [Qt官方源](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_mingw1310/)
- **MinGW 15.1.0**: [niXman GitHub](https://github.com/niXman/mingw-builds-binaries)
- **LLVM 17.0.6**: [Qt官方LLVM-MinGW](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_llvm_mingw1706/)
- **LLVM 20.1.6**: [mstorsjo GitHub](https://github.com/mstorsjo/llvm-mingw)

#### WebAssembly 平台

| 工具链 | 版本选项 | 构建模式 | Debug支持 | 工作流文件 |
|--------|----------|----------|-----------|------------|
| **Emscripten** | 3.1.70/4.0.23 | 静态构建 | 支持 | `build-qt6-wasm32_emscripten_matrix.yml` |

**WebAssembly 特性**：
- 支持多线程模式
- 包含 QtBase 和 QtDeclarative 模块
- 针对Web环境优化
- 需要Host Qt进行交叉编译

### Qt 5.15.17 兼容支持

#### Windows x64 平台

| 编译器类型 | 版本选项 | 静态链接 | 动态链接 | 工作流文件 |
|-----------|----------|----------|----------|------------|
| **MSVC** | 2019/2022 | 支持 | 支持 | `build-qt5-windows_x86_64_msvc_matrix.yml` |
| **MinGW-GCC** | 8.1.0/11.2.0 | 支持 | 支持 | `build-qt5-windows_x86_64_mingw_gcc_matrix.yml` |

---

## 构建选项详解

### 构建类型 (Build Types)

| 类型 | 说明 | 适用场景 | 文件大小 |
|------|------|----------|----------|
| **release** | 发布版本，最优性能 | 生产环境部署 | 中等 |
| **debug** | 调试版本，包含完整调试信息 | 开发调试 | 大 |
| **release-and-debug** | 同时构建发布和调试版本 | 开发和生产并用 | 大 |
| **release-sepdbg** | 发布版本+分离调试信息 | 生产部署+调试支持 | 中等+调试文件 |

### 链接类型 (Link Types)

| 类型 | 说明 | 优势 | 劣势 | 部署方式 |
|------|------|------|------|----------|
| **static** | 静态链接 | 单文件部署，无依赖 | 文件大，内存占用高 | 直接复制exe |
| **shared** | 动态链接 | 文件小，内存共享 | 需要运行时库 | 需复制DLL |

### 运行时选项 (Runtime)

| 运行时 | 说明 | 兼容性 | 推荐场景 |
|--------|------|--------|----------|
| **UCRT** | Universal C Runtime | Windows 10+ | 现代应用开发 |
| **MSVCRT** | 传统 MSVC Runtime | Windows 7+ | 兼容老系统 |

---

## 命名规范

构建产物采用标准化三段式命名格式：

```
qt{版本}-{平台}_{架构}_{编译器}{版本}_{运行时}-{链接类型}_{构建类型}.7z
```

**命名示例**：
- `qt6.9.2-windows_x86_64_msvc2022-static_release.7z`
- `qt6.9.2-windows_x86_64_mingw_gcc15.1.0_ucrt-shared_relwithdebinfo.7z`
- `qt6.9.2-windows_x86_64_llvm_clang20.1_ucrt-static_release_and_debug.7z`
- `qt6.9.2-wasm32_emscripten4.0.23-static_debug.7z`
- `qt5.15.17-windows_x86_64_msvc2022-shared_release.7z`

---

## 构建配置详情

### 通用配置

- **C++ 标准**：C++20 (Qt6) / C++17 (Qt5)
- **优化选项**：Release (-O2), Debug (-Og)
- **跳过模块**：QtWebEngine (减少构建时间)
- **开源许可**：自动接受 (-opensource -confirm-license)

### Windows 平台特定配置

#### MSVC 编译器
- **SSL后端**：Schannel (Windows原生)
- **图形API**：OpenGL Desktop
- **多处理器编译**：-mp (仅shared构建)
- **调试信息**：支持分离调试信息生成

#### MinGW-GCC 编译器
- **线程模型**：POSIX threads
- **运行时**：支持UCRT和MSVCRT
- **内置库**：libpng, libjpeg, zlib, pcre, freetype
- **SSL后端**：Schannel

#### LLVM-Clang 编译器
- **现代C++**：完整C++20支持
- **优化器**：LLVM后端优化
- **运行时**：主要支持UCRT
- **跨平台**：与其他LLVM工具链兼容

### WebAssembly 平台配置

- **编译目标**：wasm32-emscripten
- **线程支持**：WebAssembly threads (-feature-thread)
- **精简模块**：仅包含 qtbase 和 qtdeclarative
- **优化配置**：针对浏览器环境优化
- **无SSL/DBus**：移除不适用模块

---

## 详细使用指南

### GitHub Actions 自动构建

#### 1. 环境准备
```bash
# Fork 本仓库到您的账户
# 确保 GitHub Actions 已启用
# 检查仓库 Settings > Actions > General
```

#### 2. 启动构建
- 进入仓库的 **Actions** 页面
- 选择对应的工作流 (例如：`build-qt6-windows_x86_64_msvc_matrix`)
- 点击 **"Run workflow"**
- 配置构建参数：
  - Qt 版本 (6.9.2 / 5.15.17)
  - 编译器版本
  - 运行时类型
  - 其他选项

#### 3. 下载构建产物
- 构建完成后，在 **Artifacts** 部分下载压缩包
- 解压到目标目录即可使用

### 本地构建

#### 1. 环境准备

**Windows 平台**：
```bash
# 需要 Visual Studio 或 MinGW 或 LLVM-Clang
git clone https://github.com/NoWaterisEnough/QtBuild.git
cd QtBuild
```

**Linux 平台**：
```bash
# 需要 GCC 和必要的开发库
sudo apt-get install build-essential libgl1-mesa-dev
git clone https://github.com/NoWaterisEnough/QtBuild.git
cd QtBuild
```

#### 2. 执行构建

**Qt6 Windows MSVC**：
```bash
.\Qt6Build\build-qt6-windows_x86_64_msvc.cmd 6.9.2 2022 release static false
```

**Qt6 Windows MinGW**：
```bash
.\Qt6Build\build-qt6-windows_x86_64_mingw_gcc.cmd 6.9.2 15.1.0 release shared false ucrt
```

**Qt6 Windows LLVM-Clang**：
```bash
.\Qt6Build\build-qt6-windows_x86_64_llvm_clang.cmd 6.9.2 20.1 release static false ucrt "D:\path\to\llvm\bin" "llvm-mingw20.1.6_64_UCRT"
```

**Qt6 WebAssembly**：
```bash
.\Qt6Build\build-qt6-wasm32_emscripten.cmd 6.9.2 4.0.23 release static
```

**Qt5 Windows MSVC**：
```bash
.\Qt5Build\build-qt5-windows_x86_64_msvc.cmd 5.15.17 2022 release static false "C:\path\to\vcvarsall.bat" "C:\path\to\redist" "msvc2022_64"
```

**Qt5 Windows MinGW**：
```bash
.\Qt5Build\build-qt5-windows_x86_64_mingw_gcc.cmd 5.15.17 8.1 release shared false "D:\path\to\mingw\bin" "mingw810_64"
```

### 构建参数说明

脚本参数格式：
```bash
script_name <Qt版本> <编译器版本> <构建类型> <链接类型> <分离调试信息> [其他参数]
```

**参数详解**：
- `Qt版本`: 6.9.2, 5.15.17
- `编译器版本`: 2022 (MSVC), 15.1.0 (GCC), 20.1 (Clang), 4.0.23 (Emscripten)
- `构建类型`: release, debug, release-and-debug
- `链接类型`: static, shared
- `分离调试信息`: true, false
- `运行时`: ucrt, msvcrt (仅MinGW/Clang)

---

## 部署和使用

### 静态构建版本

**优势**：
- 单文件部署，无需安装运行时
- 完全自包含，兼容性好
- 适合绿色软件发布

**使用方法**：
```bash
# 设置环境变量
export QTDIR=/path/to/qt-static
export PATH=$QTDIR/bin:$PATH

# 编译应用 (qmake)
qmake your_project.pro
make

# 编译应用 (CMake)
cmake -DCMAKE_PREFIX_PATH=/path/to/qt-static .
make
```

### 动态构建版本

**优势**：
- 文件体积小
- 内存共享，多程序效率高
- 支持插件系统

**使用方法**：
```bash
# Windows 设置环境变量
set QTDIR=C:\path\to\qt-shared
set PATH=%QTDIR%\bin;%PATH%
set QT_PLUGIN_PATH=%QTDIR%\plugins

# Linux 设置环境变量
export QTDIR=/path/to/qt-shared
export PATH=$QTDIR/bin:$PATH
export LD_LIBRARY_PATH=$QTDIR/lib:$LD_LIBRARY_PATH

# 编译应用
qmake your_project.pro
make

# 部署应用 (Windows)
windeployqt.exe your_app.exe

# 部署应用 (Linux)
linuxdeployqt your_app -bundle-non-qt-libs
```

### CMake 项目配置

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(MyApp)

# 设置 Qt 路径
set(CMAKE_PREFIX_PATH "/path/to/qt-build")

# 查找 Qt 组件
find_package(Qt6 REQUIRED COMPONENTS Core Widgets)

# 创建可执行文件
qt6_add_executable(MyApp main.cpp)

# 链接 Qt 库
target_link_libraries(MyApp Qt6::Core Qt6::Widgets)
```

### WebAssembly 项目配置

```bash
# 设置 Emscripten 环境
source /path/to/emsdk/emsdk_env.sh

# 设置 Qt WebAssembly 环境
export QTDIR=/path/to/qt-wasm
export PATH=$QTDIR/bin:$PATH

# 编译 WebAssembly 应用
qmake your_project.pro
make

# 生成的文件
# your_app.html - 主HTML文件
# your_app.js - JavaScript胶水代码
# your_app.wasm - WebAssembly二进制
```

---

## 常见问题

### Q: 构建失败怎么办？
**A**: 检查以下几点：
- 编译器版本是否正确
- 磁盘空间是否足够 (至少20GB)
- 网络连接是否稳定
- 查看构建日志中的具体错误信息

### Q: 如何选择合适的构建配置？
**A**: 根据使用场景选择：
- **开发测试**: debug 版本
- **性能测试**: release 版本  
- **生产部署**: release + 分离调试信息
- **绿色软件**: 静态链接版本
- **系统集成**: 动态链接版本

### Q: WebAssembly 版本有什么限制？
**A**: 主要限制包括：
- 不支持 QtWebEngine
- 文件系统访问受限
- 网络功能受浏览器安全策略限制
- 性能相比原生版本有所下降
- 需要现代浏览器支持

### Q: 如何处理运行时依赖？
**A**: 不同构建类型处理方式：

**静态构建**：
- 无需额外DLL
- 应用程序完全自包含

**动态构建 - MSVC**：
- 需要 MSVC Redistributable
- 或复制 redist 文件夹中的DLL

**动态构建 - MinGW**：
- 需要 MinGW 运行时DLL：
  - libgcc_s_seh-1.dll
  - libstdc++-6.dll
  - libwinpthread-1.dll

**动态构建 - LLVM-Clang**：
- 需要 LLVM 运行时DLL：
  - libc++.dll
  - libunwind.dll
  - libwinpthread-1.dll

### Q: 如何验证构建结果？
**A**: 验证步骤：
1. 检查安装目录结构
2. 验证关键文件存在 (qmake.exe, moc.exe等)
3. 运行简单的测试程序
4. 在干净环境中测试部署

---

## 构建时间参考

| 平台配置 | 静态构建 | 动态构建 | 调试版本 | 备注 |
|----------|----------|----------|----------|------|
| **Windows MSVC** | ~2.5h | ~2h | ~3h | GitHub Actions |
| **Windows MinGW** | ~3h | ~2.5h | ~3.5h | GitHub Actions |
| **Windows LLVM** | ~2.8h | ~2.3h | ~3.2h | GitHub Actions |
| **WebAssembly** | ~1.5h | N/A | ~2h | GitHub Actions |

*时间基于 GitHub Actions 的 Windows/Ubuntu 运行器，实际时间可能因网络和负载情况而异*

---

## 许可证

本项目采用混合许可证：

- **构建脚本和配置**: [MIT License](LICENSE)
- **Qt 源代码**: 遵循 [Qt 官方许可证](https://www.qt.io/licensing/) (LGPL v3 / GPL v3)

### 重要说明

**静态链接Qt库的商业应用需要Qt商业许可证**

- **开源项目**: 可以使用 LGPL/GPL 版本
- **个人学习**: 不受限制
- **商业闭源**: 必须购买Qt商业许可证

详情请参考：[Qt 许可证选择指南](https://www.qt.io/licensing/)

---

## 致谢

- [Qt Project](https://www.qt.io/) - 提供优秀的跨平台框架
- [GitHub Actions](https://github.com/features/actions) - 提供免费的CI/CD服务
- [niXman](https://github.com/niXman/mingw-builds-binaries) - 提供MinGW构建版本
- [mstorsjo](https://github.com/mstorsjo/llvm-mingw) - 提供LLVM-MinGW工具链
- [Emscripten](https://emscripten.org/) - 提供WebAssembly编译工具链

### 相关链接

[![GitHub](https://img.shields.io/badge/GitHub-QtBuild-black?logo=github)](https://github.com/NoWaterisEnough/QtBuild)
[![Qt Official](https://img.shields.io/badge/Qt-Official-green?logo=qt)](https://www.qt.io/)
[![Documentation](https://img.shields.io/badge/Docs-Qt%20Docs-blue?logo=readthedocs)](https://doc.qt.io/)

---

**仅供学习研究使用 | 禁止商业用途 | 遵循Qt许可证**

</div>