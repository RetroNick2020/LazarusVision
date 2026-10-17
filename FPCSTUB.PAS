program FpcStub;

{ A stand-in for fpc, for LVTEST in DOSBox (where there is no DOS fpc to
  run): it reads the options (@response file), "finds" the error in a line
  with "(x)" in it, writes the messages the way fpc does, and for a clean
  source makes the program by copying RUNME.EXE. The options it got go to
  STUB.ARG so the test can check them. }

{$mode objfpc}{$H+}

uses Classes, SysUtils,
  TUIHW;      { only for its DOSBox fix of the RTL's Move (see TUIHW) }

var
  args, src: TStringList;
  i, n, p: integer;
  source, exe, exedir: string;
  fin, fout: TFileStream;
begin
  args := TStringList.Create;
  src := TStringList.Create;
  for i := 1 to ParamCount do
    if Copy(ParamStr(i), 1, 1) = '@' then
    begin
      src.LoadFromFile(Copy(ParamStr(i), 2, MaxInt));
      args.AddStrings(src);
    end
    else args.Add(ParamStr(i));
  args.SaveToFile('STUB.ARG');
  source := '';
  exedir := '';
  for i := 0 to args.Count - 1 do
    if Copy(args[i], 1, 1) <> '-' then source := args[i]
    else if Copy(args[i], 1, 3) = '-FE' then exedir := Copy(args[i], 4, MaxInt);
  writeln('Free Pascal Compiler version 3.2.2 (LVTEST stub)');
  if (source = '') or not FileExists(source) then
  begin
    writeln('Fatal: Can''t open file "', source, '"');
    writeln('Fatal: Compilation aborted');
    halt(1);
  end;
  writeln('Compiling ', source);
  src.LoadFromFile(source);
  n := 0;
  for i := 0 to src.Count - 1 do
  begin
    p := Pos('(x)', src[i]);
    if p > 0 then
    begin
      writeln(source, '(', i + 1, ',', p + 1, ') Error: Identifier not found "x"');
      inc(n);
    end;
  end;
  if n > 0 then
  begin
    writeln(source, '(', src.Count, ',4) Fatal: There were ', n, ' errors compiling module, stopping');
    writeln('Fatal: Compilation aborted');
    halt(1);
  end;
  if exedir <> '' then exe := IncludeTrailingPathDelimiter(exedir) + ChangeFileExt(ExtractFileName(source), '.exe')
  else exe := ChangeFileExt(source, '.exe');
  writeln('Linking ', exe);
  { the "program": a copy of RUNME.EXE }
  fin := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'RUNME.EXE', fmOpenRead);
  try
    fout := TFileStream.Create(exe, fmCreate);
    try
      fout.CopyFrom(fin, 0);
    finally
      fout.Free;
    end;
  finally
    fin.Free;
  end;
  writeln(src.Count, ' lines compiled, 0.1 sec');
end.
