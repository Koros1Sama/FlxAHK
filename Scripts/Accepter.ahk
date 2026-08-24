#NoEnv
#SingleInstance Off
DetectHiddenWindows, On
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
SetTitleMatchMode, 2

; --- الكشف عن النسخة السابقة (شغله مرتين يطفي) ---
IfWinExist, MyUniqueStatus_ON_Accepter
{
    WinClose, MyUniqueStatus_ON_Accepter
    ExitApp
}

; --- Settings ---
DelayTime := 2000  ; 2 seconds
ClickX := 1475
ClickY := 921

; --- ON Indicator (مطابق لأسلوبك بالضبط) ---
Gui, +AlwaysOnTop -Caption +ToolWindow +Owner
Gui, Color, 00FF00
Gui, Font, s12 Bold, Segoe UI
Gui, Add, Text, cBlack Center, ON
Gui, Show, x0 y0 NoActivate, MyUniqueStatus_ON_Accepter

; --- Start loop ---
SetTimer, AccepterLoop, %DelayTime%
return

AccepterLoop:
    ; Make sure Antigravity is running (any window - Manager or widget_test)
    IfWinNotExist, ahk_exe Antigravity.exe
        return

    ; Check internet
    Connected := DllCall("Wininet.dll\InternetCheckConnection", "Str", "http://www.google.com", "UInt", 1, "UInt", 0)
    if (Connected)
    {
        ; Internet OK -> click point
        Gosub, ActivateAndClick
    }
return

; --- Helper: Activate the correct window under the button and click ---
; Uses the button coordinates to find which Antigravity window owns that area
ActivateAndClick:
    ; Find which window is at the button's position
    ; This correctly handles multiple windows from the same exe (Manager vs widget_test)
    MouseGetPos_hwnd := DllCall("WindowFromPoint", "Int64", ClickX | (ClickY << 32), "Ptr")
    if (MouseGetPos_hwnd)
    {
        ; Get the top-level parent window
        TopHwnd := DllCall("GetAncestor", "Ptr", MouseGetPos_hwnd, "UInt", 2, "Ptr")
        if (TopHwnd)
        {
            WinActivate, ahk_id %TopHwnd%
            Sleep, 200
            Click, %ClickX%, %ClickY%
            Sleep, 1500
            return
        }
    }
    ; Fallback: just click directly (button is already visible on screen)
    Click, %ClickX%, %ClickY%
    Sleep, 1500
return

GuiClose:
    ExitApp
return
