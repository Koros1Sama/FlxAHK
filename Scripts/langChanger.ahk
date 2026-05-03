; === Language Changer (Encoding-Independent) ===
; All Arabic characters are defined via Chr(0xHEX) codepoints
; so this script works regardless of file encoding (BOM, no-BOM, ANSI, etc.)

; --- تجميد مراقبي الحافظة مؤقتاً (Ditto, CopyQ, ClipboardFusion, etc.) ---
ClipMonitors := ["Ditto.exe", "CopyQ.exe", "ClipboardFusion.exe", "1Clipboard.exe", "ClipAngel.exe"]
hSuspended := {}
for i, proc in ClipMonitors {
    Process, Exist, %proc%
    if (ErrorLevel) {
        hProc := DllCall("OpenProcess", "UInt", 0x0800, "Int", 0, "UInt", ErrorLevel, "Ptr")
        if (hProc) {
            DllCall("ntdll\NtSuspendProcess", "Ptr", hProc)
            hSuspended[proc] := hProc
        }
    }
}

ClipSaved := ClipboardAll
Clipboard := ""
Send, ^c
Sleep, 100
SelectedText := Clipboard

if (SelectedText = "")
{
    ; إذا لم يكن هناك نص محدد، قم بتحديد النص حتى البداية
    Send, ^+{Home}
    Sleep, 50
    Clipboard := ""
    Send, ^c
    Sleep, 100
    SelectedText := Clipboard

    ; إذا ظل فارغاً، تراجع وأرجع Ditto
    if (SelectedText = "")
    {
        Clipboard := ClipSaved
        gosub, ResumeClipMonitors
        return
    }
}

; --- Build Arabic-to-English map ---
ArToEn := {}
ArToEn[Chr(0x0630)] := "``"   ; ذ
ArToEn[Chr(0x0636)] := "q"    ; ض
ArToEn[Chr(0x0635)] := "w"    ; ص
ArToEn[Chr(0x062B)] := "e"    ; ث
ArToEn[Chr(0x0642)] := "r"    ; ق
ArToEn[Chr(0x0641)] := "t"    ; ف
ArToEn[Chr(0x063A)] := "y"    ; غ
ArToEn[Chr(0x0639)] := "u"    ; ع
ArToEn[Chr(0x0647)] := "i"    ; ه
ArToEn[Chr(0x062E)] := "o"    ; خ
ArToEn[Chr(0x062D)] := "p"    ; ح
ArToEn[Chr(0x062C)] := "["    ; ج
ArToEn[Chr(0x062F)] := "]"    ; د
ArToEn[Chr(0x0634)] := "a"    ; ش
ArToEn[Chr(0x0633)] := "s"    ; س
ArToEn[Chr(0x064A)] := "d"    ; ي
ArToEn[Chr(0x0628)] := "f"    ; ب
ArToEn[Chr(0x0644)] := "g"    ; ل
ArToEn[Chr(0x0627)] := "h"    ; ا
ArToEn[Chr(0x062A)] := "j"    ; ت
ArToEn[Chr(0x0646)] := "k"    ; ن
ArToEn[Chr(0x0645)] := "l"    ; م
ArToEn[Chr(0x0643)] := ";"    ; ك
ArToEn[Chr(0x0637)] := "'"    ; ط
ArToEn[Chr(0x0626)] := "z"    ; ئ
ArToEn[Chr(0x0621)] := "x"    ; ء
ArToEn[Chr(0x0624)] := "c"    ; ؤ
ArToEn[Chr(0x0631)] := "v"    ; ر
ArToEn[Chr(0x0649)] := "n"    ; ى
ArToEn[Chr(0x0629)] := "m"    ; ة
ArToEn[Chr(0x0648)] := ","    ; و
ArToEn[Chr(0x0632)] := "."    ; ز
ArToEn[Chr(0x0638)] := "/"    ; ظ

