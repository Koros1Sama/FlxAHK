#SingleInstance force
#Persistent
#NoEnv
#UseHook On          ; لتحسين أداء الاختصارات المعقدة
#InstallKeybdHook    ; لضمان تتبع المفاتيح بشكل جيد
;------------------ Global Settings ------------------
iniFile := A_ScriptDir "\Flx_Settings.ini"
scriptsDir := A_ScriptDir "\Scripts"
if !FileExist(scriptsDir) {
    FileCreateDir, %scriptsDir%
}
HotkeyConditions := {} ; لتتبع شروط NoFlxHotkeys

IniRead, monitoredFolders, %iniFile%, Settings, MonitoredFolders, F:\Anime,F:\Movies
IniRead, processNames, %iniFile%, Settings, ProcessNames, telegram.exe
IniRead, checkInterval, %iniFile%, Settings, CheckInterval, 1000
IniRead, isSecureMode, %iniFile%, Settings, IsSecureMode, 0
IniRead, baseHotkey, %iniFile%, HotkeySettings, BaseKey, SC056
global baseHotkey

; التحقق من صلاحية baseHotkey
if (!baseHotkey || baseHotkey = "ERROR") {
    InputBox, baseHotkey, إدخال زر Flx, أدخل رمز المفتاح الأساسي (مثل SC056 أو SC029):,, 300, 150,,,, SC056
    if (ErrorLevel || baseHotkey = "") {
        MsgBox, 48, خطأ, لم يتم إدخال زر Flx صالح. سيتم إنهاء السكربت.
        ExitApp
    }
    IniWrite, %baseHotkey%, %iniFile%, HotkeySettings, BaseKey
}

; إعادة تعريف الاختصارات بناءً على baseHotkey
ReloadHotkeys("")  ; استدعاء ReloadHotkeys بدون oldBaseHotkey لأنه التحميل الأولي

; تعريف الاختصارات الثابتة (للتأكد فقط)
try {
    Hotkey, %baseHotkey%, OpenInteractiveMode, On
    Hotkey, % baseHotkey " & D", ToggleSecureMode, On
    Hotkey, % baseHotkey " & ,", OpenSettings, On
    Hotkey, % baseHotkey " & =", OpenCustomHotkeysGUI, On
    Hotkey, % baseHotkey " & X", ExecuteCustomXHotkey, On
} catch e {
    MsgBox, 48, خطأ, فشل تعريف اختصارات Flx الأساسية:`nالسبب: %e%
}

; تحميل الاختصارات البسيطة مع شروط النافذة
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
            MsgBox, 48, خطأ, فشل تعريف الاختصار عند التحميل: %baseHotkey% & %baseKey%`nالسبب: %e%
        }
    }
}

; تحميل السكربتات المتقدمة مع شروط النافذة
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
                MsgBox, 48, خطأ, فشل تعريف السكربت المتقدم عند التحميل: %baseHotkey% & %baseKey%`nالسبب: %e%
            }
        } else {
            MsgBox, 48, تحذير, ملف السكربت غير موجود: %scriptPath%
        }
    }
}

; تحميل الاختصارات بدون Flx مع شروط النافذة
; تحميل الاختصارات بدون Flx مع شروط النافذة
NoFlxHotkeys := {}
HotkeyConditions := {} ; لتتبع الشروط لكل مفتاح
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
        ; تخزين الشرط لكل مفتاح
        if (!HotkeyConditions.HasKey(key)) {
            HotkeyConditions[key] := {}
        }
        HotkeyConditions[key][fullKey] := winCondition
        ; تعريف الاختصار ديناميكيًا مع شرط النافذة
        try {
            if (winCondition) {
                Hotkey, IfWinActive, %winCondition%
                Hotkey, %key%, ExecuteNoFlxHotkeyConditional, On
                Hotkey, IfWinActive
            } else {
                Hotkey, %key%, ExecuteNoFlxHotkeyConditional, On
            }
        } catch e {
            MsgBox, 48, خطأ, فشل تعريف الاختصار بدون Flx عند التحميل: %key%`nالسبب: %e%
        }
    }
}

; تنفيذ الاختصارات بدون Flx مع التحقق من الشرط
ExecuteNoFlxHotkeyConditional:
    global NoFlxHotkeys, HotkeyConditions
    keyPressed := A_ThisHotkey
    WinGet, activeExe, ProcessName, A
    currentWinCondition := activeExe ? "ahk_exe " . activeExe : ""
    fullKeyWithCondition := keyPressed . (currentWinCondition ? "|" . currentWinCondition : "")
    fullKeyDefault := keyPressed

    ; التحقق من وجود الاختصار مع الشرط أو بدونه
    if (NoFlxHotkeys.HasKey(fullKeyWithCondition)) {
        action := NoFlxHotkeys[fullKeyWithCondition]
        ExecuteSingleAction(action)
    } else if (NoFlxHotkeys.HasKey(fullKeyDefault)) {
        action := NoFlxHotkeys[fullKeyDefault]
        ExecuteSingleAction(action)
    }
    ; إذا لم يتم تنفيذ أي إجراء، السماح للمفتاح بالمرور
    else {
        Send {%keyPressed%}
    }
return

