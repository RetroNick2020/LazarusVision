program LfmTest;

{ Checks the .lfm reader: LFMDEMO.LFM (found at run time by the unit's
  name) and ABOUTLFM.LFM (built in with LFM2INC). Writes LFMTEST.LOG.
     fpc -Tgo32v2 lfmtest.pas    (LFMDEMO.LFM next to LFMTEST.EXE) }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIList, TUIMenu,
  TUIExt, TUIPages, TUIGrid, TUIViews, LfmDemo, AboutLfm;

type
  TScript = class
    Modal: string;
    procedure Idle(Sender: TObject);
  end;

var
  Log: text;
  Passed, Failed: integer;
  Script: TScript;
  about: TAboutForm;
  f: TForm;
  start: longint;
  ok: boolean;
  i: integer;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

procedure Run;
begin
  Application.ProcessMessages;
end;

procedure Dump(const Title: string);
var buf: array of word;
    x, y: integer;
    s: string;
begin
  SetLength(buf, ScrCols * ScrRows);
  HWReadCells(0, buf[0], ScrCols * ScrRows);
  writeln(Log);
  writeln(Log, '=== ', Title);
  for y := 0 to ScrRows - 1 do
  begin
    SetLength(s, ScrCols);
    for x := 0 to ScrCols - 1 do s[x + 1] := char(buf[y * ScrCols + x] and $FF);
    writeln(Log, s);
  end;
  writeln(Log);
end;

procedure TScript.Idle(Sender: TObject);
var m: TCustomForm;
begin
  m := Application.TopModal;
  if m = nil then exit;
  Modal := Modal + m.Caption + ';';
  if m is TAboutForm then Dump('the About dialog (built-in .lfm)');
  TUIPostKey(VK_RETURN, #13, []);
end;

begin
  Assign(Log, 'LFMTEST.LOG');
  Rewrite(Log);
  Script := TScript.Create;
  TUIMouseCursor := false;
  Application.Initialize;
  Application.OnIdle := @Script.Idle;
  Application.CreateForm(TLfmForm, LfmForm);
  with LfmForm do
  begin
    Check((NameEdit <> nil) and (HelloButton <> nil) and (Notes <> nil) and (actHello <> nil),
          'the published fields point at the controls the .lfm made');
    Check((NameEdit.Left = 9) and (NameEdit.Top = 1) and (NameEdit.Width = 30) and
          (HelloButton.Left = 42) and (HelloButton.Height = 2) and (Width = 70) and (Height = 22),
          'positions and sizes are character cells, 1:1');
    Check((Caption = 'A form from LFMDEMO.LFM') and (Menu = MainMenu1) and KeyPreview and ShowHint,
          'form properties, Menu (a reference)');
    Check((NameLabel.FocusControl = NameEdit) and (NameEdit.Parent = LfmForm) and
          (Grid.Parent = GridSheet) and (GridSheet.PageControl = Pages), 'references and parents');
    Check(LoudCheck.Font.Color = clRed, 'Font.Color = clRed');
    Check(NameEdit.Anchors = [akTop, akLeft, akRight], 'Anchors');
    Check((SizeGroup.ItemIndex = 2) and (SizeGroup.Items.Count = 3), 'radio group: ItemIndex before Items');
    Check((FruitList.ItemIndex = 1) and (FruitList.Count = 6), 'list box Items and ItemIndex');
    Check((CityCombo.Text = 'Rome') and (CityCombo.Style = csDropDownList), 'combo box');
    Check(QtySpin.Value = 12, 'spin edit Value');
    Check((Pages.ActivePage = NotesSheet) and (Pages.PageCount = 3) and (Notes.Lines.Count = 2),
          'page control, tab sheets, ActivePage, memo Lines');
    Check((Grid.FixedCols = 0) and (goEditing in Grid.Options) and (Grid.Cells[0, 1] = 'Apples'),
          'string grid; OnCreate (from the .lfm) filled it');
    Check((Files.Columns.Count = 2) and (Files.Columns[1].Alignment = taRightJustify) and
          (Files.Items.Count = 1), 'list view Columns (a collection)');
    Check((StatusBar1.Panels.Count = 2) and (StatusBar1.Panels[0].Width = 12) and
          (StatusBar1.Align = alBottom), 'status bar Panels (a collection)');
    Check((MainMenu1.Items.Count = 1) and (FileItem.Count = 3) and (HelloItem.Caption = '&Hello') and
          (HelloItem.ShortCut = ShortCut(VK_F2, [])) and (QuitItem.ShortCut = ShortCut(Ord('Q'), [ssCtrl])),
          'menu items inside the menu; the action gave Caption and ShortCut');
    Check((actHello.ActionList = ActionList1) and (HelloButton.Caption = '&Hello'), 'action inside its list');
    ok := false;
    for i := 0 to LfmWarnings.Count - 1 do
      if Pos('DesignTimePPI', LfmWarnings[i]) > 0 then ok := true;
    Check(ok, 'an unknown property (DesignTimePPI) was skipped and noted');
    Show;
    Run;
    Check((ActiveControl = NameEdit) and (Left = (ScrCols - 70) div 2), 'ActiveControl; Position poScreenCenter');
    Dump('the form from LFMDEMO.LFM');
    TUIPostString('Ann'); Run;
    Check(StatusBar1.Panels[1].Text = 'Name: Ann', 'OnChange (bound from the .lfm)');
    TUIPostKey(VK_F2, #0, []); Run;
    Check((Hellos = 1) and (LastMessage = 'Hello, Ann') and (Script.Modal = 'Information;'),
          'F2: the action''s shortcut and OnExecute: ' + Script.Modal);
    TUIPostKey(Ord('L'), #0, [ssAlt]); TUIPostKey(VK_RETURN, #13, []); Run;
    Check((Hellos = 2) and (LastMessage = 'HELLO, ANN!'), 'Alt+L, Enter (the Default button)');
    TUIPostKey(Ord('S'), #0, [ssAlt]); TUIPostKey(VK_UP, #0, []); Run;
    Check(StatusBar1.Panels[1].Text = 'Size: Medium', 'radio group OnClick');
    SetBounds(Left, Top, Width + 6, Height + 1); Run;
    Check((NameEdit.Width = 36) and (HelloButton.Left = 48) and (Pages.Height = 8),
          'resized: the anchors from the .lfm');
    start := HWTicks;
    repeat Run until (Ticks > 0) or (HWTicks - start > 3000);
    Check(Ticks > 0, 'the timer from the .lfm runs');
  end;

  { a built-in .lfm (LFM2INC, RegisterFormText) }
  about := TAboutForm.Create(nil);
  Check((about.OkButton <> nil) and (about.OkButton.ModalResult = mrOk) and about.OkButton.Cancel and
        (about.InfoLabel.Caption = 'This dialog''s .lfm is built into'), 'the built-in .lfm: ModalResult = mrOK');
  Check(about.ShowModal = mrOk, 'ShowModal, Enter: mrOk');
  about.Free;

  { strict mode: an unknown property is an error }
  LfmStrict := true;
  f := TForm.CreateNew(nil);
  ok := false;
  try
    ReadFormText(f, 'object F: TForm' + LineEnding + '  Nonsense = 1' + LineEnding + 'end');
  except
    on E: Exception do ok := true;
  end;
  Check(ok, 'LfmStrict: an unknown property raises an exception');
  f.Free;
  LfmStrict := false;

  TUIPostKey(Ord('Q'), #0, [ssCtrl]); Run;
  Check(Application.Terminated, 'Ctrl+Q (File|Quit from the .lfm) closed the main form');

  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  Script.Free;
end.
