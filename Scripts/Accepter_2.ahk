#NoEnv
#SingleInstance Off
DetectHiddenWindows, On

; --- Toggle: إذا شغال أوقفه ---
IfWinExist, Accepter_V2_ON
{
    WinClose, Accepter_V2_ON
    ExitApp
}

; --- إعدادات ---
DelayTime := 3000

; إحداثيات زر Retry (من Window Spy)
RetryX := 1866
RetryY := 912

; لون خلفية البانيل الداكنة تقريباً (أي شي أغمق من 0x40 يعتبر مافيه زر)
; لون زر Retry: 0x87848C = سطوع ~133
; لون الخلفية: ~0x1E1E1E أو 0x252526 = سطوع ~30
BrightnessThreshold := 60

; --- علامة ON ---
Gui, +AlwaysOnTop -Caption +ToolWindow +Owner
Gui, Color, 00AA44
Gui, Font, s11 Bold, Segoe UI
Gui, Add, Text, cWhite Center w40, V2
Gui, Show, x0 y0 w44 h22 NoActivate, Accepter_V2_ON

; --- بدء الفحص ---
SetTimer, CheckLoop, %DelayTime%
return

CheckLoop:
    ; 1. لازم VSCode (Antigravity) شغال
    IfWinNotExist, ahk_exe Code.exe
        return

    ; 2. أرسل Alt+Enter لـ Allow (ما يأثر لو مافيه Allow dialog)
    ControlSend,, !{Enter}, ahk_exe Code.exe

    ; 3. فحص هل زر Retry موجود عبر لون البيكسل
    CoordMode, Pixel, Screen
    PixelGetColor, PixelColor, %RetryX%, %RetryY%, RGB
    if (ErrorLevel)
        return

    ; استخراج مكونات اللون
    ColorR := (PixelColor >> 16) & 0xFF
    ColorG := (PixelColor >> 8) & 0xFF
    ColorB := PixelColor & 0xFF
    Brightness := (ColorR + ColorG + ColorB) / 3

    ; إذا السطوع أقل من الحد = مافيه زر (خلفية داكنة)
    if (Brightness < BrightnessThreshold)
        return

    ; 4. وجد زر! نفحص الإنترنت
    RunWait, %ComSpec% /c ping -n 1 -w 1500 8.8.8.8 >nul 2>nul, , Hide UseErrorLevel
    PingResult := ErrorLevel

    if (PingResult != 0)
    {
        ; مافيه إنترنت -> ما نسوي شي
        return
    }

    ; 5. إنترنت شغال = خطأ سيرفر/ضغط -> أضغط Retry
    CoordMode, Mouse, Screen
    Click, %RetryX%, %RetryY%
return

GuiClose:
    ExitApp
return