# OpenSCAD 2021.01 – dokumentace pro vývojáře

*English version: [DEVELOPMENT.md](DEVELOPMENT.md) · Uživatelský návod: [README.cs.md](README.cs.md)*

## 1. Cíle a zásady

* **Jednoduchý build**: jeden skript nebo jeden CMake preset, každá závislost z balíčkovače,
  nic se neinstaluje ručně. Pokud nějaký krok potřebuje obezličku, je zde popsaná, nebo musí zmizet.
* **Zachovat chování 2021.01**: stejná sémantika jazyka, stejné geometrické jádro (CGAL 5.6, Nef
  polyhedra). Každá změna se ověřuje proti výstupům nezměněného buildu.
* **Přenositelný kód**: žádné větve `if(MSVC)` pro hledání knihoven, žádná nová logika jen pro
  Windows mimo stávající platformovou vrstvu, aby Linux build potřeboval jen preset.
* **Dva dokumenty, dva jazyky**: `README` pro ty, kdo chtějí přeložit a spustit, `DEVELOPMENT`
  pro ty, kdo mění kód; oba anglicky i česky (`*.cs.md`) a aktualizují se společně.

## 2. Historie repozitáře

Historie gitu začíná čistým zdrojovým archivem release 2021.01
(`openscad-2021.01.src.tar.gz`, commit `8b23432`). Vše nad ním je modernizace:

```bash
git diff 8b23432 --stat          # co se změnilo
git diff 8b23432 -- src/value.h  # jeden soubor
```

Starý qmake build (`openscad.pro`, `*.pri`, `features/*.prf`, `winconsole/`) je ponechán
nedotčený jen pro referenci; nepoužívá se.

## 3. Architektura

OpenSCAD je kompilátor: skript `.scad` prochází těmito stupni (vše v `src/`):

| Stupeň | Soubory | Poznámka |
|---|---|---|
| Lexer / parser | `lexer.l`, `parser.y`, `comment_lexer.l`, `comment_parser.y` | flex + bison, generuje se do `build/.../objects/` |
| AST a vyhodnocení | `AST.*`, `expr.*`, `Assignment.*`, `func.cc`, `control.cc`, `context.*`, `evalcontext.*`, `builtin*.cc`, `value.*` | `Value` je `std::variant` undef/bool/číslo/řetězec/vektor/range/funkce |
| Strom uzlů | `node.*`, `primitives.cc`, `transform.cc`, `csgops.cc`, `linearextrude.cc`, `rotateextrude.cc`, `import.cc`, `text.cc`, `surface.cc`, `projection.cc`, `offset.cc` | jedna třída na modul jazyka |
| Geometrie | `GeometryEvaluator.*`, `cgalutils*.cc`, `CGAL_Nef_polyhedron.*`, `Polygon2d*.cc`, `polyset*.cc`, `clipper-utils.cc`, `ext/libtess2`, `ext/polyclipping` | 3D booleovské operace v CGAL, 2D v Clipperu, teselace libtess2 / CGAL |
| CSG strom pro náhled | `CSGTreeEvaluator.*`, `CSGTreeNormalizer.*`, `csgnode.*` | používá OpenCSG náhled a PNG export |
| Rendering | `OffscreenContextWGL.cc` (Windows), `OffscreenContextGLX.cc` (Linux), `OffscreenView.cc`, `GLView.cc`, `OpenCSGRenderer.cc`, `CGALRenderer.cc`, `ThrownTogetherRenderer.cc`, `fbo.cc`, `system-gl.*` | GLEW + OpenCSG; `NULLGL` staví bez OpenGL |
| Export / import | `export*.cc`, `import*.cc`, `libsvg/`, `ext/lodepng` | STL, OFF, AMF, 3MF (lib3mf, na MSVC vypnuto), DXF, SVG, PDF (cairo), PNG |
| Platforma | `PlatformUtils*.cc`, `fileutils.*`, `utf8utils.h`, `FontCache.*`, `FreetypeRenderer.*` | cesty, fonty (fontconfig + freetype + harfbuzz) |
| Příkazová řádka | `openscad.cc` | parsování voleb (Boost.Program_options), export, `main()` |
| GUI (jen při `HEADLESS=OFF`) | `mainwin.cc`, `MainWindow.h`, `QGLView.*`, `scintillaeditor.*`, `Preferences.*`, `parameter/`, `input/`, `*.ui` | Qt 6 widgets + QScintilla 2.14; `QGLView` je `QOpenGLWidget` |

