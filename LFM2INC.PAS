program Lfm2Inc;

(* LFM2INC FORM.LFM [FORM.LFI]
  Turns an .lfm into an include file holding it as a string constant, so
  the form can be built into the program:
     RegisterFormText(TMyForm, {$I FORM.LFI});
  (FPTUI forms find their .lfm file at run time too; this is for programs
  that should not need the file next to them.) *)

{$mode objfpc}{$H+}

uses
  Classes, SysUtils;

var
  src, dst: TStringList;
  i: integer;
  outName, s: string;
begin
  if ParamCount < 1 then
  begin
    writeln('LFM2INC form.lfm [form.lfi]');
    halt(1);
  end;
  if ParamCount >= 2 then outName := ParamStr(2)
  else outName := ChangeFileExt(ParamStr(1), '.LFI');
  src := TStringList.Create;
  dst := TStringList.Create;
  try
    src.LoadFromFile(ParamStr(1));
    dst.Add('{ ' + ExtractFileName(outName) + ' - made by LFM2INC from ' + ExtractFileName(ParamStr(1)) + ' }');
    for i := 0 to src.Count - 1 do
    begin
      s := '''' + StringReplace(src[i], '''', '''''', [rfReplaceAll]) + '''#10';
      if i < src.Count - 1 then s := s + ' +';
      dst.Add(s);
    end;
    if src.Count = 0 then dst.Add('''''');
    dst.SaveToFile(outName);
    writeln(outName, ': ', src.Count, ' lines');
  finally
    src.Free;
    dst.Free;
  end;
end.
