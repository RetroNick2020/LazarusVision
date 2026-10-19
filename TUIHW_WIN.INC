{ Win32 console implementation of TUIHW. Included in implementation section. }
{ CHAR_INFO is 4 bytes (2-byte character union + 2-byte attribute). }
type
  TWinCoord = packed record X, Y: SmallInt; end;
  TWinRect = packed record Left, Top, Right, Bottom: SmallInt; end;
  TWinScreenInfo = packed record
    Size, CursorPosition: TWinCoord;
    Attributes: Word;
    Window: TWinRect;
    MaximumWindowSize: TWinCoord;
  end;
  TWinCursorInfo = packed record Size: LongWord; Visible: LongBool; end;
  TWinCharInfo = packed record C: Word; Attr: Word; end;
  TWinKeyEvent = packed record
    Down: LongBool; RepeatCount, VK, Scan, Ch: Word; State: LongWord;
  end;
  TWinMouseEvent = packed record
    Position: TWinCoord; ButtonState, ControlState, EventFlags: LongWord;
  end;
  TWinInputRecord = packed record
    EventType, Padding: Word;
    case Byte of
      0: (Key: TWinKeyEvent);
      1: (Mouse: TWinMouseEvent);
  end;

function WinGetStdHandle(Which: LongInt): PtrUInt; stdcall; external 'kernel32.dll' name 'GetStdHandle';
function WinGetConsoleMode(H: PtrUInt; var Mode: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'GetConsoleMode';
function WinSetConsoleMode(H: PtrUInt; Mode: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'SetConsoleMode';
function WinGetConsoleOutputCP: LongWord; stdcall; external 'kernel32.dll' name 'GetConsoleOutputCP';
function WinSetConsoleOutputCP(CP: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'SetConsoleOutputCP';
function WinGetScreenInfo(H: PtrUInt; var Info: TWinScreenInfo): LongBool; stdcall; external 'kernel32.dll' name 'GetConsoleScreenBufferInfo';
function WinReadOutput(H: PtrUInt; Buffer: Pointer; Size, Origin: TWinCoord; var Region: TWinRect): LongBool; stdcall; external 'kernel32.dll' name 'ReadConsoleOutputA';
function WinWriteOutput(H: PtrUInt; Buffer: Pointer; Size, Origin: TWinCoord; var Region: TWinRect): LongBool; stdcall; external 'kernel32.dll' name 'WriteConsoleOutputA';
function WinSetCursorInfo(H: PtrUInt; const Info: TWinCursorInfo): LongBool; stdcall; external 'kernel32.dll' name 'SetConsoleCursorInfo';
function WinGetCursorInfo(H: PtrUInt; var Info: TWinCursorInfo): LongBool; stdcall; external 'kernel32.dll' name 'GetConsoleCursorInfo';
function WinSetCursorPos(H: PtrUInt; Pos: TWinCoord): LongBool; stdcall; external 'kernel32.dll' name 'SetConsoleCursorPosition';
function WinPeekInput(H: PtrUInt; var Buffer: TWinInputRecord; Count: LongWord; var ReadCount: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'PeekConsoleInputW';
function WinReadInput(H: PtrUInt; var Buffer: TWinInputRecord; Count: LongWord; var ReadCount: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'ReadConsoleInputW';
function WinGetTickCount: LongWord; stdcall; external 'kernel32.dll' name 'GetTickCount';
procedure WinSleep(Millis: LongWord); stdcall; external 'kernel32.dll' name 'Sleep';
function WinBeep(Frequency, Duration: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'Beep';

var
  WinIn, WinOut: PtrUInt;
  WinInMode, WinOutMode, WinOldCP: LongWord;
  WinOldInfo: TWinScreenInfo;
  WinOldCursor: TWinCursorInfo;
  WinSaved: array of TWinCharInfo;
  WinStarted: Boolean = false;
  WinOriginX, WinOriginY: Integer;
  WinMouseX, WinMouseY: Integer;
  WinButtons: Byte;
  WinWheel: Integer;
  WinShift: Byte;
  WinQueue: array[0..255] of Word;
  WinQHead, WinQTail: Integer;
  { Cache only successful native cursor updates.  Console children can alter
    cursor state, so invalidate whenever we hand the console away/back. }
  WinCursorInfoValid, WinCursorPosValid: Boolean;
  WinLastCursorVisible: Boolean;
  WinLastCursorSize: LongWord;
  WinLastCursorX, WinLastCursorY: Integer;

function WinCoord(X, Y: Integer): TWinCoord;
begin
  Result.X := X; Result.Y := Y;
end;

function WinRect(X1, Y1, X2, Y2: Integer): TWinRect;
begin
  Result.Left := X1; Result.Top := Y1;
  Result.Right := X2; Result.Bottom := Y2;
end;

procedure WinQueueKey(K: Word);
var Next: Integer;
begin
  Next := (WinQTail + 1) and 255;
  if Next <> WinQHead then begin
    WinQueue[WinQTail] := K;
    WinQTail := Next;
  end;
end;

procedure WinPoll;
var E: TWinInputRecord; N: LongWord; K: Word; A, Scan: Byte; Rep, J: Integer;
begin
  if not WinStarted then Exit;
  while WinPeekInput(WinIn, E, 1, N) and (N <> 0) do begin
    if not WinReadInput(WinIn, E, 1, N) or (N = 0) then Break;
    case E.EventType of
      1: begin
        WinShift := 0;
        if (E.Key.State and $0010) <> 0 then WinShift := WinShift or 1;
        if (E.Key.State and $0008) <> 0 then WinShift := WinShift or 2;
        if (E.Key.State and $000C) <> 0 then WinShift := WinShift or 4;
        if (E.Key.State and $0003) <> 0 then WinShift := WinShift or 8;
        if not E.Key.Down then Continue;
        Scan := E.Key.Scan and $FF;
        A := E.Key.Ch and $FF;
        { The console input stream is Unicode, while TUI expects CP437. }
        if E.Key.Ch > 127 then A := Ord('?');
        if (WinShift and 8 <> 0) and (A = 0) then A := 0;
        K := (Word(Scan) shl 8) or A;
        if K <> 0 then begin
          Rep := E.Key.RepeatCount;
          if Rep > 64 then Rep := 64;
          for J := 1 to Rep do WinQueueKey(K);
        end;
      end;
      2: begin
        WinMouseX := E.Mouse.Position.X - WinOriginX;
        WinMouseY := E.Mouse.Position.Y - WinOriginY;
        WinButtons := 0;
        if (E.Mouse.ButtonState and 1) <> 0 then WinButtons := WinButtons or 1;
        if (E.Mouse.ButtonState and 2) <> 0 then WinButtons := WinButtons or 2;
        if (E.Mouse.ButtonState and 4) <> 0 then WinButtons := WinButtons or 4;
        if E.Mouse.EventFlags = 4 then
          if SmallInt(E.Mouse.ButtonState shr 16) > 0 then Dec(WinWheel)
          else Inc(WinWheel);
      end;
      4: begin { window resize: dimensions are bounded by the cell arrays }
        { Resize integration is deferred; the active dimensions remain fixed. }
      end;
    end;
  end;
end;

procedure HWInit;
var Info: TWinScreenInfo; Rect: TWinRect; Size, Origin: TWinCoord;
begin
  WinOut := WinGetStdHandle(-11);
  WinIn := WinGetStdHandle(-10);
  if not WinGetConsoleMode(WinOut, WinOutMode) or
     not WinGetConsoleMode(WinIn, WinInMode) then
    raise Exception.Create('FPTUI needs an interactive Windows console');
  WinOldCP := WinGetConsoleOutputCP;
  WinGetScreenInfo(WinOut, WinOldInfo);
  WinGetCursorInfo(WinOut, WinOldCursor);
  Info := WinOldInfo;
  WinOriginX := Info.Window.Left;
  WinOriginY := Info.Window.Top;
  HWCols := Info.Window.Right - Info.Window.Left + 1;
  HWRows := Info.Window.Bottom - Info.Window.Top + 1;
  if HWCols > MaxCols then HWCols := MaxCols;
  if HWRows > MaxRows then HWRows := MaxRows;
  if HWCols < 1 then HWCols := 80;
  if HWRows < 1 then HWRows := 25;
  HWMono := false;
  SetLength(WinSaved, HWCols * HWRows);
  Size := WinCoord(HWCols, HWRows);
  Origin := WinCoord(0, 0);
  Rect := WinRect(WinOriginX, WinOriginY, WinOriginX+HWCols-1, WinOriginY+HWRows-1);
  WinReadOutput(WinOut, @WinSaved[0], Size, Origin, Rect);
  if not WinSetConsoleOutputCP(437) then
    raise Exception.Create('Cannot select CP437 console output code page');
  { Disable Quick Edit; it freezes input polling when text is selected. }
  WinSetConsoleMode(WinIn, (WinInMode or $0080 or $0010 or $0008) and not ($0040 or $0002 or $0004));
  WinMouseX := 0; WinMouseY := 0; WinButtons := 0; WinWheel := 0;
  WinQHead := 0; WinQTail := 0;
  WinCursorInfoValid := false; WinCursorPosValid := false;
  WinStarted := true;
  HWMouseInit;
end;

procedure HWExternalConsoleBegin;
begin
  if not WinStarted then Exit;
  { Let a console child use ordinary cooked stdin rather than mouse/raw input. }
  WinSetConsoleMode(WinIn, WinInMode);
  WinSetConsoleOutputCP(WinOldCP);
  WinQHead := 0; WinQTail := 0;
  WinCursorInfoValid := false; WinCursorPosValid := false;
end;

procedure HWExternalConsoleEnd;
begin
  if not WinStarted then Exit;
  { Re-enable mouse/keyboard input after the child, clearing its leftover events. }
  WinSetConsoleMode(WinIn, (WinInMode or $0080 or $0010 or $0008) and not ($0040 or $0002 or $0004));
  WinSetConsoleOutputCP(437);
  WinQHead := 0; WinQTail := 0;
  WinButtons := 0; WinWheel := 0;
  WinCursorInfoValid := false; WinCursorPosValid := false;
end;

procedure HWDone;
var Size, Origin: TWinCoord; Rect: TWinRect;
begin
  if not WinStarted then Exit;
  WinSetConsoleMode(WinIn, WinInMode);
  if Length(WinSaved) > 0 then begin
    Size := WinCoord(HWCols, HWRows); Origin := WinCoord(0, 0);
    Rect := WinRect(WinOriginX, WinOriginY, WinOriginX+HWCols-1, WinOriginY+HWRows-1);
    WinWriteOutput(WinOut, @WinSaved[0], Size, Origin, Rect);
  end;
  WinSetCursorInfo(WinOut, WinOldCursor);
  WinSetCursorPos(WinOut, WinOldInfo.CursorPosition);
  WinSetConsoleOutputCP(WinOldCP);
  SetLength(WinSaved, 0);
  WinStarted := false;
end;

function HWSetMode(Cols, Rows: Integer): Boolean;
begin
  { Must not resize the shared fixed-size buffers or DOS video mode. }
  Result := (Cols = HWCols) and (Rows = HWRows);
end;

function HWSetRows(Rows: Integer): Boolean;
begin
  Result := HWSetMode(HWCols, Rows);
end;

procedure HWCurrentMode(out Cols, Rows: Integer);
begin
  Cols := HWCols; Rows := HWRows;
end;

procedure HWSetBlink(On: Boolean);
begin
  { Windows console supports 16 background colours, no blink attribute. }
end;

procedure HWWriteCells(Ofs: Integer; const Src; Count: Integer);
var Buf: array of TWinCharInfo; I, X, Y, N: Integer;
    Size, Origin: TWinCoord; Rect: TWinRect; P: PWord;
begin
  if not WinStarted or (Count <= 0) or (Ofs < 0) then Exit;
  P := @Src;
  while (Count > 0) and (Ofs < HWCols * HWRows) do begin
    X := Ofs mod HWCols; Y := Ofs div HWCols;
    N := HWCols - X;
    if Count < N then N := Count;
    SetLength(Buf, N);
    for I := 0 to N-1 do begin
      Buf[I].C := P^ and $FF;
      Buf[I].Attr := P^ shr 8;
      Inc(P);
    end;
    Size := WinCoord(N, 1); Origin := WinCoord(0, 0);
    Rect := WinRect(X+WinOriginX, Y+WinOriginY, X+WinOriginX+N-1, Y+WinOriginY);
    WinWriteOutput(WinOut, @Buf[0], Size, Origin, Rect);
    Inc(HWCellsWritten, N);
    Inc(Ofs, N); Dec(Count, N);
  end;
end;

procedure HWReadCells(Ofs: Integer; var Dst; Count: Integer);
var Buf: array of TWinCharInfo; I, X, Y, N: Integer;
    Size, Origin: TWinCoord; Rect: TWinRect; P: PWord;
begin
  if not WinStarted or (Count <= 0) or (Ofs < 0) then Exit;
  P := @Dst;
  while (Count > 0) and (Ofs < HWCols * HWRows) do begin
    X := Ofs mod HWCols; Y := Ofs div HWCols;
    N := HWCols - X;
    if Count < N then N := Count;
    SetLength(Buf, N);
    Size := WinCoord(N, 1); Origin := WinCoord(0, 0);
    Rect := WinRect(X+WinOriginX, Y+WinOriginY, X+WinOriginX+N-1, Y+WinOriginY);
    if WinReadOutput(WinOut, @Buf[0], Size, Origin, Rect) then
      for I := 0 to N-1 do begin
        P^ := (Buf[I].Attr shl 8) or (Buf[I].C and $FF);
        Inc(P);
      end
    else begin
      for I := 0 to N-1 do begin P^ := $0720; Inc(P); end;
    end;
    Inc(Ofs, N); Dec(Count, N);
  end;
end;

procedure HWSetCursor(X, Y: Integer; Shape: TCursorShape);
var
  C: TWinCursorInfo;
  PosX, PosY: Integer;
begin
  if not WinStarted then Exit;
  C.Visible := Shape <> csHidden;
  if Shape = csBlock then C.Size := 100 else C.Size := 15;

  { An idle ScrFlush calls HWSetCursor repeatedly.  Reapplying cursor info
    every iteration can visibly restart the host cursor blink cycle. }
  if (not WinCursorInfoValid) or
     (WinLastCursorVisible <> C.Visible) or
     (WinLastCursorSize <> C.Size) then
    if WinSetCursorInfo(WinOut, C) then begin
      WinLastCursorVisible := C.Visible;
      WinLastCursorSize := C.Size;
      WinCursorInfoValid := true;
    end;

  if Shape <> csHidden then begin
    PosX := X + WinOriginX;
    PosY := Y + WinOriginY;
    if (not WinCursorPosValid) or
       (PosX <> WinLastCursorX) or (PosY <> WinLastCursorY) then
      if WinSetCursorPos(WinOut, WinCoord(PosX, PosY)) then begin
        WinLastCursorX := PosX;
        WinLastCursorY := PosY;
        WinCursorPosValid := true;
      end;
  end;
end;

function HWKeyPressed: Boolean;
begin
  WinPoll;
  Result := WinQHead <> WinQTail;
end;

function HWReadKey: Word;
begin
  Result := 0;
  repeat
    WinPoll;
    if WinQHead <> WinQTail then begin
      Result := WinQueue[WinQHead];
      WinQHead := (WinQHead + 1) and 255;
      Exit;
    end;
    WinSleep(10);
  until not WinStarted;
end;

function HWShiftState: Byte;
begin
  Result := WinShift;
end;

function HWMouseInit: Boolean;
begin
  HWMousePresent := WinStarted;
  HWMouseWheel := WinStarted;
  Result := HWMousePresent;
end;

procedure HWMouseRead(out X, Y: Integer; out Buttons: Byte; out Wheel: Integer);
begin
  WinPoll;
  X := WinMouseX; Y := WinMouseY;
  if X < 0 then X := 0 else if X >= HWCols then X := HWCols-1;
  if Y < 0 then Y := 0 else if Y >= HWRows then Y := HWRows-1;
  Buttons := WinButtons;
  Wheel := WinWheel;
  WinWheel := 0;
end;

procedure HWIdle;
begin
  if HWIdleCall then WinSleep(1);
end;

function HWTicks: LongInt;
begin
  Result := LongInt(WinGetTickCount);
end;

procedure HWBeep;
begin
  WinBeep(880, 70);
end;
