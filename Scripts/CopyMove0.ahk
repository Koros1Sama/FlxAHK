#SingleInstance Force

Clipboard := ""
Send {Ctrl down}
Sleep 100
Send {c down}
Sleep 100
Send {c up}
Send {Ctrl up}
ClipWait, 2
if (ErrorLevel) {
    return
}

; Global variables
global ApplyToAll := 0
global ChosenAction := ""
global ChosenOperation := ""
global CancelCopy := 0
global TotalBytes := 0
global ProcessedBytes := 0

; Split clipboard content into multiple items
ItemsToCopy := StrSplit(Clipboard, "`n", "`r")

; Calculate total size of files
Loop, % ItemsToCopy.Length()
{
    Item := Trim(ItemsToCopy[A_Index])
    IfExist, %Item%
    {
        SplitPath, Item,,, ItemExt
        if (ItemExt != "") {  ; File
            FileGetSize, FileSize, %Item%
            TotalBytes += FileSize
        }
        else {  ; Folder
            Loop, Files, %Item%\*.*, R
            {
                FileGetSize, FileSize, %A_LoopFileFullPath%
                TotalBytes += FileSize
            }
        }
    }
}

; Show initial operation selection dialog
Gui, Operation:New, +AlwaysOnTop, اختر العملية
Gui, Add, Text,, اختر العملية المطلوبة:
Gui, Add, Button, x10 y50 w80 h30 gCopyOperation, نسخ
Gui, Add, Button, x100 y50 w80 h30 gMoveOperation, نقل
Gui, Add, Button, x190 y50 w80 h30 gShortcutOperation, إنشاء اختصار
Gui, Show, w300 h100
WinWaitClose, اختر العملية

if (ChosenOperation = "")
    ExitApp

; Progress bar
Progress, B W100 H10 X0 Y0 Range0-%TotalBytes%
Progress, 0

; Process each item
Loop, % ItemsToCopy.Length()
{
    ItemToCopy := Trim(ItemsToCopy[A_Index])
    
    IfExist, %ItemToCopy%
    {
        SplitPath, ItemToCopy, ItemName,, ItemExt
        
        if (ItemExt != "") {  ; File
            TargetFile := "F:\Anime\" . ItemName
            IfNotExist, F:\Anime\
                FileCreateDir, F:\Anime\
            
            IfExist, %TargetFile%
            {
                if (ApplyToAll && ChosenAction != "") {
                    if (ChosenAction = "Replace")
                        Gosub, ReplaceAction
                    else if (ChosenAction = "Rename")
                        Gosub, RenameAction
                    else if (ChosenAction = "Cancel")
                        Gosub, SkipAction
                }
                else {
                    ShowDuplicateDialog(ItemName, "ملف")
                }
            }
            else
                ProcessItem(ItemToCopy, TargetFile)
        }
        else {  ; Folder
            TargetFolder := "F:\Anime\" . ItemName
            IfNotExist, F:\Anime\
                FileCreateDir, F:\Anime\
            
            IfExist, %TargetFolder%
            {
                if (ApplyToAll && ChosenAction != "") {
                    if (ChosenAction = "Replace")
                        Gosub, ReplaceAction
                    else if (ChosenAction = "Rename")
                        Gosub, RenameAction
                    else if (ChosenAction = "Cancel")
                        Gosub, SkipAction
                }
                else {
                    ShowDuplicateDialog(ItemName, "مجلد")
                }
            }
            else
                ProcessItem(ItemToCopy, TargetFolder)
        }
    }
    if (CancelCopy)
        break
}

DllCall("shell32\SHChangeNotify", "UInt", 0x08000000, "UInt", 0, "Ptr", 0, "Ptr", 0)
Progress, Off
ExitApp

CopyOperation:
ChosenOperation := "Copy"
Gui, Operation:Destroy
return

MoveOperation:
ChosenOperation := "Move"
Gui, Operation:Destroy
return

ShortcutOperation:
ChosenOperation := "Shortcut"
Gui, Operation:Destroy
return

SkipAction:
if (ItemExt != "") {
    FileGetSize, FileSize, %ItemToCopy%
    ProcessedBytes += FileSize
} else {
    Loop, Files, %ItemToCopy%\*.*, R
        FileGetSize, FileSize, %A_LoopFileFullPath%
        ProcessedBytes += FileSize
}
Progress, %ProcessedBytes%
Sleep, 10
return

