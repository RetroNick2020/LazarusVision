program SynTest;

{ Tests of the syntax highlighters (TUISYN): the tokens of lines of Pascal,
  QBasic and a table driven language, states that cross lines, the line
  state cache, and two real files (TUICTRL.PAS, SAMPLE.BAS) scanned whole,
  with the time it takes. Writes SYNTEST.LOG.   fpc -Tgo32v2 syntest.pas }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, TUIHW, TUISyn;

var
  Log: text;
  Passed, Failed: integer;
  Pas: TSynPasSyn;
  QB: TSynQBasicSyn;
  Any: TSynAnySyn;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

{ the tokens of a line (spaces left out) as 'kind:text kind:text ...' and   }
{ the state it ends in                                                      }
function Toks(HL: TSynCustomHighlighter; const S: string; State: integer; out EndSt: integer): string;
begin
  Result := '';
  HL.SetLine(S, State);
  while not HL.GetEol do
  begin
    if HL.TokenKind <> tkSpace then
    begin
      if Result <> '' then Result := Result + ' ';
      Result := Result + TokenKindNames[HL.TokenKind] + ':' + HL.GetToken;
    end;
    HL.Next;
  end;
  EndSt := HL.EndState;
end;

procedure T(HL: TSynCustomHighlighter; const S: string; State: integer; const Want: string;
            WantEnd: integer = 0);
var got: string;
    e: integer;
begin
  got := Toks(HL, S, State, e);
  if (got = Want) and (e = WantEnd) then Check(true, HL.LanguageName + ': ' + S)
  else Check(false, HL.LanguageName + ': ' + S + LineEnding + '        want ' + Want +
             ' (end ' + IntToStr(WantEnd) + ')' + LineEnding + '        got  ' + got +
             ' (end ' + IntToStr(e) + ')');
end;

{ every line of a file: the tokens join up to the line again; the time }
procedure WholeFile(HL: TSynCustomHighlighter; const FileName: string);
var l: TStringList;
    i, st, n, toks: integer;
    s: string;
    ok: boolean;
    t0, t1: longint;
begin
  l := TStringList.Create;
  try
    if not FileExists(FileName) then
    begin
      writeln(Log, 'note  ', FileName, ' not found: skipped');
      exit;
    end;
    l.LoadFromFile(FileName);
    ok := true;
    st := 0;
    toks := 0;
    for i := 0 to l.Count - 1 do
    begin
      HL.SetLine(l[i], st);
      s := '';
      while not HL.GetEol do
      begin
        s := s + HL.GetToken;
        inc(toks);
        HL.Next;
      end;
      if s <> l[i] then ok := false;
      st := HL.EndState;
    end;
    Check(ok and (st = 0), FileName + ': ' + IntToStr(l.Count) + ' lines, ' + IntToStr(toks) +
          ' tokens, every line rebuilt from its tokens, ends in state 0');
    { the speed: the whole file 5 times }
    t0 := HWTicks;
    for n := 1 to 5 do
    begin
      st := 0;
      for i := 0 to l.Count - 1 do st := HL.LineEndState(l[i], st);
    end;
    t1 := HWTicks;
    { (55 ms steps: the BIOS clock; the per screen figure is an average) }
    writeln(Log, 'time  ', FileName, ': 5 x ', l.Count, ' lines in ', t1 - t0, ' ms',
            ', about ', int64(t1 - t0) * 1000 * 25 div (5 * l.Count + 1),
            ' microseconds for a 25 line screen');
  finally
    l.Free;
  end;
end;

procedure LineStateTests;
var l: TStringList;
    c: TSynLineStates;
    i: integer;
