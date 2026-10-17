program LVCode;

{ LVCode - LazarusVision Code: a Free Pascal IDE for DOS in the style of the
  Free Pascal IDE (FV), built on FPTUI and its code editor. Compiles with
  the fpc in the PATH (Options|Compiler to change it), shows the compiler's
  messages and takes you to the line of an error.

     LVCODE [file ...]          the files are opened

  Build:  fpc -Tgo32v2 -O2 -Fu.. -Fi.. lvcode.pas }

{$mode objfpc}{$H+}

uses
  SysUtils, TUICtrl, LVMain;

var
  i: integer;

begin
  Application.Title := 'LVCode';
  Application.Initialize;
  Application.ShowMainForm := false;          { the main form holds the menus }
  Application.CreateForm(TLVMainForm, LVMainForm);
  for i := 1 to ParamCount do LVMainForm.OpenFile(ParamStr(i));
  if ParamCount = 0 then LVMainForm.Say('F3 opens a file, File|New starts one');
  Application.Run;
end.
