unit CodeFrm;

{ A code editor window: TSynEdit with the Pascal or QBasic highlighter
  (picked by the file's extension, or from the Language menu), a window
  menu, and a status bar with the line, the column, Ins/Ovr, Modified and
  the language. Opened from Window|Code editor. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIMenu, TUIDlgs, TUISyn, TUISynEd;

type

  { TCodeForm }

  TCodeForm = class(TForm)
    Editor: TSynEdit;
    PasSyn: TSynPasSyn;
    BasSyn: TSynQBasicSyn;
    Menu1: TMainMenu;
    Status: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    PasItem, BasItem, TextItem, WordStarItem, AutoIndentItem: TMenuItem;
    procedure NewClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure LanguageClick(Sender: TObject);
    procedure EditorStatusChange(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure IndentClick(Sender: TObject);
    procedure UnindentClick(Sender: TObject);
    procedure WordStarClick(Sender: TObject);
    procedure AutoIndentClick(Sender: TObject);
  private
    procedure UseHighlighterFor(const FileName: string);
    procedure ShowLanguage;
  public
    FileName: string;
    constructor Create(AOwner: TComponent); override;
    procedure OpenFile(const AFileName: string);
  end;

var
  CodeForm: TCodeForm;

implementation

const
  SamplePascal =
    'program Hello;' + LineEnding +
    '' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    '' + LineEnding +
    'uses SysUtils;' + LineEnding +
    '' + LineEnding +
    '(* a comment' + LineEnding +
    '   over two lines *)' + LineEnding +
    'var' + LineEnding +
    '  i: integer;' + LineEnding +
    '  s: string = ''it''''s'';' + LineEnding +
    '' + LineEnding +
    'begin' + LineEnding +
    '  for i := 1 to 10 do        // a loop' + LineEnding +
    '    WriteLn(s, i, $FF, #13);' + LineEnding +
    'end.';

constructor TCodeForm.Create(AOwner: TComponent);
var p: TStatusPanel;

  function Item(const C: string; SC: TShortCut; H: TNotifyEvent): TMenuItem;
  begin
    Result := NewItem(C, SC, false, true, H, 0, '');
  end;

begin
  inherited Create(AOwner);
  Caption := 'Code editor';
  SetBounds(0, 0, 78, 22);
  Position := poScreenCenter;
  Constraints.MinWidth := 40;
  Constraints.MinHeight := 8;

  PasSyn := TSynPasSyn.Create(Self);
  BasSyn := TSynQBasicSyn.Create(Self);

  PasItem := Item('&Pascal', 0, @LanguageClick);
  BasItem := Item('&QBasic', 0, @LanguageClick);
  TextItem := Item('Plain &text', 0, @LanguageClick);
  Menu1 := TMainMenu.Create(Self);
  Menu1.Items.Add(NewSubMenu('&File', 0, '', [
    Item('&New', 0, @NewClick),
    Item('&Open...', ShortCut(VK_F3, []), @OpenClick),
    Item('&Save', ShortCut(VK_F2, []), @SaveClick),
    Item('Save &as...', 0, @SaveAsClick),
    NewLine,
    Item('&Close', ShortCut(VK_F3, [ssAlt]), @CloseClick)]));
  Menu1.Items.Add(NewSubMenu('&Edit', 0, '', [
    Item('&Undo', ShortCut(VK_BACK, [ssAlt]), @UndoClick),
    Item('&Redo', ShortCut(VK_BACK, [ssAlt, ssShift]), @RedoClick),
    NewLine,
    Item('Cu&t', ShortCut(VK_DELETE, [ssShift]), @CutClick),
    Item('&Copy', ShortCut(VK_INSERT, [ssCtrl]), @CopyClick),
    Item('&Paste', ShortCut(VK_INSERT, [ssShift]), @PasteClick),
    NewLine,
    Item('&Indent block', 0, @IndentClick),
    Item('U&nindent block', 0, @UnindentClick)]));
  Menu1.Items.Add(NewSubMenu('&Language', 0, '', [PasItem, BasItem, TextItem]));
  WordStarItem := Item('&WordStar keys', 0, @WordStarClick);
  AutoIndentItem := Item('&Auto indent', 0, @AutoIndentClick);
  AutoIndentItem.Checked := true;
  Menu1.Items.Add(NewSubMenu('&Options', 0, '', [WordStarItem, AutoIndentItem]));
  Menu := Menu1;

  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  p := Status.Panels.Add; p.Width := 16;     { Ln / Col }
  p := Status.Panels.Add; p.Width := 3;      { Ins / Ovr, ^K / ^Q }
  p := Status.Panels.Add; p.Width := 8;      { Modified }
  p := Status.Panels.Add; p.Width := 8;      { the language }
  p := Status.Panels.Add;                    { the file }

  Editor := TSynEdit.Create(Self);
  Editor.Parent := Self;
  Editor.Align := alClient;
  Editor.OnStatusChange := @EditorStatusChange;
  Editor.Highlighter := PasSyn;
  Editor.Text := SamplePascal;
  Editor.Modified := false;

  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Filter := 'Pascal and BASIC|*.pas;*.pp;*.inc;*.bas;*.bi|' + PasSyn.DefaultFilter + '|' +
                        BasSyn.DefaultFilter + '|All files|*.*';
  OpenDialog1.Options := [ofFileMustExist];
  SaveDialog1 := TSaveDialog.Create(Self);
  SaveDialog1.Filter := OpenDialog1.Filter;
  SaveDialog1.Options := [ofOverwritePrompt];

  ActiveControl := Editor;
  ShowLanguage;
  EditorStatusChange(nil);
end;

procedure TCodeForm.ShowLanguage;
begin
  PasItem.Checked := Editor.Highlighter = PasSyn;
  BasItem.Checked := Editor.Highlighter = BasSyn;
  TextItem.Checked := Editor.Highlighter = nil;
  if Editor.Highlighter <> nil then Status.Panels[3].Text := Editor.Highlighter.LanguageName
  else Status.Panels[3].Text := 'Text';
end;

procedure TCodeForm.UseHighlighterFor(const FileName: string);
var c: TSynHighlighterClass;
begin
  c := HighlighterClassForFile(FileName);
  if c = TSynPasSyn then Editor.Highlighter := PasSyn
  else if c = TSynQBasicSyn then Editor.Highlighter := BasSyn
  else Editor.Highlighter := nil;
  ShowLanguage;
end;

procedure TCodeForm.OpenFile(const AFileName: string);
begin
  Editor.LoadFromFile(AFileName);
  FileName := AFileName;
  UseHighlighterFor(AFileName);
  Caption := 'Code editor - ' + ExtractFileName(AFileName);
  Status.Panels[4].Text := ExtractFileName(AFileName);
end;

procedure TCodeForm.EditorStatusChange(Sender: TObject);
begin
  if Status = nil then exit;
  Status.Panels[0].Text := 'Ln ' + IntToStr(Editor.CaretY) + ' Col ' + IntToStr(Editor.CaretX);
  if Editor.PendingPrefix <> #0 then Status.Panels[1].Text := '^' + Editor.PendingPrefix
  else if Editor.InsertMode then Status.Panels[1].Text := 'Ins' else Status.Panels[1].Text := 'Ovr';
  if Editor.Modified then Status.Panels[2].Text := 'Modified' else Status.Panels[2].Text := '';
end;

procedure TCodeForm.UndoClick(Sender: TObject);
begin
  Editor.Undo;
end;

procedure TCodeForm.RedoClick(Sender: TObject);
begin
  Editor.Redo;
end;

procedure TCodeForm.CutClick(Sender: TObject);
begin
  Editor.CutToClipboard;
end;

procedure TCodeForm.CopyClick(Sender: TObject);
begin
  Editor.CopyToClipboard;
end;

procedure TCodeForm.PasteClick(Sender: TObject);
begin
  Editor.PasteFromClipboard;
end;

procedure TCodeForm.IndentClick(Sender: TObject);
begin
  Editor.IndentBlock;
end;

procedure TCodeForm.UnindentClick(Sender: TObject);
begin
  Editor.UnindentBlock;
end;

procedure TCodeForm.WordStarClick(Sender: TObject);
begin
  Editor.WordStarKeys := not Editor.WordStarKeys;
  WordStarItem.Checked := Editor.WordStarKeys;
end;

procedure TCodeForm.AutoIndentClick(Sender: TObject);
begin
  if eoAutoIndent in Editor.Options then Editor.Options := Editor.Options - [eoAutoIndent]
  else Editor.Options := Editor.Options + [eoAutoIndent];
  AutoIndentItem.Checked := eoAutoIndent in Editor.Options;
end;

procedure TCodeForm.NewClick(Sender: TObject);
begin
  Editor.ClearAll;
  Editor.Modified := false;
  FileName := '';
  Caption := 'Code editor';
  Status.Panels[4].Text := '';
end;

procedure TCodeForm.OpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then OpenFile(OpenDialog1.FileName);
end;

procedure TCodeForm.SaveClick(Sender: TObject);
begin
  if FileName = '' then SaveAsClick(Sender)
  else Editor.SaveToFile(FileName);
end;

procedure TCodeForm.SaveAsClick(Sender: TObject);
begin
  SaveDialog1.FileName := FileName;
  if SaveDialog1.Execute then
  begin
    Editor.SaveToFile(SaveDialog1.FileName);
    FileName := SaveDialog1.FileName;
    UseHighlighterFor(FileName);
    Caption := 'Code editor - ' + ExtractFileName(FileName);
    Status.Panels[4].Text := ExtractFileName(FileName);
  end;
end;

procedure TCodeForm.CloseClick(Sender: TObject);
begin
  Hide;
end;

procedure TCodeForm.LanguageClick(Sender: TObject);
begin
  if Sender = PasItem then Editor.Highlighter := PasSyn
  else if Sender = BasItem then Editor.Highlighter := BasSyn
  else Editor.Highlighter := nil;
  ShowLanguage;
end;

end.
