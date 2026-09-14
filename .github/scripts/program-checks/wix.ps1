# Checks the installed xim:wix on Windows: every payload's anchors are on
# disk, `wix` builds an MSI, and the BootstrapperApplications extension turns
# that MSI into a bundle with WiX's stock installer UI. The same bundle built
# without the extension is refused, which is what shows the extension is the
# payload that made the difference.
# Every criterion checks its own result and fails explicitly; a native
# command's stderr, redirected into its reading, must not end the script.
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

function Reading([string]$id, [string]$text) { Write-Host "READING ${id}: $text" }
function Fail([string]$text) { Write-Host "::error::$text"; exit 1 }

$store = Join-Path $env:XLINGS_HOME "data\xpkgs"
$candidates = @(Get-ChildItem (Join-Path $store "local-x-wix") -Directory -ErrorAction SilentlyContinue)
Reading "installed" (($candidates | ForEach-Object { $_.Name }) -join " ")
$install = $candidates | Where-Object { $_.Name -eq "5.0.2-1" } | Select-Object -First 1
if (-not $install) { Fail "local-x-wix\5.0.2-1 is not installed" }
$root = $install.FullName

# 1. Every anchor of every payload.
$anchors = @(
    "tool\tools\net6.0\any\wix.exe",
    "bal\wixext5\WixToolset.BootstrapperApplications.wixext.dll",
    "bootstrapper\build\native\v14\x64\balutil.lib",
    "bootstrapper\runtimes\win-x64\native\mbanative.dll",
    "dutil\build\native\v14\x64\dutil.lib"
)
$missing = @($anchors | Where-Object { -not (Test-Path (Join-Path $root $_) -PathType Leaf) })
Reading "anchors" ("{0} of {1} present" -f ($anchors.Count - $missing.Count), $anchors.Count)
if ($missing.Count -gt 0) { Fail ("missing anchors:`n  " + ($missing -join "`n  ")) }

$wix = Join-Path $root "tool\tools\net6.0\any\wix.exe"
$ext = Join-Path $root "bal\wixext5\WixToolset.BootstrapperApplications.wixext.dll"
$version = & $wix --version 2>&1
Reading "wix-version" "exit=$LASTEXITCODE $version"
if ($LASTEXITCODE -ne 0) { Fail "wix --version failed" }

$work = Join-Path $env:RUNNER_TEMP "wix-check"
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $work | Out-Null
Set-Location $work
Set-Content -Path payload.txt -Value "xim-pkgindex wix check"

@'
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package Name="XimWixCheck" Manufacturer="xim-pkgindex" Version="1.0.0.0"
           UpgradeCode="6f3c1d2e-8a4b-4c5d-9e6f-0a1b2c3d4e5f">
    <MajorUpgrade DowngradeErrorMessage="A newer version is installed." />
    <MediaTemplate EmbedCab="yes" />
    <StandardDirectory Id="ProgramFiles6432Folder">
      <Directory Id="INSTALLFOLDER" Name="XimWixCheck">
        <Component>
          <File Source="payload.txt" />
        </Component>
      </Directory>
    </StandardDirectory>
  </Package>
</Wix>
'@ | Set-Content -Path package.wxs -Encoding utf8

@'
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"
     xmlns:bal="http://wixtoolset.org/schemas/v4/wxs/bal">
  <Bundle Name="XimWixCheck" Manufacturer="xim-pkgindex" Version="1.0.0.0"
          UpgradeCode="7a4d2e3f-9b5c-4d6e-8f7a-1b2c3d4e5f60">
    <BootstrapperApplication>
      <bal:WixStandardBootstrapperApplication LicenseUrl="https://example.invalid/license"
                                              Theme="hyperlinkLicense" />
    </BootstrapperApplication>
    <Chain>
      <MsiPackage SourceFile="package.msi" />
    </Chain>
  </Bundle>
</Wix>
'@ | Set-Content -Path bundle.wxs -Encoding utf8

# 2. An MSI.
$out = & $wix build package.wxs -o package.msi 2>&1
Reading "msi" "exit=$LASTEXITCODE $($out -join ' | ')"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path package.msi)) { Fail "wix build did not produce package.msi" }

# 3. The bundle without the extension is refused.
$out = & $wix build bundle.wxs -o without-extension.exe 2>&1
Reading "bundle-without-extension" "exit=$LASTEXITCODE $($out -join ' | ')"
if ($LASTEXITCODE -eq 0) { Fail "a bundle using bal: elements built without the extension, so the extension criterion measures nothing" }

# 4. The bundle with the extension.
$out = & $wix build -ext $ext bundle.wxs -o setup.exe 2>&1
Reading "bundle" "exit=$LASTEXITCODE $($out -join ' | ')"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path setup.exe)) { Fail "wix build -ext did not produce setup.exe" }
Reading "setup-size" (Get-Item setup.exe).Length

Write-Host "wix: every criterion held"
