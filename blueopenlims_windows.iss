#define MyAppName "BlueOpenLIMS"
#define MyAppVersion "0.1.5"
#define MyAppPublisher "Rúben Luz"
#define MyAppExeName "culture_app.exe"

[Setup]
; Corrigido o fecho do AppId
AppId={{10B0B43D-4634-4D78-9349-43E7AFFA2486}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

PrivilegesRequired=admin

SolidCompression=yes
Compression=lzma2
WizardStyle=modern

; Usar userdesktop simplifica se mudares de computador
OutputDir=desktop_release
OutputBaseFilename={#MyAppName}_installer_v{#MyAppVersion}
SetupIconFile=C:\Users\ruben\Documents\blue_open_lims\windows\runner\resources\app_icon.ico

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
; O flag 'ignoreversion' é ótimo para DLLs do Flutter/Windows
Source: "C:\Users\ruben\Documents\blue_open_lims\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
