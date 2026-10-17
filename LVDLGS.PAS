{-----------------------------------------------------------------------------}
{  LVDLGS - LVCode's dialogs: the compiler options (pages Syntax, Code,       }
{  Checks, Directories, Messages and the compiler, with the fpc command line  }
{  shown as it is set up) and the editor options.                             }
{-----------------------------------------------------------------------------}
unit LVDlgs;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, TUICtrl, TUIStd, TUIList, TUIMemo, TUIExt, TUIPages, LVOpts;

type
   TCompilerDialog = class(TForm)
   private
      O: TLVOptions;
      FSource: string;
      Pages: TPageControl;
      ModeGroup, OptGroup: TRadioGroup;
      cAnsi, cCOps, cMacros, cInline, cAssert: TCheckBox;
      cSize, cSmart, cStrip: TCheckBox;
      TargetCombo: TComboBox;
      cRange, cOverflow, cIO, cStack, cDebug, cLineInfo, cHeap: TCheckBox;
      eUnits, eIncludes, eLibs, eObjects, eExeDir, eUnitDir: TEdit;
      eDefines, eExtra, eCompiler: TEdit;
      cWarn, cNotes, cHints, cInfo, cAutoSave: TCheckBox;
      Preview: TMemo;
      FLoading: boolean;
      procedure Changed(Sender: TObject);
      procedure ToOptions(Dest: TLVOptions);
      procedure FromOptions;
      function  Check(P: TWinControl; X, Y: integer; const C: string): TCheckBox;
      function  Field(P: TWinControl; Y: integer; const L: string): TEdit;
   public
      constructor CreateFor(AOwner: TComponent; Opts: TLVOptions; const Source: string);
      property PageControl: TPageControl read Pages;
   end;

{ the compiler options; Page: 0 Syntax ... 3 Directories, 4 Messages (Alt+1 ..  }
{ Alt+5 switch the pages; the letters are for the fields). True: OK          }
function CompilerOptionsDialog(Opts: TLVOptions; const Source: string; Page: integer = 0): boolean;
{ tab width, block indent, WordStar keys, auto indent }
function EditorOptionsDialog(Opts: TLVOptions): boolean;

var
   { the dialog while it is open (tests) }
   LVCompilerDialog: TCompilerDialog = nil;

implementation

function Btn(F: TWinControl; X, Y: integer; const C: string; MR: TModalResult): TButton;
begin
   Result := TButton.Create(F);
   Result.Parent := F;
   Result.SetBounds(X, Y, 12, 2);
   Result.Caption := C;
   Result.ModalResult := MR;
end;

function Lbl(F: TWinControl; X, Y: integer; const C: string): TLabel;
begin
   Result := TLabel.Create(F);
   Result.Parent := F;
   Result.Left := X;
   Result.Top := Y;
   Result.Caption := C;
end;

function TCompilerDialog.Check(P: TWinControl; X, Y: integer; const C: string): TCheckBox;
begin
   Result := TCheckBox.Create(Self);
   Result.Parent := P;
   Result.Left := X;
   Result.Top := Y;
   Result.Caption := C;
   Result.OnChange := @Changed;
end;

function TCompilerDialog.Field(P: TWinControl; Y: integer; const L: string): TEdit;
begin
   Result := TEdit.Create(Self);
   Result.Parent := P;
   Result.SetBounds(22, Y, 46, 1);
   Result.OnChange := @Changed;
   Lbl(P, 1, Y, L).FocusControl := Result;
end;

constructor TCompilerDialog.CreateFor(AOwner: TComponent; Opts: TLVOptions; const Source: string);
var t: TTabSheet;
    i: integer;
    b: TButton;
