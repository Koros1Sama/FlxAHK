;Use Ctrl + Shift + Win + "+"or"=" to Open the manage menu
;Use your Flx Button + "," to Open the secure menu and it turns on by using Flx + F
;There is some Hotkeys are better to Remove Like the Flx + x it's in the script
#SingleInstance force
#Persistent
#NoEnv

;------------------ Global Settings ------------------
iniFile := A_ScriptDir "\Flx_Settings.ini"
scriptsDir := A_ScriptDir "\Scripts"
if !FileExist(scriptsDir) {
    FileCreateDir, %scriptsDir%
}

IniRead, monitoredFolders, %iniFile%, Settings, MonitoredFolders, F:\Anime,F:\Movies
IniRead, processNames, %iniFile%, Settings, ProcessNames, telegram.exe
IniRead, checkInterval, %iniFile%, Settings, CheckInterval, 1000
IniRead, isSecureMode, %iniFile%, Settings, IsSecureMode, 0
IniRead, baseHotkey, %iniFile%, HotkeySettings, BaseKey, SC056
global baseHotkey

; Load simple hotkeys with window conditions
CustomHotkeys := {}
IniRead, customKeys, %iniFile%, CustomHotkeys
if (customKeys = "ERROR") {
    customKeys := ""
}
Loop, Parse, customKeys, `n
{
    if (A_LoopField = "")
        continue
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length() >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, """", "")
        action := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (CustomHotkeys.HasKey(fullKey)) {
            continue
        }
        CustomHotkeys[fullKey] := action
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
        } catch e {
            MsgBox, 48, Error, Failed to define hotkey on load: %baseHotkey% & %baseKey%`nReason: %e%
        }
    }
}

; Load advanced scripts with window conditions
AdvancedScripts := {}
IniRead, advScripts, %iniFile%, AdvancedScripts
if (advScripts = "ERROR") {
    advScripts := ""
}
Loop, Parse, advScripts, `n
{
    if (A_LoopField = "")
        continue
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length() >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, """", "")
        scriptPath := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (AdvancedScripts.HasKey(fullKey)) {
            continue
        }
        fullPath := A_ScriptDir "\" scriptPath
        if FileExist(fullPath) {
            AdvancedScripts[fullKey] := scriptPath
            baseKey := RegExReplace(key, "[+^!#]")
            try {
                Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
            } catch e {
                MsgBox, 48, Error, Failed to define advanced script on load: %baseHotkey% & %baseKey%`nReason: %e%
            }
        } else {
            MsgBox, 48, Warning, Script file not found: %scriptPath%
        }
    }
}

; Load hotkeys without Flx with window conditions
NoFlxHotkeys := {}
IniRead, noFlxKeys, %iniFile%, NoFlx
if (noFlxKeys = "ERROR") {
    noFlxKeys := ""
}
Loop, Parse, noFlxKeys, `n
{
    if (A_LoopField = "")
        continue
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length() >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, """", "")
        action := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (NoFlxHotkeys.HasKey(fullKey)) {
            continue
        }
        NoFlxHotkeys[fullKey] := action
        try {
            Hotkey, %key%, ExecuteNoFlxHotkey, On
        } catch e {
            MsgBox, 48, Error, Failed to define hotkey without Flx on load: %key%`nReason: %e%
        }
    }
}

; Secure Mode Indicator GUI
Gui, SecureModeIndicator:+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x20
Gui, SecureModeIndicator:Color, 000000
WinSet, TransColor, 000000
Gui, SecureModeIndicator:Font, s12 cFFFFFF, Arial
Gui, SecureModeIndicator:Add, Text, BackgroundTrans, Secure Mode
Gui, SecureModeIndicator:Show, x0 y0 w120 h40 NoActivate
WinSet, Transparent, 150
if (isSecureMode) {
    Gui, SecureModeIndicator:Show, NoActivate
    SetTimer, CheckSecureMode, %checkInterval%
} else {
    Gui, SecureModeIndicator:Hide
    SetTimer, CheckSecureMode, Off
}

;------------------ Hotkeys ------------------
Hotkey, %baseHotkey%, OpenInteractiveMode
Hotkey, % baseHotkey " & F", ToggleSecureMode
Hotkey, % baseHotkey " & ,", OpenSettings
Hotkey, % baseHotkey " & =", OpenCustomHotkeysGUI
try {
    Hotkey, % baseHotkey " & X", ExecuteCustomXHotkey, On
} catch e {
    MsgBox, 48, Error, Failed to define hotkey %baseHotkey% & X`nReason: %e%
}

^#+=::
OpenCustomHotkeysGUI()
return

;------------------ Functions ------------------

OpenInteractiveMode:
    global baseHotkey
    ; Check if the GUI is already open
    IfWinExist, Hotkey Menu
    {
        Gui, InteractiveMenu:Destroy
        return
    }
    ; If not open, create it
    Gui, InteractiveMenu:Destroy  ; Destroy any old instance to ensure freshness
    Gui, InteractiveMenu:Color, 2D2D2D
    Gui, InteractiveMenu:Font, c000000 s10, Segoe UI
    Gui, InteractiveMenu:Add, Text, x10 y10 w300 h25 Center cFFD700, Select a Hotkey
    Gui, InteractiveMenu:Add, ListBox, x10 y40 w300 h230 vSelectedHotkey gExecuteFromMenu, % GenerateHotkeyListForMenu()
    Gui, InteractiveMenu:Show, w320 h270, Hotkey Menu
return

GenerateHotkeyListForMenu() {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey
    list := ""
    ; CustomHotkeys
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        displayText := baseHotkey " & " . key . " - " . action . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
    ; AdvancedScripts
    for fullKey, scriptPath in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        displayText := baseHotkey " & " . key . " - " . scriptPath . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
    ; NoFlxHotkeys
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : ""
        displayText := key . " - " . action . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
    return RTrim(list, "|")
}

ExecuteFromMenu:
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey, scriptsDir
    Gui, InteractiveMenu:Submit, NoHide
    if (SelectedHotkey = "") {
        return  ; Do nothing if nothing is selected
    }
    SplitHotkey := StrSplit(SelectedHotkey, " - ")
    if (SplitHotkey.Length() < 2) {
        MsgBox, 48, Error, Invalid hotkey format.
        return
    }
    keyDisplay := SplitHotkey[1]
    actionOrScript := SplitHotkey[2]
    
    ; Extract condition if present
    condition := ""
    if (InStr(actionOrScript, "(")) {
        conditionStart := InStr(actionOrScript, "(")
        conditionEnd := InStr(actionOrScript, ")",, -1)
        condition := SubStr(actionOrScript, conditionStart + 1, conditionEnd - conditionStart - 1)
        actionOrScript := Trim(SubStr(actionOrScript, 1, conditionStart - 1))
    }
    
    ; Determine if the hotkey uses Flx
    isFlx := InStr(keyDisplay, baseHotkey " & ")
    key := isFlx ? StrReplace(keyDisplay, baseHotkey " & ") : keyDisplay
    fullKey := StrReplace(key, ";", "VKBA") . (condition ? "|" . condition : "")

    ; Check condition if present
    if (condition && !WinActive(condition)) {
        MsgBox, 48, Error, Required window not active: %condition%
        return
    }

    ; Close the GUI first
    Gui, InteractiveMenu:Destroy
    
    ; Add a 70ms delay to allow the previous window to become active
    Sleep, 70

    ; Execute the hotkey based on its source
    if (isFlx && CustomHotkeys.HasKey(fullKey)) {
        action := CustomHotkeys[fullKey]
        ExecuteSingleAction(action)
    } else if (isFlx && AdvancedScripts.HasKey(fullKey)) {
        scriptPath := AdvancedScripts[fullKey]
        fullPath := A_ScriptDir "\" scriptPath
        if FileExist(fullPath) {
            SetWorkingDir, %scriptsDir%
            Run, %A_AhkPath% "%fullPath%", , UseErrorLevel
            SetWorkingDir, %A_ScriptDir%
            if (A_LastError) {
                MsgBox, 48, Error, Failed to run script: %fullPath%`nError: %A_LastError%
            }
        } else {
            MsgBox, 48, Error, Script file not found: %fullPath%
        }
    } else if (!isFlx && NoFlxHotkeys.HasKey(fullKey)) {
        action := NoFlxHotkeys[fullKey]
        ExecuteSingleAction(action)
    } else {
        MsgBox, 48, Error, Hotkey not defined: %fullKey%
    }
