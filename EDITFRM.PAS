unit EditFrm;

{ Stage 6: a small notepad. A TActionList holds what the menu, the tool bar
  and the keys do (one OnExecute each; OnUpdate switches Cut/Copy/Paste on
  and off); TOpenDialog / TSaveDialog / TSelectDirectoryDialog /
  TColorDialog / TFindDialog / TReplaceDialog do the rest. The tool buttons
  show hint windows (ShowHint). Opened from Window|Notepad (Ctrl+E). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUIScrn, TUICtrl, TUIStd, TUIMenu, TUIMemo, TUIPages,
  TUIDlgs;

type

  { TEditForm }

  TEditForm = class(TForm)
    Actions: TActionList;
    actNew, actOpen, actSave, actSaveAs, actFolder, actClose,
    actCut, actCopy, actPaste, actSelectAll,
    actFind, actFindNext, actReplace, actBack, actText: TAction;
    Menu1: TMainMenu;
    Tools: TToolBar;
    Memo: TMemo;
    Status: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    FolderDialog1: TSelectDirectoryDialog;
    ColorDialog1: TColorDialog;
    FindDialog1: TFindDialog;
    ReplaceDialog1: TReplaceDialog;
    procedure NewExecute(Sender: TObject);
    procedure OpenExecute(Sender: TObject);
    procedure SaveExecute(Sender: TObject);
    procedure SaveAsExecute(Sender: TObject);
    procedure FolderExecute(Sender: TObject);
    procedure CloseExecute(Sender: TObject);
    procedure CutExecute(Sender: TObject);
    procedure CopyExecute(Sender: TObject);
    procedure PasteExecute(Sender: TObject);
    procedure SelectAllExecute(Sender: TObject);
    procedure HasSelectionUpdate(Sender: TObject);
    procedure PasteUpdate(Sender: TObject);
    procedure FindExecute(Sender: TObject);
    procedure FindNextExecute(Sender: TObject);
    procedure ReplaceExecute(Sender: TObject);
    procedure BackExecute(Sender: TObject);
    procedure TextExecute(Sender: TObject);
    procedure ActionsUpdate(Sender: TObject);
    procedure FindDialog1Find(Sender: TObject);
    procedure ReplaceDialog1Replace(Sender: TObject);
    procedure MemoChange(Sender: TObject);
  private
    FModified: boolean;
    procedure Say(const S: string);
    procedure SaveTo(const F: string);
  public
    FileName: string;
    LastMessage: string;
    constructor Create(AOwner: TComponent); override;
  end;

var
  EditForm: TEditForm;

implementation

constructor TEditForm.Create(AOwner: TComponent);

  function Act(const C, H: string; SC: TShortCut; E: TNotifyEvent): TAction;
  begin
    Result := TAction.Create(Self);
    Result.ActionList := Actions;
    Result.Caption := C;
    Result.Hint := H;
    Result.ShortCut := SC;
    Result.OnExecute := E;
  end;

  function Item(A: TAction): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Action := A;
  end;

  function Tool(const S: string; A: TAction): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := Tools;
    Result.Action := A;
    Result.Caption := S;           { a short caption on the tool bar }
  end;

var p: TStatusPanel;
    sep: TToolButton;
begin
  inherited Create(AOwner);
  Caption := 'Notepad';
  SetBounds(0, 0, 76, 21);
  Position := poScreenCenter;
  Constraints.MinWidth := 40;
  Constraints.MinHeight := 10;
  ShowHint := true;                { hint windows for everything on the form }

  { ---- the actions: what the menu, the tool bar and the keys do }
  Actions := TActionList.Create(Self);
  Actions.OnUpdate := @ActionsUpdate;
  actNew := Act('&New', 'New|Start a new text', ShortCut(Ord('N'), [ssCtrl]), @NewExecute);
  actOpen := Act('&Open...', 'Open|Open a text file', ShortCut(Ord('O'), [ssCtrl]), @OpenExecute);
  actSave := Act('&Save', 'Save|Save the text', ShortCut(Ord('S'), [ssCtrl]), @SaveExecute);
  actSaveAs := Act('Save &as...', 'Save under another name', 0, @SaveAsExecute);
  actFolder := Act('&Folder...', 'Pick a folder (TSelectDirectoryDialog)', 0, @FolderExecute);
  actClose := Act('&Close', 'Close the notepad', 0, @CloseExecute);
  actCut := Act('Cu&t', 'Cut|Cut the selection', ShortCut(Ord('X'), [ssCtrl]), @CutExecute);
  actCopy := Act('&Copy', 'Copy to Windows clipboard (Ctrl+C)|Copy the selection', ShortCut(Ord('C'), [ssCtrl]), @CopyExecute);
  actPaste := Act('&Paste', 'Paste from Windows clipboard (Ctrl+V)|Paste the clipboard', ShortCut(Ord('V'), [ssCtrl]), @PasteExecute);
  actSelectAll := Act('Select &all', 'Select all the text', ShortCut(Ord('A'), [ssCtrl]), @SelectAllExecute);
  actFind := Act('&Find...', 'Find|Find a text', ShortCut(Ord('F'), [ssCtrl]), @FindExecute);
  actFindNext := Act('Find &next', 'Find it again', ShortCut(VK_F3, []), @FindNextExecute);
  actReplace := Act('&Replace...', 'Replace a text', ShortCut(Ord('R'), [ssCtrl]), @ReplaceExecute);
  actBack := Act('&Background colour...', 'The memo''s background (TColorDialog)', 0, @BackExecute);
  actText := Act('&Text colour...', 'The memo''s text colour', 0, @TextExecute);
  actCut.OnUpdate := @HasSelectionUpdate;
  actCopy.OnUpdate := @HasSelectionUpdate;
  actPaste.OnUpdate := @PasteUpdate;

  { ---- the window's menu: every item from an action }
  Menu1 := TMainMenu.Create(Self);
  Menu1.Items.Add(NewSubMenu('&File', 0, '', [Item(actNew), Item(actOpen), Item(actSave),
    Item(actSaveAs), NewLine, Item(actFolder), NewLine, Item(actClose)]));
  Menu1.Items.Add(NewSubMenu('&Edit', 0, '', [Item(actCut), Item(actCopy), Item(actPaste),
    NewLine, Item(actSelectAll), NewLine, Item(actFind), Item(actFindNext), Item(actReplace)]));
  Menu1.Items.Add(NewSubMenu('F&ormat', 0, '', [Item(actBack), Item(actText)]));
  Menu := Menu1;

  { ---- the tool bar: buttons from the same actions }
  Tools := TToolBar.Create(Self);
  Tools.Parent := Self;
  Tool('New', actNew);
  Tool('Open', actOpen);
  Tool('Save', actSave);
  sep := TToolButton.Create(Self);
  sep.Parent := Tools;
  sep.Style := tbsSeparator;
  Tool('Cut', actCut);
  Tool('Copy', actCopy);
  Tool('Paste', actPaste);
  sep := TToolButton.Create(Self);
  sep.Parent := Tools;
  sep.Style := tbsSeparator;
  Tool('Find', actFind);

  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  p := Status.Panels.Add;
  p.Width := 24;
  p := Status.Panels.Add;
  p.Width := 14;
  p := Status.Panels.Add;
  p.Width := 10;

  Memo := TMemo.Create(Self);
  Memo.Parent := Self;
  Memo.Align := alClient;
  Memo.ScrollBars := ssAutoBoth;
  Memo.ShowHint := false;
  Memo.OnChange := @MemoChange;

  { ---- the dialogs }
  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Filter := 'Text files|*.txt|Pascal|*.pas;*.pp;*.inc|All files|*.*';
  OpenDialog1.Options := [ofFileMustExist];
  SaveDialog1 := TSaveDialog.Create(Self);
  SaveDialog1.Filter := OpenDialog1.Filter;
  SaveDialog1.DefaultExt := 'txt';
  SaveDialog1.Options := [ofOverwritePrompt, ofPathMustExist];
  FolderDialog1 := TSelectDirectoryDialog.Create(Self);
  ColorDialog1 := TColorDialog.Create(Self);
  FindDialog1 := TFindDialog.Create(Self);
  FindDialog1.Options := [frDown];
  FindDialog1.OnFind := @FindDialog1Find;
  ReplaceDialog1 := TReplaceDialog.Create(Self);
  ReplaceDialog1.Options := [frDown];
  ReplaceDialog1.OnFind := @FindDialog1Find;
  ReplaceDialog1.OnReplace := @ReplaceDialog1Replace;

  ActiveControl := Memo;
  FModified := false;
  Say('Ready');
end;

procedure TEditForm.Say(const S: string);
begin
  LastMessage := S;
  if Status <> nil then Status.Panels[0].Text := S;
end;

procedure TEditForm.MemoChange(Sender: TObject);
begin
  FModified := true;
end;

{ OnUpdate of the whole list (when idle): the caret position and the state }
procedure TEditForm.ActionsUpdate(Sender: TObject);
begin
  Status.Panels[1].Text := 'Ln ' + IntToStr(Memo.CaretPos.Y + 1) + ' Col ' + IntToStr(Memo.CaretPos.X + 1);
  if FModified then Status.Panels[2].Text := 'Modified' else Status.Panels[2].Text := '';
end;

procedure TEditForm.HasSelectionUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Memo.HasSelection;
end;

procedure TEditForm.PasteUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Clipboard.HasText;
end;

procedure TEditForm.NewExecute(Sender: TObject);
begin
  Memo.Clear;
  FileName := '';
  FModified := false;
  Caption := 'Notepad';
  Say('New text');
end;

procedure TEditForm.OpenExecute(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    Memo.Lines.LoadFromFile(OpenDialog1.FileName);
    FileName := OpenDialog1.FileName;
    FModified := false;
    Caption := 'Notepad - ' + ExtractFileName(FileName);
    Say('Opened ' + ExtractFileName(FileName));
  end
  else Say('Open cancelled');
end;

procedure TEditForm.SaveTo(const F: string);
begin
  Memo.Lines.SaveToFile(F);
  FileName := F;
  FModified := false;
  Caption := 'Notepad - ' + ExtractFileName(F);
  Say('Saved ' + ExtractFileName(F));
end;

procedure TEditForm.SaveExecute(Sender: TObject);
begin
  if FileName = '' then SaveAsExecute(Sender) else SaveTo(FileName);
end;

procedure TEditForm.SaveAsExecute(Sender: TObject);
begin
  SaveDialog1.FileName := FileName;
  if SaveDialog1.Execute then SaveTo(SaveDialog1.FileName)
  else Say('Save cancelled');
end;

procedure TEditForm.FolderExecute(Sender: TObject);
begin
  if FolderDialog1.Execute then Say('Folder: ' + FolderDialog1.FileName)
  else Say('No folder');
end;

procedure TEditForm.CloseExecute(Sender: TObject);
begin
  FindDialog1.CloseDialog;
  ReplaceDialog1.CloseDialog;
  Hide;
end;

procedure TEditForm.CutExecute(Sender: TObject);
begin
  Memo.CutToClipboard;
end;

procedure TEditForm.CopyExecute(Sender: TObject);
begin
  Memo.CopyToClipboard;
  Say('Copied ' + IntToStr(Length(Clipboard.AsText)) + ' characters');
end;

procedure TEditForm.PasteExecute(Sender: TObject);
begin
  Memo.PasteFromClipboard;
end;

procedure TEditForm.SelectAllExecute(Sender: TObject);
begin
  Memo.SelectAll;
end;

procedure TEditForm.FindExecute(Sender: TObject);
begin
  ReplaceDialog1.CloseDialog;
  if Memo.HasSelection and (Pos(#10, Memo.SelText) = 0) then FindDialog1.FindText := Memo.SelText;
  FindDialog1.Execute;
end;

procedure TEditForm.FindNextExecute(Sender: TObject);
begin
  if FindDialog1.FindText = '' then FindExecute(Sender)
  else FindDialog1Find(FindDialog1);
end;

procedure TEditForm.ReplaceExecute(Sender: TObject);
begin
  FindDialog1.CloseDialog;
  ReplaceDialog1.Execute;
end;

procedure TEditForm.FindDialog1Find(Sender: TObject);
var d: TFindDialog;
begin
  d := TFindDialog(Sender);
  if MemoFindNext(Memo, d.FindText, d.Options) then
    Say('Found at ' + IntToStr(Memo.SelStart))
  else
  begin
    Say('Not found');
    MessageDlg('Find', 'Cannot find "' + d.FindText + '"', mtInformation, [mbOK], 0);
  end;
  { the search went on in the memo: keep the text the dialog last used }
  if d <> FindDialog1 then FindDialog1.FindText := d.FindText;
end;

procedure TEditForm.ReplaceDialog1Replace(Sender: TObject);
var n: integer;
begin
  n := MemoReplace(Memo, ReplaceDialog1.FindText, ReplaceDialog1.ReplaceText,
                   ReplaceDialog1.Options);
  Say('Replaced ' + IntToStr(n));
end;

procedure TEditForm.BackExecute(Sender: TObject);
begin
  if (Memo.Color >= 0) and (Memo.Color <= 15) then ColorDialog1.Color := Memo.Color
  else ColorDialog1.Color := AttrBg(Theme.Edit);
  ColorDialog1.Title := 'Background colour';
  if ColorDialog1.Execute then Memo.Color := ColorDialog1.Color;
end;

procedure TEditForm.TextExecute(Sender: TObject);
begin
  if (Memo.Font.Color >= 0) and (Memo.Font.Color <= 15) then ColorDialog1.Color := Memo.Font.Color
  else ColorDialog1.Color := AttrFg(Theme.Edit);
  ColorDialog1.Title := 'Text colour';
  if ColorDialog1.Execute then Memo.Font.Color := ColorDialog1.Color;
end;

end.
