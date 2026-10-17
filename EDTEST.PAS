program EdTest;

{ Tests of TSynEdit (TUISYNED) in the code editor window (CODEFRM): the
  colours on screen, the caret, editing, the selection, the clipboard, the
  mouse, scrolling, the line state cache while typing, a 4000 line file and
  how long paging through it takes. Writes EDTEST.LOG.
     fpc -Tgo32v2 edtest.pas   (SAMPLE.BAS and TUICTRL.PAS next to it) }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUISyn, TUISynEd, CodeFrm;

var
  Log: text;
  Passed, Failed: integer;
  E: TSynEdit;
  o: TPoint;
  i, n, statusCount: integer;
  t0, t1: longint;
  ok: boolean;

procedure Check(OK: boolean; const What: string);
begin
  if OK then begin inc(Passed); writeln(Log, 'ok    ', What); end
  else begin inc(Failed); writeln(Log, 'FAIL  ', What); end;
end;

procedure Run;
begin
  Application.ProcessMessages;
end;

procedure Key(K: Word; Shift: TShiftState);
begin
  TUIPostKey(K, #0, Shift);
end;

function CellChar(X, Y: integer): char;
var w: word;
begin
  HWReadCells(Y * ScrCols + X, w, 1);
  Result := char(w and $FF);
end;

function CellAttr(X, Y: integer): byte;
var w: word;
begin
  HWReadCells(Y * ScrCols + X, w, 1);
  Result := w shr 8;
end;

{ the screen cell of editor line L, column C (0 based) }
function Cell(L, C: integer): TPoint;
var gw: integer;
begin
  gw := Length(IntToStr(E.Lines.Count + 1));
  if gw < 3 then gw := 3;
  inc(gw, 2);
  Result := Point(E.ScreenOrigin.X + gw + C - (E.LeftChar - 1), E.ScreenOrigin.Y + L - (E.TopLine - 1));
end;

function FgAt(L, C: integer): byte;
var p: TPoint;
begin
  p := Cell(L, C);
  Result := CellAttr(p.X, p.Y) and 15;
end;

procedure Dump(const Title: string);
var buf: array of word;
    x, y: integer;
    s: string;
begin
  SetLength(buf, ScrCols * ScrRows);
  HWReadCells(0, buf[0], ScrCols * ScrRows);
  writeln(Log);
  writeln(Log, '=== ', Title);
  for y := 0 to ScrRows - 1 do
  begin
    SetLength(s, ScrCols);
    for x := 0 to ScrCols - 1 do s[x + 1] := char(buf[y * ScrCols + x] and $FF);
    writeln(Log, s);
  end;
  writeln(Log);
end;

type
  TCounter = class
    procedure Status(Sender: TObject);
  end;

procedure TCounter.Status(Sender: TObject);
begin
  inc(statusCount);
  CodeForm.EditorStatusChange(Sender);
end;

var counter: TCounter;

begin
  Assign(Log, 'EDTEST.LOG');
  Rewrite(Log);
  TUIMouseCursor := false;
  Application.Initialize;
  Application.CreateForm(TCodeForm, CodeForm);
  counter := TCounter.Create;
  E := CodeForm.Editor;
  E.OnStatusChange := @counter.Status;
  CodeForm.Show;
  Run;
  Dump('the code editor with Pascal');

  { ---- colours }
  Check(FgAt(0, 0) = tcWhite, 'program: a keyword, white');
  Check(FgAt(0, 8) = tcYellow, 'Hello: an identifier, the editor''s yellow');
  Check(FgAt(2, 0) = tcLightGreen, '{$mode objfpc}: a directive, light green');
  Check((FgAt(6, 0) = tcLightGray) and (FgAt(7, 5) = tcLightGray), '(* comment over two lines *): grey on both');
  Check(FgAt(10, 17) = tcLightCyan, '''it''''s'': a string, light cyan');
  Check(FgAt(13, 30) = tcLightGray, '// a loop: grey');
  Check((CellChar(Cell(0, 0).X - 2, Cell(0, 0).Y) = '1') and
        (CellAttr(Cell(0, 0).X - 2, Cell(0, 0).Y) and 15 = tcCyan), 'the gutter: line 1 in cyan');

  { ---- the caret and editing }
  Check((E.CaretX = 1) and (E.CaretY = 1), 'the caret starts at 1,1');
  Key(VK_DOWN, []); Key(VK_END, []); Run;
  Check((E.CaretY = 2) and (E.CaretX = 1), 'Down, End on an empty line');
  Key(VK_RIGHT, []); Key(VK_RIGHT, []); Key(VK_RIGHT, []); Run;
  Check(E.CaretX = 4, 'Right goes past the end of the line (as in TP and QBasic)');
  TUIPostString('x'); Run;
  Check((E.Lines[1] = '   x') and E.Modified, 'typing there fills the gap with spaces');
  Check(CodeForm.Status.Panels[2].Text = 'Modified', 'the status bar says Modified');
  Key(VK_BACK, []); Key(VK_BACK, []); Run;
  Check((E.Lines[1] = '') and (E.CaretX = 1),
        'Backspace: the x, then the blanks back to the indent of the line above (0)');
  Key(VK_BACK, []); Run;
  Check((E.Lines.Count = 15) and (E.CaretY = 1) and (E.CaretX = 15), 'Backspace at the start joins the lines');
  Key(VK_RETURN, []); Run;
  Check((E.Lines.Count = 16) and (E.Lines[1] = '') and (E.CaretY = 2), 'Enter splits again');
  Key(VK_HOME, [ssCtrl]); Key(VK_DOWN, []); Key(VK_DOWN, []); Key(VK_DOWN, []); Key(VK_DOWN, []); Run;
  Key(VK_END, []); Run;
  Check((E.CaretY = 5) and (E.CaretX = 15), 'End: after the last character of "uses SysUtils;"');
  Key(VK_LEFT, [ssCtrl]); Run;
  Check(E.CaretX = 6, 'Ctrl+Left: the start of the word');
  Key(VK_RIGHT, [ssShift]); Key(VK_RIGHT, [ssShift]); Key(VK_RIGHT, [ssShift]); Run;
  Check(E.SelAvail and (E.SelText = 'Sys'), 'Shift+Right selects: ' + E.SelText);
  Key(Ord('C'), [ssCtrl]); Key(VK_END, []); Key(Ord('V'), [ssCtrl]); Run;
  Check((Clipboard.AsText = 'Sys') and (E.Lines[4] = 'uses SysUtils;Sys'), 'Ctrl+C, End, Ctrl+V');
  Key(VK_LEFT, [ssShift]); Key(VK_LEFT, [ssShift]); Key(VK_LEFT, [ssShift]); Key(Ord('X'), [ssCtrl]); Run;
  Check((E.Lines[4] = 'uses SysUtils;') and not E.SelAvail, 'Shift+Left, Ctrl+X');
  Key(VK_HOME, []); Run;
  Check(E.CaretX = 1, 'Home');
  Key(VK_TAB, []); Run;
  Check((E.Lines[4] = '        uses SysUtils;') and (E.CaretX = 9), 'Tab: spaces to the next stop (8)');
  Key(VK_END, []); Key(VK_HOME, []); Run;
  Check(E.CaretX = 9, 'End, Home: the first non-blank');
  Key(VK_HOME, []); Run;
  Check(E.CaretX = 1, 'Home again: column 1');
  Key(VK_DELETE, []); Key(VK_DELETE, []); Key(VK_DELETE, []); Key(VK_DELETE, []);
  Key(VK_DELETE, []); Key(VK_DELETE, []); Key(VK_DELETE, []); Key(VK_DELETE, []); Run;
  Check(E.Lines[4] = 'uses SysUtils;', 'Del eight times');
  Key(VK_INSERT, []); TUIPostString('USES'); Key(VK_INSERT, []); Run;
  Check((E.Lines[4] = 'USES SysUtils;') and E.InsertMode, 'Ins: overwrite, Ins: insert again');
  n := E.Lines.Count;
  Key(Ord('Y'), [ssCtrl]); Run;
  Check((E.Lines.Count = n - 1) and (E.Lines[4] = ''), 'Ctrl+Y deleted the line');
  Check(statusCount > 10, 'OnStatusChange came with the moves: ' + IntToStr(statusCount));
  Check(CodeForm.Status.Panels[0].Text = 'Ln ' + IntToStr(E.CaretY) + ' Col ' + IntToStr(E.CaretX),
        'the status bar shows the caret: ' + CodeForm.Status.Panels[0].Text);

  { ---- stage 3: undo, redo }
  E.Text := 'program Undo;';
  E.Modified := false;
  E.CaretXY := Point(1, 2);
  Key(VK_END, [ssCtrl]); Key(VK_RETURN, []); TUIPostString('hello world'); Run;
  Check(E.Lines[1] = 'hello world', 'typed "hello world" on a new line');
  Key(Ord('Z'), [ssCtrl]); Run;
  Check((E.Lines[1] = 'hello ') and (E.CaretX = 7), 'Ctrl+Z: one word went ("world")');
  Key(VK_BACK, [ssAlt]); Run;
  Check((E.Lines.Count = 2) and (E.Lines[1] = ''), 'Alt+Backspace (Turbo / QBasic): "hello " went');
  Key(VK_BACK, [ssAlt]); Run;
  Check((E.Lines.Count = 1) and (E.CaretX = 14) and not E.Modified,
        'and the Enter: back to the saved text, not Modified any more');
  Check(not E.CanUndo and E.CanRedo, 'nothing left to undo; redo can');
  Key(Ord('Z'), [ssCtrl, ssShift]); Key(Ord('Z'), [ssCtrl, ssShift]); Run;
  Check((E.Lines.Count = 2) and (E.Lines[1] = 'hello ') and E.Modified, 'Ctrl+Shift+Z twice: redone');
  TUIPostString('x'); Run;
  Check(not E.CanRedo, 'typing again: the redo list is gone');
  E.Text := 'one two three';
  Check(not E.CanUndo, 'Text set from code: the undo list is cleared');
  E.CaretXY := Point(5, 1);
  E.BlockEnd := Point(8, 1);
  Clipboard.AsText := 'TWO 2';
  Key(Ord('V'), [ssCtrl]); Run;
  Check(E.Lines[0] = 'one TWO 2 three', 'paste over a selection');
  Key(Ord('Z'), [ssCtrl]); Run;
  Check((E.Lines[0] = 'one two three') and (E.SelText = 'two'), 'one Undo: the text and the selection are back');

  { ---- auto-indent, smart backspace }
  E.Text := 'begin' + LineEnding + '  if x then' + LineEnding + '    begin';
  E.CaretXY := Point(10, 3);
  Key(VK_RETURN, []); Run;
  Check((E.Lines.Count = 4) and (E.Lines[3] = '    ') and (E.CaretX = 5), 'Enter: indented like the line above');
  TUIPostString('y := 1;'); Key(VK_RETURN, []); Run;
  Check((E.CaretY = 5) and (E.CaretX = 5), 'Enter again: the same indent');
  Key(VK_BACK, []); Run;
  Check(E.CaretX = 3, 'Backspace in the indent: back to the "if" (2)');
  Key(VK_BACK, []); Run;
  Check(E.CaretX = 1, 'again: back to "begin" (0)');
  Key(VK_RETURN, []); Key(VK_BACK, [ssAlt]); Run;
  Check((E.Lines.Count = 5) and (E.CaretY = 5), 'one Undo takes back a whole Enter');

  { ---- block indent }
  E.Text := 'a' + LineEnding + 'b' + LineEnding + 'c';
  E.CaretXY := Point(1, 1);
  Key(VK_DOWN, [ssShift]); Key(VK_DOWN, [ssShift]); Run;
  Key(VK_TAB, []); Run;
  Check((E.Lines[0] = '  a') and (E.Lines[1] = '  b') and (E.Lines[2] = 'c') and E.SelAvail,
        'Tab on a selection of two lines: both moved by BlockIndent (2), the selection stays');
  Key(VK_TAB, []); Run;
  Check(E.Lines[0] = '    a', 'Tab again');
  Key(VK_TAB, [ssShift]); Run;
  Check((E.Lines[0] = '  a') and (E.Lines[1] = '  b'), 'Shift+Tab: back');
  Key(Ord('Z'), [ssCtrl]); Run;
  Check(E.Lines[0] = '    a', 'Undo the Shift+Tab: one step for both lines');
  Key(Ord('K'), [ssCtrl]); Run;
  Check((E.PendingPrefix = 'K') and (CodeForm.Status.Panels[1].Text = '^K'),
        'Ctrl+K waits for the second key (the status bar shows ^K)');
  TUIPostChar('u'); Run;
  Check((E.PendingPrefix = #0) and (E.Lines[0] = '  a'), 'Ctrl+K U: unindent');
  Key(Ord('K'), [ssCtrl]); Key(Ord('I'), [ssCtrl]); Run;
  Check(E.Lines[1] = '    b', 'Ctrl+K Ctrl+I: indent (the second key with Ctrl too)');
  Key(Ord('K'), [ssCtrl]); TUIPostChar(#9); Run;
  Check(E.Lines[1] = '      b', 'Ctrl+K Ctrl+I as DOS sends it (a Tab): indent');

  { ---- Ctrl+K blocks (they stay while the caret moves), Ctrl+Q moves }
  E.Text := 'alpha beta' + LineEnding + 'gamma';
  E.CaretXY := Point(7, 1);
  Key(Ord('K'), [ssCtrl]); TUIPostChar('b'); Key(VK_END, []); Key(Ord('K'), [ssCtrl]); TUIPostChar('k'); Run;
  Check(E.BlockMarked and (E.MarkedText = 'beta'), 'Ctrl+K B, End, Ctrl+K K: the block "beta"');
  Key(VK_DOWN, []); Key(VK_END, []); Run;
  Check(E.BlockMarked and (E.CaretY = 2), 'the caret moved down: the block is still marked');
  Dump('a marked Turbo block');
  Key(Ord('K'), [ssCtrl]); TUIPostChar('c'); Run;
  Check((E.Lines[1] = 'gammabeta') and (E.MarkedText = 'beta') and (E.CaretX = 6),
        'Ctrl+K C: a copy at the caret, the copy is the block now');
  Key(Ord('K'), [ssCtrl]); TUIPostChar('y'); Run;
  Check((E.Lines[1] = 'gamma') and not E.BlockMarked, 'Ctrl+K Y: the block deleted');
  Key(VK_HOME, [ssCtrl]); Key(Ord('K'), [ssCtrl]); TUIPostChar('b');
  Key(VK_RIGHT, [ssCtrl]); Key(Ord('K'), [ssCtrl]); TUIPostChar('k'); Run;
  Check(E.MarkedText = 'alpha ', 'the block "alpha "');
  Key(Ord('Q'), [ssCtrl]); TUIPostChar('c'); Run;
  Check((E.CaretY = 2) and (E.CaretX = 6), 'Ctrl+Q C: the end of the file');
  Key(Ord('K'), [ssCtrl]); TUIPostChar('v'); Run;
  Check((E.Lines[0] = 'beta') and (E.Lines[1] = 'gammaalpha ') and (E.MarkedText = 'alpha '),
        'Ctrl+K V: the block moved to the caret');
  Key(VK_HOME, [ssCtrl]); Key(Ord('Q'), [ssCtrl]); TUIPostChar('b'); Run;
  Check((E.CaretY = 2) and (E.CaretX = 6), 'Ctrl+Q B: the start of the block');
  Key(Ord('Z'), [ssCtrl]); Run;
  Check((E.Lines[0] = 'alpha beta') and (E.Lines[1] = 'gamma'), 'one Undo takes back the move');
  Key(Ord('K'), [ssCtrl]); TUIPostChar('l'); Key(Ord('K'), [ssCtrl]); TUIPostChar('h'); Run;
  Check(not E.BlockMarked, 'Ctrl+K L marks the line, Ctrl+K H unmarks');
  E.Text := '  some code  ';
  E.CaretXY := Point(8, 1);
  Key(Ord('Q'), [ssCtrl]); TUIPostChar('s'); Run;
  Check(E.CaretX = 1, 'Ctrl+Q S: the start of the line');
  Key(Ord('Q'), [ssCtrl]); TUIPostChar('d'); Run;
  Check(E.CaretX = 12, 'Ctrl+Q D: the end of the text on the line');
  E.CaretXY := Point(3, 1);
  Key(Ord('Q'), [ssCtrl]); TUIPostChar('y'); Run;
  Check(E.Lines[0] = '  ', 'Ctrl+Q Y: deleted to the end of the line');

  { ---- the Edit menu }
  E.Text := 'abc';
  E.CaretXY := Point(4, 1);
  TUIPostString('def'); Run;
  Key(Ord('E'), [ssAlt]); TUIPostChar('u'); Run;
  Check(E.Lines[0] = 'abc', 'Edit|Undo');
  Key(Ord('E'), [ssAlt]); TUIPostChar('r'); Run;
  Check(E.Lines[0] = 'abcdef', 'Edit|Redo');

  { ---- WordStar keys }
  E.WordStarKeys := true;
  E.Text := 'first line' + LineEnding + 'second line' + LineEnding + 'third';
  E.CaretXY := Point(1, 1);
  Key(Ord('X'), [ssCtrl]); Key(Ord('D'), [ssCtrl]); Key(Ord('D'), [ssCtrl]); Run;
  Check((E.CaretY = 2) and (E.CaretX = 3), 'WordStar: Ctrl+X down, Ctrl+D right');
  Key(Ord('E'), [ssCtrl]); Key(Ord('S'), [ssCtrl]); Run;
  Check((E.CaretY = 1) and (E.CaretX = 2), 'Ctrl+E up, Ctrl+S left');
  Key(Ord('F'), [ssCtrl]); Run;
  Check(E.CaretX = 7, 'Ctrl+F: the next word');
  Key(Ord('G'), [ssCtrl]); Run;
  Check(E.Lines[0] = 'first ine', 'Ctrl+G: delete the character');
  Key(Ord('T'), [ssCtrl]); Run;
  Check(E.Lines[0] = 'first ', 'Ctrl+T: delete the word');
  Key(Ord('Y'), [ssCtrl]); Run;
  Check((E.Lines.Count = 2) and (E.Lines[0] = 'second line'), 'Ctrl+Y: delete the line');
  Key(Ord('V'), [ssCtrl]); Run;
  Check(not E.InsertMode, 'Ctrl+V: overwrite');
  Key(Ord('V'), [ssCtrl]); Run;
  E.WordStarKeys := false;
  E.CaretXY := Point(1, 1);
  Key(VK_RIGHT, [ssShift]); Key(Ord('X'), [ssCtrl]); Run;
  Check(E.Lines[0] = 'econd line', 'WordStarKeys off: Ctrl+X is cut again');
  Check(E.UndoCount >= 1, 'undo steps: ' + IntToStr(E.UndoCount));
  E.MaxUndo := 4;
  for i := 1 to 10 do begin TUIPostString('a '); Run; end;
  Check(Length(E.Lines[0]) > 0, 'typing with MaxUndo 4');
  n := 0;
  while E.CanUndo do begin E.Undo; inc(n); end;
  Check(n <= 4, 'MaxUndo 4: at most 4 steps kept: ' + IntToStr(n));
  E.MaxUndo := 1024;

  { ---- the state cache while typing }
  E.Text := '';
  for i := 1 to 300 do E.Lines.Add('  x := x + ' + IntToStr(i) + ';');
  E.CaretXY := Point(1, 1);
  Run;
  n := E.ScannedLines;
  Key(VK_DOWN, []); Key(VK_DOWN, []); TUIPostString('{'); Run;
  Check((FgAt(2, 0) = tcLightGray) and (FgAt(10, 4) = tcLightGray), 'typing "{": the lines below turn into the comment');
  Check(E.ScannedLines - n < 40, 'and only the lines on screen were scanned: ' + IntToStr(E.ScannedLines - n));
  TUIPostString('}'); Run;
  Check((FgAt(2, 4) = tcYellow) and (FgAt(10, 2) = tcYellow), 'typing "}": back to code');
  Dump('typing in a 300 line file');

  { ---- the mouse }
  o := Cell(5, 6);
  TUIPostClick(o.X, o.Y); Run;
  Check((E.CaretY = 6) and (E.CaretX = 7), 'a click put the caret at line 6, column 7');
  o := Cell(8, 30);
  TUIPostClick(o.X, o.Y); Run;
  Check((E.CaretY = 9) and (E.CaretX = 31), 'a click past the end of a line');
  o := Cell(3, 2);
  TUIPostMouse(o.X, o.Y, 0); TUIPostMouse(o.X, o.Y, 1);
  TUIPostMouse(o.X + 5, o.Y + 1, 1); TUIPostMouse(o.X + 5, o.Y + 1, 0); Run;
  Check(E.SelAvail and (E.BlockBegin.Y = 4) and (E.BlockEnd.Y = 5) and (E.BlockEnd.X = 8),
        'a drag selected from 4,3 to 5,8');
  o := Cell(2, 4);
  TUIPostClick(o.X, o.Y); TUIPostClick(o.X, o.Y); Run;
  Check(E.SelText = 'x', 'a double click selected a word: ' + E.SelText);
  o := Cell(6, 0);
  TUIPostClick(o.X - 3, o.Y); Run;
  Check(E.SelText = E.Lines[6] + LineEnding, 'a click in the gutter selected the line');

  { ---- scrolling }
  Key(VK_HOME, [ssCtrl]); Key(VK_NEXT, []); Run;
  Check((E.TopLine > 1) and (E.CaretY > E.LinesInWindow - 2), 'PgDn');
  n := E.TopLine;
  o := Cell(E.TopLine + 2, 3);           { (Cell takes the line number in the file) }
  TUIPostWheel(o.X, o.Y, -120); Run;
  Check(E.TopLine = n + 3, 'the wheel scrolls 3 lines: ' + IntToStr(n) + ' -> ' + IntToStr(E.TopLine));
  Key(VK_END, [ssCtrl]); Run;
  Check((E.CaretY = 300) and (E.TopLine = 300 - E.LinesInWindow + 1), 'Ctrl+End: the last line at the bottom');
  E.Lines.Add(StringOfChar('-', 120) + 'END');
  Key(VK_END, [ssCtrl]); Key(VK_END, []); Run;
  Check((E.CaretX = 124) and (E.LeftChar > 1), 'a long line: End scrolled sideways');
  Dump('a long line, scrolled sideways');

  { ---- tabs in loaded text, QBasic }
  E.Text := 'a'#9'b'#9#9'c';
  Check(E.Lines[0] = 'a       b               c', 'tabs became spaces (TabWidth 8)');
  if FileExists('SAMPLE.BAS') then
  begin
    CodeForm.OpenFile('SAMPLE.BAS');
    Run;
    Check(E.Highlighter = CodeForm.BasSyn, 'SAMPLE.BAS: the QBasic highlighter');
    Check(FgAt(0, 0) = tcLightGray, 'a '' comment: grey');
    Check(FgAt(1, 0) = tcLightGreen, '''$DYNAMIC: a directive');
    E.TopLine := 10;
    Run;
    Check(FgAt(17, 0) = tcLightRed, '10 at the line start: a label, light red');
    Check(FgAt(18, 0) = tcLightRed, 'Again: a label too');
    E.TopLine := 1;
    Run;
    Check(FgAt(12, 0) = tcWhite, 'PRINT: a keyword');
    Dump('SAMPLE.BAS');
  end
  else writeln(Log, 'note  SAMPLE.BAS not found: skipped');

  { ---- a big file }
  if FileExists('TUICTRL.PAS') then
  begin
    CodeForm.OpenFile('TUICTRL.PAS');
    Run;
    n := E.ScannedLines;
    t0 := HWTicks;
    i := 0;
    repeat
      Key(VK_NEXT, []);
      Run;
      inc(i);
    until (E.CaretY >= E.Lines.Count) or (i > 2000);
    t1 := HWTicks;
    Check(E.CaretY = E.Lines.Count, 'TUICTRL.PAS (' + IntToStr(E.Lines.Count) + ' lines): PgDn to the end');
    writeln(Log, 'time  ', i, ' x PgDn through ', E.Lines.Count, ' lines: ', t1 - t0, ' ms (',
            (t1 - t0) div i, ' ms a page, screen painted each time)');
    Check(E.ScannedLines - n <= E.Lines.Count, 'every line scanned at most once while paging: ' +
          IntToStr(E.ScannedLines - n));
    n := E.ScannedLines;
    Key(VK_HOME, [ssCtrl]); Run;
    Key(VK_END, [ssCtrl]); Run;
    Check(E.ScannedLines = n, 'jumping back to the end: nothing scanned again');
    TUIPostString('x'); Run;
    Check(E.ScannedLines - n <= 2, 'typing on the last line: ' + IntToStr(E.ScannedLines - n) + ' line(s) scanned');
    Dump('the end of TUICTRL.PAS');
  end
  else writeln(Log, 'note  TUICTRL.PAS not found: skipped');

  writeln(Log);
  writeln(Log, Passed, ' passed, ', Failed, ' failed');
  Close(Log);
  counter.Free;
end.
