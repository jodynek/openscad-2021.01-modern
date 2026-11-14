# SignPath Foundation application – prepared answers

Form: <https://signpath.org/apply> (must be submitted by the maintainer; it has a reCAPTCHA).
Conditions: <https://signpath.org/terms>. Prerequisites that are already in place in this
repository: OSI licence (GPL-2.0-or-later), published release with installer, public CI build,
"Code signing policy" section in README.md / README.cs.md, ProductName/ProductVersion in all
Windows binaries and in the installer. Still needed from the maintainer: two-factor
authentication on the GitHub account (and later on the SignPath account).

| Field | Suggested answer |
|---|---|
| Project Name | OpenSCAD 2021.01 Modern |
| Repository URL | https://github.com/jodynek/openscad-2021.01-modern |
| Homepage URL | https://github.com/jodynek/openscad-2021.01-modern |
| Download URL | https://github.com/jodynek/openscad-2021.01-modern/releases |
| Wikipedia | https://en.wikipedia.org/wiki/OpenSCAD (article about the upstream project) |
| Tagline | Modernized build of OpenSCAD 2021.01, the script-based 3D CAD modeller, for Windows 11 x64 (Visual Studio 2022/2026, CMake + vcpkg, Qt 6) and Linux. |
| Category | CAD / 3D modelling (pick the closest entry, e.g. "Graphics & Design" or "Developer Tools") |
| Maintainer Type | Individual |
| Build System | GitHub Actions |
| Company Name | (optional, leave empty or your employer) |
| Primary Discovery Channel | e.g. "GitHub repository" / "Google search" |

**Description**

> OpenSCAD is a free script-based solid 3D CAD modeller: the user describes a part in the
> OpenSCAD language and the program evaluates it with constructive solid geometry (CGAL) and
> exports STL, 3MF, AMF, OFF, DXF, SVG, PDF or PNG. This project is the last tagged upstream
> release, 2021.01, with a modernized build: one CMake project with presets, dependencies from a
> vcpkg manifest, C++17, Qt 6 and a Windows installer. The language and the geometry kernel are
> unchanged, so models render exactly as in the official 2021.01 release. It targets users who
> need the stable 2021.01 behaviour on current Windows 11 x64 systems and developers who want a
> code base that compiles with a single command on Visual Studio 2022/2026 or Ubuntu 24.04.

**Reputation** (fill in current numbers; add links to any forum or social-media discussion)

> * Upstream OpenSCAD is one of the most widely used open-source CAD tools (Wikipedia article,
>   tens of thousands of GitHub stars at https://github.com/openscad/openscad); this project
>   keeps its last tagged release buildable and installable on current Windows.
> * Releases with Windows installer: https://github.com/jodynek/openscad-2021.01-modern/releases
>   (download counts visible on the page; GitHub Insights of the repository).
> * Release announcement: https://x.com/jodynek/status/2121317050568286357
> * Public CI builds for Windows and Linux: https://github.com/jodynek/openscad-2021.01-modern/actions

**What gets signed** (for the SignPath project configuration after approval)

* `OpenSCAD.exe` (GUI) and `openscad-cli.exe` (command line), ProductName
  `OpenSCAD 2021.01 Modern`, ProductVersion `2021.01-modern.N`, built by
  `.github/workflows/windows.yml`.
* `OpenSCAD-2021.01-modern.N-win64-setup.exe` (Inno Setup installer with the same
  VersionInfo product name/version).
* Third-party DLLs shipped next to the executables (Qt, CGAL/GMP/MPFR, Boost, …) are unsigned
  upstream binaries included in the package, as permitted by the SignPath terms.

After approval: create the project in app.signpath.io, an artifact configuration for the
installer (Inno Setup with nested PE files), a signing policy `release-signing` with manual
approval, and a CI integration user. Then add the repository secret `SIGNPATH_API_TOKEN` and
the variables `SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_POLICY_SLUG`;
the workflow step is already in place.
