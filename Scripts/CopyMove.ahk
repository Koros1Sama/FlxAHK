#SingleInstance Force

; Load settings from INI file
Loop, 12  ; Increased to 12 to include *, /, +
{
    IniRead, Action%A_Index%, %A_ScriptDir%\FileOperations.ini, Settings, Action%A_Index%, Copy
    IniRead, Path%A_Index%, %A_ScriptDir%\FileOperations.ini, Settings, Path%A_Index%, F:\Anime
}

; Define valid keys including new symbols
ValidKeys := "0123456789*/+"
Input, Key, L1 T3, %ValidKeys%
if (ErrorLevel = "Timeout")
    ExitApp

; Exit if key pressed is not in our valid set
if (!InStr(ValidKeys, Key))
    ExitApp

if (Key = "0")
{
    ; Settings GUI with single column, Browse next to Action dropdown
    Gui, Settings:New, +AlwaysOnTop, Button Settings
    Gui, Add, Text, x160 y8, Configure action and path for each button
    
    ; Define button labels including new symbols
    ButtonLabels := ["NumPad1", "NumPad2", "NumPad3", "NumPad4", "NumPad5", "NumPad6", "NumPad7", "NumPad8", "NumPad9", "Multiply(*)", "Divide(/)", "Add(+)"]
    
    Loop, 12  ; Increased to 12 to include *, /, +
    {
        yPos := 30 + (A_Index - 1) * 40
        Gui, Add, Text, x10 y%yPos% w80, % ButtonLabels[A_Index] ":"
        Gui, Add, DropDownList, x90 y%yPos% vAction%A_Index% w100, Copy|Move|Create Shortcut
        GuiControl, ChooseString, Action%A_Index%, % Action%A_Index%
        Gui, Add, Button, x200 y%yPos% gBrowse%A_Index%, Browse
        Gui, Add, Edit, x280 y%yPos% vPath%A_Index% w250, % Path%A_Index%
    }
    
    ; Save and Cancel buttons at the bottom
    Gui, Add, Button, x200 y505 w80 gSaveSettings Default, Save  ; Adjusted Y position
    Gui, Add, Button, x300 y505 w80 gCancelSettings, Cancel     ; Adjusted Y position
    Gui, Show, w550 h540  ; Increased height to accommodate new rows
    return
}

; Map special keys to numbers 10-12
if (Key = "*")
    Num := 10
else if (Key = "/")
    Num := 11
else if (Key = "+")
    Num := 12
else if (Key >= "1" && Key <= "9")
    Num := Key
else
    ExitApp

; Only process if we have a valid number (1-12)
if (Num >= 1 && Num <= 12)
{
    ChosenOperation := Action%Num%
    TargetPath := Path%Num%
    
    ; Copy selected items to clipboard
    Clipboard := ""
    Send {Ctrl down}
    Sleep 100
    Send {c down}
    Sleep 100
    Send {c up}
    Send {Ctrl up}
    ClipWait, 2
    if (ErrorLevel)
        ExitApp

    ; Global variables
    global ApplyToAll := 0
    global ChosenAction := ""
    global CancelCopy := 0
    global TotalBytes := 0
    global ProcessedBytes := 0

    ItemsToCopy := StrSplit(Clipboard, "`n", "`r")

    ; Calculate total size for progress bar
    Loop, % ItemsToCopy.Length()
    {
        Item := Trim(ItemsToCopy[A_Index])
        IfExist, %Item%
        {
            SplitPath, Item,,, ItemExt
            if (ItemExt != "") {
                FileGetSize, FileSize, %Item%
                TotalBytes += FileSize
            }
            else {
                Loop, Files, %Item%\*.*, R
                {
                    FileGetSize, FileSize, %A_LoopFileFullPath%
                    TotalBytes += FileSize
                }
            }
        }
    }

    Progress, B W100 H10 X0 Y0 Range0-%TotalBytes%
    Progress, 0

    ; Process items
    Loop, % ItemsToCopy.Length()
    {
        ItemToCopy := Trim(ItemsToCopy[A_Index])
        
        IfExist, %ItemToCopy%
        {
            SplitPath, ItemToCopy, ItemName,, ItemExt
            
            ; Handle both files and folders
            TargetItem := TargetPath . "\" . ItemName
            IfNotExist, %TargetPath%
                FileCreateDir, %TargetPath%
                
            IfExist, %TargetItem%
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
                    ShowDuplicateDialog(ItemName, (ItemExt != "" ? "File" : "Folder"))
                }
            }
            else
                ProcessItem(ItemToCopy, TargetItem)
        }
        if (CancelCopy)
            break
    }

    Progress, Off
    ExitApp
}

