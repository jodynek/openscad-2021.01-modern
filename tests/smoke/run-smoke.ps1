<#
.SYNOPSIS
  Smoke tests for the headless openscad.exe: language semantics, Unicode handling,
  include/use/import and geometry export. Compares echo output with expected/*.echo.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tests\smoke\run-smoke.ps1
  powershell -ExecutionPolicy Bypass -File tests\smoke\run-smoke.ps1 -Exe build\x64-headless-debug\openscad.exe
#>
param(
    [string]$Exe = "$PSScriptRoot\..\..\build\x64-headless\openscad.exe",
    [string]$GuiExe = "$PSScriptRoot\..\..\build\x64-gui\OpenSCAD.exe",
    [switch]$Gui   # also start the Qt GUI with an example and check that its main window appears
)
$ErrorActionPreference = "Continue"
$Exe = (Resolve-Path $Exe).Path
$dir = $PSScriptRoot
$tmp = Join-Path $env:TEMP ("openscad-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmp | Out-Null
Set-Location $dir

$failed = 0
foreach ($name in @("lang", "utf8", "esc", "main")) {
    $out = Join-Path $tmp "$name.echo"
    & $Exe -o $out "$name.scad" 2>$null
    # compare with normalized line endings (the program writes CRLF on Windows, expected files are LF)
    $expected = ([IO.File]::ReadAllText("$dir\expected\$name.echo")) -replace "`r`n", "`n"
    $actual = if (Test-Path $out) { ([IO.File]::ReadAllText($out)) -replace "`r`n", "`n" } else { "" }
    if ($expected -eq $actual) {
        Write-Host "PASS $name.scad"
    } else {
        Write-Host "FAIL $name.scad (echo output differs from expected\$name.echo)"
        $failed++
    }
}

# geometry: facet counts must match
# utf8.scad renders text("ž😀Ab"): 516 facets with the bundled fonts/fonts.conf (Liberation Sans + Windows fonts
# for the emoji); it was 608 before fontconfig had a configuration file on Windows.
$geom = @{ "main.scad" = 222; "tetra.scad" = 4; "utf8.scad" = 516; "..\..\examples\Basics\logo.scad" = 5892 }
foreach ($scad in $geom.Keys) {
    $out = Join-Path $tmp ([IO.Path]::GetFileNameWithoutExtension($scad) + ".stl")
    $log = & $Exe -o $out $scad 2>&1 | Out-String
    if ($log -cmatch "(?m)^\s+Facets:\s+(\d+)" -and [int]$Matches[1] -eq $geom[$scad] -and (Test-Path $out)) {
        Write-Host "PASS $scad ($($Matches[1]) facets)"
    } else {
        Write-Host "FAIL $scad (expected $($geom[$scad]) facets)"
        $failed++
    }
}

# PNG export exercises the offscreen OpenGL context
$png = Join-Path $tmp "logo.png"
& $Exe -o $png --imgsize=400,300 "..\..\examples\Basics\logo.scad" 2>$null
if ((Test-Path $png) -and (Get-Item $png).Length -gt 1000) { Write-Host "PASS logo.png export" } else { Write-Host "FAIL logo.png export"; $failed++ }

# GUI: the window must come up and stay alive (Qt runtime, QScintilla, OpenGL preview)
if ($Gui) {
    if (Test-Path $GuiExe) {
        $p = Start-Process -FilePath (Resolve-Path $GuiExe).Path -ArgumentList "$dir\..\..\examples\Basics\logo.scad" -PassThru
        $title = ""
        for ($i = 0; $i -lt 30 -and -not $p.HasExited; $i++) { Start-Sleep -Milliseconds 500; $p.Refresh(); if ($p.MainWindowHandle -ne 0) { $title = $p.MainWindowTitle; break } }
        if (-not $p.HasExited -and $title -like "*OpenSCAD*") { Write-Host "PASS GUI started ('$title')" } else { Write-Host "FAIL GUI did not show its main window (exited: $($p.HasExited))"; $failed++ }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "SKIP GUI (not built: $GuiExe)"
    }
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
if ($failed -eq 0) { Write-Host "ALL SMOKE TESTS PASSED"; exit 0 } else { Write-Host "$failed TEST(S) FAILED"; exit 1 }
