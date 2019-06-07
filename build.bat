@echo off

:start
del %~n1.lst
64tass.exe %1 --long-address -x -b -o %~n1.bin --list %~n1.lst
if errorlevel 1 goto fail

:fail
choice /m "Try again?"
if errorlevel 2 goto end
goto start

:end
echo END OF LINE
