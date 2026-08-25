#SingleInstance Force
; ClipSlot.ahk — حافظة متعددة الخانات (Flx + Numpad1/3/4/6)
;   Flx + Numpad رقم      = حفظ الحافظة الحالية في الخانة
;   Flx + Shift + Numpad  = لصق محتوى الخانة (يفضي الحافظة ثم يرسل Ctrl+V)
; المحرك يمرر المفتاح المضغوط كوسيطة أولى (مثل: Numpad1 أو +Numpad1)

key := (A_Args.Length() >= 1) ? A_Args[1] : ""
if (Trim(key) = "") {
    ExitApp
}

slot := ""
RegExMatch(key, "(\d+)$", sm)
slot := sm1
if (slot = "")
    ExitApp

isPaste := (SubStr(key, 1, 1) = "+")
slotDir := A_Temp "\FlxClipSlots"
if !FileExist(slotDir)
    FileCreateDir, %slotDir%
slotFile := slotDir "\slot" slot ".txt"

if (!isPaste) {
    ; ----- حفظ -----
    txt := A_Clipboard
    if (Trim(txt) = "") {
        ToolTip, الحافظة فاضية — لا شيء يُحفظ في خانة %slot%
        SetTimer, _ClipTipOff, -1400
        Sleep, 1450
        ExitApp
    }
    f := FileOpen(slotFile, "w", "UTF-8")
    f.Write(txt)
    f.Close()
    preview := SubStr(RegExReplace(txt, "`r`n", " "), 1, 42)
    ToolTip, ✓ خانة %slot% حفظت:  %preview%
    SetTimer, _ClipTipOff, -1400
    Sleep, 1450
} else {
    ; ----- لصق -----
    if !FileExist(slotFile) {
        ToolTip, خانة %slot% فاضية
        SetTimer, _ClipTipOff, -1400
        Sleep, 1450
        ExitApp
    }
    f := FileOpen(slotFile, "r", "UTF-8")
    txt := f.Read()
    f.Close()
    if (Trim(txt) = "") {
        ToolTip, خانة %slot% فاضية
        SetTimer, _ClipTipOff, -1400
        Sleep, 1450
        ExitApp
    }
    A_Clipboard := txt
    setOnly := (A_Args.Length() >= 2 && A_Args[2] = "--set-only")  ; للاختبار الآلي فقط
    if (!setOnly) {
        Sleep, 130
        Send, ^v
    }
}
ExitApp

_ClipTipOff:
    ToolTip
return
