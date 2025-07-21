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

if not exist "%EMSDK_ROOT%\emsdk_env.bat" (
    echo Error: emsdk_env.bat not found at %EMSDK_ROOT%
    exit /b 1
)

call "%EMSDK_ROOT%\emsdk_env.bat"
if %errorlevel% neq 0 (
    echo Error: Failed to activate Emscripten environment
    exit /b %errorlevel%
)

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

:: 检查源代码是否存在
if not exist "%SRC_QT%\configure.bat" (
    echo Error: Qt source not found at %SRC_QT%
    exit /b 1
)

:: 检查Host Qt是否存在
if not exist "%HOST_QT_DIR%\bin\qmake.exe" (
    echo Error: Host Qt not found at %HOST_QT_DIR%
    exit /b 1
)

:: 验证关键工具
where ninja >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Ninja not found
    exit /b 1
)

where emcc >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Emscripten compiler not found
    exit /b 1
)

:: 根据需要进行全新构建
echo Cleaning previous build...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

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
    -qt-host-path "%HOST_QT_DIR%" ^
    -nomake examples ^
    -nomake tests ^
    -skip qtwebengine ^
    -skip qtmultimedia ^
    -skip qtwebchannel ^
    -skip qtwebsockets ^
    -skip qtpositioning ^
    -skip qtsensors ^
    -skip qtserialport ^
    -skip qtserialbus ^
    -skip qtlocation ^
    -skip qtcharts ^
    -skip qtspeech ^
    -skip qtdatavis3d ^
    -skip qtquick3dphysics ^
    -skip qtlottie ^
    -skip qtquick3d ^
    -skip qtgraphs ^
    -skip qtremoteobjects ^
    -skip qtscxml ^
    -skip qtvirtualkeyboard ^
    -skip qtwayland ^
    -skip qtwebview ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -no-dbus ^
    -no-ssl ^
    -no-pch

if %errorlevel% neq 0 (
    echo Error: Configure failed
    exit /b %errorlevel%
)

:: 编译
echo Starting build...
cmake --build . --parallel 4

if %errorlevel% neq 0 (
    echo Error: Build failed
    exit /b %errorlevel%
)

:: 安装
echo Installing...
cmake --install .

if %errorlevel% neq 0 (
    echo Error: Install failed
    exit /b %errorlevel%
)

:: 复制qt.conf
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin\"
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