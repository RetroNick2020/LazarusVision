{-----------------------------------------------------------------------------}
{  TUISCRN - the text screen buffer and its drawing routines.                 }
{                                                                             }
{  All drawing goes into Cells (char in the low byte, attribute in the high   }
{  byte), clipped to the current clip rectangle. Each row remembers the span  }
{  of columns written since the last ScrFlush. ScrFlush compares that span    }
{  with what is on the screen (Vis) and sends only the cells that differ.     }
{  So repainting a whole form that did not change costs no video writes at    }
{  all, and typing one character into an edit field sends one cell.          }
{                                                                             }
{  The mouse cursor is drawn here (attribute inverted at flush time), so the  }
{  buffer itself never contains it.                                           }
{                                                                             }
{  Box styles follow Technojock's Object Toolkit (totFAST.BoxEngine):         }
{     0 none (spaces)  1 single  2 double  3 double sides  4 double top/bottom }
{     5 single top-left, double bottom-right (TOT's "3d" button look)         }
{  Rectangles are TRect with Right/Bottom exclusive, as in the LCL.           }
{-----------------------------------------------------------------------------}
unit TUIScrn;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Types, TUIHW;

const
   { colours (attribute nibbles) }
   tcBlack = 0; tcBlue = 1; tcGreen = 2; tcCyan = 3; tcRed = 4; tcMagenta = 5;
   tcBrown = 6; tcLightGray = 7; tcDarkGray = 8; tcLightBlue = 9;
   tcLightGreen = 10; tcLightCyan = 11; tcLightRed = 12; tcLightMagenta = 13;
   tcYellow = 14; tcWhite = 15;

   { CP437 box/shade characters used by the controls }
   chShadeLight = #176; chShadeMedium = #177; chShadeDark = #178;
   chBlock = #219; chHalfDown = #220; chHalfUp = #223;
   chArrowRight = #16; chArrowLeft = #17; chArrowUp = #30; chArrowDown = #31;
   chBullet = #7; chSquare = #254; chCheck = #251;

var
   ScrCols, ScrRows : integer;
   Cells : array[0..MaxCells - 1] of word;  { what the program drew }
   ShadowAttr : byte = $08;                 { dark gray on black }

function  MakeAttr(Fg, Bg: byte): byte; inline;
function  AttrFg(A: byte): byte; inline;
function  AttrBg(A: byte): byte; inline;

procedure ScrInit;
procedure ScrDone;
{ change the text rows (25/28/43/50) after ScrInit; everything is resent }
function  ScrSetRows(Rows: integer): boolean;
{ columns and rows (see HWSetMode) after ScrInit; everything is resent }
function  ScrSetMode(Cols, Rows: integer): boolean;
function  ScrRect: TRect;

{ clipping (screen coordinates, Right/Bottom exclusive) }
procedure ScrSetClip(const R: TRect);
procedure ScrClipAll;
function  ScrGetClip: TRect;

{ drawing; X, Y are screen cells; everything is clipped }
procedure ScrPutChar(X, Y: integer; Ch: char; Attr: byte);
procedure ScrPutStr(X, Y: integer; const S: string; Attr: byte);
{ '&' marks the access key, drawn in HotAttr ('&&' is a plain '&');       }
{ returns the number of cells written                                    }
function  ScrPutAccel(X, Y: integer; const S: string; Attr, HotAttr: byte): integer;
procedure ScrFill(const R: TRect; Ch: char; Attr: byte);
procedure ScrSetAttr(const R: TRect; Attr: byte);    { keep the chars }
procedure ScrHLine(X1, X2, Y: integer; Ch: char; Attr: byte);
procedure ScrVLine(X, Y1, Y2: integer; Ch: char; Attr: byte);
procedure ScrBox(const R: TRect; Style: integer; Attr: byte);
{ TOT style see-through shadow: the cells keep their chars and get        }
{ ShadowAttr (no colour: shadows are skipped on mono screens)             }
procedure ScrShadow(const R: TRect);
{ the shadow of a window: 2 columns on the right, 1 row below }
procedure ScrWindowShadow(const W: TRect);
function  ScrGetCell(X, Y: integer): word;

{ text without '&' markers and its width }
function  StripAccel(const S: string): string;
function  AccelChar(const S: string): char;          { upper case, #0 = none }

{ mouse cursor and hardware cursor, applied by ScrFlush }
procedure ScrSetMouse(X, Y: integer; Visible: boolean);
procedure ScrSetCursor(X, Y: integer; Shape: TCursorShape);

{ send the changed cells to the screen }
procedure ScrFlush;
{ forget what is on the screen: the next flush sends everything }
procedure ScrResend;

implementation

var
   Vis   : array[0..MaxCells - 1] of word;    { what is on the screen now }
   DirtyL, DirtyR : array[0..MaxRows - 1] of integer;  { R exclusive }
   ClipL, ClipT, ClipR, ClipB : integer;
   MouseX, MouseY : integer;
   MouseOn : boolean;
   CurX, CurY : integer;
   CurShape : TCursorShape;
   Started : boolean;

const
   BoxChars: array[1..5] of string[8] = (
      { TL  T   TR  L   R   BL  B   BR }
      #218#196#191#179#179#192#196#217,       { single }
      #201#205#187#186#186#200#205#188,       { double }
      #214#196#183#186#186#211#196#189,       { double sides }
      #213#205#184#179#179#212#205#190,       { double top/bottom }
      #218#196#183#179#186#212#205#188);      { single TL, double BR }

function MakeAttr(Fg, Bg: byte): byte; inline;
begin
   Result := (Fg and 15) or ((Bg and 15) shl 4);
end;

function AttrFg(A: byte): byte; inline;
begin
   Result := A and 15;
end;

function AttrBg(A: byte): byte; inline;
begin
   Result := A shr 4;
end;

procedure MarkDirty(Y, X1, X2: integer); inline;   { X2 exclusive }
begin
   if X1 < DirtyL[Y] then DirtyL[Y] := X1;
   if X2 > DirtyR[Y] then DirtyR[Y] := X2;
end;

procedure ResetDirty;
var y: integer;
begin
   for y := 0 to MaxRows - 1 do
   begin
      DirtyL[y] := MaxInt;
      DirtyR[y] := -1;
   end;
end;

procedure ScrClipAll;
begin
   ClipL := 0; ClipT := 0; ClipR := ScrCols; ClipB := ScrRows;
end;

procedure ScrSetClip(const R: TRect);
begin
   ClipL := R.Left; ClipT := R.Top; ClipR := R.Right; ClipB := R.Bottom;
   if ClipL < 0 then ClipL := 0;
   if ClipT < 0 then ClipT := 0;
   if ClipR > ScrCols then ClipR := ScrCols;
   if ClipB > ScrRows then ClipB := ScrRows;
end;

function ScrGetClip: TRect;
begin
   Result := Rect(ClipL, ClipT, ClipR, ClipB);
end;

function ScrRect: TRect;
begin
   Result := Rect(0, 0, ScrCols, ScrRows);
end;

procedure ScrInit;
var i: integer;
begin
   HWInit;
   ScrCols := HWCols;
   ScrRows := HWRows;
   { start from what DOS left on the screen: the first flush only sends }
   { the cells the program really changes                               }
   HWReadCells(0, Vis[0], ScrCols * ScrRows);
   for i := 0 to ScrCols * ScrRows - 1 do Cells[i] := Vis[i];
   ResetDirty;
   ScrClipAll;
   MouseOn := false;
   MouseX := 0; MouseY := 0;
   CurShape := csHidden;
   CurX := 0; CurY := 0;
   Started := true;
end;

procedure ScrDone;
begin
   if not Started then exit;
   Started := false;
   HWDone;
end;

procedure ScrResend;
var i: integer;
begin
   for i := 0 to ScrCols * ScrRows - 1 do Vis[i] := not Cells[i];
   for i := 0 to ScrRows - 1 do MarkDirty(i, 0, ScrCols);
end;

function ScrSetMode(Cols, Rows: integer): boolean;
begin
   Result := HWSetMode(Cols, Rows);
   ScrCols := HWCols;
   ScrRows := HWRows;
   HWMouseInit;
   ScrClipAll;
   FillWord(Cells, MaxCells, $0720);
   ScrResend;
end;

function ScrSetRows(Rows: integer): boolean;
begin
   Result := HWSetRows(Rows);
   ScrCols := HWCols;
   ScrRows := HWRows;
   HWMouseInit;                       { new vertical range }
   ScrClipAll;
   FillWord(Cells, MaxCells, $0720);
   ScrResend;
end;

procedure ScrPutChar(X, Y: integer; Ch: char; Attr: byte);
begin
   if (X < ClipL) or (X >= ClipR) or (Y < ClipT) or (Y >= ClipB) then exit;
   Cells[Y * ScrCols + X] := byte(Ch) or (word(Attr) shl 8);
   MarkDirty(Y, X, X + 1);
end;

procedure ScrPutStr(X, Y: integer; const S: string; Attr: byte);
var i, x1, x2, base: integer;
    a: word;
begin
   if (Y < ClipT) or (Y >= ClipB) then exit;
   x1 := X;
   x2 := X + Length(S);
   if x1 < ClipL then x1 := ClipL;
   if x2 > ClipR then x2 := ClipR;
   if x1 >= x2 then exit;
   a := word(Attr) shl 8;
   base := Y * ScrCols;
   for i := x1 to x2 - 1 do
      Cells[base + i] := byte(S[i - X + 1]) or a;
   MarkDirty(Y, x1, x2);
end;

function ScrPutAccel(X, Y: integer; const S: string; Attr, HotAttr: byte): integer;
var i, n: integer;
    hot: boolean;
begin
   n := 0;
   i := 1;
   while i <= Length(S) do
   begin
      hot := false;
      if S[i] = '&' then
      begin
         if (i < Length(S)) and (S[i + 1] <> '&') then hot := true;
         inc(i);
         if i > Length(S) then break;
      end;
      if hot then ScrPutChar(X + n, Y, S[i], HotAttr)
      else ScrPutChar(X + n, Y, S[i], Attr);
      inc(n);
      inc(i);
   end;
   Result := n;
end;

procedure ScrFill(const R: TRect; Ch: char; Attr: byte);
var x, y, x1, x2, y1, y2, base: integer;
    w: word;
begin
   x1 := R.Left; if x1 < ClipL then x1 := ClipL;
   x2 := R.Right; if x2 > ClipR then x2 := ClipR;
   y1 := R.Top; if y1 < ClipT then y1 := ClipT;
   y2 := R.Bottom; if y2 > ClipB then y2 := ClipB;
   if (x1 >= x2) or (y1 >= y2) then exit;
   w := byte(Ch) or (word(Attr) shl 8);
   for y := y1 to y2 - 1 do
   begin
      base := y * ScrCols;
      for x := x1 to x2 - 1 do Cells[base + x] := w;
      MarkDirty(y, x1, x2);
   end;
end;

procedure ScrSetAttr(const R: TRect; Attr: byte);
var x, y, x1, x2, y1, y2, base: integer;
    a: word;
begin
   x1 := R.Left; if x1 < ClipL then x1 := ClipL;
   x2 := R.Right; if x2 > ClipR then x2 := ClipR;
   y1 := R.Top; if y1 < ClipT then y1 := ClipT;
   y2 := R.Bottom; if y2 > ClipB then y2 := ClipB;
   if (x1 >= x2) or (y1 >= y2) then exit;
   a := word(Attr) shl 8;
   for y := y1 to y2 - 1 do
   begin
      base := y * ScrCols;
      for x := x1 to x2 - 1 do
         Cells[base + x] := (Cells[base + x] and $FF) or a;
      MarkDirty(y, x1, x2);
   end;
end;

procedure ScrHLine(X1, X2, Y: integer; Ch: char; Attr: byte);
begin
   ScrFill(Rect(X1, Y, X2, Y + 1), Ch, Attr);
end;

procedure ScrVLine(X, Y1, Y2: integer; Ch: char; Attr: byte);
begin
   ScrFill(Rect(X, Y1, X + 1, Y2), Ch, Attr);
end;

procedure ScrBox(const R: TRect; Style: integer; Attr: byte);
var c: string[8];
    x2, y2: integer;
begin
   if (R.Right - R.Left < 2) or (R.Bottom - R.Top < 2) then exit;
   if (Style < 1) or (Style > 5) then c := '        '
   else c := BoxChars[Style];
   x2 := R.Right - 1;
   y2 := R.Bottom - 1;
   ScrPutChar(R.Left, R.Top, c[1], Attr);
   ScrHLine(R.Left + 1, x2, R.Top, c[2], Attr);
   ScrPutChar(x2, R.Top, c[3], Attr);
   ScrVLine(R.Left, R.Top + 1, y2, c[4], Attr);
   ScrVLine(x2, R.Top + 1, y2, c[5], Attr);
   ScrPutChar(R.Left, y2, c[6], Attr);
   ScrHLine(R.Left + 1, x2, y2, c[7], Attr);
   ScrPutChar(x2, y2, c[8], Attr);
end;

procedure ScrShadow(const R: TRect);
begin
   if HWMono then exit;
   ScrSetAttr(R, ShadowAttr);
end;

procedure ScrWindowShadow(const W: TRect);
begin
   ScrShadow(Rect(W.Right, W.Top + 1, W.Right + 2, W.Bottom + 1));
   ScrShadow(Rect(W.Left + 2, W.Bottom, W.Right, W.Bottom + 1));
end;

function ScrGetCell(X, Y: integer): word;
begin
   if (X < 0) or (Y < 0) or (X >= ScrCols) or (Y >= ScrRows) then Result := $0720
   else Result := Cells[Y * ScrCols + X];
end;

function StripAccel(const S: string): string;
var i: integer;
begin
   Result := '';
   i := 1;
   while i <= Length(S) do
   begin
      if S[i] = '&' then
      begin
         inc(i);
         if i > Length(S) then break;
      end;
      Result := Result + S[i];
      inc(i);
   end;
end;

function AccelChar(const S: string): char;
var i: integer;
begin
   Result := #0;
   i := 1;
   while i < Length(S) do
   begin
      if S[i] = '&' then
      begin
         if S[i + 1] <> '&' then
         begin
            Result := UpCase(S[i + 1]);
            exit;
         end;
         inc(i);
      end;
      inc(i);
   end;
end;

procedure ScrSetMouse(X, Y: integer; Visible: boolean);
begin
   if (X = MouseX) and (Y = MouseY) and (Visible = MouseOn) then exit;
   if MouseOn then MarkDirty(MouseY, MouseX, MouseX + 1);
   MouseX := X;
   MouseY := Y;
   MouseOn := Visible;
   if MouseOn then MarkDirty(MouseY, MouseX, MouseX + 1);
end;

procedure ScrSetCursor(X, Y: integer; Shape: TCursorShape);
begin
   CurX := X;
   CurY := Y;
   CurShape := Shape;
end;

procedure ScrFlush;
var y, x, l, r, base, first, last: integer;
    tmp: array[0..MaxCols - 1] of word;
    w: word;
begin
   for y := 0 to ScrRows - 1 do
   begin
      l := DirtyL[y];
      r := DirtyR[y];
      if l >= r then continue;
      DirtyL[y] := MaxInt;
      DirtyR[y] := -1;
      if l < 0 then l := 0;
      if r > ScrCols then r := ScrCols;
      base := y * ScrCols;
      first := -1;
      last := -1;
      for x := l to r - 1 do
      begin
         w := Cells[base + x];
         if MouseOn and (y = MouseY) and (x = MouseX) then
            w := w xor $7700;           { the mouse cursor: inverted colours }
         tmp[x] := w;
         if w <> Vis[base + x] then
         begin
            if first < 0 then first := x;
            last := x;
         end;
      end;
      if first < 0 then continue;
      for x := first to last do Vis[base + x] := tmp[x];
      HWWriteCells(base + first, tmp[first], last - first + 1);
   end;
   HWSetCursor(CurX, CurY, CurShape);
end;

initialization
   ScrCols := 80;
   ScrRows := 25;
   ResetDirty;
   ScrClipAll;
finalization
   ScrDone;
end.
