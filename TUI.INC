{-----------------------------------------------------------------------------}
{  TUI.INC - switches shared by the TUI units (text mode Lazarus style UI).   }
{  Each unit sets  $mode objfpc  and  $H+  before including this file.         }
{-----------------------------------------------------------------------------}
{$B-}   { short circuit boolean evaluation }
{$R-}   { no range checks in the drawing loops }
{$Q-}   { no overflow checks }
{$S-}   { no stack checks }
{$I-}   { I/O errors checked by hand }

{ The DOS build (go32v2) talks to the hardware through the go32 unit. Any  }
{ other target (a Linux build used for testing) gets an emulated 80x25     }
{ text screen in memory, with input only from TUIPostKey / TUIPostMouse.   }
{$IFNDEF GO32V2}
  {$DEFINE TUIEMU}
{$ENDIF}
