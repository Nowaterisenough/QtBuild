@echo off
@chcp 65001 >nul
setlocal enableextensions

REM ============================================================================
REM Qt 6 Windows MinGW Build Script
REM Parameters: QT_VERSION COMPILER_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG VULKAN_SDK TEST_MODE RUNTIME
REM ============================================================================

REM === Parameter Extraction ===
set "QT_VERSION=%~1"
set "COMPILER_VERSION=%~2"
set "BUILD_TYPE=%~3"
set "LINK_TYPE=%~4"
set "SEPARATE_DEBUG=%~5"
set "VULKAN_SDK=%~6"
set "TEST_MODE=%~7"
set "RUNTIME=%~8"

REM === Parameter Validation ===
if "%QT_VERSION%"=="" (
    echo ERROR: QT_VERSION not provided
    exit /b 1
)
if "%COMPILER_VERSION%"=="" (
    echo ERROR: COMPILER_VERSION not provided
    exit /b 1
)
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=release"
if "%LINK_TYPE%"=="" set "LINK_TYPE=shared"
if "%SEPARATE_DEBUG%"=="" set "SEPARATE_DEBUG=false"
if "%VULKAN_SDK%"=="" set "VULKAN_SDK=none"
if "%TEST_MODE%"=="" set "TEST_MODE=false"
if "%RUNTIME%"=="" set "RUNTIME=ucrt"

REM === MinGW Version String ===
if /i "%RUNTIME%"=="ucrt" (
    set "MinGW_VERSION=mingw%COMPILER_VERSION:_=%%_64_UCRT"
) else (
    set "MinGW_VERSION=mingw%COMPILER_VERSION:_=%%_64_MSVCRT"
)

REM === Environment Setup ===
set "PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;D:\a\QtBuild\protoc\bin;%PATH%"

gcc --version | findstr "gcc" || (
    echo ERROR: GCC compiler not found
    exit /b 1
)

REM === Path Setup ===
set "QT_PATH=D:\a\QtBuild\Qt"
set "BUILD_DIR=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%MinGW_VERSION%"

echo === Qt %QT_VERSION% MinGW %COMPILER_VERSION% Build ===
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo Runtime: %RUNTIME%
echo Test Mode: %TEST_MODE%
echo Vulkan: %VULKAN_SDK%
echo Install: %FINAL_INSTALL_DIR%

REM === Directory Preparation ===
rmdir /s /q "%BUILD_DIR%" 2>nul
rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
mkdir "%BUILD_DIR%" || exit /b 1
mkdir "%TEMP_INSTALL_DIR%" || exit /b 1
cd /d "%BUILD_DIR%" || exit /b 1

REM === Base Configuration ===
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -nomake examples -nomake tests -c++std c++23 -headersclean -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -schannel -opengl desktop -platform win32-g++ -feature-backtrace"

REM === Module Selection ===
if /i "%TEST_MODE%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -submodules qtbase"
    echo Module: qtbase only
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -skip qtwebengine"
    echo Module: all except qtwebengine
)

REM === Build Type Configuration ===
if /i "%BUILD_TYPE%"=="debug" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -debug"
) else (
    set "CFG_OPTIONS=%CFG_OPTIONS% -release"
)

REM === Debug Info Configuration ===
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
)

REM === Vulkan Configuration ===
if /i "%VULKAN_SDK%"=="none" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -no-feature-vulkan"
    echo Vulkan: disabled
) else (
    echo Vulkan: enabled (runtime)
)

REM === SQL Driver Configuration (only non-test mode) ===
if /i "%TEST_MODE%"=="false" (
    REM SQLite is built-in
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-sqlite"

    REM PostgreSQL
    if not defined PostgreSQL_ROOT (
        echo ERROR: PostgreSQL_ROOT not defined
        exit /b 1
    )
    if not exist "%PostgreSQL_ROOT%" (
        echo ERROR: PostgreSQL_ROOT not found: %PostgreSQL_ROOT%
        exit /b 1
    )
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-psql"
    set "PostgreSQL_INCLUDE_DIRS=%PostgreSQL_ROOT%/include"
    set "PostgreSQL_LIBRARY_DIRS=%PostgreSQL_ROOT%/lib"
    echo SQL: SQLite + PostgreSQL

    REM MySQL
    if not defined MYSQL_ROOT (
        echo ERROR: MYSQL_ROOT not defined
        exit /b 1
    )
    if not exist "%MYSQL_ROOT%" (
        echo ERROR: MYSQL_ROOT not found: %MYSQL_ROOT%
        exit /b 1
    )
    set "CFG_OPTIONS=%CFG_OPTIONS% -sql-mysql"
    set "MySQL_INCLUDE_DIRS=%MYSQL_ROOT%/include"
    set "MySQL_LIBRARY_DIRS=%MYSQL_ROOT%/lib"
    echo SQL: SQLite + PostgreSQL + MySQL
)

echo Configure: %CFG_OPTIONS%

REM === Configure ===
call "%SRC_QT%\configure.bat" %CFG_OPTIONS% || exit /b 1

REM === Build ===
cmake --build . --parallel 4 || exit /b 1

REM === Install ===
cmake --install . || exit /b 1

REM === Move to Final Directory ===
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul || (
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul || exit /b 1
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM === Copy qt.conf ===
if exist "%~dp0qt.conf" copy "%~dp0qt.conf" "%FINAL_INSTALL_DIR%\bin\" >nul

REM === Copy Runtime DLLs (only shared) ===
if /i "%LINK_TYPE%"=="shared" (
    if not exist "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" (
        echo ERROR: libgcc_s_seh-1.dll not found
        exit /b 1
    )
    copy "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    if not exist "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" (
        echo ERROR: libstdc++-6.dll not found
        exit /b 1
    )
    copy "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    if not exist "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" (
        echo ERROR: libwinpthread-1.dll not found
        exit /b 1
    )
    copy "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    echo DLLs: MinGW runtime copied

    REM === Copy SQL DLLs (only non-test) ===
    if /i "%TEST_MODE%"=="false" (
        if not exist "%PostgreSQL_ROOT%\bin\libpq.dll" (
            echo ERROR: libpq.dll not found: %PostgreSQL_ROOT%\bin\libpq.dll
            exit /b 1
        )
        copy "%PostgreSQL_ROOT%\bin\libpq.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

        if not exist "%MYSQL_ROOT%\lib\libmysql.dll" (
            echo ERROR: libmysql.dll not found: %MYSQL_ROOT%\lib\libmysql.dll
            exit /b 1
        )
        copy "%MYSQL_ROOT%\lib\libmysql.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

        echo DLLs: libpq.dll + libmysql.dll copied
    )
)

echo === Build Completed ===
echo Install: %FINAL_INSTALL_DIR%
if /i "%TEST_MODE%"=="true" echo NOTE: Test mode - qtbase only