; --- Build English-to-Arabic map ---
EnToAr := {}
EnToAr["``"] := Chr(0x0630)                  ; ذ
EnToAr["q"]  := Chr(0x0636)                  ; ض
EnToAr["w"]  := Chr(0x0635)                  ; ص
EnToAr["e"]  := Chr(0x062B)                  ; ث
EnToAr["r"]  := Chr(0x0642)                  ; ق
EnToAr["t"]  := Chr(0x0641)                  ; ف
EnToAr["y"]  := Chr(0x063A)                  ; غ
EnToAr["u"]  := Chr(0x0639)                  ; ع
EnToAr["i"]  := Chr(0x0647)                  ; ه
EnToAr["o"]  := Chr(0x062E)                  ; خ
EnToAr["p"]  := Chr(0x062D)                  ; ح
EnToAr["["]  := Chr(0x062C)                  ; ج
EnToAr["]"]  := Chr(0x062F)                  ; د
EnToAr["a"]  := Chr(0x0634)                  ; ش
EnToAr["s"]  := Chr(0x0633)                  ; س
EnToAr["d"]  := Chr(0x064A)                  ; ي
EnToAr["f"]  := Chr(0x0628)                  ; ب
EnToAr["g"]  := Chr(0x0644)                  ; ل
EnToAr["h"]  := Chr(0x0627)                  ; ا
EnToAr["j"]  := Chr(0x062A)                  ; ت
EnToAr["k"]  := Chr(0x0646)                  ; ن
EnToAr["l"]  := Chr(0x0645)                  ; م
EnToAr[";"]  := Chr(0x0643)                  ; ك
EnToAr["'"]  := Chr(0x0637)                  ; ط
EnToAr["z"]  := Chr(0x0626)                  ; ئ
EnToAr["x"]  := Chr(0x0621)                  ; ء
EnToAr["c"]  := Chr(0x0624)                  ; ؤ
EnToAr["v"]  := Chr(0x0631)                  ; ر
EnToAr["b"]  := Chr(0x0644) . Chr(0x0627)    ; لا
EnToAr["n"]  := Chr(0x0649)                  ; ى
EnToAr["m"]  := Chr(0x0629)                  ; ة
EnToAr[","]  := Chr(0x0648)                  ; و
EnToAr["."]  := Chr(0x0632)                  ; ز
EnToAr["/"]  := Chr(0x0638)                  ; ظ

; --- Detect language using Unicode range (no literal chars needed) ---
ArabicCount := 0
EnglishCount := 0
Loop, Parse, SelectedText
{
    code := Asc(A_LoopField)
    if (code >= 0x0600 && code <= 0x06FF)  ; Arabic Unicode block
        ArabicCount++
    else if (code >= 0x0041 && code <= 0x005A) || (code >= 0x0061 && code <= 0x007A)  ; A-Z, a-z
        EnglishCount++
}

IsArabic := (ArabicCount > EnglishCount)
NewText := ""
Loop, Parse, SelectedText
{
    Char := A_LoopField
    if (IsArabic)
    {
        NewChar := ArToEn[Char] ? ArToEn[Char] : Char
    }
    else
    {
        NewChar := EnToAr[Char] ? EnToAr[Char] : Char
    }
    NewText .= NewChar
}

; استرجاع الحافظة القديمة أولاً
Clipboard := ClipSaved
Sleep, 50

; إعادة تشغيل مراقبي الحافظة
gosub, ResumeClipMonitors

; كتابة النص مباشرة بدل استخدام اللصق عشان ما ينحفظ في الحافظة
SendInput, {Text}%NewText%
return

; --- Subroutine: إعادة تشغيل مراقبي الحافظة ---
ResumeClipMonitors:
for proc, hProc in hSuspended {
    DllCall("ntdll\NtResumeProcess", "Ptr", hProc)
    DllCall("CloseHandle", "Ptr", hProc)
}
hSuspended := {}
return