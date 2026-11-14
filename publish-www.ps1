<#
.SYNOPSIS
  Zverejni vydani modernizovaneho OpenSCAD 2021.01 na webu jodynek.cz (sdilena slozka \\192.168.0.97\www).
.DESCRIPTION
  Stejny postup jako publish-www.ps1 u jCmd / jNotepadu. Spousti se rucne po installer\build-installer.ps1. Nahraje:
    programs/openscad/releases/OpenSCAD-<verze>-win64-setup.exe  (+ .sha256; starsi verze zustavaji)
    programs/openscad/index.html, en.html, historie.html, history.html + img/   (stranka z www\openscad\, cesky a anglicky)
    programs/openscad/changelog.json                                (historie zmen, viz krok 0)
    programs/icons/openscad.png                                     (128x128 z icons\openscad-128.png)
    programs/manifest.json                                          (zaznam OpenSCAD se prida nebo aktualizuje)
    index.html                                                      (radek v zaloznim seznamu FALLBACK)
  a zapise zmenu do HISTORIE-WEBU.md a do gitu webu (E:\Web\git-web.cmd, push na GitLab).
  Verze = AppVersion-modern.ModernRelease z installer\openscad.iss (napr. 2021.01-modern.1), soubory z build\installer\.
  Zdroje stranky jsou verzovane v tomto repozitari (www\openscad\); na webu se nic rucne neupravuje.
.EXAMPLE
  .\publish-www.ps1
  .\publish-www.ps1 -Www Y:\ -SkipCheck
