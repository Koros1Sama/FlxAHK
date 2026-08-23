try {
    brightness := GetBrightness()
    newBrightness := brightness - 10
    if (newBrightness < 0)
        newBrightness := 0
    SetBrightness(newBrightness)
    ToolTip, تم خفض السطوع إلى %newBrightness%`%
} catch {
    ToolTip, لا يمكن التحكم بالسطوع عبر WMI لهذه الشاشة
}
Sleep, 1000
ToolTip
ExitApp

GetBrightness() {
    try {
        objWMIService := ComObjGet("winmgmts:\\.\root\WMI")
        colItems := objWMIService.ExecQuery("Select * from WmiMonitorBrightness")
        for item in colItems
            return item.CurrentBrightness
    }
    return 0
}

SetBrightness(val) {
    try {
        objWMIService := ComObjGet("winmgmts:\\.\root\WMI")
        colItems := objWMIService.ExecQuery("Select * from WmiMonitorBrightnessMethods")
        for item in colItems
            item.WmiSetBrightness(1, val)
    }
}