; واجهة مؤشر وضع التسريع
Gui, SecureModeIndicator:+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x20
Gui, SecureModeIndicator:Color, 000000
WinSet, TransColor, 000000
Gui, SecureModeIndicator:Font, s12 cFFFFFF, Arial
Gui, SecureModeIndicator:Add, Text, BackgroundTrans, وضع التسريع
Gui, SecureModeIndicator:Show, x0 y0 w100 h30 NoActivate
WinSet, Transparent, 150
if (isSecureMode) {
    Gui, SecureModeIndicator:Show, NoActivate
    SetTimer, CheckSecureMode, %checkInterval%
} else {
    Gui, SecureModeIndicator:Hide
    SetTimer, CheckSecureMode, Off
}

;------------------ Hotkeys ------------------
; تعريف الاختصارات الثابتة باستخدام baseHotkey
try {
    Hotkey, %baseHotkey%, OpenInteractiveMode, On
    Hotkey, % baseHotkey " & D", ToggleSecureMode, On
    Hotkey, % baseHotkey " & ,", OpenSettings, On
    Hotkey, % baseHotkey " & =", OpenCustomHotkeysGUI, On
    Hotkey, % baseHotkey " & X", ExecuteCustomXHotkey, On
} catch e {
    MsgBox, 48, خطأ, فشل تعريف اختصارات Flx الأساسية:`nالسبب: %e%
}

; تعريف الاختصار الإضافي Ctrl+Win+=
^#+=::
OpenCustomHotkeysGUI()
return

;------------------ Functions ------------------

OpenInteractiveMode:
    global baseHotkey
    ; التحقق مما إذا كانت الواجهة مفتوحة بالفعل
    IfWinExist, قائمة الاختصارات
    {
        Gui, InteractiveMenu:Destroy
        return
    }
    ; إذا لم تكن مفتوحة، افتحها
    Gui, InteractiveMenu:Destroy  ; تدمير أي نسخة قديمة للتأكد
    Gui, InteractiveMenu:Color, 2D2D2D
    Gui, InteractiveMenu:Font, c000000 s10, Segoe UI
    Gui, InteractiveMenu:Add, Text, x10 y10 w300 h25 Center cFFD700, اختر اختصارًا
    Gui, InteractiveMenu:Add, ListBox, x10 y40 w300 h230 vSelectedHotkey gExecuteFromMenu, % GenerateHotkeyListForMenu()
    Gui, InteractiveMenu:Show, w320 h270, قائمة الاختصارات
return

GenerateHotkeyListForMenu() {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey
    list := ""
    ; CustomHotkeys
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, action, "بسيط (Flx)")
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, script, "متقدم (Flx)")
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, action, "بسيط (NoFlx)")
    }
    return RTrim(list, "|")
}

ExecuteFromMenu:
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey, scriptsDir
    Gui, InteractiveMenu:Submit, NoHide
    if (SelectedHotkey = "") {
        return  ; لا تفعل شيئًا إذا لم يتم اختيار شيء
    }
    SplitHotkey := StrSplit(SelectedHotkey, " - ")
    if (SplitHotkey.Length() < 2) {
        MsgBox, 48, خطأ, تنسيق الاختصار غير صالح.
        return
    }
    keyDisplay := SplitHotkey[1]
    actionOrScript := SplitHotkey[2]
    
    ; استخراج الشرط إذا كان موجودًا
    condition := ""
    if (InStr(actionOrScript, "(")) {
        conditionStart := InStr(actionOrScript, "(")
        conditionEnd := InStr(actionOrScript, ")",, -1)
        condition := SubStr(actionOrScript, conditionStart + 1, conditionEnd - conditionStart - 1)
        actionOrScript := Trim(SubStr(actionOrScript, 1, conditionStart - 1))
    }
    
    ; تحديد ما إذا كان الاختصار يستخدم Flx أم لا
    isFlx := InStr(keyDisplay, baseHotkey " & ")
    key := isFlx ? StrReplace(keyDisplay, baseHotkey " & ") : keyDisplay
    fullKey := StrReplace(key, ";", "VKBA") . (condition ? "|" . condition : "")

    ; إغلاق الواجهة أولاً
    Gui, InteractiveMenu:Destroy
    
    ; إضافة تأخير 70 مللي ثانية للسماح للنافذة السابقة بأن تصبح نشطة
    Sleep, 70

    ; تنفيذ الاختصار بناءً على مصدره
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
                MsgBox, 48, خطأ, فشل تشغيل السكربت: %fullPath%`nخطأ: %A_LastError%
            }
        } else {
            MsgBox, 48, خطأ, ملف السكربت غير موجود: %fullPath%
        }
    } else if (!isFlx && NoFlxHotkeys.HasKey(fullKey)) {
        action := NoFlxHotkeys[fullKey]
        ExecuteSingleAction(action)
    } else {
        MsgBox, 48, خطأ, الاختصار غير معرف: %fullKey%
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
    Gui, GuiSettings:Add, Text, x10 y10 w530 h30 Center cFFD700, إعدادات السكربت
    Gui, GuiSettings:Add, Text, x10 y50 w200 h25, المجلدات المراقبة (افصل بفواصل):
    Gui, GuiSettings:Add, Edit, x220 y50 w300 h25 vMonFolders c000000 Background424242, %monitoredFolders%
    Gui, GuiSettings:Add, Button, x530 y50 w80 h25 gBrowseFolders, تصفح
    Gui, GuiSettings:Add, Text, x10 y85 w200 h25, العمليات المراقبة (افصل بفواصل):
    Gui, GuiSettings:Add, Edit, x220 y85 w300 h25 vProcNames c000000 Background424242, %processNames%
    Gui, GuiSettings:Add, Button, x530 y85 w80 h25 gBrowseProcesses, تصفح
    Gui, GuiSettings:Add, Text, x10 y120 w200 h25, فترة الفحص (بالملي ثانية):
    Gui, GuiSettings:Add, Edit, x220 y120 w300 h25 vChkInterval c000000 Background424242, %checkInterval%
    Gui, GuiSettings:Add, Button, x260 y165 w100 h30 gSaveSettings, حفظ
    Gui, GuiSettings:Add, Button, x370 y165 w100 h30 gCancelSettings, إلغاء
    Gui, GuiSettings:Font, cA0A0A0 s8
    Gui, GuiSettings:Add, Text, x10 y205 w620 h20 Center, استخدم الفواصل لفصل المجلدات والعمليات، أو زر التصفح للإضافة
    Gui, GuiSettings:Show, w630 h230, إعدادات السكربت
}

