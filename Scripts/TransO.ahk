WinGet, TransLevel, Transparent, A
if (TransLevel = "") {
    TransLevel := 255
}
if (TransLevel <= 55) {
    TransLevel := 255
} else {
    TransLevel -= 50
}
WinSet, Transparent, %TransLevel%, A
return