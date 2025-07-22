@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, BIN_PATH, VERSION_CODE
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set BIN_PATH=%6
set VERSION_CODE=%7

REM 例如: 5.15.17  8.1  release  static  false  "D:\a\QtBuild\mingw64\bin"  "mingw810_64"

REM 设置编译器路径和Perl
echo Setting up MinGW and Perl environment...
set PATH=%BIN_PATH%;D:\a\QtBuild\Strawberry\c\bin;D:\a\QtBuild\Strawberry\perl\site\bin;D:\a\QtBuild\Strawberry\perl\bin;%PATH%

set QT_PATH=D:\a\QtBuild\Qt
set NUM_THRED=%NUMBER_OF_PROCESSORS%

REM 路径和文件名定义
set SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%
set INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%
set BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%LINK_TYPE%-%VERSION_CODE%

echo Starting Qt5 build...
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Compiler Path: %BIN_PATH%
echo Version Code: %VERSION_CODE%
echo Threads: %NUM_THRED%

REM 验证工具
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

REM 补充设置qtbase\bin和gnuwin32\bin
set PATH=%SRC_QT%\qtbase\bin;%SRC_QT%\gnuwin32\bin;%PATH%

echo.
echo ================================
echo Qt5 Build Configuration
echo ================================
echo Qt Version: %QT_VERSION%
echo Compiler: MinGW GCC %GCC_VERSION% x64
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Threads: %NUM_THRED%
echo Source Dir: %SRC_QT%
echo Build Dir: %BUILD_DIR%
echo Install Dir: %INSTALL_DIR%
echo ================================
echo.

REM 清理并创建build目录
echo Cleaning previous build...
rmdir /s /q "%BUILD_DIR%" 2>nul
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

REM 配置参数
set CFG_OPTIONS=-%LINK_TYPE% -prefix "%INSTALL_DIR%" -nomake examples -nomake tests -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop -platform win32-g++ -silent

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="release-and-debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug-and-release
) else if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
)

REM static 类型添加静态运行时选项
if "%LINK_TYPE%"=="static" (
    set CFG_OPTIONS=%CFG_OPTIONS% -static-runtime -optimize-size
)

REM shared 类型支持分离调试信息
if "%LINK_TYPE%"=="shared" (
    set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -separate-debug-info
    )
)

echo Configure options: %CFG_OPTIONS%

REM 执行configure
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 编译
echo Starting build with %NUM_THRED% threads...
mingw32-make -j%NUM_THRED%
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 安装
echo Installing...
mingw32-make install
if %errorlevel% neq 0 (
    echo Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 复制qt.conf (如果存在)
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin\" > nul
)

REM shared需要复制MinGW运行时DLL和创建部署工具
if "%LINK_TYPE%"=="shared" (
    echo Setting up shared library environment...
    
    REM 复制MinGW运行时库
    echo Copying MinGW runtime libraries...
    mkdir "%INSTALL_DIR%\redist" 2>nul
    copy "%BIN_PATH%\libgcc_s_seh-1.dll" "%INSTALL_DIR%\redist\" > nul 2>&1
    copy "%BIN_PATH%\libstdc++-6.dll" "%INSTALL_DIR%\redist\" > nul 2>&1
    copy "%BIN_PATH%\libwinpthread-1.dll" "%INSTALL_DIR%\redist\" > nul 2>&1

    REM 创建环境设置脚本
    echo Creating environment setup script...
    (
    echo @echo off
    echo :: Qt5 MinGW Shared Environment Setup Script
    echo SET QTDIR=%INSTALL_DIR%
    echo SET PATH=%INSTALL_DIR%\bin;%%PATH%%
    echo SET QT_PLUGIN_PATH=%INSTALL_DIR%\plugins
    echo SET QML_IMPORT_PATH=%INSTALL_DIR%\qml
    echo SET QML2_IMPORT_PATH=%INSTALL_DIR%\qml
    echo echo Qt5 MinGW Shared environment set up for: %INSTALL_DIR%
    echo echo Use windeployqt.exe to deploy applications
    ) > "%INSTALL_DIR%\setup_env.cmd"

    REM 创建部署指南
    echo Creating deployment guide...
    (
    echo @echo off
    echo echo.
    echo echo ===============================================
    echo echo Qt5 MinGW Shared Library Deployment Guide
    echo echo ===============================================
    echo echo.
    echo echo This Qt5 MinGW build requires runtime libraries:
    echo echo.
    echo echo Required Qt DLLs:
    dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2^>nul ^| findstr /v /i debug
    echo echo.
    echo echo Required MinGW Runtime:
    echo echo - libgcc_s_seh-1.dll
    echo echo - libstdc++-6.dll  
    echo echo - libwinpthread-1.dll
    echo echo ^(Located in: %INSTALL_DIR%\redist\^)
    echo echo.
    echo echo Deployment Steps:
    echo echo 1. Use windeployqt.exe for automatic deployment
    echo echo 2. Copy MinGW runtime DLLs from redist folder
    echo echo 3. Test on clean system
    echo echo.
    echo pause
    ) > "%INSTALL_DIR%\deployment_guide.cmd"

    REM 显示生成的库文件
    echo.
    echo Generated Qt libraries:
    dir "%INSTALL_DIR%\lib\libQt5*.a" /b 2>nul
    echo.
    echo Generated Qt DLLs:
    dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2>nul
)

echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%

REM 验证安装目录存在
if exist "%INSTALL_DIR%" (
    echo Final installation directory verified.
    if "%LINK_TYPE%"=="shared" (
        echo.
        echo SHARED BUILD NOTES:
        echo - Run setup_env.cmd to set environment variables
        echo - Use windeployqt.exe to deploy applications
        echo - MinGW runtime libraries available in redist folder
        echo - Check deployment_guide.cmd for detailed instructions
    ) else (
        echo.
        echo STATIC BUILD NOTES:
        echo - No runtime DLLs required
        echo - Applications are self-contained
        echo - Optimized for size
    )
    dir "%INSTALL_DIR%"
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo.
echo ================================
echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%
echo ================================