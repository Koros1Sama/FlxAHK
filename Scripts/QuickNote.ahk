#SingleInstance Force
; QuickNote.ahk — نوتة سريعة (Flx + NumpadAdd)
; يطلب عنوانًا ثم ينشئ ملفًا اسمه: التاريخ_الساعة-بالثانية - العنوان.txt
; بمسار محدد أدناه (غيّره كما تشاء) ويفتحه بالمفكرة فورًا.

NotesDir := A_ScriptDir "\..\Notes"   ; ← المسار المعين (افتراضيًا: مجلد Notes بجوار مجلد Scripts)

if !FileExist(NotesDir)
    FileCreateDir, %NotesDir%

InputBox, noteTitle, نوتة سريعة, العنوان:, , 380, 140
if (ErrorLevel)
    ExitApp

FormatTime, d,, yyyy-MM-dd
FormatTime, t,, HH-mm-ss
FormatTime, full,, yyyy/MM/dd  HH:mm:ss

safeTitle := SanitizeFilename(noteTitle != "" ? noteTitle : "بدون عنوان")
notePath := NotesDir "\" d "_" t " - " safeTitle ".txt"

f := FileOpen(notePath, "w", "UTF-8")
f.WriteLine(noteTitle != "" ? noteTitle : "بدون عنوان")
f.WriteLine("════════════════════════")
f.WriteLine(full)
f.WriteLine("")
f.Close()

Run, notepad.exe "%notePath%"
ExitApp

SanitizeFilename(s) {
    out := ""
    Loop, Parse, s
    {
        c := A_LoopField
        if (c = "\" || c = "/" || c = ":" || c = "*" || c = "?" || c = """" || c = "<" || c = ">" || c = "|")
            c := "-"
        out .= c
    }
    out := Trim(out, " .")
    if (out = "")
        out := "نوتة"
    return out
}
