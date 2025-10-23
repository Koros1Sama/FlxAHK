brightness := GetBrightness()
newBrightness := brightness + 10
if (newBrightness > 100)
    newBrightness := 100
SetBrightness(newBrightness)
Tooltip, تم رفع السطوع إلى %newBrightness%`
SetTimer, RemoveTooltip, -1000
return

RemoveTooltip:
    Tooltip
return

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