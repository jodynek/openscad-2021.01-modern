# OpenSCAD 2021.01 – developer documentation

*Česká verze: [DEVELOPMENT.cs.md](DEVELOPMENT.cs.md) · User guide: [README.md](README.md)*

## 1. Goals and principles

* **Simple build**: one script or one CMake preset, every dependency comes from a package
  manager, nothing is installed by hand. If a step needs a workaround, it is documented here or
  it has to go away.
* **Keep 2021.01 behaviour**: same language semantics, same geometry kernel (CGAL 5.6, Nef
  polyhedra). Every change is verified against outputs of the unmodified build.
* **Portable code**: no `if(MSVC)` branches for finding libraries, no Windows-only logic in the
  sources beyond the existing platform layer, so that a Linux build only needs a preset.
* **Two documents, two languages**: `README` for people who want to build and run, `DEVELOPMENT`
  for people who change the code; both exist in English and Czech (`*.cs.md`) and are updated
  together.

## 2. Repository history

The git history starts with the pristine source tarball of the 2021.01 release
(`openscad-2021.01.src.tar.gz`, commit `8b23432`). Everything on top of it is the modernization:

```bash
git diff 8b23432 --stat          # what changed
git diff 8b23432 -- src/value.h  # a single file
```

The old qmake build (`openscad.pro`, `*.pri`, `features/*.prf`, `winconsole/`) is kept
untouched for reference; it is not used.

## 3. Architecture

OpenSCAD is a compiler: a `.scad` script goes through these stages (all in `src/`):

| Stage | Files | Notes |
|---|---|---|
| Lexing / parsing | `lexer.l`, `parser.y`, `comment_lexer.l`, `comment_parser.y` | flex + bison, generated into `build/.../objects/` |
| AST and evaluation | `AST.*`, `expr.*`, `Assignment.*`, `func.cc`, `control.cc`, `context.*`, `evalcontext.*`, `builtin*.cc`, `value.*` | `Value` is a `std::variant` of undef/bool/number/string/vector/range/function |
| Node tree | `node.*`, `primitives.cc`, `transform.cc`, `csgops.cc`, `linearextrude.cc`, `rotateextrude.cc`, `import.cc`, `text.cc`, `surface.cc`, `projection.cc`, `offset.cc` | one class per language module |
| Geometry | `GeometryEvaluator.*`, `cgalutils*.cc`, `CGAL_Nef_polyhedron.*`, `Polygon2d*.cc`, `polyset*.cc`, `clipper-utils.cc`, `ext/libtess2`, `ext/polyclipping` | 3D booleans in CGAL, 2D in Clipper, tessellation in libtess2 / CGAL |
| CSG tree for preview | `CSGTreeEvaluator.*`, `CSGTreeNormalizer.*`, `csgnode.*` | used by OpenCSG preview and PNG export |
| Rendering | `OffscreenContextWGL.cc` (Windows), `OffscreenContextGLX.cc` (Linux), `OffscreenView.cc`, `GLView.cc`, `OpenCSGRenderer.cc`, `CGALRenderer.cc`, `ThrownTogetherRenderer.cc`, `fbo.cc`, `system-gl.*` | GLEW + OpenCSG; `NULLGL` builds without OpenGL |
| Export / import | `export*.cc`, `import*.cc`, `libsvg/`, `ext/lodepng` | STL, OFF, AMF, 3MF (needs lib3mf, off on MSVC), DXF, SVG, PDF (cairo), PNG |
| Platform | `PlatformUtils*.cc`, `fileutils.*`, `utf8utils.h`, `FontCache.*`, `FreetypeRenderer.*` | paths, fonts (fontconfig + freetype + harfbuzz) |
| Command line | `openscad.cc` | option parsing (Boost.Program_options), export dispatch, `main()` |
| GUI (only when `HEADLESS=OFF`) | `mainwin.cc`, `MainWindow.h`, `QGLView.*`, `scintillaeditor.*`, `Preferences.*`, `parameter/`, `input/`, `*.ui` | Qt 6 widgets + QScintilla 2.14; `QGLView` is a `QOpenGLWidget` |

`doc/OpenSCAD-*.pdf` contain the original class and pipeline diagrams.

## 4. Build system

### 4.1 CMake

`CMakeLists.txt` is the only build definition. Important points:

* `cmake_minimum_required(3.5)` plus `CMAKE_POLICY_VERSION_MINIMUM=3.5` in the presets, because
  CMake 4 refuses older policy versions (several dependency configs still declare them).
