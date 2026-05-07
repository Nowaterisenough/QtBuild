Describe "build-qt6-native-windows_x86_64_mingw.cmd" {
    It "applies the QtWebEngine GN pool.h compatibility patch before configure" {
        $content = Get-Content "$PSScriptRoot/../Qt6Build/build-qt6-native-windows_x86_64_mingw.cmd" -Raw

        $content | Should Match 'Patch-QtWebEngineGnPool\.ps1'
        $content | Should Match '(?s)Patch-QtWebEngineGnPool\.ps1.*configure\.bat'
    }
}
