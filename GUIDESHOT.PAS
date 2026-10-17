program GuideShot;

{ Builds the examples of the user guide (GUIDE.MD / GUIDE.HTML), one at a
  time, and writes what the screen shows - characters and colours - to
  GUIDE.SHT. MKGUIDE.PY turns those dumps into the guide's screen pictures.
  Runs anywhere (DOS or the emulated screen):  fpc guideshot.pas }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIList, TUIMenu,
  TUIMemo, TUIExt, TUIPages, TUIGrid, TUIViews, TUIDlgs, LfmDemo, TUISyn, TUISynEd;

type
  TShots = class
    Pending: string;              { a modal dialog to photograph }
    Dummy: TNotifyEvent;
    procedure Idle(Sender: TObject);
    procedure Nothing(Sender: TObject);
  end;

var
  Shots: TShots;
  Outf: text;

procedure Run;
begin
  Application.ProcessMessages;
end;

{ the screen rectangle R (clamped) into GUIDE.SHT: a header, then per row  }
{ the characters and the attributes as hex                                 }
procedure Dump(const Name: string; R: TRect);
var buf: array[0..MaxCols - 1] of word;
    x, y: integer;
    sc, sa: string;
begin
  if R.Left < 0 then R.Left := 0;
  if R.Top < 0 then R.Top := 0;
  if R.Right > ScrCols then R.Right := ScrCols;
  if R.Bottom > ScrRows then R.Bottom := ScrRows;
  writeln(Outf, '@', Name, ' ', R.Right - R.Left, ' ', R.Bottom - R.Top);
  for y := R.Top to R.Bottom - 1 do
  begin
    HWReadCells(y * ScrCols + R.Left, buf[0], R.Right - R.Left);
    sc := ''; sa := '';
    for x := 0 to R.Right - R.Left - 1 do
    begin
      sc := sc + IntToHex(buf[x] and $FF, 2);
      sa := sa + IntToHex(buf[x] shr 8, 2);
    end;
    writeln(Outf, sc, ' ', sa);
  end;
end;

{ a form with its shadow and one cell of desktop around it }
procedure DumpForm(const Name: string; F: TCustomForm);
var r: TRect;
begin
  r := F.ScreenRect;
  Dump(Name, Rect(r.Left - 1, r.Top - 1, r.Right + 3, r.Bottom + 2));
end;

