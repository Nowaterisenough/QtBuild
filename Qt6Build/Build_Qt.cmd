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

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MinGW_VERSION%"
set BUILD_DIR="%SHORT_BUILD_PATH%"

REM 清理并创建build目录
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%" && cd /d "%SHORT_BUILD_PATH%"
mkdir "%TEMP_INSTALL_DIR%"

REM 配置参数
set CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -skip qtgrpc -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-sql-psql -no-sql-odbc -schannel -platform win32-g++ -opengl desktop

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

REM 安装到临时目录
cmake --install .
if %errorlevel% neq 0 (
    echo Install failed!
    exit /b %errorlevel%
)

REM 创建最终安装目录并移动文件
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul
move "%TEMP_INSTALL_DIR%" %FINAL_INSTALL_DIR%
if %errorlevel% neq 0 (
    echo Failed to move to final directory!
    exit /b %errorlevel%
)

REM 复制qt.conf
copy %~dp0\qt.conf %FINAL_INSTALL_DIR%\bin

REM shared需要复制运行时DLL
if "%LINK_TYPE%"=="shared" (
    copy D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll %FINAL_INSTALL_DIR%\bin\
    copy D:\a\QtBuild\mingw64\bin\libstdc++-6.dll %FINAL_INSTALL_DIR%\bin\
    copy D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll %FINAL_INSTALL_DIR%\bin\
)

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

@cmd /k cd /d %FINAL_INSTALL_DIR%