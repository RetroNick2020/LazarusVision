{-----------------------------------------------------------------------------}
{  LVOPTS - LVCode's compiler options: what goes on the fpc command line.     }
{                                                                             }
{  The options are written to a response file (fpc @LVCODE.RSP FILE.PAS), so }
{  a long list of unit directories never runs into DOS's 126 character       }
{  limit; only the source file goes on the command line itself (fpc does not }
{  take it from a response file). The settings are kept in                   }
{  LVCODE.CFG (key=value lines) in the folder LVCode was started in.         }
{-----------------------------------------------------------------------------}
unit LVOpts;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

type
   { Compile: the file in the editor; Make: the primary file (or that one),  }
   { changed units with it; Build: everything again (-B)                      }
   TLVBuildKind = (bkCompile, bkMake, bkBuild);

   TLVOptions = class
   public
      CompilerPath: string;        { 'fpc': the one in the PATH }
      Mode: string;                { fpc objfpc delphi tp macpas iso: -M }
      TargetOS: string;            { '' the compiler's own; go32v2 win32 linux...: -T }
      OptLevel: integer;           { 0 none, 1..4: -O1..-O4 }
      OptSize: boolean;            { -Os }
      SmartLink: boolean;          { -XX -CX }
      StripSymbols: boolean;       { -Xs }
      DebugInfo: boolean;          { -g }
      LineInfo: boolean;           { -gl }
      HeapTrace: boolean;          { -gh }
      RangeChecks, OverflowChecks, IOChecks, StackChecks: boolean;   { -Cr -Co -Ci -Ct }
      Assertions: boolean;         { -Sa }
      AnsiStrings: boolean;        { -Sh: string = AnsiString }
      COperators: boolean;         { -Sc: += -= *= /= }
      Macros: boolean;             { -Sm }
      InlineCode: boolean;         { -Si }
      UnitDirs, IncludeDirs, LibraryDirs, ObjectDirs: string;   { ';' lists: -Fu -Fi -Fl -Fo }
      ExeOutputDir, UnitOutputDir: string;                        { -FE -FU }
      Defines: string;             { 'DEBUG;TEST': -dDEBUG -dTEST }
      ExtraOptions: string;        { anything else, as typed }
      ShowWarnings, ShowNotes, ShowHints, ShowInfo: boolean;      { -vw -vn -vh -vi }
      PrimaryFile: string;         { Make / Build / Run compile this one when set }
      RunParameters: string;       { given to the program by Run }
      AutoSave: boolean;           { save changed editor files before compiling }
      TabWidth, BlockIndent: integer;
      WordStarKeys, AutoIndent: boolean;
      constructor Create;
      procedure SetDefaults;
      procedure Assign(Source: TLVOptions);
      procedure LoadFromFile(const FileName: string);
      procedure SaveToFile(const FileName: string);
      { the options for compiling Source, one per line (the response file; }
      { fpc wants the file itself on the command line: WithSource false)  }
      procedure GetOptions(const Source: string; Kind: TLVBuildKind; List: TStrings;
                           WithSource: boolean = true);
      { the whole command, for showing it: fpc -Mobjfpc ... HELLO.PAS }
      function  CommandLine(const Source: string; Kind: TLVBuildKind): string;
      { the program the compiler makes from Source }
      function  ExeNameFor(const Source: string): string;
   end;

const
   LVModes: array[0..5] of string = ('fpc', 'objfpc', 'delphi', 'tp', 'macpas', 'iso');
   LVTargets: array[0..8] of string = ('', 'go32v2', 'msdos', 'win32', 'win64', 'linux',
                                       'freebsd', 'darwin', 'os2');

{ 'a;b;c' to its parts, blanks trimmed, empty ones left out }
procedure SplitList(const S: string; List: TStrings);

implementation

procedure SplitList(const S: string; List: TStrings);
var rest, part: string;
    p: integer;
begin
   List.Clear;
   rest := S;
   while rest <> '' do
   begin
      p := Pos(';', rest);
      if p = 0 then p := Length(rest) + 1;
      part := Trim(Copy(rest, 1, p - 1));
      Delete(rest, 1, p);
      if part <> '' then List.Add(part);
   end;
end;

constructor TLVOptions.Create;
begin
   inherited Create;
   SetDefaults;
end;

procedure TLVOptions.SetDefaults;
begin
   CompilerPath := 'fpc';
   Mode := 'objfpc';
   TargetOS := '';
   OptLevel := 1;
   OptSize := false;
   SmartLink := false;
   StripSymbols := false;
   DebugInfo := false;
   LineInfo := false;
   HeapTrace := false;
   RangeChecks := false;
   OverflowChecks := false;
   IOChecks := true;
   StackChecks := false;
   Assertions := false;
   AnsiStrings := true;
   COperators := false;
   Macros := false;
   InlineCode := false;
   UnitDirs := '';
   IncludeDirs := '';
   LibraryDirs := '';
   ObjectDirs := '';
   ExeOutputDir := '';
   UnitOutputDir := '';
   Defines := '';
   ExtraOptions := '';
   ShowWarnings := true;
   ShowNotes := true;
   ShowHints := false;
   ShowInfo := true;
   PrimaryFile := '';
   RunParameters := '';
   AutoSave := true;
   TabWidth := 8;
   BlockIndent := 2;
   WordStarKeys := false;
   AutoIndent := true;
end;

procedure TLVOptions.Assign(Source: TLVOptions);
begin
   CompilerPath := Source.CompilerPath;     Mode := Source.Mode;
   TargetOS := Source.TargetOS;             OptLevel := Source.OptLevel;
   OptSize := Source.OptSize;               SmartLink := Source.SmartLink;
   StripSymbols := Source.StripSymbols;     DebugInfo := Source.DebugInfo;
   LineInfo := Source.LineInfo;             HeapTrace := Source.HeapTrace;
   RangeChecks := Source.RangeChecks;       OverflowChecks := Source.OverflowChecks;
   IOChecks := Source.IOChecks;             StackChecks := Source.StackChecks;
   Assertions := Source.Assertions;         AnsiStrings := Source.AnsiStrings;
   COperators := Source.COperators;         Macros := Source.Macros;
   InlineCode := Source.InlineCode;         UnitDirs := Source.UnitDirs;
   IncludeDirs := Source.IncludeDirs;       LibraryDirs := Source.LibraryDirs;
   ObjectDirs := Source.ObjectDirs;         ExeOutputDir := Source.ExeOutputDir;
   UnitOutputDir := Source.UnitOutputDir;   Defines := Source.Defines;
   ExtraOptions := Source.ExtraOptions;     ShowWarnings := Source.ShowWarnings;
   ShowNotes := Source.ShowNotes;           ShowHints := Source.ShowHints;
   ShowInfo := Source.ShowInfo;             PrimaryFile := Source.PrimaryFile;
   RunParameters := Source.RunParameters;   AutoSave := Source.AutoSave;
   TabWidth := Source.TabWidth;             BlockIndent := Source.BlockIndent;
   WordStarKeys := Source.WordStarKeys;     AutoIndent := Source.AutoIndent;
end;

function B2S(B: boolean): string;
begin
   if B then Result := '1' else Result := '0';
end;

procedure TLVOptions.SaveToFile(const FileName: string);
var t: TStringList;
begin
   if FileName = '' then exit;
   t := TStringList.Create;
   try
      t.Add('; LVCode settings');
      t.Values['Compiler'] := CompilerPath;
      t.Values['Mode'] := Mode;
      t.Values['Target'] := TargetOS;
      t.Values['OptLevel'] := IntToStr(OptLevel);
      t.Values['OptSize'] := B2S(OptSize);
      t.Values['SmartLink'] := B2S(SmartLink);
      t.Values['Strip'] := B2S(StripSymbols);
      t.Values['Debug'] := B2S(DebugInfo);
      t.Values['LineInfo'] := B2S(LineInfo);
      t.Values['HeapTrace'] := B2S(HeapTrace);
      t.Values['RangeChecks'] := B2S(RangeChecks);
      t.Values['OverflowChecks'] := B2S(OverflowChecks);
      t.Values['IOChecks'] := B2S(IOChecks);
      t.Values['StackChecks'] := B2S(StackChecks);
      t.Values['Assertions'] := B2S(Assertions);
      t.Values['AnsiStrings'] := B2S(AnsiStrings);
      t.Values['COperators'] := B2S(COperators);
      t.Values['Macros'] := B2S(Macros);
      t.Values['Inline'] := B2S(InlineCode);
      t.Values['UnitDirs'] := UnitDirs;
      t.Values['IncludeDirs'] := IncludeDirs;
      t.Values['LibraryDirs'] := LibraryDirs;
      t.Values['ObjectDirs'] := ObjectDirs;
      t.Values['ExeOutputDir'] := ExeOutputDir;
      t.Values['UnitOutputDir'] := UnitOutputDir;
      t.Values['Defines'] := Defines;
      t.Values['Extra'] := ExtraOptions;
      t.Values['Warnings'] := B2S(ShowWarnings);
      t.Values['Notes'] := B2S(ShowNotes);
      t.Values['Hints'] := B2S(ShowHints);
      t.Values['Info'] := B2S(ShowInfo);
      t.Values['Primary'] := PrimaryFile;
      t.Values['Parameters'] := RunParameters;
      t.Values['AutoSave'] := B2S(AutoSave);
      t.Values['TabWidth'] := IntToStr(TabWidth);
      t.Values['BlockIndent'] := IntToStr(BlockIndent);
      t.Values['WordStar'] := B2S(WordStarKeys);
      t.Values['AutoIndent'] := B2S(AutoIndent);
      t.SaveToFile(FileName);
   finally
      t.Free;
   end;
end;

procedure TLVOptions.LoadFromFile(const FileName: string);
var t: TStringList;

   function S(const K, Def: string): string;
   begin
      if t.IndexOfName(K) >= 0 then Result := t.Values[K] else Result := Def;
   end;

   function B(const K: string; Def: boolean): boolean;
   begin
      Result := S(K, B2S(Def)) = '1';
   end;

   function I(const K: string; Def: integer): integer;
   begin
      Result := StrToIntDef(S(K, IntToStr(Def)), Def);
   end;

begin
   if not FileExists(FileName) then exit;
   t := TStringList.Create;
   try
      t.LoadFromFile(FileName);
      CompilerPath := S('Compiler', CompilerPath);
      Mode := S('Mode', Mode);
      TargetOS := S('Target', TargetOS);
      OptLevel := I('OptLevel', OptLevel);
      OptSize := B('OptSize', OptSize);
      SmartLink := B('SmartLink', SmartLink);
      StripSymbols := B('Strip', StripSymbols);
      DebugInfo := B('Debug', DebugInfo);
      LineInfo := B('LineInfo', LineInfo);
      HeapTrace := B('HeapTrace', HeapTrace);
      RangeChecks := B('RangeChecks', RangeChecks);
      OverflowChecks := B('OverflowChecks', OverflowChecks);
      IOChecks := B('IOChecks', IOChecks);
      StackChecks := B('StackChecks', StackChecks);
      Assertions := B('Assertions', Assertions);
      AnsiStrings := B('AnsiStrings', AnsiStrings);
      COperators := B('COperators', COperators);
      Macros := B('Macros', Macros);
      InlineCode := B('Inline', InlineCode);
      UnitDirs := S('UnitDirs', UnitDirs);
      IncludeDirs := S('IncludeDirs', IncludeDirs);
      LibraryDirs := S('LibraryDirs', LibraryDirs);
      ObjectDirs := S('ObjectDirs', ObjectDirs);
      ExeOutputDir := S('ExeOutputDir', ExeOutputDir);
      UnitOutputDir := S('UnitOutputDir', UnitOutputDir);
      Defines := S('Defines', Defines);
      ExtraOptions := S('Extra', ExtraOptions);
      ShowWarnings := B('Warnings', ShowWarnings);
      ShowNotes := B('Notes', ShowNotes);
      ShowHints := B('Hints', ShowHints);
      ShowInfo := B('Info', ShowInfo);
      PrimaryFile := S('Primary', PrimaryFile);
      RunParameters := S('Parameters', RunParameters);
      AutoSave := B('AutoSave', AutoSave);
      TabWidth := I('TabWidth', TabWidth);
      BlockIndent := I('BlockIndent', BlockIndent);
      WordStarKeys := B('WordStar', WordStarKeys);
      AutoIndent := B('AutoIndent', AutoIndent);
   finally
      t.Free;
   end;
end;

procedure TLVOptions.GetOptions(const Source: string; Kind: TLVBuildKind; List: TStrings;
                                WithSource: boolean);
var parts: TStringList;
    i: integer;
    v: string;

   procedure Dirs(const Prefix, L: string);
   var j: integer;
   begin
      SplitList(L, parts);
      for j := 0 to parts.Count - 1 do List.Add(Prefix + parts[j]);
   end;

begin
   List.Clear;
   parts := TStringList.Create;
   try
      if Mode <> '' then List.Add('-M' + Mode);
      if TargetOS <> '' then List.Add('-T' + TargetOS);
      if OptLevel > 0 then List.Add('-O' + IntToStr(OptLevel));
      if OptSize then List.Add('-Os');
      if SmartLink then
      begin
         List.Add('-CX');
         List.Add('-XX');
      end;
      if StripSymbols then List.Add('-Xs');
      if DebugInfo then List.Add('-g');
      if LineInfo then List.Add('-gl');
      if HeapTrace then List.Add('-gh');
      if RangeChecks then List.Add('-Cr');
      if OverflowChecks then List.Add('-Co');
      if IOChecks then List.Add('-Ci');
      if StackChecks then List.Add('-Ct');
      if Assertions then List.Add('-Sa');
      if AnsiStrings then List.Add('-Sh');
      if COperators then List.Add('-Sc');
      if Macros then List.Add('-Sm');
      if InlineCode then List.Add('-Si');
      Dirs('-Fu', UnitDirs);
      Dirs('-Fi', IncludeDirs);
      Dirs('-Fl', LibraryDirs);
      Dirs('-Fo', ObjectDirs);
      if ExeOutputDir <> '' then List.Add('-FE' + ExeOutputDir);
      if UnitOutputDir <> '' then List.Add('-FU' + UnitOutputDir);
      v := StringReplace(Defines, ' ', ';', [rfReplaceAll]);
      SplitList(v, parts);
      for i := 0 to parts.Count - 1 do List.Add('-d' + parts[i]);
      { the messages: errors always, full file names (the IDE opens them) }
      v := '-ve';
      if ShowWarnings then v := v + 'w';
      if ShowNotes then v := v + 'n';
      if ShowHints then v := v + 'h';
      if ShowInfo then v := v + 'i';
      List.Add(v + 'b');
      if Kind = bkBuild then List.Add('-B');
      { extra options as typed, split at blanks }
      v := Trim(ExtraOptions);
      while v <> '' do
      begin
         i := Pos(' ', v);
         if i = 0 then i := Length(v) + 1;
         List.Add(Copy(v, 1, i - 1));
         v := Trim(Copy(v, i + 1, MaxInt));
      end;
      if WithSource then List.Add(Source);
   finally
      parts.Free;
   end;
end;

function TLVOptions.CommandLine(const Source: string; Kind: TLVBuildKind): string;
var l: TStringList;
    i: integer;
begin
   l := TStringList.Create;
   try
      GetOptions(Source, Kind, l);
      Result := CompilerPath;
      for i := 0 to l.Count - 1 do Result := Result + ' ' + l[i];
   finally
      l.Free;
   end;
end;

function TLVOptions.ExeNameFor(const Source: string): string;
var dir, ext: string;
begin
   { a DOS / Windows target gets .exe; built on DOS for DOS too }
   ext := '';
   {$IFDEF GO32V2}
   ext := '.exe';
   {$ENDIF}
   if (TargetOS = 'go32v2') or (TargetOS = 'msdos') or (TargetOS = 'win32') or
      (TargetOS = 'win64') or (TargetOS = 'os2') then ext := '.exe'
   else if TargetOS <> '' then
   begin
      {$IFDEF GO32V2}
      ext := '';
      {$ENDIF}
   end;
   if ExeOutputDir <> '' then dir := IncludeTrailingPathDelimiter(ExpandFileName(ExeOutputDir))
   else dir := ExtractFilePath(ExpandFileName(Source));
   Result := dir + ChangeFileExt(ExtractFileName(Source), ext);
end;

end.