* Options: `HEADLESS` (no Qt; ON in all presets today), `NULLGL`, `EXPERIMENTAL`, `SNAPSHOT`,
  `PROFILE`, `IDPREFIX`, `ENABLE_TESTS` (the upstream `tests/` tree; OFF on MSVC because
  `tests/diffpng.cpp` does not compile there), `OPENSCAD_VERSION` (shown by `--version`;
  the presets set `2021.01`, default is the build date).
* Dependencies are found through imported targets (`CGAL::CGAL`, `Boost::program_options`,
  `GLEW::GLEW`, `harfbuzz::harfbuzz`, `Fontconfig::Fontconfig`, `Intl::Intl`, `Eigen3::Eigen`,
  `double-conversion::double-conversion`, `LibXml2`, `Freetype`) or the project's own find
  modules in `cmake/Modules` (cairo, libzip). The MSVC branch and the Unix branch still exist
  for historical reasons; merging them is part of the Linux stage.
* flex/bison run as explicit `add_custom_command`s inside a Ninja job pool of size 1:
  winflexbison uses fixed temp-file names and two concurrent runs corrupt each other.
* On MSVC the headless executable is linked as a console program (`-subsystem:console`),
  named `openscad.exe`; the GUI build keeps `-subsystem:windows`.
* vcpkg's `VCPKG_APPLOCAL_DEPS` copies the needed DLLs next to the executable after linking.
* A post-build step copies the resource folders (`color-schemes`, `examples`, `fonts`,
  `libraries`, `templates`) next to the executable, because `PlatformUtils::lookupResourcesPath`
  searches `.`, `../share/openscad` and `..` relative to it. On Windows it also installs
  `fonts/fonts.conf.windows` as `fonts/fonts.conf` (fontconfig has no system configuration
  there; `FontCache` points `FONTCONFIG_PATH` at that folder). `locale/` is not copied: the
  `.po` files would need `msgfmt`, translations are a later task.

### 4.2 Presets (`CMakePresets.json`)

| Preset | Generator | Purpose |
|---|---|---|
| `x64-headless` | Ninja, cl.exe, Release | the command-line build |
| `x64-headless-debug` | Ninja, cl.exe, Debug | debugging in Visual Studio |
| `x64-gui` | Ninja, cl.exe, Release, `HEADLESS=OFF` | the Qt 6 GUI; needs `QT6_ROOT` (environment variable, auto-detected by `build-msvc.ps1`) |
| `x64-gui-debug` | Ninja, cl.exe, Debug, `HEADLESS=OFF` | GUI debugging |
| `linux-headless` | Ninja, system compiler, Release | command-line build from distribution packages |
| `linux-release` / `linux-debug` | Ninja, system compiler, `HEADLESS=OFF` | GUI with the distribution's Qt 6 and QScintilla |

The `x64-*` presets are only offered on Windows and the `linux-*` presets only on Linux
(`condition` on `hostSystemName`). The Windows presets inherit `x64-msvc-base`: vcpkg toolchain from `$env{VCPKG_ROOT}`, triplet `x64-windows`,
flags `/EHsc /permissive- /bigobj /Zc:wchar_t`, defines `NOMINMAX`,
`_CRT_SECURE_NO_WARNINGS`, `YY_NO_UNISTD_H`, and the flex/bison paths in `tools/winflexbison`.

### 4.3 vcpkg manifest (`vcpkg.json`)

`builtin-baseline` points at a current vcpkg commit; the binary cache lives in
`D:\OpenSCAD\vcpkg\archives`. Two versions are overridden on purpose:

| Package | Pinned | Why |
|---|---|---|
| `cgal` | 5.6.1 | CGAL 6 requires C++17 *and* removed API used here (`Triangulation_2_filtered_projection_traits_3`, Nef changes). Moving to CGAL 6 is a separate task. |
| `opencsg` | 1.4.2 | The vcpkg port of OpenCSG 1.8 does not compile its bundled GLAD loader, so the static library does not link (`OpenCSG::gladLoaderLoadGL` unresolved). |

`build-msvc.ps1` sets `CMAKE_POLICY_VERSION_MINIMUM=3.5` and passes it to the port builds
(`VCPKG_KEEP_ENV_VARS`) because vcpkg builds ports with its own CMake 4.

### 4.3b Linux

`tools/linux-deps.sh` holds the apt package list (Ubuntu 24.04: CGAL 5.6, Boost 1.83, Qt 6.4,
QScintilla 2.14, OpenCSG 1.5, lib3mf 1.8). lib3mf is optional (`find_package(Lib3MF QUIET)`),
so 3MF support depends on the package being installed. `tools/linux-docker-check.sh` runs the
whole Linux build (`linux-headless`, then `linux-release`) plus the smoke scripts inside a
clean `ubuntu:24.04` container and copies binaries and logs to `build/linux-docker`; it is the
reference for CI and the way the Linux build is verified from Windows.

