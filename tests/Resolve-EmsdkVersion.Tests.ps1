Describe "Resolve-EmsdkVersion" {
    BeforeEach {
        $scriptPath = Join-Path $PSScriptRoot "../scripts/Resolve-EmsdkVersion.ps1"
        if (Test-Path $scriptPath) {
            . $scriptPath
        }
    }

    It "resolves latest from the upstream alias payload" {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '{"aliases":{"latest":"5.0.5"}}'
            }
        }

        $result = Resolve-EmsdkVersion -Version "latest"

        $result | Should Be "5.0.5"
    }

    It "returns explicit versions without contacting upstream" {
        Mock Invoke-WebRequest {
            throw "should not fetch"
        }

        $result = Resolve-EmsdkVersion -Version "5.0.5"

        $result | Should Be "5.0.5"
    }

    It "throws when aliases are missing from the payload" {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '{"releases":{"5.0.5":"abc"}}'
            }
        }

        { Resolve-EmsdkVersion -Version "latest" } | Should Throw "missing 'aliases'"
    }

    It "throws when the latest alias is missing from the payload" {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '{"aliases":{"latest-sdk":"latest"}}'
            }
        }

        { Resolve-EmsdkVersion -Version "latest" } | Should Throw "missing 'latest'"
    }

    It "throws when the upstream payload is not valid JSON" {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = 'not-json'
            }
        }

        { Resolve-EmsdkVersion -Version "latest" } | Should Throw "Failed to parse"
    }

    It "throws when the upstream fetch fails" {
        Mock Invoke-WebRequest {
            throw "network down"
        }

        { Resolve-EmsdkVersion -Version "latest" } | Should Throw "Failed to fetch"
    }
}
