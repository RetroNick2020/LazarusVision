{-----------------------------------------------------------------------------}
{  TUIDLGS - the common dialogs, LCL names (Dialogs):                          }
{     TOpenDialog, TSaveDialog   FileName, InitialDir, Filter, FilterIndex,    }
{                                DefaultExt, Options (ofOverwritePrompt,      }
{                                ofFileMustExist, ofPathMustExist), Title,    }
{                                Execute                                      }
{     TSelectDirectoryDialog     FileName = the folder                        }
{     TColorDialog               Color (0..15), Execute                       }
{     TFindDialog                FindText, Options (frDown, frMatchCase,      }
{                                frWholeWord, frFindNext), OnFind, Execute    }
{                                (not modal), CloseDialog                     }
{     TReplaceDialog             + ReplaceText, OnReplace (frReplace,         }
{                                frReplaceAll)                                }
{  and helpers that search a TMemo: MemoFindNext, MemoReplace.               }
{                                                                             }
{  The file dialog: a file list (the Filter's masks), a folder list ('..'    }
{  first), File type and (DOS) Drive combo boxes, the folder shown below.    }
{  Typing a name and Enter takes it; a folder name or '..' goes there; a     }
{  name with * or ? becomes the mask. Enter or a double click on a folder    }
{  opens it, on a file takes it.                                             }
{-----------------------------------------------------------------------------}
unit TUIDlgs;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIList, TUIExt,
     TUIGrid, TUIMemo;

type
   TCommonDialog = class(TComponent)
   private
      FTitle: string;
      FOnShow, FOnClose: TNotifyEvent;
   protected
      procedure DoShow; virtual;
      procedure DoClose; virtual;
   public
      function Execute: boolean; virtual; abstract;
   published
      property Title: string read FTitle write FTitle;
      property OnShow: TNotifyEvent read FOnShow write FOnShow;
      property OnClose: TNotifyEvent read FOnClose write FOnClose;
   end;

   TOpenOption = (ofReadOnly, ofOverwritePrompt, ofHideReadOnly, ofNoChangeDir,
                  ofShowHelp, ofNoValidate, ofAllowMultiSelect, ofExtensionDifferent,
                  ofPathMustExist, ofFileMustExist, ofCreatePrompt, ofShareAware,
                  ofNoReadOnlyReturn, ofNoTestFileCreate, ofNoNetworkButton,
                  ofNoLongNames, ofOldStyleDialog, ofNoDereferenceLinks,
                  ofEnableIncludeNotify, ofEnableSizing, ofDontAddToRecent,
                  ofForceShowHidden, ofViewDetail, ofAutoPreview);
   TOpenOptions = set of TOpenOption;

   TFileDialogKind = (fdOpen, fdSave, fdFolder);

   TOpenDialog = class(TCommonDialog)
   private
      FFileName, FInitialDir, FFilter, FDefaultExt: string;
      FFilterIndex: integer;
      FOptions: TOpenOptions;
      FFiles: TStringList;
   protected
      function Kind: TFileDialogKind; virtual;
      function DefaultTitle: string; virtual;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      function Execute: boolean; override;
      { 'Text files|*.txt|Pascal|*.pas;*.pp|All files|*.*' }
      { added when the name typed has no extension ('txt' or '.txt') }
   published
      property FileName: string read FFileName write FFileName;
      property Files: TStringList read FFiles;
      property InitialDir: string read FInitialDir write FInitialDir;
      property Filter: string read FFilter write FFilter;
      property FilterIndex: integer read FFilterIndex write FFilterIndex default 1;
      property DefaultExt: string read FDefaultExt write FDefaultExt;
      property Options: TOpenOptions read FOptions write FOptions;
   end;

   TSaveDialog = class(TOpenDialog)
   protected
      function Kind: TFileDialogKind; override;
      function DefaultTitle: string; override;
   end;

   TSelectDirectoryDialog = class(TOpenDialog)
   protected
      function Kind: TFileDialogKind; override;
      function DefaultTitle: string; override;
   end;

   TColorDialog = class(TCommonDialog)
   private
      FColor: TColor;
   public
      constructor Create(AOwner: TComponent); override;
      function Execute: boolean; override;
   published
      property Color: TColor read FColor write FColor default clBlack;
   end;

   TFindOption = (frDown, frFindNext, frHideMatchCase, frHideWholeWord,
                  frHideUpDown, frMatchCase, frDisableMatchCase, frDisableUpDown,
                  frDisableWholeWord, frReplace, frReplaceAll, frWholeWord,
                  frShowHelp, frEntireScope, frHideEntireScope, frPromptOnReplace,
                  frHidePromptOnReplace);
   TFindOptions = set of TFindOption;

   TFindDialog = class(TCommonDialog)
   private
      FFindText, FReplaceText: string;
      FOptions: TFindOptions;
      FForm: TForm;
      FFindEdit, FReplaceEdit: TEdit;
      FCaseCheck, FWordCheck: TCheckBox;
      FDirGroup: TRadioGroup;
      FOnFind, FOnReplace: TNotifyEvent;
      function  GetFindText: string;
      procedure SetFindText(const V: string);
      function  GetOptions: TFindOptions;
      procedure SetOptions(V: TFindOptions);
      procedure MakeForm;
      procedure ReadForm;
      procedure FindClick(Sender: TObject);
      procedure ReplaceClick(Sender: TObject);
      procedure ReplaceAllClick(Sender: TObject);
      procedure CancelClick(Sender: TObject);
   protected
      function  IsReplace: boolean; virtual;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
      procedure Find; virtual;
      procedure Replace; virtual;
   public
      destructor Destroy; override;
      { shows the dialog (not modal); always true }
      function  Execute: boolean; override;
      procedure CloseDialog;
      function  Visible: boolean;
      property Form: TForm read FForm;
   published
      property FindText: string read GetFindText write SetFindText;
      property Options: TFindOptions read GetOptions write SetOptions;
      property OnFind: TNotifyEvent read FOnFind write FOnFind;
   end;

   TReplaceDialog = class(TFindDialog)
   private
      function  GetReplaceText: string;
      procedure SetReplaceText(const V: string);
   protected
      function  IsReplace: boolean; override;
   public
   published
      property ReplaceText: string read GetReplaceText write SetReplaceText;
      property OnReplace: TNotifyEvent read FOnReplace write FOnReplace;
   end;

   { the file dialog's form (public so that programs and tests can reach in) }
   TFileDialogForm = class(TForm)
   public
      Kind: TFileDialogKind;
      Dir: string;                 { the folder shown, with a separator at the end }
      Masks: string;               { 'x;y' }
      Dialog: TOpenDialog;
      NameEdit: TEdit;
      FileList, DirList: TListBox;
      TypeCombo, DriveCombo: TComboBox;
      PathLabel: TLabel;
      OkButton, CancelButton: TButton;
      Filters: TStringList;        { name=masks }
      ResultName: string;
      constructor CreateFor(ADialog: TOpenDialog; AKind: TFileDialogKind);
      destructor Destroy; override;
      procedure SetDir(const D: string);
      procedure Fill;
      procedure OkClick(Sender: TObject);
      procedure FileListChange(Sender: TObject; User: boolean);
      procedure FileListDblClick(Sender: TObject);
      procedure DirListDblClick(Sender: TObject);
      procedure TypeComboSelect(Sender: TObject);
      procedure DriveComboSelect(Sender: TObject);
   end;

{ '*.pas' style masks (several: 'a;b'), case does not matter }
function MatchesMask(const Name, Mask: string): boolean;
function MatchesMaskList(const Name, Masks: string): boolean;

{ search Memo for S from the selection (frDown: forward, else back),     }
{ frMatchCase, frWholeWord; the find is selected. True = found          }
function MemoFindNext(Memo: TMemo; const S: string; Options: TFindOptions): boolean;
{ frReplaceAll: every S to R (the count); else the selected S (if it is }
{ one) is replaced and the next one selected                            }
function MemoReplace(Memo: TMemo; const S, R: string; Options: TFindOptions): integer;

implementation

{=============================================================================}
{  masks                                                                      }
{=============================================================================}

function MatchesMask(const Name, Mask: string): boolean;

   function Match(n, m: integer): boolean;
   begin
      while m <= Length(Mask) do
      begin
         case Mask[m] of
            '*':
               begin
                  { '*' matches any run; '*.*' also matches names without a dot }
                  if (m < Length(Mask)) and (Copy(Mask, m, 3) = '*.*') and (m + 2 = Length(Mask)) then
                     exit(true);
                  while n <= Length(Name) + 1 do
                  begin
                     if Match(n, m + 1) then exit(true);
                     inc(n);
                  end;
                  exit(false);
               end;
            '?':
               begin
                  if n > Length(Name) then exit(false);
                  inc(n);
               end;
         else
            if (n > Length(Name)) or (UpCase(Name[n]) <> UpCase(Mask[m])) then exit(false);
            inc(n);
         end;
         inc(m);
      end;
      Result := n > Length(Name);
   end;

begin
   Result := Match(1, 1);
end;

function MatchesMaskList(const Name, Masks: string): boolean;
var rest, m: string;
    p: integer;
begin
   rest := Masks;
   if Trim(rest) = '' then exit(true);
   repeat
      p := Pos(';', rest);
      if p = 0 then begin m := rest; rest := ''; end
      else begin m := Copy(rest, 1, p - 1); Delete(rest, 1, p); end;
      m := Trim(m);
      if (m <> '') and MatchesMask(Name, m) then exit(true);
   until rest = '';
   Result := false;
end;

{=============================================================================}
{  TCommonDialog                                                              }
{=============================================================================}

procedure TCommonDialog.DoShow;
begin
   if Assigned(FOnShow) then FOnShow(Self);
end;

procedure TCommonDialog.DoClose;
begin
   if Assigned(FOnClose) then FOnClose(Self);
end;

{=============================================================================}
{  TFileDialogForm                                                            }
{=============================================================================}

function WithDelim(const D: string): string;
begin
   Result := D;
   if (Result <> '') and not (Result[Length(Result)] in AllowDirectorySeparators) then
      Result := Result + DirectorySeparator;
end;

constructor TFileDialogForm.CreateFor(ADialog: TOpenDialog; AKind: TFileDialogKind);

   function Lbl(X, Y: integer; const S: string; F: TWinControl): TLabel;
   begin
      Result := TLabel.Create(Self);
      Result.Parent := Self;
      Result.Left := X;
      Result.Top := Y;
      Result.Caption := S;
      Result.FocusControl := F;
   end;

var rest, nm, ms: string;
    p, i: integer;
    {$IFDEF GO32V2}
    d: char;
    {$ENDIF}
begin
   CreateNew(nil);
   Dialog := ADialog;
   Kind := AKind;
   Filters := TStringList.Create;
   BorderStyle := bsDialog;
   Position := poScreenCenter;
   SetBounds(0, 0, 64, 21);
   if ADialog.Title <> '' then Caption := ADialog.Title else Caption := ADialog.DefaultTitle;

   NameEdit := TEdit.Create(Self);
   NameEdit.Parent := Self;
   NameEdit.SetBounds(13, 1, 48, 1);
   if AKind = fdFolder then Lbl(1, 1, 'Folder &name:', NameEdit)
   else Lbl(1, 1, 'File &name:', NameEdit);

   FileList := TListBox.Create(Self);
   FileList.Parent := Self;
   FileList.SetBounds(1, 4, 28, 10);
   FileList.Sorted := true;
   FileList.OnSelectionChange := @FileListChange;
   FileList.OnDblClick := @FileListDblClick;
   DirList := TListBox.Create(Self);
   DirList.Parent := Self;
   DirList.SetBounds(32, 4, 29, 10);
   DirList.OnDblClick := @DirListDblClick;
   if AKind = fdFolder then
   begin
      FileList.Enabled := false;
      Lbl(1, 3, 'Files:', FileList);
   end
   else Lbl(1, 3, '&Files:', FileList);
   Lbl(32, 3, '&Directories:', DirList);

   TypeCombo := TComboBox.Create(Self);
   TypeCombo.Parent := Self;
   TypeCombo.Style := csDropDownList;
   TypeCombo.SetBounds(13, 15, 16, 1);
   TypeCombo.OnSelect := @TypeComboSelect;
   Lbl(1, 15, 'File &type:', TypeCombo);
   { the filter: name|masks|name|masks }
   rest := ADialog.Filter;
   while rest <> '' do
   begin
      p := Pos('|', rest);
      if p = 0 then begin nm := rest; rest := ''; end
      else begin nm := Copy(rest, 1, p - 1); Delete(rest, 1, p); end;
      p := Pos('|', rest);
      if p = 0 then begin ms := rest; rest := ''; end
      else begin ms := Copy(rest, 1, p - 1); Delete(rest, 1, p); end;
      Filters.Add(nm + '=' + ms);
      TypeCombo.Items.Add(nm);
   end;
   if Filters.Count = 0 then
   begin
      Filters.Add('All files=*.*');
      TypeCombo.Items.Add('All files');
   end;
   i := ADialog.FilterIndex - 1;
   if (i < 0) or (i >= Filters.Count) then i := 0;
   TypeCombo.ItemIndex := i;
   Masks := Filters.ValueFromIndex[i];
   if AKind = fdFolder then TypeCombo.Enabled := false;

   DriveCombo := TComboBox.Create(Self);
   DriveCombo.Parent := Self;
   DriveCombo.Style := csDropDownList;
   DriveCombo.SetBounds(40, 15, 8, 1);
   DriveCombo.OnSelect := @DriveComboSelect;
   Lbl(32, 15, 'Dri&ve:', DriveCombo);
   {$IFDEF GO32V2}
   { C: and up (A: and B: are left out: no floppy prompts) }
   for d := 'C' to 'Z' do
      if DirectoryExists(d + ':\') then DriveCombo.Items.Add(d + ':');
   {$ELSE}
   DriveCombo.Items.Add(DirectorySeparator);
   DriveCombo.Enabled := false;
   {$ENDIF}

   PathLabel := TLabel.Create(Self);
   PathLabel.Parent := Self;
   PathLabel.AutoSize := false;
   PathLabel.ShowAccelChar := false;
   PathLabel.SetBounds(1, 16, 60, 1);

   OkButton := TButton.Create(Self);
   OkButton.Parent := Self;
   OkButton.SetBounds(35, 17, 12, 2);
   if AKind = fdSave then OkButton.Caption := '&Save'
   else if AKind = fdOpen then OkButton.Caption := '&Open'
   else OkButton.Caption := 'OK';
   OkButton.Default := true;
   OkButton.OnClick := @OkClick;
   CancelButton := TButton.Create(Self);
   CancelButton.Parent := Self;
   CancelButton.SetBounds(49, 17, 12, 2);
   CancelButton.Caption := 'Cancel';
   CancelButton.Cancel := true;
   CancelButton.ModalResult := mrCancel;

   { the folder to start in }
   if ADialog.InitialDir <> '' then rest := ADialog.InitialDir
   else if ExtractFilePath(ADialog.FileName) <> '' then rest := ExtractFilePath(ADialog.FileName)
   else rest := GetCurrentDir;
   if not DirectoryExists(rest) then rest := GetCurrentDir;
   if AKind <> fdFolder then NameEdit.Text := ExtractFileName(ADialog.FileName);
   SetDir(rest);
   ActiveControl := NameEdit;
end;

destructor TFileDialogForm.Destroy;
begin
   Filters.Free;
   inherited Destroy;
end;

procedure TFileDialogForm.SetDir(const D: string);
{$IFDEF GO32V2}
var i: integer;
{$ENDIF}
begin
   Dir := WithDelim(ExpandFileName(D));
   {$IFDEF GO32V2}
   for i := 0 to DriveCombo.Items.Count - 1 do
      if UpCase(DriveCombo.Items[i][1]) = UpCase(Dir[1]) then DriveCombo.ItemIndex := i;
   {$ELSE}
   DriveCombo.ItemIndex := 0;
   {$ENDIF}
   Fill;
end;

procedure TFileDialogForm.Fill;
var sr: TSearchRec;
    dirs: TStringList;
    i: integer;
    s: string;
begin
   dirs := TStringList.Create;
   try
      dirs.Sorted := true;
      FileList.Items.BeginUpdate;
      FileList.Items.Clear;
      if FindFirst(Dir + AllFilesMask, faAnyFile, sr) = 0 then
      begin
         repeat
            if (sr.Name = '.') or (sr.Name = '..') then continue;
            if sr.Attr and faDirectory <> 0 then dirs.Add(sr.Name + DirectorySeparator)
            else if (Kind <> fdFolder) and MatchesMaskList(sr.Name, Masks) then
               FileList.Items.Add(sr.Name);
         until FindNext(sr) <> 0;
         FindClose(sr);
      end;
      FileList.Items.EndUpdate;
      FileList.ItemIndex := -1;
      DirList.Items.BeginUpdate;
      DirList.Items.Clear;
      { '..' unless at the top of a drive }
      s := ExcludeTrailingPathDelimiter(Dir);
      if ExtractFileDir(s) <> s then DirList.Items.Add('..' + DirectorySeparator);
      for i := 0 to dirs.Count - 1 do DirList.Items.Add(dirs[i]);
      DirList.Items.EndUpdate;
      DirList.ItemIndex := -1;
   finally
      dirs.Free;
   end;
   s := Dir;
   if Length(s) > PathLabel.Width then s := '...' + Copy(s, Length(s) - PathLabel.Width + 4, MaxInt);
   PathLabel.Caption := s;
   if Kind = fdFolder then NameEdit.Text := '';
end;

procedure TFileDialogForm.FileListChange(Sender: TObject; User: boolean);
begin
   if User and (FileList.ItemIndex >= 0) then NameEdit.Text := FileList.Items[FileList.ItemIndex];
end;

procedure TFileDialogForm.FileListDblClick(Sender: TObject);
begin
   if FileList.ItemIndex >= 0 then
   begin
      NameEdit.Text := FileList.Items[FileList.ItemIndex];
      ActiveControl := NameEdit;
      OkClick(nil);
   end;
end;

procedure TFileDialogForm.DirListDblClick(Sender: TObject);
var s: string;
begin
   if DirList.ItemIndex < 0 then exit;
   s := DirList.Items[DirList.ItemIndex];
   SetDir(Dir + s);
   DirList.SetFocus;
end;

procedure TFileDialogForm.TypeComboSelect(Sender: TObject);
begin
   if TypeCombo.ItemIndex >= 0 then Masks := Filters.ValueFromIndex[TypeCombo.ItemIndex];
   Fill;
end;

procedure TFileDialogForm.DriveComboSelect(Sender: TObject);
begin
   if DriveCombo.ItemIndex >= 0 then SetDir(DriveCombo.Items[DriveCombo.ItemIndex] + DirectorySeparator);
end;

procedure TFileDialogForm.OkClick(Sender: TObject);
var t, full, ext: string;
begin
   { Enter in the folder list opens the folder }
   if (ActiveControl = DirList) and (DirList.ItemIndex >= 0) then
   begin
      DirListDblClick(nil);
      exit;
   end;
   if (ActiveControl = FileList) and (FileList.ItemIndex >= 0) then
      NameEdit.Text := FileList.Items[FileList.ItemIndex];
   t := Trim(NameEdit.Text);
   if Kind = fdFolder then
   begin
      if t = '' then full := Dir
      else if (ExtractFileDrive(t) <> '') or (t[1] in AllowDirectorySeparators) then full := t
      else full := Dir + t;
      full := ExpandFileName(full);
      if not DirectoryExists(full) then
      begin
         MessageDlg('Warning', 'The folder does not exist:' + LineEnding + full, mtWarning, [mbOK], 0);
         exit;
      end;
      ResultName := ExcludeTrailingPathDelimiter(full);
      ModalResult := mrOk;
      exit;
   end;
   if t = '' then
   begin
      HWBeep;
      exit;
   end;
   { a mask: show those files }
   if (Pos('*', t) > 0) or (Pos('?', t) > 0) then
   begin
      Masks := t;
      Fill;
      NameEdit.Text := '';
      exit;
   end;
   if (ExtractFileDrive(t) <> '') or (t[1] in AllowDirectorySeparators) then full := t
   else full := Dir + t;
   full := ExpandFileName(full);
   if DirectoryExists(full) then
   begin
      SetDir(full);
      NameEdit.Text := '';
      exit;
   end;
   if (ExtractFileExt(full) = '') and (Dialog.DefaultExt <> '') then
   begin
      ext := Dialog.DefaultExt;
      if ext[1] <> '.' then ext := '.' + ext;
      full := full + ext;
   end;
   if ((ofPathMustExist in Dialog.Options) or (ofFileMustExist in Dialog.Options)) and
      not DirectoryExists(ExtractFileDir(full)) then
   begin
      MessageDlg('Warning', 'The folder does not exist:' + LineEnding + ExtractFileDir(full),
                 mtWarning, [mbOK], 0);
      exit;
   end;
   if (Kind = fdOpen) and (ofFileMustExist in Dialog.Options) and not FileExists(full) then
   begin
      MessageDlg('Warning', 'File not found:' + LineEnding + full, mtWarning, [mbOK], 0);
      exit;
   end;
   if (Kind = fdSave) and (ofOverwritePrompt in Dialog.Options) and FileExists(full) then
      if MessageDlg('Confirm', ExtractFileName(full) + ' already exists.' + LineEnding +
                    'Replace it?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then exit;
   ResultName := full;
   ModalResult := mrOk;
end;

{=============================================================================}
{  TOpenDialog, TSaveDialog, TSelectDirectoryDialog                           }
{=============================================================================}

constructor TOpenDialog.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FFiles := TStringList.Create;
   FFilterIndex := 1;
end;

destructor TOpenDialog.Destroy;
begin
   FFiles.Free;
   inherited Destroy;
end;

function TOpenDialog.Kind: TFileDialogKind;
begin
   Result := fdOpen;
end;

function TOpenDialog.DefaultTitle: string;
begin
   Result := 'Open';
end;

function TOpenDialog.Execute: boolean;
var f: TFileDialogForm;
begin
   f := TFileDialogForm.CreateFor(Self, Kind);
   try
      DoShow;
      Result := f.ShowModal = mrOk;
      if Result then
      begin
         FFileName := f.ResultName;
         FFiles.Clear;
         FFiles.Add(FFileName);
         FFilterIndex := f.TypeCombo.ItemIndex + 1;
         if Kind = fdFolder then FInitialDir := FFileName
         else FInitialDir := ExtractFileDir(FFileName);
      end;
   finally
      f.Free;
   end;
   DoClose;
end;

function TSaveDialog.Kind: TFileDialogKind;
begin
   Result := fdSave;
end;

function TSaveDialog.DefaultTitle: string;
begin
   Result := 'Save as';
end;

function TSelectDirectoryDialog.Kind: TFileDialogKind;
begin
   Result := fdFolder;
end;

function TSelectDirectoryDialog.DefaultTitle: string;
begin
   Result := 'Select a folder';
end;

{=============================================================================}
{  TColorDialog                                                               }
{=============================================================================}

const
   ColourNames: array[0..15] of string = ('Black', 'Blue', 'Green', 'Cyan', 'Red',
      'Magenta', 'Brown', 'Light gray', 'Dark gray', 'Light blue', 'Light green',
      'Light cyan', 'Light red', 'Light magenta', 'Yellow', 'White');

type
   TColourForm = class(TForm)
   public
      Grid: TDrawGrid;
      NameLabel: TLabel;
      procedure DrawCell(Sender: TObject; aCol, aRow: integer; aRect: TRect; aState: TGridDrawState);
      procedure Select(Sender: TObject; aCol, aRow: integer);
      procedure GridDblClick(Sender: TObject);
      function  Colour: integer;
   end;

function TColourForm.Colour: integer;
begin
   Result := Grid.Row * 4 + Grid.Col;
end;

procedure TColourForm.DrawCell(Sender: TObject; aCol, aRow: integer; aRect: TRect;
                               aState: TGridDrawState);
var c: integer;
    fg: byte;
begin
   c := aRow * 4 + aCol;
   if c in [0, 1, 4, 5, 6, 8] then fg := tcWhite else fg := tcBlack;
   Grid.Canvas.Fill(aRect, ' ', MakeAttr(fg, c));
   if gdSelected in aState then
   begin
      Grid.Canvas.PutChar(aRect.Left, aRect.Top, chArrowRight, MakeAttr(fg, c));
      Grid.Canvas.PutChar(aRect.Right - 1, aRect.Top, chArrowLeft, MakeAttr(fg, c));
   end;
end;

procedure TColourForm.Select(Sender: TObject; aCol, aRow: integer);
begin
   NameLabel.Caption := ColourNames[aRow * 4 + aCol];
end;

procedure TColourForm.GridDblClick(Sender: TObject);
begin
   ModalResult := mrOk;
end;

constructor TColorDialog.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FColor := clBlack;
end;

function TColorDialog.Execute: boolean;
var f: TColourForm;
    ok, cancel: TButton;
    c: integer;
begin
   f := TColourForm.CreateNew(nil);
   try
      f.BorderStyle := bsDialog;
      f.Position := poScreenCenter;
      if FTitle <> '' then f.Caption := FTitle else f.Caption := 'Colour';
      f.SetBounds(0, 0, 54, 12);
      f.Grid := TDrawGrid.Create(f);
      f.Grid.Parent := f;
      f.Grid.SetBounds(1, 1, 48, 4);
      f.Grid.ColCount := 4;
      f.Grid.RowCount := 4;
      f.Grid.FixedCols := 0;
      f.Grid.FixedRows := 0;
      f.Grid.DefaultColWidth := 12;
      f.Grid.Options := [];
      f.Grid.OnDrawCell := @f.DrawCell;
      f.Grid.OnSelection := @f.Select;
      f.Grid.OnDblClick := @f.GridDblClick;
      f.NameLabel := TLabel.Create(f);
      f.NameLabel.Parent := f;
      f.NameLabel.SetBounds(1, 6, 20, 1);
      ok := TButton.Create(f);
      ok.Parent := f;
      ok.SetBounds(24, 7, 12, 2);
      ok.Caption := 'OK';
      ok.Default := true;
      ok.ModalResult := mrOk;
      cancel := TButton.Create(f);
      cancel.Parent := f;
      cancel.SetBounds(37, 7, 12, 2);
      cancel.Caption := 'Cancel';
      cancel.Cancel := true;
      cancel.ModalResult := mrCancel;
      c := FColor;
      if (c < 0) or (c > 15) then c := 0;
      f.Grid.MoveTo(c mod 4, c div 4);
      f.NameLabel.Caption := ColourNames[c];
      f.ActiveControl := f.Grid;
      DoShow;
      Result := f.ShowModal = mrOk;
      if Result then FColor := f.Colour;
   finally
      f.Free;
   end;
   DoClose;
end;

{=============================================================================}
{  TFindDialog, TReplaceDialog                                                }
{=============================================================================}

destructor TFindDialog.Destroy;
begin
   FreeAndNil(FForm);
   inherited Destroy;
end;

procedure TFindDialog.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FForm) then FForm := nil;
end;

function TFindDialog.IsReplace: boolean;
begin
   Result := false;
end;

procedure TFindDialog.MakeForm;
var b: TButton;
    l: TLabel;
    y: integer;

   function Btn(X, Y: integer; const S: string; H: TNotifyEvent): TButton;
   begin
      Result := TButton.Create(FForm);
      Result.Parent := FForm;
      Result.SetBounds(X, Y, 15, 2);
      Result.Caption := S;
      Result.OnClick := H;
   end;

begin
   if FForm <> nil then exit;
   FForm := TForm.CreateNew(nil);
   { the application may free the form first (when the program ends) }
   FForm.FreeNotification(Self);
   FForm.BorderStyle := bsDialog;
   FForm.Position := poScreenCenter;
   if FTitle <> '' then FForm.Caption := FTitle
   else if IsReplace then FForm.Caption := 'Replace'
   else FForm.Caption := 'Find';
   FForm.SetBounds(0, 0, 60, 12);
   FFindEdit := TEdit.Create(FForm);
   FFindEdit.Parent := FForm;
   FFindEdit.SetBounds(15, 1, 26, 1);
   l := TLabel.Create(FForm);
   l.Parent := FForm;
   l.SetBounds(1, 1, 12, 1);
   l.Caption := 'Fi&nd what:';
   l.FocusControl := FFindEdit;
   y := 3;
   if IsReplace then
   begin
      FReplaceEdit := TEdit.Create(FForm);
      FReplaceEdit.Parent := FForm;
      FReplaceEdit.SetBounds(15, 3, 26, 1);
      l := TLabel.Create(FForm);
      l.Parent := FForm;
      l.SetBounds(1, 3, 13, 1);
      l.Caption := 'Re&place with:';
      l.FocusControl := FReplaceEdit;
      y := 5;
   end;
   FCaseCheck := TCheckBox.Create(FForm);
   FCaseCheck.Parent := FForm;
   FCaseCheck.SetBounds(1, y, 18, 1);
   FCaseCheck.Caption := 'Match &case';
   FWordCheck := TCheckBox.Create(FForm);
   FWordCheck.Parent := FForm;
   FWordCheck.SetBounds(1, y + 1, 18, 1);
   FWordCheck.Caption := '&Whole word';
   FDirGroup := TRadioGroup.Create(FForm);
   FDirGroup.Parent := FForm;
   FDirGroup.SetBounds(22, y, 19, 4);
   FDirGroup.Caption := 'Direction';
   FDirGroup.Items.Add('&Up');
   FDirGroup.Items.Add('&Down');
   b := Btn(43, 1, 'Find &next', @FindClick);
   b.Default := true;
   if IsReplace then
   begin
      Btn(43, 3, '&Replace', @ReplaceClick);
      Btn(43, 5, 'Replace &all', @ReplaceAllClick);
      b := Btn(43, 7, 'Cancel', @CancelClick);
   end
   else
      b := Btn(43, 3, 'Cancel', @CancelClick);
   b.Cancel := true;
end;

{ the dialog's controls -> FFindText, FReplaceText, FOptions }
procedure TFindDialog.ReadForm;
begin
   if FForm = nil then exit;
   FFindText := FFindEdit.Text;
   if FReplaceEdit <> nil then FReplaceText := FReplaceEdit.Text;
   { (frFindNext / frReplace / frReplaceAll stay: they say which button) }
   FOptions := FOptions - [frMatchCase, frWholeWord, frDown];
   if FCaseCheck.Checked then Include(FOptions, frMatchCase);
   if FWordCheck.Checked then Include(FOptions, frWholeWord);
   if FDirGroup.ItemIndex <> 0 then Include(FOptions, frDown);
end;

function TFindDialog.Execute: boolean;
begin
   MakeForm;
   FFindEdit.Text := FFindText;
   if FReplaceEdit <> nil then FReplaceEdit.Text := FReplaceText;
   FCaseCheck.Checked := frMatchCase in FOptions;
   FWordCheck.Checked := frWholeWord in FOptions;
   if frDown in FOptions then FDirGroup.ItemIndex := 1 else FDirGroup.ItemIndex := 0;
   FForm.ActiveControl := FFindEdit;
   DoShow;
   FForm.Show;
   Result := true;
end;

procedure TFindDialog.CloseDialog;
begin
   if (FForm <> nil) and FForm.Visible then
   begin
      ReadForm;
      FForm.Hide;
      DoClose;
   end;
end;

function TFindDialog.Visible: boolean;
begin
   Result := (FForm <> nil) and FForm.Visible;
end;

function TFindDialog.GetFindText: string;
begin
   if Visible then ReadForm;
   Result := FFindText;
end;

procedure TFindDialog.SetFindText(const V: string);
begin
   FFindText := V;
   if FForm <> nil then FFindEdit.Text := V;
end;

function TFindDialog.GetOptions: TFindOptions;
begin
   if Visible then ReadForm;
   Result := FOptions;
end;

procedure TFindDialog.SetOptions(V: TFindOptions);
begin
   FOptions := V;
end;

procedure TFindDialog.Find;
begin
   if Assigned(FOnFind) then FOnFind(Self);
end;

procedure TFindDialog.Replace;
begin
   if Assigned(FOnReplace) then FOnReplace(Self);
end;

procedure TFindDialog.FindClick(Sender: TObject);
begin
   ReadForm;
   FOptions := FOptions - [frReplace, frReplaceAll] + [frFindNext];
   Find;
end;

procedure TFindDialog.ReplaceClick(Sender: TObject);
begin
   ReadForm;
   FOptions := FOptions - [frFindNext, frReplaceAll] + [frReplace];
   Replace;
end;

procedure TFindDialog.ReplaceAllClick(Sender: TObject);
begin
   ReadForm;
   FOptions := FOptions - [frFindNext, frReplace] + [frReplaceAll];
   Replace;
end;

procedure TFindDialog.CancelClick(Sender: TObject);
begin
   CloseDialog;
end;

function TReplaceDialog.IsReplace: boolean;
begin
   Result := true;
end;

function TReplaceDialog.GetReplaceText: string;
begin
   if Visible then ReadForm;
   Result := FReplaceText;
end;

procedure TReplaceDialog.SetReplaceText(const V: string);
begin
   FReplaceText := V;
   if FReplaceEdit <> nil then FReplaceEdit.Text := V;
end;

{=============================================================================}
{  searching a memo                                                           }
{=============================================================================}

function IsWordChar(C: char): boolean;
begin
   Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function FoundAt(const T, S: string; P: integer; Options: TFindOptions): boolean;
begin
   Result := false;
   if (P < 1) or (P + Length(S) - 1 > Length(T)) then exit;
   if frMatchCase in Options then
   begin
      if Copy(T, P, Length(S)) <> S then exit;
   end
   else if CompareText(Copy(T, P, Length(S)), S) <> 0 then exit;
   if frWholeWord in Options then
   begin
      if (P > 1) and IsWordChar(T[P - 1]) then exit;
      if (P + Length(S) <= Length(T)) and IsWordChar(T[P + Length(S)]) then exit;
   end;
   Result := true;
end;

function MemoFindNext(Memo: TMemo; const S: string; Options: TFindOptions): boolean;
var t: string;
    p: integer;
begin
   Result := false;
   if S = '' then exit;
   t := Memo.Text;
   if frDown in Options then
   begin
      p := Memo.SelStart + Memo.SelLength + 1;
      while p + Length(S) - 1 <= Length(t) do
      begin
         if FoundAt(t, S, p, Options) then break;
         inc(p);
      end;
   end
   else
   begin
      { 1 based; the find must end before the selection }
      p := Memo.SelStart - Length(S) + 1;
      while p >= 1 do
      begin
         if FoundAt(t, S, p, Options) then break;
         dec(p);
      end;
   end;
   if (p < 1) or (p + Length(S) - 1 > Length(t)) then exit;
   Memo.SelStart := p - 1;
   Memo.SelLength := Length(S);
   Result := true;
end;

function MemoReplace(Memo: TMemo; const S, R: string; Options: TFindOptions): integer;
var t: string;
begin
   Result := 0;
   if S = '' then exit;
   if frReplaceAll in Options then
   begin
      Memo.SelStart := 0;
      Include(Options, frDown);
      while MemoFindNext(Memo, S, Options) do
      begin
         Memo.SelText := R;
         inc(Result);
      end;
      exit;
   end;
   { the selection is the text looked for: replace it, then find the next }
   t := Memo.SelText;
   if (Length(t) = Length(S)) and FoundAt(t, S, 1, Options - [frWholeWord]) then
   begin
      Memo.SelText := R;
      Result := 1;
   end;
   MemoFindNext(Memo, S, Options);
end;

initialization
   RegisterClasses([TOpenDialog, TSaveDialog, TSelectDirectoryDialog, TColorDialog,
                    TFindDialog, TReplaceDialog]);
end.
