program RoutePlanner_p;

uses
  Vcl.Forms,
  frmHomeScreen_u in 'frmHomeScreen_u.pas' {frmHomeScreen},
  frmSignUp_u in 'frmSignUp_u.pas' {Form2},
  frmLogin_u in 'frmLogin_u.pas' {frmLogin},
  frmMainPage_u in 'frmMainPage_u.pas' {frmMainPage},
  dmRoute_u in 'dmRoute_u.pas' {dmRoute: TDataModule},
  MapDisplay in 'MapDisplay.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMainPage, frmMainPage);
  Application.CreateForm(TfrmHomeScreen, frmHomeScreen);
  Application.CreateForm(TForm2, Form2);
  Application.CreateForm(TfrmLogin, frmLogin);
  Application.CreateForm(TdmRoute, dmRoute);
  Application.Run;
end.
