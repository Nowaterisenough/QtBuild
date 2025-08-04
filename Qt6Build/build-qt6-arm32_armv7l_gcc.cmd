@echo off
@chcp 65001
@cd /d %~dp0

REM ARM32交叉编译Qt6构建脚本 (Windows Host)
REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, ARM_ARCH
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set ARM_ARCH=%6

REM 例如: 6.9.1  13.2.0  release  static  false  armv7l
REM ARM_ARCH 支持: armv7l, armv6l

if "%ARM_ARCH%"=="" set ARM_ARCH=armv7l

set QT_VERSION2=%QT_VERSION:~0,3%

REM 设置ARM GCC交叉编译器版本标识
set ARM_GCC_VERSION=arm32_gcc%GCC_VERSION:_=%%_%ARM_ARCH%

REM 设置交叉编译工具链路径
set CROSS_COMPILE_PATH=D:\a\QtBuild\arm-gcc-toolchain\%ARM_ARCH%\bin
set PATH=%CROSS_COMPILE_PATH%;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%
set QT_PATH=D:\a\QtBuild\Qt

REM ARM32统一使用gnueabihf工具链
set CROSS_PREFIX=arm-linux-gnueabihf-
set QT_PLATFORM=linux-arm-gnueabi-g++

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build_arm32
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install_arm32

REM 设置sysroot路径
set ARM_SYSROOT=D:\a\QtBuild\sysroot\%ARM_ARCH%

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%ARM_GCC_VERSION%"
set BUILD_DIR="%SHORT_BUILD_PATH%"

echo Starting Qt ARM32 cross-compilation build...
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo ARM Architecture: %ARM_ARCH%
echo Cross Compiler Prefix: %CROSS_PREFIX%
echo Qt Platform: %QT_PLATFORM%
echo Sysroot: %ARM_SYSROOT%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

REM 检查交叉编译器是否存在
if not exist "%CROSS_COMPILE_PATH%\%CROSS_PREFIX%gcc.exe" (
    echo Error: Cross compiler not found at %CROSS_COMPILE_PATH%\%CROSS_PREFIX%gcc.exe
    echo Please install ARM32 GCC cross-compilation toolchain
    echo Download from: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
    exit /b 1
)

REM 清理并创建build目录
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM 配置参数 - 针对ARM32嵌入式设备优化
set CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++17 -headersclean -skip qtwebengine -skip qtwebkit -skip qtmultimedia -skip qtlocation -skip qtspeech -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -no-openssl -no-dbus -platform %QT_PLATFORM% -device-option CROSS_COMPILE=%CROSS_PREFIX% -no-opengl -no-egl -no-feature-vulkan

REM 如果sysroot存在，添加sysroot选项
if exist "%ARM_SYSROOT%" (
    set CFG_OPTIONS=%CFG_OPTIONS% -sysroot %ARM_SYSROOT%
)

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release -optimize-size
)

REM static 不能分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info
    )
)

REM 设置交叉编译环境变量
set CC=%CROSS_PREFIX%gcc
set CXX=%CROSS_PREFIX%g++
set AR=%CROSS_PREFIX%ar
set STRIP=%CROSS_PREFIX%strip
set OBJCOPY=%CROSS_PREFIX%objcopy
set OBJDUMP=%CROSS_PREFIX%objdump

echo Configure options: %CFG_OPTIONS%
echo Cross-compilation environment:
echo   CC=%CC%
echo   CXX=%CXX%
echo   AR=%AR%

REM configure
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 构建
echo Starting ARM32 cross-compilation build...
cmake --build . --parallel 4
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

REM 创建ARM32设备专用的qt.conf
echo [Paths] > %FINAL_INSTALL_DIR%\bin\qt.conf
echo Prefix = . >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo LibraryExecutables = bin >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo Binaries = bin >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo Libraries = lib >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo Headers = include >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo. >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo [Qt] >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo QT_QPA_PLATFORM=linuxfb >> %FINAL_INSTALL_DIR%\bin\qt.conf
echo QT_QPA_GENERIC_PLUGINS=evdevtouch >> %FINAL_INSTALL_DIR%\bin\qt.conf

echo ARM32 cross-compilation build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%
echo Target architecture: %ARM_ARCH%
echo.
echo To use this Qt build on ARM32 device:
echo 1. Copy the entire installation directory to your ARM device
echo 2. Set PATH to include the Qt bin directory
echo 3. Set LD_LIBRARY_PATH to include the Qt lib directory (for shared builds)
echo 4. Ensure the target device has compatible runtime libraries

REM 验证安装目录存在
if exist %FINAL_INSTALL_DIR% (
    echo Final installation directory verified.
    dir %FINAL_INSTALL_DIR%
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)
