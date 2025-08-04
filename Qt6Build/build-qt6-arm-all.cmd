@echo off
@chcp 65001

echo ====================================
echo Qt6 ARM交叉编译构建工具
echo ====================================
echo.

if "%1"=="" goto show_usage

REM 参数解析
set QT_VERSION=%1
set GCC_VERSION=%2
set BUILD_TYPE=%3
set LINK_TYPE=%4
set SEPARATE_DEBUG=%5
set ARM_ARCH=%6

REM 参数验证
if "%QT_VERSION%"=="" goto show_usage
if "%GCC_VERSION%"=="" goto show_usage
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release
if "%LINK_TYPE%"=="" set LINK_TYPE=static
if "%SEPARATE_DEBUG%"=="" set SEPARATE_DEBUG=false
if "%ARM_ARCH%"=="" set ARM_ARCH=aarch64

REM 显示构建信息
echo 构建配置:
echo   Qt版本: %QT_VERSION%
echo   GCC版本: %GCC_VERSION%
echo   构建类型: %BUILD_TYPE%
echo   链接类型: %LINK_TYPE%
echo   分离调试信息: %SEPARATE_DEBUG%
echo   ARM架构: %ARM_ARCH%
echo.

REM 根据ARM架构选择相应的构建脚本
if /i "%ARM_ARCH%"=="aarch64" (
    echo 使用AArch64构建脚本...
    call %~dp0build-qt6-arm64_aarch64_gcc.cmd %QT_VERSION% %GCC_VERSION% %BUILD_TYPE% %LINK_TYPE% %SEPARATE_DEBUG% %ARM_ARCH%
) else if /i "%ARM_ARCH%"=="armv7l" (
    echo 使用ARM32构建脚本...
    call %~dp0build-qt6-arm32_armv7l_gcc.cmd %QT_VERSION% %GCC_VERSION% %BUILD_TYPE% %LINK_TYPE% %SEPARATE_DEBUG% %ARM_ARCH%
) else if /i "%ARM_ARCH%"=="armv6l" (
    echo 使用ARM32构建脚本...
    call %~dp0build-qt6-arm32_armv7l_gcc.cmd %QT_VERSION% %GCC_VERSION% %BUILD_TYPE% %LINK_TYPE% %SEPARATE_DEBUG% %ARM_ARCH%
) else (
    echo 错误: 不支持的ARM架构 '%ARM_ARCH%'
    echo 支持的架构: aarch64, armv7l, armv6l
    exit /b 1
)

if %errorlevel% neq 0 (
    echo.
    echo 构建失败！错误码: %errorlevel%
    exit /b %errorlevel%
)

echo.
echo ====================================
echo Qt6 ARM交叉编译构建完成！
echo ====================================
goto end

:show_usage
echo 用法: %0 ^<Qt版本^> ^<GCC版本^> [构建类型] [链接类型] [分离调试信息] [ARM架构]
echo.
echo 参数说明:
echo   Qt版本        : Qt版本号，如 6.9.1
echo   GCC版本       : GCC版本号，如 13.2.0
echo   构建类型      : release 或 debug (默认: release)
echo   链接类型      : static 或 shared (默认: static)
echo   分离调试信息  : true 或 false (默认: false)
echo   ARM架构       : aarch64, armv7l, 或 armv6l (默认: aarch64)
echo.
echo 示例:
echo   %0 6.9.1 13.2.0
echo   %0 6.9.1 13.2.0 release static false aarch64
echo   %0 6.9.1 13.2.0 debug shared true armv7l
echo.
echo 支持的ARM架构:
echo   aarch64  - ARM64架构 (树莓派4+, Jetson系列)
echo   armv7l   - ARM32v7架构 (树莓派2/3, BeagleBone)
echo   armv6l   - ARM32v6架构 (树莓派1)
echo.
echo 注意: 请确保已安装相应的ARM GCC交叉编译工具链

:end
