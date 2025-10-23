Sleep, 20
WinGet, id, list
Loop, %id%
{
    this_id := id%A_Index%
    WinGetClass, class, ahk_id %this_id%
    If (class = "WorkerW" or class = "Progman" or class = "Shell_TrayWnd")
        continue
    WinClose, ahk_id %this_id%
    Sleep, 50
}

MsgBox, 4, تأكيد الإيقاف, هل أنت متأكد أنك تريد إيقاف التشغيل، سيدي كوروس؟
IfMsgBox, No
    return
Shutdown, 5
return