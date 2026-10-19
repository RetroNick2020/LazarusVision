{ Linux UTF-8 terminal backend (no curses dependency). TUI cells remain CP437. }
const
  LinuxCP437: array[0..255] of Word = (
  $0000,$263A,$263B,$2665,$2666,$2663,$2660,$2022,
  $25D8,$25CB,$25D9,$2642,$2640,$266A,$266B,$263C,
  $25BA,$25C4,$2195,$203C,$00B6,$00A7,$25AC,$21A8,
  $2191,$2193,$2192,$2190,$221F,$2194,$25B2,$25BC,
  $0020,$0021,$0022,$0023,$0024,$0025,$0026,$0027,
  $0028,$0029,$002A,$002B,$002C,$002D,$002E,$002F,
  $0030,$0031,$0032,$0033,$0034,$0035,$0036,$0037,
  $0038,$0039,$003A,$003B,$003C,$003D,$003E,$003F,
  $0040,$0041,$0042,$0043,$0044,$0045,$0046,$0047,
  $0048,$0049,$004A,$004B,$004C,$004D,$004E,$004F,
  $0050,$0051,$0052,$0053,$0054,$0055,$0056,$0057,
  $0058,$0059,$005A,$005B,$005C,$005D,$005E,$005F,
  $0060,$0061,$0062,$0063,$0064,$0065,$0066,$0067,
  $0068,$0069,$006A,$006B,$006C,$006D,$006E,$006F,
  $0070,$0071,$0072,$0073,$0074,$0075,$0076,$0077,
  $0078,$0079,$007A,$007B,$007C,$007D,$007E,$2302,
  $00C7,$00FC,$00E9,$00E2,$00E4,$00E0,$00E5,$00E7,
  $00EA,$00EB,$00E8,$00EF,$00EE,$00EC,$00C4,$00C5,
  $00C9,$00E6,$00C6,$00F4,$00F6,$00F2,$00FB,$00F9,
  $00FF,$00D6,$00DC,$00A2,$00A3,$00A5,$20A7,$0192,
  $00E1,$00ED,$00F3,$00FA,$00F1,$00D1,$00AA,$00BA,
  $00BF,$2310,$00AC,$00BD,$00BC,$00A1,$00AB,$00BB,
  $2591,$2592,$2593,$2502,$2524,$2561,$2562,$2556,
  $2555,$2563,$2551,$2557,$255D,$255C,$255B,$2510,
  $2514,$2534,$252C,$251C,$2500,$253C,$255E,$255F,
  $255A,$2554,$2569,$2566,$2560,$2550,$256C,$2567,
  $2568,$2564,$2565,$2559,$2558,$2552,$2553,$256B,
  $256A,$2518,$250C,$2588,$2584,$258C,$2590,$2580,
  $03B1,$00DF,$0393,$03C0,$03A3,$03C3,$00B5,$03C4,
  $03A6,$0398,$03A9,$03B4,$221E,$03C6,$03B5,$2229,
  $2261,$00B1,$2265,$2264,$2320,$2321,$00F7,$2248,
  $00B0,$2219,$00B7,$221A,$207F,$00B2,$25A0,$00A0
  );
  LinuxFG: array[0..15] of Byte = (30,34,32,36,31,35,33,37,90,94,92,96,91,95,93,97);
  LinuxBG: array[0..15] of Byte = (40,44,42,46,41,45,43,47,100,104,102,106,101,105,103,107);
var
  LinuxStarted: Boolean = false;
  LinuxRaw: Boolean = false;
  LinuxStty: string;
  LinuxCells: array of Word;
  LinuxKeys: array[0..255] of Word;
  LinuxHead, LinuxTail: Integer;
  LinuxShift: Byte;
  LinuxMouseX, LinuxMouseY: Integer;
  LinuxButtons: Byte;
  LinuxWheel: Integer;
  LinuxCursorX, LinuxCursorY: Integer;
  LinuxCursorShape: TCursorShape;
  LinuxCursorValid: Boolean;
  LinuxPending: AnsiString;
  LinuxEscapeSince: QWord;
  LinuxAttr: Integer;

procedure LinuxWrite(const S: AnsiString);
var N: SizeInt;
begin
  if Length(S) = 0 then Exit;
  N := fpWrite(1, S[1], Length(S));
