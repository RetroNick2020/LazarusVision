unit MoreFrm;

{ Stage 3 controls: TMemo with a pop-up menu, TRadioGroup, TCheckListBox,
  TSpinEdit, TMaskEdit, TScrollBar, TProgressBar, TStaticText, TBevel and
  two TTimers (a clock and a progress run), plus an exception raised in an
  OnClick to show the error box. Opened from Window|More controls (Ctrl+K). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIList, TUIMenu, TUIMemo, TUIExt;

type

  { TMoreForm }

  TMoreForm = class(TForm)
    MemoLabel: TLabel;
    Memo1: TMemo;
    MemoMenu: TPopupMenu;
    WrapCheck: TCheckBox;
    InfoText: TStaticText;
    ColourGroup: TRadioGroup;
    ToppingLabel: TLabel;
    ToppingList: TCheckListBox;
    ToppingMenu: TPopupMenu;
    QtyLabel: TLabel;
    QtySpin: TSpinEdit;
    DateLabel: TLabel;
    DateEdit: TMaskEdit;
    PhoneLabel: TLabel;
    PhoneEdit: TMaskEdit;
    VolumeLabel: TLabel;
    VolumeBar: TScrollBar;
    ProgressLabel: TLabel;
    Progress: TProgressBar;
    ClockLabel: TLabel;
    Line: TBevel;
    StartButton: TButton;
    ErrorButton: TButton;
    CloseButton: TButton;
    ClockTimer: TTimer;
    RunTimer: TTimer;
    procedure ClockTimerTimer(Sender: TObject);
    procedure RunTimerTimer(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
    procedure ErrorButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure WrapCheckChange(Sender: TObject);
    procedure ColourGroupClick(Sender: TObject);
    procedure ToppingListClickCheck(Sender: TObject);
    procedure QtySpinChange(Sender: TObject);
    procedure VolumeBarChange(Sender: TObject);
    procedure MaskChange(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure SelectAllClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure CheckAllClick(Sender: TObject);
    procedure UncheckAllClick(Sender: TObject);
  private
    procedure Info(const S: string);
  public
    Ticks: integer;      { clock timer calls (the test reads it) }
    constructor Create(AOwner: TComponent); override;
  end;

var
  MoreForm: TMoreForm;

implementation

constructor TMoreForm.Create(AOwner: TComponent);

  function NewLabel(X, Y: integer; const S: string; F: TWinControl): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Left := X;
    Result.Top := Y;
    Result.Caption := S;
    Result.FocusControl := F;
  end;

  function NewMask(X, Y, W: integer; const M: string): TMaskEdit;
  begin
    Result := TMaskEdit.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(X, Y, W, 1);
    Result.EditMask := M;
    Result.OnChange := @MaskChange;
  end;

  function NewButton(X, Y, W: integer; const S: string; H: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(X, Y, W, 2);
    Result.Caption := S;
    Result.OnClick := H;
  end;

begin
  inherited Create(AOwner);
  Caption := 'More controls';
  SetBounds(0, 0, 76, 21);
  Position := poScreenCenter;
  Constraints.MinWidth := 76;
  Constraints.MinHeight := 21;

  { ---- left: memo, word wrap, info }
  Memo1 := TMemo.Create(Self);
  Memo1.Parent := Self;
  Memo1.SetBounds(1, 1, 36, 9);
  Memo1.ScrollBars := ssAutoBoth;
  Memo1.Anchors := [akLeft, akTop, akRight, akBottom];
  Memo1.Hint := 'Right click or Shift+F10: Cut, Copy, Paste...';
  Memo1.Lines.Add('TMemo: a multi-line editor. Type, select with Shift+arrows or the mouse, ' +
                  'right click for the pop-up menu.');
  Memo1.Lines.Add('');
  Memo1.Lines.Add('Word wrap breaks lines at spaces; turn it off below to get a ' +
                  'horizontal scroll bar instead.');
  Memo1.Lines.Add('');
  Memo1.Lines.Add('Line 5');
  Memo1.Lines.Add('Line 6');
  Memo1.Lines.Add('Line 7');
  Memo1.Lines.Add('Line 8');
  Memo1.Lines.Add('The end.');
  MemoLabel := NewLabel(1, 0, '&Memo:', Memo1);

  MemoMenu := TPopupMenu.Create(Self);
  MemoMenu.Items.Add([
    NewItem('Cu&t', ShortCut(Ord('X'), [ssCtrl]), false, true, @CutClick, 0, ''),
    NewItem('&Copy', ShortCut(Ord('C'), [ssCtrl]), false, true, @CopyClick, 0, ''),
    NewItem('&Paste', ShortCut(Ord('V'), [ssCtrl]), false, true, @PasteClick, 0, ''),
    NewLine,
    NewItem('Select &all', ShortCut(Ord('A'), [ssCtrl]), false, true, @SelectAllClick, 0, ''),
    NewItem('C&lear', 0, false, true, @ClearClick, 0, '')]);
  Memo1.PopupMenu := MemoMenu;

  WrapCheck := TCheckBox.Create(Self);
  WrapCheck.Parent := Self;
  WrapCheck.SetBounds(1, 10, 14, 1);
  WrapCheck.Caption := 'Word &wrap';
  WrapCheck.Checked := true;
  WrapCheck.Anchors := [akLeft, akBottom];
  WrapCheck.OnChange := @WrapCheckChange;

  InfoText := TStaticText.Create(Self);
  InfoText.Parent := Self;
  InfoText.SetBounds(1, 12, 36, 3);
  InfoText.BorderStyle := sbsSingle;
  InfoText.ShowAccelChar := false;
  InfoText.Anchors := [akLeft, akRight, akBottom];

  ClockLabel := NewLabel(1, 15, 'Time:', nil);
  ClockLabel.Anchors := [akLeft, akBottom];

  { ---- right: radio group, check list, spin, masks, scroll bar, progress }
  ColourGroup := TRadioGroup.Create(Self);
  ColourGroup.Parent := Self;
  ColourGroup.SetBounds(39, 0, 16, 5);
  ColourGroup.Caption := '&Colour';
  ColourGroup.Items.Add('Red');
  ColourGroup.Items.Add('Green');
  ColourGroup.Items.Add('Blue');
  ColourGroup.ItemIndex := 1;
  ColourGroup.Anchors := [akTop, akRight];
  ColourGroup.OnClick := @ColourGroupClick;

  ToppingList := TCheckListBox.Create(Self);
  ToppingList.Parent := Self;
  ToppingList.SetBounds(57, 1, 16, 4);
  ToppingList.Items.CommaText := 'Cheese,Ham,Olives,Onions,Peppers,Pineapple';
  ToppingList.Checked[0] := true;
  ToppingList.Anchors := [akTop, akRight];
  ToppingList.Hint := 'Space or a click on [ ] checks';
  ToppingList.OnClickCheck := @ToppingListClickCheck;
  ToppingLabel := NewLabel(57, 0, '&Toppings:', ToppingList);
  ToppingLabel.Anchors := [akTop, akRight];
  ToppingMenu := TPopupMenu.Create(Self);
  ToppingMenu.Items.Add([
    NewItem('Check &all', 0, false, true, @CheckAllClick, 0, ''),
    NewItem('&Uncheck all', 0, false, true, @UncheckAllClick, 0, '')]);
  ToppingList.PopupMenu := ToppingMenu;

  QtySpin := TSpinEdit.Create(Self);
  QtySpin.Parent := Self;
  QtySpin.SetBounds(50, 6, 8, 1);
  QtySpin.MinValue := 1;
  QtySpin.MaxValue := 99;
  QtySpin.Value := 1;
  QtySpin.Anchors := [akTop, akRight];
  QtySpin.Hint := 'Up/Down, PgUp/PgDn or the arrows';
  QtySpin.OnChange := @QtySpinChange;
  QtyLabel := NewLabel(39, 6, '&Quantity:', QtySpin);
  QtyLabel.Anchors := [akTop, akRight];

  DateEdit := NewMask(50, 8, 12, '99/99/9999;1;_');
  DateEdit.Anchors := [akTop, akRight];
  DateEdit.Hint := 'dd/mm/yyyy';
  DateLabel := NewLabel(39, 8, '&Date:', DateEdit);
  DateLabel.Anchors := [akTop, akRight];
  PhoneEdit := NewMask(50, 10, 16, '(999) 000-0000;0;_');
  PhoneEdit.Anchors := [akTop, akRight];
  PhoneEdit.Hint := 'Area code optional';
  PhoneLabel := NewLabel(39, 10, 'P&hone:', PhoneEdit);
  PhoneLabel.Anchors := [akTop, akRight];

  VolumeBar := TScrollBar.Create(Self);
  VolumeBar.Parent := Self;
  VolumeBar.SetBounds(50, 12, 23, 1);
  VolumeBar.Max := 100;
  VolumeBar.Position := 40;
  VolumeBar.Anchors := [akTop, akRight];
  VolumeBar.OnChange := @VolumeBarChange;
  VolumeLabel := NewLabel(39, 12, '&Volume:', VolumeBar);
  VolumeLabel.Anchors := [akTop, akRight];

  Progress := TProgressBar.Create(Self);
  Progress.Parent := Self;
  Progress.SetBounds(50, 14, 23, 1);
  Progress.BarShowText := true;
  Progress.Anchors := [akTop, akRight];
  ProgressLabel := NewLabel(39, 14, 'Progress:', nil);
  ProgressLabel.Anchors := [akTop, akRight];

  Line := TBevel.Create(Self);
  Line.Parent := Self;
  Line.SetBounds(1, 16, 72, 1);
  Line.Shape := bsTopLine;
  Line.Anchors := [akLeft, akRight, akBottom];

  StartButton := NewButton(1, 17, 12, '&Start', @StartButtonClick);
  StartButton.Anchors := [akLeft, akBottom];
  ErrorButton := NewButton(15, 17, 16, '&Raise error', @ErrorButtonClick);
  ErrorButton.Anchors := [akLeft, akBottom];
  ErrorButton.Hint := 'An exception in OnClick: the error box';
  CloseButton := NewButton(61, 17, 12, 'Cl&ose', @CloseButtonClick);
  CloseButton.Cancel := true;
  CloseButton.Anchors := [akRight, akBottom];

  { ---- timers }
  ClockTimer := TTimer.Create(Self);
  ClockTimer.Interval := 1000;
  ClockTimer.OnTimer := @ClockTimerTimer;
  RunTimer := TTimer.Create(Self);
  RunTimer.Interval := 110;
  RunTimer.Enabled := false;
  RunTimer.OnTimer := @RunTimerTimer;

  ActiveControl := Memo1;
  Info('Ready');
end;

procedure TMoreForm.Info(const S: string);
begin
  if InfoText <> nil then InfoText.Caption := S;
end;

procedure TMoreForm.ClockTimerTimer(Sender: TObject);
begin
  inc(Ticks);
  ClockLabel.Caption := 'Time: ' + TimeToStr(Now);
end;

procedure TMoreForm.RunTimerTimer(Sender: TObject);
begin
  Progress.StepBy(5);
  if Progress.Position >= Progress.Max then
  begin
    RunTimer.Enabled := false;
    StartButton.Caption := '&Start';
    Info('Progress done');
  end;
end;

procedure TMoreForm.StartButtonClick(Sender: TObject);
begin
  if RunTimer.Enabled then
  begin
    RunTimer.Enabled := false;
    StartButton.Caption := '&Start';
    Info('Progress stopped at ' + IntToStr(Progress.Position) + '%');
  end
  else
  begin
    if Progress.Position >= Progress.Max then Progress.Position := 0;
    RunTimer.Enabled := true;
    StartButton.Caption := '&Stop';
    Info('Progress running (TTimer, 110 ms)');
  end;
end;

procedure TMoreForm.ErrorButtonClick(Sender: TObject);
begin
  raise Exception.Create('A test error, raised in OnClick');
end;

procedure TMoreForm.CloseButtonClick(Sender: TObject);
begin
  Hide;
end;

procedure TMoreForm.WrapCheckChange(Sender: TObject);
begin
  if Memo1 <> nil then Memo1.WordWrap := WrapCheck.Checked;
end;

procedure TMoreForm.ColourGroupClick(Sender: TObject);
begin
  Info('Colour: ' + ColourGroup.Items[ColourGroup.ItemIndex]);
end;

procedure TMoreForm.ToppingListClickCheck(Sender: TObject);
var i: integer;
    s: string;
begin
  s := '';
  for i := 0 to ToppingList.Count - 1 do
    if ToppingList.Checked[i] then s := s + ToppingList.Items[i] + ' ';
  Info('Toppings: ' + s);
end;

procedure TMoreForm.QtySpinChange(Sender: TObject);
begin
  Info('Quantity: ' + IntToStr(QtySpin.Value));
end;

procedure TMoreForm.VolumeBarChange(Sender: TObject);
begin
  Info('Volume: ' + IntToStr(VolumeBar.Position));
end;

procedure TMoreForm.MaskChange(Sender: TObject);
var e: TMaskEdit;
begin
  e := TMaskEdit(Sender);
  if e.ValidateEdit then Info('Complete: ' + e.Text)
  else Info('Typing: ' + e.EditText);
end;

procedure TMoreForm.CutClick(Sender: TObject);
begin
  Memo1.CutToClipboard;
end;

procedure TMoreForm.CopyClick(Sender: TObject);
begin
  Memo1.CopyToClipboard;
end;

procedure TMoreForm.PasteClick(Sender: TObject);
begin
  Memo1.PasteFromClipboard;
end;

procedure TMoreForm.SelectAllClick(Sender: TObject);
begin
  Memo1.SelectAll;
end;

procedure TMoreForm.ClearClick(Sender: TObject);
begin
  Memo1.Clear;
end;

procedure TMoreForm.CheckAllClick(Sender: TObject);
begin
  ToppingList.CheckAll(true);
  ToppingListClickCheck(nil);
end;

procedure TMoreForm.UncheckAllClick(Sender: TObject);
begin
  ToppingList.CheckAll(false);
  ToppingListClickCheck(nil);
end;

end.
