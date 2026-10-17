{-----------------------------------------------------------------------------}
{  LVEDWIN - an LVCode editor window: one file in a TSynEdit, the Pascal or   }
{  QBasic highlighter by its extension, the line and column in the status    }
{  bar ('*' when changed), a question before a changed file is closed.       }
{-----------------------------------------------------------------------------}
unit LVEdWin;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, TUICtrl, TUIStd, TUIMenu, TUISyn, TUISynEd, LVOpts;

type
   TEditWindow = class;

   { Save as: the main form asks for the name (its save dialog) }
   TLVSaveAsFunc = function(W: TEditWindow): boolean of object;

   TEditWindow = class(TForm)
   private
      FFileName: string;
      FUntitled: boolean;
      procedure EditorStatus(Sender: TObject);
      procedure EditorChange(Sender: TObject);
      procedure WindowCloseQuery(Sender: TObject; var CanClose: boolean);
      procedure WindowClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure SetFileName(const V: string);
   public
      Editor: TSynEdit;
      Status: TStatusBar;
      constructor CreateFor(AOwner: TComponent; const AFileName: string; Untitled: boolean);
      procedure LoadFile(const AFileName: string);
      { false: not saved (no name given, or a write error shown) }
      function  Save: boolean;
      function  SaveAs: boolean;
      procedure ApplyOptions(O: TLVOptions);
      procedure UseHighlighter;
      function  SameFile(const AFileName: string): boolean;
      property FileName: string read FFileName write SetFileName;
      property Untitled: boolean read FUntitled write FUntitled;
   end;

var
   { set by the main form }
   LVSaveAs: TLVSaveAsFunc = nil;
   LVPascal: TSynCustomHighlighter = nil;
   LVBasic: TSynCustomHighlighter = nil;
   LVUntitledCount: integer = 0;

{ a name for a new window: NONAME00.PAS, NONAME01.PAS ... }
function NextUntitledName: string;

implementation

function NextUntitledName: string;
begin
   Result := ExpandFileName(Format('NONAME%.2d.PAS', [LVUntitledCount]));
   inc(LVUntitledCount);
end;

constructor TEditWindow.CreateFor(AOwner: TComponent; const AFileName: string; Untitled: boolean);
var p: TStatusPanel;
    d: TRect;
    n, i: integer;
begin
   CreateNew(AOwner);
   { a new window: the desktop above the messages window, a little further }
   { in each time                                                         }
   d := Application.DesktopRect;
   n := 0;
   for i := 0 to Screen.FormCount - 1 do
      if Screen.Forms[i] is TEditWindow then inc(n);
   n := n mod 4;
   SetBounds(d.Left + n, d.Top + n, d.Right - d.Left - n, d.Bottom - d.Top - 8 - n);
   Constraints.MinWidth := 24;
   Constraints.MinHeight := 6;
   OnCloseQuery := @WindowCloseQuery;
   OnClose := @WindowClose;
   Status := TStatusBar.Create(Self);
   Status.Parent := Self;
   p := Status.Panels.Add; p.Width := 11;     { line:col }
   p := Status.Panels.Add; p.Width := 3;      { Ins / Ovr / ^K }
   p := Status.Panels.Add; p.Width := 2;      { * }
   p := Status.Panels.Add;                    { the language }
   Editor := TSynEdit.Create(Self);
   Editor.Parent := Self;
   Editor.Align := alClient;
   Editor.OnStatusChange := @EditorStatus;
   Editor.OnChange := @EditorChange;
   ActiveControl := Editor;
   FUntitled := Untitled;
   FileName := AFileName;
   if not Untitled and FileExists(AFileName) then LoadFile(AFileName);
   UseHighlighter;
   EditorStatus(nil);
end;

procedure TEditWindow.SetFileName(const V: string);
begin
   FFileName := V;
   Caption := ExtractFileName(V);
   Hint := V;
   UseHighlighter;
end;

procedure TEditWindow.UseHighlighter;
var c: TSynHighlighterClass;
begin
   if Editor = nil then exit;
   c := HighlighterClassForFile(FFileName);
   if c = TSynPasSyn then Editor.Highlighter := LVPascal
   else if c = TSynQBasicSyn then Editor.Highlighter := LVBasic
   else Editor.Highlighter := nil;
   if Status <> nil then
      if Editor.Highlighter <> nil then Status.Panels[3].Text := Editor.Highlighter.LanguageName
      else Status.Panels[3].Text := 'Text';
end;

function TEditWindow.SameFile(const AFileName: string): boolean;
begin
   Result := CompareText(ExpandFileName(AFileName), ExpandFileName(FFileName)) = 0;
end;

procedure TEditWindow.ApplyOptions(O: TLVOptions);
begin
   Editor.TabWidth := O.TabWidth;
   Editor.BlockIndent := O.BlockIndent;
   Editor.WordStarKeys := O.WordStarKeys;
   if O.AutoIndent then Editor.Options := Editor.Options + [eoAutoIndent]
   else Editor.Options := Editor.Options - [eoAutoIndent];
end;

procedure TEditWindow.LoadFile(const AFileName: string);
begin
   Editor.LoadFromFile(AFileName);
   FUntitled := false;
   FileName := ExpandFileName(AFileName);
   EditorStatus(nil);
end;

function TEditWindow.Save: boolean;
begin
   if FUntitled then exit(SaveAs);
   try
      Editor.SaveToFile(FFileName);
      Result := true;
   except
      on E: Exception do
      begin
         MessageDlg('Error', 'Cannot save ' + FFileName + ':' + LineEnding + E.Message, mtError, [mbOK], 0);
         Result := false;
      end;
   end;
   EditorStatus(nil);
end;

function TEditWindow.SaveAs: boolean;
begin
   Result := Assigned(LVSaveAs) and LVSaveAs(Self);
   EditorStatus(nil);
end;

procedure TEditWindow.EditorStatus(Sender: TObject);
begin
   if (Status = nil) or (Editor = nil) then exit;
   Status.Panels[0].Text := IntToStr(Editor.CaretY) + ':' + IntToStr(Editor.CaretX);
   if Editor.PendingPrefix <> #0 then Status.Panels[1].Text := '^' + Editor.PendingPrefix
   else if Editor.InsertMode then Status.Panels[1].Text := 'Ins'
   else Status.Panels[1].Text := 'Ovr';
   if Editor.Modified then Status.Panels[2].Text := '*' else Status.Panels[2].Text := '';
end;

procedure TEditWindow.EditorChange(Sender: TObject);
begin
   { an edit on the error line: the mark has done its job }
   if (Editor.ErrorLine > 0) and (Editor.CaretY = Editor.ErrorLine) then Editor.ErrorLine := 0;
end;

procedure TEditWindow.WindowCloseQuery(Sender: TObject; var CanClose: boolean);
begin
   if not Editor.Modified then exit;
   case MessageDlg('Confirm', ExtractFileName(FFileName) + ' has been modified. Save?',
                   mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: CanClose := Save;
      mrNo: ;
   else
      CanClose := false;
   end;
end;

procedure TEditWindow.WindowClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   CloseAction := caFree;
end;

end.