begin
   CreateNew(AOwner);
   O := Opts;
   FSource := Source;
   if FSource = '' then FSource := 'PROGRAM.PAS';
   Caption := 'Compiler options';
   BorderStyle := bsDialog;
   Position := poScreenCenter;
   SetBounds(0, 0, 74, 22);
   FLoading := true;

   Pages := TPageControl.Create(Self);
   Pages.Parent := Self;
   Pages.SetBounds(1, 0, 70, 13);

   { ---- Syntax }
   t := Pages.AddTabSheet;
   t.Caption := '&1 Syntax';
   ModeGroup := TRadioGroup.Create(Self);
   ModeGroup.Parent := t;
   ModeGroup.SetBounds(1, 0, 30, 9);
   ModeGroup.Caption := 'Compiler &mode (-M)';
   ModeGroup.Items.CommaText := '"Free Pascal (fpc)","Object Pascal (objfpc)",Delphi,' +
                                '"Turbo Pascal (tp)","Mac Pascal","ISO Pascal"';
   ModeGroup.OnClick := @Changed;
   cAnsi := Check(t, 33, 1, '&AnsiStrings ({$H+}, -Sh)');
   cCOps := Check(t, 33, 2, '&C operators += -= (-Sc)');
   cMacros := Check(t, 33, 3, 'Macr&os (-Sm)');
   cInline := Check(t, 33, 4, '&Inline (-Si)');
   cAssert := Check(t, 33, 5, 'Asse&rtions (-Sa)');

   { ---- Code }
   t := Pages.AddTabSheet;
   t.Caption := '&2 Code';
   OptGroup := TRadioGroup.Create(Self);
   OptGroup.Parent := t;
   OptGroup.SetBounds(1, 0, 30, 8);
   OptGroup.Caption := '&Optimization (-O)';
   OptGroup.Items.CommaText := 'None,"Level 1 (-O1)","Level 2 (-O2)","Level 3 (-O3)","Level 4 (-O4)"';
   OptGroup.OnClick := @Changed;
   cSize := Check(t, 33, 1, 'Smaller code (-Os)');
   cSmart := Check(t, 33, 2, 'Smart &linking (-XX -CX)');
   cStrip := Check(t, 33, 3, 'Strip s&ymbols (-Xs)');
   TargetCombo := TComboBox.Create(Self);
   TargetCombo.Parent := t;
   TargetCombo.SetBounds(46, 5, 18, 1);
   TargetCombo.Items.Add('(default)');
   for i := 1 to High(LVTargets) do TargetCombo.Items.Add(LVTargets[i]);
   TargetCombo.OnChange := @Changed;
   TargetCombo.OnSelect := @Changed;
   Lbl(t, 33, 5, '&Target (-T):').FocusControl := TargetCombo;

   { ---- Checks and debugging }
   t := Pages.AddTabSheet;
   t.Caption := '&3 Checks';
   cRange := Check(t, 2, 1, '&Range checks (-Cr)');
   cOverflow := Check(t, 2, 2, '&Overflow checks (-Co)');
   cIO := Check(t, 2, 3, '&I/O checks (-Ci)');
   cStack := Check(t, 2, 4, '&Stack checks (-Ct)');
   cDebug := Check(t, 36, 1, '&Debug information (-g)');
   cLineInfo := Check(t, 36, 2, '&Line info (-gl)');
   cHeap := Check(t, 36, 3, '&Heap trace (-gh)');

   { ---- Directories }
   t := Pages.AddTabSheet;
   t.Caption := '&4 Directories';
   eUnits := Field(t, 1, '&Unit dirs (-Fu):');
   eIncludes := Field(t, 2, '&Include dirs (-Fi):');
   eLibs := Field(t, 3, '&Library dirs (-Fl):');
   eObjects := Field(t, 4, '&Object dirs (-Fo):');
   eExeDir := Field(t, 6, '&EXE output (-FE):');
   eUnitDir := Field(t, 7, 'Unit ou&tput (-FU):');
   Lbl(t, 1, 9, 'Several directories: separate them with ";".');

   { ---- Messages, defines, the compiler }
   t := Pages.AddTabSheet;
   t.Caption := '&5 Messages';
   cWarn := Check(t, 2, 1, '&Warnings');
   cNotes := Check(t, 2, 2, '&Notes');
   cHints := Check(t, 2, 3, '&Hints');
   cInfo := Check(t, 2, 4, '&General info');
   cAutoSave := Check(t, 36, 1, '&Save editor files first');
   eDefines := Field(t, 6, '&Defines (-d):');
   eExtra := Field(t, 7, '&Extra options:');
   eCompiler := Field(t, 9, '&Compiler:');

   Preview := TMemo.Create(Self);
   Preview.Parent := Self;
   Preview.SetBounds(1, 14, 70, 3);
   Preview.ReadOnly := true;
   Preview.TabStop := false;
   Lbl(Self, 1, 13, 'Command line:');

   b := Btn(Self, 44, 17, 'OK', mrOk);
   b.Default := true;
   b := Btn(Self, 58, 17, 'Cancel', mrCancel);
   b.Cancel := true;

   FromOptions;
   FLoading := false;
   Changed(nil);
   ActiveControl := Pages;