#>
param(
    [string]$Www     = '\\192.168.0.97\www',
    [string]$BaseUrl = 'https://jodynek.cz',
    [switch]$SkipCheck            # bez zaverecne kontroly pres HTTPS
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false     # web pouziva UTF-8 bez BOM

$iss = Get-Content -Raw installer\openscad.iss
if ($iss -notmatch '#define AppVersion "([^"]+)"') { throw 'AppVersion v installer\openscad.iss nenalezena.' }
$AppVersion = $Matches[1]
if ($iss -notmatch '#define ModernRelease "([^"]+)"') { throw 'ModernRelease v installer\openscad.iss nenalezena.' }
$Version = "$AppVersion-modern.$($Matches[1])"
$setupName = "OpenSCAD-$Version-win64-setup.exe"
$setup = "build\installer\$setupName"
if (-not (Test-Path $setup)) { throw "Instalator $setup neexistuje. Spustte nejdriv installer\build-installer.ps1." }
if (-not (Test-Path "$Www\index.html")) { throw "Web $Www neni dostupny." }
# historie webu srovnana s GitLabem driv, nez se na web cokoli nahraje
& "$PSScriptRoot\tools\sync-web-history.ps1"

# 0) historie zmen (www\openscad\changelog.json): pripravovana polozka "next" dostane cislo vydavane verze
#    a dnesni datum a nahore se zalozi nova prazdna polozka "next". Zmeneny soubor je potreba commitnout.
#    Opakovane spusteni pro stejnou verzi (verze uz v changelogu je a "next" je prazdna) nic nemeni.
$clPath = "$PSScriptRoot\www\openscad\changelog.json"
$clText = [IO.File]::ReadAllText($clPath, $utf8)
$clEntries = @($clText | ConvertFrom-Json | ForEach-Object { $_ })
$nextEntry = $clEntries | Where-Object { $_.version -eq 'next' } | Select-Object -First 1
$releaseEntry = $clEntries | Where-Object { $_.version -eq $Version } | Select-Object -First 1
$nextCount = if ($nextEntry) { @($nextEntry.changes).Count } else { 0 }
if ($releaseEntry) {
    if ($nextCount) { throw "changelog.json uz obsahuje verzi $Version a polozka next ma dalsi zmeny - zvyste ModernRelease v installer\openscad.iss a OPENSCAD_MODERN_RELEASE v CMake." }
    Write-Host "Historie zmen: verze $Version uz v changelog.json je (opakovane zverejneni)" -ForegroundColor Cyan
}
else {
    if (-not $nextEntry) { throw 'V changelog.json chybi pripravovana polozka { "version": "next", "date": "", "changes": [...] }.' }
    if (-not $nextCount) { throw 'Pripravovana polozka next v changelog.json nema zadne zmeny - doplnte, co se ve verzi zmenilo.' }
    $rxNext = [regex]'"version":\s*"next",\s*"date":\s*""'
    if (-not $rxNext.IsMatch($clText)) { throw 'V changelog.json chybi zapis { "version": "next", "date": "", ... }.' }
    $clText = $rxNext.Replace($clText, ('"version": "' + $Version + '", "date": "' + (Get-Date -Format 'yyyy-MM-dd') + '"'), 1)
    $clText = ([regex]'^\s*\[').Replace($clText, "[`n  { `"version`": `"next`", `"date`": `"`", `"changes`": [], `"changes_en`": [] },", 1)
    [IO.File]::WriteAllText($clPath, $clText, $utf8)
    Write-Host "Historie zmen: polozka next -> verze $Version (www\openscad\changelog.json je potreba commitnout)" -ForegroundColor Cyan
}

$title = 'OpenSCAD'
$desc  = 'Skriptový 3D CAD pro 3D tisk: OpenSCAD 2021.01 přeložený s Visual Studiem 2026, Qt 6 a tmavým režimem, s instalátorem pro Windows 11; zdrojové kódy na GitHubu.'
$icon  = 'programs/icons/openscad.png'
$dir   = "$Www\programs\openscad"

# 1) instalator + kontrolni soucet
New-Item -ItemType Directory -Force "$dir\releases" | Out-Null
Copy-Item $setup "$dir\releases\$setupName" -Force
$hash = (Get-FileHash "$dir\releases\$setupName" -Algorithm SHA256).Hash
[IO.File]::WriteAllText("$dir\releases\$setupName.sha256", "$hash  $setupName`n", $utf8)
Write-Host "Nahrano: $dir\releases\$setupName" -ForegroundColor Cyan
$href = "programs/openscad/releases/$setupName"

# 2) ikona 128x128
Copy-Item "$PSScriptRoot\icons\openscad-128.png" "$Www\$($icon.Replace('/', '\'))" -Force

# 3) stranka o programu (www\openscad\: cesky, anglicky, historie zmen, obrazky)
#    odkazy na obrazky a PDF dostanou cislo verze (?v=...): server neposila Cache-Control, prohlizec by jinak drzel stary soubor
foreach ($page in 'index.html', 'en.html', 'historie.html', 'history.html') {
    $html = [IO.File]::ReadAllText("$PSScriptRoot\www\openscad\$page", $utf8)
    $html = [regex]::Replace($html, '(href|src)="((?!https?:|/)[^"?#]+\.(png|jpg|pdf|mp4|vtt))"', ('$1="$2?v=' + $Version + '"'))
    [IO.File]::WriteAllText("$dir\$page", $html, $utf8)
}
Copy-Item $clPath "$dir\changelog.json" -Force
New-Item -ItemType Directory -Force "$dir\img" | Out-Null
Copy-Item "$PSScriptRoot\www\openscad\img\*" "$dir\img\" -Force
Write-Host "Stranka: $dir\index.html" -ForegroundColor Cyan

# 4) programs/manifest.json -- zaznam se pozna podle odkazu do programs/openscad/
$mfPath = "$Www\programs\manifest.json"
$items = @([IO.File]::ReadAllText($mfPath, $utf8) | ConvertFrom-Json | ForEach-Object { $_ })
$listName = "$title $Version"
$entry = [pscustomobject][ordered]@{ name = $listName; href = $href; page = 'programs/openscad/'; desc = $desc; icon = $icon }
$idx = -1
for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i].href -like 'programs/openscad/*') { $idx = $i } }
if ($idx -ge 0) { $items[$idx] = $entry } else { $items += $entry }
# stejny zapis jako publish-www.ps1 jCmd (poradi poli, prazdna pole se vynechaji)
$json = "[`n" + (($items | ForEach-Object {
    $o = $_
    "  {`n" + ((@('name', 'href', 'portable', 'arm64', 'portableArm64', 'linux', 'android', 'page', 'desc', 'icon') | Where-Object { $o.$_ } | ForEach-Object {
        '    "' + $_ + '": "' + ($o.$_ -replace '\\', '\\' -replace '"', '\"') + '"'
    }) -join ",`n") + "`n  }"
}) -join ",`n") + "`n]"
[IO.File]::WriteAllText($mfPath, $json, $utf8)
Write-Host 'Manifest programu aktualizovan.' -ForegroundColor Cyan

