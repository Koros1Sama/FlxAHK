#SingleInstance Force  ; للتأكد من أن نسخة واحدة فقط تعمل

If (InStr(Clipboard, "\") && FileExist(Clipboard)) ; التحقق من المسار
    Run, %Clipboard%
Else
{
    ; إعدادات الشريط الأحمر الصغير
    BarHeight := 10  ; ارتفاع الشريط صغير (30 بكسل)
    BarWidth := A_ScreenWidth
    FlashColor := "FF0000"  ; لون أحمر
    StartY := A_ScreenHeight - BarHeight  ; الموقع في أسفل الشاشة
    StartX := (A_ScreenWidth - BarWidth) // 2  ; توسيط الشريط أفقيًا

    ; إنشاء GUI للشريط
    Gui, WarningBar:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, WarningBar:Color, %FlashColor%
    Gui, WarningBar:Show, x%StartX% y%StartY% w%BarWidth% h%BarHeight% NoActivate

    ; تأثير الظهور التدريجي (Fade In)
    Loop, 15  ; خطوات أقل لتسريع التأثير
    {
        Alpha := A_Index * 17  ; زيادة الشفافية بسرعة (من 0 إلى 255 تقريبًا)
        WinSet, Transparent, %Alpha%, ahk_class AutoHotkeyGUI
        Sleep 2  ; سرعة الظهور (75 مللي ثانية كل التأثير)
    }

    Sleep 50  ; مدة بقاء الشريط (نص ثانية)

    ; تأثير الاختفاء التدريجي (Fade Out)
    Loop, 15
    {
        Alpha := 255 - (A_Index * 17)  ; تقليل الشفافية بسرعة
        WinSet, Transparent, %Alpha%, ahk_class AutoHotkeyGUI
        Sleep 2  ; سرعة الاختفاء
    }

    Gui, WarningBar:Destroy  ; إخفاء الشريط
}
ExitApp