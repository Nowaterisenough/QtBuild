function Resolve-VsInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Version,

        [string] $PreferredEdition,

        [hashtable] $Roots
    )

    $versionRoots = @{
        "2019" = @{
            BasePath = ${env:ProgramFiles(x86)}
            InstallFolders = @("2019", "16")
            VsWhereRange = "[16.0,17.0)"
        }
        "2022" = @{
            BasePath = ${env:ProgramFiles}
            InstallFolders = @("2022", "17")
            VsWhereRange = "[17.0,18.0)"
        }
        "2026" = @{
            BasePath = ${env:ProgramFiles}
            InstallFolders = @("2026", "18")
            VsWhereRange = "[18.0,19.0)"
        }
    }

    if (-not $versionRoots.ContainsKey($Version)) {
        throw "Unsupported MSVC version: $Version"
    }

    $editions = @("Enterprise", "Professional", "Community", "BuildTools")
    if ($PreferredEdition) {
        $editions = @($PreferredEdition) + ($editions | Where-Object { $_ -ne $PreferredEdition })
    }

    $vsConfig = $versionRoots[$Version]
    $candidateRoots = @()

    if ($Roots) {
        foreach ($folder in @($Version) + $vsConfig.InstallFolders) {
            if ($Roots.ContainsKey($folder)) {
                $candidateRoots += $Roots[$folder]
            }
        }
    } else {
        $vsWherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vsWherePath) {
            $vsWhereResult = & $vsWherePath -products * -version $vsConfig.VsWhereRange -latest -property installationPath 2>$null
            if ($LASTEXITCODE -eq 0 -and $vsWhereResult) {
                $candidateRoots += $vsWhereResult.Trim()
            }
        }

        foreach ($folder in $vsConfig.InstallFolders) {
            $candidateRoots += Join-Path $vsConfig.BasePath "Microsoft Visual Studio\$folder"
        }
    }

    $candidateRoots = $candidateRoots | Select-Object -Unique

    foreach ($vsRoot in $candidateRoots) {
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
    }

    $searchedRoots = if ($candidateRoots) { $candidateRoots -join ", " } else { "<none>" }
    throw "Visual Studio $Version not found. Searched roots: $searchedRoots"
}
