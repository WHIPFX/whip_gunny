@echo off
rem Rebuild whip_gunny's magazine-loading animation from the XML in this folder.
rem   whippy_mag_load.ycd.xml  ->  ..\stream\whippy_mag_load.ycd
rem
rem The XML is CodeWalker's clip-dictionary format. It holds two clips, both 0.8 s:
rem   load_x2          the pack's clip (sped up from 1.2 s on 29 Sep 2026), played on foot
rem   load_x2_seated   the same animation without the SKEL_Spine0-3 tracks, played in a vehicle
rem                    so the ped keeps the seat's back pose instead of sitting bolt upright
rem
rem Needs the packer at C:\Tools\whip\cwaudio (built on CodeWalker.Core, github.com/dexyfex/CodeWalker).
rem Restart the server afterwards: streamed files are picked up on start.
setlocal
set CW=C:\Tools\whip\cwaudio\bin\Release\net10.0-windows\cwaudio.exe
"%CW%" xml2ycd "%~dp0whippy_mag_load.ycd.xml" "%~dp0..\stream\whippy_mag_load.ycd" || exit /b 1
