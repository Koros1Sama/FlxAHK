; أولاً: نجلب أبعاد النافذة النشطة حالياً وموقعها
WinGetPos, wX, wY, wW, wH, A

; حساب نقطة مركز النافذة لمعرفة في أي شاشة تقع (مهم لأصحاب الشاشات المتعددة)
winCenterX := wX + (wW / 2)
winCenterY := wY + (wH / 2)

SysGet, monitorCount, MonitorCount
targetMonitor := 1

; البحث عن الشاشة التي تحتوي على النافذة
Loop, %monitorCount% {
    SysGet, mon, Monitor, %A_Index%
    if (winCenterX >= monLeft && winCenterX <= monRight && winCenterY >= monTop && winCenterY <= monBottom) {
        targetMonitor := A_Index
        break
    }
}

; جلب مساحة العمل للشاشة المستهدفة (المساحة الصافية بدون شريط المهام)
SysGet, workArea, MonitorWorkArea, %targetMonitor%

; حساب إحداثيات المنتصف الدقيقة داخل تلك الشاشة
newX := workAreaLeft + ((workAreaRight - workAreaLeft) / 2) - (wW / 2)
newY := workAreaTop + ((workAreaBottom - workAreaTop) / 2) - (wH / 2)

; تحريك النافذة
WinMove, A,, newX, newY
ExitApp