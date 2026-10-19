@echo off
setlocal
where fpc >nul 2>nul
if errorlevel 1 (
  echo Free Pascal compiler fpc.exe was not found in PATH.
  exit /b 1
)
if not exist winbuild mkdir winbuild
if not exist winbuild\units mkdir winbuild\units
if not exist winbuild\testunits mkdir winbuild\testunits
set FLAGS=-Twin64 -Mobjfpc -O1 -Fi. -Fu. -FEwinbuild -FUwinbuild\units
if /I "%1"=="win32" set FLAGS=-Twin32 -Mobjfpc -O1 -Fi. -Fu. -FEwinbuild -FUwinbuild\units
if /I "%1"=="test" goto tests
:demo
fpc %FLAGS% -B TUIDEMO.PAS
if errorlevel 1 exit /b 1
fpc %FLAGS% -B LVCODE.PAS
if errorlevel 1 exit /b 1
:tests
fpc %FLAGS% -FUwinbuild\testunits -dTUIEMU -B TUITEST.PAS
if errorlevel 1 exit /b 1
echo Finished. Binaries in winbuild.
echo To test the visible UI: winbuild\TUIDEMO.EXE
exit /b 0
