unit AboutLfm;

{ A dialog whose .lfm is compiled into the program: LFM2INC turned
  ABOUTLFM.LFM into ABOUTLFM.LFI (a string constant), and the
  initialization section registers it. No .lfm file is needed at run time. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd;

type
  TAboutForm = class(TForm)
    InfoLabel: TLabel;
    InfoLabel2: TLabel;
    OkButton: TButton;
  end;

implementation

initialization
  RegisterFormText(TAboutForm, {$I ABOUTLFM.LFI});
end.
