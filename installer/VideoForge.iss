#define MyAppName "VideoForge"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "VideoForge"

[Setup]
AppId={{AF7293DC-BDB4-4D8D-AE23-58A0DB7D8D52}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\VideoForge
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\dist
OutputBaseFilename=VideoForge-Windows-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\videoforge.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VideoForge"; Filename: "{app}\videoforge.exe"
Name: "{autodesktop}\VideoForge"; Filename: "{app}\videoforge.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\videoforge.exe"; Description: "Launch VideoForge"; Flags: nowait postinstall skipifsilent
