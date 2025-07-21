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

:: 修复qwasmsocket.cpp文件的头文件包含问题
echo Patching qwasmsocket.cpp...
SET QWASMSOCKET_FILE=%SRC_QT%\qtbase\src\corelib\platform\wasm\qwasmsocket.cpp

if exist "%QWASMSOCKET_FILE%" (
    echo Backing up original qwasmsocket.cpp...
    copy "%QWASMSOCKET_FILE%" "%QWASMSOCKET_FILE%.bak" > nul
    
    echo Applying patch to qwasmsocket.cpp...
    
    :: 创建临时PowerShell脚本来修复文件
    (
    echo $file = "%QWASMSOCKET_FILE%"
    echo $content = Get-Content $file -Raw
    echo if ^($content -notmatch "#include <QtCore/qcoreapplication.h>"^) {
    echo     $lines = Get-Content $file
    echo     $newLines = @^(^)
    echo     $includeAdded = $false
    echo     foreach ^($line in $lines^) {
    echo         if ^($line -match "^#include" -and -not $includeAdded^) {
    echo             $newLines += $line
    echo             if ^($line -match "qobject.h"^) {
    echo                 $newLines += "#include <QtCore/qcoreapplication.h>"
    echo                 $newLines += "#include <QtCore/qevent.h>"
    echo                 $includeAdded = $true
    echo             }
    echo         } else {
    echo             $newLines += $line
    echo         }
    echo     }
    echo     if ^(-not $includeAdded^) {
    echo         $newLines = @^("#include <QtCore/qcoreapplication.h>", "#include <QtCore/qevent.h>"^) + $newLines
    echo     }
    echo     $newLines ^| Set-Content $file -Encoding UTF8
    echo     Write-Host "Patched qwasmsocket.cpp successfully"
    echo } else {
    echo     Write-Host "qwasmsocket.cpp already patched"
    echo }
    ) > fix_qwasmsocket.ps1
    
    powershell -ExecutionPolicy Bypass -File fix_qwasmsocket.ps1
    del fix_qwasmsocket.ps1
    
    echo Patch applied successfully.
) else (
    echo Warning: qwasmsocket.cpp not found at %QWASMSOCKET_FILE%
)

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
    -xplatform wasm-emscripten ^
    -qt-host-path "%HOST_QT_DIR%" ^
    -nomake examples ^
    -nomake tests ^
    -submodules qtbase ^
    -c++std c++20 ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -no-dbus ^
    -no-ssl ^
    -no-pch ^
    -no-feature-network

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