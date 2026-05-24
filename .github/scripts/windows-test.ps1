# Per-package Windows install / uninstall test, invoked from the
# windows-test CI job. Takes a space-separated list of changed .lua
# paths and exercises each one end-to-end:
#
#   1. parse meta (name, has_windows, is_ref) via parse-xpkg-meta.py
#   2. skip if the package is a thin ref or has no windows branch
#   3. register: `xlings config --add-xpkg <file>`
#   4. snapshot shim + xpkgs state, install, verify new artifacts
#   5. uninstall, verify artifacts are gone

param(
    [Parameter(Mandatory=$true)]
    [string]$ChangedFiles,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Log-Step  { Write-Host "`n==> $args" -ForegroundColor Cyan }
function Log-Info  { Write-Host "  $args" -ForegroundColor Gray }
function Log-Pass  { Write-Host "  [PASS] $args" -ForegroundColor Green }
function Log-Fail  { Write-Host "  [FAIL] $args" -ForegroundColor Red }

$xlingsHome = $env:XLINGS_HOME
if (-not $xlingsHome) { throw "XLINGS_HOME not set" }
$shimDir  = Join-Path $xlingsHome "subos\default\bin"
$xpkgsDir = Join-Path $xlingsHome "data\xpkgs"
$xlingsCmd = Join-Path $xlingsHome "bin\xlings.exe"
if (-not (Test-Path $xlingsCmd)) {
    $resolved = Get-Command xlings -ErrorAction SilentlyContinue
    if ($resolved) { $xlingsCmd = $resolved.Source }
}
if (-not (Test-Path $xlingsCmd)) {
    throw "xlings command not found"
}

function Get-ShimSet {
    if (-not (Test-Path $shimDir)) { return @{} }
    $set = @{}
    foreach ($entry in Get-ChildItem $shimDir -File -ErrorAction SilentlyContinue) {
        $set[$entry.Name] = $true
    }
    return $set
}

function Get-PkgInstallDirs([string]$pkgName) {
    if (-not (Test-Path $xpkgsDir)) { return @() }
    # xlings stores installs under <xpkgs>/<ns>-x-<name>/<version>/
    return Get-ChildItem $xpkgsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^[a-z]+-x-$([regex]::Escape($pkgName))$" }
}

function Test-MetadataOnlyOwnerMigration([string]$relFile) {
    $diff = git -C $WorkspaceRoot diff --unified=0 HEAD^ -- $relFile 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $diff) { return $false }

    $changed = @($diff | Where-Object {
        ($_ -match '^[+-]') -and ($_ -notmatch '^(---|\+\+\+)')
    })
    if ($changed.Count -eq 0) { return $false }

    foreach ($line in $changed) {
        $content = $line.Substring(1)
        if ($content -match '^\s*$') { continue }
        if ($content -match '^\s*(repo|homepage|contributors)\s*=') { continue }
        return $false
    }
    return $true
}

$files = $ChangedFiles -split '\s+' | Where-Object { $_ -and $_.Trim() -ne "" }
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No changed .lua files. Nothing to test." -ForegroundColor Yellow
    exit 0
}

$failures = @()
$tested   = 0
$skipped  = 0

