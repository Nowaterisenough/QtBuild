@echo off
@chcp 65001
@cd /d %~dp0

REM 启用扩展命令，禁用延迟扩展（避免路径中 '!' 问题）
setlocal enableextensions disabledelayedexpansion

REM 参数依次为: Qt版本, Clang版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, RUNTIME, BIN_PATH, VERSION_CODE, TEST_MODE
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

REM 清理PATH，避免系统工具冲突
echo Cleaning PATH to avoid conflicts with system tools...
set "CLEAN_PATH="
set "CLEAN_PATH=%BIN_PATH%;D:\a\QtBuild\ninja"
set "CLEAN_PATH=%CLEAN_PATH%;C:\Windows\System32"
set "CLEAN_PATH=%CLEAN_PATH%;C:\Windows"
set "CLEAN_PATH=%CLEAN_PATH%;C:\Program Files\Git\bin"
set "CLEAN_PATH=%CLEAN_PATH%;C:\Program Files\CMake\bin"
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

REM ========== 纯 CMD 版 Windows SDK 检测 ==========
echo Detecting Windows SDK for llvm-rc...
call :FindWindowsSDK
if errorlevel 1 (
    echo ERROR: Windows SDK not found. LLVM-RC requires Windows SDK headers.
    echo Please ensure Windows SDK 10 is installed.
    exit /b 1
)
echo Found Windows SDK: %WINDOWS_SDK_VERSION% at %WINDOWS_SDK_ROOT%

set "WINDOWS_SDK_INCLUDE=%WINDOWS_SDK_ROOT%\Include\%WINDOWS_SDK_VERSION%"
set "WINDOWS_SDK_LIB=%WINDOWS_SDK_ROOT%\Lib\%WINDOWS_SDK_VERSION%"
set "INCLUDE=%WINDOWS_SDK_INCLUDE%\um;%WINDOWS_SDK_INCLUDE%\shared;%WINDOWS_SDK_INCLUDE%\winrt;%WINDOWS_SDK_INCLUDE%\ucrt"
set "LIB=%WINDOWS_SDK_LIB%\um\x64;%WINDOWS_SDK_LIB%\ucrt\x64"
set "LIBPATH=%WINDOWS_SDK_LIB%\um\x64;%WINDOWS_SDK_LIB%\ucrt\x64"

echo Windows SDK configured successfully.
echo INCLUDE=%INCLUDE%
echo.

REM 显式设置编译器环境变量
set "CC=clang"
set "CXX=clang++"
set "AR=llvm-ar"
set "RANLIB=llvm-ranlib"
set "RC=llvm-rc"

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
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -platform win32-clang-g++ -nomake examples -nomake tests -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop"

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

echo Configure options: %CFG_OPTIONS%
echo.

REM 运行 configure（用标签处理错误，避免在括号内展开包含括号的变量）
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS%
set "CFGERR=%errorlevel%"
if "%CFGERR%"=="0" goto :CFG_OK

:CFG_FAIL
echo Configure failed with error code: %CFGERR%
echo.
echo Current environment:
echo CC=%CC%
echo CXX=%CXX%
echo RC=%RC%
echo INCLUDE=%INCLUDE%
exit /b %CFGERR%

:CFG_OK

REM 构建（同样用标签处理错误）
echo Starting build...
if /i "%TEST_MODE%"=="true" echo Building in test mode - qtbase only...
echo Note: Using conservative parallel build settings for stability...
echo Current working directory: %CD%
echo Windows SDK Include Path: %INCLUDE%
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

REM 移动或复制文件到最终目录（避免括号块）
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


REM ============================================
REM 子程序：查找 Windows SDK（纯 CMD，无 PowerShell）
REM 输出：设置 WINDOWS_SDK_ROOT 与 WINDOWS_SDK_VERSION
REM 返回：errorlevel 0 => 成功；1 => 失败
REM ============================================
:FindWindowsSDK
setlocal
set "SDK_ROOT="
set "SDK_VER="

REM 1) 注册表（优先 WOW6432Node）
for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" /v InstallationFolder 2^>nul') do set "SDK_ROOT=%%B"
if not defined SDK_ROOT (
    for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v InstallationFolder 2^>nul') do set "SDK_ROOT=%%B"
)

REM 去除尾部反斜杠并验证
if defined SDK_ROOT (
    if "%SDK_ROOT:~-1%"=="\" set "SDK_ROOT=%SDK_ROOT:~0,-1%"
)
if defined SDK_ROOT if not exist "%SDK_ROOT%\Include" set "SDK_ROOT="

REM 2) 常见路径（避免 for in 集合里出现含括号路径）
if not defined SDK_ROOT if exist "%ProgramFiles(x86)%\Windows Kits\10\Include" set "SDK_ROOT=%ProgramFiles(x86)%\Windows Kits\10"
if not defined SDK_ROOT if exist "%ProgramFiles%\Windows Kits\10\Include" set "SDK_ROOT=%ProgramFiles%\Windows Kits\10"

if not defined SDK_ROOT (
    endlocal & exit /b 1
)

REM 3) 在 Include 下选择最高版本目录
set "TMPA=%TEMP%\__sdk_dirs.txt"
set "TMPB=%TEMP%\__sdk_dirs_sorted.txt"
dir /b /ad "%SDK_ROOT%\Include" > "%TMPA%" 2>nul
if errorlevel 1 (
    del /q "%TMPA%" 2>nul
    endlocal & exit /b 1
)
sort /R "%TMPA%" > "%TMPB%" 2>nul

REM 取排序后第一行
for /f "usebackq delims=" %%V in ("%TMPB%") do if not defined SDK_VER set "SDK_VER=%%~V"

del /q "%TMPA%" 2>nul
del /q "%TMPB%" 2>nul

if not defined SDK_VER (
    endlocal & exit /b 1
)

endlocal & (
    set "WINDOWS_SDK_ROOT=%SDK_ROOT%"
    set "WINDOWS_SDK_VERSION=%SDK_VER%"
)
exit /b 0