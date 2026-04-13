function Resolve-VsInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Version,

        [string] $PreferredEdition,

        [hashtable] $Roots
    )

    $versionRoots = @{
        "2019" = ${env:ProgramFiles(x86)}
        "2022" = ${env:ProgramFiles}
        "2026" = ${env:ProgramFiles}
    }

    if (-not $versionRoots.ContainsKey($Version)) {
        throw "Unsupported MSVC version: $Version"
    }

    $editions = @("Enterprise", "Professional", "Community", "BuildTools")
    if ($PreferredEdition) {
        $editions = @($PreferredEdition) + ($editions | Where-Object { $_ -ne $PreferredEdition })
    }

    if ($Roots -and $Roots.ContainsKey($Version)) {
        $vsRoot = $Roots[$Version]
    } else {
        $vsRoot = Join-Path $versionRoots[$Version] "Microsoft Visual Studio\$Version"
    }

    foreach ($edition in $editions) {
        $editionRoot = Join-Path $vsRoot $edition
        $vcvarsPath = Join-Path $editionRoot "VC/Auxiliary/Build/vcvarsall.bat"
        $redistPath = Join-Path $editionRoot "VC/Redist/MSVC"

        if ((Test-Path $vcvarsPath) -and (Test-Path $redistPath)) {
            return @{
                Version = $Version
                Edition = $edition
                VcvarsPath = $vcvarsPath
                RedistPath = $redistPath
                VersionCode = "msvc${Version}_64"
            }
        }
    }

    throw "Visual Studio $Version not found under $vsRoot"
}
