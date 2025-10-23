#NoEnv
#SingleInstance Force
    pythonPath := "pythonw"  ; أو المسار الكامل: "C:\Path\To\pythonw.exe"
    scriptPath := "c:\Users\KorosSama\Documents\GitHub\FlxAHK\Scripts\qr_display.py"
    command := pythonPath . " -u """ . scriptPath . """"
    Run, %command%  ; بدون Hide، لأن pythonw ما بيفتح console أصلاً
return