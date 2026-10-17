program TUITest;

{ Scripted test of the TUI units. It drives TUIDEMO's forms with posted keys
  and mouse clicks, checks the results and writes TUITEST.LOG, including
  screen dumps read back from video memory.
     fpc -Tgo32v2 tuitest.pas      then   TUITEST      (look at TUITEST.LOG)
  The same program builds on Linux against the emulated screen. }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIMenu, TUIList, TUIMemo, TUIExt, TUIPages, TUIGrid, TUIViews, TUIDlgs, MainFrm, InfoFrm, ListFrm, MoreFrm, PageFrm, DataFrm,
  EditFrm;

type
  TScript = class
    Step: integer;
    procedure Idle(Sender: TObject);
    procedure NoChange(Sender: TObject; var AllowChange: boolean);
    procedure DialogStep(m: TCustomForm);
    procedure EatWheel(Sender: TObject; Shift: TShiftState; WheelDelta: integer;
                       MousePos: TPoint; var Handled: boolean);
  public
    Wheels: integer;
    DlgAction, DlgLog: string;
    DlgPhase, ConfirmCount: integer;
    NoteName: string;
    OpenSawTxt, OpenSawPas, OpenSawSub, FolderEntered: boolean;
  end;

var
  Log: text;
  Passed, Failed: integer;
  Script: TScript;
  ErrorSeen: boolean;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

procedure Dump(const Title: string);
var buf: array of word;
    x, y: integer;
    s: string;
begin
  SetLength(buf, ScrCols * ScrRows);
  HWReadCells(0, buf[0], ScrCols * ScrRows);   { what is really on the screen }
  writeln(Log);
  writeln(Log, '=== ', Title, ' (', ScrCols, 'x', ScrRows, ')');
  for y := 0 to ScrRows - 1 do
  begin
    SetLength(s, ScrCols);
    for x := 0 to ScrCols - 1 do s[x + 1] := char(buf[y * ScrCols + x] and $FF);
    writeln(Log, s);
  end;
  writeln(Log);
end;

{ one row of the real screen, as text }
function RowText(Y: integer): string;
var buf: array[0..MaxCols - 1] of word;
    x: integer;
begin
  HWReadCells(Y * ScrCols, buf[0], ScrCols);
  SetLength(Result, ScrCols);
  for x := 0 to ScrCols - 1 do Result[x + 1] := char(buf[x] and $FF);
end;

{ one cell of the real screen: the character and the attribute }
function CellChar(X, Y: integer): char;
var w: word;
begin
  HWReadCells(Y * ScrCols + X, w, 1);
  Result := char(w and $FF);
end;

function CellAttr(X, Y: integer): byte;
var w: word;
begin
  HWReadCells(Y * ScrCols + X, w, 1);
  Result := w shr 8;
end;