return

CancelInteractiveMenu:
    Gui, InteractiveMenu:Destroy
return

ToggleSecureMode() {
    global isSecureMode, checkInterval, processNames, iniFile
    isSecureMode := !isSecureMode
    IniWrite, %isSecureMode%, %iniFile%, Settings, IsSecureMode
    if (isSecureMode) {
        WinGet, activeWindow, ID, A
        Gui, SecureModeIndicator:Show, NoActivate
        processList := StrSplit(processNames, ",")
        for index, proc in processList {
            Process, Exist, %proc%
            if (ErrorLevel) {
                Process, Close, %proc%
            }
        }
        SetTimer, CheckSecureMode, %checkInterval%
        WinActivate, ahk_id %activeWindow%
    } else {
        Gui, SecureModeIndicator:Hide
        SetTimer, CheckSecureMode, Off
    }
}

CheckSecureMode:
    global isSecureMode, processNames
    if (isSecureMode) {
        processList := StrSplit(processNames, ",")
        for index, proc in processList {
            Process, Exist, %proc%
            if (ErrorLevel) {
                Process, Close, %proc%
            }
        }
        CloseMonitoredFolders()
    }
return

CloseMonitoredFolders() {
    global monitoredFolders
    shell := ComObjCreate("Shell.Application")
    folderList := StrSplit(monitoredFolders, ",")
    for window in shell.Windows {
        try {
            windowFolder := window.document.Folder.Self.Path
        } catch {
            continue
        }
        currentFolder := Trim(windowFolder, " `t`r`n\\")
        StringLower, currentFolder, currentFolder
        for index, folder in folderList {
            targetFolder := Trim(folder, " `t`r`n\\")
            StringLower, targetFolder, targetFolder
            if (currentFolder = targetFolder) {
                window.Quit()
                Sleep, 100
                break
            }
        }
    }
}

OpenSettings() {
    global monitoredFolders, processNames, checkInterval
    Gui, GuiSettings:Destroy
    Gui, GuiSettings:Color, 2D2D2D
    Gui, GuiSettings:Font, cFFFFFF s10, Segoe UI
    Gui, GuiSettings:Add, Text, x10 y10 w530 h30 Center cFFD700, Script Settings
    Gui, GuiSettings:Add, Text, x10 y50 w200 h50, Monitored Folders (separate with commas):
    Gui, GuiSettings:Add, Edit, x220 y50 w300 h25 vMonFolders c000000 Background424242, %monitoredFolders%
    Gui, GuiSettings:Add, Button, x530 y50 w80 h25 gBrowseFolders, Browse
    Gui, GuiSettings:Add, Text, x10 y85 w200 h50, Monitored Processes (separate with commas):
    Gui, GuiSettings:Add, Edit, x220 y85 w300 h25 vProcNames c000000 Background424242, %processNames%
    Gui, GuiSettings:Add, Button, x530 y85 w80 h25 gBrowseProcesses, Browse
    Gui, GuiSettings:Add, Text, x10 y120 w200 h25, Check Interval (in milliseconds):
    Gui, GuiSettings:Add, Edit, x220 y120 w300 h25 vChkInterval c000000 Background424242, %checkInterval%
    Gui, GuiSettings:Add, Button, x260 y165 w100 h30 gSaveSettings, Save
    Gui, GuiSettings:Add, Button, x370 y165 w100 h30 gCancelSettings, Cancel
    Gui, GuiSettings:Font, cA0A0A0 s8
    Gui, GuiSettings:Add, Text, x10 y205 w620 h20 Center, Use commas to separate folders and processes, or use the browse button to add
    Gui, GuiSettings:Show, w630 h230, Script Settings
}

BrowseFolders:
    Gui, GuiSettings:Submit, NoHide
    FileSelectFolder, selectedFolder, , 3, Select a folder to monitor
    if (selectedFolder != "") {
        if (MonFolders = "")
            GuiControl, GuiSettings:, MonFolders, %selectedFolder%
        else
            GuiControl, GuiSettings:, MonFolders, %MonFolders%,%selectedFolder%
    }
return

BrowseProcesses:
    Gui, GuiSettings:Submit, NoHide
    FileSelectFile, selectedFile, 3, , Select a process to monitor, Executable Files (*.exe)
    if (selectedFile != "") {
        SplitPath, selectedFile, fileName
        if (ProcNames = "")
            GuiControl, GuiSettings:, ProcNames, %fileName%
        else
            GuiControl, GuiSettings:, ProcNames, %ProcNames%,%fileName%
    }
return

SaveSettings:
    global monitoredFolders, processNames, checkInterval, iniFile
    Gui, GuiSettings:Submit, NoHide
    monitoredFolders := MonFolders
    processNames := ProcNames
    if (ChkInterval != "" && RegExMatch(ChkInterval, "^\d+$"))
        checkInterval := ChkInterval
    else {
        MsgBox, 48, Warning, Check interval must be an integer.
    }
    IniWrite, %monitoredFolders%, %iniFile%, Settings, MonitoredFolders
    IniWrite, %processNames%, %iniFile%, Settings, ProcessNames
    IniWrite, %checkInterval%, %iniFile%, Settings, CheckInterval
    Gui, GuiSettings:Destroy
return

CancelSettings:
    Gui, GuiSettings:Destroy
return