`doc/OpenSCAD-*.pdf` obsahují původní diagramy tříd a pipeline.

## 4. Build systém

### 4.1 CMake

`CMakeLists.txt` je jediná definice buildu. Důležité body:

* `cmake_minimum_required(3.5)` plus `CMAKE_POLICY_VERSION_MINIMUM=3.5` v presetech, protože
  CMake 4 odmítá starší verze politik (několik konfigurací závislostí je stále deklaruje).
* Volby: `HEADLESS` (bez Qt; dnes ON ve všech presetech), `NULLGL`, `EXPERIMENTAL`, `SNAPSHOT`,
  `PROFILE`, `IDPREFIX`, `ENABLE_TESTS` (upstream strom `tests/`; na MSVC OFF, protože
  `tests/diffpng.cpp` se tam nepřeloží), `OPENSCAD_VERSION` (zobrazí `--version`; presety
  nastavují `2021.01`, výchozí je datum buildu).
* Závislosti se hledají přes importované cíle (`CGAL::CGAL`, `Boost::program_options`,
  `GLEW::GLEW`, `harfbuzz::harfbuzz`, `Fontconfig::Fontconfig`, `Intl::Intl`, `Eigen3::Eigen`,
  `double-conversion::double-conversion`, `LibXml2`, `Freetype`) nebo vlastní find moduly
  v `cmake/Modules` (cairo, libzip). Větev MSVC a větev Unix z historických důvodů stále
  existují; jejich sloučení patří do etapy Linux.
* flex/bison běží jako explicitní `add_custom_command` v Ninja job poolu velikosti 1:
  winflexbison používá pevné názvy dočasných souborů a dva souběžné běhy se vzájemně poškodí.
* Na MSVC je headless exe linkováno jako konzolový program (`-subsystem:console`) se jménem
  `openscad.exe`; GUI build zůstává `-subsystem:windows`.
* `VCPKG_APPLOCAL_DEPS` z vcpkg zkopíruje po linkování potřebné DLL vedle exe.
* Post-build krok kopíruje vedle exe složky se zdroji (`color-schemes`, `examples`, `fonts`,
  `libraries`, `templates`), protože `PlatformUtils::lookupResourcesPath` hledá `.`,
  `../share/openscad` a `..` relativně k němu. Na Windows navíc nainstaluje
  `fonts/fonts.conf.windows` jako `fonts/fonts.conf` (fontconfig tam nemá systémovou konfiguraci;
  `FontCache` na tu složku nastaví `FONTCONFIG_PATH`). `locale/` se nekopíruje: soubory `.po`
  by potřebovaly `msgfmt`, překlady jsou pozdější úkol.

### 4.2 Presety (`CMakePresets.json`)

| Preset | Generátor | Účel |
|---|---|---|
| `x64-headless` | Ninja, cl.exe, Release | příkazový build |
| `x64-headless-debug` | Ninja, cl.exe, Debug | ladění ve Visual Studiu |
| `x64-gui` | Ninja, cl.exe, Release, `HEADLESS=OFF` | Qt 6 GUI; potřebuje `QT6_ROOT` (proměnná prostředí, `build-msvc.ps1` ji najde sám) |
| `x64-gui-debug` | Ninja, cl.exe, Debug, `HEADLESS=OFF` | ladění GUI |
| `linux-headless` | Ninja, systémový kompilátor, Release | příkazový build z distribučních balíčků |
| `linux-release` / `linux-debug` | Ninja, systémový kompilátor, `HEADLESS=OFF` | GUI s Qt 6 a QScintillou z distribuce |

