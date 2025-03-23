#SingleInstance Force
#Include %A_ScriptDir%\Gdip.ahk  ; المسار النسبي من مجلد السكربت المتقدم (Scripts)
Input, Key, L1 T3  ; انتظار إدخال رقم من NumPad لمدة 3 ثواني
if (ErrorLevel = "Timeout")
    ExitApp

; تحميل المسار الرئيسي من ملف ini إذا كان موجوداً
IniRead, MainFolder, %A_ScriptDir%\..\ScreenshotSettings.ini, Settings, MainFolder, %A_Desktop%
IniRead, Folder1, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder1, Folder1
IniRead, Folder2, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder2, Folder2
IniRead, Folder3, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder3, Folder3
IniRead, Folder4, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder4, Folder4
IniRead, Folder5, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder5, Folder5
IniRead, Folder6, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder6, Folder6
IniRead, Folder7, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder7, Folder7
IniRead, Folder8, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder8, Folder8
IniRead, Folder9, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder9, Folder9

if (Key = "0")
{
    Gui, 1:Destroy
    Gui, 1:+AlwaysOnTop
    Gui, 1:Add, Text,, Main Folder Path:
    Gui, 1:Add, Edit, vMainFolderPath w300, %MainFolder%
    Gui, 1:Add, Button, gBrowseMainFolder, Browse
    Gui, 1:Add, Text,, Folder Names:
    Gui, 1:Add, Text,, NumPad1:
    Gui, 1:Add, Edit, vFolder1 w200, %Folder1%
    Gui, 1:Add, Text,, NumPad2:
    Gui, 1:Add, Edit, vFolder2 w200, %Folder2%
    Gui, 1:Add, Text,, NumPad3:
    Gui, 1:Add, Edit, vFolder3 w200, %Folder3%
    Gui, 1:Add, Text,, NumPad4:
    Gui, 1:Add, Edit, vFolder4 w200, %Folder4%
    Gui, 1:Add, Text,, NumPad5:
    Gui, 1:Add, Edit, vFolder5 w200, %Folder5%
    Gui, 1:Add, Text,, NumPad6:
    Gui, 1:Add, Edit, vFolder6 w200, %Folder6%
    Gui, 1:Add, Text,, NumPad7:
    Gui, 1:Add, Edit, vFolder7 w200, %Folder7%
    Gui, 1:Add, Text,, NumPad8:
    Gui, 1:Add, Edit, vFolder8 w200, %Folder8%
    Gui, 1:Add, Text,, NumPad9:
    Gui, 1:Add, Edit, vFolder9 w200, %Folder9%
    Gui, 1:Add, Button, gSaveSettings Default, Save
    Gui, 1:Add, Button, gCancelSettings, Cancel
    Gui, 1:Show
    return
}

if (Key >= "1" && Key <= "9")
{
    FolderVar := "Folder" . Key
    TargetFolder := %FolderVar%
    FullPath := MainFolder . "\" . TargetFolder
    
    IfNotExist, %FullPath%
        FileCreateDir, %FullPath%
    
    FormatTime, TimeStamp,, yyyy-MM-dd_HH-mm-ss
    FileName := FullPath . "\Screenshot_" . TimeStamp . ".png"
    
    pToken := Gdip_Startup()
    if !pToken
    {
        MsgBox, GDI+ failed to start. Please ensure Gdip.ahk is in %A_ScriptDir%.
        ExitApp
    }
    
    pBitmap := Gdip_BitmapFromScreen("0|0|" . A_ScreenWidth . "|" . A_ScreenHeight)
    if !pBitmap
    {
        MsgBox, Failed to capture screen.
        Gdip_Shutdown(pToken)
        ExitApp
    }
    
    Gdip_SaveBitmapToFile(pBitmap, FileName)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    ; إعداد تأثير الوميض على الحواف
    BorderWidth := 7  ; عرض الحافة (يمكنك تعديله حسب رغبتك)
    FlashColor := "FFFFFF"  ; لون الوميض (أبيض، يمكنك تغييره مثل "FFFF00" للأصفر)

    ; إنشاء GUI للحافة العلوية
    Gui, BorderTop:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, BorderTop:Color, %FlashColor%
    Gui, BorderTop:Show, x0 y0 w%A_ScreenWidth% h%BorderWidth% NoActivate

    ; إنشاء GUI للحافة السفلية
    Gui, BorderBottom:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, BorderBottom:Color, %FlashColor%
    BottomY := A_ScreenHeight - BorderWidth
    Gui, BorderBottom:Show, x0 y%BottomY% w%A_ScreenWidth% h%BorderWidth% NoActivate

    ; إنشاء GUI للحافة اليسرى
    Gui, BorderLeft:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, BorderLeft:Color, %FlashColor%
    Gui, BorderLeft:Show, x0 y0 w%BorderWidth% h%A_ScreenHeight% NoActivate

    ; إنشاء GUI للحافة اليمنى
    Gui, BorderRight:+LastFound +AlwaysOnTop -Caption +ToolWindow
    Gui, BorderRight:Color, %FlashColor%
    RightX := A_ScreenWidth - BorderWidth
    Gui, BorderRight:Show, x%RightX% y0 w%BorderWidth% h%A_ScreenHeight% NoActivate

    ; الانتظار لفترة قصيرة (مدة الوميض)
    Sleep, 100  ; 100 مللي ثانية (يمكنك تعديل المدة)

    ; إخفاء جميع الحواف
    Gui, BorderTop:Destroy
    Gui, BorderBottom:Destroy
    Gui, BorderLeft:Destroy
    Gui, BorderRight:Destroy
}

