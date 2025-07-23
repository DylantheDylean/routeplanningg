object frmHomeScreen: TfrmHomeScreen
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object btnLogin: TButton
    Left = 136
    Top = 296
    Width = 75
    Height = 25
    Caption = 'Login'
    TabOrder = 0
    OnClick = btnLoginClick
  end
  object btnSignUp: TButton
    Left = 440
    Top = 296
    Width = 75
    Height = 25
    Caption = 'Sign Up'
    TabOrder = 1
  end
end
