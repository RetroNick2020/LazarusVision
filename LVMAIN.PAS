{-----------------------------------------------------------------------------}
{  LVMAIN - LVCode (LazarusVision Code): the IDE. A hidden main form holds the }
{  screen's menu bar and status bar, the dialogs and the compiler options;    }
{  the files are editor windows on the desktop (TEditWindow), the compiler's  }
{  messages a window at the bottom (TMessagesForm).                          }
{                                                                             }
{  Menus as in the Free Pascal IDE:                                          }
{     File     New, Open F3, Save F2, Save as, Save all, Change dir, Exit     }
{     Edit     Undo, Redo, Cut, Copy, Paste, Clear, Select all               }
{     Search   Find, Replace, Search again Ctrl+L, Go to line number          }
{     Run      Run Ctrl+F9, Parameters, User screen Alt+F5                    }
{     Compile  Compile Alt+F9, Make F9, Build, Primary file, Clear primary   }
{              file, Next / Previous message Alt+F8 / Alt+F7, Messages,      }
{              Information                                                   }
{     Options  Compiler, Directories, Editor, Save options                   }
{     Window   Tile, Cascade, Next F6, Previous, Close Alt+F3, Close all,    }
{              the open windows                                             }
{     Help     About                                                         }
{-----------------------------------------------------------------------------}
unit LVMain;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, TUIHW, TUICtrl, TUIStd, TUIMenu, TUIDlgs, TUISyn, TUISynEd,
     LVOpts, LVExec, LVMsgs, LVEdWin, LVDlgs;

type
   TLVMainForm = class(TForm)
   private
      FWindowMenu: TMenuItem;
      FWindowListStart: integer;
      FLastSearch, FLastReplace: string;
      FLastOptions: TSynSearchOptions;
      FBusy: TForm;
      procedure MakeMenus;
      function  SaveAsFor(W: TEditWindow): boolean;
      function  AskSave(W: TEditWindow): boolean;
      procedure ShowBusy(const S: string);
      procedure HideBusy;
      procedure EditorPrefix(Sender: TObject; Prefix, Key: char; var Handled: boolean);
      procedure FindDlgFind(Sender: TObject);
      procedure ReplaceDlgReplace(Sender: TObject);
      function  DlgOptions(D: TFindDialog): TSynSearchOptions;
      procedure MessageGoto(Sender: TObject; Msg: TLVMessage);
   public
      Opts: TLVOptions;
      CfgFile: string;
      Msgs: TMessagesForm;
      PasSyn: TSynPasSyn;
      BasSyn: TSynQBasicSyn;
      OpenDlg: TOpenDialog;
      SaveDlg: TSaveDialog;
      FindDlg: TFindDialog;
      ReplaceDlg: TReplaceDialog;
      ScreenMenu: TMainMenu;
      ScreenStatus: TStatusBar;
      { the last compile }
      LastTarget, LastExe, LastResult: string;
      LastOK: boolean;
      LastOutput: TStringList;
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      { the editor window on top (the one the commands work on) }
      function  ActiveEditor: TEditWindow;
      function  EditorFor(const FileName: string): TEditWindow;
      function  EditorCount: integer;
      function  OpenFile(const FileName: string): TEditWindow;
      function  NewFile: TEditWindow;
      procedure Say(const S: string);
      { compile: true when it went without errors }
      function  DoCompile(Kind: TLVBuildKind): boolean;
      procedure DoRun;
      procedure ApplyEditorOptions;
      { menu commands }
      procedure NewClick(Sender: TObject);
      procedure OpenClick(Sender: TObject);
      procedure SaveClick(Sender: TObject);
      procedure SaveAsClick(Sender: TObject);
      procedure SaveAllClick(Sender: TObject);
      procedure ChangeDirClick(Sender: TObject);
      procedure ExitClick(Sender: TObject);
      procedure UndoClick(Sender: TObject);
      procedure RedoClick(Sender: TObject);
      procedure CutClick(Sender: TObject);
      procedure CopyClick(Sender: TObject);
      procedure PasteClick(Sender: TObject);
      procedure ClearClick(Sender: TObject);
      procedure SelectAllClick(Sender: TObject);
      procedure FindClick(Sender: TObject);
      procedure ReplaceClick(Sender: TObject);
      procedure SearchAgainClick(Sender: TObject);
      procedure GotoLineClick(Sender: TObject);
      procedure RunClick(Sender: TObject);
      procedure ParametersClick(Sender: TObject);
      procedure UserScreenClick(Sender: TObject);
      procedure CompileClick(Sender: TObject);
      procedure MakeClick(Sender: TObject);
      procedure BuildClick(Sender: TObject);
      procedure PrimaryClick(Sender: TObject);
      procedure ClearPrimaryClick(Sender: TObject);
      procedure NextMsgClick(Sender: TObject);
      procedure PrevMsgClick(Sender: TObject);
      procedure MessagesClick(Sender: TObject);
      procedure InfoClick(Sender: TObject);
      procedure CompilerOptsClick(Sender: TObject);
      procedure DirectoriesClick(Sender: TObject);
      procedure EditorOptsClick(Sender: TObject);
      procedure SaveOptsClick(Sender: TObject);
      procedure TileClick(Sender: TObject);
      procedure CascadeClick(Sender: TObject);
      procedure NextWinClick(Sender: TObject);
      procedure PrevWinClick(Sender: TObject);
      procedure CloseWinClick(Sender: TObject);
      procedure CloseAllClick(Sender: TObject);
      procedure WindowMenuClick(Sender: TObject);
      procedure WindowItemClick(Sender: TObject);
      procedure AboutClick(Sender: TObject);
      { closes every editor (asking about changed ones); false: cancelled }
      function  CloseAll: boolean;
   end;

var
   LVMainForm: TLVMainForm;

const
   LVTitle = 'LVCode';
   LVVersion = '1.0';

implementation

constructor TLVMainForm.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   Caption := LVTitle;
   Opts := TLVOptions.Create;
   CfgFile := ExpandFileName('LVCODE.CFG');
   Opts.LoadFromFile(CfgFile);
   LastOutput := TStringList.Create;
   PasSyn := TSynPasSyn.Create(Self);
   BasSyn := TSynQBasicSyn.Create(Self);
   LVPascal := PasSyn;
   LVBasic := BasSyn;
   LVSaveAs := @SaveAsFor;
   OpenDlg := TOpenDialog.Create(Self);
   OpenDlg.Filter := 'Pascal files|*.pas;*.pp;*.inc;*.lpr|BASIC files|*.bas;*.bi|All files|*.*';
   OpenDlg.Options := [ofFileMustExist];
   SaveDlg := TSaveDialog.Create(Self);
   SaveDlg.Filter := OpenDlg.Filter;
   SaveDlg.DefaultExt := 'pas';
   SaveDlg.Options := [ofOverwritePrompt, ofPathMustExist];
   FindDlg := TFindDialog.Create(Self);
   FindDlg.Options := [frDown];
   FindDlg.OnFind := @FindDlgFind;
   ReplaceDlg := TReplaceDialog.Create(Self);
   ReplaceDlg.Options := [frDown];
   ReplaceDlg.OnFind := @FindDlgFind;
   ReplaceDlg.OnReplace := @ReplaceDlgReplace;
   MakeMenus;
   Msgs := TMessagesForm.Create(Self);
   Msgs.OnGoto := @MessageGoto;
end;

destructor TLVMainForm.Destroy;
begin
   LastOutput.Free;
   Opts.Free;
   inherited Destroy;
end;

procedure TLVMainForm.MakeMenus;

   function I(const C: string; SC: TShortCut; H: TNotifyEvent): TMenuItem;
   begin
      Result := NewItem(C, SC, false, true, H, 0, '');
   end;

   procedure Panel(const T: string; H: TNotifyEvent);
   var p: TStatusPanel;
   begin
      p := ScreenStatus.Panels.Add;
      p.Text := T;
      p.OnClick := H;
   end;

begin
   ScreenMenu := TMainMenu.Create(Self);
   ScreenMenu.Items.Add(NewSubMenu('&File', 0, '', [
      I('&New', 0, @NewClick),
      I('&Open...', ShortCut(VK_F3, []), @OpenClick),
      I('&Save', ShortCut(VK_F2, []), @SaveClick),
      I('Save &as...', 0, @SaveAsClick),
      I('Save a&ll', 0, @SaveAllClick),
      NewLine,
      I('&Change dir...', 0, @ChangeDirClick),
      NewLine,
      I('E&xit', ShortCut(Ord('X'), [ssAlt]), @ExitClick)]));
   ScreenMenu.Items.Add(NewSubMenu('&Edit', 0, '', [
      I('&Undo', ShortCut(VK_BACK, [ssAlt]), @UndoClick),
      I('&Redo', ShortCut(VK_BACK, [ssAlt, ssShift]), @RedoClick),
      NewLine,
      I('Cu&t', ShortCut(VK_DELETE, [ssShift]), @CutClick),
      I('&Copy', ShortCut(VK_INSERT, [ssCtrl]), @CopyClick),
      I('&Paste', ShortCut(VK_INSERT, [ssShift]), @PasteClick),
      I('C&lear', ShortCut(VK_DELETE, [ssCtrl]), @ClearClick),
      I('Select &all', 0, @SelectAllClick)]));
   ScreenMenu.Items.Add(NewSubMenu('&Search', 0, '', [
      I('&Find...  (Ctrl+Q F)', 0, @FindClick),
      I('&Replace...  (Ctrl+Q A)', 0, @ReplaceClick),
      I('&Search again', ShortCut(Ord('L'), [ssCtrl]), @SearchAgainClick),
      NewLine,
      I('&Go to line number...', ShortCut(Ord('G'), [ssAlt]), @GotoLineClick)]));
   ScreenMenu.Items.Add(NewSubMenu('&Run', 0, '', [
      I('&Run', ShortCut(VK_F9, [ssCtrl]), @RunClick),
      I('&Parameters...', 0, @ParametersClick),
      NewLine,
      I('&User screen', ShortCut(VK_F5, [ssAlt]), @UserScreenClick)]));
   ScreenMenu.Items.Add(NewSubMenu('&Compile', 0, '', [
      I('&Compile', ShortCut(VK_F9, [ssAlt]), @CompileClick),
      I('&Make', ShortCut(VK_F9, []), @MakeClick),
      I('&Build', 0, @BuildClick),
      NewLine,
      I('&Primary file...', 0, @PrimaryClick),
      I('C&lear primary file', 0, @ClearPrimaryClick),
      NewLine,
      I('&Next message', ShortCut(VK_F8, [ssAlt]), @NextMsgClick),
      I('Pre&vious message', ShortCut(VK_F7, [ssAlt]), @PrevMsgClick),
      I('M&essages', 0, @MessagesClick),
      I('&Information...', 0, @InfoClick)]));
   ScreenMenu.Items.Add(NewSubMenu('&Options', 0, '', [
      I('&Compiler...', 0, @CompilerOptsClick),
      I('&Directories...', 0, @DirectoriesClick),
      I('&Editor...', 0, @EditorOptsClick),
      NewLine,
      I('&Save options', 0, @SaveOptsClick)]));
   FWindowMenu := NewSubMenu('&Window', 0, '', [
      I('&Tile', 0, @TileClick),
      I('C&ascade', 0, @CascadeClick),
      I('&Next', ShortCut(VK_F6, []), @NextWinClick),
      I('&Previous', ShortCut(VK_F6, [ssShift]), @PrevWinClick),
      I('&Close', ShortCut(VK_F3, [ssAlt]), @CloseWinClick),
      I('Close a&ll', 0, @CloseAllClick),
      NewLine]);
   FWindowListStart := FWindowMenu.Count;
   FWindowMenu.OnClick := @WindowMenuClick;
   ScreenMenu.Items.Add(FWindowMenu);
   ScreenMenu.Items.Add(NewSubMenu('&Help', 0, '', [I('&About...', 0, @AboutClick)]));
   Application.Menu := ScreenMenu;

   ScreenStatus := TStatusBar.Create(Self);
   Panel('~F1~ Help', @AboutClick);
   Panel('~F2~ Save', @SaveClick);
   Panel('~F3~ Open', @OpenClick);
   Panel('~Alt+F9~ Compile', @CompileClick);
   Panel('~F9~ Make', @MakeClick);
   Panel('~Ctrl+F9~ Run', @RunClick);
   Panel('~F10~ Menu', nil);
   ScreenStatus.Panels.Add;              { the last message }
   ScreenStatus.Panels[0].ShortCut := ShortCut(VK_F1, []);
   Application.StatusBar := ScreenStatus;
end;

procedure TLVMainForm.Say(const S: string);
begin
   ScreenStatus.Panels[ScreenStatus.Panels.Count - 1].Text := S;
end;

{ ---------------------------------------------------------- editor windows }

function TLVMainForm.ActiveEditor: TEditWindow;
var i: integer;
begin
   { the top-most visible editor window }
   Result := nil;
   for i := Screen.FormCount - 1 downto 0 do
      if (Screen.Forms[i] is TEditWindow) and Screen.Forms[i].Visible then
         exit(TEditWindow(Screen.Forms[i]));
end;

function TLVMainForm.EditorCount: integer;
var i: integer;
begin
   Result := 0;
   for i := 0 to Screen.FormCount - 1 do
      if Screen.Forms[i] is TEditWindow then inc(Result);
end;

function TLVMainForm.EditorFor(const FileName: string): TEditWindow;
var i: integer;
begin
   Result := nil;
   for i := 0 to Screen.FormCount - 1 do
      if (Screen.Forms[i] is TEditWindow) and TEditWindow(Screen.Forms[i]).SameFile(FileName) then
         exit(TEditWindow(Screen.Forms[i]));
end;

procedure TLVMainForm.ApplyEditorOptions;
var i: integer;
begin
   for i := 0 to Screen.FormCount - 1 do
      if Screen.Forms[i] is TEditWindow then TEditWindow(Screen.Forms[i]).ApplyOptions(Opts);
end;

function TLVMainForm.NewFile: TEditWindow;
begin
   Result := TEditWindow.CreateFor(Application, NextUntitledName, true);
   Result.ApplyOptions(Opts);
   Result.Editor.OnPrefixCommand := @EditorPrefix;
   Result.Show;
end;

function TLVMainForm.OpenFile(const FileName: string): TEditWindow;
begin
   Result := EditorFor(FileName);
   if Result <> nil then
   begin
      Result.BringToFront;
      exit;
   end;
   if not FileExists(FileName) then
   begin
      Result := TEditWindow.CreateFor(Application, ExpandFileName(FileName), false);
      Say('New file ' + ExtractFileName(FileName));
   end
   else
   begin
      Result := TEditWindow.CreateFor(Application, ExpandFileName(FileName), false);
      Say(ExtractFileName(FileName) + ': ' + IntToStr(Result.Editor.Lines.Count) + ' lines');
   end;
   Result.ApplyOptions(Opts);
   Result.Editor.OnPrefixCommand := @EditorPrefix;
   Result.Show;
end;

function TLVMainForm.SaveAsFor(W: TEditWindow): boolean;
begin
   SaveDlg.FileName := W.FileName;
   if W.Untitled then SaveDlg.FileName := '';
   Result := SaveDlg.Execute;
   if not Result then exit;
   W.FileName := SaveDlg.FileName;
   W.Untitled := false;
   Result := W.Save;
   if Result then Say('Saved ' + ExtractFileName(W.FileName));
end;

{ before compiling: a changed file is saved (AutoSave) or the user is asked }
function TLVMainForm.AskSave(W: TEditWindow): boolean;
begin
   Result := true;
   if not W.Editor.Modified then exit;
   if Opts.AutoSave and not W.Untitled then exit(W.Save);
   case MessageDlg('Confirm', ExtractFileName(W.FileName) + ' has been modified. Save?',
                   mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: Result := W.Save;
      mrNo: Result := true;
   else
      Result := false;
   end;
end;

procedure TLVMainForm.EditorPrefix(Sender: TObject; Prefix, Key: char; var Handled: boolean);
begin
   if Prefix <> 'Q' then exit;
   case Key of
      'F': begin FindClick(nil); Handled := true; end;
      'A': begin ReplaceClick(nil); Handled := true; end;
   end;
end;

{ ---------------------------------------------------------------- File }

procedure TLVMainForm.NewClick(Sender: TObject);
begin
   NewFile;
end;

procedure TLVMainForm.OpenClick(Sender: TObject);
begin
   if OpenDlg.Execute then OpenFile(OpenDlg.FileName);
end;

procedure TLVMainForm.SaveClick(Sender: TObject);
var w: TEditWindow;
begin
   w := ActiveEditor;
   if (w <> nil) and w.Save then Say('Saved ' + ExtractFileName(w.FileName));
end;

procedure TLVMainForm.SaveAsClick(Sender: TObject);
var w: TEditWindow;
begin
   w := ActiveEditor;
   if w <> nil then SaveAsFor(w);
end;

procedure TLVMainForm.SaveAllClick(Sender: TObject);
var i, n: integer;
begin
   n := 0;
   for i := 0 to Screen.FormCount - 1 do
      if (Screen.Forms[i] is TEditWindow) and TEditWindow(Screen.Forms[i]).Editor.Modified then
         if TEditWindow(Screen.Forms[i]).Save then inc(n);
   Say('Saved ' + IntToStr(n) + ' file(s)');
end;

procedure TLVMainForm.ChangeDirClick(Sender: TObject);
var d: TSelectDirectoryDialog;
begin
   d := TSelectDirectoryDialog.Create(nil);
   try
      d.InitialDir := GetCurrentDir;
      if d.Execute and SetCurrentDir(d.FileName) then Say('Directory: ' + GetCurrentDir);
   finally
      d.Free;
   end;
end;

function TLVMainForm.CloseAll: boolean;
var i: integer;
    w: TEditWindow;
    ok: boolean;
begin
   Result := true;
   for i := Screen.FormCount - 1 downto 0 do
      if (i < Screen.FormCount) and (Screen.Forms[i] is TEditWindow) then
      begin
         w := TEditWindow(Screen.Forms[i]);
         ok := true;
         if Assigned(w.OnCloseQuery) then w.OnCloseQuery(w, ok);
         if not ok then exit(false);
         w.Editor.Modified := false;
         w.Release;
      end;
   Application.ProcessMessages;
end;

procedure TLVMainForm.ExitClick(Sender: TObject);
begin
   if not CloseAll then exit;
   Opts.SaveToFile(CfgFile);
   Application.Terminate;
end;

{ ---------------------------------------------------------------- Edit }

procedure TLVMainForm.UndoClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.Undo;
end;

procedure TLVMainForm.RedoClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.Redo;
end;

procedure TLVMainForm.CutClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.CutToClipboard;
end;

procedure TLVMainForm.CopyClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.CopyToClipboard;
end;

procedure TLVMainForm.PasteClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.PasteFromClipboard;
end;

procedure TLVMainForm.ClearClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.ClearSelection;
end;

procedure TLVMainForm.SelectAllClick(Sender: TObject);
begin
   if ActiveEditor <> nil then ActiveEditor.Editor.SelectAll;
end;

{ -------------------------------------------------------------- Search }

function TLVMainForm.DlgOptions(D: TFindDialog): TSynSearchOptions;
var o: TFindOptions;
begin
   o := D.Options;
   Result := [];
   if frMatchCase in o then Include(Result, ssoMatchCase);
   if frWholeWord in o then Include(Result, ssoWholeWord);
   if not (frDown in o) then Include(Result, ssoBackwards);
end;

procedure TLVMainForm.FindClick(Sender: TObject);
var w: TEditWindow;
begin
   w := ActiveEditor;
   if w = nil then exit;
   ReplaceDlg.CloseDialog;
   if w.Editor.SelAvail and (Pos(LineEnding, w.Editor.SelText) = 0) then FindDlg.FindText := w.Editor.SelText;
   FindDlg.Execute;
end;

procedure TLVMainForm.ReplaceClick(Sender: TObject);
var w: TEditWindow;
begin
   w := ActiveEditor;
   if w = nil then exit;
   FindDlg.CloseDialog;
   if w.Editor.SelAvail and (Pos(LineEnding, w.Editor.SelText) = 0) then ReplaceDlg.FindText := w.Editor.SelText;
   ReplaceDlg.Execute;
end;

procedure TLVMainForm.FindDlgFind(Sender: TObject);
var w: TEditWindow;
    d: TFindDialog;
begin
   w := ActiveEditor;
   d := TFindDialog(Sender);
   if w = nil then exit;
   FLastSearch := d.FindText;
   FLastOptions := DlgOptions(d);
   FLastReplace := '';
   if w.Editor.SearchReplace(FLastSearch, '', FLastOptions) = 0 then
   begin
      Say('"' + FLastSearch + '" not found');
      MessageDlg('Search', 'Search string not found.', mtInformation, [mbOK], 0);
   end
   else Say('Found "' + FLastSearch + '"');
end;

procedure TLVMainForm.ReplaceDlgReplace(Sender: TObject);
var w: TEditWindow;
    o: TSynSearchOptions;
    n: integer;
begin
   w := ActiveEditor;
   if w = nil then exit;
   FLastSearch := ReplaceDlg.FindText;
   FLastReplace := ReplaceDlg.ReplaceText;
   o := DlgOptions(ReplaceDlg);
   FLastOptions := o + [ssoReplace];
   if frReplaceAll in ReplaceDlg.Options then
   begin
      n := w.Editor.SearchReplace(FLastSearch, FLastReplace, o + [ssoReplaceAll, ssoEntireScope]);
      Say(IntToStr(n) + ' replaced');
   end
   else if w.Editor.SearchReplace(FLastSearch, FLastReplace, o + [ssoReplace]) = 0 then
      Say('"' + FLastSearch + '" not found')
   else Say('Replaced');
end;

procedure TLVMainForm.SearchAgainClick(Sender: TObject);
var w: TEditWindow;
begin
   w := ActiveEditor;
   if (w = nil) or (FLastSearch = '') then exit;
   if w.Editor.SearchReplace(FLastSearch, FLastReplace, FLastOptions) = 0 then
      Say('"' + FLastSearch + '" not found')
   else Say('Found "' + FLastSearch + '"');
end;

procedure TLVMainForm.GotoLineClick(Sender: TObject);
var w: TEditWindow;
    s: string;
begin
   w := ActiveEditor;
   if w = nil then exit;
   s := IntToStr(w.Editor.CaretY);
   if InputQuery('Go to line number', 'Line number:', s) and (StrToIntDef(s, 0) > 0) then
      w.Editor.GotoLine(StrToInt(s));
end;

{ ------------------------------------------------------------- compiling }

procedure TLVMainForm.ShowBusy(const S: string);
var l: TLabel;
begin
   FBusy := TForm.CreateNew(nil);
   FBusy.BorderStyle := bsDialog;
   FBusy.Caption := 'Compiling';
   FBusy.Position := poScreenCenter;
   FBusy.SetBounds(0, 0, 46, 6);
   l := TLabel.Create(FBusy);
   l.Parent := FBusy;
   l.SetBounds(2, 1, 40, 1);
   l.AutoSize := false;
   l.Caption := S;
   l := TLabel.Create(FBusy);
   l.Parent := FBusy;
   l.SetBounds(2, 2, 40, 1);
   l.Caption := 'with ' + Opts.CompilerPath;
   FBusy.Show;
   Application.ProcessMessages;
end;

procedure TLVMainForm.HideBusy;
begin
   FreeAndNil(FBusy);
   Application.ProcessMessages;
end;

function TLVMainForm.DoCompile(Kind: TLVBuildKind): boolean;
var w, target: TEditWindow;
    src, rsp, outf, arg: string;
    i, code: integer;
    l: TStringList;
    m: TLVMessage;
    t0: longint;
begin
   Result := false;
   w := ActiveEditor;
   { what to compile: the file in the editor; Make / Build: the primary file }
   if (Kind <> bkCompile) and (Opts.PrimaryFile <> '') then src := Opts.PrimaryFile
   else if w <> nil then src := w.FileName
   else
   begin
      MessageDlg('Compile', 'There is no file to compile.', mtError, [mbOK], 0);
      exit;
   end;
   { the files are saved first }
   target := EditorFor(src);
   if (target <> nil) and target.Untitled then
      if not SaveAsFor(target) then exit
      else src := target.FileName;
   for i := Screen.FormCount - 1 downto 0 do
      if Screen.Forms[i] is TEditWindow then
         if not AskSave(TEditWindow(Screen.Forms[i])) then exit;
   src := ExpandFileName(src);
   if not FileExists(src) then
   begin
      MessageDlg('Compile', 'File not found:' + LineEnding + src, mtError, [mbOK], 0);
      exit;
   end;
   { the options in a response file: fpc @LVCODE.RSP }
   { short names on the command line: DOS takes 126 characters }
   rsp := 'LVCODE.RSP';
   outf := 'LVCODE.OUT';
   arg := ExtractRelativePath(IncludeTrailingPathDelimiter(GetCurrentDir), src);
   if Length(arg) > Length(src) then arg := src;
   l := TStringList.Create;
   try
      Opts.GetOptions(src, Kind, l, false);
      l.SaveToFile(rsp);
   finally
      l.Free;
   end;
   case Kind of
      bkCompile: ShowBusy('Compiling ' + ExtractFileName(src));
      bkMake: ShowBusy('Making ' + ExtractFileName(src));
   else
      ShowBusy('Building ' + ExtractFileName(src));
   end;
   t0 := HWTicks;
   try
      code := ExecRedirected(Opts.CompilerPath, '@' + rsp + ' ' + arg, outf);
      Application.ResumeScreen;
   finally
      HideBusy;
   end;
   LastOutput.Clear;
   if FileExists(outf) then LastOutput.LoadFromFile(outf);
   LastTarget := src;
   LastExe := Opts.ExeNameFor(src);
   { the messages }
   for i := 0 to Screen.FormCount - 1 do
      if Screen.Forms[i] is TEditWindow then TEditWindow(Screen.Forms[i]).Editor.ErrorLine := 0;
   Msgs.Clear;
   Msgs.LoadOutput(LastOutput);
   if (code = -1) or (LastOutput.Count = 0) or
      (Pos('Bad command', LastOutput.Text) > 0) or (Pos('Illegal command', LastOutput.Text) > 0) or
      (Pos(': not found', LastOutput.Text) > 0) then
   begin
      Msgs.AddText('Cannot run the compiler: ' + Opts.CompilerPath);
      Msgs.AddText('(Options|Compiler: the Compiler field; or put fpc in the PATH)');
      inc(Msgs.Errors);
   end;
   Result := (Msgs.Errors = 0) and (Pos('Compilation aborted', LastOutput.Text) = 0);
   {$IFNDEF GO32V2}
   if code <> 0 then Result := false;
   {$ENDIF}
   LastOK := Result;
   if Result then
      LastResult := 'Compile successful: ' + ExtractFileName(src) + ' (' +
                    IntToStr((HWTicks - t0) div 1000) + '.' + IntToStr((HWTicks - t0) mod 1000 div 100) + ' s)'
   else LastResult := IntToStr(Msgs.Errors) + ' error(s) in ' + ExtractFileName(src);
   if Msgs.Warnings > 0 then LastResult := LastResult + ', ' + IntToStr(Msgs.Warnings) + ' warning(s)';
   Msgs.Caption := 'Compiler messages - ' + LastResult;
   Say(LastResult);
   Msgs.Show;
   { an error: the editor goes to it }
   m := Msgs.FirstError;
   if m <> nil then MessageGoto(Msgs, m)
   else if ActiveEditor <> nil then ActiveEditor.BringToFront;
end;

procedure TLVMainForm.MessageGoto(Sender: TObject; Msg: TLVMessage);
var w: TEditWindow;
begin
   if not Msg.HasPlace then exit;
   w := EditorFor(Msg.FileName);
   if (w = nil) and FileExists(Msg.FileName) then w := OpenFile(Msg.FileName);
   if w = nil then
   begin
      Say('Cannot open ' + Msg.FileName);
      exit;
   end;
   if Msg.Kind in [mkError, mkFatal, mkWarning] then w.Editor.ErrorLine := Msg.Line;
   w.Editor.GotoLine(Msg.Line, Msg.Col);
   w.BringToFront;
   w.ActiveControl := w.Editor;
   Msgs.Select(Msg);
   Say(Msg.Text);
end;

procedure TLVMainForm.DoRun;
var code: integer;
begin
   if not DoCompile(bkMake) then exit;
   if not FileExists(LastExe) then
   begin
      MessageDlg('Run', 'No program to run:' + LineEnding + LastExe, mtError, [mbOK], 0);
      exit;
   end;
   code := RunOnUserScreen(LastExe, Opts.RunParameters);
   Say('Program ended (exit code ' + IntToStr(code) + ')');
end;

procedure TLVMainForm.RunClick(Sender: TObject);
begin
   DoRun;
end;

procedure TLVMainForm.ParametersClick(Sender: TObject);
var s: string;
begin
   s := Opts.RunParameters;
   if InputQuery('Program parameters', 'Parameters:', s) then Opts.RunParameters := s;
end;

procedure TLVMainForm.UserScreenClick(Sender: TObject);
begin
   ShowUserScreen;
end;

procedure TLVMainForm.CompileClick(Sender: TObject);
begin
   DoCompile(bkCompile);
end;

procedure TLVMainForm.MakeClick(Sender: TObject);
begin
   DoCompile(bkMake);
end;

procedure TLVMainForm.BuildClick(Sender: TObject);
begin
   DoCompile(bkBuild);
end;

procedure TLVMainForm.PrimaryClick(Sender: TObject);
begin
   OpenDlg.FileName := Opts.PrimaryFile;
   if OpenDlg.Execute then
   begin
      Opts.PrimaryFile := OpenDlg.FileName;
      Say('Primary file: ' + ExtractFileName(Opts.PrimaryFile));
   end;
end;

procedure TLVMainForm.ClearPrimaryClick(Sender: TObject);
begin
   Opts.PrimaryFile := '';
   Say('No primary file');
end;

procedure TLVMainForm.NextMsgClick(Sender: TObject);
var m: TLVMessage;
begin
   m := Msgs.NextPlace(false);
   if m <> nil then MessageGoto(Msgs, m) else Say('No more messages');
end;

procedure TLVMainForm.PrevMsgClick(Sender: TObject);
var m: TLVMessage;
begin
   m := Msgs.NextPlace(true);
   if m <> nil then MessageGoto(Msgs, m) else Say('No earlier messages');
end;

procedure TLVMainForm.MessagesClick(Sender: TObject);
begin
   Msgs.Show;
end;

procedure TLVMainForm.InfoClick(Sender: TObject);
var s: string;
begin
   s := 'Primary file: ';
   if Opts.PrimaryFile <> '' then s := s + Opts.PrimaryFile else s := s + '(none)';
   s := s + LineEnding + 'Compiler: ' + Opts.CompilerPath;
   if LastTarget <> '' then
   begin
      s := s + LineEnding + 'Last compiled: ' + LastTarget;
      s := s + LineEnding + LastResult;
      s := s + LineEnding + 'Program: ' + LastExe;
   end;
   s := s + LineEnding + 'Directory: ' + GetCurrentDir;
   MessageDlg('Information', s, mtInformation, [mbOK], 0);
end;

{ ------------------------------------------------------------- Options }

procedure TLVMainForm.CompilerOptsClick(Sender: TObject);
var src: string;
begin
   if ActiveEditor <> nil then src := ActiveEditor.FileName else src := Opts.PrimaryFile;
   CompilerOptionsDialog(Opts, src, 0);
end;

procedure TLVMainForm.DirectoriesClick(Sender: TObject);
var src: string;
begin
   if ActiveEditor <> nil then src := ActiveEditor.FileName else src := Opts.PrimaryFile;
   CompilerOptionsDialog(Opts, src, 3);
end;

procedure TLVMainForm.EditorOptsClick(Sender: TObject);
begin
   if EditorOptionsDialog(Opts) then ApplyEditorOptions;
end;

procedure TLVMainForm.SaveOptsClick(Sender: TObject);
begin
   Opts.SaveToFile(CfgFile);
   Say('Options saved to ' + ExtractFileName(CfgFile));
end;

{ -------------------------------------------------------------- Window }

procedure TLVMainForm.TileClick(Sender: TObject);
begin
   Application.Tile;
end;

procedure TLVMainForm.CascadeClick(Sender: TObject);
begin
   Application.Cascade;
end;

procedure TLVMainForm.NextWinClick(Sender: TObject);
begin
   Application.NextWindow(false);
end;

procedure TLVMainForm.PrevWinClick(Sender: TObject);
begin
   Application.NextWindow(true);
end;

procedure TLVMainForm.CloseWinClick(Sender: TObject);
begin
   if Screen.ActiveForm <> nil then Screen.ActiveForm.Close;
end;

procedure TLVMainForm.CloseAllClick(Sender: TObject);
begin
   CloseAll;
end;

procedure TLVMainForm.WindowMenuClick(Sender: TObject);
var i, n: integer;
    f: TCustomForm;
    m: TMenuItem;
begin
   while FWindowMenu.Count > FWindowListStart do FWindowMenu.Items[FWindowMenu.Count - 1].Free;
   n := 0;
   for i := 0 to Screen.FormCount - 1 do
   begin
      f := Screen.Forms[i];
      if not f.Visible or (f = Self) then continue;
      inc(n);
      m := TMenuItem.Create(Self);
      if n <= 9 then m.Caption := '&' + IntToStr(n) + ' ' + f.Caption
      else m.Caption := '  ' + f.Caption;
      m.Checked := f = Screen.ActiveForm;
      m.Tag := PtrInt(f);
      m.OnClick := @WindowItemClick;
      FWindowMenu.Add(m);
   end;
end;

procedure TLVMainForm.WindowItemClick(Sender: TObject);
begin
   TCustomForm(TMenuItem(Sender).Tag).BringToFront;
end;

procedure TLVMainForm.AboutClick(Sender: TObject);
begin
   MessageDlg('About', LVTitle + ' ' + LVVersion + ' - LazarusVision Code' + LineEnding +
              'A Free Pascal IDE for DOS, built with FPTUI.' + LineEnding +
              'Compiler: ' + Opts.CompilerPath, mtInformation, [mbOK], 0);
end;

end.
