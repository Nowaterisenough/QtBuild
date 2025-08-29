@echo off
@chcp 65001
@cd /d %~dp0

REM 参数: Qt版本 GCC版本 BUILD_TYPE LINK_TYPE SEPARATE_DEBUG RUNTIME WITH_DEBUG_INFO TEST_MODE
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set RUNTIME=%6
set WITH_DEBUG_INFO=%7
set TEST_MODE=%8

if "%WITH_DEBUG_INFO%"=="" set WITH_DEBUG_INFO=false
if "%TEST_MODE%"=="" set TEST_MODE=false

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

echo ==== Qt Build ====
echo Qt %QT_VERSION%, GCC %GCC_VERSION%, %LINK_TYPE% %BUILD_TYPE%, sepdbg=%SEPARATE_DEBUG%, rt=%RUNTIME%, test=%TEST_MODE%

if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%TEMP_INSTALL_DIR%" rmdir /s /q "%TEMP_INSTALL_DIR%"
mkdir "%BUILD_DIR%"
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%BUILD_DIR%"

set "CFG=-%LINK_TYPE% -prefix %TEMP_INSTALL_DIR% -nomake examples -nomake tests -c++std c++20 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -platform win32-g++ -opengl desktop -sql-sqlite"

if /i "%TEST_MODE%"=="true" (
    set "CFG=%CFG% -submodules qtbase"
) else (
    set "CFG=%CFG% -skip qtwebengine"
)

if defined PostgreSQL_ROOT if exist "%PostgreSQL_ROOT%" (
    call :SlashPath "%PostgreSQL_ROOT%\include" PG_INC
    call :SlashPath "%PostgreSQL_ROOT%\lib" PG_LIB
    set "CFG=%CFG% -sql-psql"
    set "PostgreSQL_INCLUDE_DIRS=%PG_INC%"
    set "PostgreSQL_LIBRARY_DIRS=%PG_LIB%"
    if exist "%PostgreSQL_ROOT%\lib\libpq.lib" (set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\libpq.lib") else if exist "%PostgreSQL_ROOT%\lib\pq.lib" (set "PostgreSQL_LIBRARIES=%PostgreSQL_ROOT%\lib\pq.lib")
)

if defined MYSQL_ROOT if exist "%MYSQL_ROOT%" (
    call :SlashPath "%MYSQL_ROOT%\include" MY_INC
    call :SlashPath "%MYSQL_ROOT%\lib" MY_LIB
    set "CFG=%CFG% -sql-mysql"
    set "MySQL_INCLUDE_DIRS=%MY_INC%"
    set "MySQL_LIBRARY_DIRS=%MY_LIB%"
    if exist "%MYSQL_ROOT%\lib\libmysql.lib" (set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\libmysql.lib") else if exist "%MYSQL_ROOT%\lib\mysqlclient.lib" (set "MySQL_LIBRARIES=%MYSQL_ROOT%\lib\mysqlclient.lib")
)

if /i "%BUILD_TYPE%"=="debug" (
    set "CFG=%CFG% -debug"
) else (
    set "CFG=%CFG% -release"
)

set ADD_DEBUG_INFO=false
if /i "%WITH_DEBUG_INFO%"=="true" set ADD_DEBUG_INFO=true
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" set ADD_DEBUG_INFO=true
if /i "%ADD_DEBUG_INFO%"=="true" set "CFG=%CFG% -force-debug-info"
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" set "CFG=%CFG% -separate-debug-info"

echo Configure: %CFG%
call "%SRC_QT%\configure.bat" %CFG%
if errorlevel 1 (
    echo Configure failed.
    exit /b 1
)

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

echo Success. Installed: %FINAL_INSTALL_DIR%
if not exist "%FINAL_INSTALL_DIR%" exit /b 1
goto :eof

:SlashPath
setlocal
set "p=%~1"
set "p=%p:\=/%"
endlocal & set "%~2=%p%"
goto :eof