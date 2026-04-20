#Requires AutoHotkey v2.0
#SingleInstance Force
;------------------ Global Settings ------------------
iniFile := A_ScriptDir . "\Flx_Settings.ini"
scriptsDir := A_ScriptDir . "\Scripts"
if (!FileExist(scriptsDir)) {
    DirCreate(scriptsDir)
}
HotkeyConditions := Map() ; لتتبع شروط NoFlxHotkeys
; IniRead syntax: IniRead(Filename, Section, Key, Default)
monitoredFolders := IniRead(iniFile, "Settings", "MonitoredFolders", "F:\Anime,F:\Movies")
monitoredFoldersWithSub := IniRead(iniFile, "Settings", "MonitoredFoldersWithSub", "F:\Anime")
excludedFolders := IniRead(iniFile, "Settings", "ExcludedFolders", " ") ; A_Space is " "
processNames := IniRead(iniFile, "Settings", "ProcessNames", "telegram.exe")
checkInterval := IniRead(iniFile, "Settings", "CheckInterval", 1000)
isSecureMode := IniRead(iniFile, "Settings", "IsSecureMode", 0)
baseHotkey := IniRead(iniFile, "HotkeySettings", "BaseKey", "SC056")
global baseHotkey
InitSecureModeIndicator()
; التحقق من صلاحية baseHotkey
if (!baseHotkey || baseHotkey == "ERROR") {
    ; InputBox syntax: InputBox(Prompt, Title, Options)
    result := InputBox("أدخل رمز المفتاح الأساسي (مثل SC056 أو SC029):", "إدخال زر Flx", "W300 H150 DefaultSC056")
    if (result.result != "OK" || result.Value == "") {
        MsgBox("لم يتم إدخال زر Flx صالح. سيتم إنهاء السكربت.", "خطأ", "IconStop")
        ExitApp()
    }
    baseHotkey := result.Value
    IniWrite(baseHotkey, iniFile, "HotkeySettings", "BaseKey")
}
quoteChar := Chr(34)
; تحميل الاختصارات البسيطة مع شروط النافذة
CustomHotkeys := Map()
customKeys := IniRead(iniFile, "CustomHotkeys", "")
if (customKeys == "ERROR") {
    customKeys := ""
}
; Loop, Parse, Var, Delimiters -> Loop Parse, Var, Delimiters
Loop Parse, customKeys, "`n"
{
    if (A_LoopField == "") {
        continue
    }
    ; KeyValue := StrSplit(A_LoopField, "=") -> KeyValue := StrSplit(A_LoopField, "=")
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, quoteChar, "")
        ; SubStr(A_LoopField, InStr(A_LoopField, "=") + 1)
        action := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (CustomHotkeys.Has(fullKey)) { ; .HasKey() -> .Has()
            continue
        }
        CustomHotkeys[fullKey] := action
        baseKey := RegExReplace(key, "[+^!#]")
        try {
            ; Hotkey, % baseHotkey " & " . baseKey, ExecuteHotkey, On -> Hotkey(KeyName, Callback, Options)
            Hotkey(baseHotkey . " & " . baseKey, ExecuteHotkey, "On")
        } catch Error as e {
            MsgBox("فشل تعريف الاختصار عند التحميل: " . baseHotkey . " & " . baseKey . "`nالسبب: " . e.message, "خطأ", "IconStop")
        }
    }
}
; تحميل السكربتات المتقدمة مع شروط النافذة
AdvancedScripts := Map()
advScripts := IniRead(iniFile, "AdvancedScripts", "")
if (advScripts == "ERROR") {
    advScripts := ""
}
Loop Parse, advScripts, "`n"
{
    if (A_LoopField == "") {
        continue
    }
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, quoteChar, "")
        scriptPath := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (AdvancedScripts.Has(fullKey)) {
            continue
        }
        fullPath := A_ScriptDir . "\" . scriptPath
        if FileExist(fullPath) {
            AdvancedScripts[fullKey] := scriptPath
            baseKey := RegExReplace(key, "[+^!#]")
            try {
                Hotkey(baseHotkey . " & " . baseKey, ExecuteHotkey, "On")
            } catch Error as e {
                MsgBox("فشل تعريف السكربت المتقدم عند التحميل: " . baseHotkey . " & " . baseKey . "`nالسبب: " . e.message, "خطأ", "IconStop")
            }
        } else {
            MsgBox("ملف السكربت غير موجود: " . scriptPath, "تحذير", "IconExclamation")
        }
    }
}
; تحميل الاختصارات بدون Flx مع شروط النافذة
NoFlxHotkeys := Map()
HotkeyConditions := Map()
noFlxKeys := IniRead(iniFile, "NoFlx", "")
if (noFlxKeys == "ERROR") {
    noFlxKeys := ""
}
Loop Parse, noFlxKeys, "`n"
{
    if (A_LoopField == "") {
        continue
    }
    KeyValue := StrSplit(A_LoopField, "=")
    if (KeyValue.Length >= 2) {
        keyCond := Trim(KeyValue[1])
        keyCond := StrReplace(keyCond, quoteChar, "")
        action := Trim(SubStr(A_LoopField, InStr(A_LoopField, "=") + 1))
        if (InStr(keyCond, ";")) {
            keyCond := StrReplace(keyCond, ";", "VKBA")
        }
        SplitKeyCond := StrSplit(keyCond, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        fullKey := key . (winCondition ? "|" . winCondition : "")
        if (NoFlxHotkeys.Has(fullKey)) {
            continue
        }
        NoFlxHotkeys[fullKey] := action
        if (!HotkeyConditions.Has(key)) {
            HotkeyConditions[key] := Map()
            try {
                Hotkey(key, ExecuteNoFlxHotkeyConditional, "On")
            } catch Error as e {
                MsgBox("فشل تعريف الاختصار بدون Flx عند التحميل: " . key . "`nالسبب: " . e.message, "خطأ", "IconStop")
            }
        }
        HotkeyConditions[key][fullKey] := winCondition
    }
}
; تنفيذ الاختصارات بدون Flx مع التحقق من الشرط
ExecuteNoFlxHotkeyConditional() {
    global NoFlxHotkeys, HotkeyConditions, scriptsDir
    keyPressed := A_ThisHotkey
    ; WinGet, activeExe, ProcessName, A -> activeExe := WinGetProcessName("A")
    activeExe := WinGetProcessName("A")
    currentWinCondition := activeExe ? "ahk_exe " . activeExe : ""
    fullKeyWithCondition := keyPressed . (currentWinCondition ? "|" . currentWinCondition : "")
    fullKeyDefault := keyPressed
    ; التحقق من الاختصار مع الشرط أو بدونه
    if (NoFlxHotkeys.Has(fullKeyWithCondition)) {
        action := NoFlxHotkeys[fullKeyWithCondition]
    } else if (NoFlxHotkeys.Has(fullKeyDefault)) {
        action := NoFlxHotkeys[fullKeyDefault]
    } else {
        ; إذا لم يكن هناك اختصار مطابق، نترك المفتاح يمر بشكل طبيعي
        return
    }
    ; تنفيذ الإجراء
    if (RegExMatch(action, "\.ahk$")) {
        fullPath := (InStr(action, "\") == 1 || InStr(action, ":") == 2) ? action : scriptsDir . "\" . action
        if FileExist(fullPath) {
            SetWorkingDir(scriptsDir)
            ; Run, %A_AhkPath% "%fullPath%", , UseErrorLevel -> Run(Target, WorkingDir, Options)
            ; A_AhkPath is a built-in variable
            ; A_LastError is replaced by the Run object's ErrorLevel property
            try {
                Run(A_AhkPath . ' "' . fullPath . '"', scriptsDir)
            } catch Error as e {
                MsgBox("فشل تشغيل السكربت: " . fullPath . "`nخطأ: " . e.message, "خطأ", "IconStop")
            }
            SetWorkingDir(A_ScriptDir)
        } else {
            MsgBox("ملف السكربت غير موجود: " . fullPath, "خطأ", "IconStop")
        }
    } else {
        ExecuteSingleAction(action)
    }
}
;------------------ Hotkeys ------------------
Hotkey("^#=", OpenCustomHotkeysGUI)
;------------------ Functions ------------------
OpenInteractiveMode() {
    global baseHotkey, InteractiveMenu
   
    ; IfWinExist, قائمة الاختصارات -> if WinExist("قائمة الاختصارات")
    if WinExist("قائمة الاختصارات") {
        ; Gui, InteractiveMenu:Destroy -> InteractiveMenu.Destroy()
        InteractiveMenu.Destroy()
        return
    }
   
    ; Gui, InteractiveMenu:Destroy -> InteractiveMenu := Gui("InteractiveMenu")
    InteractiveMenu := Gui()
    InteractiveMenu.BackColor := "2D2D2D"
   
    ; Gui, InteractiveMenu:Font, c000000 s10, Segoe UI -> InteractiveMenu.SetFont("c000000 s10", "Segoe UI")
    InteractiveMenu.SetFont("c000000 s10", "Segoe UI")
   
    ; Gui, InteractiveMenu:Add, Text, ... -> InteractiveMenu.AddText(...)
    InteractiveMenu.AddText("x10 y10 w300 h25 Center cFFD700", "اختر اختصارًا")
   
    ; Gui, InteractiveMenu:Add, ListBox, ... -> InteractiveMenu.AddListBox(...)
    InteractiveMenu.AddListBox("x10 y40 w300 h230 vSelectedHotkey gExecuteFromMenu", GenerateHotkeyListForMenu())
   
    ; Gui, InteractiveMenu:Show, ... -> InteractiveMenu.Show(...)
    InteractiveMenu.Show("w320 h270", "قائمة الاختصارات")
}
GenerateHotkeyListForMenu() {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey
    list := ""
   
    ; CustomHotkeys
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        displayText := baseHotkey . " & " . key . " - " . action . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
   
    ; AdvancedScripts
    for fullKey, scriptPath in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        displayText := baseHotkey . " & " . key . " - " . scriptPath . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
   
    ; NoFlxHotkeys
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := StrReplace(SplitKeyCond[1], "VKBA", ";")
        condition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : ""
        displayText := key . " - " . action . (condition ? " (" . condition . ")" : "")
        list .= displayText . "|"
    }
    return RTrim(list, "|")
}
ExecuteFromMenu(thisControl, *) {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys, baseHotkey, scriptsDir, InteractiveMenu
   
    ; Gui, InteractiveMenu:Submit, NoHide -> InteractiveMenu.Submit(false)
    values := InteractiveMenu.Submit(false)
    SelectedHotkey := values.SelectedHotkey
   
    if (SelectedHotkey == "") {
        return ; لا تفعل شيئًا إذا لم يتم اختيار شيء
    }
   
    SplitHotkey := StrSplit(SelectedHotkey, " - ")
    if (SplitHotkey.Length < 2) {
        MsgBox("تنسيق الاختصار غير صالح.", "خطأ", "IconStop")
        return
    }
    keyDisplay := SplitHotkey[1]
    actionOrScript := SplitHotkey[2]
   
    ; استخراج الشرط إذا كان موجودًا
    condition := ""
    if (posStart := InStr(actionOrScript, "(")) {
        posEnd := InStr(actionOrScript, ")", 0, -1)
        condition := SubStr(actionOrScript, posStart + 1, posEnd - posStart - 1)
        actionOrScript := Trim(SubStr(actionOrScript, 1, posStart - 1))
    }
   
    ; تحديد ما إذا كان الاختصار يستخدم Flx أم لا
    isFlx := InStr(keyDisplay, baseHotkey . " & ")
    key := isFlx ? StrReplace(keyDisplay, baseHotkey . " & ") : keyDisplay
    fullKey := StrReplace(key, ";", "VKBA") . (condition ? "|" . condition : "")
   
    ; إغلاق الواجهة أولاً
    InteractiveMenu.Destroy()
   
    ; تنفيذ الإجراء
    if (isFlx) {
        if (AdvancedScripts.Has(fullKey)) {
            scriptPath := AdvancedScripts[fullKey]
            fullPath := A_ScriptDir . "\" . scriptPath
            if FileExist(fullPath) {
                SetWorkingDir(scriptsDir)
                try {
                    Run(A_AhkPath . ' "' . fullPath . '"', scriptsDir)
                } catch Error as e {
                    MsgBox("فشل تشغيل السكربت: " . fullPath . "`nخطأ: " . e.message, "خطأ", "IconStop")
                }
                SetWorkingDir(A_ScriptDir)
            } else {
                MsgBox("ملف السكربت غير موجود: " . fullPath, "خطأ", "IconStop")
            }
        } else if (CustomHotkeys.Has(fullKey)) {
            action := CustomHotkeys[fullKey]
            ExecuteSingleAction(action)
        } else {
            MsgBox("لم يتم العثور على الاختصار.", "خطأ", "IconStop")
        }
    } else {
        if (NoFlxHotkeys.Has(fullKey)) {
            action := NoFlxHotkeys[fullKey]
            if (RegExMatch(action, "\.ahk$")) {
                fullPath := (InStr(action, "\") == 1 || InStr(action, ":") == 2) ? action : scriptsDir . "\" . action
                if FileExist(fullPath) {
                    SetWorkingDir(scriptsDir)
                    try {
                        Run(A_AhkPath . ' "' . fullPath . '"', scriptsDir)
                    } catch Error as e {
                        MsgBox("فشل تشغيل السكربت: " . fullPath . "`nخطأ: " . e.message, "خطأ", "IconStop")
                    }
                    SetWorkingDir(A_ScriptDir)
                } else {
                    MsgBox("ملف السكربت غير موجود: " . fullPath, "خطأ", "IconStop")
                }
            } else {
                ExecuteSingleAction(action)
            }
        } else {
            MsgBox("لم يتم العثور على الاختصار.", "خطأ", "IconStop")
        }
    }
}
ExecuteSingleAction(action) {
    ; تنفيذ الإجراءات البسيطة مثل Run أو Send
    if (SubStr(action, 1, 4) == "Run ") {
        command := Trim(SubStr(action, 5))
        try {
            Run(command)
        } catch Error as e {
            MsgBox("فشل تنفيذ الأمر: " . command . "`nخطأ: " . e.message, "خطأ", "IconStop")
        }
    } else if (SubStr(action, 1, 5) == "Send ") {
        text := Trim(SubStr(action, 6))
        Send(text)
    } else {
        MsgBox("نوع الإجراء غير مدعوم: " . action, "خطأ", "IconStop")
    }
}
; وظيفة إعادة تعريف الاختصارات
ReloadHotkeys(oldBaseHotkey) {
    global baseHotkey, CustomHotkeys, AdvancedScripts
    ; إيقاف الاختصارات القديمة إذا كان هناك مفتاح أساسي قديم
    if (oldBaseHotkey != "") {
        for fullKey, action in CustomHotkeys {
            key := RegExReplace(StrSplit(fullKey, "|")[1], "[+^!#]")
            Hotkey(oldBaseHotkey . " & " . key, "", "Off")
        }
        for fullKey, scriptPath in AdvancedScripts {
            key := RegExReplace(StrSplit(fullKey, "|")[1], "[+^!#]")
            Hotkey(oldBaseHotkey . " & " . key, "", "Off")
        }
    }
    ; تعريف الاختصارات الجديدة
    for fullKey, action in CustomHotkeys {
        key := RegExReplace(StrSplit(fullKey, "|")[1], "[+^!#]")
        try {
            Hotkey(baseHotkey . " & " . key, ExecuteHotkey, "On")
        } catch Error as e {
            MsgBox("فشل تعريف الاختصار عند إعادة التحميل: " . baseHotkey . " & " . key . "`nالسبب: " . e.message, "خطأ", "IconStop")
        }
    }
    for fullKey, scriptPath in AdvancedScripts {
        key := RegExReplace(StrSplit(fullKey, "|")[1], "[+^!#]")
        try {
            Hotkey(baseHotkey . " & " . key, ExecuteHotkey, "On")
        } catch Error as e {
            MsgBox("فشل تعريف السكربت المتقدم عند إعادة التحميل: " . baseHotkey . " & " . key . "`nالسبب: " . e.message, "خطأ", "IconStop")
        }
    }
}
; وظيفة تنفيذ اختصار Flx
ExecuteHotkey() {
    global CustomHotkeys, AdvancedScripts, baseHotkey, scriptsDir
   
    ; A_ThisHotkey is the key combination that triggered the hotkey
    hotkeyString := A_ThisHotkey
   
    ; Hotkey in v2 is a function, not a label, so A_ThisHotkey is the key combination
    ; The hotkey is defined as Hotkey(baseHotkey . " & " . baseKey, ExecuteHotkey, "On")
    ; We need to extract baseKey from A_ThisHotkey
   
    ; Find the key part after " & "
    key := Trim(SubStr(hotkeyString, InStr(hotkeyString, "&") + 1))
    ; الحصول على اسم العملية النشطة لاستخدامه كشرط
    activeExe := WinGetProcessName("A")
    currentWinCondition := activeExe ? "ahk_exe " . activeExe : ""
    fullKeyWithCondition := key . (currentWinCondition ? "|" . currentWinCondition : "")
    fullKeyDefault := key
    ; تحديد الإجراء أو السكربت
    if (AdvancedScripts.Has(fullKeyWithCondition)) {
        scriptPath := AdvancedScripts[fullKeyWithCondition]
        ; تنفيذ السكربت المتقدم
        fullPath := A_ScriptDir . "\" . scriptPath
        if FileExist(fullPath) {
            SetWorkingDir(scriptsDir)
            try {
                Run(A_AhkPath . ' "' . fullPath . '"', scriptsDir)
            } catch Error as e {
                MsgBox("فشل تشغيل السكربت: " . fullPath . "`nخطأ: " . e.message, "خطأ", "IconStop")
            }
            SetWorkingDir(A_ScriptDir)
        } else {
            MsgBox("ملف السكربت غير موجود: " . fullPath, "خطأ", "IconStop")
        }
    } else if (AdvancedScripts.Has(fullKeyDefault)) {
        scriptPath := AdvancedScripts[fullKeyDefault]
        ; تنفيذ السكربت المتقدم
        fullPath := A_ScriptDir . "\" . scriptPath
        if FileExist(fullPath) {
            SetWorkingDir(scriptsDir)
            try {
                Run(A_AhkPath . ' "' . fullPath . '"', scriptsDir)
            } catch Error as e {
                MsgBox("فشل تشغيل السكربت: " . fullPath . "`nخطأ: " . e.message, "خطأ", "IconStop")
            }
            SetWorkingDir(A_ScriptDir)
        } else {
            MsgBox("ملف السكربت غير موجود: " . fullPath, "خطأ", "IconStop")
        }
    } else if (CustomHotkeys.Has(fullKeyWithCondition)) {
        action := CustomHotkeys[fullKeyWithCondition]
        ; تنفيذ الإجراء البسيط
        ExecuteSingleAction(action)
    } else if (CustomHotkeys.Has(fullKeyDefault)) {
        action := CustomHotkeys[fullKeyDefault]
        ; تنفيذ الإجراء البسيط
        ExecuteSingleAction(action)
    } else {
        ; إذا لم يكن هناك اختصار مطابق، نترك المفتاح يمر بشكل طبيعي
        return
    }
}
; وظيفة مؤشر الوضع الآمن
InitSecureModeIndicator() {
    global isSecureMode, SecureMode
   
    ; Gui, SecureMode:Destroy -> SecureMode := Gui("SecureMode")
    if WinExist("وضع آمن") {
        SecureMode.Destroy()
    }
    if (isSecureMode) {
        SecureMode := Gui()
        SecureMode.BackColor := "FF0000"
        SecureMode.SetFont("cFFFFFF s10", "Segoe UI")
        SecureMode.AddText("x10 y10 w100 h25 Center", "وضع آمن")
        SecureMode.Show("NoActivate x0 y0", "وضع آمن")
    }
}
; وظيفة تبديل الوضع الآمن
ToggleSecureMode() {
    global isSecureMode, iniFile
    isSecureMode := !isSecureMode
    IniWrite(isSecureMode ? 1 : 0, iniFile, "Settings", "IsSecureMode")
    InitSecureModeIndicator()
}
; وظيفة فتح واجهة الاختصارات المخصصة
OpenCustomHotkeysGUI() {
    global CustomHotkeysGui
    ; Gui, CustomHotkeys:Destroy -> CustomHotkeysGui := Gui("CustomHotkeys")
    if WinExist("إدارة اختصارات Flx") {
        CustomHotkeysGui.Destroy()
    }
    CustomHotkeysGui := Gui()
    CustomHotkeysGui.BackColor := "2D2D2D"
    CustomHotkeysGui.SetFont("cFFFFFF s10", "Segoe UI")
    ; قسم إضافة اختصار جديد
    CustomHotkeysGui.AddText("x10 y10 w400 h25 Center cFFD700", "إضافة / تعديل اختصار جديد")
    CustomHotkeysGui.AddText("x10 y40 w100 h25", "المفتاح (مثل a, F1):")
    CustomHotkeysGui.AddEdit("x110 y40 w100 h25 vHotkeyKey c000000 Background424242")
    CustomHotkeysGui.AddButton("x220 y40 w100 h25 gDetectKey", "اكتشاف مفتاح")
    CustomHotkeysGui.AddText("x10 y70 w100 h25", "شرط النافذة (اختياري):")
    CustomHotkeysGui.AddEdit("x110 y70 w210 h25 vWinCondition c000000 Background424242")
    ; قسم خيارات المفتاح
    CustomHotkeysGui.AddCheckBox("x10 y100 vUseFlx Checked", "اختصار Flx (يتطلب المفتاح الأساسي)")
    CustomHotkeysGui.AddCheckBox("x150 y100 vUseCtrl", "Ctrl")
    CustomHotkeysGui.AddCheckBox("x250 y100 vUseShift", "Shift")
    CustomHotkeysGui.AddCheckBox("x350 y100 vUseAlt", "Alt")
    CustomHotkeysGui.AddCheckBox("x450 y100 vUseWin", "Win")
    ; قسم الإجراء
    CustomHotkeysGui.AddText("x10 y130 w100 h25", "الإجراء:")
    CustomHotkeysGui.AddButton("x110 y130 w120 h25 gAddAppHotkey", "تشغيل تطبيق")
    CustomHotkeysGui.AddButton("x240 y130 w120 h25 gOpenTextInput", "إرسال نص")
    ; قسم قائمة الاختصارات الحالية
    CustomHotkeysGui.AddText("x10 y170 w400 h25 Center cFFD700", "الاختصارات الحالية")
    CustomHotkeysGui.AddListBox("x10 y200 w480 h200 vSelectedHotkeyToDelete gSelectHotkeyToDelete", GenerateHotkeyList())
    CustomHotkeysGui.AddButton("x10 y410 w100 h30 gDeleteHotkey", "حذف الاختصار المحدد")
    CustomHotkeysGui.AddButton("x390 y410 w100 h30 gGuiClose", "إغلاق")
    CustomHotkeysGui.Show("w500 h450", "إدارة اختصارات Flx")
}
; وظيفة اكتشاف المفتاح
DetectKey(thisControl, *) {
    global CustomHotkeysGui
    CustomHotkeysGui.Opt("+Disabled")
    detectedKey := ""
   
    ; Loop, 255 { -> Loop 255
    Loop 255
    {
        scanCode := Format("SC{:03X}", A_Index)
        ; if GetKeyState(scanCode, "P") -> if GetKeyState(scanCode, "P")
        if GetKeyState(scanCode, "P") {
            detectedKey := scanCode
            goto EndDetect
        }
        vkCode := Format("VK{:02X}", A_Index)
        if GetKeyState(vkCode, "P") {
            detectedKey := vkCode
            goto EndDetect
        }
    }
   
    startTime := A_TickCount
    while (A_TickCount - startTime < 10000) {
        Loop 255 {
            scanCode := Format("SC{:03X}", A_Index)
            if GetKeyState(scanCode, "P") {
                detectedKey := scanCode
                goto EndDetect
            }
            vkCode := Format("VK{:02X}", A_Index)
            if GetKeyState(vkCode, "P") {
                detectedKey := vkCode
                goto EndDetect
            }
        }
        Sleep(50)
    }
    MsgBox("لم يتم الضغط على أي مفتاح خلال 10 ثوانٍ.", "خطأ", "IconStop")
    EndDetect:
    if (detectedKey != "") {
        detectedKey := RegExReplace(detectedKey, "[+^!#]")
        ; GuiControl, CustomHotkeys:, HotkeyKey, %detectedKey% -> CustomHotkeysGui["HotkeyKey"].Value := detectedKey
        CustomHotkeysGui["HotkeyKey"].Value := detectedKey
    }
    CustomHotkeysGui.Opt("-Disabled")
}
GenerateHotkeyList() {
    global CustomHotkeys, AdvancedScripts, NoFlxHotkeys
    hotkeyList := ""
    for fullKey, action in CustomHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (Flx)`n"
    }
    for fullKey, script in AdvancedScripts {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . script . " (Flx)`n"
    }
    for fullKey, action in NoFlxHotkeys {
        SplitKeyCond := StrSplit(fullKey, "|")
        key := SplitKeyCond[1]
        winCondition := SplitKeyCond.Length > 1 ? SplitKeyCond[2] : "غير محدد"
        hotkeyList .= key . " | " . winCondition . " = " . action . " (NoFlx)`n"
    }
    return hotkeyList
}
AddAppHotkey(thisControl, *) {
    global CustomHotkeysGui
    values := CustomHotkeysGui.Submit(false)
    HotkeyKey := values.HotkeyKey
    WinCondition := values.WinCondition
    UseFlx := values.UseFlx
    UseCtrl := values.UseCtrl
    UseShift := values.UseShift
    UseAlt := values.UseAlt
    UseWin := values.UseWin
   
    if (HotkeyKey == "") {
        MsgBox("يرجى إدخال مفتاح.", "خطأ", "IconStop")
        return
    }
    modifierPrefix := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
   
    if (UseFlx && (CustomHotkeys.Has(fullKey) || AdvancedScripts.Has(fullKey))) {
        oldAction := CustomHotkeys.Has(fullKey) ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        result := MsgBox("المفتاح " . key . " مع شرط النافذة " . WinCondition . " مستخدم بالفعل:`n" . oldAction . "`nهل تريد استبداله؟", "تحذير", "IconExclamation YesNo")
        if (result != "Yes") {
            return
        }
    } else if (!UseFlx && NoFlxHotkeys.Has(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        result := MsgBox("المفتاح " . key . " مع شرط النافذة " . WinCondition . " مستخدم بالفعل:`n" . oldAction . "`nهل تريد استبداله؟", "تحذير", "IconExclamation YesNo")
        if (result != "Yes") {
            return
        }
    }
   
    ; نافذة اختيار طريقة الإضافة
    global AppInput
    if WinExist("إضافة تطبيق للاختصار") {
        AppInput.Destroy()
    }
    AppInput := Gui()
    AppInput.BackColor := "2D2D2D"
    AppInput.SetFont("cFFFFFF s10", "Segoe UI")
    AppInput.AddText("x20 y20 w300 h25", "اختر طريقة إضافة التطبيق:")
    AppInput.AddButton("x20 y50 w150 h30 gBrowseAppFile", "اختيار ملف تطبيق")
    AppInput.AddButton("x180 y50 w150 h30 gManualAppInput", "إدخال أمر يدوي")
    AppInput.AddButton("x100 y90 w100 h30 gCancelAppInput", "إلغاء")
    AppInput.Show("w340 h130", "إضافة تطبيق للاختصار")
}
BrowseAppFile(thisControl, *) {
    global AppInput
    AppInput.Destroy()
   
    ; FileSelectFile, selectedFile, 3, , اختر تطبيقًا لفتحه, Executable Files (*.exe)
    selectedFile := FileSelect(3, , "اختر تطبيقًا لفتحه", "Executable Files (*.exe)")
   
    if (selectedFile != "") {
        global CustomHotkeysGui
        values := CustomHotkeysGui.Submit(false)
        HotkeyKey := values.HotkeyKey
        WinCondition := values.WinCondition
        UseFlx := values.UseFlx
        UseCtrl := values.UseCtrl
        UseShift := values.UseShift
        UseAlt := values.UseAlt
        UseWin := values.UseWin
       
        modifierPrefix := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
        key := modifierPrefix . HotkeyKey
        fullKey := key . (WinCondition ? "|" . WinCondition : "")
       
        oldHotkeyCount := UseFlx ? CustomHotkeys.Count : NoFlxHotkeys.Count
        if (UseFlx) {
            AddHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count > oldHotkeyCount || CustomHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                MsgBox("تمت إضافة الاختصار بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار.", "خطأ", "IconStop")
            }
        } else {
            AddNoFlxHotkey(HotkeyKey, "Run " . selectedFile, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count > oldHotkeyCount || NoFlxHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                MsgBox("تمت إضافة الاختصار بدون Flx بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار بدون Flx.", "خطأ", "IconStop")
            }
        }
    }
}
ManualAppInput(thisControl, *) {
    global AppInput
    AppInput.Destroy()
   
    global ManualInput
    if WinExist("إدخال أمر يدوي") {
        ManualInput.Destroy()
    }
    ManualInput := Gui()
    ManualInput.BackColor := "2D2D2D"
    ManualInput.SetFont("cFFFFFF s10", "Segoe UI")
    ManualInput.AddText("x20 y20 w300 h25", "أدخل أمر التشغيل (مثل explorer.exe shell:...):")
    ManualInput.AddEdit("x20 y50 w400 h25 vManualCommand c000000 Background424242")
    ManualInput.AddButton("x170 y80 w100 h30 gSaveManualCommand", "حفظ")
    ManualInput.AddButton("x280 y80 w100 h30 gCancelManualInput", "إلغاء")
    ManualInput.Show("w440 h120", "إدخال أمر يدوي")
}
SaveManualCommand(thisControl, *) {
    global ManualInput, CustomHotkeysGui
    values := ManualInput.Submit(false)
    ManualCommand := values.ManualCommand
   
    if (ManualCommand != "") {
        values := CustomHotkeysGui.Submit(false)
        HotkeyKey := values.HotkeyKey
        WinCondition := values.WinCondition
        UseFlx := values.UseFlx
        UseCtrl := values.UseCtrl
        UseShift := values.UseShift
        UseAlt := values.UseAlt
        UseWin := values.UseWin
       
        modifierPrefix := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
        key := modifierPrefix . HotkeyKey
        fullKey := key . (WinCondition ? "|" . WinCondition : "")
       
        oldHotkeyCount := UseFlx ? CustomHotkeys.Count : NoFlxHotkeys.Count
        if (UseFlx) {
            AddHotkey(HotkeyKey, "Run " . ManualCommand, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count > oldHotkeyCount || CustomHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                ManualInput.Destroy()
                MsgBox("تمت إضافة الاختصار بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار.", "خطأ", "IconStop")
                ManualInput.Destroy()
            }
        } else {
            AddNoFlxHotkey(HotkeyKey, "Run " . ManualCommand, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count > oldHotkeyCount || NoFlxHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                ManualInput.Destroy()
                MsgBox("تمت إضافة الاختصار بدون Flx بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار بدون Flx.", "خطأ", "IconStop")
                ManualInput.Destroy()
            }
        }
    } else {
        MsgBox("يرجى إدخال أمر تشغيل.", "خطأ", "IconStop")
    }
}
CancelManualInput(thisControl, *) {
    global ManualInput
    ManualInput.Destroy()
}
OpenTextInput(thisControl, *) {
    global CustomHotkeysGui
    values := CustomHotkeysGui.Submit(false)
    HotkeyKey := values.HotkeyKey
    WinCondition := values.WinCondition
    UseFlx := values.UseFlx
    UseCtrl := values.UseCtrl
    UseShift := values.UseShift
    UseAlt := values.UseAlt
    UseWin := values.UseWin
   
    if (HotkeyKey == "") {
        MsgBox("يرجى إدخال مفتاح.", "خطأ", "IconStop")
        return
    }
    modifierPrefix := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
    key := modifierPrefix . HotkeyKey
    fullKey := key . (WinCondition ? "|" . WinCondition : "")
   
    if (UseFlx && (CustomHotkeys.Has(fullKey) || AdvancedScripts.Has(fullKey))) {
        oldAction := CustomHotkeys.Has(fullKey) ? CustomHotkeys[fullKey] : AdvancedScripts[fullKey]
        result := MsgBox("المفتاح " . key . " مع شرط النافذة " . WinCondition . " مستخدم بالفعل:`n" . oldAction . "`nهل تريد استبداله؟", "تحذير", "IconExclamation YesNo")
        if (result != "Yes") {
            return
        }
    } else if (!UseFlx && NoFlxHotkeys.Has(fullKey)) {
        oldAction := NoFlxHotkeys[fullKey]
        result := MsgBox("المفتاح " . key . " مع شرط النافذة " . WinCondition . " مستخدم بالفعل:`n" . oldAction . "`nهل تريد استبداله؟", "تحذير", "IconExclamation YesNo")
        if (result != "Yes") {
            return
        }
    }
   
    global TextInput
    if WinExist("إرسال نص للاختصار") {
        TextInput.Destroy()
    }
    TextInput := Gui()
    TextInput.BackColor := "2D2D2D"
    TextInput.SetFont("cFFFFFF s10", "Segoe UI")
    TextInput.AddText("x20 y20 w150 h25", "أدخل النص لإرساله:")
    TextInput.AddEdit("x180 y20 w300 h25 vTextToSend c000000 Background424242")
    TextInput.AddText("x20 y50 w460 h20 cA0A0A0", "ملاحظة: يمكنك أيضًا إدخال إيموجي مثل 😊 أو 👍 هنا")
    TextInput.AddButton("x180 y80 w100 h30 gSaveTextHotkey", "حفظ")
    TextInput.AddButton("x290 y80 w100 h30 gCancelTextInput", "إلغاء")
    TextInput.Show("w500 h120", "إرسال نص للاختصار")
}
SaveTextHotkey(thisControl, *) {
    global TextInput, CustomHotkeysGui
    values := TextInput.Submit(false)
    TextToSend := values.TextToSend
   
    if (TextToSend != "") {
        values := CustomHotkeysGui.Submit(false)
        HotkeyKey := values.HotkeyKey
        WinCondition := values.WinCondition
        UseFlx := values.UseFlx
        UseCtrl := values.UseCtrl
        UseShift := values.UseShift
        UseAlt := values.UseAlt
        UseWin := values.UseWin
       
        modifierPrefix := (UseCtrl ? "^" : "") . (UseShift ? "+" : "") . (UseAlt ? "!" : "") . (UseWin ? "#" : "")
        key := modifierPrefix . HotkeyKey
        fullKey := key . (WinCondition ? "|" . WinCondition : "")
       
        oldHotkeyCount := UseFlx ? CustomHotkeys.Count : NoFlxHotkeys.Count
        if (UseFlx) {
            AddHotkey(HotkeyKey, "Send " . TextToSend, UseCtrl, UseShift, UseAlt, UseWin, UseFlx, WinCondition)
            if (CustomHotkeys.Count > oldHotkeyCount || CustomHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                TextInput.Destroy()
                MsgBox("تمت إضافة الاختصار بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار.", "خطأ", "IconStop")
                TextInput.Destroy()
            }
        } else {
            AddNoFlxHotkey(HotkeyKey, "Send " . TextToSend, UseCtrl, UseShift, UseAlt, UseWin, WinCondition)
            if (NoFlxHotkeys.Count > oldHotkeyCount || NoFlxHotkeys.Has(fullKey)) {
                CustomHotkeysGui["HotkeyKey"].Value := ""
                CustomHotkeysGui["WinCondition"].Value := ""
                CustomHotkeysGui["UseFlx"].Value := 1
                CustomHotkeysGui["UseCtrl"].Value := 0
                CustomHotkeysGui["UseShift"].Value := 0
                CustomHotkeysGui["UseAlt"].Value := 0
                CustomHotkeysGui["UseWin"].Value := 0
                CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
                TextInput.Destroy()
                MsgBox("تمت إضافة الاختصار بدون Flx بنجاح!", "تم", "IconInfo")
            } else {
                MsgBox("فشل إضافة الاختصار بدون Flx.", "خطأ", "IconStop")
                TextInput.Destroy()
            }
        }
    } else {
        MsgBox("يرجى إدخال نص للإرسال.", "خطأ", "IconStop")
    }
}
CancelTextInput(thisControl, *) {
    global TextInput
    TextInput.Destroy()
}
SelectHotkeyToDelete(thisControl, *) {
    ; مجرد تحديث، لا حاجة لشيء هنا إذا كان gSelectHotkeyToDelete فقط للتحديد
}
DeleteHotkey(thisControl, *) {
    global CustomHotkeysGui, baseHotkey, iniFile
    values := CustomHotkeysGui.Submit(false)
    SelectedHotkeyToDelete := values.SelectedHotkeyToDelete
   
    if (SelectedHotkeyToDelete == "") {
        MsgBox("يرجى تحديد اختصار للحذف.", "خطأ", "IconStop")
        return
    }
    ; تحليل الاختصار المحدد
    ; التنسيق: key | winCondition = action (Type)
    eqPos := InStr(SelectedHotkeyToDelete, " = ")
    pipePos := InStr(SelectedHotkeyToDelete, " | ")
    keyPart := SubStr(SelectedHotkeyToDelete, 1, pipePos - 1)
    rest := SubStr(SelectedHotkeyToDelete, pipePos + 3)
    winConditionPart := SubStr(rest, 1, InStr(rest, " = ") - 1)
    actionPart := SubStr(rest, InStr(rest, " = ") + 3)
    openParenPos := InStr(actionPart, "(")
    typePart := SubStr(actionPart, openParenPos + 1, InStr(actionPart, ")") - openParenPos - 1)
    action := Trim(SubStr(actionPart, 1, openParenPos - 1))
    ; استخراج المفتاح الأساسي
    key := keyPart
    fullKey := key . (winConditionPart != "غير محدد" ? "|" . winConditionPart : "")
    result := MsgBox("هل أنت متأكد من حذف الاختصار:`n" . SelectedHotkeyToDelete . "؟", "تأكيد الحذف", "IconQuestion YesNo")
    if (result != "Yes") {
        return
    }
    isFlx := (typePart == "Flx")
    if (isFlx) {
        ; حذف اختصار Flx
        if (CustomHotkeys.Has(fullKey)) {
            RemoveHotkey(key, baseHotkey)
            CustomHotkeys.Delete(fullKey)
            IniDelete(iniFile, "CustomHotkeys", fullKey)
        } else if (AdvancedScripts.Has(fullKey)) {
            RemoveHotkey(key, baseHotkey)
            AdvancedScripts.Delete(fullKey)
            IniDelete(iniFile, "AdvancedScripts", fullKey)
        } else {
            MsgBox("لم يتم العثور على اختصار Flx للحذف.", "خطأ", "IconStop")
            return
        }
    } else {
        ; حذف اختصار NoFlx
        if (NoFlxHotkeys.Has(fullKey)) {
            NoFlxHotkeys.Delete(fullKey)
            if (HotkeyConditions.Has(key)) {
                HotkeyConditions[key].Delete(fullKey)
                if (HotkeyConditions[key].Count == 0) {
                    try {
                        Hotkey(key, "", "Off")
                    } catch Error as e {
                        MsgBox("فشل إيقاف الاختصار بدون Flx: " . key . "`nالسبب: " . e.message, "خطأ", "IconStop")
                    }
                    HotkeyConditions.Delete(key)
                }
            }
            IniDelete(iniFile, "NoFlx", fullKey)
        } else {
            MsgBox("لم يتم العثور على اختصار NoFlx للحذف.", "خطأ", "IconStop")
            return
        }
    }
    MsgBox("تم حذف الاختصار بنجاح.", "تم", "IconInfo")
    CustomHotkeysGui["SelectedHotkeyToDelete"].Text := GenerateHotkeyList()
}
RemoveHotkey(key, baseHotkey) {
    baseKey := RegExReplace(key, "[+^!#]")
    try {
        Hotkey(baseHotkey . " & " . baseKey, "", "Off")
    } catch Error as e {
        MsgBox("فشل إيقاف الاختصار: " . baseHotkey . " & " . baseKey . "`nالسبب: " . e.message, "خطأ", "IconStop")
    }
}
AddHotkey(key, action, useCtrl, useShift, useAlt, useWin, useFlx, winCondition) {
    global CustomHotkeys, AdvancedScripts, baseHotkey, iniFile
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    ; تحديد ما إذا كان الإجراء هو تشغيل سكربت متقدم
    isAdvancedScript := RegExMatch(action, "Run .*?\.ahk$")
    if (isAdvancedScript) {
        ; إضافة سكربت متقدم
        scriptPath := Trim(SubStr(action, 5))
        AdvancedScripts[fullKey] := scriptPath
        IniWrite(scriptPath, iniFile, "AdvancedScripts", fullKey)
    } else {
        ; إضافة اختصار بسيط
        CustomHotkeys[fullKey] := action
        IniWrite(action, iniFile, "CustomHotkeys", fullKey)
    }
    ; تعريف الاختصار
    baseKey := RegExReplace(modifierPrefix . key, "[+^!#]")
    try {
        Hotkey(baseHotkey . " & " . baseKey, ExecuteHotkey, "On")
    } catch Error as e {
        MsgBox("فشل تعريف الاختصار: " . baseHotkey . " & " . baseKey . "`nالسبب: " . e.message, "خطأ", "IconStop")
    }
}
AddNoFlxHotkey(key, action, useCtrl, useShift, useAlt, useWin, winCondition) {
    global NoFlxHotkeys, HotkeyConditions, iniFile
    modifierPrefix := (useCtrl ? "^" : "") . (useShift ? "+" : "") . (useAlt ? "!" : "") . (useWin ? "#" : "")
    fullKey := modifierPrefix . key . (winCondition ? "|" . winCondition : "")
    NoFlxHotkeys[fullKey] := action
    IniWrite(action, iniFile, "NoFlx", fullKey)
    hotkeyKey := modifierPrefix . key
    if (!HotkeyConditions.Has(hotkeyKey)) {
        HotkeyConditions[hotkeyKey] := Map()
        try {
            Hotkey(hotkeyKey, ExecuteNoFlxHotkeyConditional, "On")
        } catch Error as e {
            MsgBox("فشل تعريف الاختصار بدون Flx: " . hotkeyKey . "`nالسبب: " . e.message, "خطأ", "IconStop")
        }
    }
    HotkeyConditions[hotkeyKey][fullKey] := winCondition
}
GuiClose(thisControl, *) {
    global CustomHotkeysGui
    CustomHotkeysGui.Destroy()
}
CancelAppInput(thisControl, *) {
    global AppInput
    AppInput.Destroy()
}
; وظيفة تبديل الوضع الآمن عن طريق اختصار
; SC056 هو رمز المسح الافتراضي لـ RCtrl
Hotkey("SC056 & SC029", ToggleSecureMode)