return

BrowseMainFolder:
Gui, 1:Submit, NoHide
FileSelectFolder, SelectedFolder, , 3
if SelectedFolder !=
    GuiControl, 1:, MainFolderPath, %SelectedFolder%
return

SaveSettings:
Gui, 1:Submit
if (MainFolderPath = "")
    MainFolderPath := A_Desktop
if (Folder1 = "" or Folder1 = "Folder1")
    Folder1 := "Folder1"
if (Folder2 = "" or Folder2 = "Folder2")
    Folder2 := "Folder2"
if (Folder3 = "" or Folder3 = "Folder3")
    Folder3 := "Folder3"
if (Folder4 = "" or Folder4 = "Folder4")
    Folder4 := "Folder4"
if (Folder5 = "" or Folder5 = "Folder5")
    Folder5 := "Folder5"
if (Folder6 = "" or Folder6 = "Folder6")
    Folder6 := "Folder6"
if (Folder7 = "" or Folder7 = "Folder7")
    Folder7 := "Folder7"
if (Folder8 = "" or Folder8 = "Folder8")
    Folder8 := "Folder8"
if (Folder9 = "" or Folder9 = "Folder9")
    Folder9 := "Folder9"

IniRead, OldMainFolder, %A_ScriptDir%\..\ScreenshotSettings.ini, Settings, MainFolder, %A_Desktop%
IniRead, OldFolder1, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder1, Folder1
IniRead, OldFolder2, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder2, Folder2
IniRead, OldFolder3, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder3, Folder3
IniRead, OldFolder4, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder4, Folder4
IniRead, OldFolder5, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder5, Folder5
IniRead, OldFolder6, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder6, Folder6
IniRead, OldFolder7, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder7, Folder7
IniRead, OldFolder8, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder8, Folder8
IniRead, OldFolder9, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder9, Folder9

if (OldMainFolder != MainFolderPath && InStr(FileExist(OldMainFolder), "D"))
{
    FileMoveDir, %OldMainFolder%, %MainFolderPath%, R
    if (ErrorLevel)
        MsgBox, Failed to rename main folder from %OldMainFolder% to %MainFolderPath%. ErrorLevel: %ErrorLevel%
}

OldFolders := [OldFolder1, OldFolder2, OldFolder3, OldFolder4, OldFolder5, OldFolder6, OldFolder7, OldFolder8, OldFolder9]
NewFolders := [Folder1, Folder2, Folder3, Folder4, Folder5, Folder6, Folder7, Folder8, Folder9]

Loop, 9
{
    OldFolder := OldFolders[A_Index]
    NewFolder := NewFolders[A_Index]
    OldPath := OldMainFolder . "\" . OldFolder
    NewPath := MainFolderPath . "\" . NewFolder

    if (OldFolder != NewFolder && InStr(FileExist(OldPath), "D"))
    {
        FileMoveDir, %OldPath%, %NewPath%, R
        if (ErrorLevel)
            MsgBox, Failed to rename folder from %OldPath% to %NewPath%. ErrorLevel: %ErrorLevel%
    }
}

IniWrite, %MainFolderPath%, %A_ScriptDir%\..\ScreenshotSettings.ini, Settings, MainFolder
IniWrite, %Folder1%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder1
IniWrite, %Folder2%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder2
IniWrite, %Folder3%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder3
IniWrite, %Folder4%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder4
IniWrite, %Folder5%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder5
IniWrite, %Folder6%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder6
IniWrite, %Folder7%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder7
IniWrite, %Folder8%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder8
IniWrite, %Folder9%, %A_ScriptDir%\..\ScreenshotSettings.ini, Folders, Folder9

Gui, 1:Destroy
return

CancelSettings:
Gui, 1:Destroy
return

GuiClose:
Gui, 1:Destroy
return