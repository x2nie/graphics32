program GR32_Clipper_Demo;

{$R Media.rc}

uses
  Interfaces,
  Forms,
  MainUnit in 'MainUnit.pas';

begin
  Application.Initialize;
  Application.CreateForm(TFrmClipper, FrmClipper);
  Application.Run;
end.
