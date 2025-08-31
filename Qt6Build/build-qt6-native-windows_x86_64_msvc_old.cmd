@echo off
@chcp 65001
@cd /d %~dp0

REM 统一参数格式: Qt版本, 编译器版本, BUILD_TYPE, LINK_TYPE, SEPARATE_DEBUG, [特定参数], [额外参数], TEST_MODE
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
REM MSVC没有runtime参数，第6个参数为空或其他
set "UNUSED_PARAM=%~6"
set "EXTRA_PARAM=%~7"
set "TEST_MODE=%~8"

REM 处理默认值
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"

REM MSVC特定设置
set "MSVC_VERSION=%COMPILER_VERSION%"

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
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MSVC_VERSION_CODE%"
set "BUILD_DIR=%SHORT_BUILD_PATH%"

echo Starting Qt build...
echo Qt Version: %QT_VERSION%
echo MSVC Version: %MSVC_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Separate Debug: %SEPARATE_DEBUG%
echo Test Mode: %TEST_MODE%
echo Source: %SRC_QT%
echo Final Install Dir: %FINAL_INSTALL_DIR%

REM 显示编译器版本信息
echo Using compiler:
cl
echo.

REM 清理并创建build目录
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul
if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%SHORT_BUILD_PATH%" 
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

REM ==== 配置选项构建 ====
REM 基础配置选项
set "CFG_OPTIONS=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop"

REM 平台特定选项
set "CFG_OPTIONS=%CFG_OPTIONS% -platform win32-msvc"

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

REM 验证config.summary生成
if exist "%BUILD_DIR%\config.summary" (
    echo Found config.summary - configuration verified
) else (
    echo Warning: config.summary not found in %BUILD_DIR%
)
echo.

REM ==== 构建执行 ====
echo Starting build process...
if /i "%TEST_MODE%"=="true" (
    echo Building in test mode - qtbase only
) else (
    echo Building full Qt with all selected modules
)
cmake --build . --parallel 4
if %errorlevel% neq 0 (
    echo ERROR: Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)
echo Build completed successfully
echo.

REM ==== 安装执行 ====
echo Installing to temporary directory...
cmake --install .
if %errorlevel% neq 0 (
    echo ERROR: Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)
echo Install completed successfully
echo.

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

echo Build completed successfully!
if /i "%TEST_MODE%"=="true" (
    echo NOTE: Test mode was enabled - only qtbase was built
)
echo Installation directory: %FINAL_INSTALL_DIR%

REM 验证安装目录存在
if exist "%FINAL_INSTALL_DIR%" (
    echo Final installation directory verified.
    if /i "%LINK_TYPE%"=="shared" (
        echo Generated Qt libraries:
        dir /b "%FINAL_INSTALL_DIR%\bin\Qt6*.dll"
    )
    dir "%FINAL_INSTALL_DIR%"
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

REM 复制数据库DLL文件（仅shared构建）
if /i "%LINK_TYPE%"=="shared" (
    if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%\bin\libpq.dll" (
        copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" >nul 2>nul
        echo Copied PostgreSQL DLL
    )
    if defined MYSQL_ROOT if exist "%MYSQL_ROOT%\bin\libmysql.dll" (
        copy "%MYSQL_ROOT%\bin\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" >nul 2>nul
        echo Copied MySQL DLL
    )
)

echo Qt build process completed successfully!
goto :eof

:SlashPath
setlocal
set "p=%~1"
set "p=%p:\=/%"
endlocal & set "%~2=%p%"
goto :eof