; ============================================================================
; simple_lsp Inno Setup Installer
;
; Creates a Windows installer for simple_lsp (Eiffel LSP for VS Code)
;
; Build with: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" simple_lsp_setup.iss
; ============================================================================

#define MyAppName "Eiffel LSP"
#define MyAppVersion "0.8.5"
#define MyAppPublisher "Simple Eiffel"
#define MyAppURL "https://github.com/simple-eiffel/simple_lsp"
#define MyAppExeName "simple_lsp.exe"

[Setup]
AppId={{E1FF3L-L5P0-5IMP-LE01-000000000001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\simple_lsp
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
InfoBeforeFile=readme_before.txt
OutputDir=output
OutputBaseFilename=simple_lsp_setup_{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardImageFile=wizard_image.png
WizardSmallImageFile=wizard_small.png
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "envpath"; Description: "Add to PATH environment variable"; GroupDescription: "Environment:"
Name: "envvar"; Description: "Set SIMPLE_LSP environment variable"; GroupDescription: "Environment:"; Flags: checkedonce
Name: "vscodeext"; Description: "Install VS Code extension"; GroupDescription: "VS Code Integration:"; Flags: checkedonce

[Files]
; Main executable (F_code with -keep: optimized + contracts enabled)
Source: "..\EIFGENs\simple_lsp_exe\F_code\simple_lsp.exe"; DestDir: "{app}"; Flags: ignoreversion

; VS Code extension (specific version, not wildcard to avoid including old versions)
Source: "..\vscode-extension\eiffel-lsp-{#MyAppVersion}.vsix"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{group}\Documentation"; Filename: "{app}\README.md"

[Registry]
; Set SIMPLE_LSP environment variable (user level)
Root: HKCU; Subkey: "Environment"; ValueType: string; ValueName: "SIMPLE_LSP"; ValueData: "{app}"; Flags: uninsdeletevalue; Tasks: envvar

[Run]
; Install VS Code extension
Filename: "cmd.exe"; Parameters: "/c code --install-extension ""{app}\eiffel-lsp-{#MyAppVersion}.vsix"""; StatusMsg: "Installing VS Code extension..."; Flags: runhidden waituntilterminated; Tasks: vscodeext; Check: VSCodeInstalled

[Code]
// Check if VS Code is installed
function VSCodeInstalled: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd.exe', '/c where code', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

// Add to PATH
procedure CurStepChanged(CurStep: TSetupStep);
var
  Path: string;
  AppDir: string;
begin
  if CurStep = ssPostInstall then
  begin
    if WizardIsTaskSelected('envpath') then
    begin
      AppDir := ExpandConstant('{app}');
      if RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path) then
      begin
        if Pos(Lowercase(AppDir), Lowercase(Path)) = 0 then
        begin
          Path := Path + ';' + AppDir;
          RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path);
        end;
      end
      else
      begin
        RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', AppDir);
      end;
    end;
  end;
end;

// Remove from PATH on uninstall
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Path: string;
  AppDir: string;
  P: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    if RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path) then
    begin
      P := Pos(';' + Lowercase(AppDir), Lowercase(Path));
      if P > 0 then
      begin
        Delete(Path, P, Length(AppDir) + 1);
        RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path);
      end
      else
      begin
        P := Pos(Lowercase(AppDir) + ';', Lowercase(Path));
        if P > 0 then
        begin
          Delete(Path, P, Length(AppDir) + 1);
          RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path);
        end
        else if Lowercase(Path) = Lowercase(AppDir) then
        begin
          RegDeleteValue(HKEY_CURRENT_USER, 'Environment', 'Path');
        end;
      end;
    end;
  end;
end;
