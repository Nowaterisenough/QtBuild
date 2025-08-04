@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5

set QT_VERSION2=%QT_VERSION:~0,3%
set GNU_VERSION=aarch64_none_linux_gnu_%GCC_VERSION%

REM 设置工具链路径
set TOOLCHAIN_ROOT=D:\a\QtBuild\arm-gnu-toolchain
set TOOLCHAIN_BIN=%TOOLCHAIN_ROOT%\bin
set TOOLCHAIN_SYSROOT=%TOOLCHAIN_ROOT%\aarch64-none-linux-gnu

REM 设置PATH，确保交叉编译器可以被找到
set PATH=%TOOLCHAIN_BIN%;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%
set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set HOST_QT_DIR="%QT_PATH%\%QT_VERSION%-host"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%GNU_VERSION%"
set BUILD_DIR="%SHORT_BUILD_PATH%"

REM 设置工具链前缀
set TOOLCHAIN_PREFIX=aarch64-none-linux-gnu

REM 设置交叉编译环境变量
set CC=%TOOLCHAIN_PREFIX%-gcc
set CXX=%TOOLCHAIN_PREFIX%-g++
set AR=%TOOLCHAIN_PREFIX%-ar
set STRIP=%TOOLCHAIN_PREFIX%-strip
set OBJCOPY=%TOOLCHAIN_PREFIX%-objcopy
set OBJDUMP=%TOOLCHAIN_PREFIX%-objdump
set NM=%TOOLCHAIN_PREFIX%-nm
set RANLIB=%TOOLCHAIN_PREFIX%-ranlib

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
echo Toolchain Root: %TOOLCHAIN_ROOT%
echo Toolchain Bin: %TOOLCHAIN_BIN%
echo Toolchain Sysroot: %TOOLCHAIN_SYSROOT%
echo Source: %SRC_QT%
echo Host Qt Dir: %HOST_QT_DIR%
echo Final Install Dir: %FINAL_INSTALL_DIR%
echo CC: %CC%
echo CXX: %CXX%
echo =====================================

REM 验证工具链
echo Verifying toolchain...
set GCC_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-gcc.exe
set GPP_FULL_PATH=%TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-g++.exe

if not exist "%GCC_FULL_PATH%" (
    echo Error: ARM GNU toolchain GCC not found at %GCC_FULL_PATH%
    echo Available files in bin directory:
    dir "%TOOLCHAIN_BIN%\*.exe" /B 2>nul
    exit /b 1
)

if not exist "%GPP_FULL_PATH%" (
    echo Error: ARM GNU toolchain G++ not found at %GPP_FULL_PATH%
    echo Available files in bin directory:
    dir "%TOOLCHAIN_BIN%\*.exe" /B 2>nul
    exit /b 1
)

if not exist "%TOOLCHAIN_SYSROOT%" (
    echo Error: Toolchain sysroot not found at %TOOLCHAIN_SYSROOT%
    exit /b 1
)

echo Testing compiler execution...
echo GCC version:
"%GCC_FULL_PATH%" --version
if %errorlevel% neq 0 (
    echo Error: GCC test failed
    exit /b %errorlevel%
)

echo G++ version:
"%GPP_FULL_PATH%" --version
if %errorlevel% neq 0 (
    echo Error: G++ test failed
    exit /b %errorlevel%
)

REM 清理并创建build目录
echo Cleaning previous build...
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"

