program LclTest;

{ The form in LCLFORM.PAS uses only LCL unit names (Forms, Controls,
  StdCtrls, Dialogs...). This program runs it with posted keys and writes
  LCLTEST.LOG.   fpc -Tgo32v2 -FuLCL lcltest.pas   (or LCLTEST.EXE) }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, LCLType, Clipbrd,
  TUIHW, TUICtrl, LclForm;

type
  TScript = class
    Messages: string;
    procedure Idle(Sender: TObject);
  end;

var
  Log: text;
  Passed, Failed: integer;
  Script: TScript;
  start: longint;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

procedure Run;
begin
  Application.ProcessMessages;
end;

procedure TScript.Idle(Sender: TObject);
var m: TCustomForm;
begin
  m := Application.TopModal;
  if m = nil then exit;
  Messages := Messages + TLabel(m.Controls[0]).Caption + ';';
  if m.ControlCount > 2 then TUIPostChar('y')          { Yes / No }
  else TUIPostKey(VK_RETURN, #13, []);
end;

begin
  Assign(Log, 'LCLTEST.LOG');
  Rewrite(Log);
  Script := TScript.Create;
  TUIMouseCursor := false;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.OnIdle := @Script.Idle;
  Form1.Show;
  Run;
  with Form1 do
  begin
    Check(ActiveControl = Edit1, 'OnCreate: the focus on Edit1');
    TUIPostString('Ann'); Run;
    Check(StatusBar1.SimpleText = 'Name: Ann', 'OnChange: ' + StatusBar1.SimpleText);
    Check((Button1.Caption = '&Hello') and (MainMenu1.Items[0].Items[0].ShortCut = ShortCut(VK_F2, [])),
          'Action: button and menu item took Caption and ShortCut');
    TUIPostKey(VK_F2, #0, []); Run;
    Check((Hellos = 1) and (Script.Messages = 'Hello, Ann;'), 'F2: the action; ShowMessage: ' + Script.Messages);
    TUIPostKey(Ord('L'), #0, [ssAlt]); TUIPostKey(Ord('H'), #0, [ssAlt]); Run;
    Check((Hellos = 2) and (Pos('HELLO, ANN!', Script.Messages) > 0), 'Alt+L, Alt+H (button with the action)');
    ListBox1.SetFocus; TUIPostKey(VK_DOWN, #0, []); TUIPostKey(VK_DOWN, #0, []); Run;
    Check(StatusBar1.SimpleText = 'Picked Two', 'list box: ' + StatusBar1.SimpleText);
    TUIPostKey(Ord('S'), #0, [ssAlt]); TUIPostKey(VK_DOWN, #0, []); Run;
    Check(RadioGroup1.ItemIndex = 2, 'radio group: Alt+S, Down');
    StringGrid1.SetFocus; TUIPostString('x'); TUIPostKey(VK_RETURN, #13, []); Run;
    Check(StringGrid1.Cells[1, 1] = 'x', 'string grid (Align alClient in a panel) edited');
    SetBounds(Left, Top, Width + 6, Height + 2); Run;
    Check((Edit1.Width = 36) and (Button1.Left = 50) and (StringGrid1.Width = 64),
          'resized: anchors and Align followed');
    start := HWTicks;
    repeat Run until (Ticks > 0) or (HWTicks - start > 3000);
    Check(Ticks > 0, 'TTimer ran');
    TUIPostKey(VK_ESCAPE, #27, []); Run;
    Check(Application.Terminated and (Pos('Quit?', Script.Messages) > 0), 'Esc, Yes: closed the main form');
  end;
  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  Script.Free;
end.
