@echo off
@chcp 65001 > nul
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=5.15.17

:: 设置MinGW版本代号
SET MinGW_VERSION=mingw810_64

:: 设置编译器和Perl
echo Setting up MinGW and Perl environment...
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\Strawberry\c\bin;D:\a\QtBuild\Strawberry\perl\site\bin;D:\a\QtBuild\Strawberry\perl\bin;%PATH%

:: 验证工具
gcc --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: GCC not found
    exit /b 1
)

mingw32-make --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: mingw32-make not found
    exit /b 1
)

perl --version > nul 2>&1
IF ERRORLEVEL 1 (
    echo Error: Perl not found
    exit /b 1
)

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

:: 设置线程数
SET NUM_THRED=%NUMBER_OF_PROCESSORS%

:: 设置Qt源代码目录
SET SRC_QT=%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%

:: 补充设置qtbase\bin和gnuwin32\bin
SET PATH=%SRC_QT%\qtbase\bin;%SRC_QT%\gnuwin32\bin;%PATH%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-shared\%MinGW_VERSION%

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-shared-%MinGW_VERSION%

:: 显示配置信息
echo.
echo ================================
echo Qt5 Build Configuration
echo ================================
echo Qt Version: %QT_VERSION%
echo Compiler: MinGW 8.1.0 x64
echo Build Type: Shared Release
echo Threads: %NUM_THRED%
echo Source Dir: %SRC_QT%
echo Build Dir: %BUILD_DIR%
echo Install Dir: %INSTALL_DIR%
echo ================================
echo.

:: 根据需要进行全新构建
echo Cleaning previous build...
IF EXIST "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

:: 定位到构建目录
echo Creating build directory...
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

:: configure
echo Starting Qt configure...
call "%SRC_QT%\configure.bat" ^
    -shared ^
    -release ^
    -force-debug-info ^
    -separate-debug-info ^
    -prefix "%INSTALL_DIR%" ^
    -nomake examples ^
    -nomake tests ^
    -skip qtwebengine ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -schannel ^
    -opengl desktop ^
    -platform win32-g++ ^
    -silent

IF ERRORLEVEL 1 (
    echo Error: Configure failed
    exit /b 1
)

:: 编译
echo Starting build with %NUM_THRED% threads...
mingw32-make -j%NUM_THRED%
IF ERRORLEVEL 1 (
    echo Error: Build failed
    exit /b 1
)

:: 安装
echo Installing...
mingw32-make install
IF ERRORLEVEL 1 (
    echo Error: Install failed
    exit /b 1
)

:: 复制qt.conf
echo Copying qt.conf...
IF EXIST "%~dp0qt.conf" (
    copy "%~dp0qt.conf" "%INSTALL_DIR%\bin" > nul
)

:: 复制MinGW运行时库
echo Copying MinGW runtime libraries...
mkdir "%INSTALL_DIR%\redist" 2>nul
copy "D:\a\QtBuild\mingw64\bin\libgcc_s_seh-1.dll" "%INSTALL_DIR%\redist\" > nul 2>&1
copy "D:\a\QtBuild\mingw64\bin\libstdc++-6.dll" "%INSTALL_DIR%\redist\" > nul 2>&1
copy "D:\a\QtBuild\mingw64\bin\libwinpthread-1.dll" "%INSTALL_DIR%\redist\" > nul 2>&1

:: 创建环境设置脚本
echo Creating environment setup script...
(
echo @echo off
echo :: Qt5 MinGW Shared Environment Setup Script
echo SET QTDIR=%INSTALL_DIR%
echo SET PATH=%INSTALL_DIR%\bin;%%PATH%%
echo SET QT_PLUGIN_PATH=%INSTALL_DIR%\plugins
echo SET QML_IMPORT_PATH=%INSTALL_DIR%\qml
echo SET QML2_IMPORT_PATH=%INSTALL_DIR%\qml
echo echo Qt5 MinGW Shared environment set up for: %INSTALL_DIR%
echo echo Use windeployqt.exe to deploy applications
) > "%INSTALL_DIR%\setup_env.cmd"