begin
  l := TStringList.Create;
  for i := 0 to 999 do l.Add('  x := x + ' + IntToStr(i) + ';  // line ' + IntToStr(i));
  l[20] := '  } end of a comment';
  c := TSynLineStates.Create(l, Pas);
  try
    Check(c.StartState(999) = 0, 'states: a 1000 line file starts every line in code');
    Check(c.Scanned = 999, 'states: the first time every line before is scanned: ' + IntToStr(c.Scanned));
    c.Scanned := 0;
    Check(c.StartState(999) = 0, 'states: asked again');
    Check(c.Scanned = 0, 'states: nothing scanned again');
    l[500] := '  y := 2;';
    c.LineChanged(500);
    c.Scanned := 0;
    c.StartState(999);
    Check(c.Scanned <= 2, 'states: an edit that keeps the state: the line and the next scanned, the rest still holds: ' +
          IntToStr(c.Scanned));
    l[10] := '  { a comment opens';
    c.LineChanged(10);
    c.Scanned := 0;
    Check((c.StartState(15) = 1) and (c.StartState(20) = 1) and (c.StartState(21) = 0) and
          (c.StartState(999) = 0), 'states: "{" on line 10: lines 11..20 in the comment, 21 on in code');
    Check(c.Scanned = 11, 'states: and only lines 10..20 were scanned: ' + IntToStr(c.Scanned));
    l.Insert(5, '  (* another');
    l.Insert(6, '  *) closed');
    c.LinesInserted(5, 2);
    c.Scanned := 0;
    Check((c.StartState(6) = 2) and (c.StartState(7) = 0) and (c.StartState(13) = 1) and
          (c.StartState(23) = 0) and (c.StartState(1001) = 0), 'states: two lines inserted');
    Check(c.Scanned < 10, 'states: after an insert only the lines near it: ' + IntToStr(c.Scanned));
    l.Delete(12);
    c.LinesDeleted(12, 1);
    Check((c.StartState(12) = 0) and (c.StartState(13) = 0) and (c.StartState(22) = 0),
          'states: the line with "{" deleted: the comment is gone');
  finally
    c.Free;
    l.Free;
  end;
end;

