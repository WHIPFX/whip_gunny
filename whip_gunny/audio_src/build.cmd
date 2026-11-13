@echo off
rem Rebuild whip_gunny's GTA audio from the XML in this folder.
rem   whippy_gunny.awc.xml + the wavs     ->  ..\audiodirectory\whippy_gunny.awc
rem   whippy_gunny_sounds.dat54.rel.xml   ->  ..\data\whippy_gunny_sounds.dat54.rel
rem Needs the packer at C:\Tools\whip\cwaudio (built on CodeWalker.Core, github.com/dexyfex/CodeWalker).
rem Restart the server afterwards: streamed audio is picked up on start.
setlocal
set CW=C:\Tools\whip\cwaudio\bin\Release\net10.0-windows\cwaudio.exe
if not exist "%~dp0..\audiodirectory" mkdir "%~dp0..\audiodirectory"
if not exist "%~dp0..\data" mkdir "%~dp0..\data"
"%CW%" xml2awc "%~dp0whippy_gunny.awc.xml" "%~dp0..\audiodirectory\whippy_gunny.awc" || exit /b 1
"%CW%" xml2rel "%~dp0whippy_gunny_sounds.dat54.rel.xml" "%~dp0..\data\whippy_gunny_sounds.dat54.rel" || exit /b 1