OpenCustomHotkeysGUI() {
    global iniFile, CustomHotkeys, AdvancedScripts, baseHotkey, NoFlxHotkeys
    Gui, CustomHotkeys:Destroy
    Gui, CustomHotkeys:Color, 2D2D2D
    Gui, CustomHotkeys:Font, cFFFFFF s10, Segoe UI
    Gui, CustomHotkeys:Add, Tab3, x0 y0 w650 h400, Basic|Advanced
    Gui, CustomHotkeys:Tab, Basic
    Gui, CustomHotkeys:Add, Text, x20 y50 w610 h30 Center cFFD700, Manage Hotkeys Easily
    Gui, CustomHotkeys:Add, Text, x20 y90 w150 h25, Key (e.g., T or 9):
    Gui, CustomHotkeys:Add, Edit, x180 y90 w150 h25 vHotkeyKey c000000 Background424242,
    Gui, CustomHotkeys:Add, Text, x340 y90 w300 h50 cA0A0A0, Symbols like = or , can also be used
    Gui, CustomHotkeys:Add, CheckBox, x20 y120 w60 h25 vUseFlx Checked, Flx
    Gui, CustomHotkeys:Add, CheckBox, x90 y120 w60 h25 vUseCtrl, Ctrl
    Gui, CustomHotkeys:Add, CheckBox, x160 y120 w60 h25 vUseShift, Shift
    Gui, CustomHotkeys:Add, CheckBox, x230 y120 w60 h25 vUseAlt, Alt
    Gui, CustomHotkeys:Add, CheckBox, x300 y120 w60 h25 vUseWin, Win
    Gui, CustomHotkeys:Add, Text, x20 y150 w180 h25, Active Window (optional):
    Gui, CustomHotkeys:Add, Edit, x180 y150 w300 h25 vWinCondition c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x490 y150 w80 h25 gBrowseWinCondition, Browse
    Gui, CustomHotkeys:Add, Button, x20 y180 w150 h40 gAddAppHotkey, Open App
    Gui, CustomHotkeys:Add, Button, x20 y230 w150 h40 gOpenTextInput, Send Text
    Gui, CustomHotkeys:Add, Button, x340 y180 w150 h40 gOpenFileHotkey, Open File
    Gui, CustomHotkeys:Add, Button, x180 y180 w150 h40 gOpenFolderHotkey, Open Folder
    Gui, CustomHotkeys:Add, Button, x180 y230 w150 h40 gOpenHotkeyManagerGUI, Manage Hotkeys
    Gui, CustomHotkeys:Tab, Advanced
    Gui, CustomHotkeys:Add, Text, x20 y50 w610 h30 Center cFFD700, Advanced Options
    Gui, CustomHotkeys:Add, Text, x20 y75 w150 h50, Flx Key (e.g., SC056):
    Gui, CustomHotkeys:Add, Edit, x180 y90 w150 h25 vBaseHotkeyInput c000000 Background424242, %baseHotkey%
    Gui, CustomHotkeys:Add, Button, x340 y90 w150 h25 gSaveBaseHotkey, Save Flx Key
    Gui, CustomHotkeys:Add, Text, x20 y110 w150 h50, Key (e.g., T) or press Detect:
    Gui, CustomHotkeys:Add, Edit, x180 y120 w150 h25 vAdvHotkeyKey c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x340 y120 w100 h25 gDetectKey, Detect Key
    Gui, CustomHotkeys:Add, Text, x450 y120 w190 h50 cA0A0A0, Symbols like = or , can also be used
    Gui, CustomHotkeys:Add, CheckBox, x20 y150 w60 h25 vAdvUseFlx Checked, Flx
    Gui, CustomHotkeys:Add, CheckBox, x90 y150 w60 h25 vAdvUseCtrl, Ctrl
    Gui, CustomHotkeys:Add, CheckBox, x160 y150 w60 h25 vAdvUseShift, Shift
    Gui, CustomHotkeys:Add, CheckBox, x230 y150 w60 h25 vAdvUseAlt, Alt
    Gui, CustomHotkeys:Add, CheckBox, x300 y150 w60 h25 vAdvUseWin, Win
    Gui, CustomHotkeys:Add, Text, x20 y180 w180 h25, Active Window (optional):
    Gui, CustomHotkeys:Add, Edit, x180 y180 w300 h25 vAdvWinCondition c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x490 y180 w80 h25 gBrowseWinConditionAdv, Browse
    Gui, CustomHotkeys:Add, Text, x20 y210 w150 h25, Script (full AHK code):
    Gui, CustomHotkeys:Add, Edit, x180 y210 w300 h80 vAdvHotkeyScript c000000 Background424242 Multi,
    Gui, CustomHotkeys:Add, Button, x490 y210 w80 h25 gBrowseAdvAction, Browse
    Gui, CustomHotkeys:Add, Button, x180 y300 w100 h30 gAddAdvHotkey, Add
    Gui, CustomHotkeys:Add, Button, x340 y300 w100 h30 gOpenHotkeyManagerGUI, Manage Hotkeys
    Gui, CustomHotkeys:Show, w650 h400, Hotkey Manager
}

BrowseWinCondition:
BrowseWinConditionAdv:
    Gui, CustomHotkeys:Submit, NoHide
    MsgBox, 64, Instructions, Click on the window you want to select after pressing "OK". The GUI will be temporarily hidden to allow selection.
    Gui, CustomHotkeys:Hide
    KeyWait, LButton, D T10
    if (ErrorLevel) {
        MsgBox, 48, Error, No window was clicked within 10 seconds.
        Gui, CustomHotkeys:Show
        return
    }
    MouseGetPos,,, windowID
    WinGet, activeExe, ProcessName, ahk_id %windowID%
    if (activeExe) {
        condition := "ahk_exe " . activeExe
        if (A_ThisLabel = "BrowseWinCondition") {
            GuiControl, CustomHotkeys:, WinCondition, %condition%
        } else {
            GuiControl, CustomHotkeys:, AdvWinCondition, %condition%
        }
    } else {
        MsgBox, 48, Error, No process found associated with the selected window.
    }
    Gui, CustomHotkeys:Show
return

SaveBaseHotkey:
    global baseHotkey, iniFile, CustomHotkeys, AdvancedScripts
    Gui, CustomHotkeys:Submit, NoHide
    if (BaseHotkeyInput = "") {
        MsgBox, 48, Error, Please enter a base key.
        return
    }
    oldBaseHotkey := baseHotkey
    baseHotkey := BaseHotkeyInput
    IniWrite, %baseHotkey%, %iniFile%, HotkeySettings, BaseKey
    ReloadHotkeys(oldBaseHotkey)
    MsgBox, 64, Done, Flx key changed to %baseHotkey% and hotkeys redefined successfully!
return

ReloadHotkeys(oldBaseHotkey) {
    global baseHotkey, CustomHotkeys, AdvancedScripts, NoFlxHotkeys
    for fullKey in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % oldBaseHotkey " & " . baseKey, Off
        } catch e {
            ; Ignore errors
        }
    }
    for fullKey in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % oldBaseHotkey " & " . baseKey, Off
        } catch e {
            ; Ignore errors
        }
    }
    for fullKey in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
        } catch e {
            MsgBox, 48, Error, Failed to define hotkey: %baseHotkey% & %baseKey%`nReason: %e%
        }
    }
    for fullKey in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
        } catch e {
            MsgBox, 48, Error, Failed to define advanced script: %baseHotkey% & %baseKey%`nReason: %e%
        }
    }
    try {
        Hotkey, % baseHotkey " & F", ToggleSecureMode, On
        Hotkey, % baseHotkey " & ,", OpenSettings, On
        Hotkey, % baseHotkey " & =", OpenCustomHotkeysGUI, On
        Hotkey, % baseHotkey " & X", ExecuteCustomXHotkey, On
    } catch e {
        MsgBox, 48, Error, Failed to redefine fixed hotkeys: %e%
    }
}

