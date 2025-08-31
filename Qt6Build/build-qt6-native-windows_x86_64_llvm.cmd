@echo off
@chcp 65001 >nul
setlocal enableextensions disabledelayedexpansion

REM 参数: QT_VERSION COMPILER_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG RUNTIME BIN_PATH VERSION_CODE TEST_MODE
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "RUNTIME=%~6"
set "BIN_PATH=%~7"
set "VERSION_CODE=%~8"
set "TEST_MODE=%~9"

REM 默认值
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"
if "%RUNTIME%"=="" set "RUNTIME=ucrt"

REM 路径设置
set "PATH=%BIN_PATH%;D:\a\QtBuild\ninja;C:\Windows\System32;C:\Windows;C:\Program Files\Git\bin;C:\Program Files\CMake\bin"
set "QT_PATH=D:\a\QtBuild\Qt"
set "BUILD_DIR=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%"

echo === Qt %QT_VERSION% LLVM Build ===
echo Compiler: LLVM/Clang %COMPILER_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Install Dir: %FINAL_INSTALL_DIR%

REM 验证编译器
clang --version | findstr "clang version" || (echo ERROR: Clang not found & exit /b 1)

REM 清理和创建目录
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%BUILD_DIR%" || exit /b 1
mkdir "%TEMP_INSTALL_DIR%" || exit /b 1
cd /d "%BUILD_DIR%" || exit /b 1

REM 设置编译器环境
set "CC=clang"
set "CXX=clang++"
set "AR=llvm-ar"
set "RANLIB=llvm-ranlib"

REM 推导MinGW根目录用于RC
for %%I in ("%BIN_PATH%\..") do set "MINGW_ROOT=%%~fI"
set "RC=%BIN_PATH%\llvm-rc.exe"
for %%I in ("%RC%") do set "RC=%%~sI"

REM 构建配置选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -platform win32-clang-g++ -nomake examples -nomake tests -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop"

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

REM 静态运行时
if /i "%LINK_TYPE%"=="static" set "CFG_OPTIONS=%CFG_OPTIONS% -static-runtime"

REM 调试信息
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
)

REM 头文件检查
if "%COMPILER_VERSION%"=="17.0" set "CFG_OPTIONS=%CFG_OPTIONS% -headersclean"

echo Configure options: %CFG_OPTIONS%

REM 配置Qt
call "%SRC_QT%\configure.bat" %CFG_OPTIONS% -- -DCMAKE_RC_COMPILER:FILEPATH="%RC%" || exit /b 1

REM 构建
echo Building with 2 parallel jobs...
cmake --build . --parallel 2 || (
    echo Parallel build failed, trying single-threaded...
    cmake --build . --parallel 1 || exit /b 1
)

REM 安装
cmake --install . || exit /b 1

REM 移动到最终目录
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul || (
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul || exit /b 1
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM 复制运行时DLL（仅shared）
if /i "%LINK_TYPE%"=="shared" (
    copy "%BIN_PATH%\libc++.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libunwind.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "%BIN_PATH%\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    
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