end;

function LinuxCSI(X,Y: Integer): AnsiString;
begin
  Result := #27+'['+IntToStr(Y+1)+';'+IntToStr(X+1)+'H';
end;

function LinuxUTF(Code: LongWord): AnsiString;
begin
  if Code < $80 then Result := Chr(Code)
  else if Code < $800 then Result := Chr($C0 or (Code shr 6)) + Chr($80 or (Code and $3F))
  else Result := Chr($E0 or (Code shr 12)) + Chr($80 or ((Code shr 6) and $3F)) + Chr($80 or (Code and $3F));
end;

procedure LinuxQueueKey(K: Word);
var N: Integer;
begin
  N := (LinuxTail+1) and 255;
  if N <> LinuxHead then begin LinuxKeys[LinuxTail] := K; LinuxTail := N; end;
end;

procedure LinuxMode(Raw: Boolean);
var Cmd: string;
begin
  if Raw then Cmd := 'stty raw -echo -ixon -ixoff min 0 time 0 < /dev/tty'
  else Cmd := 'stty ' + LinuxStty + ' < /dev/tty';
  if ExecuteProcess('/bin/sh', ['-c',Cmd]) <> 0 then
    raise Exception.Create('Unable to configure Linux terminal with stty');
  LinuxRaw := Raw;
end;

