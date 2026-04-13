Describe "build-qt6-native-windows_x86_64_msvc.cmd" {
    It "applies a VS2026 warning compatibility flag for Qt 6.11 builds" {
        $content = Get-Content "$PSScriptRoot/../Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd" -Raw

        $content | Should Match 'if /i "%COMPILER_VERSION%"=="2026"'
        $content | Should Match '/Wv:18'
    }
}
