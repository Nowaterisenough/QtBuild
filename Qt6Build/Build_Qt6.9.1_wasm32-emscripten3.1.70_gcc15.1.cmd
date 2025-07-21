@echo off
@chcp 65001 > nul
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=6.9.1

:: 设置WASM版本代号
SET WASM_VERSION=wasm32_emscripten

:: 设置Emscripten版本
SET EMSCRIPTEN_VERSION=3.1.70

echo =====================================
echo Qt WebAssembly Build Configuration
echo =====================================
echo Qt Version: %QT_VERSION%
echo WASM Version: %WASM_VERSION%
echo Emscripten Version: %EMSCRIPTEN_VERSION%
echo =====================================

:: 设置Emscripten SDK路径并激活环境
SET EMSDK_ROOT=D:\a\QtBuild\emsdk
echo Setting up Emscripten environment...
call "%EMSDK_ROOT%\emsdk_env.bat"

:: 设置工具路径
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

:: 设置Qt源代码目录
SET SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-static\%WASM_VERSION%

:: 设置Host Qt目录
SET HOST_QT_DIR=%QT_PATH%\%QT_VERSION%-host

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%WASM_VERSION%

:: 显示配置信息
echo.
echo ================================
echo Qt6 WebAssembly Build Configuration
echo ================================
echo Qt Version: %QT_VERSION%
echo Platform: WebAssembly (Emscripten %EMSCRIPTEN_VERSION%)
echo Build Type: Static Release
echo Source Dir: %SRC_QT%
echo Build Dir: %BUILD_DIR%
echo Install Dir: %INSTALL_DIR%
echo Host Qt Dir: %HOST_QT_DIR%
echo ================================
echo.

:: 根据需要进行全新构建
echo Cleaning previous build...
IF EXIST "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

:: 定位到构建目录
echo Creating build directory...
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

:: configure
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" ^
    -static ^
    -release ^
    -prefix "%INSTALL_DIR%" ^
    -platform wasm-emscripten ^
    -no-warnings-are-errors
    -qt-host-path "%HOST_QT_DIR%" ^
    -nomake examples ^
    -nomake tests ^
    -submodules qtbase qtdeclarative ^
    -c++std c++20 ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -no-dbus ^
    -feature-thread

IF ERRORLEVEL 1 (
    echo Error: Configure failed
    exit /b 1
)

:: 编译
echo Starting build...
cmake --build . --parallel 4

IF ERRORLEVEL 1 (
    echo Error: Build failed
    exit /b 1
)

:: 安装
echo Installing...
cmake --install .

IF ERRORLEVEL 1 (
    echo Error: Install failed
    exit /b 1
)

:: 复制qt.conf
IF EXIST "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin" > nul
)

:: 创建构建信息文件
echo Creating build info...
(
echo Qt6 WebAssembly Build Information
echo ==================================
echo Qt Version: %QT_VERSION%
echo Platform: WebAssembly ^(Emscripten %EMSCRIPTEN_VERSION%^)
echo Build Type: Static Release
echo Build Date: %DATE% %TIME%
echo Install Path: %INSTALL_DIR%
echo Host Qt Path: %HOST_QT_DIR%
echo.
echo Build completed successfully!
) > "%INSTALL_DIR%\build-info.txt"

echo.
echo ================================
echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%
echo ================================

cd /d "%INSTALL_DIR%"