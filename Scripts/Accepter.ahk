#NoEnv
#SingleInstance Off
DetectHiddenWindows, On
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
SetTitleMatchMode, 2

; --- الكشف عن النسخة السابقة (شغله مرتين يطفي) ---
IfWinExist, MyUniqueStatus_ON_Indicator
{
    WinClose, MyUniqueStatus_ON_Indicator
    ExitApp
}

; --- Settings ---
DelayTime := 5000  ; 5 seconds
Variation := 100   ; The confirmed working variation

; Image paths
RetryImage := A_ScriptDir . "\Retry.png"
AllowImage := A_ScriptDir . "\Allow.png"
RunImage := A_ScriptDir . "\Run.png"
AcceptAltImage := A_ScriptDir . "\AcceptAlt.png"

; Search area (bottom-right corner)
SearchX1 := 1500
SearchY1 := 700
SearchX2 := A_ScreenWidth
SearchY2 := A_ScreenHeight

; --- ON Indicator (مطابق لأسلوبك بالضبط) ---
Gui, +AlwaysOnTop -Caption +ToolWindow +Owner
Gui, Color, 00FF00
Gui, Font, s12 Bold, Segoe UI
Gui, Add, Text, cBlack Center, ON
Gui, Show, x0 y0 NoActivate, MyUniqueStatus_ON_Indicator

; --- Start loop ---
SetTimer, AccepterLoop, %DelayTime%
return

AccepterLoop:
    ; Make sure Antigravity is running
    IfWinNotExist, ahk_exe Antigravity.exe
        return

    ; 1. Check for Allow button
    if (FileExist(AllowImage))
    {
        ImageSearch, Ax, Ay, %SearchX1%, %SearchY1%, %SearchX2%, %SearchY2%, *%Variation% %AllowImage%
        if (!ErrorLevel)
        {
            ClickX := Ax + 10
            ClickY := Ay + 10
            WinActivate, ahk_exe Antigravity.exe
            Sleep, 200
            Click, %ClickX%, %ClickY%
            Sleep, 1500
        }
    }

    ; 1.5. Check for Accept Alt button
    if (FileExist(AcceptAltImage))
    {
        ; Search the entire screen just in case
        ImageSearch, AxAlt, AyAlt, 0, 0, A_ScreenWidth, A_ScreenHeight, *%Variation% %AcceptAltImage%
        if (!ErrorLevel)
        {
            ClickX := AxAlt + 10
            ClickY := AyAlt + 10
            WinActivate, ahk_exe Antigravity.exe
            Sleep, 200
            Click, %ClickX%, %ClickY%
            Sleep, 1500
        }
    }

    ; 2. Check for Run button
    if (FileExist(RunImage))
    {
        ; Search the entire screen for the Run button just in case it's located at the top right
        ImageSearch, Rx, Ry, 0, 0, A_ScreenWidth, A_ScreenHeight, *%Variation% %RunImage%
        if (!ErrorLevel)
        {
            ClickX := Rx + 10
            ClickY := Ry + 10
            WinActivate, ahk_exe Antigravity.exe
            Sleep, 200
            Click, %ClickX%, %ClickY%
            Sleep, 1500
        }
    }

    ; 3. Check for Retry button
    if (FileExist(RetryImage))
    {
        ImageSearch, Rtx, Rty, %SearchX1%, %SearchY1%, %SearchX2%, %SearchY2%, *%Variation% %RetryImage%
        if (!ErrorLevel)
        {
            ; Found Retry -> check internet
            Connected := DllCall("Wininet.dll\InternetCheckConnection", "Str", "http://www.google.com", "UInt", 1, "UInt", 0)
            if (Connected)
            {
                ; Internet OK -> click Retry
                ClickX := Rtx + 10
                ClickY := Rty + 10
                WinActivate, ahk_exe Antigravity.exe
                Sleep, 200
                Click, %ClickX%, %ClickY%
                Sleep, 1500
            }
        }
    }
return

GuiClose:
    ExitApp
return
