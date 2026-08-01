; Instalador de Windows para Variedades Lopsi, generado con Inno Setup 6.
;
; AppId fijo (no cambiar nunca: ver memoria del proyecto "Auto-actualización
; apps Windows") para que las actualizaciones futuras se instalen encima en
; vez de crear una instalación paralela.
;
; Uso: compilar con
;   flutter build windows --release
;   iscc windows\installer\variedades_lopsi.iss
; El .exe resultante queda en windows\installer\Output\Lopsi<version>.exe
; -subirlo a mano al release de GitHub junto con el .apk, ver
; ActualizacionService y version_app.dart-.

#define MyAppName "Variedades Lopsi"
#define MyAppVersion "7"
#define MyAppExeName "sistema_ventas.exe"
#define MyReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{5898ADAB-EB29-4E2C-87E9-EAC1CB23F6C9}
AppName={#MyAppName}
AppVerName={#MyAppName} version {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher=My Company, Inc.
AppPublisherURL=https://www.example.com/
AppSupportURL=https://www.example.com/
AppUpdatesURL=https://www.example.com/
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=Lopsi{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "data\*"
Source: "{#MyReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir {#MyAppName}"; Flags: nowait postinstall skipifsilent