var e: integer;
begin
  Assign(Log, 'SYNTEST.LOG');
  Rewrite(Log);
  Pas := TSynPasSyn.Create(nil);
  QB := TSynQBasicSyn.Create(nil);
  Any := TSynAnySyn.Create(nil);

  { ---- Pascal }
  T(Pas, 'begin x := 10; end;', 0, 'key:begin ident:x sym:: sym:= num:10 sym:; key:end sym:;');
  T(Pas, 'BEGIN WriteLn(Result) End', 0, 'key:BEGIN ident:WriteLn sym:( ident:Result sym:) key:End');
  T(Pas, 's := ''it''''s'';', 0, 'ident:s sym:: sym:= str:''it''''s'' sym:;');
  T(Pas, 'c := #13#$0A + ''x'';', 0, 'ident:c sym:: sym:= str:#13 str:#$0A sym:+ str:''x'' sym:;');
  T(Pas, 'n := $FF + %101 + &17 + 1.5e3 + 2E-4;', 0,
    'ident:n sym:: sym:= num:$FF sym:+ num:%101 sym:+ num:&17 sym:+ num:1.5e3 sym:+ num:2E-4 sym:;');
  T(Pas, 'for i := 1..10 do', 0, 'key:for ident:i sym:: sym:= num:1 sym:. sym:. num:10 key:do');
  T(Pas, '&begin := 1; // a note', 0, 'ident:&begin sym:: sym:= num:1 sym:; comment:// a note');
  T(Pas, '{$mode objfpc}{$H+} uses x;', 0, 'dir:{$mode objfpc} dir:{$H+} key:uses ident:x sym:;');
  T(Pas, 'x := 1; { a comment that goes on', 0, 'ident:x sym:: sym:= num:1 sym:; comment:{ a comment that goes on', 1);
  T(Pas, 'still in it } y := 2;', 1, 'comment:still in it } ident:y sym:: sym:= num:2 sym:;');
  T(Pas, '(* old style *) z (* and on', 0, 'comment:(* old style *) ident:z comment:(* and on', 2);
  T(Pas, 'more *) end.', 2, 'comment:more *) key:end sym:.');
  T(Pas, '{$IFDEF GO32V2', 0, 'dir:{$IFDEF GO32V2', 3);
  T(Pas, '  X} begin', 3, 'dir:  X} key:begin');
  T(Pas, 'asm', 0, 'key:asm', 4);
  T(Pas, '  mov ax, $13  { a mode }', 4, 'asm:mov asm:ax asm:, asm:$13 comment:{ a mode }', 4);
  T(Pas, '  int $10', 4, 'asm:int asm:$10', 4);
  T(Pas, 'end;', 4, 'key:end sym:;', 0);
  T(Pas, 'procedure TForm1.Button1Click(Sender: TObject); override;', 0,
    'key:procedure ident:TForm1 sym:. ident:Button1Click sym:( ident:Sender sym:: ident:TObject sym:) sym:; key:override sym:;');
  T(Pas, '  x := ''never closed', 0, 'ident:x sym:: sym:= str:''never closed');
  T(Pas, '', 1, '', 1);
  Check(Pas.IsKeyword('Begin') and not Pas.IsKeyword('WriteLn') and Pas.IsKeyword('xor'),
        'Pascal: IsKeyword (any case)');

  { ---- QBasic }
  T(QB, '10 PRINT "Hello"', 0, 'label:10 key:PRINT str:"Hello"');
  T(QB, 'Again: CLS', 0, 'label:Again: key:CLS');
  T(QB, 'a$ = LEFT$(name$, 3)', 0, 'ident:a$ sym:= key:LEFT$ sym:( ident:name$ sym:, num:3 sym:)');
  T(QB, 'x% = &HFF + &O17 + 1.5E+3# + 70000& + .5', 0,
    'ident:x% sym:= num:&HFF sym:+ num:&O17 sym:+ num:1.5E+3# sym:+ num:70000& sym:+ num:.5');
  T(QB, 'PRINT 10; x', 0, 'key:PRINT num:10 sym:; ident:x');
  T(QB, 'print "a": rem lower case too', 0, 'key:print str:"a" sym:: comment:rem lower case too');
  T(QB, 'REM a comment', 0, 'comment:REM a comment');
  T(QB, 'REM $DYNAMIC', 0, 'dir:REM $DYNAMIC');
  T(QB, '''$INCLUDE: ''qb.bi''', 0, 'dir:''$INCLUDE: ''qb.bi''');
  T(QB, 'x = 1 '' the rest', 0, 'ident:x sym:= num:1 comment:'' the rest');
  T(QB, 'REMAINDER = 7', 0, 'ident:REMAINDER sym:= num:7');
  T(QB, 'IF k$ = "" THEN END IF', 0, 'key:IF ident:k$ sym:= str:"" key:THEN key:END key:IF');
  T(QB, 'my.var = Total#(a#(), n%)', 0, 'ident:my.var sym:= ident:Total# sym:( ident:a# sym:( sym:) sym:, ident:n% sym:)');
  T(QB, '    LOCATE y%, x%: PRINT CHR$(218)', 0,
    'key:LOCATE ident:y% sym:, ident:x% sym:: key:PRINT key:CHR$ sym:( num:218 sym:)');
  T(QB, 'PRINT "never closed', 0, 'key:PRINT str:"never closed');
  Check(QB.IsKeyword('mid$') and not QB.IsKeyword('mid'), 'QBasic: IsKeyword with the $ sigil');

  { ---- table driven: a small C }
  Any.Language := 'C';
  Any.Keywords.CommaText := 'int,return,if,else,while,char,void';
  Any.CaseSensitive := true;
  Any.LineComments.Add('//');
  Any.BlockCommentStart := '/*';
  Any.BlockCommentEnd := '*/';
  Any.DirectiveChar := '#';
  T(Any, '#include <stdio.h>', 0, 'dir:#include <stdio.h>');
  T(Any, 'int main(void) { return 0x1F; } // end', 0,
    'key:int ident:main sym:( key:void sym:) sym:{ key:return num:0x1F sym:; sym:} comment:// end');
  T(Any, 'char *s = "a \"q\""; /* open', 0, 'key:char sym:* ident:s sym:= str:"a \"q\"" sym:; comment:/* open', 1);
  T(Any, 'closed */ Int x', 1, 'comment:closed */ ident:Int ident:x');

  Check(HighlighterClassForFile('MAIN.PAS') = TSynPasSyn, 'HighlighterClassForFile: .PAS');
  Check(HighlighterClassForFile('game.bas') = TSynQBasicSyn, 'HighlighterClassForFile: .bas');
  Check(HighlighterClassForFile('README.TXT') = nil, 'HighlighterClassForFile: .TXT: none');

  LineStateTests;
  WholeFile(Pas, 'TUICTRL.PAS');
  WholeFile(QB, 'SAMPLE.BAS');

  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  Pas.Free;
  QB.Free;
  Any.Free;
end.
