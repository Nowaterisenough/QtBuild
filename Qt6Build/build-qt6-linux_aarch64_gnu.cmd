@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5

REM 例如: 6.9.1  14.3.rel1  release  static  false

set QT_VERSION2=%QT_VERSION:~0,3%
set GNU_VERSION=aarch64_none_linux_gnu_%GCC_VERSION%

set PATH=D:\a\QtBuild\aarch64-none-linux-gnu\bin;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%
set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set HOST_QT_DIR="%QT_PATH%\%QT_VERSION%-host"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%GNU_VERSION%"
set BUILD_DIR="%SHORT_BUILD_PATH%"
set TOOLCHAIN_PREFIX=aarch64-none-linux-gnu

echo =====================================
echo Qt6 ARM64 Cross-Compilation Build
echo =====================================
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Target: Linux ARM64 (aarch64)
echo Toolchain: %TOOLCHAIN_PREFIX%
echo Source: %SRC_QT%
echo Host Qt Dir: %HOST_QT_DIR%
echo Final Install Dir: %FINAL_INSTALL_DIR%
echo =====================================

REM 清理并创建build目录
echo Cleaning previous build...
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM 设置交叉编译环境变量
set CC=%TOOLCHAIN_PREFIX%-gcc
set CXX=%TOOLCHAIN_PREFIX%-g++
set AR=%TOOLCHAIN_PREFIX%-ar
set STRIP=%TOOLCHAIN_PREFIX%-strip
set OBJCOPY=%TOOLCHAIN_PREFIX%-objcopy
set NM=%TOOLCHAIN_PREFIX%-nm
set RANLIB=%TOOLCHAIN_PREFIX%-ranlib

REM 创建交叉编译工具链文件
echo Creating toolchain file...
(
echo set^(CMAKE_SYSTEM_NAME Linux^)
echo set^(CMAKE_SYSTEM_PROCESSOR aarch64^)
echo set^(CMAKE_CROSSCOMPILING TRUE^)
echo.
echo # 设置编译器
echo set^(CMAKE_C_COMPILER %TOOLCHAIN_PREFIX%-gcc^)
echo set^(CMAKE_CXX_COMPILER %TOOLCHAIN_PREFIX%-g++^)
echo set^(CMAKE_ASM_COMPILER %TOOLCHAIN_PREFIX%-gcc^)
echo.
echo # 设置工具
echo set^(CMAKE_AR %TOOLCHAIN_PREFIX%-ar^)
echo set^(CMAKE_STRIP %TOOLCHAIN_PREFIX%-strip^)
echo set^(CMAKE_OBJCOPY %TOOLCHAIN_PREFIX%-objcopy^)
echo set^(CMAKE_NM %TOOLCHAIN_PREFIX%-nm^)
echo set^(CMAKE_RANLIB %TOOLCHAIN_PREFIX%-ranlib^)
echo.
echo # 设置根路径
echo set^(CMAKE_FIND_ROOT_PATH D:/a/QtBuild/aarch64-none-linux-gnu/aarch64-none-linux-gnu^)
echo.
echo # 设置搜索策略
echo set^(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY^)
echo set^(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY^)
) > toolchain.cmake

REM 配置参数
set CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -qt-host-path %HOST_QT_DIR% -platform win32-g++ -xplatform linux-aarch64-gnu-g++ -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -opengl es2 -no-dbus -device-option CROSS_COMPILE=%TOOLCHAIN_PREFIX%-

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
    echo Building DEBUG version for ARM64...
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
    echo Building RELEASE version for ARM64...
)

REM shared构建才能分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info
        echo Separate debug info enabled for shared build
    )
)

echo Configure options: %CFG_OPTIONS%

REM 执行configure
echo Starting Qt configure...
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 构建
echo Starting build...
REM ARM交叉编译较慢，使用适中的并行度
cmake --build . --parallel 3
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 安装到临时目录
echo Installing to temporary directory...
cmake --install .
if %errorlevel% neq 0 (
    echo Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 创建最终安装目录的父目录
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul

REM 移动文件到最终目录
echo Moving files to final directory...
move "%TEMP_INSTALL_DIR%" %FINAL_INSTALL_DIR%
if %errorlevel% neq 0 (
    echo Failed to move to final directory with error code: %errorlevel%
    REM 尝试复制而不是移动
    echo Trying to copy instead...
    xcopy "%TEMP_INSTALL_DIR%\*" %FINAL_INSTALL_DIR%\ /E /I /H /Y
    if %errorlevel% neq 0 (
        echo Copy also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
    REM 清理临时目录
    rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
)

REM 复制qt.conf (如果存在)
if exist %~dp0\qt.conf (
    copy %~dp0\qt.conf %FINAL_INSTALL_DIR%\bin\ > nul
)

REM 创建构建信息文件
echo Creating build info...
(
echo Qt6 ARM64 Cross-Compilation Build Information
echo ==============================================
echo Qt Version: %QT_VERSION%
echo Target Platform: Linux ARM64 ^(aarch64^)
echo Toolchain: GNU GCC %GCC_VERSION%
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Build Date: %DATE% %TIME%
echo Install Path: %FINAL_INSTALL_DIR%
echo Host Qt Path: %HOST_QT_DIR%
echo Toolchain Prefix: %TOOLCHAIN_PREFIX%
echo.
echo NOTE: This is a cross-compiled build for ARM64 Linux
echo - Binaries cannot run on x86_64 Windows
echo - Deploy to ARM64 Linux target system
echo - Ensure target system has required runtime libraries
echo.
if "%SEPARATE_DEBUG%"=="true" (
  echo Debug symbols have been separated for easier deployment
  echo.
)
echo Build completed successfully!
) > %FINAL_INSTALL_DIR%\build-info.txt

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist %FINAL_INSTALL_DIR% (
    echo Final installation directory verified.
    echo.
    echo Directory contents:
    dir %FINAL_INSTALL_DIR%
    echo.
    echo ARM64 CROSS-COMPILATION NOTES:
    echo - The generated binaries are for ARM64 Linux systems
    echo - Cannot be executed on this Windows x86_64 system
    echo - Deploy to target ARM64 Linux device for testing
    echo.
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo.
echo ===============================================
echo Qt6 ARM64 cross-compilation completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%
echo Target Platform: Linux ARM64 (aarch64)
echo ===============================================