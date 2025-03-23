InputBox, Minutes, تنبيه, بعد كم دقيقة تشتي التنبيه يشتغل يا سيد كوروس؟, , , , , , , 5
if (ErrorLevel = 0 && Minutes > 0)
{
    Sleep, % Minutes * 60000
    MsgBox, يا كوروس، كمل الوقت!
}
return