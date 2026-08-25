#SingleInstance Force
; Translate.ahk — ترجمة فورية للنص المحدد (Flx + Ctrl+T)
; بدون متصفح: نافذة منبثقة تعرض الترجمة. النقرة = نسخ · Esc = إغلاق.
; ثنائي الاتجاه تلقائيًا (نص عربي → إنجليزي، وإلا → عربي).
; الأساسي MyMemory، والاحتياطي نقطة جوجل العامة (gtx).

text := GrabSelection()
if (Trim(text) = "") {
    Tip("لا يوجد نص محدد أو في الحافظة", 1300)
    ExitApp
}

isAr := HasArabic(text)
target := isAr ? "en" : "ar"
subTitle := isAr ? "عربي ← English" : "← عربي"

trans := TranslateClients5(text, target)
if (trans = "")
    trans := TranslateMyMemory(text, target)
if (trans = "")
    trans := TranslateGtx(text, target)
if (trans = "") {
    Tip("تعذر الاتصال بخدمات الترجمة", 1600)
    ExitApp
}

global gTransText
gTransText := trans
ShowPopup(trans, subTitle)
ExitApp

; ---------------------------------------------------------------- دوال

Tip(msg, ms) {
    ToolTip, %msg%
    SetTimer, _OffTip, % -ms
    Sleep, % ms + 60
_OffTip:
    ToolTip
return
}

GrabSelection() {
    saved := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 0.35
    sel := Clipboard
    Clipboard := saved
    ClipWait, 0.05, 1
    if (Trim(sel) != "")
        return sel
    return Clipboard
}

HasArabic(s) {
    Loop, Parse, s
    {
        c := Asc(A_LoopField)
        if (c >= 0x0600 && c <= 0x06FF) or (c >= 0x0750 && c <= 0x077F)
            return true
    }
    return false
}

UriEncode(str) {
    ; مرمّز UTF-8 حسابي نقي (StrPut مع مؤشر غير موثوق على بعض الأنظمة)
    out := ""
    Loop, Parse, str
    {
        c := Asc(A_LoopField)
        if (c < 0x80) {
            keep := (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c = 0x2D || c = 0x2E || c = 0x5F || c = 0x7E
            out .= keep ? Chr(c) : Format("%{:02X}", c)
        } else if (c < 0x800) {
            out .= Format("%{:02X}%{:02X}", 0xC0 | (c >> 6), 0x80 | (c & 0x3F))
        } else if (c < 0x10000) {
            out .= Format("%{:02X}%{:02X}%{:02X}", 0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
        } else {
            out .= Format("%{:02X}%{:02X}%{:02X}%{:02X}", 0xF0 | (c >> 18), 0x80 | ((c >> 12) & 0x3F), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
        }
    }
    return out
}

TranslateClients5(text, target) {
    ; نقطة قاموس كروم — استجابة مباشرة [[ترجمة, لغة]]
    url := "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=" . target . "&q=" . UriEncode(text)
    resp := HttpGet(url)
    if (resp = "")
        return ""
    if RegExMatch(resp, "\[""((?:[^""\]|\.)*)""", m)
        return JsonUnescape(m1)
    return ""
}

JsonUnescape(s) {
    s := StrReplace(s, "\", Chr(1))
    s := StrReplace(s, """", """""")
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\t", "`t")
    return StrReplace(s, Chr(1), "\")
}

HttpGet(url) {
    ; ServerXMLHTTP يدعم المهل، وXMLHTTP بديل، وWinHttp غير مسجل على بعض الأنظمة
    try {
        whr := ComObjCreate("MSXML2.ServerXMLHTTP.6.0")
        whr.SetTimeouts(4000, 4000, 4000, 9000)
        whr.Open("GET", url, false)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) FlxAHK")
        whr.Send()
        if (whr.Status != 200)
            return ""
        return whr.ResponseText
    } catch {
        try {
            whr := ComObjCreate("MSXML2.XMLHTTP")
            whr.Open("GET", url, false)
            whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) FlxAHK")
            whr.Send()
            if (whr.Status != 200)
                return ""
            return whr.ResponseText
        } catch {
            return ""
        }
    }
}

TranslateMyMemory(text, target) {
    url := "https://api.mymemory.translated.net/get?q=" . UriEncode(text) . "&langpair=Autodetect%7C" . target
    resp := HttpGet(url)
    if (resp = "")
        return ""
    if RegExMatch(resp, """translatedText""\s*:\s*""((?:[^""\\]|\\.)*)""", m)
        && !InStr(m1, "MYMEMORY WARNING")
        return JsonUnescape(m1)
    return ""
}

TranslateGtx(text, target) {
    url := "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" . target . "&dt=t&q=" . UriEncode(text)
    resp := HttpGet(url)
    if (resp = "")
        return ""
    trans := ""
    pos := 1
    while (pos := RegExMatch(resp, "\[""((?:[^""\\]|\\.)*)"",""", m, pos)) {
        trans .= JsonUnescape(m1)
        pos += StrLen(m)
    }
    return Trim(trans)
}

ShowPopup(trans, subTitle) {
    global gTransText, TransHwnd
    Gui, TransGui:Destroy
    Gui, TransGui:+AlwaysOnTop -Caption +ToolWindow +Border +HWNDTransHwnd
    Gui, TransGui:Color, 1E1E1E
    Gui, TransGui:Font, c909090 s8, Segoe UI
    Gui, TransGui:Add, Text, x12 y7 w436, %subTitle%  ·  نقرة = نسخ · Esc = إغلاق
    Gui, TransGui:Font, cFFFFFF s11, Segoe UI
    estH := 34 + Ceil(StrLen(trans) / 42.0) * 24
    estH := estH < 60 ? 60 : (estH > 420 ? 420 : estH)
    Gui, TransGui:Add, Text, x12 y28 w436 h%estH% gTransGuiCopy, %trans%
    MouseGetPos, mx, my
    x := mx - 230
    x := x < 8 ? 8 : (x + 460 > A_ScreenWidth ? A_ScreenWidth - 460 : x)
    y := my + 18
    y := y + estH + 40 > A_ScreenHeight ? (my - estH - 46 < 8 ? 8 : my - estH - 46) : y
    totalH := estH + 40
    Gui, TransGui:Show, x%x% y%y% w460 h%totalH%, ترجمة Flx
    WinActivate, ahk_id %TransHwnd%
    Hotkey, IfWinActive, ahk_id %TransHwnd%
    Hotkey, Esc, TransGuiClose, On
    Hotkey, IfWinActive
    ms := 4500 + StrLen(trans) * 30
    ms := ms > 15000 ? 15000 : ms
    SetTimer, TransGuiClose, % -ms
    Loop {
        Sleep, 100
        if !WinExist("ahk_id " TransHwnd)
            break
    }
    ExitApp
}

TransGuiClose:
    SetTimer, TransGuiClose, Off
    Hotkey, IfWinActive, ahk_id %TransHwnd%
    Hotkey, Esc, TransGuiClose, Off
    Hotkey, IfWinActive
    Gui, TransGui:Destroy
return

TransGuiCopy:
    Clipboard := gTransText
    ToolTip, ✓ نُسخت الترجمة
    SetTimer, _OffTip2, -900
return

_OffTip2:
    ToolTip
return