:: 创建部署脚本
echo Creating deployment script...
(
echo @echo off
echo echo.
echo echo ===============================================
echo echo Qt5 MinGW Shared Library Deployment Guide
echo echo ===============================================
echo echo.
echo echo This Qt5 MinGW build requires runtime libraries:
echo echo.
echo echo Required Qt DLLs:
dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2>nul | findstr /v /i debug
echo echo.
echo echo Required MinGW Runtime:
echo echo - libgcc_s_seh-1.dll
echo echo - libstdc++-6.dll  
echo echo - libwinpthread-1.dll
echo echo ^(Located in: %INSTALL_DIR%\redist\^)
echo echo.
echo echo Deployment Steps:
echo echo 1. Use windeployqt.exe for automatic deployment:
echo echo    "%INSTALL_DIR%\bin\windeployqt.exe" your_app.exe
echo echo.
echo echo 2. Manual deployment - copy these files with your app:
echo echo    - Required Qt5*.dll files
echo echo    - Plugin directories: platforms, imageformats, etc.
echo echo    - MinGW runtime DLLs from redist folder
echo echo.
echo echo 3. Test on clean system without Qt/MinGW installed
echo echo.
echo echo Example windeployqt usage:
echo echo   cd your_app_directory
echo echo   "%INSTALL_DIR%\bin\windeployqt.exe" --release --no-translations your_app.exe
echo echo.
echo echo Note: MinGW builds are portable and don't require
echo echo       Visual C++ Redistributable installation
echo echo.
echo pause
) > "%INSTALL_DIR%\deployment_guide.cmd"

:: 创建库列表
echo Creating library listing...
echo Qt5 MinGW Dynamic Libraries: > "%INSTALL_DIR%\library_list.txt"
dir "%INSTALL_DIR%\lib\libQt5*.a" /b >> "%INSTALL_DIR%\library_list.txt" 2>nul
echo. >> "%INSTALL_DIR%\library_list.txt"
echo Qt5 DLL Files: >> "%INSTALL_DIR%\library_list.txt"
dir "%INSTALL_DIR%\bin\Qt5*.dll" /b >> "%INSTALL_DIR%\library_list.txt" 2>nul

:: 显示生成的库文件
echo.
echo Generated Qt libraries:
dir "%INSTALL_DIR%\lib\libQt5*.a" /b 2>nul
echo.
echo Generated Qt DLLs:
dir "%INSTALL_DIR%\bin\Qt5*.dll" /b 2>nul

:: 创建构建信息文件
echo Creating build info...
(
echo Qt5 Build Information
echo =====================
echo Qt Version: %QT_VERSION%
echo Compiler: MinGW 8.1.0 x64
echo Build Type: Shared Release ^(Dynamic^)
echo Build Date: %DATE% %TIME%
echo Install Path: %INSTALL_DIR%
echo Parallel Jobs: %NUM_THRED%
echo.
echo Configuration:
echo - Shared libraries ^(DLL^)
echo - Debug info separated
echo - Force debug info enabled
echo - OpenGL Desktop
echo - Schannel SSL
echo.
echo Runtime Requirements:
echo - MinGW runtime libraries ^(included in redist folder^)
echo - Windows 10/11 or Windows Server 2016+
echo - No Visual C++ Redistributable required
echo.
echo Deployment Tools:
echo - windeployqt.exe: %INSTALL_DIR%\bin\windeployqt.exe
echo - Runtime DLLs: %INSTALL_DIR%\redist\
echo - Setup script: %INSTALL_DIR%\setup_env.cmd
echo - Deploy guide: %INSTALL_DIR%\deployment_guide.cmd
echo.
echo Usage:
echo 1. Run setup_env.cmd to set environment
echo 2. Use windeployqt.exe for application deployment
echo 3. Include MinGW runtime from redist folder
echo.
echo Advantages of MinGW build:
echo - No MSVC runtime dependency
echo - Portable across Windows systems
echo - Smaller runtime footprint
echo.
echo Build completed successfully!
) > "%INSTALL_DIR%\build-info.txt"

echo.
echo ================================
echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%
echo.
echo Important Notes:
echo - This is a SHARED build - requires DLLs at runtime
echo - Run setup_env.cmd to set environment variables
echo - Use windeployqt.exe to deploy applications
echo - MinGW runtime libraries available in redist folder
echo - Check deployment_guide.cmd for detailed instructions
echo - No MSVC Redistributable required for MinGW builds
echo ================================

cd /d "%INSTALL_DIR%"