# OpenSCAD 2021.01 – modernized build

[![Windows build](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/windows.yml/badge.svg)](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/windows.yml)
[![Linux build](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/linux.yml/badge.svg)](https://github.com/jodynek/openscad-2021.01-modern/actions/workflows/linux.yml)

*Česká verze: [README.cs.md](README.cs.md) · Developer documentation: [DEVELOPMENT.md](DEVELOPMENT.md)*

OpenSCAD is a script-based 3D CAD modeller: you describe a part in the OpenSCAD language,
the program evaluates it with constructive solid geometry and exports STL, 3MF, AMF, OFF,
DXF, SVG, PDF or PNG. See <https://openscad.org> and the
[user manual](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual).

This repository is the **last tagged release, 2021.01**, with a modernized build:

* one CMake project with presets, dependencies through a vcpkg manifest (no manual library hunting),
* C++17, Boost reduced to header-only parts plus Program.Options, GLib removed,
* builds with Visual Studio 2026 on Windows 11 x64 out of the box.

The language and the geometry kernel (CGAL) are unchanged, so models render the same as in the
official 2021.01 release.

## Status

| Part | State |
|---|---|
| Command-line `openscad.exe` (render, export STL/PNG/…, `text()`) | **works** on Windows x64 / MSVC 2026 |
| GUI `OpenSCAD.exe` (editor, preview, customizer) with **Qt 6.10** | **works**; Fusion style, follows the system light/dark theme |
| Linux build (Ubuntu 24.04, distribution packages) | **works**: command line verified with the smoke tests, GUI binary builds with Qt 6.4 (not yet run on a desktop) |

## Build on Windows (5 minutes of your time, about an hour of the computer's)

You need:

1. **Visual Studio 2026** (Community is fine) with the workload *Desktop development with C++*.
   It ships CMake, Ninja and the compiler.
2. **Git** – <https://git-scm.com>.
3. About **15 GB** of free disk space and an internet connection.

Open PowerShell in this directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
```

The script clones vcpkg into `D:\OpenSCAD\vcpkg` (change with `-VcpkgRoot E:\vcpkg`), builds all
libraries – **the first run takes 60–90 minutes**, later runs reuse the binary cache and take
seconds – and then builds OpenSCAD.

Result: `build\x64-headless\openscad.exe` with the required DLLs next to it.

### Try it

```powershell
build\x64-headless\openscad.exe --info
build\x64-headless\openscad.exe -o logo.stl examples\Basics\logo.scad
build\x64-headless\openscad.exe -o logo.png --imgsize=800,600 examples\Basics\logo.scad
powershell -ExecutionPolicy Bypass -File tests\smoke\run-smoke.ps1
```

The build output is self-contained: the resource folders (`color-schemes`, `examples`, `fonts`,
`libraries`, `templates`) and a fontconfig configuration are copied next to the executable, so
`text()` finds the bundled Liberation fonts and the fonts installed in Windows.

### GUI build (Qt 6)

The GUI needs Qt 6 and QScintilla, which are not part of vcpkg here. One script installs both
(Qt 6.10.3 MSVC kit with Multimedia through `aqtinstall`, about 1 GB, plus QScintilla 2.14.1
built from source, a few minutes):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\install-qt6.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1 -Preset x64-gui
```

Result: `build\x64-gui\OpenSCAD.exe` with the Qt runtime deployed next to it (`windeployqt`).
Qt is installed into `D:\OpenSCAD\Qt` by default (`-QtRoot` to change it); if you already have
a Qt 6 MSVC kit, set `QT6_ROOT` to it (for example `C:\Qt\6.10.3\msvc2022_64`) and run only the
QScintilla part of the script. Python 3 must be on `PATH` for `aqtinstall`.

The smoke tests can start the GUI too: `tests\smoke\run-smoke.ps1 -Gui`.

### Open in Visual Studio

*File → Open → Folder* on this directory. Visual Studio reads `CMakePresets.json`; pick the
preset **x64 Headless Release** (or Debug), or **x64 GUI Release** for the Qt build. Set the
environment variables `VCPKG_ROOT` (for example `D:\OpenSCAD\vcpkg`) and, for the GUI,
`QT6_ROOT` (for example `D:\OpenSCAD\Qt\6.10.3\msvc2022_64`) before starting Visual Studio, or
add them to a `CMakeUserPresets.json`.

### Windows installer

Ready-made installers are on the [Releases page](https://github.com/jodynek/openscad-2021.01-modern/releases). To build one yourself
(needs [Inno Setup 6](https://jrsoftware.org/isinfo.php) and both Windows builds):

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
```

Result: `build\installer\OpenSCAD-2021.01-modern-win64-setup.exe` (about 48 MB). It installs the
GUI, `openscad-cli.exe` (the command-line build), the examples, fonts and colour schemes, offers
the `.scad` file association and an optional PATH entry, and bundles the Visual C++ runtime
(installed only when missing). Silent install: `setup.exe /VERYSILENT /NORESTART`
(`/CURRENTUSER` installs per user without administrator rights).

## Build on Linux (Ubuntu 24.04 / Debian 12)

Everything comes from the distribution packages, no vcpkg:

```bash
sudo ./tools/linux-deps.sh            # installs compiler, CMake, CGAL, Qt 6, QScintilla, ...
cmake --preset linux-release          # or linux-headless for the command-line build only
cmake --build --preset linux-release --parallel
./build/linux-release/openscad examples/Basics/logo.scad
```

`tools/linux-deps.sh --check` lists the packages and what is installed. Without root (or on
Windows with Docker Desktop) `tools/linux-docker-check.sh` builds and smoke-tests both Linux
variants in a clean `ubuntu:24.04` container; the binaries and logs land in `build/linux-docker`.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `vcpkg install failed` | Open the log named in the message (`build\x64-headless\vcpkg-manifest-install.log`) and run the script again; finished packages are not rebuilt. |
| `cl.exe` not found | Install the workload *Desktop development with C++* in the Visual Studio Installer. |
| Build stops with `win_flex ... end of file in string` | A rare race in the flex tool; just run the build again. |
| Little disk space | The vcpkg cache lives in `D:\OpenSCAD\vcpkg\archives` and `downloads`; `buildtrees` are deleted after each successful package. |
| `FATAL: unhandled exception: ...` at startup | Report it with the message; it replaces the silent crash of the original code. |

## Repository layout

| Path | Content |
|---|---|
| `src/` | C++ sources (core, geometry, exports, GUI) |
| `CMakeLists.txt`, `CMakePresets.json` | the build |
| `vcpkg.json` | dependency manifest |
| `build-msvc.ps1` | one-command build for Windows |
| `tools/winflexbison/` | flex and bison for Windows |
| `tools/install-qt6.ps1` | installs Qt 6 and builds QScintilla for the GUI |
| `tests/smoke/` | quick regression tests for the command-line build |
| `examples/`, `libraries/`, `fonts/`, `color-schemes/` | resources shipped with OpenSCAD |
| `openscad.pro`, `*.pri`, `features/` | the old qmake build, kept for reference only |

The git history starts with the pristine 2021.01 release, so `git diff <first commit>` shows
every modernization change.

## License

GPL-2.0-or-later, see [COPYING](COPYING). OpenSCAD is © the OpenSCAD developers.
