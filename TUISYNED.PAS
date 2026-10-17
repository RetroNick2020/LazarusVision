{-----------------------------------------------------------------------------}
{  TUISYNED - TSynEdit, the code editor control (stage 2 of the editor).      }
{                                                                             }
{  Names follow Lazarus's SynEdit:                                            }
{     Lines, Text, Highlighter, ReadOnly, Modified, InsertMode, TabWidth,     }
{     Options (eoScrollPastEol, eoTabsToSpaces, eoKeepCaretX), Gutter         }
{     (Visible, ShowLineNumbers, Color, TextColor), SelectedColor,            }
{     CaretX / CaretY / CaretXY (1 based), TopLine, LeftChar, LinesInWindow,  }
{     CharsInWindow, BlockBegin / BlockEnd, SelAvail, SelText, SelectAll,     }
{     SelectWord, SelectLine, ClearSelection, CopyToClipboard,                }
{     CutToClipboard, PasteFromClipboard, ClearAll, OnChange, OnStatusChange  }
{                                                                             }
{  No word wrap: long lines scroll sideways. The caret may stand past the     }
{  end of a line, as in the Turbo Pascal and QBasic editors; typing there    }
{  fills the gap with spaces. Tabs in the text become spaces (TabWidth).     }
{  Only the lines on screen are coloured; TSynLineStates keeps the state     }
{  every line starts in, so an edit rescans only what it has to.            }
{                                                                             }
{  Keys: arrows, Home / End, Ctrl+Home / End, PgUp / PgDn, Ctrl+Left /        }
{  Right (words), Ctrl+Up / Down (scroll), Shift+ any of them selects; Enter, }
{  Tab (spaces to the next stop), Backspace, Del, Ins (insert/overwrite),    }
{  Ctrl+Y (delete the line), Ctrl+A, Ctrl+C / X / V, Ctrl+Ins, Shift+Del,    }
{  Shift+Ins. Mouse: click (also past the end of a line), drag, double click }
{  (a word), a click in the gutter (a line), the scroll bars, the wheel.     }
{-----------------------------------------------------------------------------}
unit TUISynEd;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIList, TUISyn;

type
   TSynEdit = class;

   { the lines of the editor: a TStringList that says exactly what changed }
   TSynEditLines = class(TStringList)
   private
      FEditor: TSynEdit;
      FTabWidth: integer;
      FExpandTabs: boolean;
      function Expand(const S: string): string;
   protected
      procedure Put(Index: integer; const S: string); override;
      procedure InsertItem(Index: integer; const S: string; O: TObject); override;
   public
      procedure Delete(Index: integer); override;
      procedure Clear; override;
      procedure Exchange(Index1, Index2: integer); override;
   end;

   TSynEditorOption = (eoScrollPastEol, eoTabsToSpaces, eoKeepCaretX, eoAutoIndent,
                       eoBackspaceUnindents);
   TSynEditorOptions = set of TSynEditorOption;

   TSynUndoKind = (ukInsert, ukDelete);
   { one change: text put in or taken out at (L, C); lines split by #10 }
   TSynUndoItem = record
      Kind: TSynUndoKind;
      L, C: integer;
      Text: string;
      Group: integer;                      { one user action }
      CaretL, CaretC, AnchorL, AnchorC: integer;   { before the action }
   end;

   TSynTyping = (ltNone, ltChar, ltBack, ltDel);

   TSynSearchOption = (ssoMatchCase, ssoWholeWord, ssoBackwards, ssoEntireScope,
                       ssoReplace, ssoReplaceAll);
   TSynSearchOptions = set of TSynSearchOption;

   { a Ctrl+K x / Ctrl+Q x the editor does not know itself (Ctrl+Q F...) }
   TSynPrefixEvent = procedure(Sender: TObject; Prefix, Key: char; var Handled: boolean) of object;

   TSynGutter = class(TPersistent)
   private
      FEditor: TSynEdit;
      FVisible, FShowLineNumbers: boolean;
      FColor, FTextColor: TColor;
      procedure SetVisible(V: boolean);
      procedure SetShowLineNumbers(V: boolean);
      procedure SetColor(V: TColor);
      procedure SetTextColor(V: TColor);
   published
      property Visible: boolean read FVisible write SetVisible default true;
      property ShowLineNumbers: boolean read FShowLineNumbers write SetShowLineNumbers default true;
      property Color: TColor read FColor write SetColor default clNavy;
      property TextColor: TColor read FTextColor write SetTextColor default clCyan;
   end;

   TSynEdit = class(TWinControl)
   private
      FLines: TSynEditLines;
      FStates: TSynLineStates;
      FHighlighter: TSynCustomHighlighter;
      FGutter: TSynGutter;
      FSelColor: THighlightAttr;
      FOptions: TSynEditorOptions;
      FReadOnly, FModified, FInsertMode: boolean;
      FTabWidth: integer;
      FCX, FCY: integer;                  { the caret, 0 based (FCX may pass the end) }
      FAX, FAY: integer;                  { the other end of the selection }
      FTopL, FLeftC: integer;               { the first line / column shown, 0 based }
      FWantX: integer;                    { the column Up / Down aim for }
      FMaxLen: integer;
      FMaxLenOK: boolean;
      FVBar, FHBar: boolean;
      FDragSel, FThumbV, FThumbH: boolean;
      FHoldV, FHoldH: TScrollHit;
      FDragX, FDragY: integer;
      FUpdating: integer;
      FOnChange, FOnStatusChange: TNotifyEvent;
      { undo }
      FUndo, FRedo: array of TSynUndoItem;
      FGroup, FGroupCount, FSaveGroup, FBlockDepth, FMaxUndo: integer;
      FGCaretL, FGCaretC, FGAnchorL, FGAnchorC: integer;
      FUndoing: boolean;
      FInEdit: integer;
      FTyping: TSynTyping;
      FTypeL, FTypeC: integer;
      FLastChar: char;
      FBlockIndent: integer;
      FWordStarKeys: boolean;
      FPrefix: char;
      { the Turbo block (Ctrl+K B / K): stays while the caret moves }
      FBBL, FBBC, FBKL, FBKC: integer;
      FHasB, FHasK: boolean;
      FErrorLine: integer;
      FErrorColor: THighlightAttr;
      FOnPrefixCommand: TSynPrefixEvent;
      procedure SetErrorLine(V: integer);
      procedure SetErrorColor(V: THighlightAttr);
      { the edit operations everything goes through }
      procedure DoInsert(const T: string);
      procedure DoDeleteRange(L1, C1, L2, C2: integer);
      procedure RawInsert(L, C: integer; const T: string);
      procedure RawDelete(L1, C1, L2, C2: integer);
      function  RangeText(L1, C1, L2, C2: integer): string;
      procedure Rec(Kind: TSynUndoKind; L, C: integer; const T: string);
      procedure NewGroup;
      function  TopGroup: integer;
      procedure StartAction;
      procedure EndAction;
      procedure NewLine;
      procedure BackspaceKey;
      procedure DeleteKey;
      procedure DeleteLine;
      procedure DeleteToEol;
      procedure DeleteWordRight;
      procedure BlockLines(out L1, L2: integer);
      procedure ShiftBlock(Right: boolean);
      procedure CopyBlockHere(Move: boolean);
      procedure PrefixCommand(Ch: char);
      function  WordStarKey(Key: Word; Ext: boolean): boolean;
      function  ShiftOf(Ext: boolean): TShiftState;
      function  GetBlock(out L1, C1, L2, C2: integer): boolean;
      procedure ClearMarks;
      function  GetMarkedText: string;
      procedure SetLines(V: TStrings);
      function  GetLines: TStrings;
      function  GetText: string;
      procedure SetText(const V: string);
      procedure SetHighlighter(V: TSynCustomHighlighter);
      procedure HighlighterChanged(Sender: TObject);
      procedure SetOptions(V: TSynEditorOptions);
      procedure SetTabWidth(V: integer);
      procedure SetGutter(V: TSynGutter);
      procedure SetSelColor(V: THighlightAttr);
      procedure SelColorChanged(Sender: TObject);
      function  GetCaretX: integer;
      function  GetCaretY: integer;
      procedure SetCaretX(V: integer);
      procedure SetCaretY(V: integer);
      function  GetCaretXY: TPoint;
      procedure SetCaretXY(const P: TPoint);
      function  GetTopLine: integer;
      procedure SetTopLine(V: integer);
      function  GetLeftChar: integer;
      procedure SetLeftChar(V: integer);
      function  GetBlockBegin: TPoint;
      function  GetBlockEnd: TPoint;
      procedure SetBlockBegin(const P: TPoint);
      procedure SetBlockEnd(const P: TPoint);
      function  GetSelText: string;
      procedure SetSelText(const V: string);
      procedure SetInsertMode(V: boolean);
      procedure SetModified(V: boolean);
      function  LineText(I: integer): string;
      function  GutterWidth: integer;
      procedure Measure;
      function  TextW: integer;
      function  TextH: integer;
      function  MaxTop: integer;
      function  MaxLeft: integer;
      procedure SelBounds(out L1, C1, L2, C2: integer);
      procedure MoveCaret(L, C: integer; Extend: boolean);
      procedure ScrollToCaret;
      procedure StatusChanged;
      procedure TextEdited;
      procedure DoScrollV(H: TScrollHit);
      procedure DoScrollH(H: TScrollHit);
      procedure PosAt(X, Y: integer; out L, C: integer);
      function  IsWordChar(Ch: char): boolean;
   protected
      { from TSynEditLines }
      procedure LineChanged(Index: integer);
      procedure LinesInserted(Index, Count: integer);
      procedure LinesDeleted(Index, Count: integer);
      procedure LinesCleared;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
      procedure Change; virtual;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure DblClick; override;
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
      function  WantsChars: boolean; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      procedure BeginUpdate;
      procedure EndUpdate;
      function  SelAvail: boolean;
      procedure SelectAll;
      procedure SelectWord;
      procedure SelectLine;
      procedure ClearSelection;
      procedure CopyToClipboard;
      procedure CutToClipboard;
      procedure PasteFromClipboard;
      procedure ClearAll;
      { undo / redo: every user action is one step; typing a word at a time }
      procedure Undo;
      procedure Redo;
      function  CanUndo: boolean;
      function  CanRedo: boolean;
      procedure ClearUndo;
      function  UndoCount: integer;
      { several edits made in code as one undo step }
      procedure BeginUndoBlock;
      procedure EndUndoBlock;
      { the lines of the selection (or the caret's line) by BlockIndent }
      procedure IndentBlock;
      procedure UnindentBlock;
      procedure LoadFromFile(const FileName: string);
      procedure SaveToFile(const FileName: string);
      { lines / columns that fit }
      function  LinesInWindow: integer;
      function  CharsInWindow: integer;
      { the start state the highlighter gives line I (0 based); tests }
      function  LineState(I: integer): integer;
      { lines scanned by the highlighter so far (tests, speed checks) }
      function  ScannedLines: longint;
      property CaretXY: TPoint read GetCaretXY write SetCaretXY;
      property BlockBegin: TPoint read GetBlockBegin write SetBlockBegin;
      property BlockEnd: TPoint read GetBlockEnd write SetBlockEnd;
      { the selected text; setting it replaces the selection (or inserts) }
      property SelText: string read GetSelText write SetSelText;
   published
      property Lines: TStrings read GetLines write SetLines;
      property Text: string read GetText write SetText;
      property Highlighter: TSynCustomHighlighter read FHighlighter write SetHighlighter;
      property Gutter: TSynGutter read FGutter write SetGutter;
      { the selection's colours }
      property SelectedColor: THighlightAttr read FSelColor write SetSelColor;
      property Options: TSynEditorOptions read FOptions write SetOptions
         default [eoScrollPastEol, eoTabsToSpaces, eoKeepCaretX, eoAutoIndent, eoBackspaceUnindents];
      property TabWidth: integer read FTabWidth write SetTabWidth default 8;
      { how far Tab / Shift+Tab on a selection (Ctrl+K I / U) move lines }
      property BlockIndent: integer read FBlockIndent write FBlockIndent default 2;
      { Ctrl+E S D X, A F, R C, W Z, G T V N as in WordStar / Turbo Pascal; }
      { off: Ctrl+A C X V Z are select all, copy, cut, paste, undo         }
      property WordStarKeys: boolean read FWordStarKeys write FWordStarKeys default false;
      property MaxUndo: integer read FMaxUndo write FMaxUndo default 1024;
      property ReadOnly: boolean read FReadOnly write FReadOnly default false;
      property Modified: boolean read FModified write SetModified;
      property InsertMode: boolean read FInsertMode write SetInsertMode default true;
      property CaretX: integer read GetCaretX write SetCaretX;
      property CaretY: integer read GetCaretY write SetCaretY;
      property TopLine: integer read GetTopLine write SetTopLine;
      property LeftChar: integer read GetLeftChar write SetLeftChar;
      { a Turbo block marked with Ctrl+K B and Ctrl+K K (it stays while the }
      { caret moves; Ctrl+K C / V / Y / I / U and Ctrl+Q B / K use it)     }
      function  BlockMarked: boolean;
      { the caret to line L, column C (1 based), the line in the middle of }
      { the window if it was off screen                                  }
      procedure GotoLine(L: integer; C: integer = 1);
      { search from the caret (ssoEntireScope: from the start; ssoBackwards: }
      { up); the find is selected. ssoReplace: the find is replaced;        }
      { ssoReplaceAll: every one (one undo step). The number found          }
      function  SearchReplace(const ASearch, AReplace: string; AOptions: TSynSearchOptions): integer;
      property MarkedText: string read GetMarkedText;
      { 'K' or 'Q' after Ctrl+K / Ctrl+Q, waiting for the second key }
      property PendingPrefix: char read FPrefix;
      { a line shown in ErrorColor (1 based, 0: none): a compiler error }
      property ErrorLine: integer read FErrorLine write SetErrorLine;
      property ErrorColor: THighlightAttr read FErrorColor write SetErrorColor;
      property OnPrefixCommand: TSynPrefixEvent read FOnPrefixCommand write FOnPrefixCommand;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
      { the caret, the selection, Modified or InsertMode changed }
      property OnStatusChange: TNotifyEvent read FOnStatusChange write FOnStatusChange;
   end;

implementation

{=============================================================================}
{  TSynEditLines                                                              }
{=============================================================================}

function TSynEditLines.Expand(const S: string): string;
var i, col: integer;
begin
   if not FExpandTabs or (Pos(#9, S) = 0) then exit(S);
   Result := '';
   col := 0;
   for i := 1 to Length(S) do
      if S[i] = #9 then
         repeat
            Result := Result + ' ';
            inc(col);
         until col mod FTabWidth = 0
      else
      begin
         Result := Result + S[i];
         inc(col);
      end;
end;

procedure TSynEditLines.Put(Index: integer; const S: string);
begin
   inherited Put(Index, Expand(S));
   if FEditor <> nil then FEditor.LineChanged(Index);
end;

procedure TSynEditLines.InsertItem(Index: integer; const S: string; O: TObject);
begin
   inherited InsertItem(Index, Expand(S), O);
   if FEditor <> nil then FEditor.LinesInserted(Index, 1);
end;

procedure TSynEditLines.Delete(Index: integer);
begin
   inherited Delete(Index);
   if FEditor <> nil then FEditor.LinesDeleted(Index, 1);
end;

procedure TSynEditLines.Clear;
begin
   inherited Clear;
   if FEditor <> nil then FEditor.LinesCleared;
end;

procedure TSynEditLines.Exchange(Index1, Index2: integer);
begin
   inherited Exchange(Index1, Index2);
   if FEditor <> nil then
   begin
      FEditor.LineChanged(Index1);
      FEditor.LineChanged(Index2);
   end;
end;

{=============================================================================}
{  TSynGutter                                                                 }
{=============================================================================}

procedure TSynGutter.SetVisible(V: boolean);
begin
   FVisible := V;
   if FEditor <> nil then FEditor.Invalidate;
end;

procedure TSynGutter.SetShowLineNumbers(V: boolean);
begin
   FShowLineNumbers := V;
   if FEditor <> nil then FEditor.Invalidate;
end;

procedure TSynGutter.SetColor(V: TColor);
begin
   FColor := V;
   if FEditor <> nil then FEditor.Invalidate;
end;

procedure TSynGutter.SetTextColor(V: TColor);
begin
   FTextColor := V;
   if FEditor <> nil then FEditor.Invalidate;
end;

{=============================================================================}
{  TSynEdit                                                                   }
{=============================================================================}

constructor TSynEdit.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FTabWidth := 8;
   FOptions := [eoScrollPastEol, eoTabsToSpaces, eoKeepCaretX, eoAutoIndent, eoBackspaceUnindents];
   FBlockIndent := 2;
   FMaxUndo := 1024;
   FLines := TSynEditLines.Create;
   FLines.FTabWidth := FTabWidth;
   FLines.FExpandTabs := true;
   FLines.FEditor := Self;
   FStates := TSynLineStates.Create(FLines, nil);
   FGutter := TSynGutter.Create;
   FGutter.FEditor := Self;
   FGutter.FVisible := true;
   FGutter.FShowLineNumbers := true;
   FGutter.FColor := clNavy;
   FGutter.FTextColor := clCyan;
   FSelColor := THighlightAttr.Create('selection', clBlack);
   FSelColor.Background := clLightGray;
   FSelColor.OnChange := @SelColorChanged;
   FErrorColor := THighlightAttr.Create('error', clWhite);
   FErrorColor.Background := clMaroon;
   FErrorColor.OnChange := @SelColorChanged;
   FInsertMode := true;
   Color := clNavy;               { dark blue, as the Turbo Pascal / QBasic editors }
   Font.Color := clYellow;
   FWidth := 60;
   FHeight := 15;
end;

destructor TSynEdit.Destroy;
begin
   SetHighlighter(nil);
   FLines.FEditor := nil;
   FreeAndNil(FStates);
   FreeAndNil(FLines);
   FreeAndNil(FGutter);
   FreeAndNil(FSelColor);
   FreeAndNil(FErrorColor);
   inherited Destroy;
end;

procedure TSynEdit.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FHighlighter) then
   begin
      FHighlighter := nil;
      if FStates <> nil then FStates.Highlighter := nil;
      Invalidate;
   end;
end;

function TSynEdit.GetLines: TStrings;
begin
   Result := FLines;
end;

procedure TSynEdit.SetLines(V: TStrings);
begin
   FLines.Assign(V);
end;

function TSynEdit.GetText: string;
begin
   Result := FLines.Text;
end;

procedure TSynEdit.SetText(const V: string);
begin
   FLines.Text := V;
   FCX := 0; FCY := 0; FAX := 0; FAY := 0; FTopL := 0; FLeftC := 0; FWantX := 0;
   Invalidate;
   StatusChanged;
end;

procedure TSynEdit.ClearAll;
begin
   SetText('');
end;

procedure TSynEdit.LoadFromFile(const FileName: string);
begin
   FLines.LoadFromFile(FileName);
   FCX := 0; FCY := 0; FAX := 0; FAY := 0; FTopL := 0; FLeftC := 0; FWantX := 0;
   FModified := false;
   Invalidate;
   StatusChanged;
end;

procedure TSynEdit.SaveToFile(const FileName: string);
begin
   FLines.SaveToFile(FileName);
   SetModified(false);
end;

procedure TSynEdit.SetHighlighter(V: TSynCustomHighlighter);
begin
   if V = FHighlighter then exit;
   if FHighlighter <> nil then
   begin
      FHighlighter.UnhookChange(@HighlighterChanged);
      FHighlighter.RemoveFreeNotification(Self);
   end;
   FHighlighter := V;
   if V <> nil then
   begin
      V.FreeNotification(Self);
      V.HookChange(@HighlighterChanged);
   end;
   if FStates <> nil then FStates.Highlighter := V;
   Invalidate;
end;

procedure TSynEdit.HighlighterChanged(Sender: TObject);
begin
   Invalidate;
end;

procedure TSynEdit.SetOptions(V: TSynEditorOptions);
begin
   FOptions := V;
   FLines.FExpandTabs := eoTabsToSpaces in V;
   if not (eoScrollPastEol in V) then MoveCaret(FCY, FCX, false);
   Invalidate;
end;

procedure TSynEdit.SetTabWidth(V: integer);
begin
   if V < 1 then V := 1;
   if V > 16 then V := 16;
   FTabWidth := V;
   FLines.FTabWidth := V;
end;

procedure TSynEdit.SetGutter(V: TSynGutter);
begin
   FGutter.Assign(V);
end;

procedure TSynEdit.SetSelColor(V: THighlightAttr);
begin
   FSelColor.Assign(V);
end;

procedure TSynEdit.SelColorChanged(Sender: TObject);
begin
   Invalidate;
end;

procedure TSynEdit.SetInsertMode(V: boolean);
begin
   if V = FInsertMode then exit;
   FInsertMode := V;
   StatusChanged;
end;

procedure TSynEdit.SetModified(V: boolean);
begin
   { not modified: undoing back to here makes it unmodified again }
   if not V then FSaveGroup := TopGroup;
   if V = FModified then exit;
   FModified := V;
   StatusChanged;
end;

procedure TSynEdit.BeginUpdate;
begin
   inc(FUpdating);
end;

procedure TSynEdit.EndUpdate;
begin
   if FUpdating > 0 then dec(FUpdating);
   if FUpdating = 0 then
   begin
      TextEdited;
      StatusChanged;
   end;
end;

procedure TSynEdit.Change;
begin
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TSynEdit.StatusChanged;
begin
   if (FUpdating = 0) and Assigned(FOnStatusChange) then FOnStatusChange(Self);
end;

procedure TSynEdit.TextEdited;
begin
   FMaxLenOK := false;
   Invalidate;
   if FUpdating = 0 then Change;
end;

{ ---- the lines tell what changed ---- }

procedure TSynEdit.LineChanged(Index: integer);
begin
   if FInEdit = 0 then
   begin
      ClearUndo;
      FModified := true;               { changed from code: still a change }
   end;       { changed from outside: the history no longer fits }
   FStates.LineChanged(Index);
   TextEdited;
end;

procedure TSynEdit.LinesInserted(Index, Count: integer);
begin
   if FInEdit = 0 then
   begin
      ClearUndo;
      FModified := true;               { changed from code: still a change }
   end;
   FStates.LinesInserted(Index, Count);
   TextEdited;
end;

procedure TSynEdit.LinesDeleted(Index, Count: integer);
begin
   if FInEdit = 0 then
   begin
      ClearUndo;
      FModified := true;               { changed from code: still a change }
   end;
   FStates.LinesDeleted(Index, Count);
   TextEdited;
end;

procedure TSynEdit.LinesCleared;
begin
   FHasB := false;
   FHasK := false;
   if FInEdit = 0 then ClearUndo;
   FStates.Reset;
   TextEdited;
end;

function TSynEdit.LineState(I: integer): integer;
begin
   Result := FStates.StartState(I);
end;

function TSynEdit.ScannedLines: longint;
begin
   Result := FStates.Scanned;
end;

{ ---- geometry ---- }

function TSynEdit.LineText(I: integer): string;
begin
   if (I >= 0) and (I < FLines.Count) then Result := FLines[I] else Result := '';
end;

function TSynEdit.GutterWidth: integer;
var n: integer;
begin
   if not FGutter.FVisible then exit(0);
   if not FGutter.FShowLineNumbers then exit(2);
   n := Length(IntToStr(FLines.Count + 1));
   if n < 3 then n := 3;
   Result := n + 2;                        { ' ' digits separator }
end;

procedure TSynEdit.Measure;
var i, n: integer;
begin
   if not FMaxLenOK then
   begin
      FMaxLen := 0;
      for i := 0 to FLines.Count - 1 do
      begin
         n := Length(FLines[i]);
         if n > FMaxLen then FMaxLen := n;
      end;
      FMaxLenOK := true;
   end;
   FVBar := (FLines.Count > Height) and (Width >= 2) and (Height >= 2);
   FHBar := (FMaxLen + 1 > Width - GutterWidth - ord(FVBar)) and (Width >= 2) and (Height >= 2);
   if FHBar and not FVBar then FVBar := (FLines.Count > Height - 1) and (Width >= 2);
end;

function TSynEdit.TextW: integer;
begin
   Result := Width - GutterWidth - ord(FVBar);
   if Result < 1 then Result := 1;
end;

function TSynEdit.TextH: integer;
begin
   Result := Height - ord(FHBar);
   if Result < 1 then Result := 1;
end;

function TSynEdit.LinesInWindow: integer;
begin
   Measure;
   Result := TextH;
end;

function TSynEdit.CharsInWindow: integer;
begin
   Measure;
   Result := TextW;
end;

function TSynEdit.MaxTop: integer;
begin
   Result := FLines.Count - TextH;
   if Result < 0 then Result := 0;
end;

function TSynEdit.MaxLeft: integer;
begin
   Result := FMaxLen + 1 - TextW;
   if eoScrollPastEol in FOptions then
      if FCX + 1 - TextW > Result then Result := FCX + 1 - TextW;
   if Result < 0 then Result := 0;
end;

procedure TSynEdit.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   ScrollToCaret;
end;

{ ---- caret and selection ---- }

function TSynEdit.GetCaretX: integer;
begin
   Result := FCX + 1;
end;

function TSynEdit.GetCaretY: integer;
begin
   Result := FCY + 1;
end;

procedure TSynEdit.SetCaretX(V: integer);
begin
   MoveCaret(FCY, V - 1, false);
end;

procedure TSynEdit.SetCaretY(V: integer);
begin
   MoveCaret(V - 1, FCX, false);
end;

function TSynEdit.GetCaretXY: TPoint;
begin
   Result := Point(FCX + 1, FCY + 1);
end;

procedure TSynEdit.SetCaretXY(const P: TPoint);
begin
   MoveCaret(P.Y - 1, P.X - 1, false);
end;

function TSynEdit.GetTopLine: integer;
begin
   Result := FTopL + 1;
end;

procedure TSynEdit.SetTopLine(V: integer);
begin
   Measure;
   FTopL := V - 1;
   if FTopL > MaxTop then FTopL := MaxTop;
   if FTopL < 0 then FTopL := 0;
   Invalidate;
end;

function TSynEdit.GetLeftChar: integer;
begin
   Result := FLeftC + 1;
end;

procedure TSynEdit.SetLeftChar(V: integer);
begin
   Measure;
   FLeftC := V - 1;
   if FLeftC > MaxLeft then FLeftC := MaxLeft;
   if FLeftC < 0 then FLeftC := 0;
   Invalidate;
end;

function TSynEdit.SelAvail: boolean;
begin
   Result := (FAX <> FCX) or (FAY <> FCY);
end;

{ the selection in order, the columns clamped to the text }
procedure TSynEdit.SelBounds(out L1, C1, L2, C2: integer);
begin
   if (FAY < FCY) or ((FAY = FCY) and (FAX <= FCX)) then
   begin
      L1 := FAY; C1 := FAX; L2 := FCY; C2 := FCX;
   end
   else
   begin
      L1 := FCY; C1 := FCX; L2 := FAY; C2 := FAX;
   end;
end;

function TSynEdit.GetBlockBegin: TPoint;
var l1, c1, l2, c2: integer;
begin
   SelBounds(l1, c1, l2, c2);
   Result := Point(c1 + 1, l1 + 1);
end;

function TSynEdit.GetBlockEnd: TPoint;
var l1, c1, l2, c2: integer;
begin
   SelBounds(l1, c1, l2, c2);
   Result := Point(c2 + 1, l2 + 1);
end;

procedure TSynEdit.SetBlockBegin(const P: TPoint);
begin
   FAX := P.X - 1;
   FAY := P.Y - 1;
   if FAY < 0 then FAY := 0;
   if FAX < 0 then FAX := 0;
   Invalidate;
   StatusChanged;
end;

procedure TSynEdit.SetBlockEnd(const P: TPoint);
begin
   MoveCaret(P.Y - 1, P.X - 1, true);
end;

procedure TSynEdit.MoveCaret(L, C: integer; Extend: boolean);
begin
   if L >= FLines.Count then L := FLines.Count - 1;
   if L < 0 then L := 0;
   if C < 0 then C := 0;
   if not (eoScrollPastEol in FOptions) and (C > Length(LineText(L))) then C := Length(LineText(L));
   if C > 1023 then C := 1023;
   FCY := L;
   FCX := C;
   if not Extend then
   begin
      FAX := FCX;
      FAY := FCY;
   end;
   FTyping := ltNone;
   ScrollToCaret;
   Invalidate;
   StatusChanged;
end;

procedure TSynEdit.ScrollToCaret;
begin
   if FLines = nil then exit;
   Measure;
   if FCY < FTopL then FTopL := FCY;
   if FCY >= FTopL + TextH then FTopL := FCY - TextH + 1;
   if FCX < FLeftC then FLeftC := FCX;
   if FCX >= FLeftC + TextW then FLeftC := FCX - TextW + 1;
   if FTopL < 0 then FTopL := 0;
   if FLeftC < 0 then FLeftC := 0;
end;

function TSynEdit.GetSelText: string;
var l1, c1, l2, c2, i: integer;
begin
   Result := '';
   if not SelAvail then exit;
   SelBounds(l1, c1, l2, c2);
   if l1 = l2 then exit(Copy(LineText(l1), c1 + 1, c2 - c1));
   Result := Copy(LineText(l1), c1 + 1, MaxInt);
   for i := l1 + 1 to l2 - 1 do Result := Result + LineEnding + LineText(i);
   Result := Result + LineEnding + Copy(LineText(l2), 1, c2);
end;

procedure TSynEdit.SelectAll;
begin
   if FLines.Count = 0 then exit;
   FAY := 0;
   FAX := 0;
   FCY := FLines.Count - 1;
   FCX := Length(LineText(FCY));
   ScrollToCaret;
   Invalidate;
   StatusChanged;
end;

function TSynEdit.IsWordChar(Ch: char): boolean;
begin
   Result := Ch in ['A'..'Z', 'a'..'z', '0'..'9', '_', '$', '%', '&', '!', '#'];
end;

procedure TSynEdit.SelectWord;
var s: string;
    a, b: integer;
begin
   s := LineText(FCY);
   a := FCX;
   if a > Length(s) then exit;
   b := a;
   while (a > 0) and IsWordChar(s[a]) do dec(a);
   while (b < Length(s)) and IsWordChar(s[b + 1]) do inc(b);
   FAY := FCY;
   FAX := a;
   FCX := b;
   ScrollToCaret;
   Invalidate;
   StatusChanged;
end;

procedure TSynEdit.SelectLine;
begin
   FAY := FCY;
   FAX := 0;
   if FCY < FLines.Count - 1 then
   begin
      FCY := FCY + 1;
      FCX := 0;
   end
   else FCX := Length(LineText(FCY));
   ScrollToCaret;
   Invalidate;
   StatusChanged;
end;

{ ---- the undo list ---- }

procedure TSynEdit.ClearUndo;
begin
   SetLength(FUndo, 0);
   SetLength(FRedo, 0);
   FSaveGroup := 0;
   FTyping := ltNone;
end;

function TSynEdit.CanUndo: boolean;
begin
   Result := (Length(FUndo) > 0) and not FReadOnly;
end;

function TSynEdit.CanRedo: boolean;
begin
   Result := (Length(FRedo) > 0) and not FReadOnly;
end;

function TSynEdit.UndoCount: integer;
var i, g: integer;
begin
   Result := 0;
   g := -1;
   for i := 0 to High(FUndo) do
      if FUndo[i].Group <> g then
      begin
         inc(Result);
         g := FUndo[i].Group;
      end;
end;

function TSynEdit.TopGroup: integer;
begin
   if Length(FUndo) = 0 then Result := 0 else Result := FUndo[High(FUndo)].Group;
end;

{ every user action is one group: one Undo takes all of it back }
procedure TSynEdit.NewGroup;
begin
   inc(FGroupCount);
   FGroup := FGroupCount;
   { where the caret was before the action: Undo puts it back there }
   FGCaretL := FCY; FGCaretC := FCX;
   FGAnchorL := FAY; FGAnchorC := FAX;
end;

procedure TSynEdit.BeginUndoBlock;
begin
   if FBlockDepth = 0 then NewGroup;
   inc(FBlockDepth);
end;

procedure TSynEdit.EndUndoBlock;
begin
   if FBlockDepth > 0 then dec(FBlockDepth);
end;

procedure TSynEdit.Rec(Kind: TSynUndoKind; L, C: integer; const T: string);
var n, i, drop: integer;
begin
   if FUndoing then exit;
   SetLength(FRedo, 0);
   if FGroup = 0 then NewGroup;
   n := Length(FUndo);
   SetLength(FUndo, n + 1);
   FUndo[n].Kind := Kind;
   FUndo[n].L := L;
   FUndo[n].C := C;
   FUndo[n].Text := T;
   FUndo[n].Group := FGroup;
   FUndo[n].CaretL := FGCaretL;
   FUndo[n].CaretC := FGCaretC;
   FUndo[n].AnchorL := FGAnchorL;
   FUndo[n].AnchorC := FGAnchorC;
   { too many: the oldest groups go }
   if Length(FUndo) > FMaxUndo then
   begin
      drop := 0;
      while (drop < Length(FUndo) - 1) and (FUndo[drop].Group = FUndo[0].Group) do inc(drop);
      for i := drop to High(FUndo) do FUndo[i - drop] := FUndo[i];
      SetLength(FUndo, Length(FUndo) - drop);
   end;
end;

{ where text T ends when it starts at (L, C) }
procedure EndOf(L, C: integer; const T: string; out L2, C2: integer);
var i, last: integer;
begin
   L2 := L;
   last := 0;
   for i := 1 to Length(T) do
      if T[i] = #10 then
      begin
         inc(L2);
         last := i;
      end;
   if L2 = L then C2 := C + Length(T) else C2 := Length(T) - last;
end;

{ ---- the two raw edits (no undo, no selection, no padding) ---- }

{ insert T (lines split by #10) at (L, C); C is inside the line; the caret }
{ ends after it                                                            }
procedure TSynEdit.RawInsert(L, C: integer; const T: string);
var s, head, tail, part: string;
    p, q, n: integer;
begin
   inc(FInEdit);
   try
      if FLines.Count = 0 then FLines.Add('');
      if L >= FLines.Count then L := FLines.Count - 1;
      s := FLines[L];
      if C > Length(s) then C := Length(s);
      head := Copy(s, 1, C);
      tail := Copy(s, C + 1, MaxInt);
      p := Pos(#10, T);
      if p = 0 then
      begin
         FLines[L] := head + T + tail;
         FCY := L;
         FCX := C + Length(T);
      end
      else
      begin
         FLines[L] := head + Copy(T, 1, p - 1);
         n := L;
         repeat
            q := p + 1;
            p := q;
            while (p <= Length(T)) and (T[p] <> #10) do inc(p);
            part := Copy(T, q, p - q);
            inc(n);
            if p > Length(T) then
            begin
               FLines.Insert(n, part + tail);
               FCX := Length(part);
            end
            else FLines.Insert(n, part);
         until p > Length(T);
         FCY := n;
      end;
      FAX := FCX;
      FAY := FCY;
      FModified := true;
   finally
      dec(FInEdit);
   end;
end;

{ the text from (L1, C1) to (L2, C2), lines joined by #10 }
function TSynEdit.RangeText(L1, C1, L2, C2: integer): string;
var i: integer;
begin
   if L1 = L2 then exit(Copy(LineText(L1), C1 + 1, C2 - C1));
   Result := Copy(LineText(L1), C1 + 1, MaxInt);
   for i := L1 + 1 to L2 - 1 do Result := Result + #10 + LineText(i);
   Result := Result + #10 + Copy(LineText(L2), 1, C2);
end;

procedure TSynEdit.RawDelete(L1, C1, L2, C2: integer);
var a, b: string;
    i: integer;
begin
   if FLines.Count = 0 then exit;
   inc(FInEdit);
   try
      a := LineText(L1);
      b := LineText(L2);
      FLines[L1] := Copy(a, 1, C1) + Copy(b, C2 + 1, MaxInt);
      for i := L2 downto L1 + 1 do FLines.Delete(i);
      FCY := L1; FCX := C1; FAY := L1; FAX := C1;
      FModified := true;
   finally
      dec(FInEdit);
   end;
end;

{ ---- the recorded edits everything goes through ---- }

{ delete from (L1, C1) to (L2, C2), in order; columns past the end count as }
{ the end                                                                   }
procedure TSynEdit.DoDeleteRange(L1, C1, L2, C2: integer);
var t: string;
begin
   if FLines.Count = 0 then exit;
   if C1 > Length(LineText(L1)) then C1 := Length(LineText(L1));
   if C2 > Length(LineText(L2)) then C2 := Length(LineText(L2));
   if (L1 = L2) and (C1 >= C2) then exit;
   t := RangeText(L1, C1, L2, C2);
   Rec(ukDelete, L1, C1, t);
   RawDelete(L1, C1, L2, C2);
end;

{ the selection (if any) goes, then T goes in at the caret; a caret past the }
{ end of its line first gets the gap filled with spaces                      }
procedure TSynEdit.DoInsert(const T: string);
var l1, c1, l2, c2: integer;
    s, u: string;
begin
   if SelAvail then
   begin
      SelBounds(l1, c1, l2, c2);
      DoDeleteRange(l1, c1, l2, c2);
      FCY := l1; FCX := c1; FAY := l1; FAX := c1;
   end;
   if T = '' then exit;
   { one kind of line break inside: #10 }
   u := StringReplace(T, #13#10, #10, [rfReplaceAll]);
   u := StringReplace(u, #13, #10, [rfReplaceAll]);
   if FLines.Count = 0 then
   begin
      inc(FInEdit);
      FLines.Add('');
      dec(FInEdit);
   end;
   if FCY >= FLines.Count then FCY := FLines.Count - 1;
   s := LineText(FCY);
   if FCX > Length(s) then
   begin
      u := StringOfChar(' ', FCX - Length(s)) + u;
      FCX := Length(s);
   end;
   Rec(ukInsert, FCY, FCX, u);
   RawInsert(FCY, FCX, u);
end;

{ ---- undo, redo ---- }

procedure TSynEdit.Undo;
var first, i, g, l2, c2: integer;
    blk: array of TSynUndoItem;
begin
   if not CanUndo then exit;
   ClearMarks;
   g := FUndo[High(FUndo)].Group;
   first := High(FUndo);
   while (first > 0) and (FUndo[first - 1].Group = g) do dec(first);
   SetLength(blk, Length(FUndo) - first);
   for i := first to High(FUndo) do blk[i - first] := FUndo[i];
   SetLength(FUndo, first);
   FUndoing := true;
   BeginUpdate;
   try
      for i := High(blk) downto 0 do
         with blk[i] do
            if Kind = ukInsert then
            begin
               EndOf(L, C, Text, l2, c2);
               RawDelete(L, C, l2, c2);
            end
            else RawInsert(L, C, Text);
      { the caret and the selection as they were before the action }
      FCY := blk[0].CaretL; FCX := blk[0].CaretC;
      FAY := blk[0].AnchorL; FAX := blk[0].AnchorC;
   finally
      FUndoing := false;
      FModified := TopGroup <> FSaveGroup;
      EndUpdate;
   end;
   { the block goes on the redo list as it was }
   i := Length(FRedo);
   SetLength(FRedo, i + Length(blk));
   for first := 0 to High(blk) do FRedo[i + first] := blk[first];
   FTyping := ltNone;
   FGroup := 0;
   ScrollToCaret;
   StatusChanged;
end;

procedure TSynEdit.Redo;
var first, i, g, l2, c2: integer;
    blk: array of TSynUndoItem;
begin
   if not CanRedo then exit;
   ClearMarks;
   g := FRedo[High(FRedo)].Group;
   first := High(FRedo);
   while (first > 0) and (FRedo[first - 1].Group = g) do dec(first);
   SetLength(blk, Length(FRedo) - first);
   for i := first to High(FRedo) do blk[i - first] := FRedo[i];
   SetLength(FRedo, first);
   FUndoing := true;
   BeginUpdate;
   try
      for i := 0 to High(blk) do
         with blk[i] do
            if Kind = ukInsert then RawInsert(L, C, Text)
            else
            begin
               EndOf(L, C, Text, l2, c2);
               RawDelete(L, C, l2, c2);
            end;
   finally
      FUndoing := false;
      EndUpdate;
   end;
   i := Length(FUndo);
   SetLength(FUndo, i + Length(blk));
   for first := 0 to High(blk) do FUndo[i + first] := blk[first];
   FModified := TopGroup <> FSaveGroup;
   FTyping := ltNone;
   FGroup := 0;
   ScrollToCaret;
   StatusChanged;
end;

{ ---- user actions: one undo group each ---- }

procedure TSynEdit.StartAction;
begin
   if FBlockDepth = 0 then NewGroup;
   FTyping := ltNone;
   BeginUpdate;
end;

procedure TSynEdit.EndAction;
begin
   EndUpdate;
   ScrollToCaret;
   FWantX := FCX;
end;

procedure TSynEdit.ClearSelection;
var l1, c1, l2, c2: integer;
begin
   if FReadOnly or not SelAvail then exit;
   StartAction;
   try
      SelBounds(l1, c1, l2, c2);
      DoDeleteRange(l1, c1, l2, c2);
   finally
      EndAction;
   end;
end;

procedure TSynEdit.SetSelText(const V: string);
begin
   StartAction;
   try
      DoInsert(V);
   finally
      EndAction;
   end;
end;

procedure TSynEdit.CopyToClipboard;
begin
   if SelAvail then Clipboard.AsText := GetSelText;
end;

procedure TSynEdit.CutToClipboard;
begin
   if FReadOnly or not SelAvail then exit;
   CopyToClipboard;
   ClearSelection;
end;

procedure TSynEdit.PasteFromClipboard;
begin
   if FReadOnly or not Clipboard.HasText then exit;
   ClearMarks;
   SetSelText(Clipboard.AsText);
end;

{ the leading blanks of a line }
function Indent(const S: string): integer;
begin
   Result := 0;
   while (Result < Length(S)) and (S[Result + 1] = ' ') do inc(Result);
   if Result = Length(S) then Result := Length(S);
end;

function IsBlank(const S: string): boolean;
begin
   Result := Trim(S) = '';
end;

{ Enter: a new line, indented like this one (eoAutoIndent) }
procedure TSynEdit.NewLine;
var s: string;
    n, i: integer;
begin
   if FReadOnly then exit;
   ClearMarks;
   StartAction;
   try
      n := 0;
      if eoAutoIndent in FOptions then
      begin
         { the indent of this line, or of the line above when it is blank }
         i := FCY;
         s := LineText(i);
         while (i > 0) and IsBlank(s) do
         begin
            dec(i);
            s := LineText(i);
         end;
         if not IsBlank(s) then n := Indent(s);
         if (i = FCY) and (FCX < n) then n := FCX;
      end;
      { the blanks after the caret are not carried to the new line }
      s := LineText(FCY);
      if not SelAvail and (FCX < Length(s)) then
      begin
         i := FCX;
         while (i < Length(s)) and (s[i + 1] = ' ') do inc(i);
         if i > FCX then DoDeleteRange(FCY, FCX, FCY, i);
      end;
      DoInsert(#10 + StringOfChar(' ', n));
   finally
      EndAction;
   end;
end;

{ Backspace; in the leading blanks it goes back to the indent of a line }
{ above (eoBackspaceUnindents)                                          }
procedure TSynEdit.BackspaceKey;
var s: string;
    target, i: integer;
begin
   if FReadOnly then exit;
   ClearMarks;
   if SelAvail then
   begin
      ClearSelection;
      exit;
   end;
   s := LineText(FCY);
   if FCX > Length(s) then
   begin
      { in the space past the end: just move }
      MoveCaret(FCY, FCX - 1, false);
      FWantX := FCX;
      exit;
   end;
   if FTyping <> ltBack then StartAction else BeginUpdate;
   try
      if (FCX > 0) and (eoBackspaceUnindents in FOptions) and IsBlank(Copy(s, 1, FCX)) then
      begin
         target := 0;
         i := FCY - 1;
         while i >= 0 do
         begin
            if not IsBlank(LineText(i)) and (Indent(LineText(i)) < FCX) then
            begin
               target := Indent(LineText(i));
               break;
            end;
            dec(i);
         end;
         DoDeleteRange(FCY, target, FCY, FCX);
      end
      else if FCX > 0 then DoDeleteRange(FCY, FCX - 1, FCY, FCX)
      else if FCY > 0 then DoDeleteRange(FCY - 1, Length(LineText(FCY - 1)), FCY, 0);
   finally
      EndAction;
   end;
   FTyping := ltBack;
end;

procedure TSynEdit.DeleteKey;
var s: string;
begin
   if FReadOnly then exit;
   ClearMarks;
   if SelAvail then
   begin
      ClearSelection;
      exit;
   end;
   s := LineText(FCY);
   if FTyping <> ltDel then StartAction else BeginUpdate;
   try
      if FCX < Length(s) then DoDeleteRange(FCY, FCX, FCY, FCX + 1)
      else if FCY < FLines.Count - 1 then
      begin
         { join the next line; a caret past the end pads first }
         if FCX > Length(s) then
         begin
            Rec(ukInsert, FCY, Length(s), StringOfChar(' ', FCX - Length(s)));
            RawInsert(FCY, Length(s), StringOfChar(' ', FCX - Length(s)));
         end;
         DoDeleteRange(FCY, FCX, FCY + 1, 0);
      end;
   finally
      EndAction;
   end;
   FTyping := ltDel;
end;

{ the lines of the selection (or the caret's line) }
procedure TSynEdit.BlockLines(out L1, L2: integer);
var c1, c2: integer;
begin
   if GetBlock(L1, c1, L2, c2) then
   begin
      { a selection that ends at the start of a line leaves that line out }
      if (L2 > L1) and (c2 = 0) then dec(L2);
   end
   else
   begin
      L1 := FCY;
      L2 := FCY;
   end;
end;

{ Tab on a selection, Ctrl+K I: the lines move right by BlockIndent; }
{ Shift+Tab, Ctrl+K U: left. The selection moves with the text.     }
procedure TSynEdit.ShiftBlock(Right: boolean);
var l1, l2, i, n: integer;
    amount: array of integer;
    ax, ay, cx, cy: integer;

   procedure Adjust(L: integer; var C: integer);
   begin
      if (L < l1) or (L > l2) then exit;
      if Right then
      begin
         if (C > 0) and (amount[L - l1] > 0) then inc(C, amount[L - l1]);
      end
      else
      begin
         dec(C, amount[L - l1]);
         if C < 0 then C := 0;
      end;
   end;

begin
   if FReadOnly then exit;
   BlockLines(l1, l2);
   SetLength(amount, l2 - l1 + 1);
   ax := FAX; ay := FAY; cx := FCX; cy := FCY;
   StartAction;
   try
      for i := l1 to l2 do
      begin
         amount[i - l1] := 0;
         if Right then
         begin
            if IsBlank(LineText(i)) then continue;
            amount[i - l1] := FBlockIndent;
            Rec(ukInsert, i, 0, StringOfChar(' ', FBlockIndent));
            RawInsert(i, 0, StringOfChar(' ', FBlockIndent));
         end
         else
         begin
            n := Indent(LineText(i));
            if n > FBlockIndent then n := FBlockIndent;
            if n = 0 then continue;
            amount[i - l1] := n;
            DoDeleteRange(i, 0, i, n);
         end;
      end;
   finally
      Adjust(ay, ax);
      Adjust(cy, cx);
      FAY := ay; FAX := ax; FCY := cy; FCX := cx;
      EndAction;
   end;
end;

procedure TSynEdit.IndentBlock;
begin
   ShiftBlock(true);
end;

procedure TSynEdit.UnindentBlock;
begin
   ShiftBlock(false);
end;

{ Ctrl+K C: a copy of the selection at the caret; Ctrl+K V: move it there }
procedure TSynEdit.CopyBlockHere(Move: boolean);
var tx: string;
    l1, c1, l2, c2, cl, cc, el, ec: integer;
begin
   if FReadOnly or not GetBlock(l1, c1, l2, c2) then exit;
   cl := FCY; cc := FCX;
   { the caret inside the block: nothing to do }
   if ((cl > l1) or ((cl = l1) and (cc >= c1))) and ((cl < l2) or ((cl = l2) and (cc <= c2))) then exit;
   tx := RangeText(l1, c1, l2, c2);
   StartAction;
   try
      if Move then
      begin
         FAY := FCY; FAX := FCX;
         DoDeleteRange(l1, c1, l2, c2);
         { a caret after the block moves up / left with the text }
         if (cl > l2) or ((cl = l2) and (cc > c2)) then
         begin
            if cl = l2 then
            begin
               cc := c1 + (cc - c2);
               cl := l1;
            end
            else dec(cl, l2 - l1);
         end;
      end;
      FCY := cl; FCX := cc; FAY := cl; FAX := cc;
      DoInsert(tx);
      { the copy is the block now; the caret stays at its start }
      if cc > Length(LineText(cl)) then cc := Length(LineText(cl));
      EndOf(cl, cc, tx, el, ec);
      FBBL := cl; FBBC := cc; FBKL := el; FBKC := ec;
      FHasB := true; FHasK := true;
      FCY := cl; FCX := cc; FAY := cl; FAX := cc;
   finally
      EndAction;
   end;
end;

procedure TSynEdit.DeleteLine;
begin
   if FReadOnly or (FLines.Count = 0) then exit;
   ClearMarks;
   StartAction;
   try
      if FCY < FLines.Count - 1 then DoDeleteRange(FCY, 0, FCY + 1, 0)
      else if FCY > 0 then DoDeleteRange(FCY - 1, Length(LineText(FCY - 1)), FCY, Length(LineText(FCY)))
      else DoDeleteRange(0, 0, 0, Length(LineText(0)));
   finally
      EndAction;
   end;
   MoveCaret(FCY, FWantX, false);
end;

procedure TSynEdit.DeleteToEol;
begin
   if FReadOnly or (FCX >= Length(LineText(FCY))) then exit;
   StartAction;
   try
      DoDeleteRange(FCY, FCX, FCY, Length(LineText(FCY)));
   finally
      EndAction;
   end;
end;

procedure TSynEdit.DeleteWordRight;
var s: string;
    c: integer;
begin
   if FReadOnly then exit;
   s := LineText(FCY);
   if FCX >= Length(s) then
   begin
      DeleteKey;
      exit;
   end;
   c := FCX + 1;
   if IsWordChar(s[c]) then
      while (c <= Length(s)) and IsWordChar(s[c]) do inc(c)
   else
      while (c <= Length(s)) and not IsWordChar(s[c]) and (s[c] <> ' ') do inc(c);
   while (c <= Length(s)) and (s[c] = ' ') do inc(c);
   StartAction;
   try
      DoDeleteRange(FCY, FCX, FCY, c - 1);
   finally
      EndAction;
   end;
end;

{ ---- error line, go to, search ---- }

procedure TSynEdit.SetErrorLine(V: integer);
begin
   if V = FErrorLine then exit;
   FErrorLine := V;
   Invalidate;
end;

procedure TSynEdit.SetErrorColor(V: THighlightAttr);
begin
   FErrorColor.Assign(V);
end;

procedure TSynEdit.GotoLine(L: integer; C: integer = 1);
begin
   Measure;
   if L < 1 then L := 1;
   if L > FLines.Count then L := FLines.Count;
   if (L - 1 < FTopL) or (L - 1 >= FTopL + TextH) then
   begin
      FTopL := L - 1 - TextH div 2;
      if FTopL > MaxTop then FTopL := MaxTop;
      if FTopL < 0 then FTopL := 0;
   end;
   MoveCaret(L - 1, C - 1, false);
   FWantX := FCX;
end;

function SynWordChar(Ch: char): boolean;
begin
   Result := Ch in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function TSynEdit.SearchReplace(const ASearch, AReplace: string; AOptions: TSynSearchOptions): integer;
var l, c, p, startC, n: integer;
    s, key: string;
    found: boolean;

   { S at column P (1 based) of line text T? }
   function MatchAt(const T: string; P: integer): boolean;
   var w: string;
   begin
      Result := false;
      if (P < 1) or (P + Length(key) - 1 > Length(T)) then exit;
      w := Copy(T, P, Length(key));
      if not (ssoMatchCase in AOptions) then w := UpperCase(w);
      if w <> key then exit;
      if ssoWholeWord in AOptions then
      begin
         if (P > 1) and SynWordChar(T[P - 1]) then exit;
         if (P + Length(key) <= Length(T)) and SynWordChar(T[P + Length(key)]) then exit;
      end;
      Result := true;
   end;

   { the next find from (L, C) on: true and (L, P) }
   function FindNext(var L: integer; C: integer; out P: integer): boolean;
   var t: string;
   begin
      Result := false;
      while (L >= 0) and (L < FLines.Count) do
      begin
         t := FLines[L];
         if ssoBackwards in AOptions then
         begin
            P := C - Length(key) + 1;
            while P >= 1 do
            begin
               if MatchAt(t, P) then exit(true);
               dec(P);
            end;
            dec(L);
            if L >= 0 then C := Length(FLines[L]);
         end
         else
         begin
            P := C + 1;
            while P + Length(key) - 1 <= Length(t) do
            begin
               if MatchAt(t, P) then exit(true);
               inc(P);
            end;
            inc(L);
            C := 0;
         end;
      end;
   end;

begin
   Result := 0;
   if (ASearch = '') or (FLines.Count = 0) then exit;
   key := ASearch;
   if not (ssoMatchCase in AOptions) then key := UpperCase(key);
   if ssoReplaceAll in AOptions then
   begin
      if FReadOnly then exit;
      { every one, from the start (or the caret), in one undo step }
      if ssoEntireScope in AOptions then begin l := 0; c := 0; end
      else begin l := FCY; c := FCX; end;
      AOptions := AOptions - [ssoBackwards];
      StartAction;
      try
         n := 0;
         while FindNext(l, c, p) do
         begin
            FCY := l; FCX := p - 1; FAY := l; FAX := p - 1;
            DoDeleteRange(l, p - 1, l, p - 1 + Length(key));
            DoInsert(AReplace);
            c := p - 1 + Length(AReplace);
            inc(n);
         end;
         Result := n;
      finally
         EndAction;
      end;
      exit;
   end;
   { the selection is a find already: replace it (ssoReplace) }
   if (ssoReplace in AOptions) and SelAvail and not FReadOnly then
   begin
      s := GetSelText;
      if not (ssoMatchCase in AOptions) then s := UpperCase(s);
      if s = key then
      begin
         StartAction;
         try
            DoInsert(AReplace);
         finally
            EndAction;
         end;
         Result := 1;
      end;
   end;
   { then the next one }
   if ssoEntireScope in AOptions then
   begin
      if ssoBackwards in AOptions then
      begin
         l := FLines.Count - 1;
         startC := Length(FLines[l]);
      end
      else begin l := 0; startC := 0; end;
   end
   else
   begin
      l := FCY;
      if ssoBackwards in AOptions then
      begin
         { a find must end before the caret (or before the selection) }
         startC := FCX;
         if SelAvail then
         begin
            l := BlockBegin.Y - 1;
            startC := BlockBegin.X - 1;
         end;
      end
      else startC := FCX;
   end;
   found := FindNext(l, startC, p);
   if found then
   begin
      Measure;
      if (l < FTopL) or (l >= FTopL + TextH) then
      begin
         FTopL := l - TextH div 2;
         if FTopL > MaxTop then FTopL := MaxTop;
         if FTopL < 0 then FTopL := 0;
      end;
      MoveCaret(l, p - 1, false);
      MoveCaret(l, p - 1 + Length(key), true);
      FWantX := FCX;
      if Result = 0 then Result := 1;
   end;
end;

{ ---- the Turbo block ---- }

function TSynEdit.BlockMarked: boolean;
begin
   Result := FHasB and FHasK and ((FBKL > FBBL) or ((FBKL = FBBL) and (FBKC > FBBC)));
end;

procedure TSynEdit.ClearMarks;
begin
   if FHasB or FHasK then Invalidate;
   FHasB := false;
   FHasK := false;
end;

{ the block the block commands work on: the selection, else the marked block }
function TSynEdit.GetBlock(out L1, C1, L2, C2: integer): boolean;
begin
   Result := true;
   if SelAvail then SelBounds(L1, C1, L2, C2)
   else if BlockMarked then
   begin
      L1 := FBBL; C1 := FBBC; L2 := FBKL; C2 := FBKC;
      if C1 > Length(LineText(L1)) then C1 := Length(LineText(L1));
      if C2 > Length(LineText(L2)) then C2 := Length(LineText(L2));
   end
   else Result := false;
end;

function TSynEdit.GetMarkedText: string;
var l1, c1, l2, c2: integer;
begin
   if not BlockMarked then exit('');
   l1 := FBBL; c1 := FBBC; l2 := FBKL; c2 := FBKC;
   if c1 > Length(LineText(l1)) then c1 := Length(LineText(l1));
   if c2 > Length(LineText(l2)) then c2 := Length(LineText(l2));
   Result := StringReplace(RangeText(l1, c1, l2, c2), #10, LineEnding, [rfReplaceAll]);
end;

{ ---- Ctrl+K / Ctrl+Q (Turbo / WordStar block and quick commands) ---- }

procedure TSynEdit.PrefixCommand(Ch: char);
var p: char;
    l1, c1, l2, c2: integer;
    handled: boolean;
begin
   p := FPrefix;
   FPrefix := #0;
   Ch := UpCase(Ch);
   { the program's own commands first (Ctrl+Q F: find...) }
   if Assigned(FOnPrefixCommand) then
   begin
      handled := false;
      FOnPrefixCommand(Self, p, Ch, handled);
      if handled then
      begin
         StatusChanged;
         exit;
      end;
   end;
   if p = 'K' then
      case Ch of
         'B': begin FBBL := FCY; FBBC := FCX; FHasB := true; Invalidate; end;
         'K': begin FBKL := FCY; FBKC := FCX; FHasK := true; Invalidate; end;
         'H': begin
                 { hide / show again: Turbo toggles; here it unmarks }
                 ClearMarks;
                 FAY := FCY; FAX := FCX;
                 Invalidate;
              end;
         'C': CopyBlockHere(false);
         'V': CopyBlockHere(true);
         'Y': if GetBlock(l1, c1, l2, c2) and not FReadOnly then
              begin
                 StartAction;
                 try
                    DoDeleteRange(l1, c1, l2, c2);
                 finally
                    EndAction;
                 end;
                 ClearMarks;
              end;
         'I': IndentBlock;
         'U': UnindentBlock;
         'T': begin
                 SelectWord;
                 FBBL := FAY; FBBC := FAX; FBKL := FCY; FBKC := FCX;
                 FHasB := true; FHasK := true;
              end;
         'L': begin
                 FBBL := FCY; FBBC := 0; FHasB := true;
                 if FCY < FLines.Count - 1 then begin FBKL := FCY + 1; FBKC := 0; end
                 else begin FBKL := FCY; FBKC := Length(LineText(FCY)); end;
                 FHasK := true;
                 Invalidate;
              end;
      end
   else if p = 'Q' then
      case Ch of
         'S': MoveCaret(FCY, 0, false);
         'D': MoveCaret(FCY, Length(TrimRight(LineText(FCY))), false);
         'E': MoveCaret(FTopL, FCX, false);
         'X': MoveCaret(FTopL + TextH - 1, FCX, false);
         'R': MoveCaret(0, 0, false);
         'C': MoveCaret(FLines.Count - 1, Length(LineText(FLines.Count - 1)), false);
         'B': if GetBlock(l1, c1, l2, c2) then MoveCaret(l1, c1, false);
         'K': if GetBlock(l1, c1, l2, c2) then MoveCaret(l2, c2, false);
         'Y': DeleteToEol;
      end;
   FWantX := FCX;
   StatusChanged;
end;

{ the WordStar single keys (WordStarKeys): Ctrl+E S D X, A F, R C, W Z, }
{ G, T, V, N                                                            }
function TSynEdit.WordStarKey(Key: Word; Ext: boolean): boolean;
var w: Word;
begin
   Result := true;
   case Key of
      Ord('E'): begin w := VK_UP; KeyDown(w, ShiftOf(Ext)); end;
      Ord('X'): begin w := VK_DOWN; KeyDown(w, ShiftOf(Ext)); end;
      Ord('S'): begin w := VK_LEFT; KeyDown(w, ShiftOf(Ext)); end;
      Ord('D'): begin w := VK_RIGHT; KeyDown(w, ShiftOf(Ext)); end;
      Ord('A'): begin w := VK_LEFT; KeyDown(w, ShiftOf(Ext) + [ssCtrl]); end;
      Ord('F'): begin w := VK_RIGHT; KeyDown(w, ShiftOf(Ext) + [ssCtrl]); end;
      Ord('R'): begin w := VK_PRIOR; KeyDown(w, ShiftOf(Ext)); end;
      Ord('C'): begin w := VK_NEXT; KeyDown(w, ShiftOf(Ext)); end;
      Ord('W'): begin w := VK_UP; KeyDown(w, [ssCtrl]); end;
      Ord('Z'): begin w := VK_DOWN; KeyDown(w, [ssCtrl]); end;
      Ord('G'): DeleteKey;
      Ord('T'): DeleteWordRight;
      Ord('V'): SetInsertMode(not FInsertMode);
      Ord('N'): begin NewLine; MoveCaret(FCY - 1, Length(LineText(FCY - 1)), false); end;
   else
      Result := false;
   end;
end;

function TSynEdit.ShiftOf(Ext: boolean): TShiftState;
begin
   if Ext then Result := [ssShift] else Result := [];
end;

{ ---- keys ---- }

procedure TSynEdit.KeyDown(var Key: Word; Shift: TShiftState);
var ext, ctrl: boolean;
    s: string;
    c, l, n: integer;
begin
   inherited KeyDown(Key, Shift);
   if Key = 0 then exit;
   { the second key of Ctrl+K x / Ctrl+Q x }
   if FPrefix <> #0 then
   begin
      { on DOS Ctrl+I, Ctrl+H and Ctrl+M arrive as Tab, Backspace and Enter }
      if ssCtrl in Shift then
         case Key of
            VK_TAB: Key := Ord('I');
            VK_BACK: Key := Ord('H');
            VK_RETURN: Key := Ord('M');
         end
      else if (Key = VK_TAB) and (Shift = []) then Key := Ord('I')
      else if (Key = VK_BACK) and (Shift = []) then Key := Ord('H');
      if Key in [Ord('A')..Ord('Z'), Ord('0')..Ord('9')] then
      begin
         PrefixCommand(char(Key));
         Key := 0;
         exit;
      end;
      FPrefix := #0;            { anything else cancels it }
      StatusChanged;
   end;
   { undo: Ctrl+Z and Alt+Backspace (Turbo / QBasic); redo: Ctrl+Shift+Z, }
   { Alt+Shift+Backspace                                                  }
   if (Key = VK_BACK) and (ssAlt in Shift) then
   begin
      if ssShift in Shift then Redo else Undo;
      Key := 0;
      exit;
   end;
   if ssAlt in Shift then exit;
   Measure;
   ext := ssShift in Shift;
   ctrl := ssCtrl in Shift;
   if ctrl and ((Key = Ord('K')) or (Key = Ord('Q'))) and not ext then
   begin
      FPrefix := char(Key);
      StatusChanged;
      Key := 0;
      exit;
   end;
   if ctrl and FWordStarKeys and WordStarKey(Key, ext) then
   begin
      Key := 0;
      exit;
   end;
   case Key of
      VK_LEFT:
         begin
            if ctrl then
            begin
               s := LineText(FCY);
               c := FCX;
               if c > Length(s) then c := Length(s);
               if c = 0 then
               begin
                  if FCY > 0 then MoveCaret(FCY - 1, Length(LineText(FCY - 1)), ext);
               end
               else
               begin
                  while (c > 0) and not IsWordChar(s[c]) do dec(c);
                  while (c > 0) and IsWordChar(s[c]) do dec(c);
                  MoveCaret(FCY, c, ext);
               end;
            end
            else if FCX > 0 then MoveCaret(FCY, FCX - 1, ext)
            else if (FCY > 0) and not (eoScrollPastEol in FOptions) then
               MoveCaret(FCY - 1, Length(LineText(FCY - 1)), ext);
            FWantX := FCX;
            Key := 0;
         end;
      VK_RIGHT:
         begin
            s := LineText(FCY);
            if ctrl then
            begin
               c := FCX + 1;
               if FCX >= Length(s) then
               begin
                  if FCY < FLines.Count - 1 then MoveCaret(FCY + 1, 0, ext);
               end
               else
               begin
                  while (c <= Length(s)) and IsWordChar(s[c]) do inc(c);
                  while (c <= Length(s)) and not IsWordChar(s[c]) do inc(c);
                  MoveCaret(FCY, c - 1, ext);
               end;
            end
            else if (FCX >= Length(s)) and not (eoScrollPastEol in FOptions) then
            begin
               if FCY < FLines.Count - 1 then MoveCaret(FCY + 1, 0, ext);
            end
            else MoveCaret(FCY, FCX + 1, ext);
            FWantX := FCX;
            Key := 0;
         end;
      VK_UP, VK_DOWN:
         begin
            if ctrl then
            begin
               { scroll the view, the caret stays on screen }
               if Key = VK_UP then FTopL := FTopL - 1 else FTopL := FTopL + 1;
               if FTopL > MaxTop then FTopL := MaxTop;
               if FTopL < 0 then FTopL := 0;
               if FCY < FTopL then MoveCaret(FTopL, FCX, ext)
               else if FCY >= FTopL + TextH then MoveCaret(FTopL + TextH - 1, FCX, ext)
               else Invalidate;
            end
            else
            begin
               if Key = VK_UP then l := FCY - 1 else l := FCY + 1;
               if eoKeepCaretX in FOptions then c := FWantX else c := FCX;
               MoveCaret(l, c, ext);
            end;
            Key := 0;
         end;
      VK_PRIOR, VK_NEXT:
         begin
            n := TextH - 1;
            if n < 1 then n := 1;
            if Key = VK_PRIOR then n := -n;
            FTopL := FTopL + n;
            if FTopL > MaxTop then FTopL := MaxTop;
            if FTopL < 0 then FTopL := 0;
            if ctrl then
            begin
               if Key = VK_PRIOR then MoveCaret(FTopL, FCX, ext)
               else MoveCaret(FTopL + TextH - 1, FCX, ext);
            end
            else MoveCaret(FCY + n, FWantX, ext);
            Key := 0;
         end;
      VK_HOME:
         begin
            if ctrl then MoveCaret(0, 0, ext)
            else
            begin
               { the first non-blank, then column 1 (Turbo style) }
               s := LineText(FCY);
               c := 0;
               while (c < Length(s)) and (s[c + 1] = ' ') do inc(c);
               if FCX = c then c := 0;
               MoveCaret(FCY, c, ext);
            end;
            FWantX := FCX;
            Key := 0;
         end;
      VK_END:
         begin
            if ctrl then MoveCaret(FLines.Count - 1, Length(LineText(FLines.Count - 1)), ext)
            else MoveCaret(FCY, Length(TrimRight(LineText(FCY))), ext);
            FWantX := FCX;
            Key := 0;
         end;
      VK_RETURN:
         if not FReadOnly and not ctrl then
         begin
            NewLine;
            Key := 0;
         end;
      VK_TAB:
         if not FReadOnly and not ctrl then
         begin
            { a selection: block indent; Shift+Tab: unindent }
            if ext then UnindentBlock
            else if SelAvail then IndentBlock
            else
            begin
               StartAction;
               try
                  DoInsert(StringOfChar(' ', FTabWidth - FCX mod FTabWidth));
               finally
                  EndAction;
               end;
            end;
            Key := 0;
         end;
      VK_BACK:
         begin
            BackspaceKey;
            Key := 0;
         end;
      VK_DELETE:
         begin
            if ext then CutToClipboard
            else DeleteKey;
            Key := 0;
         end;
      VK_INSERT:
         begin
            if Shift = [] then SetInsertMode(not FInsertMode)
            else if Shift = [ssCtrl] then CopyToClipboard
            else if Shift = [ssShift] then PasteFromClipboard;
            Key := 0;
         end;
   else
      if ctrl then
         case Key of
            VK_A: if not ext then begin SelectAll; Key := 0; end;
            Ord('C'): if not ext then begin CopyToClipboard; Key := 0; end;
            Ord('X'): if not ext then begin CutToClipboard; Key := 0; end;
            Ord('V'): if not ext then begin PasteFromClipboard; Key := 0; end;
            Ord('Y'): if not ext then begin DeleteLine; Key := 0; end;
            Ord('Z'): begin if ext then Redo else Undo; Key := 0; end;
         end;
   end;
end;

procedure TSynEdit.KeyPress(var Key: char);
var s: string;
    merge: boolean;
begin
   inherited KeyPress(Key);
   if FPrefix <> #0 then
   begin
      if Key in ['a'..'z', 'A'..'Z', '0'..'9'] then PrefixCommand(Key)
      else begin FPrefix := #0; StatusChanged; end;
      Key := #0;
      exit;
   end;
   if (Key < ' ') or FReadOnly then exit;
   ClearMarks;
   { typing goes in one undo step a word at a time }
   merge := (FTyping = ltChar) and not SelAvail and (FCY = FTypeL) and (FCX = FTypeC) and
            not ((FLastChar = ' ') and (Key <> ' ')) and (FBlockDepth = 0);
   if merge then BeginUpdate else StartAction;
   try
      if not FInsertMode and not SelAvail and (FCX < Length(LineText(FCY))) then
      begin
         s := Key;
         DoDeleteRange(FCY, FCX, FCY, FCX + 1);
         DoInsert(s);
      end
      else DoInsert(Key);
   finally
      EndAction;
   end;
   FTyping := ltChar;
   FTypeL := FCY;
   FTypeC := FCX;
   FLastChar := Key;
   Key := #0;
end;

function TSynEdit.WantsChars: boolean;
begin
   Result := true;
end;

function TSynEdit.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   Measure;
   X := GutterWidth + FCX - FLeftC;
   Y := FCY - FTopL;
   if FInsertMode then Shape := csLine else Shape := csBlock;
   Result := (FCX >= FLeftC) and (FCX < FLeftC + TextW) and (Y >= 0) and (Y < TextH);
end;

{ ---- mouse ---- }

procedure TSynEdit.PosAt(X, Y: integer; out L, C: integer);
begin
   Measure;
   L := FTopL + Y;
   if L >= FLines.Count then L := FLines.Count - 1;
   if L < 0 then L := 0;
   C := FLeftC + X - GutterWidth;
   if C < 0 then C := 0;
end;

procedure TSynEdit.DoScrollV(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FTopL);
      shLineDown: inc(FTopL);
      shPageUp:   dec(FTopL, TextH - 1);
      shPageDown: inc(FTopL, TextH - 1);
      shThumb:    FThumbV := true;
   end;
   if FTopL > MaxTop then FTopL := MaxTop;
   if FTopL < 0 then FTopL := 0;
   Invalidate;
end;

procedure TSynEdit.DoScrollH(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FLeftC);
      shLineDown: inc(FLeftC);
      shPageUp:   dec(FLeftC, TextW - 1);
      shPageDown: inc(FLeftC, TextW - 1);
      shThumb:    FThumbH := true;
   end;
   if FLeftC > MaxLeft then FLeftC := MaxLeft;
   if FLeftC < 0 then FLeftC := 0;
   Invalidate;
end;

procedure TSynEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var l, c, gx: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button <> mbLeft then exit;
   Measure;
   FHoldV := shNone;
   FHoldH := shNone;
   gx := GutterWidth;
   if FVBar and (X = gx + TextW) and (Y < TextH) then
   begin
      FHoldV := ScrollHitAt(Y, TextH, FTopL, MaxTop);
      DoScrollV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
      exit;
   end;
   if FHBar and (Y = TextH) and (X >= gx) and (X < gx + TextW) then
   begin
      FHoldH := ScrollHitAt(X - gx, TextW, FLeftC, MaxLeft);
      DoScrollH(FHoldH);
      if FHoldH = shThumb then FHoldH := shNone;
      exit;
   end;
   if Y >= TextH then exit;
   PosAt(X, Y, l, c);
   if X < gx then
   begin
      { the gutter: the whole line }
      MoveCaret(l, 0, false);
      SelectLine;
      exit;
   end;
   MoveCaret(l, c, ssShift in Shift);
   FWantX := FCX;
   FDragSel := true;
   FDragX := X;
   FDragY := Y;
end;

procedure TSynEdit.MouseMove(Shift: TShiftState; X, Y: integer);
var l, c: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FThumbV then
   begin
      FTopL := ScrollPosAt(Y, TextH, MaxTop);
      Invalidate;
   end
   else if FThumbH then
   begin
      FLeftC := ScrollPosAt(X - GutterWidth, TextW, MaxLeft);
      Invalidate;
   end
   else if FDragSel then
   begin
      FDragX := X;
      FDragY := Y;
      if Y < 0 then Y := -1;
      if Y >= TextH then Y := TextH;
      PosAt(X, Y, l, c);
      MoveCaret(l, c, true);
      FWantX := FCX;
   end;
end;

procedure TSynEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FDragSel := false;
   FThumbV := false;
   FThumbH := false;
   FHoldV := shNone;
   FHoldH := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

{ the button held: the scroll arrows repeat; a drag past an edge keeps going }
procedure TSynEdit.MouseHeld(X, Y: integer);
var l, c: integer;
begin
   if (FHoldV <> shNone) and (ScrollHitAt(Y, TextH, FTopL, MaxTop) = FHoldV) then DoScrollV(FHoldV);
   if (FHoldH <> shNone) and (ScrollHitAt(X - GutterWidth, TextW, FLeftC, MaxLeft) = FHoldH) then
      DoScrollH(FHoldH);
   if FDragSel and ((FDragY < 0) or (FDragY >= TextH)) then
   begin
      if FDragY < 0 then PosAt(FDragX, -1, l, c) else PosAt(FDragX, TextH, l, c);
      MoveCaret(l, c, true);
   end;
end;

function TSynEdit.MouseWheel(WheelDelta: integer): boolean;
begin
   Measure;
   FTopL := FTopL - (WheelDelta div 120) * 3;
   if FTopL > MaxTop then FTopL := MaxTop;
   if FTopL < 0 then FTopL := 0;
   Invalidate;
   Result := true;
end;

procedure TSynEdit.DblClick;
begin
   inherited DblClick;
   SelectWord;
end;

{ ---- painting ---- }

procedure TSynEdit.Paint;
var bg, fg, a, ga, sa: byte;
    gw, tw, th, row, l, st, ts, te, x1, x2, l1, c1, l2, c2, s1, s2: integer;
    s, num: string;
    o: TPoint;
    hasSel, mark: boolean;
    m1, mc1, m2, mc2: integer;
    at: THighlightAttr;
    tf, tb: byte;

   function Col(C: TColor; Default: byte): byte;
   begin
      if (C >= 0) and (C <= 15) then Result := C else Result := Default;
   end;

begin
   Measure;
   if FTopL > MaxTop then FTopL := MaxTop;
   bg := Col(Color, tcBlue);
   fg := Col(Font.Color, tcYellow);
   if not IsEnabledAll then fg := Theme.DisabledFg;
   a := MakeAttr(fg, bg);
   gw := GutterWidth;
   tw := TextW;
   th := TextH;
   ga := MakeAttr(Col(FGutter.FTextColor, tcCyan), Col(FGutter.FColor, tcBlue));
   sa := MakeAttr(Col(FSelColor.Foreground, tcBlack), Col(FSelColor.Background, tcLightGray));
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   hasSel := SelAvail;
   if hasSel then SelBounds(l1, c1, l2, c2);
   mark := BlockMarked;
   if mark then
   begin
      m1 := FBBL; mc1 := FBBC; m2 := FBKL; mc2 := FBKC;
   end;
   for row := 0 to th - 1 do
   begin
      l := FTopL + row;
      { the gutter }
      if gw > 0 then
      begin
         Canvas.Fill(Rect(0, row, gw, row + 1), ' ', ga);
         if (l < FLines.Count) and FGutter.FShowLineNumbers then
         begin
            num := IntToStr(l + 1);
            Canvas.TextOut(gw - 1 - Length(num), row, num, ga);
         end;
         Canvas.PutChar(gw - 1, row, #179, MakeAttr(tcDarkGray, AttrBg(ga)));
      end;
      if l >= FLines.Count then continue;
      s := FLines[l];
      { the text, token by token, only the part on screen }
      if FHighlighter = nil then
         Canvas.TextOut(gw, row, Copy(s, FLeftC + 1, tw), a)
      else
      begin
         st := FStates.StartState(l);
         FHighlighter.SetLine(s, st);
         while not FHighlighter.GetEol do
         begin
            ts := FHighlighter.TokenStart - 1;
            te := ts + FHighlighter.TokenLength;
            if (te > FLeftC) and (ts < FLeftC + tw) and (FHighlighter.TokenKind <> tkSpace) then
            begin
               at := FHighlighter.TokenAttri;
               tf := Col(at.Foreground, fg);
               tb := Col(at.Background, bg);
               x1 := ts;
               if x1 < FLeftC then x1 := FLeftC;
               x2 := te;
               if x2 > FLeftC + tw then x2 := FLeftC + tw;
               Canvas.TextOut(gw + x1 - FLeftC, row, Copy(s, x1 + 1, x2 - x1), MakeAttr(tf, tb));
            end;
            if ts >= FLeftC + tw then break;
            FHighlighter.Next;
         end;
      end;
      { a compiler error on this line }
      if l + 1 = FErrorLine then
         Canvas.SetAttr(Rect(gw, row, gw + tw, row + 1),
                        MakeAttr(Col(FErrorColor.Foreground, tcWhite), Col(FErrorColor.Background, tcRed)));
      { the marked Turbo block, then the selection }
      if mark and (l >= m1) and (l <= m2) then
      begin
         if l = m1 then s1 := mc1 else s1 := 0;
         if l = m2 then s2 := mc2 else s2 := Length(s) + 1;
         if s2 > s1 then
         begin
            x1 := s1;
            if x1 < FLeftC then x1 := FLeftC;
            x2 := s2;
            if x2 > FLeftC + tw then x2 := FLeftC + tw;
            if x2 > x1 then Canvas.SetAttr(Rect(gw + x1 - FLeftC, row, gw + x2 - FLeftC, row + 1), sa);
         end;
      end;
      { the selection on this line: past the end too when it goes on }
      if hasSel and (l >= l1) and (l <= l2) then
      begin
         if l = l1 then s1 := c1 else s1 := 0;
         if l = l2 then s2 := c2 else s2 := Length(s) + 1;
         if s2 > s1 then
         begin
            x1 := s1;
            if x1 < FLeftC then x1 := FLeftC;
            x2 := s2;
            if x2 > FLeftC + tw then x2 := FLeftC + tw;
            if x2 > x1 then Canvas.SetAttr(Rect(gw + x1 - FLeftC, row, gw + x2 - FLeftC, row + 1), sa);
         end;
      end;
   end;
   o := ScreenOrigin;
   sa := MakeAttr(AttrFg(Theme.ListScroll), AttrBg(Theme.ListScroll));
   if FVBar then DrawVScroll(o.X + gw + tw, o.Y, th, FTopL, MaxTop, sa);
   if FHBar then DrawHScroll(o.X + gw, o.Y + th, tw, FLeftC, MaxLeft, sa);
   if FVBar and FHBar then Canvas.PutChar(gw + tw, th, ' ', sa);
   if FHBar and (gw > 0) then Canvas.Fill(Rect(0, th, gw, th + 1), ' ', ga);
end;

initialization
   RegisterClass(TSynEdit);
end.
