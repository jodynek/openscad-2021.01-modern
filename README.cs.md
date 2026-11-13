# OpenSCAD 2021.01 – modernizovaný build

[![Windows build](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/windows.yml/badge.svg)](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/windows.yml)
[![Linux build](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/linux.yml/badge.svg)](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/linux.yml)

*English version: [README.md](README.md) · Dokumentace pro vývojáře: [DEVELOPMENT.cs.md](DEVELOPMENT.cs.md)*

OpenSCAD je skriptový 3D CAD: díl popíšete v jazyce OpenSCAD, program ho vyhodnotí pomocí
konstruktivní geometrie těles a exportuje STL, 3MF, AMF, OFF, DXF, SVG, PDF nebo PNG.
Viz <https://openscad.org> a [uživatelský manuál](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual).

Tento repozitář obsahuje **poslední tagovanou verzi 2021.01** s modernizovaným buildem:

* jeden CMake projekt s presety, závislosti přes vcpkg manifest (žádné ruční shánění knihoven),
* C++17, Boost zredukovaný na hlavičkové části plus Program.Options, GLib odstraněn,
* přeloží se s Visual Studio 2026 na Windows 11 x64 bez dalšího nastavování.

Jazyk ani geometrické jádro (CGAL) se nezměnily, modely se renderují stejně jako v oficiální
verzi 2021.01.

## Stav

| Část | Stav |
|---|---|
| Příkazový `openscad.exe` (render, export STL/PNG/…, `text()`) | **funguje** na Windows x64 / MSVC 2026 |
| GUI `OpenSCAD.exe` (editor, náhled, customizer) s **Qt 6.10** | **funguje**; styl Fusion, sleduje světlý/tmavý motiv systému |
| Linux (Ubuntu 24.04, distribuční balíčky) | **funguje**: příkazová verze ověřena smoke testy, GUI binárka se překládá s Qt 6.4 (zatím nespuštěna na desktopu) |

## Kompilace na Windows (5 minut vašeho času, zhruba hodina času počítače)

Potřebujete:

1. **Visual Studio 2026** (Community stačí) s workloadem *Desktop development with C++*.
   Obsahuje CMake, Ninja i kompilátor.
2. **Git** – <https://git-scm.com>.
3. Asi **15 GB** volného místa a připojení k internetu.

Otevřete PowerShell v tomto adresáři a spusťte:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
```

Skript naklonuje vcpkg do `D:\OpenSCAD\vcpkg` (jinam: `-VcpkgRoot E:\vcpkg`), přeloží všechny
knihovny – **první běh trvá 60 až 90 minut**, další běhy berou hotové balíčky z cache a trvají
sekundy – a pak přeloží OpenSCAD.

Výsledek: `build\x64-headless\openscad.exe` s potřebnými DLL vedle něj.

### Vyzkoušejte

```powershell
build\x64-headless\openscad.exe --info
build\x64-headless\openscad.exe -o logo.stl examples\Basics\logo.scad
build\x64-headless\openscad.exe -o logo.png --imgsize=800,600 examples\Basics\logo.scad
powershell -ExecutionPolicy Bypass -File tests\smoke\run-smoke.ps1
```

Výstup buildu je soběstačný: složky se zdroji (`color-schemes`, `examples`, `fonts`,
`libraries`, `templates`) a konfigurace fontconfigu se kopírují vedle exe, takže `text()` najde
přibalené fonty Liberation i fonty nainstalované ve Windows.

### GUI build (Qt 6)

GUI potřebuje Qt 6 a QScintillu, které zde nejsou součástí vcpkg. Obojí nainstaluje jeden skript
(Qt 6.10.3 MSVC kit s Multimedia přes `aqtinstall`, asi 1 GB, plus QScintilla 2.14.1 přeložená
ze zdrojů, několik minut):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\install-qt6.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1 -Preset x64-gui
```

Výsledek: `build\x64-gui\OpenSCAD.exe` s Qt runtime nasazeným vedle (`windeployqt`).
Qt se instaluje do `D:\OpenSCAD\Qt` (jinam: `-QtRoot`); pokud už Qt 6 MSVC kit máte, nastavte
`QT6_ROOT` (např. `C:\Qt\6.10.3\msvc2022_64`) a spusťte jen část skriptu pro QScintillu.
Pro `aqtinstall` musí být na `PATH` Python 3.

