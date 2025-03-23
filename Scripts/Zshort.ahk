#SingleInstance Force  ; للتأكد من أن نسخة واحدة فقط تعمل
WinGetClass, ActiveClass, A
if (ActiveClass = "Photoshop")
{
    Send, ^+!]
    ExitApp  ; إنهاء السكربت بعد التنفيذ
}
else
    Input, Key, L1 T3
if (ErrorLevel = "Timeout")
    ExitApp  ; إنهاء إذا انتهى وقت الانتظار الأول
if (StrLen(key) = 1) {
    if (key = "z" || key = "Z") {
        if (ActiveClass = "Chrome_WidgetWin_1")
        {
            Input, key, L1 T3
            if (ErrorLevel = "Timeout")
                ExitApp  ; إنهاء إذا انتهى وقت الانتظار الثاني
            if (StrLen(key) = 1)
            {
                if (key = "z" || key = "Z")
                {
                    Send, ^+!\
                    Sleep, 100
                    Send, ^+!r
                    ExitApp
                }
                else if (key = "]")
                {
                    Send, ^+!]
                    Sleep, 10
                    Send, ]
                    Sleep, 10
                    Send, ^+!]
                    Sleep, 10
                    Send, i
                    Input, AnyKey, L1 T10
                    Send, ^+!r
                    ExitApp
                }
                else if (key = "[")
                {
                    Send, ^+!]
                    Sleep, 10
                    Send, p
                    Sleep, 10
                    Send, ^+!]
                    Sleep, 10
                    Send, i
                    Input, AnyKey, L1 T10
                    Send, ^+!r
                    ExitApp
                }
                else if (key = "p" || key = "P")
                {
                    Send, ^+!]
                    Sleep, 10
                    Send, [
                    Sleep, 10
                    Send, ^+!]
                    Sleep, 10
                    Send, ^p
                    Input, AnyKey, L1 T10
                    Send, ^+!r
                    ExitApp
                }
                ExitApp
            }
        }
        else {
            Send, ^+!%key%
            ExitApp
        }
    }
    else
    {
        Send, ^+!%key%
        ExitApp
    }
}
else
{
    Input, key, L1
    ExitApp
}
ExitApp  ; إنهاء افتراضي إذا لم يتم إدخال شيء