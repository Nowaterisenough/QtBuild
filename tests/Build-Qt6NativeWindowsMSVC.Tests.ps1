Describe "build-qt6-native-windows_x86_64_msvc.cmd" {
    It "applies a VS2026 warning compatibility flag for Qt 6.11 builds" {
        $content = Get-Content "$PSScriptRoot/../Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd" -Raw

        $content | Should Match 'if /i "%COMPILER_VERSION%"=="2026"'
        $content | Should Match '/Wv:18'
    }

    It "checks compiler availability via PATH lookup instead of invoking cl directly" {
        $content = Get-Content "$PSScriptRoot/../Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd" -Raw

        $content | Should Match 'where cl >nul 2>nul \|\| \('
        $content | Should Not Match '(^|\r?\n)cl 2>nul \|\| \('
    }

    It "applies VS2026 compatibility flags through a helper routine" {
        $content = Get-Content "$PSScriptRoot/../Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd" -Raw

        $content | Should Match 'call :apply_msvc_compat_flags'
        $content | Should Match ':apply_msvc_compat_flags'
    }
}
