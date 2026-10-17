{-----------------------------------------------------------------------------}
{  TUIMEMO - TMemo, the multi-line edit control (LCL StdCtrls names).         }
{                                                                             }
{     Lines (TStrings), Text, WordWrap, ReadOnly, ScrollBars (ssNone ..       }
{     ssAutoBoth), WantReturns, WantTabs, CaretPos, SelText, SelectAll,       }
{     ClearSelection, CopyToClipboard, CutToClipboard, PasteFromClipboard,     }
{     Clear, Append, OnChange                                                 }
{                                                                             }
{  Keys: arrows, Home/End (of the screen row), Ctrl+Home/End, PgUp/PgDn,      }
{  Ctrl+Left/Right (words), Shift+any of those selects; Enter, Tab (when     }
{  WantTabs: spaces to the next multiple of 8), Backspace, Del, Ins (insert/  }
{  overwrite), Ctrl+Y deletes the line, Ctrl+A selects all, Ctrl+C/X/V and    }
{  Ctrl+Ins/Shift+Del/Shift+Ins use the clipboard.                            }
{  Mouse: click, drag to select, double click selects a word, scroll bars     }
{  (arrows and track repeat while held, the thumb drags).                     }
{                                                                             }
{  WordWrap breaks lines at the last space that fits (or hard at the width);  }
{  the caret moves along screen rows. Without it there is a horizontal        }
{  scroll bar (ssHorizontal / ssBoth / ssAuto...).                            }
{-----------------------------------------------------------------------------}
unit TUIMemo;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, Math, TUIHW, TUIScrn, TUICtrl, TUIList;

type
   TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth,
                   ssAutoHorizontal, ssAutoVertical, ssAutoBoth);

   TMemoRow = record
      Line, Start, Len: integer;      { a screen row: part of a line }
   end;

   TMemo = class(TWinControl)
   private
      FLines: TStringList;
      FWordWrap, FReadOnly, FWantTabs, FWantReturns: boolean;
      FScrollBars: TScrollStyle;
      FLine, FCol: integer;           { the caret }
      FALine, FACol: integer;         { the other end of the selection }
      FTopRow, FLeftCol, FWantX: integer;
      FRows: array of TMemoRow;
      FRowCount: integer;
      FFirstRow: array of integer;    { per line: its first screen row }
      FLayoutOK: boolean;
      FTextW, FTextH, FMaxLen: integer;
      FVBar, FHBar: boolean;
      FDragSel, FThumbV, FThumbH: boolean;
      FHoldV, FHoldH: TScrollHit;
      FOnChange: TNotifyEvent;
      procedure LinesChanged(Sender: TObject);
      procedure SetLines(V: TStrings);
      function  GetLines: TStrings;
      function  GetText: string;
      procedure SetText(const V: string);
      procedure SetWordWrap(V: boolean);
      procedure SetScrollBars(V: TScrollStyle);
      function  GetCaretPos2: TPoint;
      procedure SetCaretPos2(const P: TPoint);
      procedure Build(W: integer);
      procedure Layout;
      function  RowOf(ALine, ACol: integer): integer;
      function  RowMaxCol(R: integer): integer;
      function  LineText(I: integer): string;
      procedure MoveTo(ALine, ACol: integer; Extend: boolean);
      procedure MoveToRow(R, X: integer; Extend: boolean);
      procedure ScrollToCaret;
      procedure SelBounds(out L1, C1, L2, C2: integer);
      procedure DeleteSel;
      procedure InsertText(const T: string);
      procedure DoScrollV(H: TScrollHit);
      procedure DoScrollH(H: TScrollHit);
      function  MaxTop: integer;
      function  MaxLeft: integer;
      procedure PosAt(X, Y: integer; out ALine, ACol: integer);
   protected
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
      function  HasSelection: boolean;
      function  GetSelText: string;
      procedure SetSelText(const V: string);
      function  GetSelStart: integer;
      procedure SetSelStart(V: integer);
      function  GetSelLength: integer;
      procedure SetSelLength(V: integer);
      { character positions in Text (line ends count as Length(LineEnding)) }
      function  PosToCaret(P: integer): TPoint;
      function  CaretToPos(const P: TPoint): integer;
      { the selection, LCL style: SelStart (0 based) and SelLength; SelText }
      { reads it and replaces it (inserts at the caret when nothing is     }
      { selected)                                                          }
      procedure SelectAll;
      procedure ClearSelection;
      procedure CopyToClipboard;
      procedure CutToClipboard;
      procedure PasteFromClipboard;
      procedure Clear;
      procedure Append(const S: string);
      { X = column, Y = line (0 based) }
      property CaretPos: TPoint read GetCaretPos2 write SetCaretPos2;
   published
      property SelStart: integer read GetSelStart write SetSelStart;
      property SelLength: integer read GetSelLength write SetSelLength;
      property SelText: string read GetSelText write SetSelText;
      property Lines: TStrings read GetLines write SetLines;
      property Text: string read GetText write SetText;
      property TopRow: integer read FTopRow;
      property LeftCol: integer read FLeftCol;
      property WordWrap: boolean read FWordWrap write SetWordWrap default true;
      property ReadOnly: boolean read FReadOnly write FReadOnly default false;
      property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssNone;
      property WantReturns: boolean read FWantReturns write FWantReturns default true;
      property WantTabs: boolean read FWantTabs write FWantTabs default false;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

