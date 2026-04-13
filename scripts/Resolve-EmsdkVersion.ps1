param(
    [string] $Version = "latest",
    [string] $TagsUrl = "https://raw.githubusercontent.com/emscripten-core/emsdk/main/emscripten-releases-tags.json"
)

function Resolve-EmsdkVersion {
    param(
        [string] $Version = "latest",
        [string] $TagsUrl = "https://raw.githubusercontent.com/emscripten-core/emsdk/main/emscripten-releases-tags.json"
    )

    if (-not [string]::IsNullOrWhiteSpace($Version) -and $Version -ne "latest") {
        return $Version
    }

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $TagsUrl -ErrorAction Stop
    } catch {
        throw "Failed to fetch emsdk release tags from '$TagsUrl': $($_.Exception.Message)"
    }

    try {
        $payload = $response.Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse emsdk release tags payload from '$TagsUrl': $($_.Exception.Message)"
    }

    if (-not $payload.PSObject.Properties["aliases"]) {
        throw "emsdk release tags payload is missing 'aliases'."
    }

    if (-not $payload.aliases.PSObject.Properties["latest"]) {
        throw "emsdk release tags payload is missing 'latest' alias."
    }

    $resolvedVersion = [string] $payload.aliases.latest
    if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
        throw "emsdk release tags payload returned an empty 'latest' alias."
    }

    return $resolvedVersion
}

if ($MyInvocation.InvocationName -ne ".") {
    Resolve-EmsdkVersion -Version $Version -TagsUrl $TagsUrl
}
