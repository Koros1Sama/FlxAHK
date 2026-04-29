#SingleInstance Force
SetWorkingDir %A_ScriptDir%

; مسار VLC
VLCPath := "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
HistoryFile := A_ScriptDir "\VlcHistory.ini"

; الحصول على المسار (ملف أو مجلد)
TargetPath := GetPathFromClipboard()
if (TargetPath = "" || !FileExist(TargetPath)) {
    TargetPath := GetActiveExplorerPath()
}
; التحقق إذا كان المسار هو سطح المكتب أو لم يتم تحديد شيء
if (TargetPath = "" || TargetPath = A_Desktop || TargetPath = A_DesktopCommon || InStr(TargetPath, "Desktop")) {
    IniRead, LastActiveFolder, %HistoryFile%, Global, LastActiveFolder, %A_Space%
    if (LastActiveFolder != "" && FileExist(LastActiveFolder)) {
        TargetPath := LastActiveFolder
    } else {
        MsgBox, لم يتم العثور على سجل لأنمي سابق لفتحه من سطح المكتب!
        ExitApp
    }
}

FolderPath := TargetPath
; تحديث آخر مجلد نشط بشكل عام
IniWrite, %FolderPath%, %HistoryFile%, Global, LastActiveFolder

; قراءة آخر ملف تم تشغيله (إن وجد) من الذاكرة
IniRead, LastPlayed, %HistoryFile%, Folders, %FolderPath%, %A_Space%

; جلب كل ملفات الفيديو في المجلد
FileList := ""
VideoExts := "mp4,mkv,avi,rmvb,flv,webm,wmv,mov"
Loop, Files, %FolderPath%\*.*, F
{
    if A_LoopFileExt in %VideoExts%
    {
        FileList .= A_LoopFileName "`n"
    }
}

; إذا لم توجد ملفات فيديو، نبحث عن مجلد فرعي وحيد (لحل مشكلة بعض الأنميات التي تأتي داخل مجلد إضافي)
if (FileList = "") {
    SubFolderCount := 0
    SingleSubFolder := ""
    Loop, Files, %FolderPath%\*.*, D
    {
        SubFolderCount++
        SingleSubFolder := A_LoopFilePath
    }
    
    if (SubFolderCount == 1) {
        FolderPath := SingleSubFolder
        IniWrite, %FolderPath%, %HistoryFile%, Global, LastActiveFolder
        IniRead, LastPlayed, %HistoryFile%, Folders, %FolderPath%, %A_Space%
        
        Loop, Files, %FolderPath%\*.*, F
        {
            if A_LoopFileExt in %VideoExts%
            {
                FileList .= A_LoopFileName "`n"
            }
        }
    }
}

if (FileList = "") {
    MsgBox, لا توجد ملفات فيديو مدعومة في هذا المجلد.
    ExitApp
}
FileList := Trim(FileList, "`n")

; الترتيب المنطقي للويندوز
Sort, FileList, F LogicalCmp

