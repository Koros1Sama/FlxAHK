; أولاً: نجلب أبعاد النافذة النشطة حالياً
WinGetPos,,, Width, Height, A

; ثانياً: نحسب إحداثيات المنتصف بناءً على حجم شاشتك وحجم النافذة
X := (A_ScreenWidth / 2) - (Width / 2)
Y := (A_ScreenHeight / 2) - (Height / 2)

; ثالثاً: نجبر النافذة تنتقل للمنتصف
WinMove, A,, X, Y