Describe "Resolve-VsInstall" {
    BeforeEach {
        $script:roots = @{
            "2026" = Join-Path $TestDrive "VS2026"
            "2022" = Join-Path $TestDrive "VS2022"
            "2019" = Join-Path $TestDrive "VS2019"
        }

        . "$PSScriptRoot/../scripts/Resolve-VsInstall.ps1"
    }

    It "resolves the preferred edition for VS2026" {
        $vcvars = Join-Path $script:roots["2026"] "Enterprise/VC/Auxiliary/Build/vcvarsall.bat"
        $redist = Join-Path $script:roots["2026"] "Enterprise/VC/Redist/MSVC"

        New-Item -ItemType Directory -Force -Path (Split-Path $vcvars), $redist | Out-Null
        Set-Content -Path $vcvars -Value "@echo off"

        $result = Resolve-VsInstall -Version "2026" -PreferredEdition "Enterprise" -Roots $script:roots

        $result.VersionCode | Should Be "msvc2026_64"
        $result.VcvarsPath | Should Be $vcvars
        $result.RedistPath | Should Be $redist
    }

    It "falls back to another edition when the preferred edition is missing" {
        $vcvars = Join-Path $script:roots["2022"] "Community/VC/Auxiliary/Build/vcvarsall.bat"
        $redist = Join-Path $script:roots["2022"] "Community/VC/Redist/MSVC"

        New-Item -ItemType Directory -Force -Path (Split-Path $vcvars), $redist | Out-Null
        Set-Content -Path $vcvars -Value "@echo off"

        $result = Resolve-VsInstall -Version "2022" -PreferredEdition "Enterprise" -Roots $script:roots

        $result.Edition | Should Be "Community"
        $result.VersionCode | Should Be "msvc2022_64"
    }

    It "throws for unsupported versions" {
        { Resolve-VsInstall -Version "2017" -Roots $script:roots } | Should Throw "Unsupported MSVC version: 2017"
    }
}