REM 创建CMake工具链文件
echo Creating CMake toolchain file...
set TOOLCHAIN_FILE=%SHORT_BUILD_PATH%\toolchain.cmake
(
echo # CMake toolchain file for ARM64 Linux cross-compilation
echo set^(CMAKE_SYSTEM_NAME Linux^)
echo set^(CMAKE_SYSTEM_PROCESSOR aarch64^)
echo.
echo # Cross-compiler settings - use full paths
echo set^(CMAKE_C_COMPILER "%GCC_FULL_PATH:\=/%"^)
echo set^(CMAKE_CXX_COMPILER "%GPP_FULL_PATH:\=/%"^)
echo set^(CMAKE_AR "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-ar.exe"^)
echo set^(CMAKE_STRIP "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-strip.exe"^)
echo set^(CMAKE_OBJCOPY "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-objcopy.exe"^)
echo set^(CMAKE_OBJDUMP "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-objdump.exe"^)
echo set^(CMAKE_NM "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-nm.exe"^)
echo set^(CMAKE_RANLIB "%TOOLCHAIN_BIN:\=/%/%TOOLCHAIN_PREFIX%-ranlib.exe"^)
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

echo Toolchain file created at: %TOOLCHAIN_FILE%

cd /d "%SHORT_BUILD_PATH%"

REM 配置参数 - 先设置Qt configure选项，再设置CMake选项
set QT_CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -qt-host-path %HOST_QT_DIR% -platform win32-g++ -xplatform linux-aarch64-gnu-g++ -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -opengl es2 -no-dbus -device-option CROSS_COMPILE=%TOOLCHAIN_PREFIX%-

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="debug" (
    set QT_CFG_OPTIONS=%QT_CFG_OPTIONS% -debug
    echo Building DEBUG version for ARM64...
) else (
    set QT_CFG_OPTIONS=%QT_CFG_OPTIONS% -release
    echo Building RELEASE version for ARM64...
)

REM shared构建才能分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set QT_CFG_OPTIONS=%QT_CFG_OPTIONS% -force-debug-info -separate-debug-info
        echo Separate debug info enabled for shared build
    )
)

REM CMake选项
set CMAKE_OPTIONS=-DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN_FILE%"

REM 完整的configure命令
set CFG_OPTIONS=%QT_CFG_OPTIONS% -- %CMAKE_OPTIONS%

echo Configure options: %CFG_OPTIONS%

REM 执行configure
echo Starting Qt configure...
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    echo.
    echo Debugging information:
    echo CMAKE_C_COMPILER: %CC%
    echo CMAKE_CXX_COMPILER: %CXX%
    echo GCC_FULL_PATH: %GCC_FULL_PATH%
    echo GPP_FULL_PATH: %GPP_FULL_PATH%
    echo Toolchain file: %TOOLCHAIN_FILE%
    if exist "%TOOLCHAIN_FILE%" (
        echo Toolchain file contents:
        type "%TOOLCHAIN_FILE%"
    ) else (
        echo Toolchain file not found!
    )
    exit /b %errorlevel%
)

REM 构建
echo Starting build...
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
    echo Failed to move to final directory, trying copy...
    xcopy "%TEMP_INSTALL_DIR%\*" %FINAL_INSTALL_DIR%\ /E /I /H /Y
    if %errorlevel% neq 0 (
        echo Copy also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
    rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
)

REM 创建构建信息文件
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
echo Toolchain Root: %TOOLCHAIN_ROOT%
echo Toolchain Sysroot: %TOOLCHAIN_SYSROOT%
echo CMake Toolchain File: %TOOLCHAIN_FILE%
echo.
echo NOTE: This is a cross-compiled build for ARM64 Linux
echo - Binaries cannot run on x86_64 Windows
echo - Deploy to ARM64 Linux target system
echo.
if "%SEPARATE_DEBUG%"=="true" (
  echo Debug symbols have been separated for easier deployment
  echo.
)
echo Build completed successfully!
) > %FINAL_INSTALL_DIR%\build-info.txt

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

if exist %FINAL_INSTALL_DIR% (
    echo Final installation directory verified.
    echo.
    echo ===============================================
    echo Qt6 ARM64 cross-compilation completed successfully!
    echo Installation directory: %FINAL_INSTALL_DIR%
    echo Target Platform: Linux ARM64 (aarch64)
    echo ===============================================
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)