### 4.3c Windows installer

`installer/openscad.iss` (Inno Setup 6) packages the `x64-gui` build output (executable, DLLs,
Qt plugin folders, resource folders) plus the `x64-headless` executable as `openscad-cli.exe`
(both builds share the same DLL set). It registers the `.scad` association (`HKA`, so it works
for admin and per-user installs), optionally adds the folder to `PATH` (`[Code]` section), and
bundles `vc_redist.x64.exe` from the Visual Studio installation, run only when the installed
14.x runtime is missing or older than the build toolset (`VCRedistNeeded`).
`installer/build-installer.ps1` locates ISCC and the redistributable and compiles the script;
the output is `build/installer/OpenSCAD-<version>-modern-win64-setup.exe`. Silent install and
uninstall are the standard Inno switches (`/VERYSILENT /NORESTART`, `/CURRENTUSER`).

### 4.3d Continuous integration and code signing

`.github/workflows/windows.yml` (windows-latest, Visual Studio 2022) runs `build-msvc.ps1` for
`x64-headless` and `x64-gui`, the smoke tests (`-SkipOpenGL`: the runner has no usable OpenGL
or desktop), `installer/build-installer.ps1`, and uploads the installer as an artifact; on a
`v*` tag it also creates the GitHub release with the installer attached. vcpkg binaries live
in the Actions cache (`VCPKG_BINARY_SOURCES=x-gha`), Qt and QScintilla in `actions/cache`,
so only the first run takes about an hour. `.github/workflows/linux.yml` (ubuntu-24.04)
installs the apt packages, builds both Linux presets and runs `tests/smoke/run-smoke.sh`.

**Code signing** is prepared for [SignPath Foundation](https://signpath.org/foundation) (free
for open source): when the repository has the secret `SIGNPATH_API_TOKEN` and the variables
`SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_POLICY_SLUG`, the Windows
workflow submits the installer artifact to SignPath after the build and publishes the signed
copy (`*-signed` artifact and the release asset). Without them the step is skipped and the
unsigned installer is published. Alternatives are Azure Trusted Signing or a classic OV/EV
certificate used through Inno Setup's `SignTool` directive and `signtool.exe` on the two
executables before packaging.

### 4.4 Tools outside vcpkg

`tools/winflexbison/` – flex 2.6.4 and bison 3.8.2 for Windows (lexxmark/winflexbison 2.5.25).
vcpkg has no package for them (it only uses them internally).

`tools/install-qt6.ps1` – Qt 6 and QScintilla for the GUI. Qt comes from the official Qt
download servers through `aqtinstall` (kit `win64_msvc2022_64`, module `qtmultimedia`; 6.10.3
because `aqtinstall` 3.3 does not understand the repository layout of 6.11+). QScintilla 2.14.1
is built from the Riverbank source tarball with the kit's `qmake` + `nmake` and installed into
the kit (`lib/qscintilla2_qt6.lib`, `lib/qscintilla2_qt6.dll`, `include/Qsci`).
`cmake/Modules/FindQScintilla.cmake` finds it there and exports `QScintilla::QScintilla`
(with the `QSCINTILLA_DLL` define needed on Windows). A `windeployqt` post-build step copies
the Qt DLLs, the platform plugin and the QScintilla DLL (scanned too, it needs
`Qt6PrintSupport`) next to `OpenSCAD.exe`.

## 5. Dependencies

| Library | Used for | Where |
|---|---|---|
| CGAL 5.6 + GMP + MPFR | exact 3D booleans (Nef polyhedra), hull, minkowski, 2D triangulation | `cgalutils*.cc`, `CGAL_Nef_polyhedron.*` |
| Eigen 3/5 | vectors, matrices, transforms | `linalg.h` everywhere |
| Boost (header-only: algorithm, assign, bind, circular_buffer, format, functional, fusion, lexical_cast, logic, property_tree, range, spirit, tokenizer) | string helpers, number formatting, JSON parameter sets | many files |
| Boost.Program_options (compiled) | command-line parsing | `openscad.cc` |
| GLEW + OpenCSG + OpenGL | preview rendering, PNG export | `*Renderer.cc`, `GLView.cc` |
| freetype + harfbuzz + fontconfig | `text()` | `FreetypeRenderer.cc`, `FontCache.cc` |
| libintl (gettext-libintl) | translations of messages (`_()` macro) | `printutils.h` |
| libxml2 | SVG and AMF import | `libsvg/`, `import_amf.cc` |
| libzip | compressed AMF import | `import_amf.cc` |
| cairo | PDF export | `export_pdf.cc` |
| double-conversion | shortest exact number printing | `value.cc` |
| lodepng, libtess2, polyclipping (Clipper 6) | vendored in `src/ext/` | |
| Qt 6.10 (Core, Gui, Widgets, OpenGL, OpenGLWidgets, Concurrent, Network, Multimedia) + QScintilla 2.14 | GUI only (`HEADLESS=OFF`) | not part of the manifest, see section 4.4 |

