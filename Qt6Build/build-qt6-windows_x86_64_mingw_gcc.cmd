@echo off
@chcp 65001
@cd /d %~dp0

REM 参数依次为: Qt版本, GCC版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, RUNTIME, WITH_DEBUG_INFO
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set RUNTIME=%6
set WITH_DEBUG_INFO=%7

REM 例如: 6.9.1  15.1.0  release  static  false  ucrt  true

set QT_VERSION2=%QT_VERSION:~0,3%

REM 直接根据 runtime 设置，不需要转换函数
if /i "%RUNTIME%"=="ucrt" (
    set MinGW_VERSION=mingw%GCC_VERSION:_=%%_64_UCRT
) else (
    set MinGW_VERSION=mingw%GCC_VERSION:_=%%_64_MSVCRT
)

REM 设置PATH时需要小心处理包含空格的路径
set "PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%"

REM 如果LLVM可用，添加到PATH
if "%LLVM_AVAILABLE%"=="true" (
    if defined LLVM_PATH (
        set "PATH=%LLVM_PATH%;%PATH%"
    )
)

set QT_PATH=D:\a\QtBuild\Qt

REM 使用短路径避免 Windows 路径长度限制
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

REM 路径和文件名定义
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MinGW_VERSION%"
set "BUILD_DIR=%SHORT_BUILD_PATH%"

echo Starting Qt build...
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo With Debug Info: %WITH_DEBUG_INFO%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

REM 清理并创建build目录
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul
if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM 配置参数 - 基本选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -platform win32-g++ -opengl desktop"

REM 将反斜杠路径转换为正斜杠，避免CMake转义问题
set "PG_INCLUDE_PATH="
set "PG_LIB_PATH="
set "MYSQL_INCLUDE_PATH="
set "MYSQL_LIB_PATH="

if defined PostgreSQL_ROOT (
    if exist "%PostgreSQL_ROOT%" (
        REM 转换反斜杠为正斜杠
        set "PG_INCLUDE_PATH=%PostgreSQL_ROOT%\include"
        set "PG_LIB_PATH=%PostgreSQL_ROOT%\lib"
        call :ConvertPath "!PG_INCLUDE_PATH!" PG_INCLUDE_PATH
        call :ConvertPath "!PG_LIB_PATH!" PG_LIB_PATH
        set "CFG_OPTIONS=%CFG_OPTIONS% -sql-psql"
        echo PostgreSQL support enabled: %PostgreSQL_ROOT%
    ) else (
        echo PostgreSQL path not found: %PostgreSQL_ROOT%
    )
)

if defined MYSQL_ROOT (
    if exist "%MYSQL_ROOT%" (
        REM 转换反斜杠为正斜杠
        set "MYSQL_INCLUDE_PATH=%MYSQL_ROOT%\include"
        set "MYSQL_LIB_PATH=%MYSQL_ROOT%\lib"
        call :ConvertPath "!MYSQL_INCLUDE_PATH!" MYSQL_INCLUDE_PATH
        call :ConvertPath "!MYSQL_LIB_PATH!" MYSQL_LIB_PATH
        set "CFG_OPTIONS=%CFG_OPTIONS% -sql-mysql"
        echo MySQL support enabled: %MYSQL_ROOT%
    ) else (
        echo MySQL path not found: %MYSQL_ROOT%
    )
)

REM 添加SQLite支持（Qt内置）
set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

REM 根据构建类型添加相应选项
if "%BUILD_TYPE%"=="debug" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -debug"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -release"
    REM 对于 release 构建，检查是否需要添加调试信息
    if "%WITH_DEBUG_INFO%"=="true" (
        set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info"
    )
)

REM 处理分离调试信息（仅对 shared 构建有效）
if "%LINK_TYPE%"=="shared" (
    if "%SEPARATE_DEBUG%"=="true" (
        set "CFG_OPTIONS=%CFG_OPTIONS% -separate-debug-info"
    )
)

echo Configure options: %CFG_OPTIONS%