BrowseFolders:
    Gui, GuiSettings:Submit, NoHide
    FileSelectFolder, selectedFolder, , 3, اختر مجلدًا للمراقبة
    if (selectedFolder != "") {
        if (MonFolders = "")
            GuiControl, GuiSettings:, MonFolders, %selectedFolder%
        else
            GuiControl, GuiSettings:, MonFolders, %MonFolders%,%selectedFolder%
    }
return

BrowseProcesses:
    Gui, GuiSettings:Submit, NoHide
    FileSelectFile, selectedFile, 3, , اختر عملية للمراقبة, Executable Files (*.exe)
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
        MsgBox, 48, تحذير, يجب أن تكون فترة الفحص عددًا صحيحًا.
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
    Gui, CustomHotkeys:Add, Tab3, x0 y0 w650 h400, أساسي|متقدم
    Gui, CustomHotkeys:Tab, أساسي
    Gui, CustomHotkeys:Add, Text, x20 y50 w610 h30 Center cFFD700, إدارة الاختصارات بسهولة
    Gui, CustomHotkeys:Add, Text, x20 y90 w150 h25, المفتاح (مثل T أو \):
    Gui, CustomHotkeys:Add, Edit, x180 y90 w150 h25 vHotkeyKey c000000 Background424242,
    Gui, CustomHotkeys:Add, Text, x340 y90 w300 h50 cA0A0A0, يمكن استخدام رموز مثل = أو , أيضاً
    Gui, CustomHotkeys:Add, CheckBox, x20 y120 w60 h25 vUseFlx Checked, Flx
    Gui, CustomHotkeys:Add, CheckBox, x90 y120 w60 h25 vUseCtrl, Ctrl
    Gui, CustomHotkeys:Add, CheckBox, x160 y120 w60 h25 vUseShift, Shift
    Gui, CustomHotkeys:Add, CheckBox, x230 y120 w60 h25 vUseAlt, Alt
    Gui, CustomHotkeys:Add, CheckBox, x300 y120 w60 h25 vUseWin, Win
    Gui, CustomHotkeys:Add, Text, x20 y150 w150 h25, النافذة النشطة (اختياري):
    Gui, CustomHotkeys:Add, Edit, x180 y150 w300 h25 vWinCondition c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x490 y150 w80 h25 gBrowseWinCondition, تصفح
    Gui, CustomHotkeys:Add, Button, x20 y180 w150 h40 gAddAppHotkey, فتح تطبيق
    Gui, CustomHotkeys:Add, Button, x20 y230 w150 h40 gOpenTextInput, إرسال نص
    Gui, CustomHotkeys:Add, Button, x340 y180 w150 h40 gOpenFileHotkey, فتح ملف 
    Gui, CustomHotkeys:Add, Button, x180 y180 w150 h40 gOpenFolderHotkey, فتح مجلد
    Gui, CustomHotkeys:Add, Button, x180 y230 w150 h40 gOpenHotkeyManagerGUI, إدارة الاختصارات
    Gui, CustomHotkeys:Tab, متقدم
    Gui, CustomHotkeys:Add, Text, x20 y50 w610 h30 Center cFFD700, خيارات متقدمة
    Gui, CustomHotkeys:Add, Text, x20 y75 w150 h50, زر الFlx (مثل SC056):
    Gui, CustomHotkeys:Add, Edit, x180 y90 w150 h25 vBaseHotkeyInput c000000 Background424242, %baseHotkey%
    Gui, CustomHotkeys:Add, Button, x340 y90 w150 h25 gSaveBaseHotkey, حفظ زر الFlx
    Gui, CustomHotkeys:Add, Text, x20 y110 w150 h50, المفتاح (مثل T) او اضغط اكتشاف:
    Gui, CustomHotkeys:Add, Edit, x180 y120 w150 h25 vAdvHotkeyKey c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x340 y120 w100 h25 gDetectKey, اكتشاف المفتاح
    Gui, CustomHotkeys:Add, Text, x450 y120 w190 h50 cA0A0A0, يمكن استخدام رموز مثل = أو , أيضاً
    Gui, CustomHotkeys:Add, CheckBox, x20 y150 w60 h25 vAdvUseFlx Checked, Flx
    Gui, CustomHotkeys:Add, CheckBox, x90 y150 w60 h25 vAdvUseCtrl, Ctrl
    Gui, CustomHotkeys:Add, CheckBox, x160 y150 w60 h25 vAdvUseShift, Shift
    Gui, CustomHotkeys:Add, CheckBox, x230 y150 w60 h25 vAdvUseAlt, Alt
    Gui, CustomHotkeys:Add, CheckBox, x300 y150 w60 h25 vAdvUseWin, Win
    Gui, CustomHotkeys:Add, Text, x20 y180 w150 h25, النافذة النشطة (اختياري):
    Gui, CustomHotkeys:Add, Edit, x180 y180 w300 h25 vAdvWinCondition c000000 Background424242,
    Gui, CustomHotkeys:Add, Button, x490 y180 w80 h25 gBrowseWinConditionAdv, تصفح
    Gui, CustomHotkeys:Add, Text, x20 y210 w150 h25, السكربت (كود AHK كامل):
    Gui, CustomHotkeys:Add, Edit, x180 y210 w300 h80 vAdvHotkeyScript c000000 Background424242 Multi,
    Gui, CustomHotkeys:Add, Button, x490 y210 w80 h25 gBrowseAdvAction, تصفح
    Gui, CustomHotkeys:Add, Button, x180 y300 w100 h30 gAddAdvHotkey, إضافة
    Gui, CustomHotkeys:Add, Button, x340 y300 w100 h30 gOpenHotkeyManagerGUI, إدارة الإختصارات
    Gui, CustomHotkeys:Show, w650 h400, إدارة الاختصارات
}

