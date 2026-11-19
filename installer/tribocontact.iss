#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef StageDir
  #error "StageDir must be defined."
#endif
#ifndef RepoDir
  #error "RepoDir must be defined."
#endif
#ifndef OutputRoot
  #define OutputRoot "."
#endif

[Setup]
AppId={{4E8A3C19-9D2B-4F6E-B104-7A5C2E8D6F31}
AppName=TriboContact
AppVersion={#AppVersion}
AppPublisher=APS Technology
AppPublisherURL=https://github.com/OleksiyPenkov/TriboContact
AppSupportURL=https://github.com/OleksiyPenkov/TriboContact/issues
DefaultDirName={autopf}\TriboContact
DefaultGroupName=TriboContact
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
LicenseFile={#RepoDir}\LICENSE
SetupIconFile={#RepoDir}\Artwork\Windows\AppIcon.ico
UninstallDisplayIcon={app}\TriboContact.exe
OutputDir={#OutputRoot}
OutputBaseFilename=TriboContact-Setup-{#AppVersion}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#StageDir}\TriboContact.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\TriboContactCLI.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\data\materials.json"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "{#StageDir}\examples\*"; DestDir: "{app}\examples"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#StageDir}\Help\*"; DestDir: "{app}\Help"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TriboContact"; Filename: "{app}\TriboContact.exe"; WorkingDir: "{app}"
Name: "{group}\TriboContact User Manual"; Filename: "{app}\Help\index.html"; WorkingDir: "{app}\Help"
Name: "{group}\Uninstall TriboContact"; Filename: "{uninstallexe}"
Name: "{autodesktop}\TriboContact"; Filename: "{app}\TriboContact.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\TriboContactCLI.exe"; Parameters: "setup-ccx"; Description: "Download and verify CalculiX FEM solver (ccx.exe, ~42 MB, GPLv2)"; Flags: postinstall unchecked
Filename: "{app}\TriboContact.exe"; Description: "{cm:LaunchProgram,TriboContact}"; Flags: nowait postinstall skipifsilent
