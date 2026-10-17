unit MainFrm;

{ The main form of TUIDEMO, written the way Lazarus writes a form unit. The
  controls a Lazarus .lfm would hold are made in the constructor instead.
  Sizes are character cells; Left/Top of a control are inside the frame.

  The form also sets up the screen's menu bar (top row) and status bar
  (bottom row): Application.Menu and Application.StatusBar. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIMenu;

type

  { TMainForm }

  TMainForm = class(TForm)
    NameLabel: TLabel;
    NameEdit: TEdit;
    HelloButton: TButton;
    OptionsBox: TGroupBox;
    BoldCheck: TCheckBox;
    SoundCheck: TCheckBox;
    UpperCheck: TCheckBox;
    SizeBox: TGroupBox;
    SmallRadio: TRadioButton;
    MediumRadio: TRadioButton;
    LargeRadio: TRadioButton;
    AgeLabel: TLabel;
    AgeEdit: TEdit;
    CityLabel: TLabel;
    CityEdit: TEdit;
    StatusLabel: TLabel;
    InputButton: TButton;
    WindowButton: TButton;
    AboutButton: TButton;
    CloseButton: TButton;
    { the screen's menu bar and status bar }
    ScreenMenu: TMainMenu;
    FileMenu, NewNameItem, InputItem, ExitItem: TMenuItem;
    BoldItem, UpperItem, SmallItem, MediumItem, LargeItem: TMenuItem;
    ScreenStatus: TStatusBar;
    WindowMenu: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure HelloButtonClick(Sender: TObject);
    procedure NameEditChange(Sender: TObject);
    procedure OptionChange(Sender: TObject);
    procedure InputButtonClick(Sender: TObject);
    procedure WindowButtonClick(Sender: TObject);
    procedure AboutButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure NewNameItemClick(Sender: TObject);
    procedure ExitItemClick(Sender: TObject);
    procedure BoldItemClick(Sender: TObject);
    procedure UpperItemClick(Sender: TObject);
    procedure SizeItemClick(Sender: TObject);
    procedure HideCounterClick(Sender: TObject);
    procedure ListsClick(Sender: TObject);
    procedure MoreClick(Sender: TObject);
    procedure PagesClick(Sender: TObject);
    procedure DataClick(Sender: TObject);
    procedure ScreenModeClick(Sender: TObject);
    procedure NextWindowClick(Sender: TObject);
    procedure PrevWindowClick(Sender: TObject);
    procedure TileClick(Sender: TObject);
    procedure CascadeClick(Sender: TObject);
    procedure WindowMenuClick(Sender: TObject);
    procedure WindowItemClick(Sender: TObject);
    procedure NotepadClick(Sender: TObject);
    procedure LfmClick(Sender: TObject);
    procedure CodeClick(Sender: TObject);
    procedure MenuPanelClick(Sender: TObject);
  private
    WindowListStart: integer;
    procedure Status(const S: string);
    procedure MakeScreenBars;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

uses InfoFrm, ListFrm, MoreFrm, PageFrm, DataFrm, EditFrm, LfmDemo, CodeFrm;

{ what the .lfm does in Lazarus: make the controls and set their properties }
constructor TMainForm.Create(AOwner: TComponent);

  function NewLabel(AParent: TWinControl; X, Y: integer; const S: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Left := X;
    Result.Top := Y;
    Result.Caption := S;
  end;

  function NewButton(X, Y, W: integer; const S, AHint: string; Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(X, Y, W, 2);
    Result.Caption := S;
    Result.Hint := AHint;
    Result.OnClick := Handler;
  end;

  function NewCheck(AParent: TWinControl; Y: integer; const S: string): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := AParent;
    Result.SetBounds(1, Y, 10, 1);
    Result.Caption := S;
    Result.OnChange := @OptionChange;
  end;

  function NewRadio(Y: integer; const S: string): TRadioButton;
  begin
    Result := TRadioButton.Create(Self);
    Result.Parent := SizeBox;
    Result.SetBounds(1, Y, 10, 1);
    Result.Caption := S;
    Result.OnChange := @OptionChange;
  end;

begin
  inherited Create(AOwner);
  Caption := 'TUI demo - a Lazarus style form in text mode';
  SetBounds(0, 0, 62, 20);
  Position := poScreenCenter;
  Constraints.MinWidth := 62;          { resizable, but not smaller }
  Constraints.MinHeight := 20;
  OnCreate := @FormCreate;

  NameLabel := NewLabel(Self, 2, 1, '&Name:');
  NameEdit := TEdit.Create(Self);
  NameEdit.Parent := Self;
  NameEdit.SetBounds(10, 1, 28, 1);
  NameEdit.Text := 'World';
  NameEdit.Hint := 'Your name, for the Hello button';
  NameEdit.OnChange := @NameEditChange;
  NameLabel.FocusControl := NameEdit;
  HelloButton := NewButton(42, 1, 14, '&Hello', 'Say hello in a message box', @HelloButtonClick);
  HelloButton.Default := true;

  OptionsBox := TGroupBox.Create(Self);
  OptionsBox.Parent := Self;
  OptionsBox.SetBounds(2, 4, 26, 5);
  OptionsBox.Caption := 'Options';
  BoldCheck := NewCheck(OptionsBox, 0, '&Bold');
  SoundCheck := NewCheck(OptionsBox, 1, '&Sound');
  UpperCheck := NewCheck(OptionsBox, 2, '&Upper case');

  SizeBox := TGroupBox.Create(Self);
  SizeBox.Parent := Self;
  SizeBox.SetBounds(30, 4, 26, 5);
  SizeBox.Caption := 'Size';
  SmallRadio := NewRadio(0, 'S&mall');
  MediumRadio := NewRadio(1, 'M&edium');
  LargeRadio := NewRadio(2, '&Large');
  MediumRadio.Checked := true;

  AgeLabel := NewLabel(Self, 2, 10, 'A&ge:');
  AgeEdit := TEdit.Create(Self);
  AgeEdit.Parent := Self;
  AgeEdit.SetBounds(10, 10, 6, 1);
  AgeEdit.MaxLength := 3;
  AgeEdit.Hint := 'Up to three digits';
  AgeLabel.FocusControl := AgeEdit;
  CityLabel := NewLabel(Self, 20, 10, 'Ci&ty:');
  CityEdit := TEdit.Create(Self);
  CityEdit.Parent := Self;
  CityEdit.SetBounds(27, 10, 29, 1);
  CityEdit.Hint := 'Where you live (also File|Input city, F3)';
  CityLabel.FocusControl := CityEdit;

  StatusLabel := NewLabel(Self, 2, 12, '');
  StatusLabel.AutoSize := false;
  StatusLabel.SetBounds(2, 12, 54, 1);
  StatusLabel.Font.Color := clBlue;

  InputButton := NewButton(2, 15, 12, '&Input...', 'Ask for the city', @InputButtonClick);
  WindowButton := NewButton(16, 15, 12, '&Window', 'Show the Counter window', @WindowButtonClick);
  AboutButton := NewButton(30, 15, 12, '&About', 'About this demo', @AboutButtonClick);
  CloseButton := NewButton(44, 15, 12, '&Close', 'Quit the demo', @CloseButtonClick);
  CloseButton.Cancel := true;

  { what follows the window when it is resized (corner, zoom box, Ctrl+F5) }
  NameEdit.Anchors := [akLeft, akTop, akRight];
  HelloButton.Anchors := [akTop, akRight];
  SizeBox.Anchors := [akLeft, akTop, akRight];
  CityEdit.Anchors := [akLeft, akTop, akRight];
  StatusLabel.Anchors := [akLeft, akTop, akRight];
  InputButton.Anchors := [akLeft, akBottom];
  WindowButton.Anchors := [akLeft, akBottom];
  AboutButton.Anchors := [akLeft, akBottom];
  CloseButton.Anchors := [akLeft, akBottom];

  MakeScreenBars;
end;

{ the menu bar on the top row and the status bar on the bottom row of the }
{ screen. Two ways of building menus are shown: item by item as Lazarus's }
{ .lfm does it (File), and with NewSubMenu/NewItem (the rest)             }
procedure TMainForm.MakeScreenBars;
var p: TStatusPanel;
begin
  ScreenMenu := TMainMenu.Create(Self);

  FileMenu := TMenuItem.Create(Self);
  FileMenu.Caption := '&File';
  ScreenMenu.Items.Add(FileMenu);
  NewNameItem := TMenuItem.Create(Self);
  NewNameItem.Caption := '&New name';
  NewNameItem.ShortCut := ShortCut(Ord('N'), [ssCtrl]);
  NewNameItem.Hint := 'Clear the name and type a new one';
  NewNameItem.OnClick := @NewNameItemClick;
  FileMenu.Add(NewNameItem);
  InputItem := NewItem('&Input city...', ShortCut(VK_F3, []), false, true,
                       @InputButtonClick, 0, '');
  InputItem.Hint := 'Ask for the city';
  FileMenu.Add(InputItem);
  FileMenu.Add(NewLine);
  ExitItem := NewItem('E&xit', ShortCut(Ord('X'), [ssAlt]), false, true,
                      @ExitItemClick, 0, '');
  ExitItem.Hint := 'Quit the demo';
  FileMenu.Add(ExitItem);

  BoldItem := NewItem('&Bold', 0, false, true, @BoldItemClick, 0, '');
  UpperItem := NewItem('&Upper case', 0, false, true, @UpperItemClick, 0, '');
  SmallItem := NewItem('&Small', 0, false, true, @SizeItemClick, 0, '');
  MediumItem := NewItem('&Medium', 0, true, true, @SizeItemClick, 0, '');
  LargeItem := NewItem('&Large', 0, false, true, @SizeItemClick, 0, '');
  SmallItem.Tag := 0; MediumItem.Tag := 1; LargeItem.Tag := 2;
  ScreenMenu.Items.Add(NewSubMenu('&Options', 0, '', [
    BoldItem,
    UpperItem,
    NewLine,
    NewSubMenu('Si&ze', 0, '', [SmallItem, MediumItem, LargeItem]),
    NewSubMenu('Scr&een', 0, '', [
      NewItem('&1  80 x 25', 0, false, true, @ScreenModeClick, 0, ''),
      NewItem('&2  80 x 50', 0, false, true, @ScreenModeClick, 0, ''),
      NewItem('&3  132 x 25', 0, false, true, @ScreenModeClick, 0, ''),
      NewItem('&4  132 x 50', 0, false, true, @ScreenModeClick, 0, '')])]));

  WindowMenu := NewSubMenu('Win&dow', 0, '', [
    NewItem('&Counter', ShortCut(VK_F2, []), false, true, @WindowButtonClick, 0, ''),
    NewItem('&Hide counter', 0, false, true, @HideCounterClick, 0, ''),
    NewLine,
    NewItem('&Lists...', ShortCut(Ord('L'), [ssCtrl]), false, true, @ListsClick, 0, ''),
    NewItem('&More controls...', ShortCut(Ord('K'), [ssCtrl]), false, true, @MoreClick, 0, ''),
    NewItem('Con&tainers...', ShortCut(Ord('P'), [ssCtrl]), false, true, @PagesClick, 0, ''),
    NewItem('&Data views...', ShortCut(Ord('D'), [ssCtrl]), false, true, @DataClick, 0, ''),
    NewItem('&Notepad...', ShortCut(Ord('E'), [ssCtrl]), false, true, @NotepadClick, 0, ''),
    NewItem('LFM &form...', 0, false, true, @LfmClick, 0, ''),
    NewItem('Cod&e editor...', 0, false, true, @CodeClick, 0, ''),
    NewLine,
    NewItem('Ne&xt window', ShortCut(VK_F6, []), false, true, @NextWindowClick, 0, ''),
    NewItem('Pre&vious window', ShortCut(VK_F6, [ssShift]), false, true, @PrevWindowClick, 0, ''),
    NewItem('T&ile', 0, false, true, @TileClick, 0, ''),
    NewItem('C&ascade', 0, false, true, @CascadeClick, 0, ''),
    NewLine]);
  { the open windows are listed after the last line: filled when the menu }
  { opens (a TMenuItem with sub items gets OnClick then)                   }
  WindowListStart := WindowMenu.Count;
  WindowMenu.OnClick := @WindowMenuClick;
  ScreenMenu.Items.Add(WindowMenu);

  ScreenMenu.Items.Add(NewSubMenu('Hel&p', 0, '', [
    NewItem('&About...', ShortCut(VK_F1, []), false, true, @AboutButtonClick, 0, '')]));

  Application.Menu := ScreenMenu;

  ScreenStatus := TStatusBar.Create(Self);   { no Parent: the screen's }
  p := ScreenStatus.Panels.Add;
  p.Text := '~F1~ Help';
  p.OnClick := @AboutButtonClick;
  p := ScreenStatus.Panels.Add;
  p.Text := '~F2~ Counter';
  p.OnClick := @WindowButtonClick;
  p := ScreenStatus.Panels.Add;
  p.Text := '~F10~ Menu';
  p.OnClick := @MenuPanelClick;
  p := ScreenStatus.Panels.Add;
  p.Text := '~Alt+X~ Exit';
  p.OnClick := @ExitItemClick;
  Application.StatusBar := ScreenStatus;
end;

procedure TMainForm.Status(const S: string);
begin
  { OnChange can fire while the constructor is still making the controls }
  if StatusLabel <> nil then StatusLabel.Caption := S;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ActiveControl := NameEdit;
  Status('F10 menu, Tab/arrows move, Alt+letter or letter picks');
end;

procedure TMainForm.HelloButtonClick(Sender: TObject);
var s: string;
begin
  s := 'Hello, ' + NameEdit.Text + '!';
  if UpperCheck.Checked then s := UpperCase(s);
  ShowMessage(s);
end;

procedure TMainForm.NameEditChange(Sender: TObject);
begin
  Status('Name is now "' + NameEdit.Text + '"');
end;

procedure TMainForm.OptionChange(Sender: TObject);
var s: string;
begin
  s := '';
  if BoldCheck.Checked then s := s + 'bold ';
  if SoundCheck.Checked then s := s + 'sound ';
  if UpperCheck.Checked then s := s + 'upper ';
  if SmallRadio.Checked then s := s + '/ small'
  else if MediumRadio.Checked then s := s + '/ medium'
  else if (LargeRadio <> nil) and LargeRadio.Checked then s := s + '/ large';
  Status('Options: ' + s);
  { the menu shows the same state (it is made after the controls) }
  if BoldItem <> nil then
  begin
    BoldItem.Checked := BoldCheck.Checked;
    UpperItem.Checked := UpperCheck.Checked;
    SmallItem.Checked := SmallRadio.Checked;
    MediumItem.Checked := MediumRadio.Checked;
    LargeItem.Checked := LargeRadio.Checked;
  end;
end;

procedure TMainForm.InputButtonClick(Sender: TObject);
var s: string;
begin
  s := CityEdit.Text;
  if InputQuery('Input', 'Which city do you live in?', s) then
  begin
    CityEdit.Text := s;
    Status('City set to ' + s);
  end
  else
    Status('Input cancelled');
end;

procedure TMainForm.WindowButtonClick(Sender: TObject);
begin
  InfoForm.Show;
end;

procedure TMainForm.HideCounterClick(Sender: TObject);
begin
  InfoForm.Hide;
end;

procedure TMainForm.ListsClick(Sender: TObject);
begin
  ListForm.Show;
end;

procedure TMainForm.MoreClick(Sender: TObject);
begin
  MoreForm.Show;
end;

procedure TMainForm.PagesClick(Sender: TObject);
begin
  PageForm.Show;
end;

procedure TMainForm.ScreenModeClick(Sender: TObject);
var c, r: integer;
    m: TMenuItem;
begin
  m := TMenuItem(Sender);
  case m.Parent.IndexOf(m) of
    0: begin c := 80; r := 25; end;
    1: begin c := 80; r := 50; end;
    2: begin c := 132; r := 25; end;
  else
    c := 132; r := 50;
  end;
  if Application.SetTextMode(c, r) then
    Status('Screen: ' + IntToStr(Screen.Width) + ' x ' + IntToStr(Screen.Height))
  else
    Status('Not available here; now ' + IntToStr(Screen.Width) + ' x ' + IntToStr(Screen.Height));
end;

procedure TMainForm.NextWindowClick(Sender: TObject);
begin
  Application.NextWindow(false);
end;

procedure TMainForm.PrevWindowClick(Sender: TObject);
begin
  Application.NextWindow(true);
end;

procedure TMainForm.TileClick(Sender: TObject);
begin
  Application.Tile;
end;

procedure TMainForm.CascadeClick(Sender: TObject);
begin
  Application.Cascade;
end;

{ the Window menu opens: list the visible windows, the active one checked }
procedure TMainForm.WindowMenuClick(Sender: TObject);
var i, n: integer;
    f: TCustomForm;
    m: TMenuItem;
begin
  while WindowMenu.Count > WindowListStart do WindowMenu.Items[WindowMenu.Count - 1].Free;
  n := 0;
  for i := 0 to Screen.FormCount - 1 do
  begin
    f := Screen.Forms[i];
    if not f.Visible then continue;
    inc(n);
    m := TMenuItem.Create(Self);
    if n <= 9 then m.Caption := '&' + IntToStr(n) + ' ' + f.Caption
    else m.Caption := '  ' + f.Caption;
    m.Checked := f = Screen.ActiveForm;
    m.Tag := PtrInt(f);
    m.OnClick := @WindowItemClick;
    WindowMenu.Add(m);
  end;
end;

procedure TMainForm.WindowItemClick(Sender: TObject);
begin
  TCustomForm(TMenuItem(Sender).Tag).BringToFront;
end;

procedure TMainForm.DataClick(Sender: TObject);
begin
  DataForm.Show;
end;

procedure TMainForm.CodeClick(Sender: TObject);
begin
  CodeForm.Show;
end;

procedure TMainForm.LfmClick(Sender: TObject);
begin
  LfmForm.Show;            { its controls came from LFMDEMO.LFM }
end;

procedure TMainForm.NotepadClick(Sender: TObject);
begin
  EditForm.Show;
end;

procedure TMainForm.AboutButtonClick(Sender: TObject);
begin
  MessageDlg('About', 'TUI - Lazarus style forms for DOS text mode' + LineEnding +
             'Free Pascal go32v2' + LineEnding + LineEnding +
             'Screen: ' + IntToStr(Screen.Width) + ' x ' + IntToStr(Screen.Height),
             mtInformation, [mbOK], 0);
end;

procedure TMainForm.CloseButtonClick(Sender: TObject);
begin
  if MessageDlg('Quit the demo?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    Close;
end;

procedure TMainForm.NewNameItemClick(Sender: TObject);
begin
  NameEdit.Text := '';
  NameEdit.SetFocus;
end;

procedure TMainForm.ExitItemClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.BoldItemClick(Sender: TObject);
begin
  BoldCheck.Checked := not BoldCheck.Checked;
end;

procedure TMainForm.UpperItemClick(Sender: TObject);
begin
  UpperCheck.Checked := not UpperCheck.Checked;
end;

procedure TMainForm.SizeItemClick(Sender: TObject);
begin
  case TMenuItem(Sender).Tag of
    0: SmallRadio.Checked := true;
    1: MediumRadio.Checked := true;
    2: LargeRadio.Checked := true;
  end;
end;

procedure TMainForm.MenuPanelClick(Sender: TObject);
begin
  ScreenMenu.Activate;
end;

end.
