@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM 参数依次为: Qt版本, MSVC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, VCVARS_PATH, REDIST_PATH, VERSION_CODE
set QT_VERSION=%1
set MSVC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set VCVARS_PATH=%6
set REDIST_PATH=%7
set VERSION_CODE=%8

REM 移除参数中的引号，避免路径问题
set VCVARS_PATH=%VCVARS_PATH:"=%
set REDIST_PATH=%REDIST_PATH:"=%
set VERSION_CODE=%VERSION_CODE:"=%

REM 例如: 5.15.17  2022  release  static  false  "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"  "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Redist\MSVC"  "msvc2022_64"

REM 设置MSVC环境
echo Setting up MSVC %MSVC_VERSION% environment...
call "%VCVARS_PATH%" amd64
if %errorlevel% neq 0 (
    echo Error: Failed to setup MSVC environment
    exit /b 1
)

REM 设置jom和Perl路径
echo Setting up build tools...
set PATH=D:\a\QtBuild\jom;D:\a\QtBuild\Strawberry\c\bin;D:\a\QtBuild\Strawberry\perl\site\bin;D:\a\QtBuild\Strawberry\perl\bin;%PATH%

set QT_PATH=D:\a\QtBuild\Qt

REM 路径和文件名定义
set SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%
set INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%
set BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%LINK_TYPE%-%VERSION_CODE%

echo Starting Qt5 build...
echo Qt Version: %QT_VERSION%
echo MSVC Version: %MSVC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Version Code: %VERSION_CODE%

REM 验证工具
jom /VERSION > nul 2>&1
if %errorlevel% neq 0 (
    echo Error: jom not found
    exit /b 1
)

perl --version > nul 2>&1
if %errorlevel% neq 0 (
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
echo Compiler: MSVC %MSVC_VERSION% x64
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
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
set CFG_OPTIONS=-%LINK_TYPE% -prefix "%INSTALL_DIR%" -nomake examples -nomake tests -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop -platform win32-msvc -silent

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

REM shared 类型支持分离调试信息和多处理器编译
if "%LINK_TYPE%"=="shared" (
    set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -mp
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
echo Starting build...
jom
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 安装
echo Installing...
jom install
if %errorlevel% neq 0 (
    echo Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 复制qt.conf (如果存在)
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin\" > nul
)

REM shared需要复制MSVC运行时库和创建部署工具
if "%LINK_TYPE%"=="shared" (
    echo Setting up shared library environment...
    
    REM 复制MSVC运行时库
    echo Copying MSVC runtime libraries...
    mkdir "%INSTALL_DIR%\redist" 2>nul
    for /f "delims=" %%i in ('dir "%REDIST_PATH%" /b /ad 2^>nul') do (
        copy "%REDIST_PATH%\%%i\x64\Microsoft.VC143.CRT\*.dll" "%INSTALL_DIR%\redist\" > nul 2>&1
    )

    REM 创建环境设置脚本
    echo Creating environment setup script...
    (
    echo @echo off
    echo :: Qt5 MSVC Shared Environment Setup Script
    echo SET QTDIR=%INSTALL_DIR%
    echo SET PATH=%INSTALL_DIR%\bin;%%PATH%%
    echo SET QT_PLUGIN_PATH=%INSTALL_DIR%\plugins
    echo SET QML_IMPORT_PATH=%INSTALL_DIR%\qml
    echo SET QML2_IMPORT_PATH=%INSTALL_DIR%\qml
    echo echo Qt5 MSVC Shared environment set up for: %INSTALL_DIR%
    echo echo Use windeployqt.exe to deploy applications
    ) > "%INSTALL_DIR%\setup_env.cmd"

    REM 创建部署指南
    echo Creating deployment guide...
    (
    echo @echo off
    echo echo.
    echo echo =============================================
    echo echo Qt5 MSVC Shared Library Deployment Guide
    echo echo =============================================
    echo echo.
    echo echo This Qt5 build requires runtime libraries:
    echo echo.
    echo echo Required Qt DLLs:
    dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2^>nul ^| findstr /v /i debug
    echo echo.
    echo echo Required MSVC Runtime:
    echo echo - Located in: %INSTALL_DIR%\redist\
    dir "%INSTALL_DIR%\redist\*.dll" /b 2^>nul
    echo echo.
    echo echo Deployment Steps:
    echo echo 1. Use windeployqt.exe for automatic deployment
    echo echo 2. Copy MSVC runtime DLLs from redist folder
    echo echo 3. Test on clean system
    echo echo.
    echo pause
    ) > "%INSTALL_DIR%\deployment_guide.cmd"

    REM 显示生成的库文件
    echo.
    echo Generated Qt libraries:
    dir "%INSTALL_DIR%\lib\Qt5*.lib" /b 2>nul
    echo.
    echo Generated Qt DLLs:
    dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2>nul
)

REM 创建构建信息文件
echo Creating build info...
(
echo Qt5 MSVC Build Information
echo ==========================
echo Qt Version: %QT_VERSION%
echo Compiler: MSVC %MSVC_VERSION% x64
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Build Date: %DATE% %TIME%
echo Install Path: %INSTALL_DIR%
echo.
if "%SEPARATE_DEBUG%"=="true" (
  echo Debug Info: Separated ^(PDB files generated^)
) else (
  echo Debug Info: Embedded
)
echo.
echo Configuration:
if "%LINK_TYPE%"=="static" (
  echo - Static linking
  echo - Static runtime
  echo - Optimized for size
) else (
  echo - Shared libraries ^(DLL^)
  echo - Multi-processor compilation
  echo - MSVC runtime required
)
echo - OpenGL Desktop
echo - Schannel SSL
echo.
echo Build completed successfully!
) > "%INSTALL_DIR%\build-info.txt"

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
        echo - MSVC runtime libraries available in redist folder
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