#SingleInstance Force  ; للتأكد من أن نسخة واحدة فقط تعمل

; 1. الحصول على النص إما من التحديد الحالي أو من الحافظة
RawText := GetTargetText()

if (RawText = "")
{
    Gosub, ShowWarning
    ExitApp
}

; 2. تنظيف ومعالجة المسار
CleanPath := NormalizePath(RawText)

; 3. محاولة تشغيل المسار أو الرابط
if (ExecutePath(CleanPath))
{
    ExitApp
}
else
{
    Gosub, ShowWarning
}
ExitApp

; =========================================================================
; دوال المعالجة الذكية للمسارات
; =========================================================================

GetTargetText() {
    ; فحص ما إذا كان المستخدم يحدد نصاً حالياً على الشاشة
    ClipSaved := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 0.08
    SelectedText := Clipboard
    Clipboard := ClipSaved
    
    if (Trim(SelectedText) != "")
        return SelectedText
        
    ; إذا لم يكن هناك نص محدد، نأخذ ما هو موجود في الحافظة
    return Clipboard
}

NormalizePath(str) {
    ; أخذ أول سطر فقط وتجاوز الأسطر الفارغة
    Loop, Parse, str, `n, `r
    {
        line := Trim(A_LoopField)
        if (line != "") {
            str := line
            break
        }
    }
    
    str := Trim(str, " `t`r`n")
    
    ; استخراج المسار إذا كان داخل رابط Markdown مثل [Title](path_or_url)
    if RegExMatch(str, "\[.*?\]\((.*?)\)", match)
        str := match1
        
    ; إزالة علامات الاقتباس والأقواس المحيطة
    str := Trim(str, " `t`r`n`"`'`<`>`[`]`(`)`{`}`~`*``")
    
    ; فك تشفير روابط file:/// و URLs
    if (InStr(str, "file://") = 1 || InStr(str, "file:///") = 1) {
        str := RegExReplace(str, "^file://+", "")
        str := UrlDecode(str)
    }
    
    ; فحص روابط الويب العادية
    if RegExMatch(str, "i)^(https?://|ftp://|mailto:)")
        return str
    if RegExMatch(str, "i)^www\.")
        return "https://" . str
    if RegExMatch(str, "i)^(localhost|127\.0\.0\.1)(:\d+)?(/.*)?$")
        return "http://" . str
        
    ; فحص أوامر ويندوز الخاصة (shell:...)
    if RegExMatch(str, "i)^shell:")
        return str
        
    ; معالجة مسارات WSL مثل /mnt/c/...
    if RegExMatch(str, "i)^/mnt/([a-zA-Z])/(.*)", wslMatch)
        str := wslMatch1 . ":\" . StrReplace(wslMatch2, "/", "\")
        
    ; معالجة اختصار مجلد المستخدم الرئيسي (~)
    if (SubStr(str, 1, 2) = "~/" || SubStr(str, 1, 2) = "~\") {
        EnvGet, userProf, USERPROFILE
        str := userProf . "\" . SubStr(str, 3)
    }
    
    ; إزالة أرقام الأسطر وإشارات Git/VSCode الملحقة في نهاية المسار
    ; مثل: file.ahk:45 أو file.ahk:45:10 أو file.ahk#L45 أو file.ahk(45)
    str := RegExReplace(str, "#L\d+.*$", "")
    str := RegExReplace(str, "(?<!^[a-zA-Z]):\d+(:\d+)?$", "")
    str := RegExReplace(str, "\(\d+(,\d+)?\)$", "")
    str := RegExReplace(str, ", line \d+.*$", "")
    
    ; استبدال السلاشات العادية إلى باك سلاش للمسارات المحلية
    if RegExMatch(str, "^[a-zA-Z]:[/\\].*") || InStr(str, "\\") || InStr(str, "\") || InStr(str, "/") {
        str := StrReplace(str, "/", "\")
    }
    
    ; توسيع متغيرات البيئة مثل %APPDATA% و %USERPROFILE% و %TEMP%
    if (InStr(str, "%")) {
        VarSetCapacity(expanded, 4096)
        DllCall("ExpandEnvironmentStrings", "Str", str, "Str", expanded, "UInt", 2048)
        if (expanded != "")
            str := expanded
    }
    
    ; معالجة رمز القرص المجرد (C: -> C:\)
    if RegExMatch(str, "^[a-zA-Z]:$")
        str .= "\"
        
    return Trim(str)
}

UrlDecode(url) {
    try {
        doc := ComObjCreate("HTMLFile")
        doc.write("<!DOCTYPE html><html><body></body></html>")
        return doc.parentWindow.decodeURIComponent(url)
    } catch {
        VarSetCapacity(out, StrLen(url) * 4 + 2, 0)
        len := StrLen(url) * 2
        DllCall("shlwapi.dll\UrlUnescapeW", "WStr", url, "WStr", out, "UIntP", len, "UInt", 0)
        return out ? out : url
    }
}

ExecutePath(path) {
    if (path = "")
        return false
        
    ; فحص روابط الويب واختصارات shell
    if RegExMatch(path, "i)^(https?://|ftp://|shell:|mailto:)")
    {
        try {
            Run, %path%
            return true
        } catch {
            return false
        }
    }
    
    ; فحص المسارات المحلية (ملفات أو مجلدات)
    if FileExist(path)
    {
        try {
            Run, "%path%"
            return true
        } catch {
            Run, %path%
            return true
        }
    }
    
    ; إذا كان المسار لملف غير موجود ولكن المجلد الأب موجود
    SplitPath, path,, parentDir
    if (parentDir != "" && FileExist(parentDir))
    {
        try {
            Run, "%parentDir%"
            return true
        }
    }
    
    ; فحص البرامج والأوامر العامة المدمجة في الويندوز
    knownCommands := ["notepad", "calc", "cmd", "powershell", "regedit", "taskmgr", "explorer", "control", "ms-settings:"]
    for i, cmd in knownCommands {
        if (path = cmd || InStr(path, cmd . " ") = 1) {
            try {
                Run, %path%
                return true
            }
        }
    }
    
    return false
}

; =========================================================================
; شريط التحذير في حال كان المسار غير صالح
; =========================================================================
ShowWarning:
    BarHeight := 10
    BarWidth := A_ScreenWidth
    FlashColor := "FF0000"
    StartY := A_ScreenHeight - BarHeight
    StartX := (A_ScreenWidth - BarWidth) // 2

    Gui, WarningBar:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, WarningBar:Color, %FlashColor%
    Gui, WarningBar:Show, x%StartX% y%StartY% w%BarWidth% h%BarHeight% NoActivate

    Loop, 15
    {
        Alpha := A_Index * 17
        WinSet, Transparent, %Alpha%, ahk_class AutoHotkeyGUI
        Sleep, 2
    }

    Sleep, 50

    Loop, 15
    {
        Alpha := 255 - (A_Index * 17)
        WinSet, Transparent, %Alpha%, ahk_class AutoHotkeyGUI
        Sleep, 2
    }

    Gui, WarningBar:Destroy
return