Sleep, 20
WinGet, id, list
unclosed_count := 0
Loop, %id%
{
    this_id := id%A_Index%
    WinGetClass, class, ahk_id %this_id%
    If (class = "WorkerW" or class = "Progman" or class = "Shell_TrayWnd")
        continue
    
    WinClose, ahk_id %this_id%
    WinWaitClose, ahk_id %this_id%, , 1 ; ننتظر ثانية كحد أقصى لتُغلق النافذة
    
    ; إذا لم تُغلق النافذة (غالباً بسبب ظهور رسالة "هل تريد حفظ التغييرات؟")
    if WinExist("ahk_id " this_id) {
        WinActivate, ahk_id %this_id%
        TrayTip, تحذير الإطفاء, هناك برنامج يطلب تدخلك ولم يتم إغلاقه!, 3, 2
        unclosed_count++
        continue
    }
}

if (unclosed_count > 0) {
    MsgBox, 48, إيقاف الطوارئ, تم إيقاف عملية إطفاء الجهاز! `nيوجد برنامج أو أكثر يطلب تدخلك (ربما عمل غير محفوظ).
    ExitApp
}

MsgBox, 4, تأكيد الإيقاف, هل أنت متأكد أنك تريد إيقاف التشغيل، سيدي كوروس؟
IfMsgBox, No
    ExitApp

; استخدام رقم 1 (Shutdown العادي) بدلاً من 5 (الذي يجبر الإغلاق بقوة Force وقد يدمر الملفات)
Shutdown, 1
ExitApp