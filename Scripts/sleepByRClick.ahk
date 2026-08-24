#SingleInstance Force
#Persistent

ToolTip, [كليك يمين: سكون (Sleep)] | [سهم يسار: إسبات (Hibernate)]
SetTimer, CheckTime, 15000
return

CheckTime:
ToolTip
ExitApp
return

RButton::
ToolTip
DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
Sleep, 1000
ExitApp

Left::
ToolTip
DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
Sleep, 1000
ExitApp
