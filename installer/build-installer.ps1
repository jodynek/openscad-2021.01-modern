<#
.SYNOPSIS
  Builds the Windows installer (Inno Setup) from the x64-gui and x64-headless build outputs.

.DESCRIPTION
  Needs Inno Setup 6 (https://jrsoftware.org/isinfo.php, or `choco install innosetup`) and the
  finished builds:  .\build-msvc.ps1 -Preset x64-gui   and   .\build-msvc.ps1 -Preset x64-headless
  The Visual C++ redistributable is taken from the Visual Studio installation and bundled; the
  installer runs it only when the machine has no (or an older) 14.x runtime.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
  -> build\installer\OpenSCAD-2021.01-modern.1-win64-setup.exe
#>
param(
    [string]$AppVersion = "2021.01",
    [string]$BuildDir = "$PSScriptRoot\..\build\x64-gui",
    [string]$HeadlessDir = "$PSScriptRoot\..\build\x64-headless",
    [string]$VCRedist = ""
)
$ErrorActionPreference = "Stop"

# --- Inno Setup ---
$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $iscc) {
    foreach ($c in @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")) { if (Test-Path $c) { $iscc = $c; break } }
}
if (-not $iscc) { throw "Inno Setup 6 (ISCC.exe) not found. Install it from https://jrsoftware.org/isinfo.php or 'choco install innosetup'." }

# --- build outputs ---
if (-not (Test-Path "$BuildDir\OpenSCAD.exe")) { throw "GUI build not found in $BuildDir - run .\build-msvc.ps1 -Preset x64-gui first." }
if (-not (Test-Path "$BuildDir\platforms\qwindows.dll")) { throw "Qt runtime not deployed in $BuildDir (platforms\qwindows.dll missing)." }
$BuildDir = (Resolve-Path $BuildDir).Path
if (Test-Path "$HeadlessDir\openscad.exe") { $HeadlessDir = (Resolve-Path $HeadlessDir).Path } else { Write-Warning "headless build not found in $HeadlessDir - openscad-cli.exe will not be included"; $HeadlessDir = "" }

# --- Visual C++ redistributable from the Visual Studio installation ---
if (-not $VCRedist) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
        if ($vsPath) {
            $VCRedist = Get-ChildItem "$vsPath\VC\Redist\MSVC\*\vc_redist.x64.exe" -ErrorAction SilentlyContinue |
                Where-Object { $_.Directory.Name -match '^\d' } | Sort-Object { [version]$_.Directory.Name } -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }
    }
}
if ($VCRedist -and (Test-Path $VCRedist)) { Write-Host "VC++ redistributable: $VCRedist" } else { Write-Warning "vc_redist.x64.exe not found - the installer will not bundle the Visual C++ runtime"; $VCRedist = "" }
# minimum runtime version the binaries need = the toolset they were built with (14.<minor>)
$toolsetMinor = 0
if ($VCRedist) { $m = [regex]::Match($VCRedist, "MSVC\\14\.(\d+)\."); if ($m.Success) { $toolsetMinor = [int]$m.Groups[1].Value } }
if ($toolsetMinor -eq 0 -and $env:VCToolsVersion -match "^14\.(\d+)") { $toolsetMinor = [int]$Matches[1] }
if ($toolsetMinor -gt 0) { Write-Host "VC++ toolset: 14.$toolsetMinor" }

# --- compile ---
$args = @("/DAppVersion=$AppVersion", "/DBuildDir=$BuildDir")
if ($HeadlessDir) { $args += "/DHeadlessDir=$HeadlessDir" }
if ($VCRedist) { $args += "/DVCRedist=$VCRedist" }
if ($toolsetMinor -gt 0) { $args += "/DVCToolsetMinor=$toolsetMinor" }
$args += "$PSScriptRoot\openscad.iss"
Write-Host "ISCC $($args -join ' ')"
& $iscc @args
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
$out = Get-ChildItem "$PSScriptRoot\..\build\installer\*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ""
Write-Host "Installer: $($out.FullName) ($([math]::Round($out.Length / 1MB, 1)) MB)"