Presety `x64-*` se nabízejí jen na Windows a `linux-*` jen na Linuxu (`condition` na
`hostSystemName`). Windows presety dědí z `x64-msvc-base`: vcpkg toolchain z `$env{VCPKG_ROOT}`, triplet `x64-windows`,
flagy `/EHsc /permissive- /bigobj /Zc:wchar_t`, definice `NOMINMAX`,
`_CRT_SECURE_NO_WARNINGS`, `YY_NO_UNISTD_H` a cesty k flex/bison v `tools/winflexbison`.

### 4.3 vcpkg manifest (`vcpkg.json`)

`builtin-baseline` ukazuje na aktuální commit vcpkg; binární cache je v
`D:\OpenSCAD\vcpkg\archives`. Dvě verze jsou záměrně přepsané:

| Balíček | Verze | Proč |
|---|---|---|
| `cgal` | 5.6.1 | CGAL 6 vyžaduje C++17 *a* odstranil zde používané API (`Triangulation_2_filtered_projection_traits_3`, změny Nef). Přechod na CGAL 6 je samostatný úkol. |
| `opencsg` | 1.4.2 | vcpkg port OpenCSG 1.8 nepřekládá bundlovaný GLAD loader, statická knihovna se nelinkuje (`OpenCSG::gladLoaderLoadGL`). |

`build-msvc.ps1` nastaví `CMAKE_POLICY_VERSION_MINIMUM=3.5` a propustí ji do buildů portů
(`VCPKG_KEEP_ENV_VARS`), protože vcpkg staví porty vlastním CMake 4.

### 4.3b Linux

`tools/linux-deps.sh` obsahuje seznam apt balíčků (Ubuntu 24.04: CGAL 5.6, Boost 1.83, Qt 6.4,
QScintilla 2.14, OpenCSG 1.5, lib3mf 1.8). lib3mf je volitelný (`find_package(Lib3MF QUIET)`),
podpora 3MF tedy závisí na tom, zda je balíček nainstalován. `tools/linux-docker-check.sh`
spustí celý linuxový build (`linux-headless`, pak `linux-release`) plus smoke skripty v čistém
kontejneru `ubuntu:24.04` a zkopíruje binárky a logy do `build/linux-docker`; je to reference
pro CI a způsob, jak se Linux build ověřuje z Windows.

### 4.3c Instalátor pro Windows

`installer/openscad.iss` (Inno Setup 6) balí výstup buildu `x64-gui` (exe, DLL, složky Qt
pluginů, složky se zdroji) plus exe z `x64-headless` jako `openscad-cli.exe` (oba buildy sdílejí
stejnou sadu DLL). Registruje asociaci `.scad` (`HKA`, funguje pro instalaci správcem i pro
uživatele), volitelně přidá složku do `PATH` (sekce `[Code]`) a obsahuje `vc_redist.x64.exe`
z instalace Visual Studia, který se spustí jen když nainstalovaný runtime 14.x chybí nebo je
starší než toolset buildu (`VCRedistNeeded`). `installer/build-installer.ps1` najde ISCC
a redistributable a skript přeloží; výstup je
`build/installer/OpenSCAD-<verze>-modern.<N>-win64-setup.exe` (N = `ModernRelease` v .iss, stejné číslo jako `OPENSCAD_MODERN_RELEASE` v CMake). Tichá instalace a odinstalace jsou
standardní přepínače Inno (`/VERYSILENT /NORESTART`, `/CURRENTUSER`).

### 4.3d Průběžná integrace a podepisování kódu

