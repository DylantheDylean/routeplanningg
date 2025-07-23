unit frmHomeScreen_u;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,frmLogin_u ,frmSignUp_u ;

type
  TfrmHomeScreen = class(TForm)
    btnLogin: TButton;
    btnSignUp: TButton;
    procedure btnLoginClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmHomeScreen: TfrmHomeScreen;

implementation

{$R *.dfm}

procedure TfrmHomeScreen.btnLoginClick(Sender: TObject);
begin
      frmLogin.Show;
      frmHomeScreen.Hide;
end;

end.
