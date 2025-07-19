@chcp 65001
@cd /d %~dp0

:: 设置Qt版本
SET QT_VERSION=6.9.1

:: 设置WASM版本代号
SET WASM_VERSION=wasm32_emscripten

:: 设置Emscripten版本
SET EMSCRIPTEN_VERSION=3.1.70

:: 设置Emscripten SDK路径并激活环境
SET EMSDK_ROOT=D:\a\QtBuild\emsdk
call "%EMSDK_ROOT%\emsdk_env.bat"

:: 设置工具路径（MinGW用于一些工具，Ninja用于构建）
SET PATH=D:\a\QtBuild\mingw64\bin;D:\a\QtBuild\ninja;%PATH%

:: 设置Qt文件夹路径
SET QT_PATH=D:\a\QtBuild\Qt

::----------以下无需修改----------

:: 设置Qt源代码目录
SET SRC_QT="%QT_PATH%\%QT_VERSION%\qt-everywhere-src-%QT_VERSION%"

:: 设置安装文件夹目录
SET INSTALL_DIR="%QT_PATH%\%QT_VERSION%-static\%WASM_VERSION%"

:: 设置build文件夹目录
SET BUILD_DIR="%QT_PATH%\%QT_VERSION%\build-%WASM_VERSION%"

:: 显示编译器版本信息
echo Using Emscripten:
emcc --version
echo.

:: 验证Emscripten环境
echo Checking Emscripten environment:
echo EMSDK: %EMSDK%
echo EMSCRIPTEN: %EMSCRIPTEN%
echo.

:: 根据需要进行全新构建
rmdir /s /q "%BUILD_DIR%" 2>nul
:: 定位到构建目录：
mkdir "%BUILD_DIR%" && cd /d "%BUILD_DIR%"

:: configure for WebAssembly
call %SRC_QT%\configure.bat ^
    -static ^
    -release ^
    -prefix %INSTALL_DIR% ^
    -platform wasm-emscripten ^
    -nomake examples ^
    -nomake tests ^
    -skip qtwebengine ^
    -skip qtmultimedia ^
    -skip qtwebchannel ^
    -skip qtwebsockets ^
    -skip qtpositioning ^
    -skip qtsensors ^
    -skip qtserialport ^
    -skip qtserialbus ^
    -skip qtlocation ^
    -skip qtcharts ^
    -skip qtdatavis3d ^
    -skip qtlottie ^
    -skip qtquick3d ^
    -skip qtremoteobjects ^
    -skip qtscxml ^
    -skip qtvirtualkeyboard ^
    -skip qtwayland ^
    -skip qtwebview ^
    -opensource ^
    -confirm-license ^
    -qt-libpng ^
    -qt-libjpeg ^
    -qt-zlib ^
    -qt-pcre ^
    -qt-freetype ^
    -no-feature-thread ^
    -no-dbus ^
    -no-ssl ^
    -no-pch

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

echo Build completed successfully!
echo Installation directory: %INSTALL_DIR%

::@pause
@cmd /k cd /d %INSTALL_DIR%