end;

procedure TCompilerDialog.FromOptions;
var i: integer;
begin
   ModeGroup.ItemIndex := 1;
   for i := 0 to High(LVModes) do
      if SameText(LVModes[i], O.Mode) then ModeGroup.ItemIndex := i;
   cAnsi.Checked := O.AnsiStrings;
   cCOps.Checked := O.COperators;
   cMacros.Checked := O.Macros;
   cInline.Checked := O.InlineCode;
   cAssert.Checked := O.Assertions;
   OptGroup.ItemIndex := O.OptLevel;
   cSize.Checked := O.OptSize;
   cSmart.Checked := O.SmartLink;
   cStrip.Checked := O.StripSymbols;
   if O.TargetOS = '' then TargetCombo.Text := '(default)' else TargetCombo.Text := O.TargetOS;
   cRange.Checked := O.RangeChecks;
   cOverflow.Checked := O.OverflowChecks;
   cIO.Checked := O.IOChecks;
   cStack.Checked := O.StackChecks;
   cDebug.Checked := O.DebugInfo;
   cLineInfo.Checked := O.LineInfo;
   cHeap.Checked := O.HeapTrace;
   eUnits.Text := O.UnitDirs;
   eIncludes.Text := O.IncludeDirs;
   eLibs.Text := O.LibraryDirs;
   eObjects.Text := O.ObjectDirs;
   eExeDir.Text := O.ExeOutputDir;
   eUnitDir.Text := O.UnitOutputDir;
   cWarn.Checked := O.ShowWarnings;
   cNotes.Checked := O.ShowNotes;
   cHints.Checked := O.ShowHints;
   cInfo.Checked := O.ShowInfo;
   cAutoSave.Checked := O.AutoSave;
   eDefines.Text := O.Defines;
   eExtra.Text := O.ExtraOptions;
   eCompiler.Text := O.CompilerPath;
end;

procedure TCompilerDialog.ToOptions(Dest: TLVOptions);
var t: string;
begin
   if ModeGroup.ItemIndex >= 0 then Dest.Mode := LVModes[ModeGroup.ItemIndex];
   Dest.AnsiStrings := cAnsi.Checked;
   Dest.COperators := cCOps.Checked;
   Dest.Macros := cMacros.Checked;
   Dest.InlineCode := cInline.Checked;
   Dest.Assertions := cAssert.Checked;
   if OptGroup.ItemIndex >= 0 then Dest.OptLevel := OptGroup.ItemIndex;
   Dest.OptSize := cSize.Checked;
   Dest.SmartLink := cSmart.Checked;
   Dest.StripSymbols := cStrip.Checked;
   t := Trim(TargetCombo.Text);
   if (t = '(default)') then t := '';
   Dest.TargetOS := t;
   Dest.RangeChecks := cRange.Checked;
   Dest.OverflowChecks := cOverflow.Checked;
   Dest.IOChecks := cIO.Checked;
   Dest.StackChecks := cStack.Checked;
   Dest.DebugInfo := cDebug.Checked;
   Dest.LineInfo := cLineInfo.Checked;
   Dest.HeapTrace := cHeap.Checked;
   Dest.UnitDirs := eUnits.Text;
   Dest.IncludeDirs := eIncludes.Text;
   Dest.LibraryDirs := eLibs.Text;
   Dest.ObjectDirs := eObjects.Text;
   Dest.ExeOutputDir := eExeDir.Text;
   Dest.UnitOutputDir := eUnitDir.Text;
   Dest.ShowWarnings := cWarn.Checked;
   Dest.ShowNotes := cNotes.Checked;
   Dest.ShowHints := cHints.Checked;
   Dest.ShowInfo := cInfo.Checked;
   Dest.AutoSave := cAutoSave.Checked;
   Dest.Defines := eDefines.Text;
   Dest.ExtraOptions := eExtra.Text;
   if Trim(eCompiler.Text) <> '' then Dest.CompilerPath := Trim(eCompiler.Text);