procedure TShots.Idle(Sender: TObject);
var m: TCustomForm;
begin
  m := Application.TopModal;
  if (m = nil) or (Pending = '') then exit;
  DumpForm(Pending, m);
  Pending := '';
  TUIPostKey(VK_ESCAPE, #27, []);
end;

procedure TShots.Nothing(Sender: TObject);
begin
end;

function NewForm(const ACaption: string; W, H: integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.Caption := ACaption;
  Result.SetBounds(2, 1, W, H);
end;

function Lbl(F: TWinControl; X, Y: integer; const S: string): TLabel;
begin
  Result := TLabel.Create(F);
  Result.Parent := F;
  Result.Left := X;
  Result.Top := Y;
  Result.Caption := S;
end;

function Btn(F: TWinControl; X, Y, W: integer; const S: string): TButton;
begin
  Result := TButton.Create(F);
  Result.Parent := F;
  Result.SetBounds(X, Y, W, 2);
  Result.Caption := S;
end;

function Edt(F: TWinControl; X, Y, W: integer; const S: string): TEdit;
begin
  Result := TEdit.Create(F);
  Result.Parent := F;
  Result.SetBounds(X, Y, W, 1);
  Result.Text := S;
end;

procedure Show(F: TForm; const Name: string);
begin
  F.Show;
  Run;
  DumpForm(Name, F);
  F.Free;
  Run;
end;

{=========================================================== the examples }

procedure ShotHello;
var f: TForm;
    e: TEdit;
    l: TLabel;
    b: TButton;
begin
  f := NewForm('Hello', 40, 8);
  l := Lbl(f, 2, 1, '&Name:');
  e := Edt(f, 9, 1, 26, 'World');
  l.FocusControl := e;
  b := Btn(f, 13, 3, 12, '&Greet');
  b.Default := true;
  f.ActiveControl := e;
  Show(f, 'hello');
end;

procedure ShotDialog;
var f: TForm;
    ok, cancel: TButton;
begin
  f := NewForm('Settings', 38, 8);
  f.BorderStyle := bsDialog;
  Lbl(f, 2, 1, 'Save the changes before closing?');
  ok := Btn(f, 6, 3, 12, 'OK');
  ok.Default := true;
  ok.ModalResult := mrOk;
  cancel := Btn(f, 20, 3, 12, 'Cancel');
  cancel.Cancel := true;
  cancel.ModalResult := mrCancel;
  f.ActiveControl := ok;
  Show(f, 'dialog');
end;

procedure ShotEdits;
var f: TForm;
    e1, e2, e3: TEdit;
begin
  f := NewForm('Login', 44, 9);
  e1 := Edt(f, 12, 1, 28, 'ann');
  Lbl(f, 2, 1, '&User:').FocusControl := e1;
  e2 := Edt(f, 12, 3, 28, 'secret');
  e2.PasswordChar := '*';
  Lbl(f, 2, 3, '&Password:').FocusControl := e2;
  e3 := Edt(f, 12, 5, 6, '');
  e3.MaxLength := 4;
  Lbl(f, 2, 5, 'P&IN:').FocusControl := e3;
  f.ActiveControl := e2;
  Show(f, 'edits');
end;

procedure ShotButtons;
var f: TForm;
    b: TButton;
begin
  f := NewForm('Buttons', 50, 6);
  b := Btn(f, 2, 1, 14, '&Default');
  b.Default := true;
  Btn(f, 18, 1, 14, '&Normal');
  b := Btn(f, 34, 1, 12, 'D&isabled');
  b.Enabled := false;
  f.ActiveControl := nil;
  Show(f, 'buttons');
end;

procedure ShotChecks;
var f: TForm;
    g: TGroupBox;
    c: TCheckBox;
    r: TRadioButton;
    rg: TRadioGroup;
begin
  f := NewForm('Options', 58, 11);
  g := TGroupBox.Create(f);
  g.Parent := f;
  g.SetBounds(1, 0, 24, 5);
  g.Caption := 'Style';
  c := TCheckBox.Create(f); c.Parent := g; c.Left := 1; c.Top := 0; c.Caption := '&Bold'; c.Checked := true;
  c := TCheckBox.Create(f); c.Parent := g; c.Left := 1; c.Top := 1; c.Caption := '&Italic';
  c := TCheckBox.Create(f); c.Parent := g; c.Left := 1; c.Top := 2; c.Caption := '&Underline';
  r := TRadioButton.Create(f); r.Parent := f; r.Left := 28; r.Top := 1; r.Caption := '&Left';
  r := TRadioButton.Create(f); r.Parent := f; r.Left := 28; r.Top := 2; r.Caption := '&Centre'; r.Checked := true;
  r := TRadioButton.Create(f); r.Parent := f; r.Left := 28; r.Top := 3; r.Caption := '&Right';
  rg := TRadioGroup.Create(f);
  rg.Parent := f;
  rg.SetBounds(1, 5, 54, 4);
  rg.Caption := '&Paper';
  rg.Columns := 3;
  rg.Items.CommaText := 'A4,A5,Letter,Legal,B5,Envelope';
  rg.ItemIndex := 2;
  f.ActiveControl := TWinControl(g.Controls[0]);
  Show(f, 'checks');
end;

procedure ShotPanels;
var f: TForm;
    p: TPanel;
    b: TBevel;
    s: TStaticText;
begin
  f := NewForm('Panels', 50, 11);
  p := TPanel.Create(f);
  p.Parent := f;
  p.SetBounds(1, 0, 22, 4);
  p.Border := pbSingle;
  p.Caption := 'A TPanel';
  p.Color := clCyan;
  s := TStaticText.Create(f);
  s.Parent := f;
  s.SetBounds(25, 0, 22, 4);
  s.BorderStyle := sbsSingle;
  s.Alignment := taCenter;
  s.Caption := 'TStaticText' + LineEnding + 'with a border';
  b := TBevel.Create(f);
  b.Parent := f;
  b.SetBounds(1, 5, 46, 1);
  b.Shape := bsTopLine;
  b := TBevel.Create(f);
  b.Parent := f;
  b.SetBounds(1, 6, 46, 3);
  b.Shape := bsBox;
  b.Style := bsRaised;
  Lbl(f, 3, 7, 'TBevel: a line above, a box here');
  Show(f, 'panels');
end;

procedure ShotLists;
var f: TForm;
    lb: TListBox;
    cl: TCheckListBox;
begin
  f := NewForm('Lists', 50, 11);
  lb := TListBox.Create(f);
  lb.Parent := f;
  lb.SetBounds(1, 1, 22, 7);
  lb.Items.CommaText := 'Apple,Banana,Cherry,Grape,Lemon,Mango,Orange,Peach,Pear,Plum';
  lb.ItemIndex := 2;
  Lbl(f, 1, 0, '&Fruit:').FocusControl := lb;
  cl := TCheckListBox.Create(f);
  cl.Parent := f;
  cl.SetBounds(25, 1, 22, 7);
  cl.Items.CommaText := 'Cheese,Ham,Olives,Onions,Peppers';
  cl.Checked[0] := true;
  cl.Checked[2] := true;
  Lbl(f, 25, 0, '&Toppings:').FocusControl := cl;
  f.ActiveControl := lb;
  Show(f, 'lists');
end;

procedure ShotCombo;
var f: TForm;
    c1, c2: TComboBox;
begin
  f := NewForm('Combo boxes', 50, 13);
  c1 := TComboBox.Create(f);
  c1.Parent := f;
  c1.SetBounds(9, 1, 18, 1);
  c1.Style := csDropDownList;
  c1.Items.CommaText := 'Small,Medium,Large,"Extra large"';
  c1.ItemIndex := 1;
  Lbl(f, 1, 1, '&Size:').FocusControl := c1;
  c2 := TComboBox.Create(f);
  c2.Parent := f;
  c2.SetBounds(9, 3, 18, 1);
  c2.Items.CommaText := 'Paris,Rome,Madrid,Lisbon,Athens,Vienna';
  c2.Text := 'Rome';
  Lbl(f, 1, 3, '&City:').FocusControl := c2;
  f.ActiveControl := c2;
  f.Show;
  Run;
  c2.DropDown;
  Run;
  DumpForm('combo', f);
  c2.CloseUp;
  f.Free;
  Run;
end;

procedure ShotMemo;
var f: TForm;
    m: TMemo;
begin
  f := NewForm('Notes', 44, 11);
  m := TMemo.Create(f);
  m.Parent := f;
  m.Align := alClient;
  m.ScrollBars := ssAutoVertical;
  m.Lines.Add('TMemo is a multi-line editor.');
  m.Lines.Add('');
  m.Lines.Add('With WordWrap (the default) long lines are broken at spaces to fit the width.');
  m.Lines.Add('Shift+arrows select; Ctrl+C, Ctrl+X and Ctrl+V use the clipboard.');
  m.Lines.Add('Line 6');
  m.Lines.Add('Line 7');
  m.Lines.Add('Line 8');
  m.Lines.Add('Line 9');
  f.ActiveControl := m;
  m.SelStart := 4;
  m.SelLength := 4;
  Show(f, 'memo');
end;

procedure ShotNumbers;
var f: TForm;
    sp: TSpinEdit;
    me: TMaskEdit;
    sb: TScrollBar;
    tb: TTrackBar;
    pb: TProgressBar;
begin
  f := NewForm('Numbers', 50, 13);
  sp := TSpinEdit.Create(f);
  sp.Parent := f;
  sp.SetBounds(12, 1, 8, 1);
  sp.MinValue := 1;
  sp.MaxValue := 99;
  sp.Value := 12;
  Lbl(f, 1, 1, '&Quantity:').FocusControl := sp;
  me := TMaskEdit.Create(f);
  me.Parent := f;
  me.SetBounds(12, 3, 12, 1);
  me.EditMask := '99/99/9999;1;_';
  me.Text := '2512';
  Lbl(f, 1, 3, '&Date:').FocusControl := me;
  sb := TScrollBar.Create(f);
  sb.Parent := f;
  sb.SetBounds(12, 5, 30, 1);
  sb.Position := 35;
  Lbl(f, 1, 5, '&Volume:').FocusControl := sb;
  tb := TTrackBar.Create(f);
  tb.Parent := f;
  tb.SetBounds(12, 7, 21, 1);
  tb.Max := 10;
  tb.Position := 7;
  Lbl(f, 1, 7, '&Zoom:').FocusControl := tb;
  pb := TProgressBar.Create(f);
  pb.Parent := f;
  pb.SetBounds(12, 9, 30, 1);
  pb.Position := 64;
  pb.BarShowText := true;
  Lbl(f, 1, 9, 'Progress:');
  f.ActiveControl := sp;
  Show(f, 'numbers');
end;

procedure ShotWindowMenu;
var f: TForm;
    mm: TMainMenu;
    sb: TStatusBar;
    p: TStatusPanel;
    m: TMemo;
begin
  f := NewForm('Editor', 44, 12);
  mm := TMainMenu.Create(f);
  mm.Items.Add(NewSubMenu('&File', 0, '', [
    NewItem('&New', ShortCut(Ord('N'), [ssCtrl]), false, true, nil, 0, ''),
    NewItem('&Open...', ShortCut(Ord('O'), [ssCtrl]), false, true, nil, 0, ''),
    NewItem('&Save', ShortCut(Ord('S'), [ssCtrl]), false, true, nil, 0, ''),
    NewLine,
    NewItem('E&xit', ShortCut(Ord('X'), [ssAlt]), false, true, nil, 0, '')]));
  mm.Items.Add(NewSubMenu('&Edit', 0, '', [NewItem('&Copy', 0, false, true, nil, 0, '')]));
  f.Menu := mm;
  sb := TStatusBar.Create(f);
  sb.Parent := f;
  p := sb.Panels.Add;
  p.Text := '~F10~ Menu';
  p := sb.Panels.Add;
  p.Text := 'Ln 1 Col 1';
  m := TMemo.Create(f);
  m.Parent := f;
  m.Align := alClient;
  m.Text := 'Some text.';
  f.ActiveControl := m;
  f.Show;
  Run;
  mm.Activate;
  Run;
  Dump('windowmenu', Rect(1, 0, 50, 15));
  mm.CloseMenu;
  f.Free;
  Run;
end;

procedure ShotScreen;
var f: TForm;
    mm: TMainMenu;
    sb: TStatusBar;
    p: TStatusPanel;
    l: TLabel;
begin
  mm := TMainMenu.Create(nil);
  mm.Items.Add(NewSubMenu('&File', 0, '', [NewItem('E&xit', ShortCut(Ord('X'), [ssAlt]), false, true, nil, 0, '')]));
  mm.Items.Add(NewSubMenu('&Window', 0, '', [NewItem('&Tile', 0, false, true, nil, 0, '')]));
  mm.Items.Add(NewSubMenu('&Help', 0, '', [NewItem('&About', 0, false, true, nil, 0, '')]));
  Application.Menu := mm;
  sb := TStatusBar.Create(nil);
  p := sb.Panels.Add; p.Text := '~F1~ Help';
  p := sb.Panels.Add; p.Text := '~F10~ Menu';
  p := sb.Panels.Add; p.Text := '~Alt+X~ Exit';
  Application.StatusBar := sb;
  f := NewForm('My program', 50, 10);
  f.Position := poScreenCenter;
  l := Lbl(f, 2, 2, 'The screen''s menu bar is on the top row,');
  l := Lbl(f, 2, 3, 'the status bar on the bottom row; forms');
  l := Lbl(f, 2, 4, 'live on the desktop between them.');
  if l = nil then;
  f.Show;
  Run;
  Dump('screen', Rect(0, 0, ScrCols, ScrRows));
  f.Free;
  Application.Menu := nil;
  Application.StatusBar := nil;
  mm.Free;
  sb.Free;
  Run;
end;

procedure ShotPopup;
var f: TForm;
    m: TMemo;
    pm: TPopupMenu;
begin
  f := NewForm('Pop-up menu', 44, 10);
  m := TMemo.Create(f);
  m.Parent := f;
  m.Align := alClient;
  m.Text := 'Right click (or Shift+F10) for the menu.';
  pm := TPopupMenu.Create(f);
  pm.Items.Add([NewItem('Cu&t', ShortCut(Ord('X'), [ssCtrl]), false, true, nil, 0, ''),
                NewItem('&Copy', ShortCut(Ord('C'), [ssCtrl]), false, true, nil, 0, ''),
                NewItem('&Paste', ShortCut(Ord('V'), [ssCtrl]), false, true, nil, 0, ''),
                NewLine,
                NewItem('Select &all', ShortCut(Ord('A'), [ssCtrl]), false, true, nil, 0, '')]);
  m.PopupMenu := pm;
  f.ActiveControl := m;
  f.Show;
  Run;
  pm.Popup(14, 4);
  Run;
  Dump('popup', Rect(1, 0, 48, 13));
  pm.CloseMenu;
  f.Free;
  Run;
end;

procedure ShotPages;
var f: TForm;
    pc: TPageControl;
    t1, t2, t3: TTabSheet;
    e: TEdit;
    c: TCheckBox;
begin
  f := NewForm('Preferences', 50, 11);
  pc := TPageControl.Create(f);
  pc.Parent := f;
  pc.Align := alClient;
  t1 := pc.AddTabSheet;
  t1.Caption := '&General';
  t2 := pc.AddTabSheet;
  t2.Caption := '&Editor';
  t3 := pc.AddTabSheet;
  t3.Caption := '&Colours';
  e := Edt(t1, 10, 1, 30, 'C:\WORK');
  Lbl(t1, 1, 1, '&Folder:').FocusControl := e;
  c := TCheckBox.Create(f);
  c.Parent := t1;
  c.SetBounds(10, 3, 24, 1);
  c.Caption := '&Save on exit';
  c.Checked := true;
  if t2 = t3 then;
  f.ActiveControl := pc;
  Show(f, 'pages');
end;

procedure ShotContainers;
var f: TForm;
    tb: TToolBar;
    b: TToolButton;
    lb: TListBox;
    sp: TSplitter;
    sbx: TScrollBox;
    i: integer;

  procedure Tool(const S: string; St: TToolButtonStyle);
  begin
    b := TToolButton.Create(f);
    b.Parent := tb;
    b.Style := St;
    b.Caption := S;
  end;

begin
  f := NewForm('Containers', 56, 13);
  tb := TToolBar.Create(f);
  tb.Parent := f;
  Tool('New', tbsButton);
  Tool('Open', tbsButton);
  Tool('', tbsSeparator);
  Tool('B', tbsCheck);
  b.Down := true;
  Tool('I', tbsCheck);
  lb := TListBox.Create(f);
  lb.Parent := f;
  lb.Width := 14;
  lb.Align := alLeft;
  lb.Items.CommaText := 'Name,Address,Phone';
  lb.ItemIndex := 0;
  sp := TSplitter.Create(f);
  sp.Parent := f;
  sp.Align := alLeft;
  sbx := TScrollBox.Create(f);
  sbx.Parent := f;
  sbx.Align := alClient;
  for i := 1 to 8 do
  begin
    Edt(sbx, 10, (i - 1) * 2, 26, 'Value ' + IntToStr(i));
    Lbl(sbx, 1, (i - 1) * 2, 'Field ' + IntToStr(i) + ':');
  end;
  f.ActiveControl := nil;
  Show(f, 'containers');
end;

procedure ShotGrid;
var f: TForm;
    g: TStringGrid;
    i: integer;
const
  Names: array[1..6] of string = ('Apples', 'Bread', 'Cheese', 'Milk', 'Rice', 'Tea');
begin
  f := NewForm('Shopping', 50, 11);
  g := TStringGrid.Create(f);
  g.Parent := f;
  g.Align := alClient;
  g.ColCount := 4;
  g.RowCount := 7;
  g.FixedCols := 0;
  g.Options := g.Options + [goEditing, goColSizing];
  g.ColWidths[0] := 16;
  g.ColWidths[1] := 8;
  g.ColWidths[2] := 10;
  g.ColWidths[3] := 10;
  g.ColAlignments[1] := taRightJustify;
  g.ColAlignments[2] := taRightJustify;
  g.ColAlignments[3] := taRightJustify;
  g.Cells[0, 0] := 'Product';
  g.Cells[1, 0] := 'Qty';
  g.Cells[2, 0] := 'Price';
  g.Cells[3, 0] := 'Total';
  for i := 1 to 6 do
  begin
    g.Cells[0, i] := Names[i];
    g.Cells[1, i] := IntToStr(i + 1);
    g.Cells[2, i] := FormatFloat('0.00', i * 1.25);
    g.Cells[3, i] := FormatFloat('0.00', (i + 1) * i * 1.25);
  end;
  f.ActiveControl := g;
  g.Col := 1;
  g.Row := 2;
  Show(f, 'grid');
end;

procedure ShotListView;
var f: TForm;
    lv: TListView;
    c: TListColumn;
    it: TListItem;
    i: integer;
const
  Files: array[1..6] of string = ('README.TXT', 'TUIDEMO.EXE', 'TUICTRL.PAS', 'NOTES.TXT', 'MAIN.PAS', 'DATA.DAT');
  Sizes: array[1..6] of string = ('1204', '428864', '96211', '310', '7718', '20480');
begin
  f := NewForm('Files', 52, 11);
  lv := TListView.Create(f);
  lv.Parent := f;
  lv.Align := alClient;
  lv.Checkboxes := true;
  lv.GridLines := true;
  c := lv.Columns.Add; c.Caption := 'Name'; c.Width := 20;
  c := lv.Columns.Add; c.Caption := 'Size'; c.Width := 9; c.Alignment := taRightJustify;
  c := lv.Columns.Add; c.Caption := 'Type'; c.Width := 6;
  for i := 1 to 6 do
  begin
    it := lv.Items.Add;
    it.Caption := Files[i];
    it.SubItems.Add(Sizes[i]);
    it.SubItems.Add(ExtractFileExt(Files[i]));
  end;
  lv.Items[1].Checked := true;
  lv.SortColumn := 0;
  lv.AlphaSort;
  lv.ItemIndex := 2;
  f.ActiveControl := lv;
  Show(f, 'listview');
end;

procedure ShotTree;
var f: TForm;
    tv: TTreeView;
    root, c, n: TTreeNode;
begin
  f := NewForm('Folders', 40, 13);
  tv := TTreeView.Create(f);
  tv.Parent := f;
  tv.Align := alClient;
  root := tv.Items.Add(nil, 'C:');
  n := tv.Items.AddChild(root, 'DOS');
  c := tv.Items.AddChild(root, 'FPC');
  tv.Items.AddChild(c, 'bin');
  tv.Items.AddChild(c, 'units');
  tv.Items.AddChild(c, 'source');
  n := tv.Items.AddChild(root, 'GAMES');
  tv.Items.AddChild(n, 'DIGGER');
  n := tv.Items.AddChild(root, 'TEMP');
  n.HasChildren := true;
  root.Expanded := true;
  c.Expanded := true;
  tv.Selected := c.Items[1];
  f.ActiveControl := tv;
  Show(f, 'tree');
end;

procedure ShotLfm;
var f: TLfmForm;
begin
  f := TLfmForm.Create(nil);       { reads LFMDEMO.LFM }
  f.Timer1.Enabled := false;
  f.Show;
  Run;
  DumpForm('lfm', f);
  f.Free;
  Run;
end;

procedure ShotSynEdit;
var f: TForm;
    ed: TSynEdit;
    pas: TSynPasSyn;
    bas: TSynQBasicSyn;
begin
  f := NewForm('HELLO.PAS', 60, 15);
  pas := TSynPasSyn.Create(f);
  ed := TSynEdit.Create(f);
  ed.Parent := f;
  ed.Align := alClient;
  ed.Highlighter := pas;
  ed.Lines.Add('program Hello;');
  ed.Lines.Add('{$mode objfpc}{$H+}');
  ed.Lines.Add('uses SysUtils;');
  ed.Lines.Add('(* a comment over');
  ed.Lines.Add('   two lines *)');
  ed.Lines.Add('var i: integer;');
  ed.Lines.Add('begin');
  ed.Lines.Add('  for i := 1 to 10 do      // a loop');
  ed.Lines.Add('    WriteLn(''Hello '', i, $FF, #13);');
  ed.Lines.Add('end.');
  f.ActiveControl := ed;
  ed.CaretXY := Point(7, 8);
  ed.BlockBegin := Point(3, 8);
  ed.BlockEnd := Point(6, 8);
  Show(f, 'synedit');
  f := NewForm('SAMPLE.BAS', 60, 15);
  bas := TSynQBasicSyn.Create(f);
  ed := TSynEdit.Create(f);
  ed.Parent := f;
  ed.Align := alClient;
  ed.Highlighter := bas;
  ed.Lines.Add('''$DYNAMIC');
  ed.Lines.Add('DECLARE SUB DrawBox (x%, y%, w%, h%)');
  ed.Lines.Add('CONST MaxItems = 10');
  ed.Lines.Add('DIM SHARED names$(1 TO MaxItems)');
  ed.Lines.Add('CLS: COLOR 14, 1');
  ed.Lines.Add('10 PRINT "Shopping list"');
  ed.Lines.Add('Again:');
  ed.Lines.Add('    k$ = INKEY$');
  ed.Lines.Add('    IF k$ = "" THEN GOTO Again');
  ed.Lines.Add('    REM other keys draw a box');
  ed.Lines.Add('    x& = &HFF + 70000&');
  ed.Lines.Add('GOTO Again');
  f.ActiveControl := ed;
  Show(f, 'synqbasic');
end;

procedure ShotMessage;
begin
  Shots.Pending := 'messagedlg';
  MessageDlg('Save the changes to NOTES.TXT?', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
end;

procedure ShotInput;
var s: string;
begin
  s := 'Lisbon';
  Shots.Pending := 'inputquery';
  InputQuery('City', 'Which city do you live in?', s);
end;

procedure ShotOpen;
var d: TOpenDialog;
    t: TStringList;
    dir: string;
begin
  dir := ExpandFileName('GUIDETMP');
  ForceDirectories(dir + DirectorySeparator + 'DOCS');
  ForceDirectories(dir + DirectorySeparator + 'SRC');
  t := TStringList.Create;
  t.Add('x');
  t.SaveToFile(dir + DirectorySeparator + 'README.TXT');
  t.SaveToFile(dir + DirectorySeparator + 'NOTES.TXT');
  t.SaveToFile(dir + DirectorySeparator + 'TODO.TXT');
  t.SaveToFile(dir + DirectorySeparator + 'MAIN.PAS');
  t.Free;
  d := TOpenDialog.Create(nil);
  d.InitialDir := dir;
  d.Filter := 'Text files|*.txt|Pascal|*.pas|All files|*.*';
  d.Options := [ofFileMustExist];
  Shots.Pending := 'opendialog';
  d.Execute;
  d.Free;
end;

procedure ShotColour;
var d: TColorDialog;
begin
  d := TColorDialog.Create(nil);
  d.Color := clLightCyan;
  Shots.Pending := 'colordialog';
  d.Execute;
  d.Free;
end;

procedure ShotFind;
var d: TFindDialog;
begin
  d := TFindDialog.Create(nil);
  d.FindText := 'cat';
  d.Options := [frDown];
  d.Execute;
  Run;
  DumpForm('finddialog', d.Form);
  d.Free;
  Run;
end;

procedure ShotHint;
var f: TForm;
    tb: TToolBar;
    b: TToolButton;
    m: TMemo;
    start: longint;
begin
  f := NewForm('Hints', 44, 8);
  f.ShowHint := true;
  tb := TToolBar.Create(f);
  tb.Parent := f;
  b := TToolButton.Create(f); b.Parent := tb; b.Caption := 'New'; b.Hint := 'New|Start a new text';
  b := TToolButton.Create(f); b.Parent := tb; b.Caption := 'Open'; b.Hint := 'Open|Open a file';
  m := TMemo.Create(f);
  m.Parent := f;
  m.Align := alClient;
  f.ActiveControl := m;
  f.Show;
  Run;
  TUIPostMouse(b.ScreenRect.Left + 1, b.ScreenRect.Top, 0);
  start := HWTicks;
  repeat Run until Application.HintVisible or (HWTicks - start > 3000);
  DumpForm('hint', f);
  TUIPostMouse(0, 24, 0);
  Run;
  f.Free;
  Run;
end;

procedure ShotTile;
var a, b, c: TForm;
begin
  a := NewForm('Accounts', 40, 10);
  b := NewForm('Invoices', 40, 10);
  c := NewForm('Customers', 40, 10);
  Lbl(a, 1, 1, 'Window 1');
  Lbl(b, 1, 1, 'Window 2');
  Lbl(c, 1, 1, 'Window 3');
  a.Show; b.Show; c.Show;
  Application.Cascade;
  Run;
  Dump('cascade', Rect(0, 0, ScrCols, ScrRows));
  Application.Tile;
  Run;
  Dump('tile', Rect(0, 0, ScrCols, ScrRows));
  a.Free; b.Free; c.Free;
  Run;
end;

begin
  Assign(Outf, 'GUIDE.SHT');
  Rewrite(Outf);
  Shots := TShots.Create;
  TUIMouseCursor := false;
  Application.Initialize;
  Application.OnIdle := @Shots.Idle;
  Run;
  ShotHello;
  ShotDialog;
  ShotLfm;
  ShotEdits;
  ShotButtons;
  ShotChecks;
  ShotPanels;
  ShotLists;
  ShotCombo;
  ShotMemo;
  ShotNumbers;
  ShotWindowMenu;
  ShotScreen;
  ShotPopup;
  ShotPages;
  ShotContainers;
  ShotGrid;
  ShotListView;
  ShotTree;
  ShotSynEdit;
  ShotMessage;
  ShotInput;
  ShotOpen;
  ShotColour;
  ShotFind;
  ShotHint;
  ShotTile;
  Close(Outf);
  Shots.Free;
end.
