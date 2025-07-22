@echo off
@chcp 65001
@cd /d %~dp0

REM 参数依次为: Qt版本, MSVC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG
set QT_VERSION=%1
set MSVC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5

REM 例如: 6.9.1  2022  release  static  false

REM 设置MSVC版本代号
set MSVC_VERSION_CODE=msvc%MSVC_VERSION%_64

REM 设置MSVC环境变量
if "%MSVC_VERSION%"=="2022" (
    CALL "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" amd64
) else if "%MSVC_VERSION%"=="2019" (
    CALL "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" amd64
) else (
    echo Unsupported MSVC version: %MSVC_VERSION%
    exit /b 1
)

set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MSVC_VERSION_CODE%"
set BUILD_DIR="%SHORT_BUILD_PATH%"

echo Starting Qt build...
echo Qt Version: %QT_VERSION%
echo MSVC Version: %MSVC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

REM 显示编译器版本信息
echo Using compiler:
cl
echo.

REM 清理并创建build目录
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM 配置参数
set CFG_OPTIONS=-%LINK_TYPE% -platform win32-msvc -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
)

REM shared 类型支持分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info
    )
)

echo Configure options: %CFG_OPTIONS%

REM 执行configure
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

REM 构建
echo Starting build...
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

REM 复制qt.conf (如果存在)
if exist %~dp0\qt.conf (
    copy %~dp0\qt.conf %FINAL_INSTALL_DIR%\bin\
)

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist %FINAL_INSTALL_DIR% (
    echo Final installation directory verified.
    if "%LINK_TYPE%"=="shared" (
        echo Generated Qt libraries:
        dir /b %FINAL_INSTALL_DIR%\bin\Qt6*.dll
    )
    dir %FINAL_INSTALL_DIR%
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)