implementation

constructor TMemo.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FLines := TStringList.Create;
   FLines.OnChange := @LinesChanged;
   FWordWrap := true;
   FWantReturns := true;
   FWidth := 30;
   FHeight := 6;
end;

destructor TMemo.Destroy;
begin
   FLines.OnChange := nil;
   FreeAndNil(FLines);
   inherited Destroy;
end;

function TMemo.GetLines: TStrings;
begin
   Result := FLines;
end;

procedure TMemo.SetLines(V: TStrings);
begin
   FLines.Assign(V);
end;

function TMemo.GetText: string;
begin
   Result := FLines.Text;
end;

procedure TMemo.SetText(const V: string);
begin
   FLines.Text := V;
   FLine := 0; FCol := 0; FALine := 0; FACol := 0;
   FTopRow := 0; FLeftCol := 0;
end;

procedure TMemo.Clear;
begin
   SetText('');
end;

procedure TMemo.Append(const S: string);
begin
   FLines.Add(S);
end;

procedure TMemo.Change;
begin
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TMemo.LinesChanged(Sender: TObject);
begin
   FLayoutOK := false;
   if FLine >= FLines.Count then FLine := FLines.Count - 1;
   if FLine < 0 then FLine := 0;
   if FCol > Length(LineText(FLine)) then FCol := Length(LineText(FLine));
   if FALine >= FLines.Count then FALine := FLine;
   if FALine < 0 then FALine := 0;
   if FACol > Length(LineText(FALine)) then FACol := Length(LineText(FALine));
   Invalidate;
   Change;
end;

procedure TMemo.SetWordWrap(V: boolean);
begin
   if V = FWordWrap then exit;
   FWordWrap := V;
   FLeftCol := 0;
   FLayoutOK := false;
   Invalidate;
end;

procedure TMemo.SetScrollBars(V: TScrollStyle);
begin
   if V = FScrollBars then exit;
   FScrollBars := V;
   FLayoutOK := false;
   Invalidate;
end;

procedure TMemo.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   FLayoutOK := false;
end;

function TMemo.LineText(I: integer): string;
begin
   if (I >= 0) and (I < FLines.Count) then Result := FLines[I] else Result := '';
end;

function TMemo.GetCaretPos2: TPoint;
begin
   Result := Point(FCol, FLine);
end;

procedure TMemo.SetCaretPos2(const P: TPoint);
begin
   MoveTo(P.Y, P.X, false);
end;

{----------------------------------------------------------------- layout --}

procedure TMemo.Build(W: integer);
var i, start, n, k, p: integer;
    s: string;

   procedure AddRow(L, St, Ln: integer);
   begin
      if FRowCount >= Length(FRows) then SetLength(FRows, FRowCount * 2 + 16);
      FRows[FRowCount].Line := L;
      FRows[FRowCount].Start := St;
      FRows[FRowCount].Len := Ln;
      inc(FRowCount);
   end;

