Describe "build-qt6-native-windows_x86_64_llvm_matrix.yml" {
    It "excludes the unsupported shared debug matrix entry" {
        $content = Get-Content "$PSScriptRoot/../.github/workflows/build-qt6-native-windows_x86_64_llvm_matrix.yml" -Raw

        $content | Should Match "(?s)exclude:\s+.*?link_type:\s+shared\s+build_type:\s+debug"
    }
}
