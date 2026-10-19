#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p linuxbuild/units linuxbuild/testunits
FLAGS="-Tlinux -Mobjfpc -O1 -Fi. -Fu. -FElinuxbuild -FUlinuxbuild/units"
fpc $FLAGS -B TUIDEMO.PAS
fpc $FLAGS -B LVCODE.PAS
fpc $FLAGS -FUlinuxbuild/testunits -dTUIEMU -B TUITEST.PAS
printf '\nLinux binaries are under linuxbuild/\n'
