"""FlxShow.py — مشغّل خفيف للواجهة.

المقام الأول للسرعة: إن كانت الواجهة مقيمة بالخلفية (named pipe موجود)
نرسل لها أمر show خلال ~0.2 ثانية بدون استيراد PySide6 إطلاقًا، ثم نخرج.
وإلا نشغّل FlxGUI.py كاملًا (إقلاع النسخة الأولى فقط هو البطيء).
"""

import ctypes
import os

PIPE_PATH = r"\\.\pipe\FlxAHK_GUI"

GENERIC_WRITE = 0x40000000
OPEN_EXISTING = 3

_kernel32 = ctypes.windll.kernel32


def send_command(cmd: str) -> bool:
    """إرسال أمر للنسخة المقيمة عبر الـ named pipe. يعيد True إذا وُجد مستقبِل."""
    handle = _kernel32.CreateFileW(
        PIPE_PATH, GENERIC_WRITE, 0, None, OPEN_EXISTING, 0, None
    )
    if handle == -1 or handle == 0:
        return False
    try:
        data = (cmd + "\n").encode("utf-8")
        written = ctypes.c_ulong(0)
        ok = _kernel32.WriteFile(handle, data, len(data), ctypes.byref(written), None)
        return bool(ok)
    finally:
        _kernel32.CloseHandle(handle)


def main():
    if send_command("show"):
        return  # نسخة مقيمة موجودة — طلبنا إظهارها وانتهى دورنا بسرعة
    # لا نسخة مقيمة: إقلاع كامل للواجهة
    import runpy

    gui_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "FlxGUI.py")
    runpy.run_path(gui_path, run_name="__main__")


if __name__ == "__main__":
    main()
