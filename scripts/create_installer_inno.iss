#define MyAppName "KRISTAL LABORATORIAL"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "3º Sgt Rolandi - H Mil Resende"
#define MyAppExeName "kristal_laboratorial.exe"

[Setup]
AppId={{9E7B8D83-61D1-4B67-9E96-KRISTALLAB001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\KRISTAL LABORATORIAL
DefaultGroupName=KRISTAL LABORATORIAL
AllowNoIcons=yes
OutputDir=installer
OutputBaseFilename=KRISTAL_LABORATORIAL_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "drivers\*"; DestDir: "{app}\drivers"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "scripts\install_drivers.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\install_drivers_admin.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion

[Icons]
Name: "{group}\KRISTAL LABORATORIAL"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Instalar drivers KRISTAL"; Filename: "{app}\scripts\install_drivers_admin.bat"
Name: "{autodesktop}\KRISTAL LABORATORIAL"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{app}\scripts\install_drivers.ps1"" -AppDir ""{app}"" -Quiet"; StatusMsg: "Instalando drivers laboratoriais..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Executar KRISTAL LABORATORIAL"; Flags: nowait postinstall skipifsilent
