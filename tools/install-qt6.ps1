<#
.SYNOPSIS
  Installs Qt 6 (MSVC 2022 x64 kit + Multimedia) with aqtinstall and builds QScintilla against it.
  Needed only for the GUI presets (x64-gui, x64-gui-debug).

.DESCRIPTION
  1. pip install aqtinstall (user scope)
  2. aqt install-qt windows desktop <version> win64_msvc2022_64 -m qtmultimedia  -> <QtRoot>\<version>\msvc2022_64
  3. downloads QScintilla <QsciVersion> from riverbankcomputing.com, builds it with qmake/nmake
     from the Visual Studio 2026 developer environment and installs it into the Qt kit
  Afterwards:  .\build-msvc.ps1 -Preset x64-gui   (QT6_ROOT is auto-detected under <QtRoot>)

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\install-qt6.ps1
  powershell -ExecutionPolicy Bypass -File .\tools\install-qt6.ps1 -QtRoot E:\Qt -QtVersion 6.10.3
#>
param(
    [string]$QtRoot = "D:\OpenSCAD\Qt",
    [string]$QtVersion = "6.10.3",
    [string]$QsciVersion = "2.14.1",
    [string]$WorkDir = "D:\OpenSCAD\qscintilla-src"
)
$ErrorActionPreference = "Stop"
$kit = Join-Path $QtRoot "$QtVersion\msvc2022_64"

# --- Qt ------------------------------------------------------------------
if (-not (Test-Path "$kit\bin\qmake.exe")) {
    Write-Host "Installing aqtinstall ..."
    python -m pip install --user --quiet aqtinstall
    if ($LASTEXITCODE -ne 0) { throw "pip install aqtinstall failed (is Python 3 installed and on PATH?)" }
    Write-Host "Downloading Qt $QtVersion (MSVC 2022 x64 + Multimedia) into $QtRoot ..."
    New-Item -ItemType Directory -Force $QtRoot | Out-Null
    python -m aqt install-qt windows desktop $QtVersion win64_msvc2022_64 -m qtmultimedia -O $QtRoot
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$kit\bin\qmake.exe")) { throw "Qt download failed; see messages above" }
} else {
    Write-Host "Qt $QtVersion already present: $kit"
}

# --- QScintilla -------------------------------------------------------------
if (Test-Path "$kit\lib\qscintilla2_qt6.lib") {
    Write-Host "QScintilla already installed in $kit"
    exit 0
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
# Visual Studio 2022 (v17) or 2026 (v18), newest first
$vsPath = & $vswhere -latest -version "[17.0,19.0)" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vsPath) { throw "Visual Studio 2022/2026 with the C++ workload not found." }
Import-Module "$vsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vsPath -DevCmdArguments "-arch=amd64 -host_arch=amd64" -SkipAutomaticLocation

New-Item -ItemType Directory -Force $WorkDir | Out-Null
$archive = Join-Path $WorkDir "QScintilla_src-$QsciVersion.tar.gz"
$srcDir = Join-Path $WorkDir "QScintilla_src-$QsciVersion"
if (-not (Test-Path $archive)) {
    Write-Host "Downloading QScintilla $QsciVersion ..."
    Invoke-WebRequest -Uri "https://www.riverbankcomputing.com/static/Downloads/QScintilla/$QsciVersion/QScintilla_src-$QsciVersion.tar.gz" -OutFile $archive
}
if (-not (Test-Path $srcDir)) { tar -xzf $archive -C $WorkDir }

$env:PATH = "$kit\bin;$env:PATH"
Set-Location "$srcDir\src"
Write-Host "Building QScintilla with qmake/nmake (several minutes) ..."
qmake qscintilla.pro "CONFIG+=release" "CONFIG-=debug_and_release" "DEFINES+=SCI_NAMESPACE"
if ($LASTEXITCODE -ne 0) { throw "qmake failed" }
nmake /NOLOGO
if ($LASTEXITCODE -ne 0) { throw "nmake failed" }
nmake /NOLOGO install
if ($LASTEXITCODE -ne 0) { throw "nmake install failed" }
Write-Host ""
Write-Host "Done. Qt 6 kit with QScintilla: $kit"
Write-Host "Now run:  powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1 -Preset x64-gui"
