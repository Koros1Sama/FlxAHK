ClipSaved := ClipboardAll
Clipboard := ""
Send, ^c
Sleep, 100
SelectedText := Clipboard
if (SelectedText = "")
{
    Clipboard := ClipSaved
    return
}
ArToEn := { "ذ": "``", "ض": "q", "ص": "w", "ث": "e", "ق": "r", "ف": "t", "غ": "y", "ع": "u", "ه": "i", "خ": "o"
, "ح": "p", "ج": "[", "د": "]", "ش": "a", "س": "s", "ي": "d", "ب": "f", "ل": "g", "ا": "h", "ت": "j"
, "ن": "k", "م": "l", "ك": ";", "ط": "'", "ئ": "z", "ء": "x", "ؤ": "c", "ر": "v", "لا": "b"
, "ى": "n", "ة": "m", "و": ",", "ز": ".", "ظ": "/" }
EnToAr := { "``": "ذ", "q": "ض", "w": "ص", "e": "ث", "r": "ق", "t": "ف", "y": "غ", "u": "ع", "i": "ه", "o": "خ"
, "p": "ح", "[": "ج", "]": "د", "a": "ش", "s": "س", "d": "ي", "f": "ب", "g": "ل", "h": "ا", "j": "ت"
, "k": "ن", "l": "م", ";": "ك", "'": "ط", "z": "ئ", "x": "ء", "c": "ؤ", "v": "ر", "b": "لا"
, "n": "ى", "m": "ة", ",": "و", ".": "ز", "/": "ظ" }
ArabicCount := 0
EnglishCount := 0
Loop, Parse, SelectedText
{
    if RegExMatch(A_LoopField, "[اأإبتثجحخدذرزسشصضطظعغفقكلمنهويةىئؤلا]")
        ArabicCount++
    else if RegExMatch(A_LoopField, "[a-zA-Z]")
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
Clipboard := NewText
Send, ^v
Sleep, 100
Clipboard := ClipSaved
return