BrowseWinCondition:
BrowseWinConditionAdv:
    Gui, CustomHotkeys:Submit, NoHide
    MsgBox, 64, تعليمات, انقر على النافذة التي تريد اختيارها بعد الضغط على "موافق". سيتم إخفاء الواجهة مؤقتًا للسماح بالاختيار.
    Gui, CustomHotkeys:Hide
    KeyWait, LButton, D T10
    if (ErrorLevel) {
        MsgBox, 48, خطأ, لم يتم النقر على أي نافذة خلال 10 ثوانٍ.
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
        MsgBox, 48, خطأ, لم يتم العثور على عملية مرتبطة بالنافذة المختارة.
    }
    Gui, CustomHotkeys:Show
return

SaveBaseHotkey:
    global baseHotkey, iniFile, CustomHotkeys, AdvancedScripts
    Gui, CustomHotkeys:Submit, NoHide
    if (BaseHotkeyInput = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح أساسي.
        return
    }
    oldBaseHotkey := baseHotkey
    baseHotkey := BaseHotkeyInput
    IniWrite, %baseHotkey%, %iniFile%, HotkeySettings, BaseKey
    ReloadHotkeys(oldBaseHotkey)
    MsgBox, 64, تم, تم تغيير زر الFlx إلى %baseHotkey% وإعادة تعريف الاختصارات بنجاح!
return