foreach ($relFile in $files) {
    $luaFile = Join-Path $WorkspaceRoot $relFile
    if (-not (Test-Path $luaFile)) {
        Log-Info "skip (path does not exist): $relFile"
        continue
    }
    if ($luaFile -notlike "*.lua") {
        Log-Info "skip (not a .lua file): $relFile"
        continue
    }
    if (Test-MetadataOnlyOwnerMigration -relFile $relFile) {
        Log-Info "skip (metadata-only owner/link migration): $relFile"
        $skipped++
        continue
    }

    Log-Step "Parsing meta: $relFile"
    $metaJson = python "$WorkspaceRoot\.github\scripts\parse-xpkg-meta.py" $luaFile
    if ($LASTEXITCODE -ne 0) {
        Log-Fail "parser failed"
        $failures += $relFile
        continue
    }
    $meta = $metaJson | ConvertFrom-Json
    $pkgNs = if ($meta.namespace) { $meta.namespace } else { "local" }
    Log-Info "name=$($meta.name)  namespace=$pkgNs  programs=[$($meta.programs -join ',')]  is_ref=$($meta.is_ref)  has_windows=$($meta.has_windows)"

    if ($meta.is_ref) {
        Log-Info "skip (ref package)"
        $skipped++
        continue
    }
    if (-not $meta.has_windows) {
        Log-Info "skip (no windows branch)"
        $skipped++
        continue
    }
    if (-not $meta.name) {
        Log-Fail "package name not parseable"
        $failures += $relFile
        continue
    }

    $tested++
    $pkg = $meta.name
    # Package types that are expected to produce an install dir and (when
    # `programs = {...}` is declared) shims via xvm.add. Other types —
    # bugfix, config, courses, plugin, script — may legitimately install
    # without touching xpkgs/ or subos/bin/, so we only log their state
    # rather than asserting specific artifacts.
    $pkgType = if ($meta.type) { $meta.type } else { "package" }
    $expectArtifacts = $pkgType -in @("package", "app", "lib")

    # --- register ---
    Log-Step "[$pkg] register (type=$pkgType)"
    & $xlingsCmd config --add-xpkg $luaFile 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Log-Fail "config --add-xpkg failed"
        $failures += "$relFile (register)"
        continue
    }

    # --- snapshot pre-install state ---
    $shimsBefore = Get-ShimSet
    Log-Info "shims before install: $($shimsBefore.Count)"

    # Packages that declare `namespace = "config"` (or any other non-default
    # namespace) are registered under <namespace>:<name> rather than
    # local:<name>, so install/remove must address them by that spec.
    $pkgSpec = "${pkgNs}:${pkg}"

    # --- install ---
    Log-Step "[$pkg] install ($pkgSpec)"
    & $xlingsCmd install $pkgSpec -y 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Log-Fail "install failed"
        $failures += "$relFile (install)"
        continue
    }

    # --- post-install checks ---
    Log-Step "[$pkg] post-install checks"
    $installDirs = @(Get-PkgInstallDirs -pkgName $pkg)
    if ($installDirs.Count -eq 0) {
        if ($expectArtifacts) {
            Log-Fail "no install dir matching '*-x-$pkg' found under $xpkgsDir"
            $failures += "$relFile (install-dir-missing)"
        } else {
            Log-Info "no install dir (expected for type '$pkgType')"
        }
    } else {
        foreach ($d in $installDirs) {
            $versions = @(Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue)
            if ($versions.Count -eq 0) {
                if ($expectArtifacts) {
                    Log-Fail "install dir has no version subdir: $($d.FullName)"
                    $failures += "$relFile (install-dir-empty)"
                } else {
                    Log-Info "install dir exists but has no version subdir: $($d.FullName)"
                }
            } else {
                foreach ($v in $versions) { Log-Pass "install dir: $($v.FullName)" }
            }
        }
    }

    $shimsAfter = Get-ShimSet
    $newShims = $shimsAfter.Keys | Where-Object { -not $shimsBefore.ContainsKey($_) }
    if ($newShims -and $newShims.Count -gt 0) {
        foreach ($s in $newShims) { Log-Pass "new shim: $s" }
    }

    # The presence check is "every declared program has a shim post-install",
    # NOT "every declared program is in the new-shim set". Re-installs and
    # self-installs (e.g. the CI runner already has an xlings shim because
    # it just used xlings to drive the test) leave $newShims empty even
    # though the install did its job — the shim names already existed and
    # were re-pointed at the freshly installed binaries.
    if ($expectArtifacts -and $meta.programs -and $meta.programs.Count -gt 0) {
        foreach ($prog in $meta.programs) {
            $matched = $shimsAfter.Keys | Where-Object { $_ -eq $prog -or $_ -eq "$prog.exe" -or $_ -eq "$prog.cmd" }
            if (-not $matched) {
                Log-Fail "declared program '$prog' has no shim in $shimDir"
                $failures += "$relFile (missing-shim:$prog)"
            }
        }
    }
    if (-not $newShims -or $newShims.Count -eq 0) {
        Log-Info "no new shim appeared (type='$pkgType'; declared programs may have been re-pointed)"
    }

    # --- uninstall ---
    Log-Step "[$pkg] uninstall ($pkgSpec)"
    & $xlingsCmd remove $pkgSpec -y 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Log-Fail "uninstall failed"
        $failures += "$relFile (uninstall)"
        continue
    }

    # --- post-uninstall checks ---
    Log-Step "[$pkg] post-uninstall checks"
    $shimsFinal = Get-ShimSet
    $survived = $newShims | Where-Object { $shimsFinal.ContainsKey($_) }

    # Only flag survivals that are owned by this package — i.e. shims
    # whose name appears in the package's `programs` list. Shims that
    # arrived as a side effect of installing the package's `deps` are
    # the deps' own lifecycle (they remain installed even when this
    # package goes away) and are not a leak.
    $leftover = @()
    if ($survived -and $meta.programs -and $meta.programs.Count -gt 0) {
        $progSet = @{}
        foreach ($prog in $meta.programs) { $progSet[$prog] = $true }
        $leftover = $survived | Where-Object { $progSet.ContainsKey($_) }
    }

    if ($leftover -and $leftover.Count -gt 0) {
        Log-Fail "shims still present after uninstall: $($leftover -join ',')"
        $failures += "$relFile (leftover-shim)"
    } else {
        Log-Pass "all shims cleaned"
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host " Windows test summary" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  tested:   $tested"
Write-Host "  skipped:  $skipped"
Write-Host "  failures: $($failures.Count)"
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "    - $f" -ForegroundColor Red }
    exit 1
}
exit 0
