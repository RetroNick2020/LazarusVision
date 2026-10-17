program TUIDemo;

{ A Lazarus style project for DOS text mode: compare with a Lazarus .lpr.
  Build:  fpc -Tgo32v2 -O2 tuidemo.pas
  Options: TUIDEMO 50   runs in 80x50 (VGA) }

{$mode objfpc}{$H+}

uses
  SysUtils, TUICtrl, MainFrm, InfoFrm, ListFrm, MoreFrm, PageFrm, DataFrm, EditFrm, LfmDemo, CodeFrm;

begin
  if ParamStr(1) <> '' then TUITextRows := StrToIntDef(ParamStr(1), 0);
  Application.Title := 'TUI demo';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TInfoForm, InfoForm);
  Application.CreateForm(TListForm, ListForm);
  Application.CreateForm(TMoreForm, MoreForm);
  Application.CreateForm(TPageForm, PageForm);
  Application.CreateForm(TDataForm, DataForm);
  Application.CreateForm(TEditForm, EditForm);
  Application.CreateForm(TLfmForm, LfmForm);     { from LFMDEMO.LFM }
  Application.CreateForm(TCodeForm, CodeForm);
  Application.Run;
end.
