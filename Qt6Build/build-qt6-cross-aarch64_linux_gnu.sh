@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM 启用延迟扩展
setlocal enabledelayedexpansion

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, TEST_MODE
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set TEST_MODE=%6

REM 处理可能为空的参数，设置默认值
if "%TEST_MODE%"=="" set TEST_MODE=false

set GNU_VERSION=aarch64_none_linux_gnu_%GCC_VERSION%

REM 设置工具链路径 - 使用 D:\a\QtBuild 作为基础路径
set TOOLCHAIN_ROOT=D:\a\QtBuild\arm-gnu-toolchain
set TOOLCHAIN_BIN=%TOOLCHAIN_ROOT%\bin
set TOOLCHAIN_TARGET_DIR=%TOOLCHAIN_ROOT%\aarch64-none-linux-gnu
set TOOLCHAIN_SYSROOT=%TOOLCHAIN_TARGET_DIR%\libc

REM 设置PATH
set "PATH=%TOOLCHAIN_BIN%;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%"
set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "HOST_QT_DIR=%QT_PATH%\%QT_VERSION%-host"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%GNU_VERSION%"
set "BUILD_DIR=%SHORT_BUILD_PATH%"

REM 设置工具链前缀
set TOOLCHAIN_PREFIX=aarch64-none-linux-gnu

echo =====================================
echo Qt6 ARM64 Cross-Compilation Build
echo =====================================
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Test Mode: %TEST_MODE%
echo Target: Linux ARM64 (aarch64)
echo Source: %SRC_QT%
echo Host Qt Dir: %HOST_QT_DIR%
echo Final Install Dir: %FINAL_INSTALL_DIR%
echo Toolchain Root: %TOOLCHAIN_ROOT%
echo =====================================

REM 验证工具链目录
if not exist "%TOOLCHAIN_ROOT%" (
    echo Error: Toolchain root directory not found at %TOOLCHAIN_ROOT%
    echo Checking current directory structure...
    dir D:\a\QtBuild\ /B
    exit /b 1
)

REM 验证bin目录
if not exist "%TOOLCHAIN_BIN%" (
    echo Error: Toolchain bin directory not found at %TOOLCHAIN_BIN%
    echo Checking toolchain root structure...
    dir "%TOOLCHAIN_ROOT%" /B
    exit /b 1
)

REM 列出工具链bin目录内容（用于调试）
echo.
echo Checking toolchain bin directory: %TOOLCHAIN_BIN%
echo Looking for compiler executables...
dir "%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-*.exe" /B 2>nul | findstr /i "gcc g++ ar strip" | head -10

REM 验证工具链
echo.
echo Verifying toolchain executables...
set GCC_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-gcc.exe
set GPP_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-g++.exe
set AR_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-ar.exe
set STRIP_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-strip.exe

if not exist "%GCC_FULL_PATH%" (
    echo Error: ARM GNU toolchain GCC not found at %GCC_FULL_PATH%
    echo Available executables in bin directory:
    dir "%TOOLCHAIN_BIN%\*.exe" /B | head -20
    exit /b 1
)

if not exist "%GPP_FULL_PATH%" (
    echo Error: ARM GNU toolchain G++ not found at %GPP_FULL_PATH%
    exit /b 1
)

echo Found GCC: %GCC_FULL_PATH%
echo Found G++: %GPP_FULL_PATH%
echo Found AR: %AR_FULL_PATH%
echo Found STRIP: %STRIP_FULL_PATH%

REM 检查sysroot位置
echo.
echo Checking sysroot locations...
if exist "%TOOLCHAIN_TARGET_DIR%\libc" (
    set TOOLCHAIN_SYSROOT=%TOOLCHAIN_TARGET_DIR%\libc
    echo Found sysroot at: %TOOLCHAIN_SYSROOT%
) else if exist "%TOOLCHAIN_TARGET_DIR%\sysroot" (
    set TOOLCHAIN_SYSROOT=%TOOLCHAIN_TARGET_DIR%\sysroot
    echo Found sysroot at: %TOOLCHAIN_SYSROOT%
) else if exist "%TOOLCHAIN_TARGET_DIR%" (
    set TOOLCHAIN_SYSROOT=%TOOLCHAIN_TARGET_DIR%
    echo Using target directory as sysroot: %TOOLCHAIN_SYSROOT%
) else (
    echo Warning: No standard sysroot found, using toolchain root
    set TOOLCHAIN_SYSROOT=%TOOLCHAIN_ROOT%
)

echo Using sysroot: %TOOLCHAIN_SYSROOT%

