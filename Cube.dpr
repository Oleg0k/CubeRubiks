program Cube;

uses
{  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,}
  Forms,
  SysUtils,
  Dialogs,
  CubeRubik in 'CubeRubik.pas' {frmGLScene},
  uSmallCube in 'uSmallCube.pas',
  uMath in 'uMath.pas',
  uConsts in 'uConsts.pas',
  uSettings in 'uSettings.pas' {frmSettings};

{$R *.RES}

begin
  Application.Initialize;
  if (ParamCount>0) and (UpperCase(Copy(ParamStr(1),1,2)) ='/C') then
     Application.CreateForm(TfrmSettings, frmSettings)
  else
  Application.CreateForm(TfrmGLScene, frmGLScene);
//  Application.CreateForm(TfrmSettings, frmSettings);
  Application.Run;
end.

