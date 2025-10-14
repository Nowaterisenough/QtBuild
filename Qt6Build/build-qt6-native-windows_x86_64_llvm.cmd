@echo off
@chcp 65001 >nul
setlocal enableextensions disabledelayedexpansion

REM ============================================================================
REM Qt 6 Windows LLVM Build Script
REM Parameters: QT_VERSION COMPILER_VERSION BUILD_TYPE LINK_TYPE SEPARATE_DEBUG VULKAN_SDK TEST_MODE RUNTIME BIN_PATH VERSION_CODE
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
set "BIN_PATH=%~9"
shift
set "VERSION_CODE=%~9"

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
if "%BIN_PATH%"=="" (
    echo ERROR: BIN_PATH not provided
    exit /b 1
)
if "%VERSION_CODE%"=="" (
    echo ERROR: VERSION_CODE not provided
    exit /b 1
)

REM === Environment Setup ===
set "PATH=%BIN_PATH%;D:\a\QtBuild\ninja;C:\Windows\System32;C:\Windows;C:\Program Files\Git\bin;C:\Program Files\CMake\bin"

clang --version | findstr "clang version" || (
    echo ERROR: Clang compiler not found
    exit /b 1
)

REM === Compiler Environment ===
set "CC=clang"
set "CXX=clang++"
set "AR=llvm-ar"
set "RANLIB=llvm-ranlib"

REM Derive MinGW root for RC
for %%I in ("%BIN_PATH%\..") do set "MINGW_ROOT=%%~fI"
set "RC=%BIN_PATH%\llvm-rc.exe"
for %%I in ("%RC%") do set "RC=%%~sI"

REM === Path Setup ===
set "QT_PATH=D:\a\QtBuild\Qt"
set "BUILD_DIR=D:\a\QtBuild\build"
set "TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install"
set "SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set "FINAL_INSTALL_DIR=%QT_PATH%\%QT_VERSION%-%LINK_TYPE%\%VERSION_CODE%"

echo === Qt %QT_VERSION% LLVM %COMPILER_VERSION% Build ===
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
set "CFG_OPTIONS=-%LINK_TYPE% -prefix "%TEMP_INSTALL_DIR%" -platform win32-clang-g++ -nomake examples -nomake tests -c++std c++23 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -schannel -opengl desktop"

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

REM === Static Runtime ===
if /i "%LINK_TYPE%"=="static" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -static-runtime"
)

REM === Debug Info Configuration ===
if /i "%LINK_TYPE%"=="shared" if /i "%SEPARATE_DEBUG%"=="true" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -force-debug-info -separate-debug-info"
)

REM === Headers Clean (version specific) ===
if "%COMPILER_VERSION%"=="17.0" (
    set "CFG_OPTIONS=%CFG_OPTIONS% -headersclean"
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
call "%SRC_QT%\configure.bat" %CFG_OPTIONS% -- -DCMAKE_RC_COMPILER:FILEPATH="%RC%" || exit /b 1

REM === Build ===
echo Building with 2 parallel jobs...
cmake --build . --parallel 2 || (
    echo Parallel build failed, trying single-threaded...
    cmake --build . --parallel 1 || exit /b 1
)

REM === Install ===
cmake --install . || exit /b 1

REM === Move to Final Directory ===
mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul
move "%TEMP_INSTALL_DIR%" "%FINAL_INSTALL_DIR%" >nul || (
    xcopy "%TEMP_INSTALL_DIR%\*" "%FINAL_INSTALL_DIR%\" /E /I /H /Y >nul || exit /b 1
    rmdir /s /q "%TEMP_INSTALL_DIR%" 2>nul
)

REM === Copy Runtime DLLs (only shared) ===
if /i "%LINK_TYPE%"=="shared" (
    if not exist "%BIN_PATH%\libc++.dll" (
        echo ERROR: libc++.dll not found: %BIN_PATH%\libc++.dll
        exit /b 1
    )
    copy "%BIN_PATH%\libc++.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    if not exist "%BIN_PATH%\libunwind.dll" (
        echo ERROR: libunwind.dll not found: %BIN_PATH%\libunwind.dll
        exit /b 1
    )
    copy "%BIN_PATH%\libunwind.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    if not exist "%BIN_PATH%\libwinpthread-1.dll" (
        echo ERROR: libwinpthread-1.dll not found: %BIN_PATH%\libwinpthread-1.dll
        exit /b 1
    )
    copy "%BIN_PATH%\libwinpthread-1.dll" "%FINAL_INSTALL_DIR%\bin\" || exit /b 1

    echo DLLs: LLVM runtime copied

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