procedure HWExternalConsoleBegin;
begin
  if not LinuxStarted then Exit;
  LinuxWrite(#27+'[0m'+#27+'[?1000l'+#27+'[?1002l'+#27+'[?1006l'+#27+'[?25h');
  fpFcntl(0, 4, fpFcntl(0, 3, 0) and not 2048);
  LinuxMode(false);
  LinuxPending := ''; LinuxHead := 0; LinuxTail := 0;
  LinuxCursorValid := false;
end;

procedure HWExternalConsoleEnd;
begin
  if not LinuxStarted then Exit;
  LinuxMode(true);
  fpFcntl(0, 4, fpFcntl(0, 3, 0) or 2048);
  LinuxWrite(#27+'[?1000h'+#27+'[?1002h'+#27+'[?1006h');
  LinuxPending := ''; LinuxHead := 0; LinuxTail := 0;
  LinuxButtons := 0;
  LinuxCursorValid := false;
end;

procedure HWInit;
var S: string; P: Integer;
begin
  if not RunCommand('/bin/sh',['-c','stty -g < /dev/tty'],S) then
    raise Exception.Create('LazarusVision needs an interactive Linux TTY');
  LinuxStty := Trim(S);
  if LinuxStty = '' then raise Exception.Create('Cannot read original TTY settings');
  { stty size reports rows then columns. }
  if not RunCommand('/bin/sh',['-c','stty size < /dev/tty'],S) then S := '25 80';
  S := Trim(S); P := Pos(' ', S);
  if P > 0 then begin
    HWRows := StrToIntDef(Copy(S,1,P-1),25);
    HWCols := StrToIntDef(Trim(Copy(S,P+1,MaxInt)),80);
  end else begin HWCols := 80; HWRows := 25; end;
  if HWCols < 1 then HWCols := 80;
  if HWRows < 1 then HWRows := 25;
  if HWCols > MaxCols then HWCols := MaxCols;
  if HWRows > MaxRows then HWRows := MaxRows;
  HWMono := false;
  SetLength(LinuxCells,HWCols*HWRows);
  FillWord(LinuxCells[0],Length(LinuxCells),$0720);
  LinuxHead := 0; LinuxTail := 0; LinuxMouseX := 0; LinuxMouseY := 0;
  LinuxButtons := 0; LinuxWheel := 0; LinuxShift := 0;
  LinuxAttr := -1; LinuxPending := ''; LinuxCursorValid := false;
  LinuxMode(true);
  fpFcntl(0, 4, fpFcntl(0, 3, 0) or 2048);
  LinuxStarted := true;
  LinuxWrite(#27+'[?1049h'+#27+'[?25l'+#27+'[2J'+#27+'[H'+#27+'[?1000h'+#27+'[?1002h'+#27+'[?1006h');
  HWMouseInit;
end;

procedure HWDone;
begin
  if not LinuxStarted then Exit;
  LinuxWrite(#27+'[?1000l'+#27+'[?1002l'+#27+'[?1006l'+#27+'[0m'+#27+'[?25h'+#27+'[?1049l');
  LinuxStarted := false;
  fpFcntl(0, 4, fpFcntl(0, 3, 0) and not 2048);
  LinuxMode(false);
  SetLength(LinuxCells,0);
end;

function HWSetMode(Cols,Rows: Integer): Boolean;
begin Result := (Cols=HWCols) and (Rows=HWRows); end;
function HWSetRows(Rows: Integer): Boolean;
begin Result := HWSetMode(HWCols, Rows); end;
procedure HWCurrentMode(out Cols, Rows: Integer);
begin Cols:=HWCols; Rows:=HWRows; end;
procedure HWSetBlink(On: Boolean);
begin end;

procedure HWWriteCells(Ofs: Integer; const Src; Count: Integer);
var P: PWord; X,Y,Attr,LastAttr,Code: Integer; S: AnsiString;
begin
  if not LinuxStarted or (Count<=0) or (Ofs<0) or (Ofs>=Length(LinuxCells)) then Exit;
  P := @Src; S := ''; LastAttr := -1;
  while (Count>0) and (Ofs<Length(LinuxCells)) do begin
    X := Ofs mod HWCols; Y := Ofs div HWCols;
    S := S + LinuxCSI(X,Y);
    repeat
      LinuxCells[Ofs] := P^;
      Attr := P^ shr 8;
      if Attr <> LastAttr then begin
        S := S + #27+'['+IntToStr(LinuxFG[Attr and 15])+';'+IntToStr(LinuxBG[(Attr shr 4) and 15])+'m';
        LastAttr := Attr;
      end;
      Code := LinuxCP437[P^ and 255];
      if Code < 32 then Code := 32;
      S := S + LinuxUTF(Code);
      Inc(P); Inc(Ofs); Dec(Count); Inc(HWCellsWritten);
    until (Count<=0) or (Ofs mod HWCols = 0) or (Ofs>=Length(LinuxCells));
  end;
  LinuxWrite(S);
  LinuxCursorValid := false; { terminal output moves the host caret }
end;

procedure HWReadCells(Ofs: Integer; var Dst; Count: Integer);
var P: PWord; I: Integer;
begin
  if (Count<=0) or (Ofs<0) then Exit;
  P := @Dst;
  for I := 0 to Count-1 do begin
    if Ofs+I < Length(LinuxCells) then P^ := LinuxCells[Ofs+I] else P^ := $0720;
    Inc(P);
  end;
end;

procedure HWSetCursor(X,Y: Integer; Shape: TCursorShape);
var S: AnsiString;
begin
  if not LinuxStarted then Exit;
  if LinuxCursorValid and (X=LinuxCursorX) and (Y=LinuxCursorY) and (Shape=LinuxCursorShape) then Exit;
  S := '';
  if Shape=csHidden then S := #27+'[?25l'
  else begin
    if not LinuxCursorValid or (LinuxCursorShape=csHidden) then S := #27+'[?25h';
    if Shape=csBlock then S := S+#27+'[2 q' else S := S+#27+'[4 q';
    S := S+LinuxCSI(X,Y);
  end;
  LinuxWrite(S);
  LinuxCursorX:=X; LinuxCursorY:=Y; LinuxCursorShape:=Shape; LinuxCursorValid:=true;
end;

procedure LinuxParse;
var C: Byte; I,J,B,X,Y,V,ModKey: Integer; Seq: string; K: Word;
begin
  while Length(LinuxPending)>0 do begin
    C := Ord(LinuxPending[1]);
    if C<>27 then begin
      Delete(LinuxPending,1,1);
      if C=10 then C:=13;
      if C=127 then K:=$0E08
      else if C=9 then K:=$0F09
      else if C=13 then K:=$1C0D
      else if C<32 then K:=Word(C)
      else if C<128 then K:=Word(C) else K:=Ord('?');
      LinuxQueueKey(K); Continue;
    end;
    if Length(LinuxPending)=1 then Exit; { allow ESC sequence to complete }
    if LinuxPending[2]<>'[' then begin
      Delete(LinuxPending,1,1); LinuxQueueKey($011B); Continue;
    end;
    I:=3;
    while (I<=Length(LinuxPending)) and not (LinuxPending[I] in ['A'..'Z','a'..'z','~']) do Inc(I);
    if I>Length(LinuxPending) then Exit;
    Seq:=Copy(LinuxPending,3,I-3);
    C:=Ord(LinuxPending[I]); Delete(LinuxPending,1,I);
    if (Length(Seq)>0) and (Seq[1]='<') and ((C=Ord('M')) or (C=Ord('m'))) then begin
      Delete(Seq,1,1);
      J:=Pos(';',Seq); if J=0 then Continue;
      B:=StrToIntDef(Copy(Seq,1,J-1),0); Delete(Seq,1,J);
      J:=Pos(';',Seq); if J=0 then Continue;
      X:=StrToIntDef(Copy(Seq,1,J-1),1)-1;
      Y:=StrToIntDef(Copy(Seq,J+1,MaxInt),1)-1;
      LinuxMouseX:=X; LinuxMouseY:=Y;
      if (B and 64)<>0 then begin
        if (B and 1)=0 then Inc(LinuxWheel) else Dec(LinuxWheel);
      end else if C=Ord('m') then LinuxButtons:=0
      else case B and 3 of
        0: LinuxButtons:=1;
        1: LinuxButtons:=4;
        2: LinuxButtons:=2;
        3: LinuxButtons:=0;
      end;
      Continue;
    end;
    case Char(C) of
      'A': K:=$4800; 'B': K:=$5000; 'C': K:=$4D00; 'D': K:=$4B00;
      'H': K:=$4700; 'F': K:=$4F00;
      '~': begin
        V:=StrToIntDef(Seq,0);
        case V of
          1,7: K:=$4700; 2: K:=$5200; 3: K:=$5300;
          4,8: K:=$4F00; 5: K:=$4900; 6: K:=$5100;
          15: K:=$3F00; 17: K:=$4000; 18: K:=$4100;
          19: K:=$4200; 20: K:=$4300; 21: K:=$4400;
          else K:=0;
        end;
      end;
      else K:=0;
    end;
    if K<>0 then LinuxQueueKey(K);
  end;
end;

procedure LinuxPoll;
var Buf: array[0..127] of Byte; N,I: Integer;
begin
  if not LinuxStarted then Exit;
  repeat
    N:=fpRead(0,Buf,SizeOf(Buf));
    if N>0 then begin
      for I:=0 to N-1 do LinuxPending:=LinuxPending+Chr(Buf[I]);
      LinuxEscapeSince:=GetTickCount64;
      LinuxParse;
    end;
  until N<=0;
  { A standalone Escape key has no trailing bytes. Resolve it after a brief
    delay instead of keeping it buffered indefinitely. }
  if (LinuxPending = #27) and (GetTickCount64 - LinuxEscapeSince > 50) then begin
    LinuxPending := '';
    LinuxQueueKey($011B);
  end;
end;

function HWKeyPressed: Boolean;
begin LinuxPoll; Result:=LinuxHead<>LinuxTail; end;
function HWReadKey: Word;
begin
  repeat
    LinuxPoll;
    if LinuxHead<>LinuxTail then begin
      Result:=LinuxKeys[LinuxHead]; LinuxHead:=(LinuxHead+1) and 255; Exit;
    end;
    Sleep(10);
  until not LinuxStarted;
  Result:=0;
end;
function HWShiftState: Byte;
begin Result:=LinuxShift; end;
function HWMouseInit: Boolean;
begin HWMousePresent:=LinuxStarted; HWMouseWheel:=LinuxStarted; Result:=HWMousePresent; end;
procedure HWMouseRead(out X,Y: Integer; out Buttons: Byte; out Wheel: Integer);
begin
  LinuxPoll;
  X:=LinuxMouseX; Y:=LinuxMouseY;
  if X<0 then X:=0 else if X>=HWCols then X:=HWCols-1;
  if Y<0 then Y:=0 else if Y>=HWRows then Y:=HWRows-1;
  Buttons:=LinuxButtons; Wheel:=LinuxWheel; LinuxWheel:=0;
end;
procedure HWIdle;
begin if HWIdleCall then Sleep(1); end;
function HWTicks: LongInt;
begin Result:=LongInt(GetTickCount64 and $7FFFFFFF); end;
procedure HWBeep;
begin LinuxWrite(#7); end;