VideoFiles := []
Loop, Parse, FileList, `n
{
    if (A_LoopField != "")
        VideoFiles.Push(A_LoopField)
}

FileCount := VideoFiles.Count()

; إنشاء مصفوفة ثانية مرتبة حسب طول الاسم (من الأطول للأقصر) لتفادي تداخل الأسماء
VideoFilesByLength := []
for k, v in VideoFiles
    VideoFilesByLength.Push(v)

MaxIndex := VideoFilesByLength.Count()
Loop % MaxIndex {
    i := A_Index
    Loop % MaxIndex - i {
        j := A_Index
        if (StrLen(VideoFilesByLength[j]) < StrLen(VideoFilesByLength[j+1])) {
            temp := VideoFilesByLength[j]
            VideoFilesByLength[j] := VideoFilesByLength[j+1]
            VideoFilesByLength[j+1] := temp
        }
    }
}

; البحث عن رقم (Index) آخر حلقة
StartIndex := 1
for index, file in VideoFiles {
    if (file = LastPlayed) {
        StartIndex := index
        break
    }
}

; بناء قائمة الملفات لتمريرها عبر سطر الأوامر مباشرة (للحفاظ على خاصية استكمال التشغيل النيتف في VLC)
CommandLineArgs := ""

; كتابة الملفات ابتداءً من نقطة التوقف وحتى النهاية
Loop % FileCount - StartIndex + 1 {
    currentIndex := StartIndex + A_Index - 1
    fileName := VideoFiles[currentIndex]
    CommandLineArgs .= """" fileName """ "
}

; كتابة الملفات القديمة من البداية لتكتمل الدائرة
Loop % StartIndex - 1 {
    fileName := VideoFiles[A_Index]
    CommandLineArgs .= """" fileName """ "
}

; تشغيل VLC من داخل مجلد الحلقات لتقليل طول سطر الأوامر (لتجاوز حد ويندوز 8191 حرف)
; مع إجبار النافذة على عرض اسم الملف الصافي ($u) لتفادي الميتاداتا التالفة
Run, "%VLCPath%" --input-title-format="$u" %CommandLineArgs%, %FolderPath%

; الانتظار حتى تظهر نافذة VLC
WinWait, ahk_exe vlc.exe, , 10
if (ErrorLevel) {
    ExitApp
}

; حلقة المراقبة في الخلفية
Loop {
    if !WinExist("ahk_exe vlc.exe") {
        ExitApp
    }
    
    TitleFound := ""
    WinGet, idList, List, ahk_exe vlc.exe
    Loop % idList {
        this_id := idList%A_Index%
        WinGetTitle, this_title, ahk_id %this_id%
        if (this_title != "" && this_title != "VLC media player" && this_title != "مشغّل الوسائط VLC" && !InStr(this_title, "Direct3D")) {
            TitleFound := this_title
            break
        }
    }
    
    if (TitleFound != "") {
        TitleFound := StrReplace(TitleFound, "%20", " ") ; تحويل المسافات المشفرة إلى مسافات عادية
        
        for index, file in VideoFilesByLength {
            if InStr(TitleFound, file) {
                IniWrite, %file%, %HistoryFile%, Folders, %FolderPath%
                
                ; تنظيف السجل إذا تجاوز 50 مجلد (حذف أقدم مدخل من أعلى القائمة)
                IniRead, AllFolders, %HistoryFile%, Folders
                StrReplace(AllFolders, "`n", "`n", FolderCount)
                if (FolderCount >= 50) {
                    Loop, Parse, AllFolders, `n
                    {
                        if (A_Index == 1) {
                            StringSplit, KeyPair, A_LoopField, =
                            IniDelete, %HistoryFile%, Folders, %KeyPair1%
                            break
                        }
                    }
                }
                
                break
            }
        }
    }
    
    Sleep, 3000
}
ExitApp

LogicalCmp(a, b, offset) {
    return DllCall("shlwapi.dll\StrCmpLogicalW", "WStr", a, "WStr", b, "Int")
}

GetPathFromClipboard() {
    ; دعم سطح المكتب ومستكشف الملفات
    if (WinActive("ahk_class CabinetWClass") || WinActive("ahk_class ExplorerWClass") || WinActive("ahk_class Progman") || WinActive("ahk_class WorkerW")) {
        ClipboardOld := ClipboardAll
        Clipboard := ""
        Send {Ctrl down}
        Sleep 50
        Send {c down}
        Sleep 50
        Send {c up}
        Send {Ctrl up}
        ClipWait, 1
        if (!ErrorLevel && FileExist(Clipboard)) {
            SelectedPath := ""
            Loop, Parse, Clipboard, `n, `r
            {
                SelectedPath := A_LoopField
                break ; نأخذ أول ملف فقط إذا كان هناك عدة ملفات محددة
            }
            Clipboard := ClipboardOld
            
            ; التحقق مما إذا كان المسار المحدد مجلداً وليس ملفاً
            FileGetAttrib, attrib, %SelectedPath%
            if InStr(attrib, "D") {
                return SelectedPath
            } else {
                return "" ; تجاهل الملفات والعودة بمسار فارغ ليعتمد على مستكشف الملفات المفتوح
            }
        }
        Clipboard := ClipboardOld
    }
    return ""
}

GetActiveExplorerPath() {
    WinGet, activeWin, ID, A
    for window in ComObjCreate("Shell.Application").Windows {
        if (window.HWND = activeWin) {
            return window.Document.Folder.Self.Path
        }
    }
    return ""
}
