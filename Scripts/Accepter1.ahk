#NoEnv
#SingleInstance Off ; ضروري جداً لكي يسمح لنا بفحص إذا كان السكربت شغالاً من قبل
DetectHiddenWindows, On

; --- الكشف عن النسخة السابقة ---
; نبحث عن النافذة التي أنشأناها باسم معين
IfWinExist, MyUniqueStatus_ON_Indicator
{
    ; إذا وجدت النافذة، فهذا يعني أن السكربت شغال
    ; نقوم بإغلاق النافذة (وهذا سيغلق السكربت السابق)
    WinClose, MyUniqueStatus_ON_Indicator
    ; ثم نغلق هذه النسخة الحالية فوراً
    ExitApp
}

; --- إذا وصل الكود هنا، فهذا يعني أنه لم يكن شغالاً ---

; إعدادات السرعة
DelayTime := 8000

; إنشاء علامة ON
Gui, +AlwaysOnTop -Caption +ToolWindow +Owner
Gui, Color, 00FF00
Gui, Font, s12 Bold, Segoe UI
Gui, Add, Text, cBlack Center, ON
; نعطي النافذة اسماً مميزاً لنبحث عنه عند التشغيل القادم
Gui, Show, x0 y0 NoActivate, MyUniqueStatus_ON_Indicator

; بدء الضغط
SetTimer, PressMyKeys, %DelayTime%
return

; دالة الضغط
PressMyKeys:
    Send, !{VK0D}
return

; عند إغلاق النافذة (من خلال الكود في الأعلى) يغلق السكربت بالكامل
GuiClose:
    ExitApp
return