`.github/workflows/windows.yml` (windows-latest, Visual Studio 2022) spouští `build-msvc.ps1`
pro `x64-headless` a `x64-gui`, smoke testy (`-SkipOpenGL`: runner nemá použitelný OpenGL ani
desktop), `installer/build-installer.ps1` a nahraje instalátor jako artefakt; při tagu `v*`
také vytvoří GitHub release s instalátorem. Binárky vcpkg jsou v Actions cache
(`VCPKG_BINARY_SOURCES=x-gha`), Qt a QScintilla v `actions/cache`, takže jen první běh trvá
zhruba hodinu. `.github/workflows/linux.yml` (ubuntu-24.04) nainstaluje apt balíčky, přeloží
oba linuxové presety a spustí `tests/smoke/run-smoke.sh`.

**Podepisování kódu** je připravené pro [SignPath Foundation](https://signpath.org/foundation)
(zdarma pro open source): pokud má repozitář secret `SIGNPATH_API_TOKEN` a proměnné
`SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_POLICY_SLUG`, Windows workflow
po buildu odešle artefakt s instalátorem do SignPath a zveřejní podepsanou kopii (artefakt
`*-signed` a asset release). Bez nich se krok přeskočí a zveřejní se nepodepsaný instalátor.
Alternativy jsou Azure Trusted Signing nebo klasický OV/EV certifikát přes direktivu
`SignTool` v Inno Setupu a `signtool.exe` na obou exe před zabalením.

Co SignPath Foundation od projektu vyžaduje, je připraveno: sekce „Code signing policy"
v `README.md` (role v týmu, prohlášení o soukromí, povinná věta), veřejný CI build a Windows
version resource. `openscad_win32.rc.in` CMake konfiguruje do build adresáře (jen MSVC) a dává
oběma exe ikonu, `ProductName` (`OPENSCAD_PRODUCT_NAME`, výchozí `OpenSCAD 2021.01 Modern`),
`ProductVersion` (`<verze>-modern.<OPENSCAD_MODERN_RELEASE>`) a `FileVersion`
(`2021.1.<N>.0`); instalátor nese stejné hodnoty v direktivách `VersionInfo*`
(`/DModernRelease=N`). SignPath vyžaduje shodný název a verzi produktu ve všech podepsaných
souborech. Připravené odpovědi do formuláře žádosti jsou v `installer/signpath-application.md`.

### 4.3e Stránka programu na jodynek.cz

Stránka o programu na <https://jodynek.cz/programs/openscad/> je verzovaná zde ve
`www/openscad/` (`index.html` česky, `en.html` anglicky, `historie.html` / `history.html` s celou
historií změn, `changelog.json`, `img/`), ve stejném rozložení jako stránky jCmd a jNotepadu.
Na webovém sdílení se nic neupravuje přímo. `publish-www.ps1` (po `build-installer.ps1`) převede
položku `next` v `changelog.json` na vydávanou verzi, nahraje instalátor se SHA-256 do
`programs/openscad/releases/`, zkopíruje stránky s `?v=<verze>` u obrázků a PDF (proti
mezipaměti prohlížeče), aktualizuje `programs/manifest.json`, záložní seznam v `index.html` webu
a `HISTORIE-WEBU.md`, zapíše web do jeho vlastního gitu (`E:\Web\git-web.cmd`, push na GitLab;
`tools/sync-web-history.ps1` ho nejdřív srovná) a výsledek zkontroluje přes HTTPS. Před každým
vydáním doplňte změny do položky `next` v `changelog.json` (česky i anglicky) a zvyšte
`ModernRelease` / `OPENSCAD_MODERN_RELEASE`.

### 4.4 Nástroje mimo vcpkg

`tools/winflexbison/` – flex 2.6.4 a bison 3.8.2 pro Windows (lexxmark/winflexbison 2.5.25).
vcpkg pro ně balíček nemá (používá je jen interně).

`tools/install-qt6.ps1` – Qt 6 a QScintilla pro GUI. Qt se stahuje z oficiálních serverů Qt
přes `aqtinstall` (kit `win64_msvc2022_64`, modul `qtmultimedia`; verze 6.10.3, protože
`aqtinstall` 3.3 nerozumí rozložení repozitáře verzí 6.11+). QScintilla 2.14.1 se překládá ze
zdrojového archivu Riverbank pomocí `qmake` + `nmake` z kitu a instaluje do kitu
(`lib/qscintilla2_qt6.lib`, `lib/qscintilla2_qt6.dll`, `include/Qsci`).
`cmake/Modules/FindQScintilla.cmake` ji tam najde a exportuje `QScintilla::QScintilla`
(s definicí `QSCINTILLA_DLL`, kterou Windows potřebuje). Post-build krok `windeployqt` kopíruje
vedle `OpenSCAD.exe` Qt DLL, platform plugin a QScintilla DLL (tu také skenuje, potřebuje
`Qt6PrintSupport`).

## 5. Závislosti

| Knihovna | K čemu | Kde |
|---|---|---|
| CGAL 5.6 + GMP + MPFR | přesné 3D booleovské operace (Nef polyhedra), hull, minkowski, 2D triangulace | `cgalutils*.cc`, `CGAL_Nef_polyhedron.*` |
| Eigen 3/5 | vektory, matice, transformace | `linalg.h` všude |
| Boost (hlavičkové: algorithm, assign, bind, circular_buffer, format, functional, fusion, lexical_cast, logic, property_tree, range, spirit, tokenizer) | řetězcové pomůcky, formátování čísel, JSON sady parametrů | mnoho souborů |
| Boost.Program_options (kompilovaný) | parsování příkazové řádky | `openscad.cc` |
| GLEW + OpenCSG + OpenGL | náhled, PNG export | `*Renderer.cc`, `GLView.cc` |
| freetype + harfbuzz + fontconfig | `text()` | `FreetypeRenderer.cc`, `FontCache.cc` |
| libintl (gettext-libintl) | překlady hlášení (makro `_()`) | `printutils.h` |
| libxml2 | import SVG a AMF | `libsvg/`, `import_amf.cc` |
| libzip | import komprimovaného AMF | `import_amf.cc` |
| cairo | export PDF | `export_pdf.cc` |
| double-conversion | nejkratší přesný tisk čísel | `value.cc` |
| lodepng, libtess2, polyclipping (Clipper 6) | přibalené v `src/ext/` | |
| Qt 6.10 (Core, Gui, Widgets, OpenGL, OpenGLWidgets, Concurrent, Network, Multimedia) + QScintilla 2.14 | jen GUI (`HEADLESS=OFF`) | není v manifestu, viz kapitola 4.4 |

Oproti 2021.01 odstraněno: **GLib** (nahrazen `src/utf8utils.h`), **Boost.Filesystem**
(`std::filesystem`), **Boost.Regex** (`std::regex`, v `import_stl.cc` ruční parsování),
**Boost.Variant** (`std::variant`), **Boost.Optional** v jádru (`std::optional`; customizer stále
používá `boost::optional<ptree&>`, protože ho vrací Boost.Property_tree).

## 6. Změny oproti 2021.01

| Soubor(y) | Změna | Důvod |
|---|---|---|
| `CMakeLists.txt`, `CMakePresets.json`, `vcpkg.json`, `build-msvc.ps1` | nový build systém | viz kapitola 4 |
| `src/linalg.h` | podmínka `#if defined(EIGEN_HAS_CXX11_CONTAINERS)` | makro v Eigen 5 zrušeno; `#warning` je na MSVC tvrdá chyba |
| `src/system-gl.h` | `<windows.h>` před GLEW, `#undef DIFFERENCE` | GLEW 2.3 už nenechá `APIENTRY` pro `GL/glu.h`; `DIFFERENCE` z winuser.h koliduje s `OpenSCADOperator::DIFFERENCE` |
| `src/cgalutils-tess.cc` | `Filtered_projection_traits_3` pro CGAL ≥ 5.4 | přejmenováno v CGAL |
| `src/cgalutils-polyhedron.cc` | lokální `generic_print_polyhedron` | z CGAL 5 odstraněno |
| `src/openscad.cc` | kvalifikovaný `boost::algorithm::join`; `main()` v try/catch; `std::optional` | nejednoznačnost pod MSVC; tichý fail-fast při nezachycené výjimce |
| `src/FreetypeRenderer.h`, `src/node.cc`, `src/exceptions.h`, `src/feature.*`, `src/libsvg/libsvg.h`, `src/Network.h` | úklid pro C++17 | `std::unary_function`, `std::mem_fun`, `throw()` |
| `src/utf8utils.h` + `FreetypeRenderer.cc`, `func.cc`, `value.*`, `lexer.l`, `LibraryInfo.cc` | vlastní UTF-8 pomůcky | GLib odstraněn; `unichar_validate` záměrně přijímá nonznaky jako GLib |
| 35 souborů | `std::filesystem` | Boost.Filesystem odstraněn; `fs_last_write_time()` ve `fileutils.h` vrací sekundy pro klíče cache |
| `src/parsersettings.cc` | přeskočení prázdných cest ke knihovnám | `std::filesystem::absolute("")` na Windows vyhazuje výjimku; Boost tiše použil aktuální adresář (ten se proto už v knihovních cestách neobjevuje) |
| `src/FileModule.cc`, `src/Geometry.h` | `is_regular_file`, `<cassert>` | zrušený alias v Boostu, chybějící include |
| `src/comment.cpp`, `handle_dep.cc`, `nodedumper.cc`, `PlatformUtils-posix.cc`, `import_stl.cc` | `std::regex` / řetězcové operace | Boost.Regex odstraněn; import STL parsuje řádky bez regexu (rychlejší) |
| `src/value.h`, `src/value.cc` | `std::variant`, `std::visit`, `std::get_if` | Boost.Variant odstraněn |
| `src/color.cc` | `std::optional` | Boost.Optional odstraněn z jádra |
| `src/scintillaeditor.cpp`, `editor.cc`, `Preferences.cc`, `parameter/parametervirtualwidget.cpp` | `QRegularExpression`, `QWheelEvent::angleDelta()` | `QRegExp` a `QWheelEvent::delta()` v Qt 6 neexistují |
| `src/mainwin.cc`, `MainWindow.h` | geometrie přes `QScreen`, `QSoundEffect`, `QElapsedTimer`, `Qt::CTRL \| ...`, `palette().window()`, `setTabStopDistance`, bez `setCodec` | `QDesktopWidget`, `QSound`, `QTime::elapsed`, `Qt::Modifier +`, `QPalette::background`, `setTabStopWidth`, `QTextStream::setCodec` byly v Qt 6 odstraněny |
| `src/LibraryInfoDialog.cc`, `FontListTableView.cc`, `ProgressWidget.*`, `QGLView.cc`, `tabmanager.cc`, `openscad.cc` | `QStringView`, `horizontalAdvance`, `QElapsedTimer`, `QWheelEvent::position()`, bez `setCodec`, bez `QTextCodec` | stejný důvod |
| `CMakeLists.txt` (GUI blok), `cmake/Modules/FindQScintilla.cmake`, `tools/install-qt6.ps1` | Qt 6 build, hledání QScintilly, instalace Qt | nahrazuje logiku Qt 5 / `FindQt5QScintilla.cmake`; Qt Gamepad v Qt 6 není, ten vstupní ovladač zmizel |
| `src/openscad.cc` (`gui()`), `src/Preferences.cc` | styl Fusion, výchozí schémata podle `QStyleHints::colorScheme()` | platformové styly Windows zůstávají světlé i při tmavém systému; Fusion tmavý režim umí a vypadá stejně na Linuxu. Tmavý systém → výchozí „For Dark Background" (editor) a „Tomorrow Night" (3D pohled); uložené předvolby mají přednost. `QT_STYLE_OVERRIDE` dál funguje. |
| `CMakeLists.txt` (post-build), `fonts/fonts.conf.windows` | složky se zdroji a soubor fontconfigu vedle exe | viz kapitola 4.1; opravuje i prázdné menu Examples a chybějící barevná schémata v build stromu |
| `src/launchingscreen.ui`, `src/launchingscreen.cc` | uvítací obrazovka bez bitmapy na pozadí a ručních zelených gradientů; standardní tlačítka, logo 256 px | sleduje paletu (světlá/tmavá) a HiDPI jako každé jiné okno |
| `src/func.cc` (`search()` s vektorovou tabulkou), `src/parsersettings.h` | řetězec držen naživu před `c_str()`; `#include <vector>` | našel Linux build: původní kód používal visící ukazatel (nedefinované chování; na Windows vyhledávání v tabulce tiše nikdy nenašlo, na Linuxu našlo), a hlavičky MSVC vkládají `<vector>` transitivně, GCC ne |
| `tests/smoke/` | nové | regresní testy, viz kapitola 7 |

## 7. Testování

`tests/smoke/run-smoke.ps1` spustí headless exe na několika skriptech a porovná:

* výstup `echo` z `lang.scad` (aritmetika, porovnání, vektory, range, řetězce, funkce),
  `utf8.scad` a `esc.scad` (Unicode indexování, `ord`/`chr`, `search`, escape sekvence) a
  `main.scad` (`include`/`use`/`import` s relativními cestami) proti `expected/*.echo`,
* počty facet STL exportů (`logo.scad` = 5892, import `tetra.stl` = 4, …),
* PNG export přes offscreen OpenGL kontext,
* s `-Gui`: spustí Qt GUI s příkladem a hlavní okno se musí objevit.

Očekávané soubory vytvořil nezměněný kód 2021.01 přeložený se stejnými knihovnami, takže
úspěšný běh znamená shodu chování. STL soubory se neporovnávají bajt po bajtu: pořadí facet
není deterministické ani v původním kódu.

Upstream regresní sada (`tests/CMakeLists.txt`, ~1000 obrazových porovnání) zatím na MSVC
nejde použít (`ENABLE_TESTS=OFF`); je přirozeným dalším krokem, až bude GUI build.

## 8. Plán

1. **GUI s Qt 6** – hotovo (viz kapitoly 4.4 a 6). Zbývá: instalační/balicí pravidla
   (`cmake --install`, instalátor) a upstream regresní sada.
2. **Vzhled** – základ hotov (Fusion, světlý/tmavý motiv podle systému, tmavé výchozí
   hodnoty, uvítací obrazovka podle palety). Zbývá: jedna konzistentní sada SVG ikon (toolbary
   míchají dvě bitmapové sady volené podle světlosti palety v `MainWindow::initActionIcon`),
   velikosti ikon pro HiDPI a méně přeplněné Předvolby.
3. **Linux** – hotovo: presety, `tools/linux-deps.sh`, `tools/linux-docker-check.sh`; headless
   build a smoke testy procházejí v čistém kontejneru Ubuntu 24.04, GUI binárka se překládá
   proti Qt 6.4 / QScintille 2.14 z distribuce. Zbývá: spuštění GUI na linuxovém desktopu,
   sloučení větví závislostí MSVC/Unix v `CMakeLists.txt`, CI matice (Windows MSVC + Ubuntu)
   postavená na těch dvou skriptech.
4. **Později** – CGAL 6 nebo Manifold, Clipper 2, instalátory přes CPack.

## 9. Konvence

* C++17, `/permissive-` na MSVC; kód musí jít přeložit i GCC/Clangem.
* Žádný nový kód jen pro Windows mimo `PlatformUtils-win.cc` / `OffscreenContextWGL.cc`.
* Formátování podle `.clang-format` (tabulátory, jako v původních zdrojích).
* Každá změna, která může ovlivnit výstup, se kontroluje `tests/smoke/run-smoke.ps1`; při zásahu
  do evaluátoru nebo exportéru testy rozšiřte.
* Dokumentace: `README*.md` a `DEVELOPMENT*.md` aktualizovat v obou jazycích ve stejné změně.
