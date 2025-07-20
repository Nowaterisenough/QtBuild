@echo off
@chcp 65001
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=6.9.1

:: 设置WASM版本代号
SET WASM_VERSION=wasm32_emscripten

:: 设置Emscripten版本
SET EMSCRIPTEN_VERSION=3.1.70

echo Qt Version: %QT_VERSION%
echo WASM Version: %WASM_VERSION%
echo Emscripten Version: %EMSCRIPTEN_VERSION%

:: 设置Emscripten SDK路径并激活环境
SET EMSDK_ROOT=D:\a\QtBuild\emsdk
echo Activating Emscripten environment...

if not exist "%EMSDK_ROOT%\emsdk_env.bat" (
    echo ERROR: emsdk_env.bat not found at %EMSDK_ROOT%
    exit /b 1
)

call "%EMSDK_ROOT%\emsdk_env.bat"

echo set tool paths

:: 设置工具路径
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%

echo Tool paths set:
echo PATH=%PATH%

echo Setting Qt paths...

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

:: 设置Qt源代码目录
SET SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-static\%WASM_VERSION%

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%WASM_VERSION%

:: 检查源代码是否存在
if not exist "%SRC_QT%\configure.bat" (
    echo ERROR: Qt source not found at %SRC_QT%
    exit /b 1
)

:: 清理并创建构建目录
if exist "%BUILD_DIR%" (
    rmdir /s /q "%BUILD_DIR%"
)
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

echo Starting Qt configure...

:: configure for WebAssembly
call "%SRC_QT%\configure.bat" ^
    -static ^
    -release ^
    -prefix "%INSTALL_DIR%" ^
    -platform wasm-emscripten ^
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
    -skip qtdatavis3d ^
    -skip qtlottie ^
    -skip qtquick3d ^
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

:: 检查configure是否成功
if %errorlevel% neq 0 (
    echo Configure failed!
    exit /b %errorlevel%
)

:: 编译
echo Starting build...
cmake --build . --parallel 4

:: 检查编译是否成功
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

:: 安装
echo Installing...
cmake --install .

:: 检查安装是否成功
if %errorlevel% neq 0 (
    echo Install failed!
    exit /b %errorlevel%
)

:: 复制qt.conf
if exist "%~dp0\qt.conf" (
    copy "%~dp0\qt.conf" "%INSTALL_DIR%\bin\"
)

echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%

exit /b 0