ReloadHotkeys(oldBaseHotkey) {
    global baseHotkey, CustomHotkeys, AdvancedScripts, NoFlxHotkeys
    ; تعطيل الاختصارات القديمة لـ CustomHotkeys و AdvancedScripts
    for fullKey in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % oldBaseHotkey " & " . baseKey, Off
        } catch e {
            ; تجاهل الأخطاء إذا لم يكن معرفًا
        }
    }
    for fullKey in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % oldBaseHotkey " & " . baseKey, Off
        } catch e {
            ; تجاهل الأخطاء
        }
    }
    ; تعطيل الاختصارات الثابتة القديمة
    try {
        Hotkey, %oldBaseHotkey%, Off
        Hotkey, % oldBaseHotkey " & D", Off
        Hotkey, % oldBaseHotkey " & ,", Off
        Hotkey, % oldBaseHotkey " & =", Off
        Hotkey, % oldBaseHotkey " & X", Off
    } catch e {
        ; تجاهل الأخطاء
    }
    ; تفعيل الاختصارات الجديدة لـ CustomHotkeys و AdvancedScripts
    for fullKey in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
        } catch e {
            MsgBox, 48, خطأ, فشل تعريف الاختصار: %baseHotkey% & %baseKey%`nالسبب: %e%
        }
    }
    for fullKey in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On
        } catch e {
            MsgBox, 48, خطأ, فشل تعريف السكربت المتقدم: %baseHotkey% & %baseKey%`nالسبب: %e%
        }
    }
    ; تفعيل الاختصارات الثابتة الجديدة
    try {
        Hotkey, %baseHotkey%, OpenInteractiveMode, On
        Hotkey, % baseHotkey " & D", ToggleSecureMode, On
        Hotkey, % baseHotkey " & ,", OpenSettings, On
        Hotkey, % baseHotkey " & =", OpenCustomHotkeysGUI, On
        Hotkey, % baseHotkey " & X", ExecuteCustomXHotkey, On
    } catch e {
        MsgBox, 48, خطأ, فشل إعادة تعريف الاختصارات الثابتة: %e%
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
        MsgBox, 48, خطأ, لم يتم الضغط على أي مفتاح خلال 10 ثوانٍ.
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
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (Flx)`n"
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . script . " (Flx)`n"
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (NoFlx)`n"
    }
    return hotkeyList
}

AddAppHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    }
    ; نافذة اختيار طريقة الإضافة
    Gui, AppInput:Destroy
    Gui, AppInput:Color, 2D2D2D
    Gui, AppInput:Font, cFFFFFF s10, Segoe UI
    Gui, AppInput:Add, Text, x20 y20 w300 h25, اختر طريقة إضافة التطبيق:
    Gui, AppInput:Add, Button, x20 y50 w150 h30 gBrowseAppFile, اختيار ملف تطبيق
    Gui, AppInput:Add, Button, x180 y50 w150 h30 gManualAppInput, إدخال أمر يدوي
    Gui, AppInput:Add, Button, x100 y90 w100 h30 gCancelAppInput, إلغاء
    Gui, AppInput:Show, w340 h130, إضافة تطبيق للاختصار
return

BrowseAppFile:
    Gui, AppInput:Destroy
    FileSelectFile, selectedFile, 3, , اختر تطبيقًا لفتحه, Executable Files (*.exe)
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
                MsgBox, 64, تم, تمت إضافة الاختصار بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
            }
        }
    }
return

ManualAppInput:
    Gui, AppInput:Destroy
    Gui, ManualInput:Destroy
    Gui, ManualInput:Color, 2D2D2D
    Gui, ManualInput:Font, cFFFFFF s10, Segoe UI
    Gui, ManualInput:Add, Text, x20 y20 w300 h25, أدخل أمر التشغيل (مثل explorer.exe shell:...):
    Gui, ManualInput:Add, Edit, x20 y50 w400 h25 vManualCommand c000000 Background424242,
    Gui, ManualInput:Add, Button, x170 y80 w100 h30 gSaveManualCommand, حفظ
    Gui, ManualInput:Add, Button, x280 y80 w100 h30 gCancelManualInput, إلغاء
    Gui, ManualInput:Show, w440 h120, إدخال أمر يدوي
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
                MsgBox, 64, تم, تمت إضافة الاختصار بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
                Gui, ManualInput:Destroy
            }
        }
    } else {
        MsgBox, 48, خطأ, يرجى إدخال أمر تشغيل.
    }
return

CancelManualInput:
    Gui, ManualInput:Destroy
return

CancelAppInput:
    Gui, AppInput:Destroy
return
    FileSelectFile, selectedFile, 3, , اختر تطبيقًا لفتحه, Executable Files (*.exe)
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
                MsgBox, 64, تم, تمت إضافة الاختصار بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
            }
        }
    }
return

OpenTextInput:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    }
    Gui, TextInput:Destroy
    Gui, TextInput:Color, 2D2D2D
    Gui, TextInput:Font, cFFFFFF s10, Segoe UI
    Gui, TextInput:Add, Text, x20 y20 w150 h25, أدخل النص لإرساله:
    Gui, TextInput:Add, Edit, x180 y20 w300 h25 vTextToSend c000000 Background424242,
    Gui, TextInput:Add, Text, x20 y50 w460 h20 cA0A0A0, ملاحظة: يمكنك أيضًا إدخال إيموجي مثل 😊 أو 👍 هنا
    Gui, TextInput:Add, Button, x180 y80 w100 h30 gSaveTextHotkey, حفظ
    Gui, TextInput:Add, Button, x290 y80 w100 h30 gCancelTextInput, إلغاء
    Gui, TextInput:Show, w500 h120, إرسال نص للاختصار
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
                MsgBox, 64, تم, تمت إضافة الاختصار بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
                Gui, TextInput:Destroy
            }
        }
    } else {
        MsgBox, 48, خطأ, يرجى إدخال نص.
        Gui, TextInput:Destroy
    }
return

CancelTextInput:
    Gui, TextInput:Destroy
return

OpenFileHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    }
    FileSelectFile, selectedFile, 3, , اختر ملفًا لفتحه, All Files (*.*)
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
                MsgBox, 64, تم, تمت إضافة الاختصار لفتح الملف بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx لفتح الملف بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
            }
        }
    }
return

OpenFolderHotkey:
    Gui, CustomHotkeys:Submit, NoHide
    if (HotkeyKey = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح.
        return
    }
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
    if (UseFlx && (CustomHotkeys.HasKey(fullKey) || AdvancedScripts.HasKey(fullKey))) {
        oldAction := CustomHotkeys[fullKey] ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    } else if (!UseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %WinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    }
    Gui, FolderInput:Destroy
    Gui, FolderInput:Color, 2D2D2D
    Gui, FolderInput:Font, cFFFFFF s10, Segoe UI
    Gui, FolderInput:Add, Text, x20 y20 w150 h25, أدخل مسار المجلد:
    Gui, FolderInput:Add, Edit, x180 y20 w300 h25 vFolderPath c000000 Background424242,
    Gui, FolderInput:Add, Button, x490 y20 w80 h25 gBrowseFolder, تصفح
    Gui, FolderInput:Add, Button, x180 y60 w100 h30 gSaveFolderHotkey, حفظ
    Gui, FolderInput:Add, Button, x290 y60 w100 h30 gCancelFolderInput, إلغاء
    Gui, FolderInput:Show, w600 h100, فتح مجلد للاختصار
return

BrowseFolder:
    Gui, FolderInput:Submit, NoHide
    FileSelectFolder, selectedFolder, , 3, اختر مجلدًا لفتحه
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
                MsgBox, 64, تم, تمت إضافة الاختصار بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار.
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
                MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
            } else {
                MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
                Gui, FolderInput:Destroy
            }
        }
    } else {
        MsgBox, 48, خطأ, يرجى إدخال مسار مجلد أو اختيار واحد.
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
        MsgBox, 48, خطأ, يرجى إدخال مفتاح وسكربت.
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
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %AdvWinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
    } else if (!AdvUseFlx && NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %AdvWinCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
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
            actionText := isEdit ? "تعديل" : "إضافة"
            MsgBox, 64, تم, تمت %actionText% السكربت المتقدم بنجاح!
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
            MsgBox, 64, تم, تمت إضافة الاختصار بدون Flx بنجاح!
        } else {
            MsgBox, 48, خطأ, فشل إضافة الاختصار بدون Flx.
        }
    }
return

BrowseAdvAction:
    Gui, CustomHotkeys:Submit, NoHide
    FileSelectFile, selectedFile, 3, , اختر ملف سكربت AHK, AutoHotkey Scripts (*.ahk)
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
    Gui, HotkeyManager:Add, Text, x20 y20 w540 h25, قائمة الاختصارات:
    Gui, HotkeyManager:Add, Edit, x20 y50 w440 h25 vSearchTerm gSearchHotkeys c000000 Background424242,
    Gui, HotkeyManager:Add, Button, x470 y50 w90 h25 gSearchHotkeys, بحث
    Gui, HotkeyManager:Add, ListView, x20 y80 w540 h200 vHotkeyList gHotkeyListEvent -Multi +Grid +LV0x10000 Background2D2D2D, المفتاح|النافذة|الإجراء|النوع
    Gui, HotkeyManager:Add, Button, x130 y290 w100 h30 gDeleteSelectedHotkeys, حذف المحدد
    Gui, HotkeyManager:Add, Button, x260 y290 w100 h30 gEditSelectedHotkey, تعديل
    Gui, HotkeyManager:Add, Button, x390 y290 w100 h30 gCancelHotkeyManager, إلغاء
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, action, "بسيط (Flx)")
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, script, "متقدم (Flx)")
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        LV_Add("", key, winCondition, action, "بسيط (NoFlx)")
    }
    LV_ModifyCol(1, 50)
    LV_ModifyCol(2, 100)
    LV_ModifyCol(3, 340)
    LV_ModifyCol(4, 50)
    Gui, HotkeyManager:Show, w650 h330, إدارة الاختصارات
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
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(action, SearchTerm)) {
            LV_Add("", key, winCondition, action, "بسيط (Flx)")
        }
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(script, SearchTerm)) {
            LV_Add("", key, winCondition, script, "متقدم (Flx)")
        }
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        winCondition := SplitKeyCond.Length() > 1 ? SplitKeyCond[2] : "غير محدد"
        if (SearchTerm = "" || InStr(key, SearchTerm) || InStr(winCondition, SearchTerm) || InStr(action, SearchTerm)) {
            LV_Add("", key, winCondition, action, "بسيط (NoFlx)")
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
            fullSelectedKey := StrReplace(selectedKey, ";", "VKBA") . (selectedWinCondition != "غير محدد" ? "|" . selectedWinCondition : "")
            Gosub, EditSelectedHotkey
        }
    }
return

DeleteFromEditHotkey:
    MsgBox, 4, تأكيد, هل تريد حذف الاختصار "%selectedKey%" مع شرط النافذة "%selectedWinCondition%"؟
    IfMsgBox, Yes
    {
        if (InStr(type, "Flx")) {
            if (InStr(type, "بسيط")) {
                DeleteHotkeyAction(fullSelectedKey)
            } else {
                DeleteAdvancedScript(fullSelectedKey)
            }
        } else {
            DeleteNoFlxHotkey(fullSelectedKey)
        }
        Gui, EditHotkey:Destroy
        Gosub, OpenHotkeyManagerGUI
        MsgBox, 64, تم, تم حذف الاختصار بنجاح!
    }
return

EditSelectedHotkey:
    row := LV_GetNext(0)
    if (!row) {
        MsgBox, 48, خطأ, يرجى تحديد اختصار لتعديله.
        return
    }
    LV_GetText(selectedKey, row, 1)
    LV_GetText(selectedWinCondition, row, 2)
    LV_GetText(actionOrScript, row, 3)
    LV_GetText(type, row, 4)
    fullSelectedKey := StrReplace(selectedKey, ";", "VKBA") . (selectedWinCondition != "غير محدد" ? "|" . selectedWinCondition : "")
    baseKey := RegExReplace(selectedKey, "[+^!#]")
    Gui, EditHotkey:Destroy
    Gui, EditHotkey:Color, 2D2D2D
    Gui, EditHotkey:Font, cFFFFFF s10, Segoe UI
    Gui, EditHotkey:Add, Text, x20 y20 w150 h25, المفتاح:
    Gui, EditHotkey:Add, Edit, x180 y20 w150 h25 vNewKey c000000 Background424242, %baseKey%
    Gui, EditHotkey:Add, CheckBox, x20 y50 w60 h25 vUseFlx Checked, Flx
    Gui, EditHotkey:Add, CheckBox, x90 y50 w60 h25 vUseCtrl, Ctrl
    Gui, EditHotkey:Add, CheckBox, x160 y50 w60 h25 vUseShift, Shift
    Gui, EditHotkey:Add, CheckBox, x230 y50 w60 h25 vUseAlt, Alt
    Gui, EditHotkey:Add, CheckBox, x300 y50 w60 h25 vUseWin, Win
    Gui, EditHotkey:Add, Text, x20 y80 w150 h25, النافذة النشطة (اختياري):
    Gui, EditHotkey:Add, Edit, x180 y80 w300 h25 vNewWinCondition c000000 Background424242, % (selectedWinCondition != "غير محدد" ? selectedWinCondition : "")
    Gui, EditHotkey:Add, Button, x490 y80 w80 h25 gBrowseWinConditionEdit, تصفح
    if (InStr(type, "بسيط")) {
        Gui, EditHotkey:Add, Text, x20 y110 w150 h25, الإجراء:
        Gui, EditHotkey:Add, Edit, x180 y110 w300 h25 vNewAction c000000 Background424242, %actionOrScript%
    } else {
        Gui, EditHotkey:Add, Text, x20 y110 w150 h25, السكربت:
        Gui, EditHotkey:Add, Edit, x180 y110 w300 h100 vNewAction c000000 Background424242 Multi, %actionOrScript%
        fullPath := A_ScriptDir "\" actionOrScript
        if FileExist(fullPath) {
            FileRead, scriptContent, %fullPath%
            GuiControl, EditHotkey:, NewAction, %scriptContent%
        }
    }
    Gui, EditHotkey:Add, Button, x180 y230 w100 h30 gSaveEditedHotkey, حفظ
    Gui, EditHotkey:Add, Button, x290 y230 w100 h30 gCancelEditHotkey, إلغاء
    Gui, EditHotkey:Add, Button, x400 y230 w100 h30 gDeleteFromEditHotkey, حذف
    if (InStr(type, "متقدم")) {
        Gui, EditHotkey:Add, Button, x180 y270 w100 h30 gOpenScriptLocation, فتح الموقع
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
    Gui, EditHotkey:Show, w510 h310, تعديل الاختصار
return

BrowseWinConditionEdit:
    Gui, EditHotkey:Submit, NoHide
    MsgBox, 64, تعليمات, انقر على النافذة التي تريد اختيارها بعد الضغط على "موافق". سيتم إخفاء الواجهة مؤقتًا للسماح بالاختيار.
    Gui, EditHotkey:Hide
    KeyWait, LButton, D T10
    if (ErrorLevel) {
        MsgBox, 48, خطأ, لم يتم النقر على أي نافذة خلال 10 ثوانٍ.
        Gui, EditHotkey:Show
        return
    }
    MouseGetPos,,, windowID
    WinGet, activeExe, ProcessName, ahk_id %windowID%
    if (activeExe) {
        condition := "ahk_exe " . activeExe
        GuiControl, EditHotkey:, NewWinCondition, %condition%
    } else {
        MsgBox, 48, خطأ, لم يتم العثور على عملية مرتبطة بالنافذة المختارة.
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
        MsgBox, 48, خطأ, لا يمكن العثور على موقع السكربت.
    }
return

SaveEditedHotkey:
    Gui, EditHotkey:Submit
    if (NewKey = "") {
        MsgBox, 48, خطأ, يرجى إدخال مفتاح.
        Gui, EditHotkey:Destroy
        return
    }
    newKey := StrReplace(NewKey, ";", "VKBA")
    modifierPrefix := (UseFlx ? "" : "") . (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    fullNewKey := modifierPrefix . newKey . (NewWinCondition ? "|" . NewWinCondition : "")
    if (fullNewKey != fullSelectedKey) {
        if (UseFlx && (CustomHotkeys.HasKey(fullNewKey) || AdvancedScripts.HasKey(fullNewKey))) {
            oldAction := CustomHotkeys[fullNewKey] ? CustomHotkeys[fullNewKey] : AdvancedScripts[fullNewKey]
            MsgBox, 4, تحذير, المفتاح %fullNewKey% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
            IfMsgBox, No
                return
        } else if (!UseFlx && NoFlxHotkeys.HasKey(fullNewKey)) {
            oldAction := NoFlxHotkeys[fullNewKey]
            MsgBox, 4, تحذير, المفتاح %fullNewKey% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
            IfMsgBox, No
                return
        }
    }
    if (InStr(type, "Flx")) {
        if (InStr(type, "بسيط")) {
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
            if (InStr(type, "بسيط")) {
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
    MsgBox, 64, تم, تم تعديل الاختصار بنجاح!
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
        fullKey := StrReplace(key, ";", "VKBA") . (winCondition != "غير محدد" ? "|" . winCondition : "")
        selectedRows.Push({Key: fullKey, Type: type})
    }
    count := selectedRows.Length()
    if (count = 0) {
        MsgBox, 48, خطأ, يرجى تحديد اختصار واحد على الأقل.
        return
    }
    MsgBox, 4, تأكيد, هل تريد حذف %count% عناصر محددة؟
    IfMsgBox, Yes
    {
        for index, item in selectedRows {
            if (InStr(item.Type, "NoFlx")) {
                DeleteNoFlxHotkey(item.Key)
            } else if (InStr(item.Type, "بسيط")) {
                DeleteHotkeyAction(item.Key)
            } else if (InStr(item.Type, "متقدم")) {
                DeleteAdvancedScript(item.Key)
            }
        }
        Gosub, OpenHotkeyManagerGUI
        MsgBox, 64, تم, تم حذف العناصر المحددة بنجاح!
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
        ; تجاهل الأخطاء إذا لم يكن الاختصار معرفًا
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
        ; تجاهل الأخطاء
    }
}

DeleteNoFlxHotkey(fullKey) {
    global iniFile, NoFlxHotkeys, HotkeyConditions
    IniDelete, %iniFile%, NoFlx, %fullKey%
    SplitKeyCond := StrSplit(fullKey, "|")
    key := SplitKeyCond[1]
    NoFlxHotkeys.Delete(fullKey)
    if (HotkeyConditions.HasKey(key)) {
        HotkeyConditions[key].Delete(fullKey)
        if (HotkeyConditions[key].Count() = 0) {
            HotkeyConditions.Delete(key)
            try {
                Hotkey, %key%, Off
            } catch e {
                ; تجاهل الأخطاء إذا لم يكن الاختصار معرفًا
            }
        }
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
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %winCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
        DeleteHotkeyAction(fullKey)
    } else if (AdvancedScripts.HasKey(fullKey)) {
        oldScript := AdvancedScripts[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %winCondition% مستخدم بالفعل كسكربت متقدم:`n%oldScript%`nهل تريد استبداله؟
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
        MsgBox, 48, خطأ, فشل تعريف الاختصار: %baseHotkey% & %baseKey%`nالسبب: %e%
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
    InputBox, scriptName, إدخال اسم السكربت, أدخل اسمًا للسكربت (بدون .ahk):,, 300, 150,,,, %defaultValue%
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
            MsgBox, 48, خطأ, اسم السكربت %scriptName% مستخدم بالفعل لاختصار آخر.`nيرجى اختيار اسم مختلف.
            return 0
        }
    }
    FileDelete, %fullScriptPath%
    FileAppend, %script%, %fullScriptPath%, UTF-8
    if (ErrorLevel) {
        MsgBox, 48, خطأ, فشل حفظ السكربت في: %fullScriptPath%
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
        MsgBox, 48, خطأ, فشل تعريف السكربت المتقدم: %baseHotkey% & %baseKey%`nالسبب: %e%
        return 0
    }
    return 1
}

