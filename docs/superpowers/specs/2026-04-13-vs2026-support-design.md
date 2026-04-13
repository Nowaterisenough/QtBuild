# VS2026 Support Design

## Goal

Add repository-wide support for `vs2026` while keeping the existing `2019` and `2022` flows intact.
The implementation should stop depending on a single hard-coded Visual Studio edition path and instead auto-detect the installed MSVC toolchain for a requested version.

## Scope

In scope:

- Qt 6 Windows MSVC local build script
- Qt 5 Windows MSVC GitHub Actions workflow
- Qt 6 Windows MSVC GitHub Actions workflow
- Documentation and examples that list supported MSVC versions
- Artifact naming for the new compiler version code `msvc2026_64`

Out of scope:

- Changing non-MSVC workflows
- Redesigning all compiler-selection inputs to be versionless or fully automatic
- Changing package naming conventions beyond adding `2026`

## Current State

- `Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd` only accepts `2019` and `2022`, and hard-codes one `vcvarsall.bat` path per version.
- `.github/workflows/build-qt6-native-windows_x86_64_msvc_matrix.yml` only exposes `2019` and `2022` as selectable inputs.
- `.github/workflows/build-qt5-windows_x86_64_msvc_matrix.yml` only exposes `2019` and `2022`, and maps them to hard-coded `Enterprise` or selected-edition paths.
- `README.md` only documents `2019/2022`.

## Chosen Approach

Use a "known version, auto-detected path" model.

- Keep the current user-facing version input values: `2019`, `2022`, `2026`.
- Replace hard-coded VS installation paths with a version-specific auto-detection routine.
- Search standard installation roots for `Enterprise`, `Professional`, `Community`, and `BuildTools`.
- Keep existing output folder and archive naming conventions, adding support for `msvc2026_64`.

This keeps the surface area small, preserves compatibility with existing naming and release flows, and solves the path fragility that exists today.

## Design

### 1. Qt 6 local MSVC build script

File:

- `Qt6Build/build-qt6-native-windows_x86_64_msvc.cmd`

Changes:

- Add `2026` as a supported `COMPILER_VERSION`.
- Add a reusable batch subroutine that:
  - accepts a requested VS version
  - checks the correct Program Files root for that version
  - scans the editions `Enterprise`, `Professional`, `Community`, `BuildTools`
  - returns the first existing `vcvarsall.bat`
- Fail with a clear error if no installation is found for the requested version.
- Continue to generate install directories in the form `msvc%COMPILER_VERSION%_64`, so `2026` naturally becomes `msvc2026_64`.

### 2. Qt 5 GitHub Actions MSVC workflow

File:

- `.github/workflows/build-qt5-windows_x86_64_msvc_matrix.yml`

Changes:

- Add `2026` to the workflow input choices.
- Replace the current version-to-path `if/else` block with a PowerShell helper that:
  - receives the requested version
  - derives the expected VS root for that version
  - searches `Enterprise`, `Professional`, `Community`, `BuildTools`
  - returns:
    - `vcvars_path`
    - `redist_path`
    - `version_code` such as `msvc2026_64`
- Keep `vs_edition` input for backward compatibility, but do not require it for successful resolution.
  - Resolution order should prefer the selected edition first, then fall back to the other editions.

### 3. Qt 6 GitHub Actions MSVC workflow

File:

- `.github/workflows/build-qt6-native-windows_x86_64_msvc_matrix.yml`

Changes:

- Add `2026` to the workflow input choices.
- No version-path mapping is currently in the workflow because the batch script resolves it.
- The workflow should continue passing `COMPILER_VERSION` through unchanged.
- Packaging and artifact naming already derive from `COMPILER_VERSION`, so only input validation changes are required unless verification reveals hidden `2022` assumptions elsewhere.

### 4. Documentation

File:

- `README.md`

Changes:

- Update supported MSVC versions from `2019/2022` to `2019/2022/2026`.
- Update examples to include a `2026` invocation example.
- Add or adjust archive naming examples so `msvc2026` is represented.

## Error Handling

- If a requested version is unsupported, fail fast with `Unsupported MSVC version`.
- If a requested version is supported but not installed, fail with a message that includes:
  - requested version
  - searched root
  - searched editions
- If `Redist\MSVC` is not found in the workflow, fail before invoking the Qt 5 script to avoid delayed build failures.

## Testing Strategy

Because this repository is mostly scripts and workflows, verification should focus on deterministic resolution and syntax safety.

### Local script checks

- Run targeted search checks to confirm all user-facing MSVC version lists include `2026`.
- Run batch syntax-safe inspection by invoking the detection path in a dry way where practical, or at minimum checking that the script contains the new supported branch and subroutine references.

### Workflow checks

- Inspect both MSVC workflows to confirm:
  - `2026` is present in dispatch options
  - path resolution logic can emit `msvc2026_64`
  - no remaining `2019/2022`-only assumptions remain in the MSVC workflows

### Regression checks

- Verify that `2019` and `2022` still map to the same version codes as before.
- Verify that artifact naming remains unchanged except for the new `2026` variant.

## Risks

- GitHub-hosted runners may not actually provide a `2026` installation yet. The repository can still support the version logically, but runtime success will depend on runner availability.
- `BuildTools` installations may have different redist layouts than full IDE editions. The implementation should search the same `VC\Redist\MSVC` root and fail clearly if absent.
- If future LLVM workflows also depend on `lib.exe` under a hard-coded `2022` path, that is a separate issue and not required to claim `vs2026` support for the MSVC workflows.

## Success Criteria

- Users can select or pass `2026` anywhere the repository exposes an MSVC version input for Qt 5 and Qt 6 MSVC flows.
- The Qt 6 MSVC batch script resolves `vcvarsall.bat` automatically for `2019`, `2022`, and `2026`.
- The Qt 5 MSVC workflow resolves `vcvarsall.bat`, redist path, and `msvc2026_64` automatically.
- Documentation reflects `2019/2022/2026`.