REM 测试编译器
echo.
echo Testing compiler...
"%GCC_FULL_PATH%" --version
if %errorlevel% neq 0 (
    echo Error: GCC test failed
    exit /b %errorlevel%
)

REM 清理并创建build目录
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul
if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"

REM 创建CMake工具链文件
echo.
echo Creating CMake toolchain file...
set TOOLCHAIN_FILE=%SHORT_BUILD_PATH%\toolchain.cmake
(
echo # CMake toolchain file for ARM64 Linux cross-compilation
echo set^(CMAKE_SYSTEM_NAME Linux^)
echo set^(CMAKE_SYSTEM_PROCESSOR aarch64^)
echo.
echo # Cross-compiler settings
echo set^(CMAKE_C_COMPILER "%GCC_FULL_PATH:\=/%"^)
echo set^(CMAKE_CXX_COMPILER "%GPP_FULL_PATH:\=/%"^)
echo set^(CMAKE_AR "%AR_FULL_PATH:\=/%"^)
echo set^(CMAKE_STRIP "%STRIP_FULL_PATH:\=/%"^)
echo.
echo # Sysroot
echo set^(CMAKE_SYSROOT "%TOOLCHAIN_SYSROOT:\=/%"^)
echo set^(CMAKE_FIND_ROOT_PATH "%TOOLCHAIN_SYSROOT:\=/%"^)
echo.
echo # Search paths
echo set^(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY^)
echo.
echo # Compiler flags
echo set^(CMAKE_C_FLAGS_INIT "-march=armv8-a"^)
echo set^(CMAKE_CXX_FLAGS_INIT "-march=armv8-a"^)
) > "%TOOLCHAIN_FILE%"

cd /d "%SHORT_BUILD_PATH%"

REM 配置参数 - 基本选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -qt-host-path %HOST_QT_DIR% -platform win32-g++ -xplatform linux-aarch64-gnu-g++ -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-opengl -no-dbus -no-pkg-config -device-option CROSS_COMPILE=%TOOLCHAIN_PREFIX%-"

REM 测试模式：只编译 qtbase
if /i "%TEST_MODE%"=="true" (
    echo Test mode enabled: Only building qtbase module
    set "CFG_OPTIONS=!CFG_OPTIONS! -submodules qtbase"
)

REM 添加SQLite支持（Qt内置）
set "CFG_OPTIONS=!CFG_OPTIONS! -sql-sqlite"

REM 根据构建类型添加相应选项
if /i "%BUILD_TYPE%"=="debug" (
    set "CFG_OPTIONS=!CFG_OPTIONS! -debug"
) else (
    set "CFG_OPTIONS=!CFG_OPTIONS! -release"
)

REM 处理分离调试信息（仅对 shared 构建有效）
if /i "%LINK_TYPE%"=="shared" (
    if /i "%SEPARATE_DEBUG%"=="true" (
        set "CFG_OPTIONS=!CFG_OPTIONS! -force-debug-info -separate-debug-info"
    )
)

REM CMake选项
set CMAKE_OPTIONS=-DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN_FILE%" -DQT_FEATURE_pkg_config=OFF

REM 完整的configure命令
set "FULL_CFG_OPTIONS=!CFG_OPTIONS! -- %CMAKE_OPTIONS%"

echo.
echo Configure options: !FULL_CFG_OPTIONS!

REM 执行configure
echo.
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" !FULL_CFG_OPTIONS!
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 构建
echo.
echo Starting build...
if /i "%TEST_MODE%"=="true" (
    echo Building in test mode - qtbase only...
)
cmake --build . --parallel 3
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 安装到临时目录
echo.
echo Installing to temporary directory...
cmake --install .
if %errorlevel% neq 0 (
    echo Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 创建最终安装目录的父目录
if not exist "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul

REM 移动文件到最终目录
echo.
echo Moving files to final directory...
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%"
if %errorlevel% neq 0 (
    echo Failed to move to final directory, trying copy...
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y
    if %errorlevel% neq 0 (
        echo Copy also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
    if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM 复制qt.conf (如果存在)
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\"
)

echo.
echo Build completed successfully!
if /i "%TEST_MODE%"=="true" (
    echo NOTE: Test mode was enabled - only qtbase was built
)
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist "%FINAL_INSTALL_DIR%" (
    echo Final installation directory verified.
    echo.
    echo ===============================================
    echo Qt6 ARM64 cross-compilation completed successfully!
    echo Target Platform: Linux ARM64 (aarch64)
    echo ===============================================
    dir "%FINAL_INSTALL_DIR%"
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo.
echo Qt build process completed successfully!

endlocal