end;

{ any change: the command line as it would be }
procedure TCompilerDialog.Changed(Sender: TObject);
var tmp: TLVOptions;
begin
   if FLoading or (Preview = nil) then exit;
   tmp := TLVOptions.Create;
   try
      tmp.Assign(O);
      ToOptions(tmp);
      Preview.Text := tmp.CommandLine(ExtractFileName(FSource), bkMake);
   finally
      tmp.Free;
   end;
end;

function CompilerOptionsDialog(Opts: TLVOptions; const Source: string; Page: integer): boolean;
var d: TCompilerDialog;
begin
   d := TCompilerDialog.CreateFor(nil, Opts, Source);
   LVCompilerDialog := d;
   try
      if (Page >= 0) and (Page < d.Pages.PageCount) then d.Pages.ActivePageIndex := Page;
      Result := d.ShowModal = mrOk;
      if Result then d.ToOptions(Opts);
   finally
      LVCompilerDialog := nil;
      d.Free;
   end;
end;

function EditorOptionsDialog(Opts: TLVOptions): boolean;
var f: TForm;
    tw, bi: TSpinEdit;
    ws, ai: TCheckBox;
    b: TButton;
begin
   f := TForm.CreateNew(nil);
   try
      f.Caption := 'Editor options';
      f.BorderStyle := bsDialog;
      f.Position := poScreenCenter;
      f.SetBounds(0, 0, 44, 12);
      tw := TSpinEdit.Create(f);
      tw.Parent := f;
      tw.SetBounds(18, 1, 6, 1);
      tw.MinValue := 1;
      tw.MaxValue := 16;
      tw.Value := Opts.TabWidth;
      Lbl(f, 2, 1, '&Tab width:').FocusControl := tw;
      bi := TSpinEdit.Create(f);
      bi.Parent := f;
      bi.SetBounds(18, 2, 6, 1);
      bi.MinValue := 1;
      bi.MaxValue := 16;
      bi.Value := Opts.BlockIndent;
      Lbl(f, 2, 2, '&Block indent:').FocusControl := bi;
      ws := TCheckBox.Create(f);
      ws.Parent := f;
      ws.SetBounds(2, 4, 36, 1);
      ws.Caption := '&WordStar keys (Ctrl+E S D X ...)';
      ws.Checked := Opts.WordStarKeys;
      ai := TCheckBox.Create(f);
      ai.Parent := f;
      ai.SetBounds(2, 5, 36, 1);
      ai.Caption := '&Auto indent';
      ai.Checked := Opts.AutoIndent;
      b := Btn(f, 15, 7, 'OK', mrOk);
      b.Default := true;
      b := Btn(f, 28, 7, 'Cancel', mrCancel);
      b.Cancel := true;
      f.ActiveControl := tw;
      Result := f.ShowModal = mrOk;
      if Result then
      begin
         Opts.TabWidth := tw.Value;
         Opts.BlockIndent := bi.Value;
         Opts.WordStarKeys := ws.Checked;
         Opts.AutoIndent := ai.Checked;
      end;
   finally
      f.Free;
   end;
end;

end.
