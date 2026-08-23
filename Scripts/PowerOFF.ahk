Sleep, 20
WinGet, id, list
Loop, %id%
{
    this_id := id%A_Index%
    WinGetClass, class, ahk_id %this_id%
    If (class = "WorkerW" or class = "Progman" or class = "Shell_TrayWnd")
        continue
    
    WinClose, ahk_id %this_id%
    WinWaitClose, ahk_id %this_id%, , 1 ; ننتظر ثانية كحد أقصى لتُغلق النافذة
}

; استخدام رقم 1 (Shutdown العادي) بدلاً من 5 (الذي يجبر الإغلاق بقوة Force وقد يدمر الملفات)
Shutdown, 1
ExitApp