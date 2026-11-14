<#
.SYNOPSIS
  Před vydáním srovná historii webu (git v E:\Web\jodynek.cz.git, soubory na \\192.168.0.97\www) s GitLabem (bod 262).

.DESCRIPTION
  Volá ho publish-www.ps1 (jCmd i jNotepad – stejný soubor je v obou repozitářích v tools\) dřív, než na web cokoli
  nahraje. Když jsou na GitLabu novější zápisy (např. ruční úprava webu z jiného počítače):
  - soubory, které ty zápisy změnily, jsou na webu stejné jako na GitLabu → historie se spojí sama
    (bez místních zápisů posunem historie, jinak „merge -s ours“ – soubory webu se nemění), vydání pokračuje;
  - některý se liší → vydání se zastaví s výpisem rozdílných souborů (nic se ještě nenahrálo).
  Když GitLab nejde načíst, jen upozorní (zápis do historie pak odešle publish-www.ps1 jako dřív, nebo ohlásí chybu).

.PARAMETER WebGit
  git pro web (výchozí E:\Web\git-web.cmd); testy předávají vlastní.
#>
param([string]$WebGit = 'E:\Web\git-web.cmd')

if (-not (Test-Path $WebGit)) { return }
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'   # git píše hlášky na stderr; ve Windows PowerShellu by 2>&1 se Stop skript ukončil
try {
    & $WebGit fetch -q origin 2>&1 | Out-Null
    if ($LASTEXITCODE) {
        Write-Warning 'Historie webu: GitLab nejde načíst (git fetch) – pokračuji bez srovnání.'
        return
    }
    $counts = @(((& $WebGit rev-list --left-right --count 'main...origin/main' 2>$null) -join ' ').Trim() -split '\s+')
    if ($counts.Count -lt 2) { Write-Warning 'Historie webu: stav vůči GitLabu nejde zjistit – pokračuji bez srovnání.'; return }
    $ahead = [int]$counts[0]; $behind = [int]$counts[1]
    if ($behind -eq 0) { return }

    # soubory změněné novějšími zápisy na GitLabu: musí být na webu stejné jako na GitLabu
    $base = ((& $WebGit merge-base main origin/main 2>$null) -join '').Trim()
    if (-not $base) { throw 'Historie webu: s GitLabem nemá společný začátek – srovnejte ručně (E:\Web\git-web.cmd).' }
    $files = @(& $WebGit -c core.quotepath=false diff --name-only $base origin/main 2>$null | Where-Object { $_ })
    $differs = @($files | Where-Object { & $WebGit diff --quiet origin/main -- $_ 2>$null; $LASTEXITCODE -ne 0 })
    if ($differs.Count) {
        $list = ($differs | Select-Object -First 10) -join ', '
        throw ("Historie webu: na GitLabu je $behind novější zápis(ů), ale soubory na webu se od nich liší ($list). " +
               'Vydání se zastavuje dřív, než na web něco nahraje. Rozdíl: E:\Web\git-web.cmd diff origin/main -- <soubor>; ' +
               'srovnejte web s GitLabem a vydání spusťte znovu.')
    }
    # bez místních zápisů: jen posunout historii a index na GitLab (soubory na webu se nepřepisují – jsou stejné)
    if ($ahead -eq 0) { & $WebGit reset -q origin/main 2>&1 | Out-Null }
    else { & $WebGit merge -q -s ours origin/main -m 'web: spojeni historie (zapisy z GitLabu uz na webu byly)' 2>&1 | Out-Null }
    if ($LASTEXITCODE) { throw 'Historie webu: spojení s GitLabem selhalo – srovnejte ručně (E:\Web\git-web.cmd).' }
    Write-Host "Historie webu: srovnána s GitLabem ($behind novější zápis(ů) z GitLabu už byl(y) na webu)." -ForegroundColor Cyan
}
finally { $ErrorActionPreference = $prevPref }
