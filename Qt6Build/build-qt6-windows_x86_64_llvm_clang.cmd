@echo off
@chcp 65001
@cd /d %~dp0

REM 启用扩展命令，禁用延迟扩展（避免路径中 '!' 问题）
setlocal enableextensions disabledelayedexpansion

REM 参数: Qt版本, Clang版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, RUNTIME, BIN_PATH, VERSION_CODE, TEST_MODE
set "QT_VERSION=%~1"
set "CLANG_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "RUNTIME=%~6"
set "BIN_PATH=%~7"
set "VERSION_CODE=%~8"
set "TEST_MODE=%~9"
if "%TEST_MODE%"=="" set "TEST_MODE=false"

REM 清理 PATH，避免系统工具冲突
echo Cleaning PATH to avoid conflicts with system tools...
set "CLEAN_PATH=%BIN_PATH%;D:\a\QtBuild\ninja;C:\Windows\System32;C:\Windows;C:\Program Files\Git\bin;C:\Program Files\CMake\bin"
set "PATH=%CLEAN_PATH%"

set "QT_PATH=D:\a\QtBuild\Qt"
set "SHORT_BUILD_PATH=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"

set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%"
set "BUILD_DIR=%SHORT_BUILD_PATH%"

echo Starting Qt build...
echo Qt Version: %QT_VERSION%
echo Clang Version: %CLANG_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Runtime: %RUNTIME%
echo Test Mode: %TEST_MODE%
echo Compiler Path: %BIN_PATH%
echo Version Code: %VERSION_CODE%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

echo Using compiler:
clang --version
clang++ --version
echo.

REM ========== 仅为 llvm-rc 配置 MinGW 头文件搜索路径（不要把 SDK 加到 C/C++） ==========
REM 推导 llvm-mingw 根目录
for %%I in ("%BIN_PATH%\..") do set "MINGW_ROOT=%%~fI"

REM MinGW-w64 头文件目录
set "MINGW_INC1=%MINGW_ROOT%\include"
set "MINGW_INC2=%MINGW_ROOT%\x86_64-w64-windows-gnu\include"

REM 转为 8.3 短路径，避免空格引发拆词
for %%I in ("%MINGW_INC1%") do set "MINGW_INC1_SHORT=%%~sI"
for %%I in ("%MINGW_INC2%") do set "MINGW_INC2_SHORT=%%~sI"

REM llvm-rc 路径也用短路径
set "RC=%BIN_PATH%\llvm-rc.exe"
for %%I in ("%RC%") do set "RC_SHORT=%%~sI"
set "RC=%RC_SHORT%"

REM 仅为 RC 构造 -I 参数；注意：整条 -DCMAKE_RC_FLAGS:STRING=... 必须作为单一参数传入
set "RC_INCLUDE_FLAGS=-I%MINGW_INC1_SHORT% -I%MINGW_INC2_SHORT%"

REM 确保不带入任何遗留的 SDK 注入（清空可能的环境残留）
set "INCLUDE="
set "LIB="
set "LIBPATH="
set "CFLAGS="
set "CXXFLAGS="

echo RC will use MinGW headers:
echo   %RC_INCLUDE_FLAGS%
echo.

REM 显式设置编译器环境变量
set "CC=clang"
set "CXX=clang++"
set "AR=llvm-ar"
set "RANLIB=llvm-ranlib"

echo Using LLVM tools:
echo CC=%CC%
echo CXX=%CXX%
echo AR=%AR%
echo RANLIB=%RANLIB%
echo RC=%RC%
echo.

REM 清理并创建 build 目录
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%SHORT_BUILD_PATH%" 2>nul
mkdir "%TEMP_INSTALL_DIR%" 2>nul
cd /d "%SHORT_BUILD_PATH%"

REM 配置参数
set "CFG_OPTIONS=-%LINK_TYPE% -prefix \"%TEMP_INSTALL_DIR%\" -platform win32-clang-g++ -nomake examples -nomake tests -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop"

if /i "%TEST_MODE%"=="true" (
    echo Test mode enabled: Only building qtbase module
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"
)

set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

if /i "%BUILD_TYPE%"=="debug" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -debug"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -release"
)

if /i "%LINK_TYPE%"=="static" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -static-runtime"
)

if /i "%LINK_TYPE%"=="shared" (
    if /i "%SEPARATE_DEBUG%"=="true" (
        set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
    )
)

if "%CLANG_VERSION%"=="17.0" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -headersclean"
)

set "CFG_OPTIONS=%CFG_OPTIONS% -silent"

REM 仅把 RC 的设置传给 CMake（作为单一参数）
set "CMAKE_EXTRA=-- -DCMAKE_RC_COMPILER:FILEPATH=\"%RC%\" \"-DCMAKE_RC_FLAGS:STRING=%RC_INCLUDE_FLAGS%\""

echo Configure options:
echo   %CFG_OPTIONS%
echo   %CMAKE_EXTRA%
echo.

REM 运行 configure（用标签处理错误）
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS% %CMAKE_EXTRA%
set "CFGERR=%errorlevel%"
if "%CFGERR%"=="0" goto :CFG_OK

:CFG_FAIL
echo Configure failed with error code: %CFGERR%
echo.
echo CC=%CC%
echo CXX=%CXX%
echo RC=%RC%
exit /b %CFGERR%

:CFG_OK

REM 构建
echo Starting build...
if /i "%TEST_MODE%"=="true" echo Building in test mode - qtbase only...
echo Note: Using conservative parallel build settings for stability...
echo Current working directory: %CD%
echo.

cmake --build . --parallel 2
set "BLDERR=%errorlevel%"
if "%BLDERR%"=="0" goto :BLD_OK

echo Build failed with error code: %BLDERR%
echo.
echo Build failed. Attempting single-threaded build for debugging...
cmake --build . --parallel 1
set "BLDERR=%errorlevel%"
if "%BLDERR%"=="0" goto :BLD_OK

echo Single-threaded build also failed with error code: %BLDERR%
exit /b %BLDERR%

:BLD_OK

REM 安装
echo Installing to temporary directory...
cmake --install .
set "INSTERR=%errorlevel%"
if "%INSTERR%"=="0" goto :INST_OK

echo Install failed with error code: %INSTERR%
exit /b %INSTERR%

:INST_OK

REM 创建最终安装目录父目录
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul

REM 移动或复制文件到最终目录
echo Moving files to final directory...
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul
set "MVERR=%errorlevel%"
if "%MVERR%"=="0" goto :MV_OK

echo Move failed, fallback to copy...
xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul
set "CPERR=%errorlevel%"
if "%CPERR%"=="0" (
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
    goto :MV_OK
)
echo Copy also failed with error code: %CPERR%
exit /b %CPERR%

:MV_OK

REM shared 需要复制 LLVM-MinGW 运行时 DLL
if /i "%LINK_TYPE%"=="shared" (
    echo Copying LLVM-MinGW runtime libraries...
    copy "%BIN_PATH%\libc++.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libunwind.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
)

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" echo NOTE: Test mode was enabled - only qtbase was built
echo Installation directory: %FINAL_INSTALL_DIR%
exit /b 0