begin
   FRowCount := 0;
   FMaxLen := 0;
   n := FLines.Count;
   if n = 0 then n := 1;
   SetLength(FFirstRow, n);
   for i := 0 to n - 1 do
   begin
      s := LineText(i);
      if Length(s) > FMaxLen then FMaxLen := Length(s);
      FFirstRow[i] := FRowCount;
      start := 0;
      if FWordWrap and (W > 1) then
         while Length(s) - start > W do
         begin
            { the last space that fits, else a hard break }
            p := 0;
            for k := start + W downto start + 2 do
               if s[k] = ' ' then begin p := k; break; end;
            if p > 0 then
            begin
               AddRow(i, start, p - start);
               start := p;
            end
            else
            begin
               AddRow(i, start, W);
               inc(start, W);
            end;
         end;
      if (Length(s) - start > 0) or (FFirstRow[i] = FRowCount) then
         AddRow(i, start, Length(s) - start);
   end;
end;

procedure TMemo.Layout;
var vb, hb, autoV, autoH: boolean;
    pass: integer;
begin
   if FLayoutOK then exit;
   vb := FScrollBars in [ssVertical, ssBoth];
   hb := (FScrollBars in [ssHorizontal, ssBoth]) and not FWordWrap;
   autoV := FScrollBars in [ssAutoVertical, ssAutoBoth];
   autoH := (FScrollBars in [ssAutoHorizontal, ssAutoBoth]) and not FWordWrap;
   for pass := 1 to 3 do
   begin
      FTextW := Width - ord(vb);
      FTextH := Height - ord(hb);
      if FTextW < 1 then FTextW := 1;
      if FTextH < 1 then FTextH := 1;
      Build(FTextW);
      if autoV and not vb and (FRowCount > FTextH) then begin vb := true; continue; end;
      if autoH and not hb and (FMaxLen >= FTextW) then begin hb := true; continue; end;
      break;
   end;
   FVBar := vb and (Width >= 2) and (Height >= 2);
   FHBar := hb and (Width >= 2) and (Height >= 2);
   FLayoutOK := true;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FLeftCol > MaxLeft then FLeftCol := MaxLeft;
end;

function TMemo.MaxTop: integer;
begin
   Result := FRowCount - FTextH;
   if Result < 0 then Result := 0;
end;

function TMemo.MaxLeft: integer;
begin
   if FWordWrap then exit(0);
   Result := FMaxLen + 1 - FTextW;
   if Result < 0 then Result := 0;
end;

function TMemo.RowOf(ALine, ACol: integer): integer;
begin
   Layout;
   if ALine >= Length(FFirstRow) then ALine := High(FFirstRow);
   if ALine < 0 then ALine := 0;
   Result := FFirstRow[ALine];
   while (Result + 1 < FRowCount) and (FRows[Result + 1].Line = ALine) and
         (ACol >= FRows[Result + 1].Start) do inc(Result);
end;

{ the last column the caret can take on row R and stay on it }
function TMemo.RowMaxCol(R: integer): integer;
begin
   Result := FRows[R].Start + FRows[R].Len;
   if (R + 1 < FRowCount) and (FRows[R + 1].Line = FRows[R].Line) then dec(Result);
   if Result < FRows[R].Start then Result := FRows[R].Start;
end;

procedure TMemo.ScrollToCaret;
var r: integer;
begin
   Layout;
   r := RowOf(FLine, FCol);
   if r < FTopRow then FTopRow := r;
   if r >= FTopRow + FTextH then FTopRow := r - FTextH + 1;
   if not FWordWrap then
   begin
      if FCol < FLeftCol then FLeftCol := FCol;
      if FCol >= FLeftCol + FTextW then FLeftCol := FCol - FTextW + 1;
   end;
end;

{------------------------------------------------------------- the caret --}