DetectKey:
    Gui, CustomHotkeys:+Disabled
    detectedKey := ""
    Loop, 255 {
        scanCode := Format("SC{:03X}", A_Index)
        if GetKeyState(scanCode, "P") {
            detectedKey := scanCode
            break
        }
        vkCode := Format("VK{:02X}", A_Index)
        if GetKeyState(vkCode, "P") {
            detectedKey := vkCode
            break
        }
    }
    if (detectedKey = "") {
        SetTimer, CheckKeyTimeout, 10000
        Loop {
            Loop, 255 {
                scanCode := Format("SC{:03X}", A_Index)
                if GetKeyState(scanCode, "P") {
                    detectedKey := scanCode
                    break 2
                }
                vkCode := Format("VK{:02X}", A_Index)
                if GetKeyState(vkCode, "P") {
                    detectedKey := vkCode
                    break 2
                }
            }
            Sleep, 50
        }
    }
    SetTimer, CheckKeyTimeout, Off
    if (detectedKey = "") {
        MsgBox, 48, Error, No key was pressed within 10 seconds.
    } else {
        detectedKey := RegExReplace(detectedKey, "[+^!#]")
        GuiControl, CustomHotkeys:, AdvHotkeyKey, %detectedKey%
    }
    Gui, CustomHotkeys:-Disabled
return

CheckKeyTimeout:
    detectedKey := ""
return

