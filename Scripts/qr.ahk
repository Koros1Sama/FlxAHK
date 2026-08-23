#NoEnv
#SingleInstance Force

; إذا كان المستخدم يحدد نصاً ولم ينسخه، ننسخه بسرعة
ClipSaved := ClipboardAll
Clipboard := ""
Send, ^c
ClipWait, 0.08
if (Clipboard = "")
    Clipboard := ClipSaved

pythonPath := "pythonw"
; استخدام مسار ديناميكي بدلاً من مسار ثابت ليعمل السكربت حتى لو تغير مكان المجلد
scriptPath := A_ScriptDir "\qr_display.py"
command := pythonPath . " -u """ . scriptPath . """"

Run, %command%
ExitApp