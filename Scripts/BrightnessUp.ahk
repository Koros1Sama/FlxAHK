brightness := GetBrightness()
newBrightness := brightness + 10
if (newBrightness > 100)
    newBrightness := 100
SetBrightness(newBrightness)
ToolTip, تم رفع السطوع إلى %newBrightness%`%
Sleep, 1000
ExitApp
GetBrightness() {
    objWMIService := ComObjGet("winmgmts:\\.\root\WMI")
    colItems := objWMIService.ExecQuery("Select * from WmiMonitorBrightness")
    for item in colItems
        return item.CurrentBrightness
    return 0
}

SetBrightness(val) {
    objWMIService := ComObjGet("winmgmts:\\.\root\WMI")
    colItems := objWMIService.ExecQuery("Select * from WmiMonitorBrightnessMethods")
    for item in colItems
        item.WmiSetBrightness(1, val)
}