REM 设置CMAKE环境变量来处理路径问题
if defined PostgreSQL_ROOT (
    set "PostgreSQL_ROOT=%PostgreSQL_ROOT%"
    set "PostgreSQL_INCLUDE_DIRS=%PG_INCLUDE_PATH%"
    set "PostgreSQL_LIBRARY_DIRS=%PG_LIB_PATH%"
    REM 查找libpq库
    if exist "%PostgreSQL_ROOT%\lib\libpq.lib" (
        set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\libpq.lib"
    ) else if exist "%PostgreSQL_ROOT%\lib\pq.lib" (
        set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\pq.lib"
    )
)

if defined MYSQL_ROOT (
    set "MySQL_ROOT=%MYSQL_ROOT%"
    set "MySQL_INCLUDE_DIRS=%MYSQL_INCLUDE_PATH%"
    set "MySQL_LIBRARY_DIRS=%MYSQL_LIB_PATH%"
    REM 查找MySQL库
    if exist "%MYSQL_ROOT%\lib\libmysql.lib" (
        set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\libmysql.lib"
    ) else if exist "%MYSQL_ROOT%\lib\mysqlclient.lib" (
        set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\mysqlclient.lib"
    )
)

REM configure - 使用 call 并处理路径
echo Starting configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    echo Trying alternative configuration without custom include/lib paths...
    
    REM 重试不带自定义路径的配置
    set "CFG_OPTIONS_RETRY=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -skip qtwebengine -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -platform win32-g++ -opengl desktop -sql-sqlite"
    
    if "%BUILD_TYPE%"=="debug" (
        set "CFG_OPTIONS_RETRY=%CFG_OPTIONS_RETRY% -debug"
    ) else (
        set "CFG_OPTIONS_RETRY=%CFG_OPTIONS_RETRY% -release"
        if "%WITH_DEBUG_INFO%"=="true" (
            set "CFG_OPTIONS_RETRY=%CFG_OPTIONS_RETRY% -force-debug-info"
        )
    )
    
    if "%LINK_TYPE%"=="shared" (
        if "%SEPARATE_DEBUG%"=="true" (
            set "CFG_OPTIONS_RETRY=%CFG_OPTIONS_RETRY% -separate-debug-info"
        )
    )
    
    echo Retry configure options: %CFG_OPTIONS_RETRY%
    call "%SRC_QT%\configure.bat" %CFG_OPTIONS_RETRY%
    if %errorlevel% neq 0 (
        echo Configure retry also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
)

REM 构建
echo Starting build...
cmake --build . --parallel 4
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    echo Checking for common issues...
    
    REM 检查是否是数据库驱动问题
    if exist "qtbase\src\plugins\sqldrivers\psql\CMakeFiles\QPSQLDriverPlugin.dir" (
        echo PostgreSQL driver build issue detected
        echo PostgreSQL paths:
        echo   Root: %PostgreSQL_ROOT%
        echo   Include: %PostgreSQL_INCLUDE_DIRS%
        echo   Lib: %PostgreSQL_LIBRARY_DIRS%
    )
    
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
if not exist "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul

REM 移动文件到最终目录
echo Moving files to final directory...
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
    if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM 复制qt.conf (如果存在)
if exist "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\"
)

REM shared需要复制运行时DLL
if "%LINK_TYPE%"=="shared" (
    echo Copying MinGW runtime DLLs...
    copy "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    copy "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
    
    REM 复制数据库驱动需要的DLL
    if defined PostgreSQL_ROOT (
        if exist "%PostgreSQL_ROOT%\bin\libpq.dll" (
            copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
            echo Copied PostgreSQL runtime DLL
        )
    )
    
    if defined MYSQL_ROOT (
        if exist "%MYSQL_ROOT%\bin\libmysql.dll" (
            copy "%MYSQL_ROOT%\bin\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" 2>nul
            echo Copied MySQL runtime DLL
        )
    )
)

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist "%FINAL_INSTALL_DIR%" (
    echo Final installation directory verified.
    dir "%FINAL_INSTALL_DIR%"
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo Qt build process completed successfully!
goto :eof

:ConvertPath
setlocal enabledelayedexpansion
set "inputPath=%~1"
set "outputVar=%~2"
set "convertedPath=!inputPath:\=/!"
endlocal & set "%outputVar%=%convertedPath%"
goto :eof