@chcp 65001
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=6.9.1

:: 设置MinGW版本代号
SET MinGW_VERSION=mingw1310_64

:: 设置编译器和Ninja
SET PATH=D:\a\QtBuild\Tools\mingw1310_64\bin;D:\a\QtBuild\ninja;%PATH%

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

::----------以下无需修改----------

:: 设置Qt源代码目录
SET SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"

:: 设置安装文件夹目录
SET INSTALL_DIR="%QT_PATH%\%QT_VERSION%-shared\%MinGW_VERSION%"

:: 设置build文件夹目录
SET BUILD_DIR="%QT_PATH%\%QT_VERSION%\build-shared-%MinGW_VERSION%"

:: 显示编译器版本信息
echo Using compiler:
gcc --version
g++ --version
echo.

:: 根据需要进行全新构建
rmdir /s /q "%BUILD_DIR%" 2>nul
:: 定位到构建目录：
mkdir "%BUILD_DIR%" && cd /d "%BUILD_DIR%"

:: configure for shared build
call %SRC_QT%\configure.bat ^
    -shared ^
    -release ^
    -force-debug-info ^
    -separate-debug-info ^
    -prefix %INSTALL_DIR% ^
    -nomake examples ^
    -nomake tests ^
    -c++std c++20 ^
    -headersclean ^
    -skip qtwebengine ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -schannel ^
    -platform win32-g++ ^
    -opengl desktop

:: 检查configure是否成功
if %errorlevel% neq 0 (
    echo Configure failed!
    exit /b %errorlevel%
)

:: 编译(不要忘记点)
echo Starting build...
cmake --build . --parallel

:: 检查编译是否成功
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

:: 安装(不要忘记点)
echo Installing...
cmake --install .

:: 检查安装是否成功
if %errorlevel% neq 0 (
    echo Install failed!
    exit /b %errorlevel%
)

:: 复制qt.conf
copy %~dp0\qt.conf %INSTALL_DIR%\bin

:: 复制MinGW运行时库到bin目录
echo Copying MinGW runtime libraries...
copy D:\a\QtBuild\Tools\mingw1310_64\bin\libgcc_s_seh-1.dll %INSTALL_DIR%\bin\ 2>nul
copy D:\a\QtBuild\Tools\mingw1310_64\bin\libstdc++-6.dll %INSTALL_DIR%\bin\ 2>nul
copy D:\a\QtBuild\Tools\mingw1310_64\bin\libwinpthread-1.dll %INSTALL_DIR%\bin\ 2>nul

:: 列出生成的动态库
echo.
echo Generated Qt libraries:
dir /b %INSTALL_DIR%\bin\Qt6*.dll

echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%

::@pause
@cmd /k cd /d %INSTALL_DIR%