@echo off
@chcp 65001 >nul
setlocal enableextensions

REM 参数: QT_VERSION COMPILER_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG [UNUSED] TEST_MODE
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "TEST_MODE=%~7"

REM 默认值
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"

REM 设置MSVC环境
if "%COMPILER_VERSION%"=="2022" (
    call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" amd64
) else if "%COMPILER_VERSION%"=="2019" (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" amd64
) else (
    echo Unsupported MSVC version: %COMPILER_VERSION%
    exit /b 1
)

REM 路径设置
set "QT_PATH=D:\a\QtBuild\Qt"
set "BUILD_DIR=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\msvc%COMPILER_VERSION%_64"

echo === Qt %QT_VERSION% MSVC Build ===
echo MSVC Version: %COMPILER_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Test Mode: %TEST_MODE%
echo Install Dir: %FINAL_INSTALL_DIR%

REM 验证编译器
cl 2>nul || (echo ERROR: MSVC not found & exit /b 1)

REM 清理和创建目录
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%BUILD_DIR%" || exit /b 1
mkdir "%TEMP_INSTALL_DIR%" || exit /b 1
cd /d "%BUILD_DIR%" || exit /b 1

REM 构建配置选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop -platform win32-msvc"

REM 模块选择
if /i "%TEST_MODE%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
    echo Test mode: Only building qtbase, skipping SQL drivers
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"

    REM 数据库支持（仅在非test mode下）
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

    REM PostgreSQL支持 - 必须存在
    if not defined PostgreSQL_ROOT (
        echo ERROR: PostgreSQL_ROOT not defined
        exit /b 1
    )
    if not exist "%PostgreSQL_ROOT%" (
        echo ERROR: PostgreSQL directory not found: %PostgreSQL_ROOT%
        exit /b 1
    )
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-psql"
    set "PostgreSQL_INCLUDE_DIRS=%PostgreSQL_ROOT%/include"
    set "PostgreSQL_LIBRARY_DIRS=%PostgreSQL_ROOT%/lib"
    echo PostgreSQL support enabled: %PostgreSQL_ROOT%

    REM MySQL支持 - 必须存在
    if not defined MYSQL_ROOT (
        echo ERROR: MYSQL_ROOT not defined
        exit /b 1
    )
    if not exist "%MYSQL_ROOT%" (
        echo ERROR: MySQL directory not found: %MYSQL_ROOT%
        exit /b 1
    )
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-mysql"
    set "MySQL_INCLUDE_DIRS=%MYSQL_ROOT%/include"
    set "MySQL_LIBRARY_DIRS=%MYSQL_ROOT%/lib"
    echo MySQL support enabled: %MYSQL_ROOT%
)

REM 构建类型
if /i "%BUILD_TYPE%"=="debug" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -debug"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -release"
)

REM 调试信息
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
)

echo Configure options: %CFG_OPTIONS%

REM 配置Qt
call "%SRC_QT%\configure.bat" %CFG_OPTIONS% || exit /b 1

REM 构建
cmake --build . --parallel 4 || exit /b 1

REM 安装
cmake --install . || exit /b 1

REM 移动到最终目录
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul || (
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul || exit /b 1
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM 复制qt.conf
if exist "%~dp0qt.conf" copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\" >nul

REM 复制数据库DLL（仅shared且非test mode）
if /i "%LINK_TYPE%"=="shared" if /i "%TEST_MODE%"=="false" (
    REM PostgreSQL DLL - 必须存在
    if not exist "%PostgreSQL_ROOT%\bin\libpq.dll" (
        echo ERROR: PostgreSQL DLL not found: %PostgreSQL_ROOT%\bin\libpq.dll
        exit /b 1
    )
    copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1
    echo Copied: libpq.dll

    REM MySQL DLL - 必须存在
    if not exist "%MYSQL_ROOT%\bin\libmysql.dll" (
        echo ERROR: MySQL DLL not found: %MYSQL_ROOT%\bin\libmysql.dll
        exit /b 1
    )
    copy "%MYSQL_ROOT%\bin\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1
    echo Copied: libmysql.dll
)

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" echo NOTE: Test mode - only qtbase built
echo Installation: %FINAL_INSTALL_DIR%