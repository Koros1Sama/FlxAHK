#SingleInstance Force
#Persistent

SetTimer, CheckTime, 2000
return

CheckTime:
ExitApp
return

RButton::
DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
Sleep, 1000
ExitApp
return

Left::
DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
Sleep, 1000
ExitApp
return