Removed compared to 2021.01: **GLib** (replaced by `src/utf8utils.h`), **Boost.Filesystem**
(`std::filesystem`), **Boost.Regex** (`std::regex`, and plain parsing in `import_stl.cc`),
**Boost.Variant** (`std::variant`), **Boost.Optional** in the core (`std::optional`; the
customizer still uses `boost::optional<ptree&>` because Boost.Property_tree returns it).

## 6. Changes compared to 2021.01

| File(s) | Change | Reason |
|---|---|---|
| `CMakeLists.txt`, `CMakePresets.json`, `vcpkg.json`, `build-msvc.ps1` | new build system | see section 4 |
| `src/linalg.h` | `#if defined(EIGEN_HAS_CXX11_CONTAINERS)` guard | macro removed in Eigen 5; `#warning` is a hard error on MSVC |
| `src/system-gl.h` | `<windows.h>` before GLEW, `#undef DIFFERENCE` | GLEW 2.3 no longer leaves `APIENTRY` defined for `GL/glu.h`; `DIFFERENCE` from winuser.h clashes with `OpenSCADOperator::DIFFERENCE` |
| `src/cgalutils-tess.cc` | `Filtered_projection_traits_3` for CGAL ≥ 5.4 | renamed in CGAL |
| `src/cgalutils-polyhedron.cc` | local `generic_print_polyhedron` | removed from CGAL 5 |
| `src/openscad.cc` | `boost::algorithm::join` qualified; `main()` wrapped in try/catch; `std::optional` | ambiguity under MSVC; silent fail-fast on uncaught exceptions |
| `src/FreetypeRenderer.h`, `src/node.cc`, `src/exceptions.h`, `src/feature.*`, `src/libsvg/libsvg.h`, `src/Network.h` | C++17 cleanups | `std::unary_function`, `std::mem_fun`, `throw()` |
| `src/utf8utils.h` + `FreetypeRenderer.cc`, `func.cc`, `value.*`, `lexer.l`, `LibraryInfo.cc` | own UTF-8 helpers | GLib removed; `unichar_validate` deliberately accepts non-characters like GLib does |
| 35 files | `std::filesystem` | Boost.Filesystem removed; `fs_last_write_time()` in `fileutils.h` returns seconds for cache keys |
| `src/parsersettings.cc` | skip empty library paths | `std::filesystem::absolute("")` throws on Windows; Boost silently used the current directory (which therefore no longer appears in the library path) |
| `src/FileModule.cc`, `src/Geometry.h` | `is_regular_file`, `<cassert>` | removed Boost alias, missing include |
| `src/comment.cpp`, `handle_dep.cc`, `nodedumper.cc`, `PlatformUtils-posix.cc`, `import_stl.cc` | `std::regex` / string operations | Boost.Regex removed; STL import parses lines without regex (faster) |
| `src/value.h`, `src/value.cc` | `std::variant`, `std::visit`, `std::get_if` | Boost.Variant removed |
| `src/color.cc` | `std::optional` | Boost.Optional removed from the core |
| `src/scintillaeditor.cpp`, `editor.cc`, `Preferences.cc`, `parameter/parametervirtualwidget.cpp` | `QRegularExpression`, `QWheelEvent::angleDelta()` | `QRegExp` and `QWheelEvent::delta()` do not exist in Qt 6 |
| `src/mainwin.cc`, `MainWindow.h` | `QScreen` geometry, `QSoundEffect`, `QElapsedTimer`, `Qt::CTRL \| ...`, `palette().window()`, `setTabStopDistance`, no `setCodec` | `QDesktopWidget`, `QSound`, `QTime::elapsed`, `Qt::Modifier +`, `QPalette::background`, `setTabStopWidth`, `QTextStream::setCodec` removed in Qt 6 |
| `src/LibraryInfoDialog.cc`, `FontListTableView.cc`, `ProgressWidget.*`, `QGLView.cc`, `tabmanager.cc`, `openscad.cc` | `QStringView`, `horizontalAdvance`, `QElapsedTimer`, `QWheelEvent::position()`, no `setCodec`, no `QTextCodec` | same reason |
| `CMakeLists.txt` (GUI block), `cmake/Modules/FindQScintilla.cmake`, `tools/install-qt6.ps1` | Qt 6 build, QScintilla lookup, Qt installation | replaces the Qt 5 / `FindQt5QScintilla.cmake` logic; Qt Gamepad has no Qt 6 version, that input driver is gone |
| `src/openscad.cc` (`gui()`), `src/Preferences.cc` | Fusion style, defaults follow `QStyleHints::colorScheme()` | the Windows platform styles stay light under a dark system theme; Fusion is dark-mode aware and identical on Linux. Dark system → defaults "For Dark Background" (editor) and "Tomorrow Night" (3D view); stored preferences win. `QT_STYLE_OVERRIDE` still works. |
| `CMakeLists.txt` (post-build), `fonts/fonts.conf.windows` | resource folders and fontconfig file next to the executable | see section 4.1; also fixes the empty Examples menu and the missing colour schemes in a build tree |
| `src/launchingscreen.ui`, `src/launchingscreen.cc` | welcome screen without the background bitmap and hand-made green gradients; standard buttons, 256 px logo | follows the palette (light/dark) and HiDPI like every other window |
| `src/func.cc` (`search()` with a vector table), `src/parsersettings.h` | string kept alive before taking `c_str()`; `#include <vector>` | found by the Linux build: the original code used a dangling pointer (undefined behaviour; on Windows table lookups silently never matched, on Linux they did), and MSVC headers include `<vector>` transitively while GCC does not |
| `tests/smoke/` | new | regression tests, see section 7 |

