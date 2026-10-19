{-----------------------------------------------------------------------------}
{  LVEXEC - running other programs from LVCode: the compiler (its output      }
{  goes to a file) and the program you built (on the user screen).            }
{                                                                             }
{  DOS: through COMSPEC (COMMAND.COM /C ... > file), so the compiler is found  }
{  in the PATH like at the prompt. Elsewhere (tests on the emulated screen):  }
{  /bin/sh -c.                                                               }
{-----------------------------------------------------------------------------}
unit LVExec;

{$mode objfpc}{$H+}
{$I TUI.INC}  { Define TUIWIN consistently with TUIHW/TUICTRL }

interface

uses Classes, SysUtils, TUIHW, TUIScrn, TUICtrl;

var
   { Run: wait for a key after the program, as the FP IDE does }
   LVWaitAfterRun: boolean = true;
   { the user screen: what the screen showed when the program ended }
   LVUserScreen: array of word;
   LVUserCols, LVUserRows: integer;

{ run Prog Args with the output going to OutFile; the exit code (-1: it }
{ could not be started)                                                }
function ExecRedirected(const Prog, Args, OutFile: string): integer;
function ExecCompiler(const Prog, ResponseFile, SourceFile, OutFile: string): integer;

{ run the program on the user screen; afterwards (LVWaitAfterRun) "Press any }
{ key"; the screen is kept for ShowUserScreen. The exit code                }
function RunOnUserScreen(const Exe, Params: string): integer;

{ show the last user screen until a key is pressed }
procedure ShowUserScreen;

implementation

{$IFDEF TUIWIN}
uses Process;
{$ENDIF}

{ Run FPC as a direct child and wait for its actual exit. Avoid cmd.exe /C,
  which can misinterpret spaces, metacharacters and executable quoting. }
function ExecCompiler(const Prog, ResponseFile, SourceFile, OutFile: string): integer;
{$IFDEF TUIWIN}
var P: TProcess;
    F: TFileStream;
    Buf: array[0..8191] of byte;
    N: longint;
begin
   Result := -1;
   DeleteFile(OutFile);
   P := TProcess.Create(nil);
   try
      P.Executable := Prog;
      P.Parameters.Add('@' + ResponseFile);
      P.Parameters.Add(SourceFile);
      P.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      F := TFileStream.Create(OutFile, fmCreate);
      try
         try
            P.Execute;
            repeat
               N := P.Output.NumBytesAvailable;
               if N > SizeOf(Buf) then N := SizeOf(Buf);
               if N > 0 then
               begin
                  N := P.Output.Read(Buf, N);
                  if N > 0 then F.WriteBuffer(Buf, N);
               end
               else if P.Running then Sleep(10);
            until (not P.Running) and (P.Output.NumBytesAvailable = 0);
            P.WaitOnExit;
            Result := P.ExitStatus;
         except
            on E: Exception do
            begin
               Result := -1;
               if P.Running then P.Terminate(1);
               { Leave a meaningful diagnostic for LVCode's message pane. }
               F.WriteBuffer(PChar(E.Message)^, Length(E.Message));
            end;
         end;
      finally
         F.Free;
      end;
   finally
      P.Free;
   end;
end;
{$ELSE}
begin
   Result := ExecRedirected(Prog, '@' + ResponseFile + ' ' + SourceFile, OutFile);
end;
{$ENDIF}

function ExecRedirected(const Prog, Args, OutFile: string): integer;
var cmd: string;
begin
   DeleteFile(OutFile);
   try
      {$IFDEF GO32V2}
      cmd := GetEnvironmentVariable('COMSPEC');
      if cmd = '' then cmd := 'COMMAND.COM';
      Result := ExecuteProcess(cmd, '/C ' + Prog + ' ' + Args + ' > ' + OutFile);
      {$ELSE}
        {$IFDEF WINDOWS}
      cmd := GetEnvironmentVariable('COMSPEC');
      if cmd = '' then cmd := 'cmd.exe';
      Result := ExecuteProcess(cmd, '/C ' + Prog + ' ' + Args + ' > ' + OutFile + ' 2>&1');
        {$ELSE}
      cmd := Prog + ' ' + Args + ' > ' + OutFile + ' 2>&1';
      Result := ExecuteProcess('/bin/sh', ['-c', cmd]);
        {$ENDIF}
      {$ENDIF}
   except
      on E: Exception do Result := -1;
   end;
end;

procedure SaveUserScreen;
begin
   LVUserCols := ScrCols;
   LVUserRows := ScrRows;
   SetLength(LVUserScreen, ScrCols * ScrRows);
   HWReadCells(0, LVUserScreen[0], ScrCols * ScrRows);
end;

{$IFNDEF GO32V2}
{ the emulated screen: the program's output (a file) drawn on it }
procedure OutputToScreen(const OutFile: string);
var t: TStringList;
    i, x, y: integer;
    cells: array of word;
    s: string;
begin
   SetLength(cells, ScrCols * ScrRows);
   for i := 0 to High(cells) do cells[i] := $0720;
   t := TStringList.Create;
   try
      if FileExists(OutFile) then t.LoadFromFile(OutFile);
      t.Add('');
      if LVWaitAfterRun then t.Add('Press any key to return to LVCode...');
      { the last lines that fit, as a scrolled console would show them }
      y := t.Count - ScrRows;
      if y < 0 then y := 0;
      for i := y to t.Count - 1 do
      begin
         s := t[i];
         for x := 1 to Length(s) do
            if x <= ScrCols then cells[(i - y) * ScrCols + x - 1] := $0700 or ord(s[x]);
      end;
   finally
      t.Free;
   end;
   HWWriteCells(0, cells[0], Length(cells));
end;
{$ENDIF}

function RunOnUserScreen(const Exe, Params: string): integer;
var dir: string;
begin
   Application.SuspendScreen(true);
   dir := GetCurrentDir;
   try
      {$IFDEF GO32V2}
      try
         Result := ExecuteProcess(Exe, Params);
      except
         on E: Exception do
         begin
            writeln('Cannot run ', Exe, ': ', E.Message);
            Result := -1;
         end;
      end;
      if LVWaitAfterRun then
      begin
         writeln;
         write('Press any key to return to LVCode...');
         while HWKeyPressed do HWReadKey;
         HWReadKey;
      end;
      {$ELSE}
        {$IFDEF TUIWIN}
      { Run as a child of LVCode, not through cmd.exe. ExecuteProcess waits
        for the program to exit, preserving interactive stdin/stdout. }
      HWExternalConsoleBegin;
      try
         try
            Result := ExecuteProcess(Exe, Params);
         except
            on E: Exception do
            begin
               WriteLn('Cannot run ', Exe, ': ', E.Message);
               Result := -1;
            end;
         end;
         if LVWaitAfterRun then
         begin
            WriteLn;
            Write('Press ENTER to return to LVCode...');
            ReadLn;
         end;
      finally
         HWExternalConsoleEnd;
      end;
        {$ELSE}
          {$IFDEF TUILINUX}
      HWExternalConsoleBegin;
      try
         try
            Result := ExecuteProcess(Exe, Params);
         except
            on E: Exception do begin
               WriteLn('Cannot run ', Exe, ': ', E.Message);
               Result := -1;
            end;
         end;
         if LVWaitAfterRun then begin
            WriteLn;
            Write('Press ENTER to return to LVCode...');
            ReadLn;
         end;
      finally
         HWExternalConsoleEnd;
      end;
          {$ELSE}
      Result := ExecRedirected(Exe, Params, 'LVRUN.OUT');
      OutputToScreen('LVRUN.OUT');
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
      SaveUserScreen;
   finally
      SetCurrentDir(dir);
      Application.ResumeScreen;
   end;
end;

procedure ShowUserScreen;
begin
   if Length(LVUserScreen) = 0 then exit;
   Application.SuspendScreen(false);
   try
      if (LVUserCols = ScrCols) and (LVUserRows = ScrRows) then
         HWWriteCells(0, LVUserScreen[0], Length(LVUserScreen));
      {$IFDEF GO32V2}
      while HWKeyPressed do HWReadKey;
      HWReadKey;
      {$ENDIF}
   finally
      Application.ResumeScreen;
   end;
end;

end.
