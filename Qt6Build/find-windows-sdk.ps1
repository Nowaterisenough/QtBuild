# find-windows-sdk.ps1
param(
    [string]$OutputBatch
)

$ErrorActionPreference = "SilentlyContinue"

# 查找Windows SDK
$sdkRoot = $null
$sdkVersion = $null

# 尝试从注册表获取
try {
    $regKey = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" -Name "InstallationFolder" 2>$null
    if ($regKey) {
        $sdkRoot = $regKey.InstallationFolder
    }
} catch {}

if (-not $sdkRoot) {
    try {
        $regKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" -Name "InstallationFolder" 2>$null
        if ($regKey) {
            $sdkRoot = $regKey.InstallationFolder
        }
    } catch {}
}

# 如果注册表失败，尝试常见路径
if (-not $sdkRoot) {
    $commonPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10",
        "${env:ProgramFiles}\Windows Kits\10"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\Include") {
            $sdkRoot = $path
            break
        }
    }
}

# 查找SDK版本
if ($sdkRoot) {
    $includePath = Join-Path $sdkRoot "Include"
    if (Test-Path $includePath) {
        $versions = Get-ChildItem $includePath -Directory | 
                   Where-Object { $_.Name -like "10.*" } | 
                   Sort-Object Name -Descending
        
        if ($versions) {
            $sdkVersion = $versions[0].Name
        }
    }
}

# 输出结果到批处理文件
$batchContent = @"
@echo off
"@

if ($sdkRoot -and $sdkVersion) {
    $sdkRoot = $sdkRoot.TrimEnd('\')
    $batchContent += @"
set "WINDOWS_SDK_ROOT=$sdkRoot"
set "WINDOWS_SDK_VERSION=$sdkVersion"
set "WINDOWS_SDK_INCLUDE=$sdkRoot\Include\$sdkVersion"
set "WINDOWS_SDK_LIB=$sdkRoot\Lib\$sdkVersion"
set "INCLUDE=$sdkRoot\Include\$sdkVersion\um;$sdkRoot\Include\$sdkVersion\shared;$sdkRoot\Include\$sdkVersion\winrt;$sdkRoot\Include\$sdkVersion\ucrt"
set "LIB=$sdkRoot\Lib\$sdkVersion\um\x64;$sdkRoot\Lib\$sdkVersion\ucrt\x64"
set "LIBPATH=$sdkRoot\Lib\$sdkVersion\um\x64;$sdkRoot\Lib\$sdkVersion\ucrt\x64"
echo Windows SDK $sdkVersion found at $sdkRoot
exit /b 0
"@
} else {
    $batchContent += @"
echo ERROR: Windows SDK not found
exit /b 1
"@
}

$batchContent | Out-File -FilePath $OutputBatch -Encoding ASCII