GenerateHotkeyList() {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys
    hotkeyList := ""
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (Flx)`n"
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        hotkeyList .= key . " | " . winCondition . " = " . script . " (Flx)`n"
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (NoFlx)`n"
    }
    return hotkeyList
}

AddAppHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, Error, Please enter a key.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    }
    ; Window to choose how to add the app
    Gui, AppInput:Destroy
    Gui, AppInput:Color, 2D2D2D
    Gui, AppInput:Font, cFFFFFF s10, Segoe UI
    Gui, AppInput:Add, Text, x20 y20 w300 h25, Choose how to add the application:
    Gui, AppInput:Add, Button, x20 y50 w150 h30 gBrowseAppFile, Select App File
    Gui, AppInput:Add, Button, x180 y50 w150 h30 gManualAppInput, Enter Command Manually
    Gui, AppInput:Add, Button, x100 y90 w100 h30 gCancelAppInput, Cancel
    Gui, AppInput:Show, w340 h130, Add Application to Hotkey
return

BrowseAppFile:
    Gui, AppInput:Destroy
    FileSelectFile, selectedFile, 3, , Select an application to open, Executable Files (*.exe)
    if (selectedFile != "") {
        Gui, CustomHotkeys:Submit, NoHide
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added without Flx successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
            }
        }
    }
return

ManualAppInput:
    Gui, AppInput:Destroy
    Gui, ManualInput:Destroy
    Gui, ManualInput:Color, 2D2D2D
    Gui, ManualInput:Font, cFFFFFF s10, Segoe UI
    Gui, ManualInput:Add, Text, x20 y20 w300 h25, Enter the run command (e.g., explorer.exe shell:...):
    Gui, ManualInput:Add, Edit, x20 y50 w400 h25 vManualCommand c000000 Background424242,
    Gui, ManualInput:Add, Button, x170 y80 w100 h30 gSaveManualCommand, Save
    Gui, ManualInput:Add, Button, x280 y80 w100 h30 gCancelManualInput, Cancel
    Gui, ManualInput:Show, w440 h120, Manual Command Input
return

SaveManualCommand:
    Gui, ManualInput:Submit
    if (ManualCommand != "") {
        Gui, CustomHotkeys:Submit, NoHide
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Run " . ManualCommand, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, ManualInput:Destroy
                MsgBox, 64, Done, Hotkey added successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
                Gui, ManualInput:Destroy
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Run " . ManualCommand, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, ManualInput:Destroy
                MsgBox, 64, Done, Hotkey added without Flx successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
                Gui, ManualInput:Destroy
            }
        }
    } else {
        MsgBox, 48, Error, Please enter a run command.
    }
return

CancelManualInput:
    Gui, ManualInput:Destroy
return

CancelAppInput:
    Gui, AppInput:Destroy
return
    FileSelectFile, selectedFile, 3, , Select an application to open, Executable Files (*.exe)
    if (selectedFile != "") {
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added without Flx successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
            }
        }
    }
return

OpenTextInput:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, Error, Please enter a key.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    }
    Gui, TextInput:Destroy
    Gui, TextInput:Color, 2D2D2D
    Gui, TextInput:Font, cFFFFFF s10, Segoe UI
    Gui, TextInput:Add, Text, x20 y20 w150 h25, Enter text to send:
    Gui, TextInput:Add, Edit, x180 y20 w300 h25 vTextToSend c000000 Background424242,
    Gui, TextInput:Add, Text, x20 y50 w460 h20 cA0A0A0, Note: You can also enter emojis like 😊 or 👍 here
    Gui, TextInput:Add, Button, x180 y80 w100 h30 gSaveTextHotkey, Save
    Gui, TextInput:Add, Button, x290 y80 w100 h30 gCancelTextInput, Cancel
    Gui, TextInput:Show, w500 h120, Send Text for Hotkey
return

SaveTextHotkey:
    Gui, TextInput:Submit
    if (TextToSend != "") {
        Gui, CustomHotkeys:Submit, NoHide
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Send " . TextToSend, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            fullKey := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "") . HotkeyKey . (WinCondition ? "|" . WinCondition : "")
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, TextInput:Destroy
                MsgBox, 64, Done, Hotkey added successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
                Gui, TextInput:Destroy
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Send " . TextToSend, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            fullKey := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "") . HotkeyKey . (WinCondition ? "|" . WinCondition : "")
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, TextInput:Destroy
                MsgBox, 64, Done, Hotkey added without Flx successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
                Gui, TextInput:Destroy
            }
        }
    } else {
        MsgBox, 48, Error, Please enter text.
        Gui, TextInput:Destroy
    }
return

CancelTextInput:
    Gui, TextInput:Destroy
return

OpenFileHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, Error, Please enter a key.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    }
    FileSelectFile, selectedFile, 3, , Select a file to open, All Files (*.*)
    if (selectedFile != "") {
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added to open file successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                MsgBox, 64, Done, Hotkey added without Flx to open file successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
            }
        }
    }
return

OpenFolderHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, Error, Please enter a key.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %WinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    }
    Gui, FolderInput:Destroy
    Gui, FolderInput:Color, 2D2D2D
    Gui, FolderInput:Font, cFFFFFF s10, Segoe UI
    Gui, FolderInput:Add, Text, x20 y20 w150 h25, Enter folder path:
    Gui, FolderInput:Add, Edit, x180 y20 w300 h25 vFolderPath c000000 Background424242,
    Gui, FolderInput:Add, Button, x490 y20 w80 h25 gBrowseFolder, Browse
    Gui, FolderInput:Add, Button, x180 y60 w100 h30 gSaveFolderHotkey, Save
    Gui, FolderInput:Add, Button, x290 y60 w100 h30 gCancelFolderInput, Cancel
    Gui, FolderInput:Show, w600 h100, Open Folder for Hotkey
return

BrowseFolder:
    Gui, FolderInput:Submit, NoHide
    FileSelectFolder, selectedFolder, , 3, Select a folder to open
    if (selectedFolder != "") {
        GuiControl, FolderInput:, FolderPath, %selectedFolder%
    }
return

SaveFolderHotkey:
    Gui, FolderInput:Submit
    if (FolderPath != "") {
        Gui, CustomHotkeys:Submit, NoHide
        if (UseFlx) {
            oldHotkeyCount := CustomHotkeys.Count()
            AddHotkey(HotkeyKey, "Run " . FolderPath, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            fullKey := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "") . HotkeyKey . (WinCondition ? "|" . WinCondition : "")
            if (CustomHotkeys.Count() > oldHotkeyCount || CustomHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, FolderInput:Destroy
                MsgBox, 64, Done, Hotkey added successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey.
                Gui, FolderInput:Destroy
            }
        } else {
            oldHotkeyCount := NoFlxHotkeys.Count()
            AddNoFlxHotkey(HotkeyKey, "Run " . FolderPath, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            fullKey := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "") . HotkeyKey . (WinCondition ? "|" . WinCondition : "")
            if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
                GuiControl, CustomHotkeys:, HotkeyKey,
                GuiControl, CustomHotkeys:, WinCondition,
                GuiControl, CustomHotkeys:, UseFlx, 1
                GuiControl, CustomHotkeys:, UseCtrl, 0
                GuiControl, CustomHotkeys:, UseShift, 0
                GuiControl, CustomHotkeys:, UseAlt, 0
                GuiControl, CustomHotkeys:, UseWin, 0
                Gui, FolderInput:Destroy
                MsgBox, 64, Done, Hotkey added without Flx successfully!
            } else {
                MsgBox, 48, Error, Failed to add hotkey without Flx.
                Gui, FolderInput:Destroy
            }
        }
    } else {
        MsgBox, 48, Error, Please enter a folder path or select one.
        Gui, FolderInput:Destroy
    }
return

CancelFolderInput:
    Gui, FolderInput:Destroy
return
AddAdvHotkey:
    global AdvancedScripts
    Gui, CustomHotkeys:Submit, NoHide
    if (AdvHotkeyKey = "" || AdvHotkeyScript = "") {
        MsgBox, 48, Error, Please enter a key and script.
        return
    }
    modifierPrefix := (AdvUseFlx ? "" : "") . (AdvUseCtrl ? "^" : "") . (AdvUseShift ? "+" : "") . (AdvUseAlt ? "!" : "") . (AdvUseWin ? "#" : "")
    key := modifierPrefix . AdvHotkeyKey
    fullKey := key . (AdvWinCondition ? "|" . AdvWinCondition : "")
    defaultScriptName := ""
    isEdit := 0
    if (AdvUseFlx && AdvancedScripts.HasKey(fullKey)) {
        defaultScriptName := StrReplace(AdvancedScripts[fullKey], "Scripts\", "")
        defaultScriptName := StrReplace(defaultScriptName, ".ahk", "")
        isEdit := 1
    }
    if (AdvUseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %AdvWinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    } else if (!AdvUseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %AdvWinCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
    }
    if (AdvUseFlx) {
        result := AddAdvancedScript(AdvHotkeyKey, AdvHotkeyScript, AdvUseCtrl, AdvUseShift, AdvUseAlt, AdvUseWin, defaultScriptName, AdvWinCondition)
        if (result = 1) {
            GuiControl, CustomHotkeys:, AdvHotkeyKey,
            GuiControl, CustomHotkeys:, AdvHotkeyScript,
            GuiControl, CustomHotkeys:, AdvWinCondition,
            GuiControl, CustomHotkeys:, AdvUseFlx, 1
            GuiControl, CustomHotkeys:, AdvUseCtrl, 0
            GuiControl, CustomHotkeys:, AdvUseShift, 0
            GuiControl, CustomHotkeys:, AdvUseAlt, 0
            GuiControl, CustomHotkeys:, AdvUseWin, 0
            actionText := isEdit ? "edit" : "addition"
            MsgBox, 64, Done, Advanced script %actionText% completed successfully!
        }
    } else {
        oldHotkeyCount := NoFlxHotkeys.Count()
        AddNoFlxHotkey(AdvHotkeyKey, AdvHotkeyScript, AdvUseCtrl, AdvUseShift, AdvUseAlt, AdvUseWin, AdvWinCondition)
        if (NoFlxHotkeys.Count() > oldHotkeyCount || NoFlxHotkeys.HasKey(fullKey)) {
            GuiControl, CustomHotkeys:, AdvHotkeyKey,
            GuiControl, CustomHotkeys:, AdvHotkeyScript,
            GuiControl, CustomHotkeys:, AdvWinCondition,
            GuiControl, CustomHotkeys:, AdvUseFlx, 1
            GuiControl, CustomHotkeys:, AdvUseCtrl, 0
            GuiControl, CustomHotkeys:, AdvUseShift, 0
            GuiControl, CustomHotkeys:, AdvUseAlt, 0
            GuiControl, CustomHotkeys:, AdvUseWin, 0
            MsgBox, 64, Done, Hotkey added without Flx successfully!
        } else {
            MsgBox, 48, Error, Failed to add hotkey without Flx.
        }
    }
return

BrowseAdvAction:
    Gui, CustomHotkeys:Submit, NoHide
    FileSelectFile, selectedFile, 3, , Select an AHK script file, AutoHotkey Scripts (*.ahk)
    if (selectedFile != "") {
        FileRead, scriptContent, %selectedFile%
        GuiControl, CustomHotkeys:, AdvHotkeyScript, %scriptContent%
    }
return

OpenHotkeyManagerGUI:
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys
    Gui, HotkeyManager:Destroy
    Gui, HotkeyManager:Color, 2D2D2D
    Gui, HotkeyManager:Font, cFFFFFF s10, Segoe UI
    Gui, HotkeyManager:Add, Text, x20 y20 w540 h25, Hotkey List:
    Gui, HotkeyManager:Add, Edit, x20 y50 w440 h25 vSearchTerm gSearchHotkeys c000000 Background424242,
    Gui, HotkeyManager:Add, Button, x470 y50 w90 h25 gSearchHotkeys, Search
    Gui, HotkeyManager:Add, ListView, x20 y80 w540 h200 vHotkeyList gHotkeyListEvent -Multi +Grid +LV0x10000 Background2D2D2D, Key|Window|Action|Type
    Gui, HotkeyManager:Add, Button, x130 y290 w100 h30 gDeleteSelectedHotkeys, Delete Selected
    Gui, HotkeyManager:Add, Button, x260 y290 w100 h30 gEditSelectedHotkey, Edit
    Gui, HotkeyManager:Add, Button, x390 y290 w100 h30 gCancelHotkeyManager, Cancel
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        LV_Add("", key, winCondition, action, "Simple (Flx)")
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        LV_Add("", key, winCondition, script, "Advanced (Flx)")
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        LV_Add("", key, winCondition, action, "Simple (NoFlx)")
    }
    LV_ModifyCol(1, 50)
    LV_ModifyCol(2, 100)
    LV_ModifyCol(3, 340)
    LV_ModifyCol(4, 50)
    Gui, HotkeyManager:Show, w650 h330, Hotkey Manager
return

CancelHotkeyManager:
    Gui, HotkeyManager:Destroy
return

SearchHotkeys:
    Gui, HotkeyManager:Submit, NoHide
    LV_Delete()
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(action, SearchTerm)) {
            LV_Add("", key, winCondition, action, "Simple (Flx)")
        }
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(script, SearchTerm)) {
            LV_Add("", key, winCondition, script, "Advanced (Flx)")
        }
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "Not specified"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(action, SearchTerm)) {
            LV_Add("", key, winCondition, action, "Simple (NoFlx)")
        }
    }
    LV_ModifyCol(1, 50)
    LV_ModifyCol(2, 100)
    LV_ModifyCol(3, 340)
    LV_ModifyCol(4, 50)
return

HotkeyListEvent:
    if (A_GuiEvent = "DoubleClick") {
        row := LV_GetNext(0)
        if (row) {
            LV_GetText(selectedKey, row, 1)
            LV_GetText(selectedWinCondition, row, 2)
            LV_GetText(type, row, 4)
            fullSelectedKey := StrReplace(selectedKey, ";", "VKBA") . (selectedWinCondition != "Not specified" ? "|" . selectedWinCondition : "")
            Gosub, EditSelectedHotkey
        }
    }
return

DeleteFromEditHotkey:
    MsgBox, 4, Confirmation, Do you want to delete the hotkey "%selectedKey%" with window condition "%selectedWinCondition%"?
    IfMsgBox, Yes
    {
        if (InStr(type, "Flx")) {
            if (InStr(type, "Simple")) {
                DeleteHotkeyAction(fullSelectedKey)
            } else {
                DeleteAdvancedScript(fullSelectedKey)
            }
        } else {
            DeleteNoFlxHotkey(fullSelectedKey)
        }
        Gui, EditHotkey:Destroy
        Gosub, OpenHotkeyManagerGUI
        MsgBox, 64, Done, Hotkey deleted successfully!
    }
return

EditSelectedHotkey:
    row := LV_GetNext(0)
    if (!row) {
        MsgBox, 48, Error, Please select a hotkey to edit.
        return
    }
    LV_GetText(selectedKey, row, 1)
    LV_GetText(selectedWinCondition, row, 2)
    LV_GetText(actionOrScript, row, 3)
    LV_GetText(type, row, 4)
    fullSelectedKey := StrReplace(selectedKey, ";", "VKBA") . (selectedWinCondition != "Not specified" ? "|" . selectedWinCondition : "")
    baseKey := RegExReplace(selectedKey, "[+^!#]")
    Gui, EditHotkey:Destroy
    Gui, EditHotkey:Color, 2D2D2D
    Gui, EditHotkey:Font, cFFFFFF s10, Segoe UI
    Gui, EditHotkey:Add, Text, x20 y20 w150 h25, Key:
    Gui, EditHotkey:Add, Edit, x180 y20 w150 h25 vNewKey c000000 Background424242, %baseKey%
    Gui, EditHotkey:Add, CheckBox, x20 y50 w60 h25 vUseFlx Checked, Flx
    Gui, EditHotkey:Add, CheckBox, x90 y50 w60 h25 vUseCtrl, Ctrl
    Gui, EditHotkey:Add, CheckBox, x160 y50 w60 h25 vUseShift, Shift
    Gui, EditHotkey:Add, CheckBox, x230 y50 w60 h25 vUseAlt, Alt
    Gui, EditHotkey:Add, CheckBox, x300 y50 w60 h25 vUseWin, Win
    Gui, EditHotkey:Add, Text, x20 y80 w180 h25, Active Window (optional):
    Gui, EditHotkey:Add, Edit, x180 y80 w300 h25 vNewWinCondition c000000 Background424242, % (selectedWinCondition != "Not specified" ? selectedWinCondition : "")
    Gui, EditHotkey:Add, Button, x490 y80 w80 h25 gBrowseWinConditionEdit, Browse
    if (InStr(type, "Simple")) {
        Gui, EditHotkey:Add, Text, x20 y110 w150 h25, Action:
        Gui, EditHotkey:Add, Edit, x180 y110 w300 h25 vNewAction c000000 Background424242, %actionOrScript%
    } else {
        Gui, EditHotkey:Add, Text, x20 y110 w150 h25, Script:
        Gui, EditHotkey:Add, Edit, x180 y110 w300 h100 vNewAction c000000 Background424242 Multi, %actionOrScript%
        fullPath := A_ScriptDir "\" actionOrScript
        if FileExist(fullPath) {
            FileRead, scriptContent, %fullPath%
            GuiControl, EditHotkey:, NewAction, %scriptContent%
        }
    }
    Gui, EditHotkey:Add, Button, x180 y230 w100 h30 gSaveEditedHotkey, Save
    Gui, EditHotkey:Add, Button, x290 y230 w100 h30 gCancelEditHotkey, Cancel
    Gui, EditHotkey:Add, Button, x400 y230 w100 h30 gDeleteFromEditHotkey, Delete
    if (InStr(type, "Advanced")) {
        Gui, EditHotkey:Add, Button, x180 y270 w100 h30 gOpenScriptLocation, Open Location
    }
    if (InStr(fullSelectedKey, "^"))
        GuiControl, EditHotkey:, UseCtrl, 1
    if (InStr(fullSelectedKey, "+"))
        GuiControl, EditHotkey:, UseShift, 1
    if (InStr(fullSelectedKey, "!"))
        GuiControl, EditHotkey:, UseAlt, 1
    if (InStr(fullSelectedKey, "#"))
        GuiControl, EditHotkey:, UseWin, 1
    if (!InStr(type, "Flx"))
        GuiControl, EditHotkey:, UseFlx, 0
    Gui, EditHotkey:Show, w510 h310, Edit Hotkey
return

BrowseWinConditionEdit:
    Gui, EditHotkey:Submit, NoHide
    MsgBox, 64, Instructions, Click on the window you want to select after pressing "OK". The GUI will be temporarily hidden to allow selection.
    Gui, EditHotkey:Hide
    KeyWait, LButton, D T10
    if (ErrorLevel) {
        MsgBox, 48, Error, No window was clicked within 10 seconds.
        Gui, EditHotkey:Show
        return
    }
    MouseGetPos,,, windowID
    WinGet, activeExe, ProcessName, ahk_id %windowID%
    if (activeExe) {
        condition := "ahk_exe " . activeExe
        GuiControl, EditHotkey:, NewWinCondition, %condition%
    } else {
        MsgBox, 48, Error, No process found associated with the selected window.
    }
    Gui, EditHotkey:Show
return

OpenScriptLocation:
    global AdvancedScripts, fullSelectedKey
    scriptPath := AdvancedScripts[fullSelectedKey]
    if (scriptPath != "") {
        fullPath := A_ScriptDir "\" scriptPath
        SplitPath, fullPath,, dir
        Run, explorer.exe "%dir%"
    } else {
        MsgBox, 48, Error, Cannot find script location.
    }
return

SaveEditedHotkey:
    Gui, EditHotkey:Submit
    if (NewKey = "") {
        MsgBox, 48, Error, Please enter a key.
        Gui, EditHotkey:Destroy
        return
    }
    newKey := StrReplace(NewKey, ";", "VKBA")
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    fullNewKey := modifierPrefix . newKey . (NewWinCondition ? "|" . NewWinCondition : "")
    if (fullNewKey != fullSelectedKey) {
        if (UseFlx && (CustomHotkeys.HasKey(fullNewKey) || AdvancedScripts.HasKey(fullNewKey))) {
            oldAction := CustomHotkeys[fullNewKey] ? CustomHotkeys[fullNewKey] : AdvancedScripts[fullNewKey]
            MsgBox, 4, Warning, The key %fullNewKey% is already in use:`n%oldAction%`nDo you want to replace it?
            IfMsgBox, No
                return
        } else if (!UseFlx && NoFlxHotkeys.HasKey(fullNewKey)) {
            oldAction := NoFlxHotkeys[fullNewKey]
            MsgBox, 4, Warning, The key %fullNewKey% is already in use:`n%oldAction%`nDo you want to replace it?
            IfMsgBox, No
                return
        }
    }
    if (InStr(type, "Flx")) {
        if (InStr(type, "Simple")) {
            DeleteHotkeyAction(fullSelectedKey)
            if (UseFlx) {
                AddHotkey(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, NewWinCondition)
            } else {
                AddNoFlxHotkey(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin, NewWinCondition)
            }
        } else {
            DeleteAdvancedScript(fullSelectedKey)
            if (UseFlx) {
                AddAdvancedScript(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin,, NewWinCondition)
            } else {
                AddNoFlxHotkey(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin, NewWinCondition)
            }
        }
    } else {
        DeleteNoFlxHotkey(fullSelectedKey)
        if (UseFlx) {
            if (InStr(type, "Simple")) {
                AddHotkey(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, NewWinCondition)
            } else {
                AddAdvancedScript(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin,, NewWinCondition)
            }
        } else {
            AddNoFlxHotkey(newKey, NewAction, UseCtrl, UseShift, UseAlt, UseWin, NewWinCondition)
        }
    }
    Gui, EditHotkey:Destroy
    Gosub, OpenHotkeyManagerGUI
    MsgBox, 64, Done, Hotkey edited successfully!
return

CancelEditHotkey:
    Gui, EditHotkey:Destroy
return

DeleteSelectedHotkeys:
    selectedRows := []
    Loop {
        row := LV_GetNext(row ? row : 0)
        if (!row)
            break
        LV_GetText(key, row, 1)
        LV_GetText(winCondition, row, 2)
        LV_GetText(type, row, 4)
        fullKey := StrReplace(key, ";", "VKBA") . (winCondition != "Not specified" ? "|" . winCondition : "")
        selectedRows.Push({Key: fullKey, Type: type})
    }
    count := selectedRows.Length()
    if (count = 0) {
        MsgBox, 48, Error, Please select at least one hotkey.
        return
    }
    MsgBox, 4, Confirmation, Do you want to delete %count% selected items?
    IfMsgBox, Yes
    {
        for index, item in selectedRows {
            if (InStr(item.Type, "Flx")) {
                if (InStr(item.Type, "Simple")) {
                    DeleteHotkeyAction(item.Key)
                } else {
                    DeleteAdvancedScript(item.Key)
                }
            } else {
                DeleteNoFlxHotkey(item.Key)
            }
        }
        Gosub, OpenHotkeyManagerGUI
        MsgBox, 64, Done, Selected items deleted successfully!
    }
return

DeleteHotkeyAction(fullKey) {
    global iniFile, CustomHotkeys, baseHotkey
    IniDelete, %iniFile%, CustomHotkeys, %fullKey%
    CustomHotkeys.Delete(fullKey)
    SplitKeyCond := StrSplit(fullKey, "|")
    key := SplitKeyCond[1]
    baseKey := RegExReplace(key, "[+^!#]")
    try {
        Hotkey, % baseHotkey " & " . baseKey, Off
    } catch e {
        ; Ignore errors if hotkey isn’t defined
    }
}

DeleteAdvancedScript(fullKey) {
    global iniFile, AdvancedScripts, scriptsDir, baseHotkey
    scriptPath := AdvancedScripts[fullKey]
    if (scriptPath != "") {
        fullPath := A_ScriptDir "\" scriptPath
        FileDelete, %fullPath%
    }
    IniDelete, %iniFile%, AdvancedScripts, %fullKey%
    AdvancedScripts.Delete(fullKey)
    SplitKeyCond := StrSplit(fullKey, "|")
    key := SplitKeyCond[1]
    baseKey := RegExReplace(key, "[+^!#]")
    try {
        Hotkey, % baseHotkey " & " . baseKey, Off
    } catch e {
        ; Ignore errors
    }
}

DeleteNoFlxHotkey(fullKey) {
    global iniFile, NoFlxHotkeys
    IniDelete, %iniFile%, NoFlx, %fullKey%
    NoFlxHotkeys.Delete(fullKey)
    SplitKeyCond := StrSplit(fullKey, "|")
    key := SplitKeyCond[1]
    try {
        Hotkey, %key%, Off
    } catch e {
        ; Ignore errors
    }
}

AddHotkey(key, action, useCtrl := 0, useShift := 0, useAlt := 0, useWin := 0, useFlx := 1, winCondition := "") {
    global iniFile, CustomHotkeys, baseHotkey
    if (key = ";") {
        key := "VKBA"
    } else {
        key := Format("{:U}", key)
    }
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    if (CustomHotkeys.HasKey(fullKey)) {
        oldAction := CustomHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %winCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
        DeleteHotkeyAction(fullKey)
    } else if (AdvancedScripts.HasKey(fullKey)) {
        oldScript := AdvancedScripts[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %winCondition% is already in use as an advanced script:`n%oldScript%`nDo you want to replace it?
        IfMsgBox, No
            return
        DeleteAdvancedScript(fullKey)
    }
    IniWrite, %action%, %iniFile%, CustomHotkeys, %fullKey%
    CustomHotkeys[fullKey] := action
    baseKey := RegExReplace(key, "[+^!#]")
    try {
        Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
    } catch e {
        MsgBox, 48, Error, Failed to define hotkey: %baseHotkey% & %baseKey%`nReason: %e%
    }
}