# 5) index.html -- radek v zaloznim seznamu FALLBACK
$idxPath = "$Www\index.html"
$html = [IO.File]::ReadAllText($idxPath, $utf8)
$line = "          { name: '$listName', href: '$href', page: 'programs/openscad/', desc: '$desc', icon: '$icon' }"
$rxOld = "(?m)^[ \t]*\{ name: '[^']*', href: 'programs/openscad/[^']*'.*?\}(?=,?[ \t]*$)"
if ([regex]::IsMatch($html, $rxOld)) {
    $html = [regex]::Replace($html, $rxOld, $line.Replace('$', '$$'))
}
else {
    $rxEnd = "(?s)(const FALLBACK = \[.*?)(\}\s*)(\n\s*\];)"
    if (-not [regex]::IsMatch($html, $rxEnd)) { throw 'V index.html jsem nenasel seznam FALLBACK.' }
    $html = [regex]::Replace($html, $rxEnd, { param($m) $m.Groups[1].Value + '},' + "`n" + $line + $m.Groups[3].Value })
}
[IO.File]::WriteAllText($idxPath, $html, $utf8)
Write-Host "Web aktualizovan: $BaseUrl/#programy" -ForegroundColor Green

# 6) historie zmen webu (HISTORIE-WEBU.md) a verzovani webu (git mimo web, E:\Web\git-web.cmd)
$webHistory = "$Www\HISTORIE-WEBU.md"
if (Test-Path $webHistory) {
    $hist = [IO.File]::ReadAllText($webHistory, $utf8)
    $at = $hist.IndexOf('<!-- NOVE ZAZNAMY')
    if ($at -ge 0) {
        $eol = $hist.IndexOf("`n", $at) + 1
        $nl = if ($hist.Contains("`r`n")) { "`r`n" } else { "`n" }
        $line = "- **$(Get-Date -Format 'yyyy-MM-dd')** – OpenSCAD $Version (instalátor, stránka programu a historie změn)." + $nl
        [IO.File]::WriteAllText($webHistory, $hist.Insert($eol, $line), $utf8)
        Write-Host "Historie zmen webu: $webHistory" -ForegroundColor Cyan
    }
}
$webGit = 'E:\Web\git-web.cmd'
if (Test-Path $webGit) {
    & $webGit add -A | Out-Null
    & $webGit diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        & $webGit commit -q -m "web: OpenSCAD $Version"
        Write-Host "Web zapsan do historie (git): OpenSCAD $Version" -ForegroundColor Cyan
        $prevPref = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & $webGit push -q origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host 'Historie webu odeslana na GitLab.' -ForegroundColor Cyan }
        else { Write-Warning 'Historii webu se nepodarilo odeslat na GitLab (spustte E:\Web\git-web.cmd push).' }
        $ErrorActionPreference = $prevPref
    }
}

# 7) kontrola pres HTTPS: stranky odpovidaji 200, manifest obsahuje vydani, instalator ma spravnou velikost
if (-not $SkipCheck) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $fails = 0
    $stamp = [DateTime]::UtcNow.Ticks
    foreach ($p in 'programs/openscad/', 'programs/openscad/en.html', 'programs/openscad/historie.html', 'programs/openscad/history.html', 'programs/openscad/changelog.json') {
        try { $r = Invoke-WebRequest -UseBasicParsing "$BaseUrl/$p`?check=$stamp"; Write-Host "OK    $p ($($r.StatusCode))" -ForegroundColor Green }
        catch { Write-Host "CHYBA $p : $($_.Exception.Message)" -ForegroundColor Red; $fails++ }
    }
    try {
        $m = (Invoke-WebRequest -UseBasicParsing "$BaseUrl/programs/manifest.json?check=$stamp").Content | ConvertFrom-Json
        if (@($m | Where-Object { $_.href -eq $href }).Count) { Write-Host "OK    programs/manifest.json obsahuje $href" -ForegroundColor Green }
        else { Write-Host "CHYBA programs/manifest.json neobsahuje $href" -ForegroundColor Red; $fails++ }
    } catch { Write-Host "CHYBA programs/manifest.json: $($_.Exception.Message)" -ForegroundColor Red; $fails++ }
    try {
        $h = Invoke-WebRequest -UseBasicParsing -Method Head "$BaseUrl/$href`?check=$stamp"
        $len = [int64]$h.Headers['Content-Length']; $local = (Get-Item $setup).Length
        if ($len -eq $local) { Write-Host "OK    $setupName ($len B)" -ForegroundColor Green } else { Write-Host "CHYBA $setupName : web $len B, lokalne $local B" -ForegroundColor Red; $fails++ }
    } catch { Write-Host "CHYBA $setupName : $($_.Exception.Message)" -ForegroundColor Red; $fails++ }
    if ($fails) { Write-Warning "Kontrola webu nasla $fails chyb." } else { Write-Host 'Kontrola webu: vse v poradku.' -ForegroundColor Green }
}
