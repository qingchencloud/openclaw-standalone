; OpenClaw Standalone Installer - Inno Setup Script
; Produces a professional guided .exe installer for Windows
; Compile: ISCC.exe /DAppVersion=x.y.z /DSourceDir=...\build\win-x64 /DOutputDir=...\output setup.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef SourceDir
  #define SourceDir "..\build\win-x64"
#endif

#ifndef OutputDir
  #define OutputDir "..\output"
#endif

[Setup]
AppId={{A7E3F2B1-9C4D-4E5F-B6A8-1D2E3F4A5B6C}
AppName=OpenClaw
AppVersion={#AppVersion}
AppVerName=OpenClaw {#AppVersion}
AppPublisher=晴辰云 (QingChenCloud)
AppPublisherURL=https://github.com/qingchencloud/openclaw-standalone
AppSupportURL=https://github.com/qingchencloud/openclaw-standalone/issues
AppUpdatesURL=https://github.com/qingchencloud/openclaw-standalone/releases
DefaultDirName={autopf}\OpenClaw
DefaultGroupName=OpenClaw
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=openclaw-{#AppVersion}-win-x64-setup
SetupIconFile=..\assets\openclaw.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesEnvironment=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\openclaw.cmd
VersionInfoCompany=QingChenCloud
VersionInfoDescription=OpenClaw - AI 智能体引擎
VersionInfoProductName=OpenClaw
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
BeveledLabel=QingChenCloud · OpenClaw Setup

[CustomMessages]
AddToPath=Add OpenClaw to PATH (recommended)
FinishMessage=OpenClaw installed!%n%nOpen a terminal and type openclaw to get started.%n%nGUI panel: https://github.com/qingchencloud/clawpanel

[Tasks]
Name: "addtopath"; Description: "{cm:AddToPath}"; GroupDescription: "Configuration:"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\node.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\openclaw.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\node_modules\*"; DestDir: "{app}\node_modules"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OpenClaw 终端"; Filename: "{cmd}"; Parameters: "/k ""{app}\openclaw.cmd"""; WorkingDir: "{userdocs}"; Comment: "打开 OpenClaw 终端"
Name: "{group}\卸载 OpenClaw"; Filename: "{uninstallexe}"

[Run]
Filename: "{cmd}"; Parameters: "/k echo OpenClaw {#AppVersion} 安装成功！输入 openclaw 开始使用。&& ""{app}\openclaw.cmd"" --version"; Description: "打开终端验证安装"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}\node_modules"
Type: files; Name: "{app}\node.exe"
Type: files; Name: "{app}\openclaw.cmd"
Type: files; Name: "{app}\VERSION"

[Code]
// Add/remove install directory from user PATH
procedure AddToUserPath(Dir: string);
var
  OldPath: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment', 'Path', OldPath) then
    OldPath := '';
  if Pos(Uppercase(Dir), Uppercase(OldPath)) = 0 then
  begin
    if OldPath <> '' then
      OldPath := OldPath + ';';
    OldPath := OldPath + Dir;
    RegWriteStringValue(HKEY_CURRENT_USER,
      'Environment', 'Path', OldPath);
  end;
end;

procedure RemoveFromUserPath(Dir: string);
var
  OldPath, NewPath, Item: string;
  I: Integer;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment', 'Path', OldPath) then
    Exit;
  NewPath := '';
  while Length(OldPath) > 0 do
  begin
    I := Pos(';', OldPath);
    if I = 0 then
    begin
      Item := OldPath;
      OldPath := '';
    end else begin
      Item := Copy(OldPath, 1, I - 1);
      OldPath := Copy(OldPath, I + 1, Length(OldPath));
    end;
    Item := Trim(Item);
    if (Length(Item) > 0) and (CompareText(Item, Dir) <> 0) then
    begin
      if NewPath <> '' then
        NewPath := NewPath + ';';
      NewPath := NewPath + Item;
    end;
  end;
  RegWriteStringValue(HKEY_CURRENT_USER,
    'Environment', 'Path', NewPath);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('addtopath') then
      AddToUserPath(ExpandConstant('{app}'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveFromUserPath(ExpandConstant('{app}'));
end;

// Notify Windows about PATH change
procedure BroadcastEnvironmentChange;
var
  Dummy: Longint;
begin
  // SendMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, 'Environment')
  // Inno Setup doesn't have direct access, but the PATH change takes effect on next terminal open
end;
