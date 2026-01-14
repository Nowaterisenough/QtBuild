# QtBuild - Qt 自动构建系统

基于 GitHub Actions 的 Qt 源代码自动构建项目。

## 重要声明

**本项目仅供学习研究使用，静态构建版本禁止商业用途！**

商业开发需购买 [Qt 商业许可证](https://www.qt.io/licensing/)。

## 支持配置

### Qt 6

| 平台 | 编译器 | 版本 |
|------|--------|------|
| Windows x64 | MSVC | 2019/2022 |
| Windows x64 | MinGW-GCC | 13.1.0 - 15.2.0 |
| Windows x64 | LLVM-Clang | 17.0 - 21 |
| Linux x86_64 | GCC | 11 - 15.2 |
| Linux x86_64 | LLVM | 15 - 21 |
| WebAssembly | Emscripten | 3.1.70/4.0.23 |

### Qt 5.15.17

| 平台 | 编译器 | 版本 |
|------|--------|------|
| Windows x64 | MSVC | 2019/2022 |
| Windows x64 | MinGW-GCC | 8.1.0/11.2.0 |

**构建选项**: static/shared, release/debug/release-sepdbg

## 命名规范

```
qt{版本}-{平台}-{架构}-{编译器}{版本}-{链接类型}_{构建类型}.7z
```

示例:
- `qt6.9.2-windows-x86_64-msvc2022-static_release.7z`
- `qt6.9.2-linux-x86_64-gcc15.2-shared_release.7z`
- `qt6.9.2-wasm32_emscripten4.0.23-static_release.7z`

## 使用方法

### GitHub Actions

1. Fork 本仓库
2. 进入 **Actions** 页面
3. 选择对应工作流，点击 **Run workflow**
4. 构建完成后下载 Artifacts

### 本地构建

```bash
# Windows MSVC
.\Qt6Build\build-qt6-native-windows_x86_64_msvc.cmd 6.9.2 2022 release static

# Windows MinGW
.\Qt6Build\build-qt6-native-windows_x86_64_mingw.cmd 6.9.2 15.2.0 release shared ucrt

# Linux GCC (WSL)
./Qt6Build/build-qt6-native-linux_x86_64_gcc.sh 6.9.2 15.2 release shared

# WebAssembly
.\Qt6Build\build-qt6-cross-wasm32_emscripten_windows.cmd 6.9.2 4.0.23 release static
```

## 项目配置

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(MyApp)

set(CMAKE_PREFIX_PATH "/path/to/qt-build")
find_package(Qt6 REQUIRED COMPONENTS Core Widgets)

qt6_add_executable(MyApp main.cpp)
target_link_libraries(MyApp Qt6::Core Qt6::Widgets)
```

## 许可证

- 构建脚本: [MIT License](LICENSE)
- Qt 源代码: [Qt 官方许可证](https://www.qt.io/licensing/)

---

**仅供学习研究使用 | 静态版本禁止商业用途**
