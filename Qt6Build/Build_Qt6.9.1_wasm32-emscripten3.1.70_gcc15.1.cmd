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
echo.

:: 设置Emscripten SDK路径并激活环境
SET EMSDK_ROOT=D:\a\QtBuild\emsdk
echo [INFO] Activating Emscripten environment...

if not exist "%EMSDK_ROOT%\emsdk_env.bat" (
    echo [ERROR] emsdk_env.bat not found at %EMSDK_ROOT%
    exit /b 1
)

call "%EMSDK_ROOT%\emsdk_env.bat"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate Emscripten environment
    exit /b %errorlevel%
)

echo [INFO] Emscripten environment activated successfully

:: 设置工具路径
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%

echo [INFO] Tool paths configured

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

echo [INFO] Checking dependencies...

:: 检查源代码是否存在
if not exist "%SRC_QT%\configure.bat" (
    echo [ERROR] Qt source not found at %SRC_QT%
    echo Expected configure.bat at: %SRC_QT%\configure.bat
    exit /b 1
)
echo [INFO] Qt source found at: %SRC_QT%

:: 检查Host Qt是否存在
if not exist "%HOST_QT_DIR%\bin\qmake.exe" (
    echo [ERROR] Host Qt not found at %HOST_QT_DIR%
    echo Please ensure Host Qt is downloaded and extracted to %HOST_QT_DIR%
    exit /b 1
)
echo [INFO] Host Qt found at: %HOST_QT_DIR%

:: 验证关键工具
where ninja >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Ninja not found in PATH
    exit /b 1
)
echo [INFO] Ninja found

:: 验证 Emscripten 编译器
where emcc >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Emscripten compiler (emcc) not found in PATH
    exit /b 1
)
echo [INFO] Emscripten compiler found

:: 清理并创建构建目录
echo [INFO] Preparing build directory...
if exist "%BUILD_DIR%" (
    echo [INFO] Removing existing build directory...
    rmdir /s /q "%BUILD_DIR%"
)
mkdir "%BUILD_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create build directory
    exit /b %errorlevel%
)

cd /d "%BUILD_DIR%"
echo [INFO] Changed to build directory: %BUILD_DIR%

echo.
echo [INFO] Starting Qt configure...
echo =====================================

:: configure for WebAssembly with Host Qt
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
    echo [ERROR] Configure failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo [INFO] Configure completed successfully

echo.
echo [INFO] Starting build...
echo =====================================
cmake --build . --parallel 4

if %errorlevel% neq 0 (
    echo [ERROR] Build failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo [INFO] Build completed successfully

echo.
echo [INFO] Installing...
echo =====================================
cmake --install .

if %errorlevel% neq 0 (
    echo [ERROR] Install failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo [INFO] Install completed successfully

:: 复制qt.conf
if exist "%~dp0\qt.conf" (
    echo [INFO] Copying qt.conf...
    copy "%~dp0\qt.conf" "%INSTALL_DIR%\bin\"
)

:: 创建构建信息文件
echo [INFO] Creating build info...
(
echo Qt WebAssembly Build Information
echo ================================
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
echo =====================================
echo [SUCCESS] Build completed successfully!
echo Installation directory: %INSTALL_DIR%
echo =====================================

exit /b 0