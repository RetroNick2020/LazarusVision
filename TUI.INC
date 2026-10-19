{-----------------------------------------------------------------------------}
{  TUI.INC - switches shared by the TUI units (text mode Lazarus style UI).   }
{  Each unit sets  $mode objfpc  and  $H+  before including this file.         }
{-----------------------------------------------------------------------------}
{$B-}   { short circuit boolean evaluation }
{$R-}   { no range checks in the drawing loops }
{$Q-}   { no overflow checks }
{$S-}   { no stack checks }
{$I-}   { I/O errors checked by hand }

{ Define TUIEMU explicitly (-dTUIEMU) for headless tests on any host. }
{ Native Windows builds use TUIHW_WIN.INC; GO32v2 keeps BIOS backend. }
{$IFNDEF GO32V2}
  {$IFDEF WINDOWS}
    {$IFNDEF TUIEMU}
      {$DEFINE TUIWIN}
    {$ENDIF}
  {$ELSE}
    {$IFDEF LINUX}
      {$IFNDEF TUIEMU}
        {$DEFINE TUILINUX}
      {$ENDIF}
    {$ELSE}
      {$DEFINE TUIEMU}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}
