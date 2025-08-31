@echo off
@chcp 65001 >nul
setlocal enableextensions

REM 参数: QT_VERSION COMPILER_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG RUNTIME [EXTRA] TEST_MODE
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "RUNTIME=%~6"
set "TEST_MODE=%~8"

REM 默认值
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"
if "%RUNTIME%"=="" set "RUNTIME=ucrt"

REM MinGW设置
if /i "%RUNTIME%"=="ucrt" (
    set "MinGW_VERSION=mingw%COMPILER_VERSION:_=%%_64_UCRT"
) else (
    set "MinGW_VERSION=mingw%COMPILER_VERSION:_=%%_64_MSVCRT"
)

REM 路径设置
set "PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%"
set "QT_PATH=D:\a\QtBuild\Qt"
set "BUILD_DIR=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MinGW_VERSION%"

echo === Qt %QT_VERSION% MinGW Build ===
echo GCC Version: %COMPILER_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Runtime: %RUNTIME%
echo Install Dir: %FINAL_INSTALL_DIR%

REM 验证编译器
gcc --version | findstr "gcc" || (echo ERROR: GCC not found & exit /b 1)

REM 清理和创建目录
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%BUILD_DIR%" || exit /b 1
mkdir "%TEMP_INSTALL_DIR%" || exit /b 1
cd /d "%BUILD_DIR%" || exit /b 1

REM 构建配置选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -opengl desktop -platform win32-g++"

REM 模块选择
if /i "%TEST_MODE%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"
)

REM 数据库支持
set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

REM PostgreSQL支持
if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-psql"
    set "PostgreSQL_INCLUDE_DIRS=%PostgreSQL_ROOT%/include"
    set "PostgreSQL_LIBRARY_DIRS=%PostgreSQL_ROOT%/lib"
    echo PostgreSQL support enabled: %PostgreSQL_ROOT%
)

REM MySQL支持  
if defined MYSQL_ROOT if exist "%MYSQL_ROOT%" (
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

REM 复制运行时DLL（仅shared）
if /i "%LINK_TYPE%"=="shared" (
    copy "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    copy "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    copy "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    
    REM 复制数据库DLL
    if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%\bin\libpq.dll" (
        copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    )
    if defined MYSQL_ROOT if exist "%MYSQL_ROOT%\bin\libmysql.dll" (
        copy "%MYSQL_ROOT%\bin\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    )
)

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" echo NOTE: Test mode - only qtbase built
echo Installation: %FINAL_INSTALL_DIR%