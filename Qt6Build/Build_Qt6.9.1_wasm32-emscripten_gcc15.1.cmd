@echo off
@chcp 65001
@cd /d %~dp0

echo ============ Debug Info ============
echo Current directory: %CD%
echo Script location: %~dp0
echo Date/Time: %DATE% %TIME%
echo ===================================

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
echo EMSDK_ROOT: %EMSDK_ROOT%

if not exist "%EMSDK_ROOT%\emsdk_env.bat" (
    echo ERROR: emsdk_env.bat not found at %EMSDK_ROOT%
    echo Directory contents:
    dir "%EMSDK_ROOT%" /b 2>nul
    exit /b 1
)

call "%EMSDK_ROOT%\emsdk_env.bat"

:: 验证Emscripten环境
echo ============ Emscripten Environment ============
echo EMSDK: %EMSDK%
echo EMSCRIPTEN: %EMSCRIPTEN%
echo EM_CONFIG: %EM_CONFIG%
echo PATH (first part): 
echo %PATH% | findstr /i emscripten
echo ================================================

where emcc >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: emcc not found in PATH
    exit /b 1
)

echo Found emcc at:
where emcc
echo Testing emcc:
emcc --version
if %errorlevel% neq 0 (
    echo ERROR: emcc --version failed
    exit /b 1
)

:: 设置工具路径
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

:: 设置Qt源代码目录 (不要预先加引号)
SET SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-static\%WASM_VERSION%

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%WASM_VERSION%

:: 显示路径信息
echo ============ Path Information ============
echo QT_PATH: %QT_PATH%
echo SRC_QT: %SRC_QT%
echo INSTALL_DIR: %INSTALL_DIR%
echo BUILD_DIR: %BUILD_DIR%
echo =========================================

:: 检查Qt版本目录
echo Checking Qt version directory:
if exist "%QT_PATH%\%QT_VERSION%" (
    echo Found: %QT_PATH%\%QT_VERSION%
    echo Contents:
    dir "%QT_PATH%\%QT_VERSION%" /b
) else (
    echo ERROR: Qt version directory not found: %QT_PATH%\%QT_VERSION%
    echo Available directories in %QT_PATH%:
    dir "%QT_PATH%" /b 2>nul
    exit /b 1
)

:: 检查源代码是否存在
echo Checking Qt source directory:
if exist "%SRC_QT%" (
    echo Found Qt source: %SRC_QT%
    echo Source directory contents:
    dir "%SRC_QT%" /b | findstr /i configure
) else (
    echo ERROR: Qt source directory not found: %SRC_QT%
    echo Available directories in %QT_PATH%\%QT_VERSION%:
    dir "%QT_PATH%\%QT_VERSION%" /b 2>nul
    echo Looking for qt-everywhere-src patterns:
    dir "%QT_PATH%\%QT_VERSION%\qt-everywhere-src*" /b /ad 2>nul
    exit /b 1
)

:: 检查configure.bat是否存在
if not exist "%SRC_QT%\configure.bat" (
    echo ERROR: configure.bat not found in %SRC_QT%
    echo Directory contents:
    dir "%SRC_QT%" /b | head -20
    exit /b 1
)

:: 根据需要进行全新构建
echo Cleaning build directory...
if exist "%BUILD_DIR%" (
    echo Removing existing build directory: %BUILD_DIR%
    rmdir /s /q "%BUILD_DIR%"
    if %errorlevel% neq 0 (
        echo Warning: Failed to remove build directory
    )
)

:: 定位到构建目录
echo Creating build directory: %BUILD_DIR%
mkdir "%BUILD_DIR%"
if %errorlevel% neq 0 (
    echo ERROR: Failed to create build directory
    exit /b 1
)

cd /d "%BUILD_DIR%"
if %errorlevel% neq 0 (
    echo ERROR: Failed to change to build directory
    exit /b 1
)

echo Current directory after cd: %CD%
echo Starting Qt configure...

:: configure for WebAssembly
echo ============ Running Configure ============
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
echo Configure finished with exit code: %errorlevel%
if %errorlevel% neq 0 (
    echo ============ Configure Failed ============
    echo Configure failed with error code: %errorlevel%
    echo Last 50 lines of output:
    if exist "config.log" (
        tail -n 50 config.log 2>nul
    )
    echo =========================================
    exit /b %errorlevel%
)

echo ============ Configure Success ============
echo Configure completed successfully, starting build...
echo Current directory: %CD%
echo Available files:
dir . /b | head -10

echo ============ Starting Build ============
:: 编译
cmake --build . --parallel 4
SET BUILD_EXIT_CODE=%errorlevel%

echo Build finished with exit code: %BUILD_EXIT_CODE%
:: 检查编译是否成功
if %BUILD_EXIT_CODE% neq 0 (
    echo ============ Build Failed ============
    echo Build failed with error code: %BUILD_EXIT_CODE%
    echo =====================================
    exit /b %BUILD_EXIT_CODE%
)

echo ============ Build Success ============
echo Build completed successfully, starting install...

:: 安装
cmake --install .
SET INSTALL_EXIT_CODE=%errorlevel%

echo Install finished with exit code: %INSTALL_EXIT_CODE%
:: 检查安装是否成功
if %INSTALL_EXIT_CODE% neq 0 (
    echo ============ Install Failed ============
    echo Install failed with error code: %INSTALL_EXIT_CODE%
    echo ======================================
    exit /b %INSTALL_EXIT_CODE%
)

:: 复制qt.conf
if exist "%~dp0\qt.conf" (
    echo Copying qt.conf...
    copy "%~dp0\qt.conf" "%INSTALL_DIR%\bin\"
) else (
    echo qt.conf not found, skipping...
)

echo ============ Build Completed Successfully! ============
echo Installation directory: %INSTALL_DIR%

:: 检查安装目录
if exist "%INSTALL_DIR%" (
    echo Installation directory contents:
    dir "%INSTALL_DIR%" /b
    echo.
    echo Bin directory contents:
    if exist "%INSTALL_DIR%\bin" (
        dir "%INSTALL_DIR%\bin" /b | head -20
    ) else (
        echo Bin directory not found
    )
) else (
    echo WARNING: Installation directory not found!
)

echo ================================================
exit /b 0