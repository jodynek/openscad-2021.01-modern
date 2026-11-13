; Inno Setup script for OpenSCAD 2021.01 (modern build), Windows x64.
; Build with installer\build-installer.ps1 (it passes the defines below), or directly:
;   ISCC.exe /DBuildDir=..\build\x64-gui /DHeadlessDir=..\build\x64-headless /DVCRedist=<path\vc_redist.x64.exe> openscad.iss

#ifndef AppVersion
  #define AppVersion "2021.01"
#endif
#ifndef BuildDir
  #define BuildDir "..\build\x64-gui"
#endif
#ifndef HeadlessDir
  #define HeadlessDir "..\build\x64-headless"
#endif
#ifndef VCToolsetMinor
  #define VCToolsetMinor 44
#endif
#define AppName "OpenSCAD"
#define AppExe "OpenSCAD.exe"
#define AppUrl "https://github.com/jodynek/openscad-2021.01-modern"
#ifndef ModernRelease
  #define ModernRelease "1"
#endif
; ProductName/ProductVersion must match the binaries (openscad_win32.rc.in) - required for code signing
#define ProductName "OpenSCAD 2021.01 Modern"

[Setup]
AppId={{7B6C2F4E-3F0B-4C2E-9D7A-OPENSCAD2021M}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion} (modern build)
AppPublisher=The OpenSCAD Developers (modern build by jodynek)
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
AppUpdatesURL={#AppUrl}/releases
DefaultDirName={autopf}\OpenSCAD
DefaultGroupName=OpenSCAD
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion} (modern build)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; admin install to Program Files by default; "/CURRENTUSER" on the command line (or the dialog) installs per user without elevation
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
LicenseFile=..\COPYING
SetupIconFile=..\icons\openscad.ico
WizardStyle=modern
OutputDir=..\build\installer
OutputBaseFilename=OpenSCAD-{#AppVersion}-modern-win64-setup
Compression=lzma2/ultra64
SolidCompression=yes
ChangesAssociations=yes
ChangesEnvironment=yes
MinVersion=10.0
VersionInfoVersion=2021.1.{#ModernRelease}.0
VersionInfoProductName={#ProductName}
VersionInfoProductVersion=2021.1.{#ModernRelease}.0
VersionInfoProductTextVersion={#AppVersion}-modern.{#ModernRelease}
VersionInfoDescription={#ProductName} Setup
VersionInfoCompany=The OpenSCAD Developers (modern build: Petr Jodas)
VersionInfoCopyright=Copyright (C) 2009-2021 The OpenSCAD Developers. GPL-2.0-or-later.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "czech"; MessagesFile: "compiler:Languages\Czech.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "fileassoc"; Description: "{cm:AssocFileExtension,{#AppName},.scad}"; GroupDescription: "{cm:AssocFileExtension,{#AppName},.scad}:"
Name: "addtopath"; Description: "Add the installation folder to PATH (for openscad-cli.exe)"; GroupDescription: "Command line:"; Flags: unchecked

[Files]
; application + runtime deployed by the build (vcpkg applocal + windeployqt)
Source: "{#BuildDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\platforms\*"; DestDir: "{app}\platforms"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\styles\*"; DestDir: "{app}\styles"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\imageformats\*"; DestDir: "{app}\imageformats"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\iconengines\*"; DestDir: "{app}\iconengines"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\multimedia\*"; DestDir: "{app}\multimedia"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\networkinformation\*"; DestDir: "{app}\networkinformation"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\tls\*"; DestDir: "{app}\tls"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\generic\*"; DestDir: "{app}\generic"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
; resources (color schemes, examples, fonts incl. fonts.conf, libraries, templates)
Source: "{#BuildDir}\color-schemes\*"; DestDir: "{app}\color-schemes"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\examples\*"; DestDir: "{app}\examples"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\fonts\*"; DestDir: "{app}\fonts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\libraries\*"; DestDir: "{app}\libraries"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#BuildDir}\templates\*"; DestDir: "{app}\templates"; Flags: ignoreversion recursesubdirs createallsubdirs
; command-line build (console subsystem) next to the GUI, shares the same DLLs
#ifexist HeadlessDir + "\openscad.exe"
Source: "{#HeadlessDir}\openscad.exe"; DestDir: "{app}"; DestName: "openscad-cli.exe"; Flags: ignoreversion
#endif
; icons for the file association and docs
Source: "..\icons\openscad_doc.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\COPYING"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.cs.md"; DestDir: "{app}"; Flags: ignoreversion
; Visual C++ runtime, installed only when missing or older than the one the build needs
#ifdef VCRedist
Source: "{#VCRedist}"; DestDir: "{tmp}"; DestName: "vc_redist.x64.exe"; Flags: deleteafterinstall; Check: VCRedistNeeded
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"
Name: "{group}\{#AppName} examples"; Filename: "{app}\examples"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; .scad association (HKA = HKLM for admin installs, HKCU for per-user installs)
Root: HKA; Subkey: "Software\Classes\.scad"; ValueType: string; ValueName: ""; ValueData: "OpenSCAD.scad"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OpenSCAD.scad"; ValueType: string; ValueName: ""; ValueData: "OpenSCAD design"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OpenSCAD.scad\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\openscad_doc.ico"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OpenSCAD.scad\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: fileassoc

[Run]
#ifdef VCRedist
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing the Visual C++ runtime..."; Check: VCRedistNeeded; Flags: waituntilterminated
#endif
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// --- Visual C++ runtime check: needs the 14.x runtime at least as new as the toolset used for the build ---
const
  VCRuntimeKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  NeededMinor = {#VCToolsetMinor};   // 14.<minor> toolset the binaries were built with (passed by build-installer.ps1)

function VCRedistNeeded: Boolean;
var
  Installed, Major, Minor: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM, VCRuntimeKey, 'Installed', Installed) and (Installed = 1) then
    if RegQueryDWordValue(HKLM, VCRuntimeKey, 'Major', Major) and RegQueryDWordValue(HKLM, VCRuntimeKey, 'Minor', Minor) then
      Result := (Major < 14) or ((Major = 14) and (Minor < NeededMinor));
end;

// --- PATH handling for the "addtopath" task ---
function EnvRootKey: Integer;
begin
  if IsAdminInstallMode then Result := HKLM else Result := HKCU;
end;

function EnvSubKey: String;
begin
  if IsAdminInstallMode then
    Result := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  else
    Result := 'Environment';
end;

procedure EnvAddPath(Path: String);
var
  Paths: String;
begin
  if not RegQueryStringValue(EnvRootKey, EnvSubKey, 'Path', Paths) then Paths := '';
  if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then exit;
  if (Paths <> '') and (Paths[Length(Paths)] <> ';') then Paths := Paths + ';';
  Paths := Paths + Path;
  RegWriteExpandStringValue(EnvRootKey, EnvSubKey, 'Path', Paths);
end;

procedure EnvRemovePath(Path: String);
var
  Paths: String;
  P: Integer;
begin
  if not RegQueryStringValue(EnvRootKey, EnvSubKey, 'Path', Paths) then exit;
  P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
  if P = 0 then exit;
  Delete(Paths, P - 1, Length(Path) + 1);
  RegWriteExpandStringValue(EnvRootKey, EnvSubKey, 'Path', Paths);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('addtopath') then
    EnvAddPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}'));
end;
