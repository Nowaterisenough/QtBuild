Describe "Patch-QtWebEngineGnPool.ps1" {
    It "adds cstdint to QtWebEngine GN pool.h exactly once" {
        $sourceRoot = Join-Path $TestDrive "qt-everywhere-src-6.11.0"
        $headerDir = Join-Path $sourceRoot "qtwebengine/src/3rdparty/gn/src/gn"
        New-Item -ItemType Directory -Path $headerDir -Force | Out-Null

        $headerPath = Join-Path $headerDir "pool.h"
        @'
#ifndef TOOLS_GN_POOL_H_
#define TOOLS_GN_POOL_H_

#include "gn/item.h"

class Pool {
 public:
  int64_t depth() const { return depth_; }
 private:
  int64_t depth_ = 0;
};

#endif
'@ | Set-Content -Path $headerPath -Encoding ASCII

        & "$PSScriptRoot/../scripts/Patch-QtWebEngineGnPool.ps1" -SourceRoot $sourceRoot

        $content = Get-Content -Path $headerPath -Raw
        $content | Should Match '#include "gn/item\.h"\r?\n#include <cstdint>'
        ([regex]::Matches($content, '#include <cstdint>').Count) | Should Be 1

        & "$PSScriptRoot/../scripts/Patch-QtWebEngineGnPool.ps1" -SourceRoot $sourceRoot

        $content = Get-Content -Path $headerPath -Raw
        ([regex]::Matches($content, '#include <cstdint>').Count) | Should Be 1
    }

    It "succeeds when QtWebEngine GN pool.h is absent" {
        $sourceRoot = Join-Path $TestDrive "qt-no-webengine-src-6.11.0"
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        & "$PSScriptRoot/../scripts/Patch-QtWebEngineGnPool.ps1" -SourceRoot $sourceRoot

        $LASTEXITCODE | Should Be 0
    }
}
