@echo off
@chcp 65001 > nul
@cd /d %~dp0

REM Args: Qt version, Emscripten version, build type, link type
set QT_VERSION=%1
set EMSCRIPTEN_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4

if "%QT_VERSION%"=="" (
    echo Error: Qt version is required
    echo Usage: %0 QT_VERSION EMSCRIPTEN_VERSION BUILD_TYPE LINK_TYPE
    echo Example: %0 6.9.2 latest release static
    exit /b 1
)
if "%EMSCRIPTEN_VERSION%"=="" set EMSCRIPTEN_VERSION=latest
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release
if "%LINK_TYPE%"=="" set LINK_TYPE=static

set REQUESTED_EMSCRIPTEN_VERSION=%EMSCRIPTEN_VERSION%
set RESOLVED_EMSCRIPTEN_VERSION=%EMSCRIPTEN_VERSION%

if /I "%REQUESTED_EMSCRIPTEN_VERSION%"=="latest" (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Resolve-EmsdkVersion.ps1" -Version "%REQUESTED_EMSCRIPTEN_VERSION%"`) do (
        set RESOLVED_EMSCRIPTEN_VERSION=%%i
    )
    if not defined RESOLVED_EMSCRIPTEN_VERSION (
        echo Failed to resolve the latest Emscripten version.
        exit /b 1
    )
)

set WASM_VERSION=wasm32_emscripten

echo =====================================
echo Qt WebAssembly Build Configuration
echo =====================================
echo Qt Version: %QT_VERSION%
echo WASM Version: %WASM_VERSION%
echo Requested Emscripten Version: %REQUESTED_EMSCRIPTEN_VERSION%
echo Resolved Emscripten Version: %RESOLVED_EMSCRIPTEN_VERSION%
echo Build Type: %BUILD_TYPE%
echo Link Type: %LINK_TYPE%
echo =====================================

set EMSDK_ROOT=D:\a\QtBuild\emsdk
echo Setting up Emscripten environment...
call "%EMSDK_ROOT%\emsdk_env.bat"

set PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%
set QT_PATH=D:\a\QtBuild\Qt
set SHORT_BUILD_PATH=D:\a\QtBuild\build
set TEMP_INSTALL_DIR=D:\a\QtBuild\temp_install

set SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"
set HOST_QT_DIR="%QT_PATH%\%QT_VERSION%-host"
set FINAL_INSTALL_DIR="%QT_PATH%\%QT_VERSION%-%LINK_TYPE%-%WASM_VERSION%"
set BUILD_DIR="%SHORT_BUILD_PATH%"

echo.
echo ================================
echo Qt6 WebAssembly Build Configuration
echo ================================
echo Qt Version: %QT_VERSION%
echo Platform: WebAssembly (Emscripten %RESOLVED_EMSCRIPTEN_VERSION%)
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Source Dir: %SRC_QT%
echo Build Dir: %BUILD_DIR%
echo Install Dir: %FINAL_INSTALL_DIR%
echo Host Qt Dir: %HOST_QT_DIR%
echo ================================
echo.

echo Cleaning previous build...
rmdir /s /q %BUILD_DIR% 2>nul
rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
mkdir "%SHORT_BUILD_PATH%"
mkdir "%TEMP_INSTALL_DIR%"
cd /d "%SHORT_BUILD_PATH%"

set CFG_OPTIONS=-prefix %TEMP_INSTALL_DIR% -platform wasm-emscripten -no-warnings-are-errors -qt-host-path %HOST_QT_DIR% -nomake examples -nomake tests -submodules qtbase,qtdeclarative -c++std c++20 -opensource -confirm-license -qt-libpng -qt-libjpeg -qt-zlib -qt-pcre -qt-freetype -no-dbus -feature-thread

if "%LINK_TYPE%"=="static" (
    set CFG_OPTIONS=%CFG_OPTIONS% -static
) else if "%LINK_TYPE%"=="shared" (
    set CFG_OPTIONS=%CFG_OPTIONS% -shared
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -static
)

