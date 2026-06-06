#NoEnv
CoordMode, Pixel, Screen
ImagePath := A_ScriptDir . "\image.png"

; تصوير منطقة أسفل يمين الشاشة فقط (لتجنب إيجاد صورة الملف المفتوحة في المحرر)
ImageSearch, fX, fY, 1500, 700, A_ScreenWidth, A_ScreenHeight, *60 %ImagePath%

if (ErrorLevel = 2)
{
    MsgBox, 16, خطأ, هناك مشكلة، لم أستطع إيجاد الملف:`n%ImagePath%
}
else if (ErrorLevel = 1)
{
    MsgBox, 48, غير موجود, لم أجد زر Retry في منطقة أسفل يمين الشاشة.`nلعل الصورة المرفوعة مختلفة قليلاً عن الزر الحقيقي أو فيها حواف زائدة.
}
else
{
    MsgBox, 64, تم العثور, ممتاز! تم العثور على زر Retry الحقيقي بنجاح عند:`nX: %fX% `nY: %fY%
}
ExitApp
