@echo off
@chcp 65001
@cd /d %~dp0

REM 参数依次为: Qt版本, Clang版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, RUNTIME, BIN_PATH, VERSION_CODE, TEST_MODE
set QT_VERSION=%1
set CLANG_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set RUNTIME=%6
set BIN_PATH=%7
set VERSION_CODE=%8
set TEST_MODE=%9

REM 移除参数中的引号，避免路径问题
set BIN_PATH=%BIN_PATH:"=%
set VERSION_CODE=%VERSION_CODE:"=%

REM 例如: 6.9.1  20.1  release  static  false  ucrt  "D:\a\QtBuild\llvm-mingw-20250528-ucrt-x86_64\bin"  "llvm-mingw20.1.6_64_UCRT"  false

REM 处理可能为空的参数，设置默认值
if "%TEST_MODE%"=="" set TEST_MODE=false

REM 设置编译器路径和工具
set PATH=%BIN_PATH%;D:\a\QtBuild\ninja;%PATH%

set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%
set FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%
set BUILD_DIR=%SHORT_BUILD_PATH%

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

REM 显示编译器版本信息
echo Using compiler:
clang --version
clang++ --version
echo.

REM 跳过Windows SDK检测，直接使用LLVM工具链
echo Using LLVM-MinGW toolchain (self-contained)...
echo Skipping Windows SDK detection - LLVM-MinGW includes all necessary tools.

REM 确保LLVM-Clang编译器优先级最高
set PATH=%BIN_PATH%;D:\a\QtBuild\ninja;%PATH%

REM 显式设置编译器环境变量
set CC=clang
set CXX=clang++
set AR=llvm-ar
set RANLIB=llvm-ranlib
set RC=llvm-rc

echo Using LLVM tools:
echo CC=%CC%
echo CXX=%CXX%
echo AR=%AR%
echo RANLIB=%RANLIB%
echo RC=%RC%

REM 清理并创建build目录
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM 配置参数 - 使用正确的平台
set CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -platform win32-clang-g++ -nomake examples -nomake tests -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop

REM 测试模式：只编译 qtbase
if /i "%TEST_MODE%"=="true" (
    echo Test mode enabled: Only building qtbase module
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
) else (
    REM 正常模式：跳过 qtwebengine
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"
)

REM 添加SQLite支持（Qt内置）
set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

REM 根据构建类型添加相应选项
if /i "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
)

REM static 类型添加静态运行时选项
if "%LINK_TYPE%"=="static" (
    set CFG_OPTIONS=%CFG_OPTIONS% -static-runtime
)

REM shared 类型支持分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info
    )
)

REM Clang 17.0 版本添加 headersclean 选项
if "%CLANG_VERSION%"=="17.0" (
    set CFG_OPTIONS=%CFG_OPTIONS% -headersclean
)

REM 添加编译器优化选项以避免syncqt问题
set CFG_OPTIONS=%CFG_OPTIONS% -silent

echo Configure options: %CFG_OPTIONS%

REM 执行configure
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    echo.
    echo Troubleshooting suggestions:
    echo 1. Verify LLVM-Clang installation
    echo 2. Check environment variables
    echo 3. Ensure all required tools are in PATH
    echo.
    echo Current environment:
    echo CC=%CC%
    echo CXX=%CXX%
    echo RC=%RC%
    echo PATH=%PATH%
    exit /b %errorlevel%
)

REM 构建 - 使用更保守的并行设置
echo Starting build...
if /i "%TEST_MODE%"=="true" (
    echo Building in test mode - qtbase only...
)
echo Note: Using conservative parallel build settings for stability...
cmake --build . --parallel 2
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    echo.
    echo Build failed. Attempting single-threaded build for debugging...
    cmake --build . --parallel 1
    if %errorlevel% neq 0 (
        echo Single-threaded build also failed with error code: %errorlevel%
        echo.
        echo Additional troubleshooting:
        echo 1. Check if all LLVM tools are available
        echo 2. Verify resource compiler setup
        echo 3. Check CMake cache and regenerate if needed
        exit /b %errorlevel%
    )
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
echo Source: "%TEMP_INSTALL_DIR%"
echo Destination: "%FINAL_INSTALL_DIR%"

move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%"
if %errorlevel% neq 0 (
    echo Failed to move to final directory with error code: %errorlevel%
    REM 尝试复制而不是移动
    echo Trying to copy instead...
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y
    if %errorlevel% neq 0 (
        echo Copy also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
    REM 清理临时目录
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM 复制qt.conf (如果存在)
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\"
)

REM shared需要复制LLVM-MinGW运行时DLL
if "%LINK_TYPE%"=="shared" (
    echo Copying LLVM-MinGW runtime libraries...
    copy "%BIN_PATH%\libc++.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libunwind.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    
    REM 创建部署指南
    echo Creating deployment guide...
    (
    echo @echo off
    echo echo LLVM-Clang Qt6 Shared Library Deployment Guide
    echo echo ============================================
    echo echo Required Runtime Libraries:
    echo echo - libc++.dll
    echo echo - libunwind.dll
    echo echo - libwinpthread-1.dll
    echo echo.
    echo echo Usage: Copy these DLLs with your application
    echo pause
    ) > "%FINAL_INSTALL_DIR%\deployment_guide.cmd"
)

REM 创建构建信息文件
echo Creating build info...
(
echo Qt6 LLVM-Clang Build Information
echo ================================
echo Qt Version: %QT_VERSION%
echo Compiler: LLVM-Clang %CLANG_VERSION%
echo Runtime: %RUNTIME%
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Test Mode: %TEST_MODE%
echo Build Date: %DATE% %TIME%
echo Install Path: %FINAL_INSTALL_DIR%
echo Toolchain: LLVM-MinGW ^(self-contained^)
echo Resource Compiler: %RC%
echo.
if "%SEPARATE_DEBUG%"=="true" (
  echo Debug Info: Separated ^(PDB files generated^)
) else (
  echo Debug Info: Embedded
)
echo.
if /i "%TEST_MODE%"=="true" (
  echo NOTE: Test mode was enabled - only qtbase was built
)
echo.
echo Build completed successfully!
) > "%FINAL_INSTALL_DIR%\build-info.txt"

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" (
    echo NOTE: Test mode was enabled - only qtbase was built
)
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist "%FINAL_INSTALL_DIR%" (
    echo Final installation directory verified.
    if "%LINK_TYPE%"=="shared" (
        echo Generated Qt libraries:
        dir /b "%FINAL_INSTALL_DIR%\bin\Qt6*.dll" 2>nul
    )
    echo.
    echo Directory contents:
    dir "%FINAL_INSTALL_DIR%"
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo.
echo ================================
echo Build completed successfully!
if /i "%TEST_MODE%"=="true" (
    echo NOTE: Test mode was enabled - only qtbase was built
)
echo Installation directory: %FINAL_INSTALL_DIR%
echo ================================