CancelAction:
Gui, Duplicate:Submit
if (ApplyToAll)
    ChosenAction := "Cancel"
Gui, Duplicate:Destroy
return

CancelAllAction:
global CancelCopy := 1
Gui, Duplicate:Destroy
return

ReplaceAction:
Gui, Duplicate:Submit
if (ApplyToAll)
    ChosenAction := "Replace"
Gui, Duplicate:Destroy
if (ItemExt != "") {
    FileDelete, %TargetFile%
    ProcessItem(ItemToCopy, TargetFile)
} else {
    FileRemoveDir, %TargetFolder%, 1
    if (!ErrorLevel)
        ProcessItem(ItemToCopy, TargetFolder)
}
return

RenameAction:
Gui, Duplicate:Submit
if (ApplyToAll)
    ChosenAction := "Rename"
Gui, Duplicate:Destroy
Loop
{
    NewName := ItemName . " (" . A_Index . ")"
    if (ItemExt != "")
        NewTarget := "F:\Anime\" . NewName . "." . ItemExt
    else
        NewTarget := "F:\Anime\" . NewName
    
    IfNotExist, %NewTarget%
        break
}
ProcessItem(ItemToCopy, NewTarget)
return

ProcessItem(Source, Dest) {
    global ChosenOperation, ProcessedBytes
    if (ChosenOperation = "Copy") {
        if (ItemExt != "")
            CopyFileWithProgress(Source, Dest)
        else
            CopyFolderWithProgress(Source, Dest)
    }
    else if (ChosenOperation = "Move") {
        if (ItemExt != "")
            FileMove, %Source%, %Dest%, 1
        else
            FileMoveDir, %Source%, %Dest%, 1
        FileGetSize, FileSize, %Source%
        ProcessedBytes += FileSize
        Progress, %ProcessedBytes%
        Sleep, 10
    }
    else if (ChosenOperation = "Shortcut") {
        if (ItemExt != "")
            FileCreateShortcut, %Source%, %Dest%.lnk
        else
            FileCreateShortcut, %Source%, %Dest%.lnk
        ProcessedBytes += 100  ; Arbitrary size for shortcuts
        Progress, %ProcessedBytes%
        Sleep, 10
    }
}

CopyFileWithProgress(Source, Dest) {
    global CancelCopy, ProcessedBytes
    FileGetSize, FileSize, %Source%
    FileCopy, %Source%, %Dest%, 1
    if (CancelCopy) {
        FileDelete, %Dest%
    } else {
        ProcessedBytes += FileSize
        Progress, %ProcessedBytes%
        Sleep, 10
    }
}

CopyFolderWithProgress(Source, Dest) {
    global CancelCopy, ProcessedBytes
    FileCreateDir, %Dest%
    Loop, Files, %Source%\*.*, R
    {
        if (CancelCopy) {
            FileRemoveDir, %Dest%, 1
            return
        }
        RelPath := SubStr(A_LoopFileFullPath, StrLen(Source) + 2)
        TargetPath := Dest . "\" . RelPath
        SplitPath, TargetPath,, TargetDir
        IfNotExist, %TargetDir%
            FileCreateDir, %TargetDir%
        FileGetSize, FileSize, %A_LoopFileFullPath%
        FileCopy, %A_LoopFileFullPath%, %TargetPath%, 1
        ProcessedBytes += FileSize
        Progress, %ProcessedBytes%
        Sleep, 10
    }
}

ShowDuplicateDialog(ItemName, ItemType) {
    Gui, Duplicate:New, +AlwaysOnTop, %ItemType% موجود
    Gui, Add, Text,, ال%ItemType% %ItemName% موجود بالفعل في F:\Anime
    Gui, Add, Button, x10 y50 w70 h30 gReplaceAction, استبدال
    Gui, Add, Button, x85 y50 w70 h30 gRenameAction, إعادة تسمية
    Gui, Add, Button, x160 y50 w70 h30 gCancelAction, تخطي
    Gui, Add, Button, x235 y50 w70 h30 gCancelAllAction, إلغاء الكل
    Gui, Add, Checkbox, x10 y90 w290 h20 vApplyToAll, تطبيق هذا الخيار على جميع العناصر المتكررة
    Gui, Show, w320 h120
    WinWaitClose, %ItemType% موجود
}