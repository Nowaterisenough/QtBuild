@echo off
@chcp 65001
@cd /d %~dp0

REM 统一参数格式: Qt版本, 编译器版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, RUNTIME, [额外参数], TEST_MODE  
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"  
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "RUNTIME=%~6"
set "EXTRA_PARAM=%~7"
set "TEST_MODE=%~8"

REM 处理默认值
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"
if "%RUNTIME%"=="" set "RUNTIME=ucrt"

REM MinGW特定设置
set "GCC_VERSION=%COMPILER_VERSION%"

if /i "%RUNTIME%"=="ucrt" (
    set MinGW_VERSION=mingw%GCC_VERSION:_=%%_64_UCRT
) else (
    set MinGW_VERSION=mingw%GCC_VERSION:_=%%_64_MSVCRT
)

set "PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%"
set QT_PATH=D:\a\QtBuild\Qt
set BUILD_DIR=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MinGW_VERSION%"

echo Starting Qt build...
echo Qt Version: %QT_VERSION%
echo GCC Version: %GCC_VERSION%  
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Runtime: %RUNTIME%
echo Test Mode: %TEST_MODE%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

REM 显示编译器版本信息
echo.
echo Using compiler:
gcc --version
echo.

if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%"
mkdir "%BUILD_DIR%"
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%BUILD_DIR%"

REM ==== 配置选项构建 ====
REM 基础配置选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -opengl desktop"

REM 平台特定选项
set "CFG_OPTIONS=%CFG_OPTIONS% -platform win32-g++"

REM 模块选择
if /i "%TEST_MODE%"=="true" (
    echo Test mode enabled: Only building qtbase module
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
) else (
    echo Normal mode: Building all modules except qtwebengine
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"
)

REM 添加数据库支持
set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

REM PostgreSQL支持
if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%" (
    call :SlashPath "%PostgreSQL_ROOT%\include" PG_INC
    call :SlashPath "%PostgreSQL_ROOT%\lib" PG_LIB
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-psql"
    set "PostgreSQL_INCLUDE_DIRS=%PG_INC%"
    set "PostgreSQL_LIBRARY_DIRS=%PG_LIB%"
    if exist "%PostgreSQL_ROOT%\lib\libpq.lib" (set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\libpq.lib") else if exist "%PostgreSQL_ROOT%\lib\pq.lib" (set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\pq.lib")
    echo PostgreSQL support enabled: %PostgreSQL_ROOT%
)

REM MySQL支持  
if defined MYSQL_ROOT if exist "%MYSQL_ROOT%" (
    call :SlashPath "%MYSQL_ROOT%\include" MY_INC
    call :SlashPath "%MYSQL_ROOT%\lib" MY_LIB
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-mysql"
    set "MySQL_INCLUDE_DIRS=%MY_INC%"
    set "MySQL_LIBRARY_DIRS=%MY_LIB%"
    if exist "%MYSQL_ROOT%\lib\libmysql.lib" (set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\libmysql.lib") else if exist "%MYSQL_ROOT%\lib\mysqlclient.lib" (set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\mysqlclient.lib")
    echo MySQL support enabled: %MYSQL_ROOT%
)

REM 构建类型配置
if /i "%BUILD_TYPE%"=="debug" (
    echo Setting debug build configuration
    set "CFG_OPTIONS=%CFG_OPTIONS% -debug"
) else (
    echo Setting release build configuration  
    set "CFG_OPTIONS=%CFG_OPTIONS% -release"
)

REM 调试信息处理
if /i "%LINK_TYPE%"=="shared" (
    if /i "%SEPARATE_DEBUG%"=="true" (
        echo Enabling separate debug information for shared build
        set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
    )
)

echo Configure options: %CFG_OPTIONS%
echo.

REM ==== Qt Configure 执行 ====
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo ERROR: Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)
echo Configure completed successfully
echo.

REM 确认 Qt 配置摘要（供上层导出）
if exist "%BUILD_DIR%\config.summary" (
  echo Found config.summary
) else (
  echo Warning: config.summary not found in %BUILD_DIR%
)

echo Building...
cmake --build . --parallel 4
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo Installing...
cmake --install .
if errorlevel 1 (
    echo Install failed.
    exit /b 1
)

if not exist "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%"
if exist "%FINAL_INSTALL_DIR%" rmdir /s /q "%FINAL_INSTALL_DIR%"
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul
if errorlevel 1 (
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul
    if errorlevel 1 exit /b 1
    rmdir /s /q "%TEMP_INSTALL_DIR%"
)

if exist "%~dp0qt.conf" copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\" >nul

if /i "%LINK_TYPE%"=="shared" (
    copy "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    copy "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    copy "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%\bin\libpq.dll" copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
    if defined MYSQL_ROOT if exist "%MYSQL_ROOT%\bin\libmysql.dll" copy "%MYSQL_ROOT%\bin\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" >nul
)

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" echo NOTE: Test mode was enabled - only qtbase was built
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if not exist "%FINAL_INSTALL_DIR%" (
    echo Error: Final installation directory does not exist!
    exit /b 1
) else (
    echo Final installation directory verified.
    if /i "%LINK_TYPE%"=="shared" (
        echo Generated Qt libraries:
        if exist "%FINAL_INSTALL_DIR%\bin\Qt6*.dll" (
            dir /b "%FINAL_INSTALL_DIR%\bin\Qt6*.dll"
        ) else (
            echo No Qt6*.dll files found
        )
    )
)
exit /b 0

:SlashPath
setlocal
set "p=%~1"
set "p=%p:\=/%"
endlocal & set "%~2=%p%"
goto :eof