; Browse buttons for settings (expanded to 12)
Browse1:
Browse2:
Browse3:
Browse4:
Browse5:
Browse6:
Browse7:
Browse8:
Browse9:
Browse10:
Browse11:
Browse12:
Num := SubStr(A_ThisLabel, 7)
Gui, Settings:Submit, NoHide
FileSelectFolder, SelectedFolder, , 3
if (SelectedFolder != "")
    GuiControl,, Path%Num%, %SelectedFolder%
return

SaveSettings:
Gui, Settings:Submit
Loop, 12  ; Increased to 12
{
    IniWrite, % Action%A_Index%, %A_ScriptDir%\FileOperations.ini, Settings, Action%A_Index%
    IniWrite, % Path%A_Index%, %A_ScriptDir%\FileOperations.ini, Settings, Path%A_Index%
}
Gui, Settings:Destroy
ExitApp

CancelSettings:
Gui, Settings:Destroy
ExitApp

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
    FileDelete, %TargetItem%
    ProcessItem(ItemToCopy, TargetItem)
} else {
    FileRemoveDir, %TargetItem%, 1
    if (!ErrorLevel)
        ProcessItem(ItemToCopy, TargetItem)
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
        NewTarget := TargetPath . "\" . NewName . "." . ItemExt
    else
        NewTarget := TargetPath . "\" . NewName
    
    IfNotExist, %NewTarget%
        break
}
ProcessItem(ItemToCopy, NewTarget)
return

ProcessItem(Source, Dest) {
    global ChosenOperation, ProcessedBytes, ItemExt
    if (ChosenOperation = "Copy") {
        if (ItemExt != "")
            CopyFileWithProgress(Source, Dest)
        else
            CopyFolderWithProgress(Source, Dest)
    }
    else if (ChosenOperation = "Move") {
        if (ItemExt != "") {
            FileMove, %Source%, %Dest%, 1
            FileGetSize, FileSize, %Source%
            ProcessedBytes += FileSize
        }
        else {
            FileMoveDir, %Source%, %Dest%, 1
            Loop, Files, %Dest%\*.*, R
                FileGetSize, FileSize, %A_LoopFileFullPath%
                ProcessedBytes += FileSize
        }
        Progress, %ProcessedBytes%
        Sleep, 10
    }
    else if (ChosenOperation = "Create Shortcut") {
        if (ItemExt != "")
            FileCreateShortcut, %Source%, %Dest%.lnk
        else
            FileCreateShortcut, %Source%, %Dest%.lnk
        ProcessedBytes += 100
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
    Gui, Duplicate:New, +AlwaysOnTop, %ItemType% Exists
    Gui, Add, Text,, The %ItemType% %ItemName% already exists
    Gui, Add, Button, x10 y50 w70 h30 gReplaceAction, Replace
    Gui, Add, Button, x85 y50 w70 h30 gRenameAction, Rename
    Gui, Add, Button, x160 y50 w70 h30 gCancelAction, Skip
    Gui, Add, Button, x235 y50 w70 h30 gCancelAllAction, Cancel All
    Gui, Add, Checkbox, x10 y90 w290 h20 vApplyToAll, Apply this choice to all duplicate items
    Gui, Show, w320 h120
    WinWaitClose, %ItemType% Exists
}