procedure TMemo.MoveTo(ALine, ACol: integer; Extend: boolean);
begin
   if ALine >= FLines.Count then ALine := FLines.Count - 1;
   if ALine < 0 then ALine := 0;
   if ACol > Length(LineText(ALine)) then ACol := Length(LineText(ALine));
   if ACol < 0 then ACol := 0;
   FLine := ALine;
   FCol := ACol;
   if not Extend then
   begin
      FALine := FLine;
      FACol := FCol;
   end;
   ScrollToCaret;
   FWantX := FCol - FRows[RowOf(FLine, FCol)].Start;
   Invalidate;
end;

procedure TMemo.MoveToRow(R, X: integer; Extend: boolean);
var c: integer;
begin
   Layout;
   if R < 0 then R := 0;
   if R >= FRowCount then R := FRowCount - 1;
   c := FRows[R].Start + X;
   if c > RowMaxCol(R) then c := RowMaxCol(R);
   FLine := FRows[R].Line;
   FCol := c;
   if not Extend then
   begin
      FALine := FLine;
      FACol := FCol;
   end;
   ScrollToCaret;
   Invalidate;
end;

function TMemo.HasSelection: boolean;
begin
   Result := (FLine <> FALine) or (FCol <> FACol);
end;

procedure TMemo.SelBounds(out L1, C1, L2, C2: integer);
begin
   if (FALine < FLine) or ((FALine = FLine) and (FACol <= FCol)) then
   begin
      L1 := FALine; C1 := FACol; L2 := FLine; C2 := FCol;
   end
   else
   begin
      L1 := FLine; C1 := FCol; L2 := FALine; C2 := FACol;
   end;
end;

function TMemo.GetSelText: string;
var l1, c1, l2, c2, i: integer;
begin
   Result := '';
   if not HasSelection then exit;
   SelBounds(l1, c1, l2, c2);
   if l1 = l2 then exit(Copy(LineText(l1), c1 + 1, c2 - c1));
   Result := Copy(LineText(l1), c1 + 1, MaxInt);
   for i := l1 + 1 to l2 - 1 do Result := Result + LineEnding + LineText(i);
   Result := Result + LineEnding + Copy(LineText(l2), 1, c2);
end;

function TMemo.PosToCaret(P: integer): TPoint;
var l, n: integer;
begin
   l := 0;
   if P < 0 then P := 0;
   while l < FLines.Count do
   begin
      n := Length(FLines[l]);
      if P <= n then exit(Point(P, l));
      dec(P, n + Length(LineEnding));
      if P < 0 then exit(Point(n, l));
      inc(l);
   end;
   if FLines.Count = 0 then Result := Point(0, 0)
   else Result := Point(Length(FLines[FLines.Count - 1]), FLines.Count - 1);
end;

function TMemo.CaretToPos(const P: TPoint): integer;
var l: integer;
begin
   Result := 0;
   for l := 0 to P.Y - 1 do
      if l < FLines.Count then inc(Result, Length(FLines[l]) + Length(LineEnding));
   inc(Result, P.X);
end;

function TMemo.GetSelStart: integer;
var l1, c1, l2, c2: integer;
begin
   SelBounds(l1, c1, l2, c2);
   Result := CaretToPos(Point(c1, l1));
end;

procedure TMemo.SetSelStart(V: integer);
var p: TPoint;
begin
   p := PosToCaret(V);
   MoveTo(p.Y, p.X, false);
end;

function TMemo.GetSelLength: integer;
var l1, c1, l2, c2: integer;
begin
   SelBounds(l1, c1, l2, c2);
   Result := CaretToPos(Point(c2, l2)) - CaretToPos(Point(c1, l1));
end;

procedure TMemo.SetSelLength(V: integer);
var a, b: TPoint;
    st: integer;
begin
   st := GetSelStart;
   a := PosToCaret(st);
   b := PosToCaret(st + V);
   FALine := a.Y;
   FACol := a.X;
   FLine := b.Y;
   FCol := b.X;
   ScrollToCaret;
   Invalidate;
end;

procedure TMemo.SetSelText(const V: string);
begin
   FLines.BeginUpdate;
   try
      InsertText(V);
   finally
      FLines.EndUpdate;
   end;
   ScrollToCaret;
end;