Smoke testy umí spustit i GUI: `tests\smoke\run-smoke.ps1 -Gui`.

### Otevření ve Visual Studiu

*File → Open → Folder* na tento adresář. Visual Studio načte `CMakePresets.json`; vyberte preset
**x64 Headless Release** (nebo Debug), případně **x64 GUI Release** pro Qt build. Před spuštěním
VS nastavte proměnné prostředí `VCPKG_ROOT` (např. `D:\OpenSCAD\vcpkg`) a pro GUI `QT6_ROOT`
(např. `D:\OpenSCAD\Qt\6.10.3\msvc2022_64`), nebo je vložte do `CMakeUserPresets.json`.

### Instalátor pro Windows

Hotové instalátory jsou na [stránce Releases](https://github.com/jodynek/openscad-2021.01-modern/releases).
Vlastní sestavení (potřebuje [Inno Setup 6](https://jrsoftware.org/isinfo.php) a oba Windows buildy):

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
```

Výsledek: `build\installer\OpenSCAD-2021.01-modern-win64-setup.exe` (asi 48 MB). Nainstaluje GUI,
`openscad-cli.exe` (příkazovou verzi), příklady, fonty a barevná schémata, nabídne asociaci
souborů `.scad` a volitelně přidání do PATH, a obsahuje Visual C++ runtime (instaluje se jen
když chybí). Tichá instalace: `setup.exe /VERYSILENT /NORESTART` (`/CURRENTUSER` instaluje
pro uživatele bez práv správce).

## Kompilace na Linuxu (Ubuntu 24.04 / Debian 12)

Vše z distribučních balíčků, bez vcpkg:

```bash
sudo ./tools/linux-deps.sh            # nainstaluje kompilátor, CMake, CGAL, Qt 6, QScintillu, ...
cmake --preset linux-release          # nebo linux-headless jen pro příkazovou verzi
cmake --build --preset linux-release --parallel
./build/linux-release/openscad examples/Basics/logo.scad
```

`tools/linux-deps.sh --check` vypíše balíčky a co je nainstalováno. Bez práv roota (nebo na
Windows s Docker Desktop) `tools/linux-docker-check.sh` přeloží a otestuje obě linuxové varianty
v čistém kontejneru `ubuntu:24.04`; binárky a logy skončí v `build/linux-docker`.

## Když něco selže

| Příznak | Co dělat |
|---|---|
| `vcpkg install failed` | Otevřete log uvedený v hlášení (`build\x64-headless\vcpkg-manifest-install.log`) a spusťte skript znovu; hotové balíčky se nepřekládají znovu. |
| Chybí `cl.exe` | Ve Visual Studio Installeru doinstalujte workload *Desktop development with C++*. |
| Build skončí s `win_flex ... end of file in string` | Vzácný souběh v nástroji flex; spusťte build znovu. |
| Málo místa na disku | Cache vcpkg je v `D:\OpenSCAD\vcpkg\archives` a `downloads`; `buildtrees` se po každém hotovém balíčku mažou. |
| `FATAL: unhandled exception: ...` při startu | Nahlaste i s textem hlášení; nahrazuje tichý pád původního kódu. |

## Co je v repozitáři

| Cesta | Obsah |
|---|---|
| `src/` | zdrojové kódy C++ (jádro, geometrie, exporty, GUI) |
| `CMakeLists.txt`, `CMakePresets.json` | build |
| `vcpkg.json` | manifest závislostí |
| `build-msvc.ps1` | build na Windows jedním příkazem |
| `tools/winflexbison/` | flex a bison pro Windows |
| `tools/install-qt6.ps1` | nainstaluje Qt 6 a přeloží QScintillu pro GUI |
| `tests/smoke/` | rychlé regresní testy příkazové verze |
| `examples/`, `libraries/`, `fonts/`, `color-schemes/` | zdroje dodávané s OpenSCADem |
| `openscad.pro`, `*.pri`, `features/` | starý qmake build, ponechán jen pro referenci |

Historie gitu začíná čistým release 2021.01, takže `git diff <první commit>` ukáže všechny
modernizační změny.

## Licence

GPL-2.0-or-later, viz [COPYING](COPYING). OpenSCAD je © vývojáři OpenSCADu.
