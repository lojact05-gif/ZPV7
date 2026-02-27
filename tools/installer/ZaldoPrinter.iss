[Setup]
AppId={{E3D4B4AE-2A38-4C31-A78A-3F8E3E4AE511}
AppName=Zaldo Printer
AppVersion=1.0.0
AppPublisher=Zaldo

; Instala sempre em Program Files (64-bit, porque teu build é x64)
DefaultDirName={pf}\ZaldoPrinter
DefaultGroupName=Zaldo Printer
DisableProgramGroupPage=no

UninstallDisplayIcon={app}\ZaldoPrinter.ConfigApp.exe

; Saída do instalador (mantive teu padrão)
OutputDir=..\dist
OutputBaseFilename=ZaldoPrinterSetup

Compression=lzma
SolidCompression=yes

ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern


[Files]
; Mantive teu source. Garanta que o workflow gera tools/ZaldoPrinter/dist/package/*
Source: "..\dist\package\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs


[Tasks]
Name: "desktopicon"; Description: "Criar atalho no desktop"; GroupDescription: "Atalhos:"


[Icons]
Name: "{autoprograms}\Zaldo Printer\Zaldo Printer Config"; Filename: "{app}\ZaldoPrinter.ConfigApp.exe"; Check: CanLaunchConfigApp
Name: "{autodesktop}\Zaldo Printer Config"; Filename: "{app}\ZaldoPrinter.ConfigApp.exe"; Tasks: desktopicon; Check: CanLaunchConfigApp


[Run]
; Parar serviço apenas se já existir
Filename: "{sys}\sc.exe"; Parameters: "stop ""ZaldoPrinterService"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')

; Se não existir, cria
Filename: "{sys}\sc.exe"; Parameters: "create ""ZaldoPrinterService"" binPath= ""{app}\ZaldoPrinter.Service.exe"" start= auto DisplayName= ""Zaldo Printer Service"""; Flags: runhidden; Check: not ServiceExists('ZaldoPrinterService')

; Se existir, reconfigura binPath/auto-start/nome (upgrade)
Filename: "{sys}\sc.exe"; Parameters: "config ""ZaldoPrinterService"" binPath= ""{app}\ZaldoPrinter.Service.exe"" start= auto DisplayName= ""Zaldo Printer Service"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')

; Descrição
Filename: "{sys}\sc.exe"; Parameters: "description ""ZaldoPrinterService"" ""Zaldo Printer local API and thermal print service"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')

; Iniciar serviço
Filename: "{sys}\sc.exe"; Parameters: "start ""ZaldoPrinterService"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')

; Abrir app de configuração ao final
Filename: "{app}\ZaldoPrinter.ConfigApp.exe"; Description: "Abrir Zaldo Printer Config"; Flags: nowait postinstall skipifsilent; Check: CanLaunchConfigApp


[UninstallRun]
; Parar e apagar o serviço na desinstalação (só se existir)
Filename: "{sys}\sc.exe"; Parameters: "stop ""ZaldoPrinterService"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')
Filename: "{sys}\sc.exe"; Parameters: "delete ""ZaldoPrinterService"""; Flags: runhidden; Check: ServiceExists('ZaldoPrinterService')


[Code]
function CanLaunchConfigApp: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\ZaldoPrinter.ConfigApp.exe'));
end;

function ServiceExists(const ServiceName: string): Boolean;
var
  ResultCode: Integer;
begin
  Result :=
    Exec(
      ExpandConstant('{sys}\sc.exe'),
      'query "' + ServiceName + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    ) and (ResultCode = 0);
end;
