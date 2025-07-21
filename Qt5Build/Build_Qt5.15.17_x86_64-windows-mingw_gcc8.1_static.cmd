@echo off
@chcp 65001 > nul
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=5.15.17

:: 设置MinGW版本代号
SET MinGW_VERSION=mingw810_64

:: 设置编译器和Perl
echo Setting up MinGW and Perl environment...
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\Strawberry\c\bin;D:\a\QtBuild\Strawberry\perl\site\bin;D:\a\QtBuild\Strawberry\perl\bin;%PATH%

:: 验证工具
gcc --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: GCC not found
    exit /b 1
)

mingw32-make --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: mingw32-make not found
    exit /b 1
)

perl --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: Perl not found
    exit /b 1
)

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

:: 设置线程数
SET NUM_THRED=%NUMBER_OF_PROCESSORS%

:: 设置Qt源代码目录
SET SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%

:: 补充设置qtbase\bin和gnuwin32\bin
SET PATH=%SRC_QT%\qtbase\bin;%SRC_QT%\gnuwin32\bin;%PATH%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-static\%MinGW_VERSION%

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%MinGW_VERSION%

:: 显示配置信息
echo.
echo ================================
echo Qt5 Build Configuration
echo ================================
echo Qt Version: %QT_VERSION%
echo Compiler: MinGW 8.1.0 x64
echo Build Type: Static Release
echo Threads: %NUM_THRED%
echo Source Dir: %SRC_QT%
echo Build Dir: %BUILD_DIR%
echo Install Dir: %INSTALL_DIR%
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
    -static-runtime ^
    -release ^
    -optimize-size ^
    -prefix "%INSTALL_DIR%" ^
    -nomake examples ^
    -nomake tests ^
    -skip qtwebengine ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -schannel ^
    -opengl desktop ^
    -platform win32-g++ ^
    -silent

IF ERRORLEVEL 1 (
    echo Error: Configure failed
    exit /b 1
)

:: 编译
echo Starting build with %NUM_THRED% threads...
mingw32-make -j%NUM_THRED%
IF ERRORLEVEL 1 (
    echo Error: Build failed
    exit /b 1
)

:: 安装
echo Installing...
mingw32-make install
IF ERRORLEVEL 1 (
    echo Error: Install failed
    exit /b 1
)

:: 复制qt.conf
echo Copying qt.conf...
IF EXIST "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin" > nul
)

:: 创建构建信息文件
echo Creating build info...
(
echo Qt5 Build Information
echo =====================
echo Qt Version: %QT_VERSION%
echo Compiler: MinGW 8.1.0 x64
echo Build Type: Static Release
echo Build Date: %DATE% %TIME%
echo Install Path: %INSTALL_DIR%
echo Parallel Jobs: %NUM_THRED%
echo.
echo Configuration:
echo - Static linking
echo - OpenGL Desktop
echo - Schannel SSL
echo - Optimized for size
echo.
echo Build completed successfully!
) > "%INSTALL_DIR%\build-info.txt"

echo.
echo ================================
echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%
echo ================================

cd /d "%INSTALL_DIR%"