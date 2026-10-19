# LazarusVision Linux experimental port (Revision 08)

Based on validated Windows caret-fix Revision 07. DOS GO32v2 and Windows backend source is unchanged; Linux is selected only by `{$IFDEF LINUX}` / `TUILINUX`.

## Compile
`chmod +x BUILD_LINUX.SH && ./BUILD_LINUX.SH`

## Run
Use an interactive UTF-8 terminal (xterm, GNOME Terminal, Konsole, etc.): `./linuxbuild/TUIDEMO` or `./linuxbuild/LVCODE`.
The terminal backend uses `stty` and `/dev/tty`, UTF-8 CP437-to-Unicode rendering, ANSI colors, alternate screen, raw keyboard input, and SGR mouse support. It restores terminal settings on normal exit. Run `stty sane` if an abnormal termination leaves the terminal unusable.

## Limitations / testing
- **Unverified build**: Free Pascal is not installed in this environment, so compile and runtime validation must occur on Linux.
- Fixed 240x100 maximum cells, dimensions detected at application start. Live resize is not yet handled.
- ANSI keyboard parsing is initial: some Alt/Ctrl/function combinations and Unicode input require further work.
- The terminal backend uses `/dev/tty`, `stty`, and a UTF-8 capable terminal; it is not supported through redirected stdio.
- Native OS clipboard is not implemented on Linux; internal clipboard remains.
- Child console programs run synchronously with terminal handoff, but require Linux testing.
- Windows and DOS source blocks are intentionally not modified, and should be regression-tested before release.
