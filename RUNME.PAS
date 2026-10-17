program RunMe;
{ the "program" FPCSTUB makes: LVTEST runs it with Run (Ctrl+F9) }
uses TUIHW;  { the DOSBox fix of the RTL's Move }
var i: integer;
begin
  for i := 1 to 3 do writeln('Hello ', i);
  if ParamCount > 0 then writeln('Parameters: ', ParamStr(1));
end.
