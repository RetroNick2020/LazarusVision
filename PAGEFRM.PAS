unit PageFrm;

{ Stage 4 containers: a tool bar (TToolBar, TToolButton), a list on the
  left, a TSplitter, and a TPageControl with three TTabSheets - one holding
  a TScrollBox bigger than the window, one a TMemo. A status bar at the
  bottom. Opened from Window|Containers (Ctrl+P); Esc closes it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUIScrn, TUICtrl, TUIStd, TUIList, TUIMenu, TUIMemo, TUIPages;

type

  { TPageForm }

  TPageForm = class(TForm)
    ToolBar1: TToolBar;
    NewButton, OpenButton, SaveButton, Sep1, BoldButton, ItalicButton, Sep2,
    LeftButton, CenterButton, RightButton: TToolButton;
    SectionList: TListBox;
    Splitter1: TSplitter;
    Pages: TPageControl;
    GeneralSheet, ScrollSheet, NotesSheet: TTabSheet;
    NameLabel, EmailLabel: TLabel;
    NameEdit, EmailEdit: TEdit;
    SubscribeCheck: TCheckBox;
    Box: TScrollBox;
    Notes: TMemo;
    Status: TStatusBar;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ToolClick(Sender: TObject);
    procedure SectionListSelectionChange(Sender: TObject; User: boolean);
    procedure PagesChange(Sender: TObject);
    procedure Splitter1Moved(Sender: TObject);
  private
    procedure Say(const S: string);
  public
    Fields: array[1..15] of TEdit;
    ChangeCount: integer;
    constructor Create(AOwner: TComponent); override;
  end;

var
  PageForm: TPageForm;

implementation

constructor TPageForm.Create(AOwner: TComponent);

  function Tool(const S, AHint: string; AStyle: TToolButtonStyle): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := ToolBar1;
    Result.Style := AStyle;
    Result.Caption := S;
    Result.Hint := AHint;
    Result.OnClick := @ToolClick;
  end;

  function NewLabel(AParent: TWinControl; X, Y: integer; const S: string; F: TWinControl): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Left := X;
    Result.Top := Y;
    Result.Caption := S;
    Result.FocusControl := F;
  end;

  function NewEdit(AParent: TWinControl; X, Y, W: integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := AParent;
    Result.SetBounds(X, Y, W, 1);
  end;

var i: integer;
begin
  inherited Create(AOwner);
  Caption := 'Containers';
  SetBounds(0, 0, 76, 21);
  Position := poScreenCenter;
  Constraints.MinWidth := 50;
  Constraints.MinHeight := 12;
  KeyPreview := true;
  OnKeyDown := @FormKeyDown;

  { ---- tool bar (Align alTop, buttons left to right) }
  ToolBar1 := TToolBar.Create(Self);
  ToolBar1.Parent := Self;
  NewButton := Tool('New', 'New document', tbsButton);
  OpenButton := Tool('Open', 'Open a document', tbsButton);
  SaveButton := Tool('Save', 'Save the document', tbsButton);
  Sep1 := Tool('', '', tbsSeparator);
  BoldButton := Tool('B', 'Bold (on/off)', tbsCheck);
  ItalicButton := Tool('I', 'Italic (on/off)', tbsCheck);
  Sep2 := Tool('', '', tbsSeparator);
  LeftButton := Tool('Left', 'Align left', tbsButton);
  CenterButton := Tool('Center', 'Align centre', tbsButton);
  RightButton := Tool('Right', 'Align right', tbsButton);
  LeftButton.GroupIndex := 1;
  CenterButton.GroupIndex := 1;
  RightButton.GroupIndex := 1;
  LeftButton.Down := true;

  { ---- status bar (Align alBottom) }
  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  Status.SimplePanel := true;

  { ---- left list, splitter, pages (alLeft, alLeft, alClient) }
  SectionList := TListBox.Create(Self);
  SectionList.Parent := Self;
  SectionList.Width := 16;
  SectionList.Align := alLeft;
  SectionList.Items.Add('General');
  SectionList.Items.Add('Scrolling');
  SectionList.Items.Add('Notes');
  SectionList.Hint := 'Picks a page; drag the line on its right';
  SectionList.OnSelectionChange := @SectionListSelectionChange;

  Splitter1 := TSplitter.Create(Self);
  Splitter1.Parent := Self;
  Splitter1.Align := alLeft;
  Splitter1.MinSize := 8;
  Splitter1.OnMoved := @Splitter1Moved;

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;
  Pages.Hint := 'Left/Right or Ctrl+Tab switch pages';
  Pages.OnChange := @PagesChange;

  GeneralSheet := Pages.AddTabSheet;
  GeneralSheet.Caption := '&General';
  NameEdit := NewEdit(GeneralSheet, 9, 1, 30);
  NameEdit.Anchors := [akLeft, akTop, akRight];
  NameLabel := NewLabel(GeneralSheet, 1, 1, '&Name:', NameEdit);
  EmailEdit := NewEdit(GeneralSheet, 9, 3, 30);
  EmailEdit.Anchors := [akLeft, akTop, akRight];
  EmailLabel := NewLabel(GeneralSheet, 1, 3, 'E&mail:', EmailEdit);
  SubscribeCheck := TCheckBox.Create(Self);
  SubscribeCheck.Parent := GeneralSheet;
  SubscribeCheck.SetBounds(9, 5, 20, 1);
  SubscribeCheck.Caption := '&Subscribe';

  ScrollSheet := Pages.AddTabSheet;
  ScrollSheet.Caption := 'Sc&rolling';
  Box := TScrollBox.Create(Self);
  Box.Parent := ScrollSheet;
  Box.Align := alClient;
  for i := 1 to 15 do
  begin
    Fields[i] := NewEdit(Box, 11, (i - 1) * 2, 50);
    Fields[i].Text := 'Value ' + IntToStr(i);
    NewLabel(Box, 1, (i - 1) * 2, 'Field ' + IntToStr(i) + ':', Fields[i]);
  end;

  NotesSheet := Pages.AddTabSheet;
  NotesSheet.Caption := 'N&otes';
  Notes := TMemo.Create(Self);
  Notes.Parent := NotesSheet;
  Notes.Align := alClient;
  Notes.ScrollBars := ssAutoVertical;
  Notes.Text := 'A memo filling its tab sheet (Align alClient).' + LineEnding +
                'Ctrl+Tab still switches the pages from here.';

  Pages.ActivePageIndex := 0;
  ChangeCount := 0;
  ActiveControl := NameEdit;
  Say('Ready');
end;

procedure TPageForm.Say(const S: string);
begin
  if Status <> nil then Status.SimpleText := S;
end;

procedure TPageForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Hide;
  end;
end;

procedure TPageForm.ToolClick(Sender: TObject);
var b: TToolButton;
begin
  b := TToolButton(Sender);
  if b.Style = tbsCheck then
    Say(b.Hint + ': ' + BoolToStr(b.Down, 'on', 'off'))
  else
    Say('Tool button: ' + b.Caption);
end;

procedure TPageForm.SectionListSelectionChange(Sender: TObject; User: boolean);
begin
  if User then Pages.ActivePageIndex := SectionList.ItemIndex;
end;

procedure TPageForm.PagesChange(Sender: TObject);
begin
  inc(ChangeCount);
  if SectionList <> nil then SectionList.ItemIndex := Pages.ActivePageIndex;
  Say('Page: ' + StripAccel(Pages.ActivePage.Caption));
end;

procedure TPageForm.Splitter1Moved(Sender: TObject);
begin
  Say('List width: ' + IntToStr(SectionList.Width));
end;

end.
