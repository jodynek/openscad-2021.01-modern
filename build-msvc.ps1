<#
.SYNOPSIS
  Build OpenSCAD 2021.01 with Visual Studio 2026 (MSVC x64) + vcpkg.

.DESCRIPTION
  1. Clones + bootstraps vcpkg into $VcpkgRoot (default D:\vcpkg) if missing.
  2. Enters the VS2026 x64 developer environment.
  3. Runs cmake configure (vcpkg manifest mode installs all deps - first run takes hours)
     and builds the chosen preset.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
  powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1 -Preset x64-debug
  powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1 -DepsOnly
#>
param(
    [string]$VcpkgRoot = "D:\vcpkg",
    [ValidateSet("x64-headless", "x64-headless-debug", "x64-gui", "x64-gui-debug")]
    [string]$Preset = "x64-headless",
    [switch]$DepsOnly,
    [switch]$SkipConfigure
)

$ErrorActionPreference = "Stop"
$SrcDir = $PSScriptRoot

# --- Visual Studio 2026 ---------------------------------------------------
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -version "[18.0,19.0)" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vsPath) { throw "Visual Studio 2026 (v18) with C++ tools not found." }
Write-Host "Using Visual Studio: $vsPath"

Import-Module "$vsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vsPath -DevCmdArguments "-arch=amd64 -host_arch=amd64" -SkipAutomaticLocation
Set-Location $SrcDir

# VS-bundled CMake + Ninja first on PATH
$env:PATH = "$vsPath\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;$vsPath\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;$env:PATH"

# --- vcpkg ----------------------------------------------------------------
if (-not (Test-Path "$VcpkgRoot\.git")) {
    Write-Host "Cloning vcpkg into $VcpkgRoot ..."
    git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
}
if (-not (Test-Path "$VcpkgRoot\vcpkg.exe")) {
    Write-Host "Bootstrapping vcpkg ..."
    & "$VcpkgRoot\bootstrap-vcpkg.bat" -disableMetrics
}
# make sure the pinned builtin-baseline commit is present locally
$baseline = (Get-Content "$SrcDir\vcpkg.json" | ConvertFrom-Json).'builtin-baseline'
if (-not (git -C $VcpkgRoot cat-file -e "$baseline^{commit}" 2>$null)) {
    Write-Host "Fetching vcpkg history for baseline $baseline ..."
    git -C $VcpkgRoot fetch origin
}

$env:VCPKG_ROOT = $VcpkgRoot
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows"
# keep caches on the same (bigger) drive as vcpkg instead of %LOCALAPPDATA%
$env:VCPKG_DEFAULT_BINARY_CACHE = "$VcpkgRoot\archives"
$env:VCPKG_DOWNLOADS = "$VcpkgRoot\downloads"
New-Item -ItemType Directory -Force $env:VCPKG_DEFAULT_BINARY_CACHE, $env:VCPKG_DOWNLOADS | Out-Null
$env:PATH = "$VcpkgRoot;$env:PATH"
# vcpkg's own CMake is 4.x: let the (older, pinned) ports configure with pre-3.5 cmake_minimum_required
$env:CMAKE_POLICY_VERSION_MINIMUM = "3.5"
$env:VCPKG_KEEP_ENV_VARS = "CMAKE_POLICY_VERSION_MINIMUM"

if ($DepsOnly) {
    Write-Host "Installing dependencies only (manifest mode) ..."
    & "$VcpkgRoot\vcpkg.exe" install --triplet x64-windows --host-triplet x64-windows --clean-after-build --x-install-root "$SrcDir\build\$Preset\vcpkg_installed"
    exit $LASTEXITCODE
}

# --- Qt 6 (GUI presets only) ---------------------------------------------
if ($Preset -like 'x64-gui*') {
    if (-not $env:QT6_ROOT) {
        $candidates = Get-ChildItem 'D:\OpenSCAD\Qt','C:\Qt' -Directory -ErrorAction SilentlyContinue |
            Get-ChildItem -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^6\.' } |
            ForEach-Object { Join-Path $_.FullName 'msvc2022_64' } | Where-Object { Test-Path (Join-Path $_ 'bin\qmake.exe') } | Sort-Object -Descending
        if ($candidates) { $env:QT6_ROOT = ($candidates | Select-Object -First 1) }
    }
    if (-not $env:QT6_ROOT -or -not (Test-Path "$env:QT6_ROOT\bin\qmake.exe")) {
        throw "Qt 6 not found. Install it (see README) and set QT6_ROOT, e.g. D:\OpenSCAD\Qt\6.10.3\msvc2022_64"
    }
    Write-Host "Using Qt 6: $env:QT6_ROOT"
}

# --- configure + build ----------------------------------------------------
if (-not $SkipConfigure) {
    Write-Host "cmake --preset $Preset"
    cmake --preset $Preset
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed ($LASTEXITCODE)" }
}
Write-Host "cmake --build --preset $Preset"
cmake --build --preset $Preset --parallel
if ($LASTEXITCODE -ne 0) { throw "Build failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host "Done: $SrcDir\build\$Preset\OpenSCAD.exe"
