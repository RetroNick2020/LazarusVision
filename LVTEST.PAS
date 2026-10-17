program LVTest;

{ Tests of LVCode with posted keys. On the emulated screen (Linux) it runs
  the real fpc; in DOSBox FPCSTUB.EXE stands in for it (COMPILER=FPCSTUB on
  the command line: LVTEST FPCSTUB). Works in the folder LVTMP. Writes
  LVTEST.LOG with screen dumps. }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUISynEd, TUIDlgs,
  LVOpts, LVExec, LVMsgs, LVEdWin, LVDlgs, LVMain;

type
  TScript = class
    Step: string;
    Seen: string;
    procedure Idle(Sender: TObject);
  end;

var
  Log: text;
  Passed, Failed: integer;
  Script: TScript;
  W, W2: TEditWindow;
  E: TSynEdit;
  dir, src, s: string;
  t: TStringList;
  o2: TLVOptions;
  i, n: integer;
  ok: boolean;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

procedure Run;
begin
  Application.ProcessMessages;
end;

procedure Key(K: Word; Shift: TShiftState);
begin
  TUIPostKey(K, #0, Shift);
end;

function RowText(Y: integer): string;
var buf: array of word;
    x: integer;
begin
  SetLength(buf, ScrCols);
  HWReadCells(Y * ScrCols, buf[0], ScrCols);
  SetLength(Result, ScrCols);
  for x := 0 to ScrCols - 1 do Result[x + 1] := char(buf[x] and $FF);
end;

procedure Dump(const Title: string);
var y: integer;
begin
  writeln(Log);
  writeln(Log, '=== ', Title);
  for y := 0 to ScrRows - 1 do writeln(Log, RowText(y));
  writeln(Log);
end;

procedure WriteText(const F, S: string);
var l: TStringList;
begin
  l := TStringList.Create;
  try
    l.Text := S;
    l.SaveToFile(F);
  finally
    l.Free;
  end;
end;

{ the modal dialogs: one step per idle call }
procedure TScript.Idle(Sender: TObject);
var m: TCustomForm;
begin
  m := Application.TopModal;
  if m = nil then exit;
  Seen := Seen + m.Caption + ';';
  if m.Caption = 'Compiler options' then
  begin
    if Step = 'options' then
    begin
      Dump('the compiler options dialog');
      { Checks page: range checks on; Messages: a define }
      Key(Ord('3'), [ssAlt]); Key(Ord('R'), [ssAlt]);     { (an access key ticks the box) }
      Key(Ord('5'), [ssAlt]); Key(Ord('D'), [ssAlt]); TUIPostString('DEBUG'); Run;
      Step := 'options-ok';
    end
    else if Step = 'options-ok' then
    begin
      Dump('the compiler options dialog, changed');
      TUIPostKey(VK_RETURN, #13, []);
      Step := '';
    end
    else TUIPostKey(VK_ESCAPE, #27, []);
    exit;
  end;
  if m.Caption = 'Go to line number' then
  begin
    Key(Ord('A'), [ssCtrl]); TUIPostString('3'); TUIPostKey(VK_RETURN, #13, []);
    exit;
  end;
  if m.Caption = 'Confirm' then
  begin
    if Step = 'no' then TUIPostChar('n') else TUIPostChar('y');
    exit;
  end;
  { anything else (Search not found, About, Information): Enter }
  TUIPostKey(VK_RETURN, #13, []);
end;

begin
  Assign(Log, 'LVTEST.LOG');
  Rewrite(Log);
  Script := TScript.Create;
  TUIMouseCursor := false;
  LVWaitAfterRun := false;

  { a folder to work in, with a program that has an error on line 5 }
  dir := ExpandFileName('LVTMP');
  ForceDirectories(dir);
  SetCurrentDir(dir);
  DeleteFile('LVCODE.CFG');
  src := dir + DirectorySeparator + 'HELLO.PAS';
  WriteText(src, 'program Hello;' + LineEnding +
                 'var' + LineEnding +
                 '  i: integer;' + LineEnding +
                 'begin' + LineEnding +
                 '  WriteLn(x);' + LineEnding +
                 '  for i := 1 to 3 do' + LineEnding +
                 '    WriteLn(''Hello '', i);' + LineEnding +
                 'end.');

  Application.Initialize;
  Application.ShowMainForm := false;
  Application.OnIdle := @Script.Idle;
  Application.CreateForm(TLVMainForm, LVMainForm);
  with LVMainForm do
  begin
    if ParamCount > 0 then
    begin
      { DOSBox: the stub (and the program it makes) are in the folder above }
      Opts.CompilerPath := '..' + DirectorySeparator + ParamStr(1);
    end;
    Opts.ShowInfo := true;
    Run;
    Check((Application.Menu = ScreenMenu) and (Pos('Compile', RowText(0)) > 0) and
          (Pos('Alt+F9', RowText(ScrRows - 1)) > 0), 'the screen menu (File ... Compile ...) and status bar');
    Check(ActiveEditor = nil, 'no editor yet: an empty desktop');

    { ---- open, compile with an error }
    W := OpenFile(src);
    Run;
    E := W.Editor;
    Check((ActiveEditor = W) and (W.Caption = 'HELLO.PAS') and (E.Lines.Count = 8) and
          (E.Highlighter = PasSyn), 'opened HELLO.PAS in an editor window, the Pascal highlighter');
    Dump('LVCode with HELLO.PAS');
    Key(VK_F9, [ssAlt]); Run;
    Check(Msgs.Visible and (Msgs.Errors >= 1), 'Alt+F9: compiled, the messages window shows ' +
          IntToStr(Msgs.Errors) + ' error(s)');
    s := '';
    for i := 0 to Msgs.Count - 1 do s := s + Msgs.Messages(i).Display + ' | ';
    writeln(Log, 'msgs  ', s);
    Check((E.ErrorLine = 5) and (E.CaretY = 5) and (Screen.ActiveForm = W),
          'the editor went to the error: line ' + IntToStr(E.CaretY) + ', marked');
    Check(Pos('Identifier not found', ScreenStatus.Panels[ScreenStatus.Panels.Count - 1].Text) > 0,
          'the status bar shows the error: ' + ScreenStatus.Panels[ScreenStatus.Panels.Count - 1].Text);
    t := TStringList.Create;
    t.LoadFromFile('LVCODE.RSP');
    Check((Pos('-Mobjfpc', t.Text) > 0) and (Pos('HELLO.PAS', t.Text) = 0) and
          (Pos('-vewnib', t.Text) > 0), 'the response file: the mode, the messages (-vewnib); the file not in it');
    t.Free;
    Dump('a compile error');

    { ---- fix it, Make, Build, Run }
    Key(VK_HOME, []); Key(VK_HOME, []); Key(VK_END, [ssShift]); Run;
    TUIPostString('  WriteLn(''start'');'); Run;
    Check((E.Lines[4] = '  WriteLn(''start'');') and E.Modified and (E.ErrorLine = 0),
          'line 5 typed again: the error mark is gone');
    Key(VK_F9, []); Run;
    Check(LastOK and not E.Modified and FileExists(LastExe), 'F9 (Make): saved first, compiled, ' +
          ExtractFileName(LastExe) + ' made: ' + LastResult);
    Key(Ord('C'), [ssAlt]); TUIPostChar('b'); Run;
    t := TStringList.Create;
    t.LoadFromFile('LVCODE.RSP');
    Check(LastOK and (Pos('-B', t.Text) > 0), 'Compile|Build: everything again (-B), the program built, not run');
    t.Free;
    Check(Length(LVUserScreen) = 0, 'nothing ran yet');
    Opts.RunParameters := 'abc';
    Key(VK_F9, [ssCtrl]); Run;
    ok := false;
    if Length(LVUserScreen) > 0 then
      for i := 0 to LVUserRows - 1 do
      begin
        s := '';
        for n := 0 to LVUserCols - 1 do s := s + char(LVUserScreen[i * LVUserCols + n] and $FF);
        if Pos('Hello 3', s) > 0 then ok := true;
      end;
    Check(ok, 'Ctrl+F9 (Run): the program ran, the user screen shows "Hello 3"');

    { ---- options }
    Script.Step := 'options';
    Key(Ord('O'), [ssAlt]); TUIPostChar('c'); Run;
    Check(Opts.RangeChecks and (Opts.Defines = 'DEBUG') and (Pos('-Cr', Opts.CommandLine('X.PAS', bkMake)) > 0) and
          (Pos('-dDEBUG', Opts.CommandLine('X.PAS', bkMake)) > 0), 'Options|Compiler: range checks and a define: ' +
          Opts.CommandLine('X.PAS', bkMake));
    Opts.UnitDirs := 'C:\LIB;C:\MORE';
    Check(Pos('-FuC:\LIB -FuC:\MORE', Opts.CommandLine('X.PAS', bkMake)) > 0, 'unit dirs: one -Fu each');
    Key(Ord('O'), [ssAlt]); TUIPostChar('s'); Run;
    o2 := TLVOptions.Create;
    o2.LoadFromFile('LVCODE.CFG');
    Check(o2.RangeChecks and (o2.UnitDirs = 'C:\LIB;C:\MORE') and (o2.RunParameters = 'abc'),
          'Options|Save options: LVCODE.CFG read back');
    o2.Free;
    Opts.UnitDirs := '';
    Opts.RangeChecks := false;
    Opts.Defines := '';

    { ---- two errors: Alt+F8 / Alt+F7 }
    E.Lines[4] := '  WriteLn(x);';
    E.Lines[6] := '    WriteLn(x);';
    Key(VK_F9, [ssAlt]); Run;
    Check((Msgs.Errors >= 2) and (E.CaretY = 5), 'two errors: the first one (line 5)');
    Key(VK_F8, [ssAlt]); Run;
    Check((E.CaretY = 7) and (E.ErrorLine = 7), 'Alt+F8: the next one (line 7)');
    Key(VK_F7, [ssAlt]); Run;
    Check(E.CaretY = 5, 'Alt+F7: back to line 5');
    Msgs.List.ItemIndex := Msgs.List.Count - 1;
    for i := 0 to Msgs.Count - 1 do
      if Msgs.Messages(i).HasPlace and (Msgs.Messages(i).Line = 7) then Msgs.List.ItemIndex := i;
    Msgs.BringToFront; Run;
    TUIPostKey(VK_RETURN, #13, []); Run;
    Check((E.CaretY = 7) and (Screen.ActiveForm = W), 'Enter on a message in the window: there');
    E.Lines[4] := '  WriteLn(''start'');';
    E.Lines[6] := '    WriteLn(''Hello '', i);';
    W.Save;

    { ---- search, go to line }
    Key(VK_HOME, [ssCtrl]); Key(Ord('Q'), [ssCtrl]); TUIPostChar('f'); Run;
    Check(FindDlg.Visible, 'Ctrl+Q F: the Find dialog');
    Key(Ord('A'), [ssCtrl]); TUIPostString('WriteLn'); TUIPostKey(VK_RETURN, #13, []); Run;
    Check((E.SelText = 'WriteLn') and (E.CaretY = 5), 'found "WriteLn" on line 5');
    Key(VK_ESCAPE, []); Run;
    Key(Ord('L'), [ssCtrl]); Run;
    Check((E.SelText = 'WriteLn') and (E.CaretY = 7), 'Ctrl+L (search again): line 7');
    Key(Ord('L'), [ssCtrl]); Run;
    Check(Pos('not found', ScreenStatus.Panels[ScreenStatus.Panels.Count - 1].Text) > 0, 'no more: not found');
    Key(Ord('G'), [ssAlt]); Run;
    Check(E.CaretY = 3, 'Alt+G: go to line 3');
    Key(Ord('Q'), [ssCtrl]); TUIPostChar('a'); Run;
    Check(ReplaceDlg.Visible, 'Ctrl+Q A: the Replace dialog');
    Key(Ord('A'), [ssCtrl]); TUIPostString('integer');
    Key(Ord('P'), [ssAlt]); TUIPostString('longint');
    Key(Ord('A'), [ssAlt]); Run;
    Check(E.Lines[2] = '  i: longint;', 'Replace all: integer -> longint');
    Key(VK_ESCAPE, []); Run;

    { ---- several windows }
    W2 := NewFile;
    Run;
    Check((ActiveEditor = W2) and W2.Untitled and (Pos('NONAME', W2.Caption) = 1), 'File|New: ' + W2.Caption);
    TUIPostString('x := 1;'); Run;
    Key(VK_F6, []); Run;
    Check(Screen.ActiveForm <> W2, 'F6: the next window');
    Key(Ord('W'), [ssAlt]); Run;
    n := 0;
    for i := 0 to ScreenMenu.Items.Count - 1 do;
    Dump('the Window menu');
    Key(VK_ESCAPE, []); Key(VK_ESCAPE, []); Run;
    W2.BringToFront; Run;
    Script.Step := 'no';
    Key(VK_F3, [ssAlt]); Run;
    Check(Pos('Confirm', Script.Seen) > 0, 'Alt+F3 on a changed window: "Save?"; No');
    Run;
    Check(EditorCount = 1, 'the window closed');
    Script.Step := '';

    { ---- primary file, a missing compiler }
    Opts.PrimaryFile := src;
    W2 := NewFile;
    Run;
    Key(VK_F9, []); Run;
    Check(LastOK and SameText(LastTarget, src), 'a primary file: Make compiles it, not the new window');
    W2.Editor.Modified := false;
    W2.Close; Run;
    Opts.PrimaryFile := '';
    s := Opts.CompilerPath;
    Opts.CompilerPath := 'nosuchfpc';
    Key(VK_F9, [ssAlt]); Run;
    ok := false;
    for i := 0 to Msgs.Count - 1 do
      if Pos('Cannot run the compiler', Msgs.Messages(i).Raw) > 0 then ok := true;
    Check(ok and not LastOK, 'a compiler that is not there: said so');
    Opts.CompilerPath := s;
    Key(Ord('C'), [ssAlt]); TUIPostChar('i'); Run;
    Check(Pos('Information', Script.Seen) > 0, 'Compile|Information');

    { ---- exit }
    Key(Ord('X'), [ssAlt]); Run;
    Check(Application.Terminated and FileExists('LVCODE.CFG'), 'Alt+X: the options saved, LVCode ended');
  end;

  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  Script.Free;
end.
