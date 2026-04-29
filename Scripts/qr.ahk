#NoEnv
#SingleInstance Force

pythonPath := "pythonw"
; استخدام مسار ديناميكي بدلاً من مسار ثابت ليعمل السكربت حتى لو تغير مكان المجلد
scriptPath := A_ScriptDir "\qr_display.py"
command := pythonPath . " -u """ . scriptPath . """"

Run, %command%
ExitApp