procedure TMemo.SelectAll;
begin
   if FLines.Count = 0 then exit;
   FALine := 0;
   FACol := 0;
   FLine := FLines.Count - 1;
   FCol := Length(LineText(FLine));
   ScrollToCaret;
   Invalidate;
end;

procedure TMemo.ClearSelection;
begin
   if FReadOnly or not HasSelection then exit;
   FLines.BeginUpdate;
   try
      DeleteSel;
   finally
      FLines.EndUpdate;
   end;
   ScrollToCaret;
end;

{------------------------------------------------------------- editing --}

{ these two run inside BeginUpdate / EndUpdate: one OnChange per edit }
procedure TMemo.DeleteSel;
var l1, c1, l2, c2, i: integer;
begin
   if not HasSelection then exit;
   SelBounds(l1, c1, l2, c2);
   FLines[l1] := Copy(LineText(l1), 1, c1) + Copy(LineText(l2), c2 + 1, MaxInt);
   for i := l2 downto l1 + 1 do FLines.Delete(i);
   FLine := l1; FCol := c1; FALine := l1; FACol := c1;
end;

procedure TMemo.InsertText(const T: string);
var parts: TStringList;
    head, tail: string;
    i: integer;
begin
   DeleteSel;
   if FLines.Count = 0 then FLines.Add('');
   head := Copy(LineText(FLine), 1, FCol);
   tail := Copy(LineText(FLine), FCol + 1, MaxInt);
   parts := TStringList.Create;
   try
      { the parts between line breaks (a trailing break gives an empty part) }
      parts.Text := T;
      if (T <> '') and (T[Length(T)] in [#10, #13]) then parts.Add('');
      if parts.Count = 0 then parts.Add('');
      if parts.Count = 1 then
      begin
         FLines[FLine] := head + parts[0] + tail;
         inc(FCol, Length(parts[0]));
      end
      else
      begin
         FLines[FLine] := head + parts[0];
         for i := 1 to parts.Count - 1 do
            FLines.Insert(FLine + i, parts[i]);
         FLine := FLine + parts.Count - 1;
         FCol := Length(parts[parts.Count - 1]);
         FLines[FLine] := FLines[FLine] + tail;
      end;
   finally
      parts.Free;
   end;
   FALine := FLine;
   FACol := FCol;
end;

procedure TMemo.CopyToClipboard;
begin
   if HasSelection then Clipboard.AsText := SelText;
end;

procedure TMemo.CutToClipboard;
begin
   if FReadOnly or not HasSelection then exit;
   CopyToClipboard;
   ClearSelection;
end;

procedure TMemo.PasteFromClipboard;
var t: string;
    i: integer;
begin
   if FReadOnly or not Clipboard.HasText then exit;
   t := Clipboard.AsText;
   for i := 1 to Length(t) do if t[i] = #9 then t[i] := ' ';
   FLines.BeginUpdate;
   try
      InsertText(t);
   finally
      FLines.EndUpdate;
   end;
   ScrollToCaret;
end;

{---------------------------------------------------------------- keys --}

procedure TMemo.KeyDown(var Key: Word; Shift: TShiftState);
var ext, ctrl: boolean;
    r, l, c: integer;
    s: string;

   procedure Edit(const T: string);
   begin
      FLines.BeginUpdate;
      try
         InsertText(T);
      finally
         FLines.EndUpdate;
      end;
      ScrollToCaret;
      FWantX := FCol - FRows[RowOf(FLine, FCol)].Start;
   end;

begin
   inherited KeyDown(Key, Shift);
   if Key = 0 then exit;
   Layout;
   ext := ssShift in Shift;
   ctrl := ssCtrl in Shift;
   if ssAlt in Shift then exit;
   case Key of
      VK_LEFT:
         begin
            if ctrl then
            begin
               s := LineText(FLine); c := FCol;
               if c = 0 then
               begin
                  if FLine > 0 then MoveTo(FLine - 1, MaxInt, ext);
               end
               else
               begin
                  while (c > 0) and (s[c] = ' ') do dec(c);
                  while (c > 0) and (s[c] <> ' ') do dec(c);
                  MoveTo(FLine, c, ext);
               end;
            end
            else if (FCol = 0) and (FLine > 0) then MoveTo(FLine - 1, MaxInt, ext)
            else MoveTo(FLine, FCol - 1, ext);
            Key := 0;
         end;
      VK_RIGHT:
         begin
            s := LineText(FLine);
            if ctrl then
            begin
               c := FCol + 1;
               if FCol >= Length(s) then
               begin
                  if FLine < FLines.Count - 1 then MoveTo(FLine + 1, 0, ext);
               end
               else
               begin
                  while (c <= Length(s)) and (s[c] <> ' ') do inc(c);
                  while (c <= Length(s)) and (s[c] = ' ') do inc(c);
                  MoveTo(FLine, c - 1, ext);
               end;
            end
            else if (FCol >= Length(s)) and (FLine < FLines.Count - 1) then MoveTo(FLine + 1, 0, ext)
            else MoveTo(FLine, FCol + 1, ext);
            Key := 0;
         end;
      VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT:
         begin
            r := RowOf(FLine, FCol);
            case Key of
               VK_UP:    dec(r);
               VK_DOWN:  inc(r);
               VK_PRIOR: begin dec(r, FTextH - 1); FTopRow := FTopRow - (FTextH - 1); if FTopRow < 0 then FTopRow := 0; end;
               VK_NEXT:  begin inc(r, FTextH - 1); FTopRow := FTopRow + (FTextH - 1); if FTopRow > MaxTop then FTopRow := MaxTop; end;
            end;
            if (r >= 0) and (r < FRowCount) then MoveToRow(r, FWantX, ext)
            else if r < 0 then MoveToRow(0, 0, ext)
            else MoveToRow(FRowCount - 1, MaxInt div 2, ext);
            Key := 0;
         end;
      VK_HOME:
         begin
            if ctrl then MoveTo(0, 0, ext)
            else MoveTo(FLine, FRows[RowOf(FLine, FCol)].Start, ext);
            Key := 0;
         end;
      VK_END:
         begin
            if ctrl then MoveTo(FLines.Count - 1, MaxInt, ext)
            else MoveTo(FLine, RowMaxCol(RowOf(FLine, FCol)), ext);
            Key := 0;
         end;
      VK_RETURN:
         if FWantReturns and not FReadOnly and not ctrl then
         begin
            Edit(LineEnding);
            Key := 0;
         end;
      VK_TAB:
         if FWantTabs and not FReadOnly and not ctrl then
         begin
            Edit(StringOfChar(' ', 8 - FCol mod 8));
            Key := 0;
         end;
      VK_BACK:
         begin
            if not FReadOnly then
               if HasSelection then ClearSelection
               else if (FCol > 0) or (FLine > 0) then
               begin
                  { select the character (or line break) before, delete it }
                  l := FLine; c := FCol;
                  if c > 0 then dec(c) else begin dec(l); c := Length(LineText(l)); end;
                  FALine := l; FACol := c;
                  ClearSelection;
               end;
            FWantX := FCol - FRows[RowOf(FLine, FCol)].Start;
            Key := 0;
         end;
      VK_DELETE:
         begin
            if ssShift in Shift then CutToClipboard
            else if not FReadOnly then
               if HasSelection then ClearSelection
               else
               begin
                  l := FLine; c := FCol;
                  if c < Length(LineText(l)) then inc(c)
                  else if l < FLines.Count - 1 then begin inc(l); c := 0; end;
                  FALine := l; FACol := c;
                  ClearSelection;
               end;
            Key := 0;
         end;
      VK_INSERT:
         begin
            if Shift = [] then TUIInsertMode := not TUIInsertMode
            else if Shift = [ssCtrl] then CopyToClipboard
            else if Shift = [ssShift] then PasteFromClipboard;
            Key := 0;
         end;
   else
      if ctrl then
         case Key of
            VK_A: begin SelectAll; Key := 0; end;
            Ord('C'): begin CopyToClipboard; Key := 0; end;
            Ord('X'): begin CutToClipboard; Key := 0; end;
            Ord('V'): begin PasteFromClipboard; Key := 0; end;
            Ord('Y'):
               begin
                  if not FReadOnly and (FLines.Count > 0) then
                  begin
                     if FLines.Count = 1 then FLines[0] := ''
                     else FLines.Delete(FLine);
                     MoveTo(FLine, 0, false);
                  end;
                  Key := 0;
               end;
         end;
   end;
   Invalidate;
end;

procedure TMemo.KeyPress(var Key: char);
var s: string;
begin
   inherited KeyPress(Key);
   if (Key < ' ') or FReadOnly then exit;
   FLines.BeginUpdate;
   try
      if not TUIInsertMode and not HasSelection and (FCol < Length(LineText(FLine))) then
      begin
         s := LineText(FLine);
         s[FCol + 1] := Key;
         FLines[FLine] := s;
         inc(FCol);
         FALine := FLine; FACol := FCol;
      end
      else
         InsertText(Key);
   finally
      FLines.EndUpdate;
   end;
   ScrollToCaret;
   FWantX := FCol - FRows[RowOf(FLine, FCol)].Start;
   Key := #0;
end;

function TMemo.WantsChars: boolean;
begin
   Result := true;
end;

function TMemo.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
var r: integer;
begin
   Layout;
   r := RowOf(FLine, FCol);
   X := FCol - FRows[r].Start - FLeftCol;
   Y := r - FTopRow;
   if TUIInsertMode then Shape := csLine else Shape := csBlock;
   Result := (X >= 0) and (X < FTextW) and (Y >= 0) and (Y < FTextH);
end;

{--------------------------------------------------------------- mouse --}

procedure TMemo.PosAt(X, Y: integer; out ALine, ACol: integer);
var r, c: integer;
begin
   Layout;
   r := FTopRow + Y;
   if r < 0 then r := 0;
   if r >= FRowCount then r := FRowCount - 1;
   c := FRows[r].Start + FLeftCol + X;
   if X < 0 then c := FRows[r].Start + FLeftCol;
   if c > RowMaxCol(r) then c := RowMaxCol(r);
   ALine := FRows[r].Line;
   ACol := c;
end;

procedure TMemo.DoScrollV(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FTopRow);
      shLineDown: inc(FTopRow);
      shPageUp:   dec(FTopRow, FTextH - 1);
      shPageDown: inc(FTopRow, FTextH - 1);
      shThumb:    FThumbV := true;
   end;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FTopRow < 0 then FTopRow := 0;
   Invalidate;
end;

procedure TMemo.DoScrollH(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FLeftCol);
      shLineDown: inc(FLeftCol);
      shPageUp:   dec(FLeftCol, FTextW - 1);
      shPageDown: inc(FLeftCol, FTextW - 1);
      shThumb:    FThumbH := true;
   end;
   if FLeftCol > MaxLeft then FLeftCol := MaxLeft;
   if FLeftCol < 0 then FLeftCol := 0;
   Invalidate;
end;

procedure TMemo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var l, c: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button <> mbLeft then exit;
   Layout;
   FHoldV := shNone;
   FHoldH := shNone;
   if FVBar and (X = FTextW) and (Y < FTextH) then
   begin
      FHoldV := ScrollHitAt(Y, FTextH, FTopRow, MaxTop);
      DoScrollV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
      exit;
   end;
   if FHBar and (Y = FTextH) and (X < FTextW) then
   begin
      FHoldH := ScrollHitAt(X, FTextW, FLeftCol, MaxLeft);
      DoScrollH(FHoldH);
      if FHoldH = shThumb then FHoldH := shNone;
      exit;
   end;
   if (X >= FTextW) or (Y >= FTextH) then exit;
   PosAt(X, Y, l, c);
   MoveTo(l, c, ssShift in Shift);
   FDragSel := true;
end;

procedure TMemo.MouseMove(Shift: TShiftState; X, Y: integer);
var l, c: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FThumbV then
   begin
      FTopRow := ScrollPosAt(Y, FTextH, MaxTop);
      Invalidate;
   end
   else if FThumbH then
   begin
      FLeftCol := ScrollPosAt(X, FTextW, MaxLeft);
      Invalidate;
   end
   else if FDragSel then
   begin
      { dragging past the edges scrolls }
      if Y < 0 then begin Y := 0; if FTopRow > 0 then dec(FTopRow); end;
      if Y >= FTextH then begin Y := FTextH - 1; if FTopRow < MaxTop then inc(FTopRow); end;
      PosAt(X, Y, l, c);
      MoveTo(l, c, true);
   end;
end;

procedure TMemo.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FDragSel := false;
   FThumbV := false;
   FThumbH := false;
   FHoldV := shNone;
   FHoldH := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TMemo.MouseHeld(X, Y: integer);
begin
   if (FHoldV <> shNone) and (X = FTextW) and (Y < FTextH) and
      (ScrollHitAt(Y, FTextH, FTopRow, MaxTop) = FHoldV) then DoScrollV(FHoldV);
   if (FHoldH <> shNone) and (Y = FTextH) and (X < FTextW) and
      (ScrollHitAt(X, FTextW, FLeftCol, MaxLeft) = FHoldH) then DoScrollH(FHoldH);
end;

{ a double click selects the word under the caret }
procedure TMemo.DblClick;
var s: string;
    a, b: integer;
begin
   inherited DblClick;
   s := LineText(FLine);
   a := FCol;
   b := FCol;
   while (a > 0) and (s[a] <> ' ') do dec(a);
   while (b < Length(s)) and (s[b + 1] <> ' ') do inc(b);
   FALine := FLine;
   FACol := a;
   FCol := b;
   Invalidate;
end;

{--------------------------------------------------------------- paint --}

procedure TMemo.Paint;
var a, sel, sa: byte;
    i, r, l1, c1, l2, c2, sx1, sx2, rs, re: integer;
    row: TMemoRow;
    o: TPoint;
    hasSel: boolean;
begin
   Layout;
   a := Theme.Edit;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a))
   else a := MakeAttr(TextColor(AttrFg(a)), AttrBg(a));
   sel := Theme.EditSelect;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   hasSel := HasSelection;
   if hasSel then SelBounds(l1, c1, l2, c2);
   for i := 0 to FTextH - 1 do
   begin
      r := FTopRow + i;
      if r >= FRowCount then break;
      row := FRows[r];
      Canvas.TextOut(0, i, Copy(LineText(row.Line), row.Start + FLeftCol + 1,
                     Min(row.Len - FLeftCol, FTextW)), a);
      if hasSel and (row.Line >= l1) and (row.Line <= l2) then
      begin
         { the selected columns of this row (a line break shows as a cell) }
         rs := row.Start;
         re := row.Start + row.Len;
         if (r + 1 >= FRowCount) or (FRows[r + 1].Line <> row.Line) then
            if row.Line < l2 then inc(re);
         if row.Line = l1 then sx1 := c1 else sx1 := 0;
         if row.Line = l2 then sx2 := c2 else sx2 := MaxInt;
         if sx1 < rs then sx1 := rs;
         if sx2 > re then sx2 := re;
         if sx2 > sx1 then
            Canvas.SetAttr(Rect(sx1 - rs - FLeftCol, i, sx2 - rs - FLeftCol, i + 1), sel);
      end;
   end;
   { the text area clip keeps the selection off the scroll bars }
   o := ScreenOrigin;
   sa := MakeAttr(AttrFg(Theme.ListScroll), AttrBg(a));
   if FVBar then DrawVScroll(o.X + FTextW, o.Y, FTextH, FTopRow, MaxTop, sa);
   if FHBar then DrawHScroll(o.X, o.Y + FTextH, FTextW, FLeftCol, MaxLeft, sa);
   if FVBar and FHBar then Canvas.PutChar(FTextW, FTextH, ' ', sa);
end;


function TMemo.MouseWheel(WheelDelta: integer): boolean;
begin
   Layout;
   FTopRow := FTopRow - (WheelDelta div 120) * 3;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FTopRow < 0 then FTopRow := 0;
   Invalidate;
   Result := true;
end;

initialization
   RegisterClass(TMemo);
end.