## 7. Testing

`tests/smoke/run-smoke.ps1` runs the headless executable on a handful of scripts and compares:

* `echo` output of `lang.scad` (arithmetic, comparisons, vectors, ranges, strings, functions),
  `utf8.scad` and `esc.scad` (Unicode indexing, `ord`/`chr`, `search`, escape sequences) and
  `main.scad` (`include`/`use`/`import` with relative paths) against `expected/*.echo`,
* facet counts of STL exports (`logo.scad` = 5892, `tetra.stl` import = 4, …),
* a PNG export through the offscreen OpenGL context,
* with `-Gui`: the Qt GUI is started with an example and must show its main window.

The expected files were produced by the unmodified 2021.01 code built with the same libraries,
so a passing run means behaviour parity. STL files are not compared byte for byte: facet order
is not deterministic even in the original code.

The upstream regression suite (`tests/CMakeLists.txt`, ~1000 image comparisons) is not usable on
MSVC yet (`ENABLE_TESTS=OFF`); it is the natural next step once the GUI build exists.

## 8. Roadmap

1. **GUI with Qt 6** – done (see sections 4.4 and 6). Still open: install/packaging rules for
   `examples/`, `fonts/`, `color-schemes/`, `libraries/`, `locale/` (the program currently
   reads them from the source tree next to the build directory), and the upstream regression
   suite.
2. **Look and feel** – done for the basics (Fusion, system light/dark, dark defaults, palette
   based welcome screen). Open: one consistent SVG icon set (the toolbars mix two bitmap sets
   chosen by palette lightness in `MainWindow::initActionIcon`), HiDPI icon sizes, and a
   Preferences page that is less crowded.
3. **Linux** – done: presets, `tools/linux-deps.sh`, `tools/linux-docker-check.sh`; headless
   build and smoke tests pass in a clean Ubuntu 24.04 container, the GUI binary builds against
   Qt 6.4 / QScintilla 2.14 from the distribution. Open: running the GUI on a Linux desktop,
   merging the MSVC/Unix dependency branches in `CMakeLists.txt`, a CI matrix (Windows MSVC +
   Ubuntu) built on the two scripts.
4. **Later** – CGAL 6 or Manifold, Clipper 2, CPack installers.

## 9. Conventions

* C++17, `/permissive-` on MSVC; code must also compile with GCC/Clang.
* No new Windows-only code outside `PlatformUtils-win.cc` / `OffscreenContextWGL.cc`.
* Formatting follows `.clang-format` (tabs, as in the original sources).
* Every change that can alter output is checked with `tests/smoke/run-smoke.ps1`; extend the
  tests when you touch the evaluator or an exporter.
* Documentation: update `README*.md` and `DEVELOPMENT*.md` in both languages in the same change.