procedure Key(K: Word; Shift: TShiftState);
begin
  TUIPostKey(K, #0, Shift);
end;

procedure WriteText(const F, S: string);
var t: TStringList;
begin
  t := TStringList.Create;
  try
    t.Text := S;
    t.SaveToFile(F);
  finally
    t.Free;
  end;
end;

function ToolBtn(const C: string): TToolButton;
var i: integer;
begin
  for i := 0 to EditForm.Tools.ControlCount - 1 do
    if EditForm.Tools.Controls[i].Caption = C then exit(TToolButton(EditForm.Tools.Controls[i]));
  Result := nil;
end;

procedure ClickOn(C: TControl; DX: integer = 0);
var r: TRect;
begin
  r := C.ScreenRect;
  TUIPostClick(r.Left + DX, r.Top);
end;

procedure Run;
begin
  Application.ProcessMessages;
end;

function HasItem(L: TStrings; const S: string): boolean;
var i: integer;
begin
  for i := 0 to L.Count - 1 do
    if SameText(L[i], S) then exit(true);
  Result := false;
end;

{ the modal dialogs of stage 6, by caption / kind, one step per idle call }
procedure TScript.DialogStep(m: TCustomForm);
var f: TFileDialogForm;
    i: integer;
begin
  if m.Caption = 'Confirm' then
  begin
    inc(ConfirmCount);
    TUIPostChar('y');
    exit;
  end;
  if (m.Caption = 'Warning') or (m.Caption = 'Find') then
  begin
    DlgLog := TLabel(m.Controls[0]).Caption;
    TUIPostKey(VK_RETURN, #13, []);
    exit;
  end;
  if Pos('colour', m.Caption) > 0 then
  begin
    Dump('colour dialog');
    Key(VK_RIGHT, []); Key(VK_RIGHT, []); TUIPostKey(VK_RETURN, #13, []);
    exit;
  end;
  if not (m is TFileDialogForm) then exit;
  f := TFileDialogForm(m);
  if Copy(DlgAction, 1, 5) = 'save:' then
  begin
    TUIPostString(Copy(DlgAction, 6, MaxInt));
    TUIPostKey(VK_RETURN, #13, []);
  end
  else if DlgAction = 'open' then
  begin
    case DlgPhase of
      0: begin
           Dump('open dialog');
           OpenSawTxt := HasItem(f.FileList.Items, 'NOTE1.TXT') and HasItem(f.FileList.Items, 'A.TXT') and
                         not HasItem(f.FileList.Items, 'B.PAS');
           { the name as the file system has it (DOS: upper case) }
           NoteName := 'NOTE1.TXT';
           for i := 0 to f.FileList.Items.Count - 1 do
             if SameText(f.FileList.Items[i], 'NOTE1.TXT') then NoteName := f.FileList.Items[i];
           OpenSawSub := HasItem(f.DirList.Items, 'SUB' + DirectorySeparator) and
                         HasItem(f.DirList.Items, '..' + DirectorySeparator);
           Key(Ord('T'), [ssAlt]); Key(VK_DOWN, []);
         end;
      1: begin
           OpenSawPas := (f.FileList.Items.Count = 2) and HasItem(f.FileList.Items, 'B.PAS') and
                         HasItem(f.FileList.Items, 'C.PAS');
           Key(Ord('N'), [ssAlt]);
           TUIPostString(NoteName);
           TUIPostKey(VK_RETURN, #13, []);
         end;
    else
      TUIPostKey(VK_ESCAPE, #27, []);      { something went wrong: get out }
    end;
    inc(DlgPhase);
  end
  else if DlgAction = 'open-missing' then
  begin
    if DlgPhase = 0 then
    begin
      TUIPostString('NOPE.TXT');
      TUIPostKey(VK_RETURN, #13, []);
    end
    else TUIPostKey(VK_ESCAPE, #27, []);
    inc(DlgPhase);
  end
  else if DlgAction = 'folder' then
  begin
    if DlgPhase > 1 then TUIPostKey(VK_ESCAPE, #27, [])
    else if DlgPhase = 0 then
    begin
      Key(Ord('D'), [ssAlt]); TUIPostChar('s'); TUIPostKey(VK_RETURN, #13, []);
    end
    else
    begin
      FolderEntered := (Pos('SUB', f.PathLabel.Caption) > 0) and (f.DirList.Items.Count = 1);
      Dump('folder dialog in SUB');
      TUIPostKey(VK_RETURN, #13, []);
    end;
    inc(DlgPhase);
  end;
end;

procedure TScript.EatWheel(Sender: TObject; Shift: TShiftState; WheelDelta: integer;
                           MousePos: TPoint; var Handled: boolean);
begin
  inc(Wheels);
  Handled := true;
end;

{ no two of the visible windows overlap, all inside the desktop }
function WindowsTiled: boolean;
var i, j: integer;
    a, b, d: TRect;
begin
  Result := true;
  d := Application.DesktopRect;
  for i := 0 to Screen.FormCount - 1 do
  begin
    if not Screen.Forms[i].Visible then continue;
    a := Screen.Forms[i].ScreenRect;
    if (a.Left < d.Left) or (a.Top < d.Top) or (a.Right > d.Right) or (a.Bottom > d.Bottom) then
      exit(false);
    for j := i + 1 to Screen.FormCount - 1 do
    begin
      if not Screen.Forms[j].Visible then continue;
      b := Screen.Forms[j].ScreenRect;
      if RectsIntersect(a, b) then exit(false);
    end;
  end;
end;

function WindowsInside: boolean;
var i: integer;
    a, d: TRect;
begin
  Result := true;
  d := Application.DesktopRect;
  for i := 0 to Screen.FormCount - 1 do
    if Screen.Forms[i].Visible then
    begin
      a := Screen.Forms[i].ScreenRect;
      if (a.Left < d.Left) or (a.Top < d.Top) or (a.Right > d.Right) or (a.Bottom > d.Bottom) then
        exit(false);
    end;
end;

procedure TScript.NoChange(Sender: TObject; var AllowChange: boolean);
begin
  AllowChange := false;
end;

{ runs inside the modal loops (dialogs), when no input is waiting }
procedure TScript.Idle(Sender: TObject);
var m: TCustomForm;
begin
  m := Application.TopModal;
  if m = nil then exit;
  if (m is TFileDialogForm) or (m.Caption = 'Confirm') or (m.Caption = 'Warning') or
     (m.Caption = 'Find') or (Pos('colour', m.Caption) > 0) then
  begin
    DialogStep(m);
    exit;
  end;
  if m.Caption = 'Error' then
  begin
    { Application.ShowException: an exception raised in an event }
    Check(Pos('A test error', TLabel(m.Controls[0]).Caption) = 1,
          'the exception in OnClick showed an error box: ' + TLabel(m.Controls[0]).Caption);
    Dump('error box');
    ErrorSeen := true;
    TUIPostKey(VK_RETURN, #13, []);
    exit;
  end;
  inc(Step);
  case Step of
    1: begin
         Dump('ShowMessage (modal)');
         Check(m.Caption = 'TUI demo', 'message box caption is Application.Title');
         TUIPostKey(VK_RETURN, #13, []);
       end;
    2: begin
         Check(m.Caption = 'Input', 'InputQuery is open');
         TUIPostString('Paris');
         Dump('InputQuery open');
         TUIPostKey(VK_RETURN, #13, []);
       end;
    3: begin
         Dump('Help|About opened with the mouse');
         Check(m.Caption = 'About', 'Help|About (mouse) opened the About box');
         TUIPostKey(VK_RETURN, #13, []);
       end;
    4: begin
         Check(Pos('You picked', TLabel(m.Controls[0]).Caption) = 1,
               'double click on the list box: ' + TLabel(m.Controls[0]).Caption);
         TUIPostKey(VK_RETURN, #13, []);
       end;
    5: begin
         Dump('quit confirmation');
         TUIPostChar('y');                 { plain letter = the &Yes button }
       end;
  else
    TUIPostKey(VK_ESCAPE, #27, []);       { anything unexpected: get out }
  end;
end;

var
  n0, n1, start: longint;
  r: TRect;
  i, w0, x, y: integer;
  hidden, ok: boolean;
  tmp: string;
  o: TPoint;
  nd: TTreeNode;
  l0, t0: integer;

begin
  Assign(Log, 'TUITEST.LOG');
  Rewrite(Log);
  Script := TScript.Create;
  TUIMouseCursor := false;              { clean screen dumps }
  Application.Title := 'TUI demo';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TInfoForm, InfoForm);
  Application.CreateForm(TListForm, ListForm);
  Application.CreateForm(TMoreForm, MoreForm);
  Application.CreateForm(TPageForm, PageForm);
  Application.CreateForm(TDataForm, DataForm);
  Application.CreateForm(TEditForm, EditForm);
  Application.OnIdle := @Script.Idle;
  MainForm.Show;
  Run;
  writeln(Log, 'screen ', ScrCols, 'x', ScrRows, ', mono=', HWMono,
          ', mouse=', HWMousePresent, ', Move patched=', MoveIsPatched);
  Dump('start');

  Check(MainForm.ActiveControl = MainForm.NameEdit, 'OnCreate put the focus on NameEdit');
  Check(MainForm.NameEdit.SelLength = 5, 'entering the edit selected "World"');

  TUIPostString('Bob'); Run;
  Check(MainForm.NameEdit.Text = 'Bob', 'typing replaced the selection: ' + MainForm.NameEdit.Text);
  Check(Pos('Bob', MainForm.StatusLabel.Caption) > 0, 'OnChange updated the status label');

  Key(VK_TAB, []); Run;
  Check(MainForm.ActiveControl = MainForm.HelloButton, 'Tab moved to the Hello button');

  Key(Ord('B'), [ssAlt]); Run;
  Check(MainForm.BoldCheck.Checked, 'Alt+B checked Bold');
  Check(MainForm.ActiveControl = MainForm.BoldCheck, 'Alt+B focused Bold');

  TUIPostChar('l'); Run;                 { plain letter outside an edit }
  Check(MainForm.LargeRadio.Checked and not MainForm.MediumRadio.Checked,
        'L picked Large and unchecked Medium');

  ClickOn(MainForm.SmallRadio, 1); Run;
  Check(MainForm.SmallRadio.Checked and not MainForm.LargeRadio.Checked,
        'mouse click picked Small');

  Key(VK_SPACE, []); Run;                { the focus is on Small now }
  Check(MainForm.ActiveControl = MainForm.SmallRadio, 'the click focused Small');

  Key(Ord('G'), [ssAlt]); Run;           { label A&ge: -> its edit }
  Check(MainForm.ActiveControl = MainForm.AgeEdit, 'Alt+G (label) focused AgeEdit');
  TUIPostString('12345'); Run;
  Check(MainForm.AgeEdit.Text = '123', 'MaxLength 3 kept "123": ' + MainForm.AgeEdit.Text);
  Key(VK_HOME, []); TUIPostString('9'); Run;
  Check(MainForm.AgeEdit.Text = '123', 'insert at full length refused');
  Key(VK_INSERT, []); TUIPostString('9'); Key(VK_INSERT, []); Run;
  Check(MainForm.AgeEdit.Text = '923', 'overwrite mode: ' + MainForm.AgeEdit.Text);
  Key(VK_BACK, []); Run;
  Check(MainForm.AgeEdit.Text = '23', 'Backspace: ' + MainForm.AgeEdit.Text);

  { speed: repainting an unchanged form sends nothing to video memory }
  n0 := HWCellsWritten;
  Application.InvalidateAll; Run;
  n1 := HWCellsWritten;
  Check(n1 = n0, 'full repaint of an unchanged screen wrote ' + IntToStr(n1 - n0) + ' cells');
  Key(Ord('T'), [ssAlt]); Run;
  n0 := HWCellsWritten;
  TUIPostChar('A'); Run;
  n1 := HWCellsWritten;
  Check((n1 - n0 > 0) and (n1 - n0 <= 2), 'typing one char wrote ' + IntToStr(n1 - n0) + ' cell(s)');

  { the second form: non-modal, mouse, dragging }
  Key(Ord('W'), [ssAlt]); Run;
  Check(InfoForm.Visible and InfoForm.IsActive, 'Alt+W showed the Counter form, active');
  ClickOn(InfoForm.CountButton, 3); Run;
  ClickOn(InfoForm.CountButton, 3); Run;
  Check(InfoForm.CountLabel.Caption = 'Clicked 2 times', 'two clicks: ' + InfoForm.CountLabel.Caption);
  l0 := InfoForm.Left; t0 := InfoForm.Top;
  TUIPostMouse(l0 + 12, t0, 0);
  TUIPostMouse(l0 + 12, t0, 1);
  TUIPostMouse(l0 + 7, t0 + 2, 1);
  TUIPostMouse(l0 + 7, t0 + 2, 0);
  Run;
  Check((InfoForm.Left = l0 - 5) and (InfoForm.Top = t0 + 2), 'title bar drag moved the form');
  Dump('two forms, Counter dragged');
  ClickOn(MainForm.NameLabel); Run;
  Check(MainForm.IsActive, 'click on the main form brought it to the front');
  Key(Ord('W'), [ssAlt]); Run;
  Key(VK_ESCAPE, []); Run;               { Hide is the Cancel button }
  Check(not InfoForm.Visible, 'Esc hid the Counter form');

  { modal dialogs (the script answers them in OnIdle) }
  Key(Ord('H'), [ssAlt]); Run;
  Check(Script.Step = 1, 'ShowMessage ran and was closed with Enter');
  Key(Ord('I'), [ssAlt]); Run;
  Check(MainForm.CityEdit.Text = 'Paris', 'InputQuery returned: ' + MainForm.CityEdit.Text);
  Dump('after the dialogs');

  { ---- the screen's menu bar and status bar }
  Check(Pos(' File ', RowText(0)) = 2, 'screen menu bar on the top row');
  Check(Pos('F10 Menu', RowText(ScrRows - 1)) > 0, 'screen status bar on the bottom row');
  Check((MainForm.Top >= 1) and (MainForm.Top + MainForm.Height <= ScrRows - 1),
        'the main form is placed between the bars');
  MainForm.NameEdit.SetFocus; Run;
  Check(Pos('Your name', RowText(ScrRows - 1)) > 0, 'status bar shows the focused control''s Hint');
  Key(VK_F10, []); Run;
  Check(Application.OpenMenu = MainForm.ScreenMenu, 'F10 opened the screen menu');
  Check(Pos('Clear the name', RowText(ScrRows - 1)) > 0, 'status bar shows the menu item''s Hint');
  Dump('F10: File menu');
  Key(VK_RIGHT, []); Run;                { Options, on Bold }
  Key(VK_RETURN, []); Run;
  Check(not MainForm.BoldCheck.Checked and not MainForm.BoldItem.Checked and
        (Application.OpenMenu = nil), 'Right, Enter: Options|Bold unchecked Bold, menu closed');
  Key(Ord('O'), [ssAlt]); Run;           { no control has O: the screen menu }
  TUIPostChar('z'); Run;                 { Si&ze submenu }
  Dump('Options|Size submenu');
  TUIPostChar('l'); Run;
  Check(MainForm.LargeRadio.Checked and MainForm.LargeItem.Checked and
        not MainForm.MediumItem.Checked, 'Alt+O, Z, L picked Large through the submenu');
  Key(Ord('O'), [ssAlt]); Key(VK_ESCAPE, []); Run;
  Check(Application.OpenMenu <> nil, 'Esc closed the drop-down, the bar stays active');
  Key(VK_ESCAPE, []); Run;
  Check(Application.OpenMenu = nil, 'a second Esc left the menu bar');
  Key(Ord('N'), [ssCtrl]); Run;
  Check((MainForm.NameEdit.Text = '') and (MainForm.ActiveControl = MainForm.NameEdit),
        'Ctrl+N (File|New name shortcut) cleared the name');
  TUIPostString('Ann'); Run;

  { ---- the window's own menu bar and status bar }
  Key(VK_F2, []); Run;
  Check(InfoForm.Visible and InfoForm.IsActive, 'F2 (Window|Counter) showed the Counter form');
  Check(Pos('Counter', RowText(InfoForm.Top + 1)) > 0, 'window menu bar under the title');
  Check(Pos('Count: 2', RowText(InfoForm.Top + InfoForm.Height - 2)) > 0,
        'window status bar on the form''s last row');
  Key(Ord('T'), [ssCtrl]); Run;
  Check(InfoForm.CountLabel.Caption = 'Clicked 12 times', 'Ctrl+T (window menu shortcut) added ten');
  Key(Ord('C'), [ssAlt]); Run;
  Check(Application.OpenMenu = InfoForm.CounterMenu, 'Alt+C opened the window''s menu');
  Dump('window menu open');
  TUIPostChar('r'); Run;
  Check(InfoForm.CountLabel.Caption = 'Clicked 0 times', 'R in the window menu reset the count');
  Key(VK_F5, []); Key(VK_F5, []); Run;
  ClickOn(InfoForm.CounterStatus, 2); Run;
  Check(InfoForm.CountLabel.Caption = 'Clicked 0 times', 'click on the "^R Reset" panel reset it');
  Key(VK_F10, []); Run;
  Check(Application.OpenMenu = InfoForm.CounterMenu, 'F10 opens the active form''s own menu');
  Key(VK_F10, []); Run;
  l0 := InfoForm.Left;
  TUIPostMouse(l0 + 12, InfoForm.Top, 0);
  TUIPostMouse(l0 + 12, InfoForm.Top, 1);
  TUIPostMouse(l0 + 12, 0, 1);
  TUIPostMouse(l0 + 12, 0, 0);
  Run;
  Check(InfoForm.Top = 1, 'a form cannot be dragged over the screen menu bar');
  Check(IsRectEmpty(InfoForm.SizeGripRect), 'a bsSingle form has no size grip');
  l0 := InfoForm.Width;
  with InfoForm.ScreenRect do
  begin
    TUIPostMouse(Right - 1, Bottom - 1, 0);
    TUIPostMouse(Right - 1, Bottom - 1, 1);
    TUIPostMouse(Right + 3, Bottom + 1, 1);
    TUIPostMouse(Right + 3, Bottom + 1, 0);
  end;
  Run;
  Check(InfoForm.Width = l0, 'and dragging its corner does not resize it');
  InfoForm.Hide; Run;
  n0 := Pos('F2 Counter', RowText(ScrRows - 1)) - 1;
  TUIPostClick(n0 + 1, ScrRows - 1); Run;
  Check(InfoForm.Visible, 'click on the "F2 Counter" status panel showed the form');
  InfoForm.Hide; Run;

  { ---- the mouse on the screen menu: Help, then About... }
  n0 := Pos('Help', RowText(0)) - 1;
  TUIPostClick(n0, 0); Run;
  Check(Application.OpenMenu = MainForm.ScreenMenu, 'click on Help opened its menu');
  TUIPostClick(n0 + 2, 2); Run;
  Check(Script.Step = 3, 'click on About... ran it');

  { ---- list box }
  with ListForm do
  begin
    Key(Ord('L'), [ssCtrl]); Run;
    Check(Visible and IsActive and (ActiveControl = CountryList), 'Ctrl+L opened Lists, list box focused');
    Check((CountryList.Items[0] = 'Brazil') and (CountryList.ItemIndex = -1), 'sorted items, nothing selected');
    Key(VK_DOWN, []); Run;
    Check(CountryList.ItemIndex = 0, 'Down selected the first item');
    Check(Pos('Country: Brazil (1 of 18)', InfoLabel.Caption) = 1, 'OnSelectionChange: ' + InfoLabel.Caption);
    Key(VK_END, []); Run;
    Check((CountryList.ItemIndex = 17) and (CountryList.TopIndex = 8), 'End: last item, scrolled to the end');
    Key(VK_HOME, []); Run;
    Check((CountryList.ItemIndex = 0) and (CountryList.TopIndex = 0), 'Home: first item, scrolled back');
    TUIPostChar('g'); Run;
    Check(CountryList.Items[CountryList.ItemIndex] = 'Germany', 'G jumped to Germany');
    TUIPostChar('g'); Run;
    Check(CountryList.Items[CountryList.ItemIndex] = 'Greece', 'G again: Greece');
    Key(VK_NEXT, []); Run;
    Check(CountryList.ItemIndex = CountryList.Items.IndexOf('Greece') + 9, 'PgDn moved a page');
    Dump('list box');
    Key(VK_HOME, []); Run;
    with CountryList.ScreenRect do
    begin
      TUIPostClick(Left + 3, Top + 2); Run;
      Check(CountryList.ItemIndex = 2, 'mouse click picked the third row');
      TUIPostClick(Right - 1, Bottom - 1); Run;
      Check((CountryList.TopIndex = 1) and (CountryList.ItemIndex = 2),
            'click on the scroll bar''s down arrow scrolled one row');
      TUIPostClick(Right - 1, Top + 7); Run;   { track below the thumb }
      Check(CountryList.TopIndex = 8, 'click on the track scrolled a page: ' + IntToStr(CountryList.TopIndex));
      TUIPostClick(Right - 1, Top + 1); Run;   { track above the thumb }
      Check(CountryList.TopIndex = 0, 'and back up a page: ' + IntToStr(CountryList.TopIndex));
      Key(VK_HOME, []); Run;
      TUIPostClick(Left + 4, Top + 4); TUIPostClick(Left + 4, Top + 4); Run;
      Check(Script.Step = 4, 'the double click ran OnDblClick');
      TUIPostClick(Right - 1, Bottom - 1); TUIPostClick(Right - 1, Bottom - 1); Run;
      Check((Script.Step = 4) and (CountryList.TopIndex = 2),
            'double click on the scroll bar arrow: scrolled twice, no OnDblClick');
    end;

    { ---- resizing (BorderStyle bsSizeable) }
    l0 := Width; t0 := Height;
    with SizeGripRect do
    begin
      TUIPostMouse(Left, Top, 0);
      TUIPostMouse(Left, Top, 1);
      TUIPostMouse(Left + 6, Top + 1, 1);
      TUIPostMouse(Left + 6, Top + 1, 0);
    end;
    n0 := CountryList.Height;
    Run;
    Check((Width = l0 + 6) and (Height = t0 + 1), 'dragging the size grip resized the form');
    Check((CountryList.Width = 22 + 6) and (CountryList.Height = 10 + 1),
          'list box anchored on all sides grew with it');
    Check((SizeCombo.Left = 27 + 6) and (OkButton.Top = 15 + 1),
          'right / bottom anchored controls moved with it');
    Dump('Lists form resized');
    with SizeGripRect do
    begin
      TUIPostMouse(Left, Top, 0);
      TUIPostMouse(Left, Top, 1);
      TUIPostMouse(Left - 30, Top - 15, 1);
      TUIPostMouse(Left - 30, Top - 15, 0);
    end;
    Run;
    Check((Width = l0) and (Height = t0) and (CountryList.Height = n0),
          'shrinking stops at Constraints.MinWidth/MinHeight');
    with ZoomBoxRect do TUIPostClick(Left + 1, Top);
    Run;
    Check((WindowState = wsMaximized) and (Top = Application.DesktopRect.Top) and
          (Height = Application.DesktopRect.Bottom - Application.DesktopRect.Top) and
          (Width = ScrCols), 'the zoom box maximized the form into the desktop');
    Check(CountryList.Height = 10 + Height - t0, 'and the list box grew');
    Dump('Lists form maximized');
    with ZoomBoxRect do TUIPostClick(Left + 1, Top);
    Run;
    Check((WindowState = wsNormal) and (Width = l0) and (Height = t0), 'clicked again: restored');
    TUIPostClick(Left + 20, Top); TUIPostClick(Left + 20, Top); Run;
    Check(WindowState = wsMaximized, 'double click on the title maximized');
    TUIPostClick(Left + 20, Top); TUIPostClick(Left + 20, Top); Run;
    Check(WindowState = wsNormal, 'and restored');
    l0 := Left; t0 := Width;
    Key(VK_F5, [ssCtrl]); Run;
    Check(Pos('Size: Shift+arrows', RowText(ScrRows - 1)) > 0, 'Ctrl+F5: move / size mode, hint shown');
    Key(VK_RIGHT, [ssShift]); Key(VK_RIGHT, [ssShift]); Key(VK_LEFT, []); Key(VK_RETURN, []); Run;
    Check((Width = t0 + 2) and (Left = l0 - 1), 'Shift+Right twice sized, Left moved, Enter ended');
    Key(VK_LEFT, [ssShift]); Key(VK_LEFT, [ssShift]); Run;
    Check(Width = t0 + 2, 'after Enter the arrows go to the controls again');
    Key(VK_F5, [ssCtrl]); Key(VK_LEFT, [ssShift]); Key(VK_LEFT, [ssShift]); Key(VK_ESCAPE, []); Run;
    Key(Ord('C'), [ssAlt]); Run;

    { ---- pick-only combo box }
    Key(Ord('S'), [ssAlt]); Run;
    Check(ActiveControl = SizeCombo, 'Alt+S focused the Size combo box');
    Key(VK_DOWN, []); Run;
    Check((SizeCombo.Text = 'Medium') and (SizeCombo.ItemIndex = 1) and
          (InfoLabel.Caption = 'Size: Medium'), 'Down picked Medium without opening (OnSelect)');
    TUIPostChar('e'); Run;
    Check(SizeCombo.Text = 'Extra large', 'E picked Extra large');
    Key(VK_F4, []); Run;
    Check(SizeCombo.DroppedDown and (Application.OpenOverlay <> nil), 'F4 opened the list');
    Dump('Size list open');
    Key(VK_UP, []); Key(VK_RETURN, []); Run;
    Check((SizeCombo.Text = 'Large') and not SizeCombo.DroppedDown, 'Up, Enter in the list picked Large');
    Key(VK_F4, []); Key(VK_HOME, []); Key(VK_ESCAPE, []); Run;
    Check((SizeCombo.Text = 'Large') and not SizeCombo.DroppedDown, 'Esc closed the list without a change');
    with SizeCombo.ScreenRect do
    begin
      TUIPostClick(Left + 3, Top); Run;
      Check(SizeCombo.DroppedDown, 'a click on the combo box opened the list');
      TUIPostClick(Left + 3, Bottom + 1); Run;
      Check((SizeCombo.Text = 'Small') and not SizeCombo.DroppedDown, 'a click on the first row picked Small');
    end;

    { ---- editable combo box }
    Key(Ord('F'), [ssAlt]); Run;
    TUIPostString('Mang'); Run;
    Check((FruitCombo.Text = 'Mang') and (FruitCombo.ItemIndex = -1), 'typed "Mang": not an item');
    TUIPostChar('o'); Run;
    Check(FruitCombo.ItemIndex = 5, 'typing "Mango" selected item 5');
    Key(VK_DOWN, [ssAlt]); Run;
    Check(FruitCombo.DroppedDown, 'Alt+Down opened the list');
    Dump('Fruit list open (6 rows, scroll bar)');
    Key(VK_END, []); Key(VK_RETURN, []); Run;
    Check((FruitCombo.Text = 'Strawberry') and (FruitCombo.ItemIndex = 10), 'End, Enter picked Strawberry');
    with FruitCombo.ScreenRect do TUIPostClick(Right - 1, Top);
    Run;
    Check(FruitCombo.DroppedDown, 'a click on the arrow opened the list');
    TUIPostClick(0, ScrRows div 2); Run;
    Check(not FruitCombo.DroppedDown and (FruitCombo.Text = 'Strawberry'), 'a click outside closed it');

    { ---- add and delete }
    Key(Ord('I'), [ssAlt]); TUIPostString('Zambia'); Key(Ord('A'), [ssAlt]); Run;
    Check((CountryList.Count = 19) and (CountryList.Items[CountryList.ItemIndex] = 'Zambia'),
          'Add put Zambia in the list and selected it');
    Key(Ord('D'), [ssAlt]); Run;
    Check((CountryList.Count = 18) and (CountryList.Items.IndexOf('Zambia') < 0), 'Delete removed it');
    Key(VK_ESCAPE, []); Run;
    Check(not Visible, 'Esc (OK is the Cancel button) hid the Lists form');
  end;

  { ---- stage 3: memo }
  with MoreForm do
  begin
    Key(Ord('K'), [ssCtrl]); Run;
    Check(Visible and (ActiveControl = Memo1), 'Ctrl+K opened More controls, memo focused');
    Dump('More controls');
    Memo1.Clear; Run;
    TUIPostString('abc'); Key(VK_RETURN, []); TUIPostString('def'); Run;
    Check((Memo1.Lines.Count = 2) and (Memo1.Lines[0] = 'abc') and (Memo1.Lines[1] = 'def') and
          (Memo1.CaretPos.X = 3) and (Memo1.CaretPos.Y = 1), 'memo: typed two lines');
    Key(VK_HOME, []); Key(VK_BACK, []); Run;
    Check((Memo1.Lines.Count = 1) and (Memo1.Lines[0] = 'abcdef') and (Memo1.CaretPos.X = 3),
          'Backspace at a line start joined the lines');
    Key(VK_LEFT, [ssShift]); Key(VK_LEFT, [ssShift]); Run;
    Check(Memo1.SelText = 'bc', 'Shift+Left selected "bc"');
    Key(Ord('C'), [ssCtrl]); Key(VK_END, []); Key(Ord('V'), [ssCtrl]); Run;
    Check((Clipboard.AsText = 'bc') and (Memo1.Lines[0] = 'abcdefbc'), 'Ctrl+C, End, Ctrl+V');
    Key(VK_HOME, []); Key(VK_RETURN, []); Key(VK_UP, []); TUIPostString('top'); Run;
    Check((Memo1.Lines.Count = 2) and (Memo1.Lines[0] = 'top'), 'Enter at a line start, Up, typing');
    Key(Ord('A'), [ssCtrl]); TUIPostChar('x'); Run;
    Check(Memo1.Text = 'x' + LineEnding, 'Ctrl+A then a key replaced everything');
    { word wrap }
    Memo1.Text := 'The quick brown fox jumps over the lazy dog and keeps running ' +
                  'far away from the farm into the woods';
    Run;
    Key(VK_HOME, [ssCtrl]); Key(VK_DOWN, []); Run;
    Check((Memo1.Lines.Count = 1) and (Memo1.CaretPos.Y = 0) and (Memo1.CaretPos.X > 20),
          'word wrap: Down moved to the next screen row of the same line');
    for i := 1 to 20 do Memo1.Lines.Add('Line ' + IntToStr(i));
    Key(VK_END, [ssCtrl]); Run;
    Check((Memo1.CaretPos.Y = 20) and (Memo1.TopRow > 0), 'Ctrl+End scrolled down to the last line');
    Dump('memo with a vertical scroll bar');
    Key(Ord('W'), [ssAlt]); Run;
    Check(not Memo1.WordWrap, 'Alt+W turned word wrap off');
    Memo1.SetFocus; Key(VK_HOME, [ssCtrl]); Key(VK_END, []); Run;
    Check(Memo1.LeftCol > 0, 'no wrap: End scrolled sideways');
    Dump('memo without word wrap');
    Key(Ord('W'), [ssAlt]); Run;

    { pop-up menu }
    r := Memo1.ScreenRect;
    TUIPostMouse(r.Left + 3, r.Top + 2, 0);
    TUIPostMouse(r.Left + 3, r.Top + 2, 2);
    TUIPostMouse(r.Left + 3, r.Top + 2, 0);
    Run;
    Check(Application.OpenMenu = MemoMenu, 'right click opened the memo''s pop-up menu');
    Dump('memo pop-up menu');
    TUIPostChar('a'); Run;
    Check((Application.OpenMenu = nil) and (Memo1.SelText = TrimRight(Memo1.Text)),
          'Select all from the pop-up menu');
    Key(VK_F10, [ssShift]); Run;
    Check(Application.OpenMenu = MemoMenu, 'Shift+F10 opened it from the keyboard');
    Key(VK_ESCAPE, []); Run;
    Check(Application.OpenMenu = nil, 'Esc closed it');

    { radio group }
    Key(Ord('C'), [ssAlt]); Run;
    Check(ActiveControl = ColourGroup.Buttons(1), 'Alt+C focused the checked radio button');
    Key(VK_DOWN, []); Run;
    Check((ColourGroup.ItemIndex = 2) and (InfoText.Caption = 'Colour: Blue'), 'Down picked Blue');
    Key(VK_DOWN, []); Run;
    Check(ColourGroup.ItemIndex = 0, 'Down wrapped to Red');
    Key(VK_TAB, []); Run;
    Check(ActiveControl = ToppingList, 'Tab left the group (only one radio is a tab stop)');

    { check list box }
    Key(VK_SPACE, []); Key(VK_SPACE, []); Run;
    Check((ToppingList.ItemIndex = 0) and not ToppingList.Checked[0], 'Space selected, Space unchecked Cheese');
    Key(VK_DOWN, []); Key(VK_SPACE, []); Run;
    Check(ToppingList.Checked[1] and (InfoText.Caption = 'Toppings: Ham '), 'Down, Space checked Ham');
    r := ToppingList.ScreenRect;
    TUIPostClick(r.Left + 2, r.Top + 2); Run;
    Check(ToppingList.Checked[2], 'a click on the box checked Olives');
    TUIPostMouse(r.Left + 6, r.Top, 0); TUIPostMouse(r.Left + 6, r.Top, 2); TUIPostMouse(r.Left + 6, r.Top, 0);
    Run;
    Check(Application.OpenMenu = ToppingMenu, 'the check list has its own pop-up menu');
    TUIPostChar('a'); Run;
    Check(ToppingList.Checked[5] and ToppingList.Checked[0], 'Check all');

    { spin edit }
    Key(Ord('Q'), [ssAlt]); Key(VK_UP, []); Key(VK_UP, []); Key(VK_UP, []); Run;
    Check(QtySpin.Value = 4, 'spin: Up three times: ' + IntToStr(QtySpin.Value));
    TUIPostChar('x'); Run;
    Check(QtySpin.Value = 4, 'a letter is refused');
    Key(VK_PRIOR, []); Run;
    Check(QtySpin.Value = 14, 'PgUp: ten steps');
    r := QtySpin.ScreenRect;
    TUIPostClick(r.Right - 1, r.Top); Run;
    Check(QtySpin.Value = 13, 'click on the down arrow');
    Key(Ord('A'), [ssCtrl]); TUIPostString('150'); Key(VK_TAB, []); Run;
    Check(QtySpin.Value = 99, 'typed 150, left the field: clamped to MaxValue 99');

    { mask edits }
    Key(Ord('D'), [ssAlt]); TUIPostString('25122026'); Run;
    Check((DateEdit.EditText = '25/12/2026') and DateEdit.ValidateEdit, 'date mask: ' + DateEdit.EditText);
    Key(Ord('H'), [ssAlt]); TUIPostString('a55'); Key(VK_BACK, []); Run;
    Check(PhoneEdit.EditText = '(5__) ___-____', 'phone mask: letter refused, Backspace: ' + PhoneEdit.EditText);
    Check(not PhoneEdit.ValidateEdit, 'incomplete: ValidateEdit is false');
    TUIPostString('5512345678'); Run;
    Check((PhoneEdit.EditText = '(555) 123-4567') and (PhoneEdit.Text = '5551234567') and
          PhoneEdit.ValidateEdit, 'phone complete, Text without literals: ' + PhoneEdit.Text);

    { scroll bar }
    Key(Ord('V'), [ssAlt]); Key(VK_RIGHT, []); Key(VK_NEXT, []); Run;
    Check(VolumeBar.Position = 51, 'scroll bar: Right, PgDn: ' + IntToStr(VolumeBar.Position));
    Key(VK_END, []); Run;
    r := VolumeBar.ScreenRect;
    TUIPostClick(r.Left, r.Top); Run;
    Check(VolumeBar.Position = 99, 'End, click on the left arrow: 99');
    TUIPostClick(r.Left + 3, r.Top); Run;
    Check((VolumeBar.Position = 89) and (InfoText.Caption = 'Volume: 89'), 'click on the track: a page');

    { timers and the progress bar }
    n0 := Ticks;
    start := HWTicks;
    repeat Run until (Ticks > n0) or (HWTicks - start > 5000);
    Check((Ticks > n0) and (Pos('Time: ', ClockLabel.Caption) = 1), 'the clock TTimer ran: ' + ClockLabel.Caption);
    Key(Ord('S'), [ssAlt]); Run;
    Check(RunTimer.Enabled and (StartButton.Caption = '&Stop'), 'Start enabled the run timer');
    start := HWTicks;
    repeat Run until (Progress.Position >= 100) or (HWTicks - start > 15000);
    Check((Progress.Position = 100) and not RunTimer.Enabled and (InfoText.Caption = 'Progress done'),
          'the progress bar ran to 100% and the timer stopped');
    Dump('progress done');

    { an exception in an event }
    Key(Ord('R'), [ssAlt]); Run;
    Check(ErrorSeen, 'the error box was shown and closed');
    Key(VK_ESCAPE, []); Run;
    Check(not Visible, 'Esc (Close is the Cancel button) hid More controls');
  end;

  { ---- stage 4: containers }
  with PageForm do
  begin
    Key(Ord('P'), [ssCtrl]); Run;
    Check(Visible and IsActive and (ActiveControl = NameEdit) and (Pages.ActivePageIndex = 0),
          'Ctrl+P opened Containers on the General page');
    Dump('Containers');
    Check((NewButton.Left = 1) and (OpenButton.Left = NewButton.Left + NewButton.Width + 1) and
          (Sep1.Width = 1), 'the tool bar laid out its buttons');
    Check((SectionList.Align = alLeft) and (Splitter1.Left = SectionList.Width) and
          (Pages.Left = SectionList.Width + 1), 'list, splitter, page control side by side');
    hidden := false;
    for i := 1 to 8 do
    begin
      Key(VK_TAB, []); Run;
      if (ActiveControl = Fields[1]) or (ActiveControl = Notes) then hidden := true;
    end;
    Check(not hidden, 'Tab never reaches the controls of hidden pages');
    NameEdit.SetFocus; Run;
    Key(VK_TAB, [ssCtrl]); Run;
    Check((Pages.ActivePageIndex = 1) and (ActiveControl = Pages), 'Ctrl+Tab: next page, the focus on the tabs');
    Key(VK_RIGHT, []); Run;
    Check(Pages.ActivePageIndex = 2, 'Right on the tab row: next page');
    Key(VK_TAB, [ssCtrl, ssShift]); Run;
    Check((Pages.ActivePageIndex = 1) and (SectionList.ItemIndex = 1) and (ChangeCount >= 3),
          'Ctrl+Shift+Tab back; OnChange kept the list in step');

    { the scroll box }
    Key(VK_TAB, []); Run;
    Check(ActiveControl = Fields[1], 'Tab went into the scroll box');
    for i := 1 to 11 do Key(VK_TAB, []);
    Run;
    r := Box.ClientScreenRect;
    Check((ActiveControl = Fields[12]) and (Box.VertPosition > 0) and
          (Fields[12].ScreenRect.Top >= r.Top) and (Fields[12].ScreenRect.Bottom <= r.Bottom),
          'the focused field was scrolled into view: ' + IntToStr(Box.VertPosition));
    Dump('scroll box scrolled');
    for i := 1 to 11 do Key(VK_TAB, [ssShift]);
    Run;
    Check(Box.VertPosition = 0, 'Shift+Tab back to Field 1 scrolled back');
    TUIPostClick(r.Right, r.Bottom - 1); Run;
    Check(Box.VertPosition = 1, 'click on the vertical scroll bar''s down arrow');
    w0 := Box.HorzPosition;
    TUIPostClick(r.Left, r.Bottom); Run;
    Check((w0 > 0) and (Box.HorzPosition = w0 - 1),
          'the wide field scrolled sideways; the left arrow scrolls back one');
    Key(VK_NEXT, []); Run;
    Check(Box.VertPosition > 1, 'PgDn (not used by the edit) scrolled the box');

    { Alt+letter on a tab, clicks on tabs, OnChanging }
    Key(Ord('O'), [ssAlt]); Run;
    Check((Pages.ActivePageIndex = 2) and (ActiveControl = Pages), 'Alt+O picked the Notes tab');
    Key(VK_TAB, []); Run;
    Check(ActiveControl = Notes, 'Tab: into the memo on the Notes page');
    Key(VK_TAB, [ssCtrl]); Run;
    Check(Pages.ActivePageIndex = 0, 'Ctrl+Tab from the memo: wrapped to General');
    r := Pages.ScreenRect;
    TUIPostClick(r.Left + 13, r.Top); Run;
    Check(Pages.ActivePageIndex = 1, 'a click on the Scrolling tab');
    Pages.OnChanging := @Script.NoChange;
    Key(VK_RIGHT, []); Run;
    Check(Pages.ActivePageIndex = 1, 'OnChanging refused the change');
    Pages.OnChanging := nil;

    { the splitter }
    w0 := SectionList.Width;
    r := Splitter1.ScreenRect;
    TUIPostMouse(r.Left, r.Top + 3, 0);
    TUIPostMouse(r.Left, r.Top + 3, 1);
    TUIPostMouse(r.Left + 5, r.Top + 3, 1);
    TUIPostMouse(r.Left + 5, r.Top + 3, 0);
    Run;
    Check((SectionList.Width = w0 + 5) and (Pages.Left = w0 + 6) and
          (Status.SimpleText = 'List width: ' + IntToStr(w0 + 5)), 'dragging the splitter widened the list');
    r := Splitter1.ScreenRect;
    TUIPostMouse(r.Left, r.Top + 3, 0);
    TUIPostMouse(r.Left, r.Top + 3, 1);
    TUIPostMouse(r.Left - 30, r.Top + 3, 1);
    TUIPostMouse(r.Left - 30, r.Top + 3, 0);
    Run;
    Check(SectionList.Width = 8, 'and stops at MinSize');
    Dump('splitter moved');

    { tool buttons }
    r := BoldButton.ScreenRect;
    TUIPostClick(r.Left, r.Top); Run;
    Check(BoldButton.Down and (Status.SimpleText = 'Bold (on/off): on'), 'tbsCheck button: down');
    TUIPostClick(r.Left, r.Top); Run;
    Check(not BoldButton.Down, 'and up again');
    r := CenterButton.ScreenRect;
    TUIPostClick(r.Left + 1, r.Top); Run;
    Check(CenterButton.Down and not LeftButton.Down, 'GroupIndex: Center down, Left up');
    r := OpenButton.ScreenRect;
    TUIPostMouse(r.Left + 1, r.Top, 0); Run;
    Check(Pos('Open a document', RowText(Top + Height - 2)) > 0,
          'the mouse over a tool button shows its Hint in the status bar');

    Key(VK_ESCAPE, []); Run;
    Check(not Visible, 'Esc (KeyPreview) hid Containers');
  end;

  { ---- stage 5: grid }
  with DataForm do
  begin
    Key(Ord('D'), [ssCtrl]); Run;
    Check(Visible and (ActiveControl = Grid) and (Grid.Col = 1) and (Grid.Row = 1),
          'Ctrl+D opened Data views, the grid at 1,1');
    Dump('Data views: grid');
    Key(VK_RIGHT, []); Key(VK_RIGHT, []); Key(VK_DOWN, []); Run;
    Check((Grid.Col = 3) and (Grid.Row = 2) and (Status.SimpleText = 'Bread: Price'),
          'arrows moved the cell, OnSelection: ' + Status.SimpleText);
    Key(VK_END, [ssCtrl]); Run;
    Check((Grid.Col = 4) and (Grid.Row = 24) and (Grid.TopRow > 1), 'Ctrl+End: the last cell, scrolled');
    Key(VK_HOME, [ssCtrl]); Run;
    Check((Grid.Col = 1) and (Grid.Row = 1) and (Grid.TopRow = 1), 'Ctrl+Home: back');
    Key(VK_RIGHT, []); TUIPostString('10'); TUIPostKey(VK_RETURN, #13, []); Run;
    Check((Grid.Cells[2, 1] = '10') and not Grid.EditorMode and
          (Grid.Cells[4, 1] = FormatFloat('0.00', 10 * StrToFloat(Grid.Cells[3, 1]))),
          'typing edited the cell, Enter kept it, OnSetEditText: ' + Grid.Cells[4, 1]);
    Key(VK_F2, []); TUIPostString('99'); Run;
    Check(Grid.EditorMode, 'F2 opened the editor');
    Dump('grid editor');
    Key(VK_ESCAPE, []); Run;
    Check((Grid.Cells[2, 1] = '10') and not Grid.EditorMode and Visible, 'Esc threw the edit away');
    TUIPostChar('7'); Key(VK_DOWN, []); Run;
    Check((Grid.Cells[2, 1] = '7') and (Grid.Row = 2), 'Down kept the edit and moved');
    o := Grid.ScreenOrigin;
    TUIPostClick(o.X + Grid.ColX(1) + 2, o.Y); Run;
    ok := true;
    for i := 1 to Grid.RowCount - 2 do
      if CompareText(Grid.Cells[1, i], Grid.Cells[1, i + 1]) > 0 then ok := false;
    Check(ok and (Status.SimpleText = 'Sorted by Product up'), 'a header click sorted by Product');
    TUIPostClick(o.X + Grid.ColX(1) + 2, o.Y); Run;
    Check(Grid.Cells[1, 1] = 'Yogurt', 'again: the other way: ' + Grid.Cells[1, 1]);
    TUIPostClick(o.X + Grid.ColX(2) + 2, o.Y); Run;
    ok := true;
    for i := 1 to Grid.RowCount - 2 do
      if StrToInt(Grid.Cells[2, i]) > StrToInt(Grid.Cells[2, i + 1]) then ok := false;
    Check(ok, 'sorted by Qty as numbers');
    w0 := Grid.ColWidths[1];
    TUIPostMouse(o.X + Grid.ColX(1) + w0 - 1, o.Y, 0);
    TUIPostMouse(o.X + Grid.ColX(1) + w0 - 1, o.Y, 1);
    TUIPostMouse(o.X + Grid.ColX(1) + w0 + 3, o.Y, 1);
    TUIPostMouse(o.X + Grid.ColX(1) + w0 + 3, o.Y, 0);
    Run;
    Check(Grid.ColWidths[1] = w0 + 4, 'dragging a header''s edge widened the column');
    TUIPostClick(o.X + Grid.ColX(3) + 1, o.Y + 3); Run;
    Check((Grid.Col = 3) and (Grid.Row = 3), 'a click picked a cell');
    TUIPostClick(o.X + Grid.ColX(3) + 1, o.Y + 3); Run;
    Check(Grid.EditorMode, 'a double click opened the editor');
    Key(VK_ESCAPE, []); Run;
    TUIPostClick(o.X + Grid.Width - 1, o.Y + Grid.Height - 1); Run;
    Check(Grid.TopRow = 2, 'the scroll bar''s down arrow');
    Dump('grid sorted, column wider');
    { fewer rows than the grid is high: the title row stays gray to the }
    { right edge, the fixed column and the lines go on to the bottom    }
    Grid.RowCount := 6; Run;
    o := Grid.ScreenOrigin;
    x := Grid.ColX(4) + Grid.ColWidths[4] + 3;
    Check((CellAttr(o.X + x, o.Y) = Theme.MenuBar) and
          (CellAttr(o.X + Grid.Width - 1, o.Y) = Theme.MenuBar),
          'the title row is gray past the last column');
    y := Grid.Height - 1;
    Check((CellChar(o.X + Grid.ColX(1) + Grid.ColWidths[1] - 1, o.Y + y) = #179) and
          (CellChar(o.X + Grid.ColX(4) + Grid.ColWidths[4] - 1, o.Y + y) = #179) and
          (CellAttr(o.X + 1, o.Y + y) = Theme.MenuBar),
          'below the last row the column lines and the fixed column reach the bottom');
    Dump('grid with fewer rows than it is high');

    { ---- list view }
    Key(VK_TAB, [ssCtrl]); Key(VK_TAB, []); Key(VK_TAB, []); Run;
    Check((Pages.ActivePageIndex = 1) and (ActiveControl = Files), 'Ctrl+Tab, Tab, Tab: the list view');
    Key(VK_DOWN, []); Run;
    Check((Files.ItemIndex = 0) and (Pos('Selected: ', Status.SimpleText) = 1), 'Down: OnSelectItem');
    Key(VK_SPACE, []); Run;
    Check(Files.Items[0].Checked and (Pos(' checked', Status.SimpleText) > 0), 'Space checked it');
    o := Files.ScreenOrigin;
    TUIPostClick(o.X + 20, o.Y); Run;
    ok := true;
    for i := 0 to Files.Items.Count - 2 do
      if StrToInt(Files.Items[i].SubItems[0]) > StrToInt(Files.Items[i + 1].SubItems[0]) then ok := false;
    Check(ok and (Files.SortColumn = 1) and (Files.Items[Files.ItemIndex].Checked),
          'a click on Size sorted (numbers), the selection followed');
    TUIPostClick(o.X + 20, o.Y); Run;
    Check(Files.SortDirection = sdDescending, 'again: descending');
    TUIPostChar('t'); Run;
    Check(UpCase(Files.Selected.Caption[1]) = 'T', 'T jumped to ' + Files.Selected.Caption);
    Key(VK_END, []); Run;
    Check((Files.ItemIndex = 29) and (Files.TopIndex > 0), 'End: the last item, scrolled');
    Dump('list view');
    TUIPostMouse(o.X + 17, o.Y, 0); TUIPostMouse(o.X + 17, o.Y, 1);
    TUIPostMouse(o.X + 20, o.Y, 1); TUIPostMouse(o.X + 20, o.Y, 0); Run;
    Check(Files.Columns[0].Width = 21, 'dragging the Name header''s edge');
    TUIPostClick(o.X + 6, o.Y + 2); TUIPostClick(o.X + 6, o.Y + 2); Run;
    Check(Pos('Open ', Status.SimpleText) = 1, 'double click: OnDblClick');
    while Files.Items.Count > 5 do Files.Items.Delete(Files.Items.Count - 1);
    Run;
    o := Files.ScreenOrigin;
    Check((CellAttr(o.X + Files.Width - 1, o.Y) = Theme.MenuBar) and
          (CellChar(o.X + Files.Columns[0].Width - 1, o.Y + Files.Height - 1) = #179),
          'list view: the header is gray to the edge, the grid lines reach the bottom');
    Dump('list view with 5 items');
    Key(Ord('R'), [ssAlt]); Run;
    Check(Files.ViewStyle = vsList, 'Alt+R: list style');
    Dump('list view, vsList');
    Key(Ord('R'), [ssAlt]); Run;

    { ---- tree view }
    Key(VK_TAB, [ssCtrl]); Key(VK_TAB, []); Run;
    Check((Pages.ActivePageIndex = 2) and (ActiveControl = Tree) and (Tree.Selected.Text = 'Computer'),
          'the Tree page, the root selected');
    Check(Tree.VisibleRowCount = 5, 'the root open: 5 rows');
    Key(VK_DOWN, []); Key(VK_RIGHT, []); Key(VK_RIGHT, []); Run;
    Check((Tree.Selected.Text = 'FPC') and (PathLabel.Caption = 'Computer/C:/FPC'),
          'Down, Right (open), Right (first child); OnChange: ' + PathLabel.Caption);
    Key(VK_LEFT, []); Run;
    Check(Tree.Selected.Text = 'C:', 'Left: to the parent');
    Key(VK_LEFT, []); Run;
    Check(not Tree.Selected.Expanded and (Tree.VisibleRowCount = 5), 'Left again: closed');
    Key(VK_RIGHT, []); TUIPostChar('d'); TUIPostChar('d'); Run;
    Check(Pos('D:', Tree.Selected.Text) = 1, 'D, D: jumped to ' + Tree.Selected.Text);
    Key(VK_RIGHT, []); Run;
    Check((LazyFilled = 1) and (Tree.Selected.Count = 5) and Tree.Selected.Expanded,
          'OnExpanding filled D: when it was opened');
    Dump('tree view');
    o := Tree.ScreenOrigin;
    y := -1;
    for i := 0 to Tree.Height - 1 do
      if (Tree.GetNodeAt(2, i) <> nil) and (Tree.GetNodeAt(2, i).Text = 'GAMES') then y := i;
    TUIPostClick(o.X + 6, o.Y + y); Run;
    nd := Tree.Items.FindNodeWithText('GAMES');
    Check((y >= 0) and nd.Expanded, 'a click on GAMES'' [+] opened it');
    TUIPostChar('*'); Run;
    Check(Tree.Selected.Expanded, '* opens everything below');
    i := Tree.Items.Count;
    Tree.Items.Delete(Tree.Items.FindNodeWithText('Network')); Run;
    Check(Tree.Items.Count = i - 1, 'Items.Delete removed a node');
    Tree.FullCollapse; Run;
    Check((Tree.VisibleRowCount = 2) and (PathLabel.Caption = 'Computer'),
          'FullCollapse: the two roots; the selection moved up (OnChange)');

    { ---- track bars }
    Key(Ord('Z'), [ssAlt]); Key(VK_RIGHT, []); Run;
    Check((ActiveControl = Zoom) and (Zoom.Position = 6), 'track bar: Right');
    Key(VK_NEXT, []); Run;
    Check(Zoom.Position = 8, 'PgDn: a page');
    o := Zoom.ScreenOrigin;
    TUIPostClick(o.X + 10, o.Y); Run;
    Check((Zoom.Position = 5) and (Status.SimpleText = 'Zoom 5, level 2'), 'a click on the middle: 5');
    Key(Ord('E'), [ssAlt]); Key(VK_DOWN, []); Run;
    Check(Level.Position = 3, 'the vertical track bar: Down');
    Dump('tree collapsed, track bars');
    Key(VK_ESCAPE, []); Run;
    Check(not Visible, 'Esc hid Data views');
  end;

  { ---- stage 6: dialogs and actions (files in TUITMP) }
  tmp := ExpandFileName('TUITMP');
  ForceDirectories(tmp + DirectorySeparator + 'SUB');
  WriteText(tmp + DirectorySeparator + 'A.TXT', 'alpha');
  WriteText(tmp + DirectorySeparator + 'B.PAS', 'program b;');
  WriteText(tmp + DirectorySeparator + 'C.PAS', 'program c;');
  WriteText(tmp + DirectorySeparator + 'SUB' + DirectorySeparator + 'D.TXT', 'delta');
  DeleteFile(tmp + DirectorySeparator + 'NOTE1.TXT');
  DeleteFile(tmp + DirectorySeparator + 'NOTE1.txt');
  with EditForm do
  begin
    OpenDialog1.InitialDir := tmp;
    SaveDialog1.InitialDir := tmp;
    FolderDialog1.InitialDir := tmp;
    Key(Ord('E'), [ssCtrl]); Run;
    Check(Visible and (ActiveControl = Memo), 'Ctrl+E opened the Notepad');
    Check(not actCut.Enabled and not actCopy.Enabled and not ToolBtn('Cut').Enabled and
          not Menu1.Items[1].Items[0].Enabled, 'OnUpdate: Cut/Copy off (action, tool button, menu item)');
    Check((ToolBtn('Open') <> nil) and (Menu1.Items[0].Items[1].Caption = '&Open...') and
          (Menu1.Items[0].Items[1].ShortCut = ShortCut(Ord('O'), [ssCtrl])),
          'menu item and tool button took the action''s caption and shortcut (short caption kept)');
    TUIPostString('the cat sat on the mat'); Key(VK_RETURN, []); TUIPostString('and the cat ran'); Run;
    Key(Ord('A'), [ssCtrl]); Run;
    Check(actCut.Enabled and ToolBtn('Cut').Enabled and Menu1.Items[1].Items[1].Enabled,
          'a selection: Cut/Copy on everywhere');
    Dump('notepad');
    r := ToolBtn('Copy').ScreenRect;
    TUIPostClick(r.Left + 1, r.Top); Run;
    Check((Clipboard.AsText = 'the cat sat on the mat' + LineEnding + 'and the cat ran') and
          (Pos('Copied', LastMessage) = 1), 'the Copy tool button ran the action');

    { find }
    Key(VK_HOME, [ssCtrl]); Run;
    Key(Ord('F'), [ssCtrl]); Run;
    Check(FindDialog1.Visible, 'Ctrl+F (the action''s shortcut) showed Find');
    TUIPostString('cat'); TUIPostKey(VK_RETURN, #13, []); Run;
    Check((Memo.SelText = 'cat') and (Memo.SelStart = 4), 'Find next: the first "cat"');
    Dump('find dialog');
    TUIPostKey(VK_RETURN, #13, []); Run;
    Check((Memo.SelText = 'cat') and (Memo.CaretPos.Y = 1), 'again: the one on line 2');
    TUIPostKey(VK_RETURN, #13, []); Run;
    Check(Pos('Cannot find "cat"', Script.DlgLog) = 1, 'no more: a message');
    Key(Ord('N'), [ssAlt]); Key(Ord('A'), [ssCtrl]); TUIPostString('at');
    Key(Ord('W'), [ssAlt]); Run;
    Memo.SelStart := 0;
    TUIPostKey(VK_RETURN, #13, []); Run;
    Check(Pos('Cannot find "at"', Script.DlgLog) = 1, 'Whole word: "at" is not a word here');
    Key(VK_ESCAPE, []); Run;
    Check(not FindDialog1.Visible, 'Esc closed Find');

    { replace }
    Key(Ord('R'), [ssCtrl]); Run;
    Check(ReplaceDialog1.Visible, 'Ctrl+R showed Replace');
    Key(Ord('A'), [ssCtrl]); TUIPostString('cat');
    Key(Ord('P'), [ssAlt]); TUIPostString('dog');
    Key(Ord('C'), [ssAlt]);                 { Match case on: it does not matter here }
    Key(Ord('A'), [ssAlt]); Run;
    Check((Pos('cat', Memo.Text) = 0) and (LastMessage = 'Replaced 2') and
          (Memo.Lines[1] = 'and the dog ran'), 'Replace all: ' + LastMessage + ' [' +
          ReplaceDialog1.FindText + '/' + ReplaceDialog1.ReplaceText + '] ' + Memo.Text);
    Dump('replace dialog');
    Key(VK_ESCAPE, []); Run;

    { save as, overwrite }
    Script.DlgAction := 'save:NOTE1';
    Key(Ord('S'), [ssCtrl]); Run;
    Check(FileExists(tmp + DirectorySeparator + 'NOTE1.txt') and
          SameText(ExtractFileName(FileName), 'NOTE1.txt') and (LastMessage = 'Saved NOTE1.txt'),
          'Ctrl+S, no name yet: Save as, DefaultExt added: ' + FileName);
    Key(Ord('F'), [ssAlt]); TUIPostChar('a'); Run;
    Check((Script.ConfirmCount = 1) and (LastMessage = 'Saved NOTE1.txt'),
          'Save as the same name: asked to replace, Yes');

    { new, open }
    Key(Ord('N'), [ssCtrl]); Run;
    Check(Trim(Memo.Text) = '', 'Ctrl+N: a new text');
    Script.DlgAction := 'open';
    Script.DlgPhase := 0;
    Key(Ord('O'), [ssCtrl]); Run;
    Check(Script.OpenSawTxt, 'Open: the file list shows the *.txt files only');
    Check(Script.OpenSawSub, 'the folder list has .. and SUB');
    Check(Script.OpenSawPas, 'File type Pascal: B.PAS and C.PAS');
    Check((Memo.Lines.Count > 1) and (Memo.Lines[1] = 'and the dog ran') and
          SameText(LastMessage, 'Opened NOTE1.TXT'),
          'typed the name, Enter: opened it');
    Script.DlgAction := 'open-missing';
    Script.DlgPhase := 0;
    Key(Ord('O'), [ssCtrl]); Run;
    Check((Pos('File not found', Script.DlgLog) = 1) and (LastMessage = 'Open cancelled'),
          'a missing file: a warning (ofFileMustExist), then Esc');

    { folder, colour }
    Script.DlgAction := 'folder';
    Script.DlgPhase := 0;
    Key(Ord('F'), [ssAlt]); TUIPostChar('f'); Run;
    Check(Script.FolderEntered and (Copy(LastMessage, Length(LastMessage) - 2, 3) = 'SUB'),
          'Select a folder: into SUB, OK: ' + LastMessage);
    Key(Ord('O'), [ssAlt]); TUIPostChar('b'); Run;
    Check(Memo.Color = 3, 'Format|Background colour: two to the right of blue: cyan');

    { the hint window }
    r := ToolBtn('Open').ScreenRect;
    TUIPostMouse(r.Left + 1, r.Top, 0);
    start := HWTicks;
    repeat Run until Application.HintVisible or (HWTicks - start > 5000);
    Check(Application.HintVisible and (Application.HintText = 'Open') and
          (Pos(' Open ', RowText(r.Top + 1)) > 0), 'the mouse rests on Open: a hint window (short hint)');
    Check(Pos('Open a text file', RowText(Top + Height - 2)) > 0, 'and the long hint in the status bar');
    Dump('hint window');
    Key(VK_END, []); Run;
    Check(not Application.HintVisible, 'a key put it away');
    TUIPostMouse(0, 0, 0); Run;

    Key(Ord('F'), [ssAlt]); TUIPostChar('c'); Run;
    Check(not Visible, 'File|Close');
  end;

  { ---- stage 7: windows, the wheel, text modes }
  MainForm.Show; InfoForm.Show; ListForm.Show; Run;
  Check(Screen.ActiveForm = ListForm, 'three windows, Lists on top');
  Key(VK_F6, []); Run;
  Check(Screen.ActiveForm = MainForm, 'F6: the bottom window comes up');
  Key(VK_F6, []); Run;
  Check(Screen.ActiveForm = InfoForm, 'F6 again: Counter');
  Key(VK_F6, [ssShift]); Run;
  Check(Screen.ActiveForm = MainForm, 'Shift+F6: back (the top one went to the bottom)');
  Key(Ord('D'), [ssAlt]); Run;
  Check((MainForm.WindowMenu.Count = 3 + 16) and
        (Pos('Lists', MainForm.WindowMenu.Items[MainForm.WindowMenu.Count - 3 + 2].Caption) +
         Pos('Lists', MainForm.WindowMenu.Items[MainForm.WindowMenu.Count - 3 + 1].Caption) +
         Pos('Lists', MainForm.WindowMenu.Items[MainForm.WindowMenu.Count - 3].Caption) > 0),
        'the Window menu lists the 3 open windows: ' + IntToStr(MainForm.WindowMenu.Count));
  Dump('window menu with the window list');
  ok := false;
  for i := 16 to MainForm.WindowMenu.Count - 1 do
    if MainForm.WindowMenu.Items[i].Checked and
       (Pos('TUI demo', MainForm.WindowMenu.Items[i].Caption) > 0) then ok := true;
  Check(ok, 'the active window is checked');
  { the digit of the Lists entry (the list follows the z order) }
  for i := 16 to MainForm.WindowMenu.Count - 1 do
    if Pos('Lists', MainForm.WindowMenu.Items[i].Caption) > 0 then
      TUIPostChar(MainForm.WindowMenu.Items[i].Caption[2]);
  Run;
  Check(Screen.ActiveForm = ListForm, 'its digit brought Lists to the front: ' + Screen.ActiveForm.Caption);

  { the wheel }
  ListForm.CountryList.TopIndex := 0;
  r := ListForm.CountryList.ScreenRect;
  TUIPostWheel(r.Left + 2, r.Top + 2, -120); Run;
  Check(ListForm.CountryList.TopIndex = 3, 'wheel down a notch: the list scrolled 3 rows');
  TUIPostWheel(r.Left + 2, r.Top + 2, 240); Run;
  Check(ListForm.CountryList.TopIndex = 0, 'wheel up: back to the top');
  ListForm.CountryList.OnMouseWheel := @Script.EatWheel;
  TUIPostWheel(r.Left + 2, r.Top + 2, -120); Run;
  Check((Script.Wheels = 1) and (ListForm.CountryList.TopIndex = 0), 'OnMouseWheel took it (Handled)');
  ListForm.CountryList.OnMouseWheel := nil;
  r := ListForm.SizeCombo.ScreenRect;
  w0 := ListForm.CountryList.TopIndex;
  TUIPostWheel(r.Left + 2, r.Top, -120); Run;
  Check(ListForm.CountryList.TopIndex = w0, 'the wheel over another control does not scroll the list');

  { text modes: 132 x 50, or 132 x 25 where only that one is there }
  ok := Application.SetTextMode(132, 50);
  if not ok then
  begin
    writeln(Log, 'note  132 x 50 is not available on this video card (VESA text mode)');
    ok := Application.SetTextMode(132, 25);
  end;
  if ok then
  begin
    Run;
    Check((Screen.Width = 132) and (Pos('F10 Menu', RowText(Screen.Height - 1)) > 0) and
          (Application.StatusBar.Width = 132),
          '132 x ' + IntToStr(Screen.Height) + ': the screen bars moved to the new size');
    { (Alt+D alone would press the Lists form's Delete button: F10 first) }
    Key(VK_F10, []); Key(Ord('D'), [ssAlt]); TUIPostChar('i'); Run;
    if Screen.Height >= 50 then
      Check(WindowsTiled, 'Window|Tile: no overlaps, all on the desktop')
    else
      Check(WindowsInside, 'Window|Tile: all on the desktop (too small for no overlaps)');
    Dump('132 columns, tiled');
    Key(VK_F10, []); Key(Ord('D'), [ssAlt]); TUIPostChar('a'); Run;
    ok := true;
    n0 := 0;
    for i := 0 to Screen.FormCount - 1 do
      if Screen.Forms[i].Visible then
      begin
        if (Screen.Forms[i].Left <> 2 * n0) or (Screen.Forms[i].Top <> 1 + n0) then ok := false;
        inc(n0);
      end;
    Check(ok, 'Window|Cascade: each one 2 right, 1 down');
    MainForm.WindowState := wsMaximized; Run;
    Check(MainForm.Width = 132, 'maximized in 132 columns');
    Dump('132 columns, cascaded, main form maximized');
  end
  else
    writeln(Log, 'note  no 132 column mode on this video card');
  MainForm.WindowState := wsMaximized;
  Key(Ord('O'), [ssAlt]); TUIPostChar('e'); TUIPostChar('2'); Run;
  Check((Screen.Width = 80) and (Screen.Height = 50) and (MainForm.Width = 80) and WindowsInside,
        'Options|Screen|80 x 50: forms kept inside, the maximized one follows');
  Key(Ord('O'), [ssAlt]); TUIPostChar('e'); TUIPostChar('1'); Run;
  Check((Screen.Width = 80) and (Screen.Height = 25) and WindowsInside and
        (Pos('F10 Menu', RowText(24)) > 0), 'back to 80 x 25');
  MainForm.WindowState := wsNormal;
  InfoForm.Hide; ListForm.Hide; MainForm.Show; Run;
  Dump('back to 80 x 25');

  Key(VK_ESCAPE, []); Run;               { Close (Cancel) -> confirm -> Yes }
  Check(Application.Terminated, 'Esc, Yes: the application terminated');

  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  Script.Free;
end.
