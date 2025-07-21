@echo off
@chcp 65001
@cd /d %~dp0

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5

REM 例如: 6.9.1  15.1.0  release  static  false

set QT_VERSION2=%QT_VERSION:~0,3%
set MinGW_VERSION=mingw%GCC_VERSION:_=%%_64_UCRT

set PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%
set QT_PATH=D:\a\QtBuild\Qt

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE\%MinGW_VERSION%"
set BUILD_DIR="%QT_PATH%\%QT_VERSION%\build-%LINK_TYPE-%BUILD_TYPE-%MinGW_VERSION%"

REM 清理并创建build目录
rmdir /s /q %BUILD_DIR% 2>nul
mkdir "%BUILD_DIR%" && cd /d "%BUILD_DIR%"

REM 配置参数
set CFG_OPTIONS=-%LINK_TYPE -prefix %INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -schannel -platform win32-g++ -opengl desktop

REM static 不能分离调试信息
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info
    )
)
if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
)

REM configure
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed!
    exit /b %errorlevel%
)

REM 构建
cmake --build . --parallel
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

REM 安装
cmake --install .
if %errorlevel% neq 0 (
    echo Install failed!
    exit /b %errorlevel%
)

REM 复制qt.conf
copy %~dp0\qt.conf %INSTALL_DIR%\bin

REM shared需要复制运行时DLL
if "%LINK_TYPE%"=="shared" (
    copy D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll %INSTALL_DIR%\bin\
    copy D:\a\QtBuild\mingw64\bin\libstdc++-6.dll %INSTALL_DIR%\bin\
    copy D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll %INSTALL_DIR%\bin\
)

echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%

@cmd /k cd /d %INSTALL_DIR%