if "%BUILD_TYPE%"=="debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug -force-debug-info
    echo Building DEBUG version for WebAssembly...
    echo WARNING: Debug builds are significantly larger and slower
) else if "%BUILD_TYPE%"=="release-and-debug" (
    set CFG_OPTIONS=%CFG_OPTIONS% -debug-and-release
    echo Building RELEASE-AND-DEBUG version for WebAssembly...
) else (
    set CFG_OPTIONS=%CFG_OPTIONS% -release
    echo Building RELEASE version for WebAssembly...
)

echo Configure options: %CFG_OPTIONS%

echo Starting Qt configure...
call %SRC_QT%\configure.bat %CFG_OPTIONS%
if %errorlevel% neq 0 (
    echo Configure failed with error code: %errorlevel%
    exit /b %errorlevel%
)

echo Starting build...
if "%BUILD_TYPE%"=="debug" (
    cmake --build . --parallel 2
) else (
    cmake --build . --parallel 4
)
if %errorlevel% neq 0 (
    echo Build failed with error code: %errorlevel%
    exit /b %errorlevel%
)

echo Installing to temporary directory...
cmake --install .
if %errorlevel% neq 0 (
    echo Install failed with error code: %errorlevel%
    exit /b %errorlevel%
)

mkdir "%QT_PATH%\%QT_VERSION%-%LINK_TYPE%" 2>nul

echo Moving files to final directory...
move "%TEMP_INSTALL_DIR%" %FINAL_INSTALL_DIR%
if %errorlevel% neq 0 (
    echo Failed to move to final directory with error code: %errorlevel%
    echo Trying to copy instead...
    xcopy "%TEMP_INSTALL_DIR%\*" %FINAL_INSTALL_DIR%\ /E /I /H /Y
    if %errorlevel% neq 0 (
        echo Copy also failed with error code: %errorlevel%
        exit /b %errorlevel%
    )
    rmdir /s /q %TEMP_INSTALL_DIR% 2>nul
)

if exist %~dp0\qt.conf (
    copy %~dp0\qt.conf %FINAL_INSTALL_DIR%\bin\ > nul
)

echo Creating build info...
(
echo Qt6 WebAssembly Build Information
echo ==================================
echo Qt Version: %QT_VERSION%
echo Requested Emscripten Version: %REQUESTED_EMSCRIPTEN_VERSION%
echo Platform: WebAssembly ^(Emscripten %RESOLVED_EMSCRIPTEN_VERSION%^)
echo Build Type: %LINK_TYPE% %BUILD_TYPE%
echo Build Date: %DATE% %TIME%
echo Install Path: %FINAL_INSTALL_DIR%
echo Host Qt Path: %HOST_QT_DIR%
echo.
if "%BUILD_TYPE%"=="debug" (
  echo NOTE: This is a DEBUG build for WebAssembly
  echo - WASM files will be significantly larger
  echo - Runtime performance will be reduced
  echo - Recommended for development and debugging only
  echo - Use release builds for production deployment
  echo.
)
if "%BUILD_TYPE%"=="release-and-debug" (
  echo NOTE: This build includes both RELEASE and DEBUG versions
  echo - Use debug version for development
  echo - Use release version for production
  echo.
)
echo Build completed successfully!
) > %FINAL_INSTALL_DIR%\build-info.txt

echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%

if exist %FINAL_INSTALL_DIR% (
    echo Final installation directory verified.
    echo.
    echo Directory contents:
    dir %FINAL_INSTALL_DIR%
    echo.
    if "%BUILD_TYPE%"=="debug" (
        echo DEBUG BUILD NOTES:
        echo - The generated WASM files will be much larger than release builds
        echo - Loading and execution will be slower in browsers
        echo - Use this build for development and debugging purposes only
        echo.
    )
) else (
    echo Error: Final installation directory does not exist!
    exit /b 1
)

echo.
echo ================================
echo Build completed successfully!
echo Installation directory: %FINAL_INSTALL_DIR%
echo ================================