AddNoFlxHotkey(key, action, useCtrl := 0, useShift := 0, useAlt := 0, useWin := 0, winCondition := "") {
    global iniFile, NoFlxHotkeys, HotkeyConditions
    if (key = ";") {
        key := "VKBA"
    } else {
        key := Format("{:U}", key)
    }
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    if (NoFlxHotkeys.HasKey(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        MsgBox, 4, تحذير, المفتاح %key% مع شرط النافذة %winCondition% مستخدم بالفعل:`n%oldAction%`nهل تريد استبداله؟
        IfMsgBox, No
            return
        DeleteNoFlxHotkey(fullKey)
    }
    IniWrite, %action%, %iniFile%, NoFlx, %fullKey%
    NoFlxHotkeys[fullKey] := action
    if (!HotkeyConditions.HasKey(modifierPrefix . key)) {
        HotkeyConditions[modifierPrefix . key] := {}
    }
    HotkeyConditions[modifierPrefix . key][fullKey] := winCondition
    try {
        if (winCondition) {
            Hotkey, IfWinActive, %winCondition%
            Hotkey, % modifierPrefix . key, ExecuteNoFlxHotkeyConditional, On
            Hotkey, IfWinActive
        } else {
            Hotkey, % modifierPrefix . key, ExecuteNoFlxHotkeyConditional, On
        }
    } catch e {
        MsgBox, 48, خطأ, فشل تعريف الاختصار بدون Flx: %fullKey%`nالسبب: %e%
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
                MsgBox, 48, خطأ, فشل تشغيل السكربت: %fullPath%`nخطأ: %A_LastError%
            }
        } else {
            MsgBox, 48, خطأ, ملف السكربت غير موجود: %fullPath%
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
                MsgBox, 48, خطأ, فشل تشغيل السكربت: %fullPath%`nخطأ: %A_LastError%
            }
        } else {
            MsgBox, 48, خطأ, ملف السكربت غير موجود: %fullPath%
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
        SplitPath, command, fileName, dir
        if (fileName = "") {  ; إذا كان مجلدًا
            Run, explorer.exe "%command%", , UseErrorLevel
            if (A_LastError) {
                MsgBox, 48, خطأ, فشل فتح المجلد: %command%`nخطأ: %A_LastError%
            }
            return
        }

        ; الحصول على المسار الكامل للتطبيق
        fullPath := command

        ; التحقق من النافذة المركزة فقط
        WinGet, activeFullPath, ProcessPath, A  ; المسار الكامل للنافذة النشطة
        WinGet, activeID, ID, A
        if (activeFullPath = fullPath) {  ; إذا كانت النافذة المركزة هي التطبيق المطلوب
            WinMinimize, ahk_id %activeID%
            return
        }

        ; البحث عن النافذة إذا لم تكن مركزة
        WinGet, processList, List
        found := false
        targetID := ""
        Loop, %processList% {
            thisID := processList%A_Index%
            WinGet, thisPath, ProcessPath, ahk_id %thisID%
            if (thisPath = fullPath) {  ; إذا تطابق المسار الكامل
                found := true
                targetID := thisID
                break  ; نوقف البحث بمجرد العثور على النافذة
            }
        }

        if (found) {  ; إذا وجدنا النافذة ولكنها ليست مركزة
            WinGet, thisState, MinMax, ahk_id %targetID%
            if (thisState = -1) {  ; إذا كانت مصغرة
                WinRestore, ahk_id %targetID%
            }
            WinActivate, ahk_id %targetID%  ; نركز على النافذة
        } else {  ; إذا لم يتم العثور على النافذة، نشغل التطبيق
            Run, %command%, , UseErrorLevel
            if (A_LastError) {
                MsgBox, 48, خطأ, فشل تشغيل: %command%`nخطأ: %A_LastError%
            }
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
                MsgBox, 48, خطأ, فشل تنفيذ الأمر: %action%`nخطأ: %A_LastError%
            }
        } catch e {
            MsgBox, 48, خطأ, الأمر غير مدعوم أو غير صالح: %action%`nالسبب: %e%
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
        Run, "F:\D old\أبو هدهود\Fundamentals of Programming #Course 1\الدرس السادس_ اجزاء البايت ومصطلحاتها(360P).mp4"
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