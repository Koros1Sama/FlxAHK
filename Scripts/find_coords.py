"""
أداة لمعرفة إحداثيات زر Retry بدقة.
شغّله مع ظهور رسالة الخطأ، يعطيك إحداثيات مؤشر الماوس كل ثانية.
ضع المؤشر على زر Retry واقرأ الإحداثيات.
"""
import pyautogui, time

print("ضع الماوس على زر Retry...")
print("Ctrl+C للإيقاف\n")

try:
    while True:
        x, y = pyautogui.position()
        import ctypes
        sw = ctypes.windll.user32.GetSystemMetrics(0)
        sh = ctypes.windll.user32.GetSystemMetrics(1)
        print(f"  pos=({x},{y})  ratio=({x/sw:.3f}, {y/sh:.3f})", end="\r", flush=True)
        time.sleep(0.1)
except KeyboardInterrupt:
    x, y = pyautogui.position()
    import ctypes
    sw = ctypes.windll.user32.GetSystemMetrics(0)
    sh = ctypes.windll.user32.GetSystemMetrics(1)
    print(f"\nFinal: ({x},{y})  ratio=({x/sw:.3f}, {y/sh:.3f})")
    print(f"\nاكتب هذا في accepter_helper.py:")
    print(f"    retry_x = int(sw * {x/sw:.3f})")
    print(f"    retry_y = int(sh * {y/sh:.3f})")
