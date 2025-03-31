#SingleInstance Force
SetWorkingDir %A_ScriptDir%

; مسار VLC
VLCPath := "C:\Program Files\VideoLAN\VLC\vlc.exe"

; التحقق أولاً من المجلد المحدد عبر الحافظة
FolderPath := GetFolderFromClipboard()
if (FolderPath = "" || !FileExist(FolderPath)) {
    ; إذا لم يكن هناك مجلد محدد أو المسار غير صالح، استخدام طريقة المستكشف
    FolderPath := GetActiveExplorerPath()
    if (FolderPath = "") {
        MsgBox, لم يتم العثور على مجلد مفتوح أو محدد!
        ExitApp
    }
}

; تشغيل VLC مباشرة بدون واجهة
Run, "%VLCPath%" "--playlist-autostart" "--loop" "%FolderPath%"
ExitApp

; دالة لاستخراج المسار من الحافظة
GetFolderFromClipboard() {
    if (WinActive("ahk_class CabinetWClass") || WinActive("ahk_class ExplorerWClass")) {
        ClipboardOld := ClipboardAll  ; حفظ الحافظة الحالية
        Clipboard := ""  ; تفريغ الحافظة
        Send {Ctrl down}
        Sleep 50
        Send {c down}
        Sleep 50
        Send {c up}
        Send {Ctrl up}
        ClipWait, 1  ; الانتظار لمدة ثانية واحدة
        if (!ErrorLevel && FileExist(Clipboard)) {
            FolderPath := Trim(Clipboard, "`n`r")
            Clipboard := ClipboardOld  ; استعادة الحافظة
            return FolderPath
        }
        Clipboard := ClipboardOld  ; استعادة الحافظة إذا فشل
    }
    return ""  ; إرجاع فارغ إذا لم ينجح
}

; دالة لاستخراج المسار من مستكشف الملفات
GetActiveExplorerPath() {
    WinGet, activeWin, ID, A
    for window in ComObjCreate("Shell.Application").Windows {
        if (window.HWND = activeWin) {
            return window.Document.Folder.Self.Path
        }
    }
    return ""
}