AddAdvancedScript(key, script, useCtrl := 0, useShift := 0, useAlt := 0, useWin := 0, defaultName := "", winCondition := "") {
    global iniFile, AdvancedScripts, scriptsDir, baseHotkey
    if (key = ";") {
        key := "VKBA"
    } else {
        key := Format("{:U}", key)
    }
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    defaultValue := defaultName ? defaultName : key
    InputBox, scriptName, Enter Script Name, Enter a name for the script (without .ahk):,, 300, 150,,,, %defaultValue%
    if (ErrorLevel || scriptName = "") {
        return 0
    }
    if (SubStr(scriptName, -3) != ".ahk") {
        scriptName .= ".ahk"
    }
    scriptPath := "Scripts\" scriptName
    fullScriptPath := scriptsDir "\" scriptName
    for existingKey, existingPath in AdvancedScripts {
        if (existingPath = scriptPath && existingKey != fullKey) {
            MsgBox, 48, Error, The script name %scriptName% is already in use for another hotkey.`nPlease choose a different name.
            return 0
        }
    }
    FileDelete, %fullScriptPath%
    FileAppend, %script%, %fullScriptPath%, UTF-8
    if (ErrorLevel) {
        MsgBox, 48, Error, Failed to save script to: %fullScriptPath%
        return 0
    }
    if (AdvancedScripts.HasKey(fullKey)) {
        oldScriptPath := AdvancedScripts[fullKey]
        if (oldScriptPath != scriptPath) {
            FileDelete, % A_ScriptDir "\" oldScriptPath
        }
        IniDelete, %iniFile%, AdvancedScripts, %fullKey%
    }
    IniWrite, %scriptPath%, %iniFile%, AdvancedScripts, %fullKey%
    AdvancedScripts[fullKey] := scriptPath
    baseKey := RegExReplace(key, "[+^!#]")
    try {
        Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
    } catch e {
        MsgBox, 48, Error, Failed to define advanced script: %baseHotkey% & %baseKey%`nReason: %e%
        return 0
    }
    return 1
}

AddNoFlxHotkey(key, action, useCtrl := 0, useShift := 0, useAlt := 0, useWin := 0, winCondition := "") {
    global iniFile, NoFlxHotkeys
    if (key = ";") {
        key := "VKBA"
    } else {
        key := Format("{:U}", key)
    }
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    if (NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, Warning, The key %key% with window condition %winCondition% is already in use:`n%oldAction%`nDo you want to replace it?
        IfMsgBox, No
            return
        DeleteNoFlxHotkey(fullKey)
    }
    IniWrite, %action%, %iniFile%, NoFlx, %fullKey%
    NoFlxHotkeys[fullKey] := action
    try {
        Hotkey, % modifierPrefix . key, ExecuteNoFlxHotkey, On
    } catch e {
        MsgBox, 48, Error, Failed to define hotkey without Flx: %fullKey%`nReason: %e%
    }
}

ExecuteHotkey:
    global CustomHotkeys, AdvancedScripts, baseHotkey, scriptsDir
    keyPressed := StrReplace(A_ThisHotkey, baseHotkey " & ")
    ctrlState := GetKeyState("Ctrl", "P")
    shiftState := GetKeyState("Shift", "P")
    altState := GetKeyState("Alt", "P")
    winState := GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
    modifierPrefix := (ctrlState ? "^" : "") . (shiftState ? "+" : "") . (altState ? "!" : "") . (winState ? "#" : "")
    baseKey := modifierPrefix . keyPressed
    WinGet, activeExe, ProcessName, A
    currentWinCondition := activeExe ? "ahk_exe " . activeExe : ""
    fullKeyWithCondition := baseKey . (currentWinCondition ? "|" . currentWinCondition : "")
    fullKeyDefault := baseKey
    if (AdvancedScripts.HasKey(fullKeyWithCondition)) {
        scriptPath := AdvancedScripts[fullKeyWithCondition]
        fullPath := A_ScriptDir "\" scriptPath
        if FileExist(fullPath) {
            SetWorkingDir, %scriptsDir%
            Run, %A_AhkPath% "%fullPath%", , UseErrorLevel
            SetWorkingDir, %A_ScriptDir%
            if (A_LastError) {
                MsgBox, 48, Error, Failed to run script: %fullPath%`nError: %A_LastError%
            }
        } else {
            MsgBox, 48, Error, Script file not found: %fullPath%
        }
    }
    else if (AdvancedScripts.HasKey(fullKeyDefault)) {
        scriptPath := AdvancedScripts[fullKeyDefault]
        fullPath := A_ScriptDir "\" scriptPath
        if FileExist(fullPath) {
            SetWorkingDir, %scriptsDir%
            Run, %A_AhkPath% "%fullPath%", , UseErrorLevel
            SetWorkingDir, %A_ScriptDir%
            if (A_LastError) {
                MsgBox, 48, Error, Failed to run script: %fullPath%`nError: %A_LastError%
            }
        } else {
            MsgBox, 48, Error, Script file not found: %fullPath%
        }
    }
    else if (CustomHotkeys.HasKey(fullKeyWithCondition)) {
        action := CustomHotkeys[fullKeyWithCondition]
        ExecuteSingleAction(action)
    }
    else if (CustomHotkeys.HasKey(fullKeyDefault)) {
        action := CustomHotkeys[fullKeyDefault]
        ExecuteSingleAction(action)
    }
return

ExecuteNoFlxHotkey:
    global NoFlxHotkeys
    keyPressed := A_ThisHotkey
    WinGet, activeExe, ProcessName, A
    currentWinCondition := activeExe ? "ahk_exe " . activeExe : ""
    fullKeyWithCondition := keyPressed . (currentWinCondition ? "|" . currentWinCondition : "")
    fullKeyDefault := keyPressed
    if (NoFlxHotkeys.HasKey(fullKeyWithCondition)) {
        action := NoFlxHotkeys[fullKeyWithCondition]
        ExecuteSingleAction(action)
    }
    else if (NoFlxHotkeys.HasKey(fullKeyDefault)) {
        action := NoFlxHotkeys[fullKeyDefault]
        ExecuteSingleAction(action)
    }
return

ExecuteSingleAction(action) {
    action := Trim(action)
    if (InStr(action, "Run ") = 1) {
        command := Trim(SubStr(action, 5))
        
        ; Extract process name or path for checking
        SplitPath, command, fileName, dir
        if (fileName = "") {  ; If it’s only a folder path
            ; Open the folder directly without checking
            Run, explorer.exe "%command%", , UseErrorLevel
            if (A_LastError) {
                MsgBox, 48, Error, Failed to open folder: %command%`nError: %A_LastError%
            }
            return
        } else {  ; If it’s a file (like an application)
            targetPath := fileName
        }

        ; Handle applications only
        WinGet, activePath, ProcessName, A
        WinGet, activeID, ID, A
        if (activePath = targetPath) {  ; If the application is active
            WinMinimize, ahk_id %activeID%
            return
        } else {
            WinGet, processList, List, ahk_exe %targetPath%
            if (processList > 0) {  ; If the application is open
                Loop, %processList% {
                    thisID := processList%A_Index%
                    WinGet, thisState, MinMax, ahk_id %thisID%
                    if (thisState != -1) {  ; If it’s not minimized
                        WinMinimize, ahk_id %thisID%
                        return
                    } else {  ; If it’s minimized
                        WinRestore, ahk_id %thisID%
                        WinActivate, ahk_id %thisID%
                        return
                    }
                }
            }
        }

        ; If the application isn’t open, run it
        Run, %command%, , UseErrorLevel
        if (A_LastError) {
            MsgBox, 48, Error, Failed to run: %command%`nError: %A_LastError%
        }
    } else if (InStr(action, "Send ") = 1) {
        command := Trim(SubStr(action, 6))
        Send, %command%
    } else if (InStr(action, "WinMinimize") = 1) {
        WinMinimize, A
    } else if (InStr(action, "WinMaximize") = 1) {
        WinMaximize, A
    } else if (InStr(action, "WinClose") = 1) {
        WinClose, A
    } else {
        try {
            Run, %A_AhkPath% /c "%action%", , UseErrorLevel
            if (A_LastError) {
                MsgBox, 48, Error, Failed to execute command: %action%`nError: %A_LastError%
            }
        } catch e {
            MsgBox, 48, Error, Unsupported or invalid command: %action%`nReason: %e%
        }
    }
}

;------------------ Additional Hotkeys and Functions ------------------
#IfWinActive ahk_class WorkerW
~n::
Send ^+!n
return

~z::
Send ^+!z
return

~k::
Send ^+!k
return

~m::
Send ^+!m
return

~h::
Send ^+!h
return
#IfWinActive

ExecuteCustomXHotkey:
    global isSecureMode
    if (!isSecureMode) {
        ToggleSecureMode()
    }
    Send !^+x
    IfWinActive, ahk_class Qt51515QWindowIcon
    {
        SendInput, #1
        Sleep, 100
    }
    if WinActive("ahk_class Qt5QWindowIcon")
    {
        Run, "F:\D old\Abu Hadhoud\Fundamentals of Programming #Course 1\Lesson Six_ Parts of a Byte and Its Terms(360P).mp4"
    }
    if WinActive("ahk_class Chrome_WidgetWin_1")
    {
        Send, ^+!\
        Sleep, 10
        Sleep, 500
        Send, ^+!r
    }
    Process, Close, Telegram.exe
return