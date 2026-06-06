@echo off
echo Running Flx.ahk and capturing warnings...
"C:\Program Files\AutoHotkey\AutoHotkey.exe" Flx.ahk > warnings.txt 2>&1
echo Done! Please tell the AI that warnings.txt is ready.
pause
