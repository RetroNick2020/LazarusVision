{-----------------------------------------------------------------------------}
{  TUIHW - all hardware access for the text mode UI (go32v2).                 }
{                                                                             }
{  Everything that touches the PC goes through here: the text video memory,   }
{  the BIOS cursor, int 16h keyboard, int 33h mouse and the idle call. The    }
{  rest of TUI only sees cells (char + attribute words) and cell positions.   }
{                                                                             }
{  Speed: nothing is drawn straight to the screen. TUISCRN keeps a buffer of  }
{  the whole screen and sends only the cells that changed, one row span at a  }
{  time, with HWWriteCells (one dosmemput = one REP MOVS into B800h). The     }
{  keyboard is polled by reading the BIOS buffer head/tail (no real mode      }
{  switch); int 16h is only called when a key is really there. The mouse     }
{  driver's own cursor is never shown: TUISCRN draws it into the buffer, so   }
{  writes to video memory never have to hide and show it (no flicker).       }
{                                                                             }
{  On non-DOS targets (TUIEMU) the screen is an 80x25 array in memory and     }
{  there is no keyboard or mouse: tests feed input through TUIPostKey.        }
{-----------------------------------------------------------------------------}
unit TUIHW;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

const
   {$IFDEF TUIWIN}
   MaxCols  = 240;
   MaxRows  = 100;
   {$ELSE}
   {$IFDEF TUILINUX}
   MaxCols  = 240;
   MaxRows  = 100;
   {$ELSE}
   MaxCols  = 132;
   MaxRows  = 60;
   {$ENDIF}
   {$ENDIF}
   MaxCells = MaxCols * MaxRows;

type
   TCursorShape = (csHidden, csLine, csBlock);

var
   HWCols, HWRows : integer;      { text screen size in cells }
   HWMono         : boolean;      { MDA / Hercules text (B000h) }
   HWMousePresent : boolean;
   HWMouseWheel   : boolean;      { a wheel (CuteMouse 2 wheel API) }
   HWIdleCall     : boolean = true; { release the time slice when idle }
   MoveIsPatched  : boolean;      { see PatchRtlMove }
   HWCellsWritten : longint = 0;  { cells sent to video memory (statistics) }

{ start / end: detect the mode, save the DOS screen, restore it at the end }
procedure HWInit;
procedure HWDone;
{$IFDEF TUIWIN}
  {$DEFINE TUI_EXTERNAL_CONSOLE}
{$ENDIF}
{$IFDEF TUILINUX}
  {$DEFINE TUI_EXTERNAL_CONSOLE}
{$ENDIF}
{$IFDEF TUI_EXTERNAL_CONSOLE}
procedure HWExternalConsoleBegin;
procedure HWExternalConsoleEnd;
{$ENDIF}

{ change the number of text rows (25, 28, 43 or 50; VGA for 28/50). Call   }
{ before HWInit or after it (TUISCRN.ScrSetRows does both).                }
function  HWSetRows(Rows: integer): boolean;
{ columns and rows: 80 x 25/28/43/50 (VGA fonts), 80 x 60 and 132 x 25/43/  }
{ 50/60 (VESA text modes 108h-10Ch, when the card has them)                }
function  HWSetMode(Cols, Rows: integer): boolean;
{ the text mode the BIOS is in now (after another program ran) }
procedure HWCurrentMode(out Cols, Rows: integer);

{ 16 background colours instead of blinking (attribute bit 7) }
procedure HWSetBlink(On: boolean);

{ video memory, in cells from the top left (Ofs = Y * HWCols + X) }
procedure HWWriteCells(Ofs: integer; const Src; Count: integer);
procedure HWReadCells(Ofs: integer; var Dst; Count: integer);

{ the hardware cursor }
procedure HWSetCursor(X, Y: integer; Shape: TCursorShape);

{ keyboard: BIOS key word, high byte scan code, low byte ASCII (0 or $E0   }
{ for extended keys). HWShiftState: BIOS shift bits (1/2 shift, 4 ctrl,    }
{ 8 alt).                                                                   }
function  HWKeyPressed: boolean;
function  HWReadKey: word;
function  HWShiftState: byte;

{ mouse, in cells; Buttons bit 0 left, bit 1 right, bit 2 middle }
function  HWMouseInit: boolean;
procedure HWMouseRead(out X, Y: integer; out Buttons: byte; out Wheel: integer);

{ nothing to do: give the time slice back (Windows, OS/2, DOSEMU...) }
procedure HWIdle;

{ milliseconds, from the BIOS tick count (55 ms steps) }
function  HWTicks: longint;

procedure HWBeep;

{$IFDEF TUIEMU}
{ the emulated screen as text, one string per row (tests) }
function  HWEmuRow(Y: integer): string;
function  HWEmuAttr(X, Y: integer): byte;
var
   HWEmuCursorX, HWEmuCursorY: integer;
   HWEmuCursorShape: TCursorShape;
{$ENDIF}

implementation

{$IFDEF GO32V2}
uses go32;
{$ELSE}
  {$IFDEF TUIWIN}
uses SysUtils;
  {$ENDIF}
  {$IFDEF TUILINUX}
uses SysUtils, BaseUnix, Unix, Process;
  {$ENDIF}
{$ENDIF}

{$IFDEF GO32V2}
{=============================================================================}
{  DOS (go32v2)                                                               }
{=============================================================================}
var
   VidSeg     : word;       { B800h colour, B000h mono }
   VidOfs     : word;       { start of the visible page }
   CharHeight : integer;    { scan lines per character (cursor shape) }
   OldMode    : byte;
   OldRows    : integer;
   OldCurPos  : word;
   OldCurShape: word;
   SavedScreen: array of word;
   SavedCols, SavedRows: integer;
   RowsChanged: boolean;
   BlinkChanged: boolean;
   LastCurX, LastCurY: integer;
   LastShape  : TCursorShape;

procedure ClearRegs(out R: trealregs); inline;
begin
   FillChar(R, SizeOf(R), 0);
end;

function BiosByte(Ofs: word): byte;
begin
   dosmemget($40, Ofs, Result, 1);
end;

function BiosWord(Ofs: word): word;
begin
   dosmemget($40, Ofs, Result, 2);
end;

{-- FPC's Move copies blocks over 36 bytes with x87 FILD/FISTP when the  --}
{-- CPU has no SSE; DOSBox keeps 53 bits there and corrupts strings and  --}
{-- buffers (one byte in eight). Same fix as FPTEGL's TGHW: point Move's --}
{-- large block routines at REP MOVS versions.                           --}
{$ASMMODE ATT}
procedure SafeMoveForward; assembler; nostackframe;
asm
   pushl  %esi
   pushl  %edi
   movl   %eax,%esi
   movl   %edx,%edi
   movl   %ecx,%edx
   cld
   shrl   $2,%ecx
   rep
   movsl
   movl   %edx,%ecx
   andl   $3,%ecx
   rep
   movsb
   popl   %edi
   popl   %esi
end;

procedure SafeMoveBackward; assembler; nostackframe;
asm
   pushl  %esi
   pushl  %edi
   leal   -1(%eax,%ecx),%esi
   leal   -1(%edx,%ecx),%edi
   std
   rep
   movsb
   cld
   popl   %edi
   popl   %esi
end;

procedure PatchRtlMove;
type PPtr = ^pointer;
var code : PByte;
    i, n : integer;
    slot : array[0..1] of PPtr;
begin
   MoveIsPatched := false;
   code := PByte(@System.Move);
   n := 0;
   for i := 0 to 95 do
      if (code[i] = $FF) and (code[i+1] = $25) then
      begin
         if n < 2 then slot[n] := PPtr(PPtr(@code[i+2])^);
         inc(n);
      end;
   if n <> 2 then exit;
   slot[0]^ := @SafeMoveForward;
   slot[1]^ := @SafeMoveBackward;
   MoveIsPatched := true;
end;

procedure ReadMode;
var r: trealregs;
begin
   ClearRegs(r);
   r.ah := $0F;
   realintr($10, r);
   HWMono := (r.al = 7);
   HWCols := r.ah;
   if HWCols < 40 then HWCols := 80;
   if HWCols > MaxCols then HWCols := MaxCols;
   { rows - 1 is in the BIOS data area on EGA and later; 0 = CGA/MDA }
   HWRows := BiosByte($84) + 1;
   if (HWRows < 25) or (HWRows > MaxRows) then HWRows := 25;
   CharHeight := BiosWord($85);
   if (CharHeight < 8) or (CharHeight > 16) then
      if HWMono then CharHeight := 14 else CharHeight := 8;
   if HWMono then VidSeg := $B000 else VidSeg := $B800;
   VidOfs := BiosWord($4E);
end;

function HWSetRows(Rows: integer): boolean;
var r: trealregs;
begin
   Result := false;
   if HWMono then exit;
   ClearRegs(r);
   r.ax := $0003;                       { 80x25 colour, clears the screen }
   realintr($10, r);
   case Rows of
      28: begin ClearRegs(r); r.ax := $1111; r.bl := 0; realintr($10, r); end; { 8x14 font }
      43, 50: begin ClearRegs(r); r.ax := $1112; r.bl := 0; realintr($10, r); end; { 8x8 font }
   end;
   RowsChanged := true;
   ReadMode;
   { the 8x8 font leaves the BIOS cursor shape odd on some cards }
   LastShape := csBlock;
   HWSetCursor(0, 0, csHidden);
   Result := (HWRows = Rows) or ((Rows = 50) and (HWRows = 43));
end;

function HWSetMode(Cols, Rows: integer): boolean;
var r: trealregs;
    m: word;
begin
   Result := false;
   if HWMono then exit;
   if (Cols <= 80) and (Rows <> 60) then exit(HWSetRows(Rows));
   if Cols <= 80 then m := $108
   else
      case Rows of
         43: m := $10A;
         50: m := $10B;
         60: m := $10C;
      else
         m := $109;
      end;
   ClearRegs(r);
   r.ax := $4F02;                       { VESA: set mode }
   r.bx := m;
   realintr($10, r);
   if r.ax <> $004F then
   begin
      { no VESA text mode: the S3 / Cirrus BIOS modes 55h (132 x 25) and }
      { 54h (132 x 43) that many cards (and DOSBox) have                 }
      if (Cols <= 80) or not (Rows in [25, 43]) then exit;
      ClearRegs(r);
      if Rows = 25 then r.ax := $0055 else r.ax := $0054;
      realintr($10, r);
      ReadMode;
      if HWCols <> Cols then
      begin
         HWSetRows(25);
         exit;
      end;
   end;
   RowsChanged := true;
   ReadMode;
   LastShape := csBlock;
   HWSetCursor(0, 0, csHidden);
   Result := (HWCols = Cols) and (HWRows = Rows);
end;

procedure HWCurrentMode(out Cols, Rows: integer);
begin
   Cols := BiosWord($4A);
   Rows := BiosByte($84) + 1;
   if (Rows < 25) or (Rows > MaxRows) then Rows := 25;
   if (Cols < 40) or (Cols > MaxCols) then Cols := 80;
end;

procedure HWSetBlink(On: boolean);
var r: trealregs;
begin
   ClearRegs(r);
   r.ax := $1003;
   if On then r.bl := 1 else r.bl := 0;
   realintr($10, r);
   BlinkChanged := not On;
end;

procedure HWWriteCells(Ofs: integer; const Src; Count: integer);
begin
   if Count > 0 then
   begin
      dosmemput(VidSeg, VidOfs + Ofs * 2, (@Src)^, Count * 2);
      inc(HWCellsWritten, Count);
   end;
end;

procedure HWReadCells(Ofs: integer; var Dst; Count: integer);
begin
   if Count > 0 then
      dosmemget(VidSeg, VidOfs + Ofs * 2, Dst, Count * 2);
end;

procedure HWSetCursor(X, Y: integer; Shape: TCursorShape);
var r: trealregs;
begin
   if Shape <> LastShape then
   begin
      ClearRegs(r);
      r.ah := $01;
      case Shape of
         csHidden: r.cx := $2000;
         csLine:   begin r.ch := CharHeight - 2; r.cl := CharHeight - 1; end;
         csBlock:  begin r.ch := 0;              r.cl := CharHeight - 1; end;
      end;
      realintr($10, r);
      LastShape := Shape;
   end;
   if (Shape <> csHidden) and ((X <> LastCurX) or (Y <> LastCurY)) then
   begin
      ClearRegs(r);
      r.ah := $02;
      r.bh := 0;
      r.dl := X;
      r.dh := Y;
      realintr($10, r);
      LastCurX := X;
      LastCurY := Y;
   end;
end;

function HWKeyPressed: boolean;
var ht: array[0..1] of word;
begin
   { BIOS keyboard buffer head and tail: equal = empty }
   dosmemget($40, $1A, ht, 4);
   Result := ht[0] <> ht[1];
end;

function HWReadKey: word;
var r: trealregs;
begin
   ClearRegs(r);
   r.ah := $10;                         { enhanced keyboard read }
   realintr($16, r);
   Result := r.ax;
end;

function HWShiftState: byte;
begin
   Result := BiosByte($17);
end;

function HWMouseInit: boolean;
var r: trealregs;
begin
   ClearRegs(r);
   r.ax := $0000;
   realintr($33, r);
   HWMousePresent := r.ax = $FFFF;
   if HWMousePresent then
   begin
      { cell = pixel div 8 in text modes; set the range for the row count }
      ClearRegs(r); r.ax := $0007; r.cx := 0; r.dx := HWCols * 8 - 1; realintr($33, r);
      ClearRegs(r); r.ax := $0008; r.cx := 0; r.dx := HWRows * 8 - 1; realintr($33, r);
      { the driver's cursor stays hidden: TUISCRN draws its own }
      { CuteMouse 2: function 11h switches the wheel on, 'WM' in AX }
      ClearRegs(r); r.ax := $0011; realintr($33, r);
      HWMouseWheel := (r.ax = $574D) and (r.cx and 1 <> 0);
   end;
   Result := HWMousePresent;
end;

procedure HWMouseRead(out X, Y: integer; out Buttons: byte; out Wheel: integer);
var r: trealregs;
begin
   Wheel := 0;
   if not HWMousePresent then
   begin
      X := 0; Y := 0; Buttons := 0;
      exit;
   end;
   ClearRegs(r);
   r.ax := $0003;
   realintr($33, r);
   X := r.cx div 8;
   Y := r.dx div 8;
   if X >= HWCols then X := HWCols - 1;
   if Y >= HWRows then Y := HWRows - 1;
   Buttons := r.bl and 7;
   { the wheel's movement since the last call, negative = away (up) }
   if HWMouseWheel then Wheel := shortint(r.bh);
end;

procedure HWIdle;
var r: trealregs;
begin
   if not HWIdleCall then exit;
   ClearRegs(r);
   r.ax := $1680;                       { release current VM time slice }
   realintr($2F, r);
   if r.al = $80 then HWIdleCall := false; { not supported: stop asking }
end;

function HWTicks: longint;
var t: longint;
begin
   dosmemget($40, $6C, t, 4);
   Result := t * 55;
end;

procedure HWBeep;
begin
   write(#7);
end;

procedure HWInit;
var r: trealregs;
begin
   ReadMode;
   OldMode := 0;
   OldRows := HWRows;
   ClearRegs(r);
   r.ah := $03;
   r.bh := 0;
   realintr($10, r);
   OldCurPos := r.dx;
   OldCurShape := r.cx;
   SavedCols := HWCols;
   SavedRows := HWRows;
   SetLength(SavedScreen, SavedCols * SavedRows);
   HWReadCells(0, SavedScreen[0], SavedCols * SavedRows);
   LastCurX := -1;
   LastCurY := -1;
   LastShape := csLine;
   HWSetCursor(0, 0, csHidden);
   HWMouseInit;
end;

procedure HWDone;
var r: trealregs;
begin
   if HWMousePresent then
   begin
      ClearRegs(r);
      r.ax := $0000;                    { reset: leaves the cursor hidden }
      realintr($33, r);
   end;
   if BlinkChanged then HWSetBlink(true);
   if RowsChanged then
      HWSetRows(OldRows);               { back to the rows DOS had }
   if (HWCols = SavedCols) and (HWRows = SavedRows) and (Length(SavedScreen) > 0) then
      HWWriteCells(0, SavedScreen[0], SavedCols * SavedRows);
   ClearRegs(r);
   r.ah := $01;
   r.cx := OldCurShape;
   realintr($10, r);
   ClearRegs(r);
   r.ah := $02;
   r.bh := 0;
   r.dx := OldCurPos;
   realintr($10, r);
   SetLength(SavedScreen, 0);
end;

{$ELSE}
{$IFDEF TUIWIN}
{$I TUIHW_WIN.INC}
{$ELSE}
{$IFDEF TUILINUX}
{$I TUIHW_LINUX.INC}
{$ELSE}
{=============================================================================}
{  Emulation (tests on other targets)                                         }
{=============================================================================}
var
   EmuScreen: array[0..MaxCells - 1] of word;

function HWSetRows(Rows: integer): boolean;
begin
   HWCols := 80;
   if (Rows >= 25) and (Rows <= MaxRows) then HWRows := Rows;
   FillWord(EmuScreen, MaxCells, $0720);
   Result := HWRows = Rows;
end;

function HWSetMode(Cols, Rows: integer): boolean;
begin
   Result := false;
   if (Cols < 40) or (Cols > MaxCols) or (Rows < 25) or (Rows > MaxRows) then exit;
   HWCols := Cols;
   HWRows := Rows;
   FillWord(EmuScreen, MaxCells, $0720);
   Result := true;
end;

procedure HWCurrentMode(out Cols, Rows: integer);
begin
   Cols := HWCols;
   Rows := HWRows;
end;

procedure HWSetBlink(On: boolean);
begin
end;

procedure HWWriteCells(Ofs: integer; const Src; Count: integer);
var p: PWord;
    i: integer;
begin
   p := PWord(@Src);
   inc(HWCellsWritten, Count);
   for i := 0 to Count - 1 do
   begin
      EmuScreen[Ofs + i] := p^;
      inc(p);
   end;
end;

procedure HWReadCells(Ofs: integer; var Dst; Count: integer);
var p: PWord;
    i: integer;
begin
   p := PWord(@Dst);
   for i := 0 to Count - 1 do
   begin
      p^ := EmuScreen[Ofs + i];
      inc(p);
   end;
end;

procedure HWSetCursor(X, Y: integer; Shape: TCursorShape);
begin
   HWEmuCursorX := X;
   HWEmuCursorY := Y;
   HWEmuCursorShape := Shape;
end;

function HWKeyPressed: boolean;
begin
   Result := false;
end;

function HWReadKey: word;
begin
   Result := 0;
end;

function HWShiftState: byte;
begin
   Result := 0;
end;

function HWMouseInit: boolean;
begin
   HWMousePresent := false;
   Result := false;
end;

procedure HWMouseRead(out X, Y: integer; out Buttons: byte; out Wheel: integer);
begin
   X := 0; Y := 0; Buttons := 0; Wheel := 0;
end;

procedure HWIdle;
begin
end;

var EmuTicks: longint;

function HWTicks: longint;
begin
   inc(EmuTicks, 55);
   Result := EmuTicks;
end;

procedure HWBeep;
begin
end;

procedure HWInit;
begin
   HWCols := 80;
   HWRows := 25;
   HWMono := false;
   FillWord(EmuScreen, MaxCells, $0720);
   HWMouseInit;
end;

procedure HWDone;
begin
end;

function HWEmuRow(Y: integer): string;
var x: integer;
begin
   SetLength(Result, HWCols);
   for x := 0 to HWCols - 1 do
      Result[x + 1] := char(EmuScreen[Y * HWCols + x] and $FF);
end;

function HWEmuAttr(X, Y: integer): byte;
begin
   Result := EmuScreen[Y * HWCols + X] shr 8;
end;
{$ENDIF} { TUILINUX / emulator }
{$ENDIF} { TUIWIN / others }
{$ENDIF} { GO32V2 }

initialization
   HWCols := 80;
   HWRows := 25;
{$IFDEF GO32V2}
   PatchRtlMove;
{$ELSE}
   MoveIsPatched := false;
{$ENDIF}
end.
