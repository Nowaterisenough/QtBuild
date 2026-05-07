[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$poolHeader = Join-Path $SourceRoot "qtwebengine/src/3rdparty/gn/src/gn/pool.h"

if (-not (Test-Path -LiteralPath $poolHeader)) {
    Write-Host "QtWebEngine GN pool.h not found; skipping patch: $poolHeader"
    exit 0
}

$content = [System.IO.File]::ReadAllText($poolHeader)

if ($content -match '#include\s+<cstdint>') {
    Write-Host "QtWebEngine GN pool.h already includes cstdint."
    exit 0
}

$anchor = '#include "gn/item.h"'
$anchorIndex = $content.IndexOf($anchor, [System.StringComparison]::Ordinal)
if ($anchorIndex -lt 0) {
    Write-Error "Unable to patch QtWebEngine GN pool.h because '$anchor' was not found: $poolHeader"
    exit 1
}

$lineEnding = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
$insertAt = $anchorIndex + $anchor.Length
$content = $content.Substring(0, $insertAt) + $lineEnding + '#include <cstdint>' + $content.Substring($insertAt)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($poolHeader, $content, $utf8NoBom)

Write-Host "Patched QtWebEngine GN pool.h with #include <cstdint>."
