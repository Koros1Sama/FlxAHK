"""
FlxGUI.py — واجهة FlxAHK الحديثة (PySide6).

نافذة واحدة موحّدة بشريط جانبي تستبدل نوافذ AHK القديمة لإدارة الاختصارات والإعدادات.
تعمل بشكل مستقل، وإذا كان Flx.ahk يعمل ترسل له رسالة PostMessage لإعادة تحميل الإعدادات فورًا.

التشغيل:  pythonw FlxGUI.py
"""

import os
import re
import sys
import glob
import ctypes
import subprocess
import contextlib
from ctypes import wintypes

from PySide6.QtCore import (
    Qt,
    QTimer,
    QThread,
    QPropertyAnimation,
    QEasingCurve,
    QSettings,
    QEvent,
    QObject,
)
from PySide6.QtGui import QFont, QKeySequence, QCursor, QShortcut
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QLabel,
    QPushButton,
    QLineEdit,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QStackedWidget,
    QListWidget,
    QComboBox,
    QCheckBox,
    QFileDialog,
    QTableWidget,
    QTableWidgetItem,
    QHeaderView,
    QMessageBox,
    QInputDialog,
    QPlainTextEdit,
    QAbstractItemView,
    QButtonGroup,
    QFrame,
    QGroupBox,
    QRadioButton,
    QSpinBox,
    QStyle,
    QSystemTrayIcon,
    QGraphicsOpacityEffect,
    QDialog,
    QMenu,
)

from ini_manager import (
    FlxConfig,
    HotkeyEntry,
    join_fullkey,
    split_fullkey,
    strip_modifiers,
    display_key,
)

# ------------------------------------------------------------------ paths

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPTS_DIR)
INI_PATH = os.path.join(BASE_DIR, "Flx_Settings.ini")
THEME_PATH = os.path.join(SCRIPTS_DIR, "flx_theme.qss")

# ------------------------------------------------------------------ IPC مع Flx.ahk

WM_APP = 0x8000
RELOAD_WPARAM = 0x464C58  # "FLX"

_user32 = ctypes.windll.user32
_kernel32 = ctypes.windll.kernel32


def find_flx_ahk_window():
    """البحث عن النافذة المخفية لـ Flx.ahk (كلاس AutoHotkey والعنوان يحوي اسم الملف)."""
    result = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _lparam):
        buf = ctypes.create_unicode_buffer(256)
        _user32.GetClassNameW(hwnd, buf, 256)
        if buf.value != "AutoHotkey":
            return True
        title = ctypes.create_unicode_buffer(512)
        _user32.GetWindowTextW(hwnd, title, 512)
        t = title.value.lower()
        if "flx.ahk" in t or "flx.exe" in t:
            result.append(hwnd)
            return False
        return True

    _user32.EnumWindows(cb, 0)
    return result[0] if result else None


def post_reload():
    """إرسال طريقة إعادة التحميل إلى Flx.ahk. يعيد True إذا نجح الإرسال."""
    hwnd = find_flx_ahk_window()
    if not hwnd:
        return False
    return bool(_user32.PostMessageW(hwnd, WM_APP, RELOAD_WPARAM, 0))


def is_key_pressed(vk):
    return bool(_user32.GetAsyncKeyState(vk) & 0x8000)


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def get_cursor_pos():
    pt = POINT()
    _user32.GetCursorPos(ctypes.byref(pt))
    return pt.x, pt.y


def window_from_point(x, y):
    hwnd = _user32.WindowFromPoint(POINT(x, y))
    return hwnd or None


def get_root_window(hwnd):
    return _user32.GetAncestor(hwnd, 2) or hwnd  # GA_ROOT


def get_window_pid(hwnd):
    pid = wintypes.DWORD()
    _user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return pid.value


def get_window_exe(hwnd):
    pid = wintypes.DWORD()
    _user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if not pid.value:
        return ""
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    handle = _kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
    if not handle:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(2048)
        size = wintypes.DWORD(2048)
        if _kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return os.path.basename(buf.value)
        return ""
    finally:
        _kernel32.CloseHandle(handle)


# ------------------------------------------------------------------ خرائط المفاتيح

VK_NAMES = {
    0x08: "Backspace",
    0x09: "Tab",
    0x0D: "Enter",
    0x13: "Pause",
    0x14: "CapsLock",
    0x20: "Space",
    0x21: "PgUp",
    0x22: "PgDn",
    0x23: "End",
    0x24: "Home",
    0x25: "Left",
    0x26: "Up",
    0x27: "Right",
    0x28: "Down",
    0x2D: "Insert",
    0x2E: "Delete",
    0x5D: "AppsKey",
    0x6A: "NumpadMult",
    0x6B: "NumpadAdd",
    0x6D: "NumpadSub",
    0x6E: "NumpadDot",
    0x6F: "NumpadDiv",
    0x90: "NumLock",
    0x91: "ScrollLock",
    0xBA: ";",
    0xBB: "=",
    0xBC: ",",
    0xBD: "-",
    0xBE: ".",
    0xBF: "/",
    0xC0: "`",
    0xDB: "[",
    0xDC: "\\",
    0xDD: "]",
    0xDE: "'",
    0xE2: "\\",
}

EXCLUDED_VKS = (
    set(range(0x01, 0x07))
    | set(range(0x0A, 0x10))
    | {
        0x10,
        0x11,
        0x12,
        0x1B,
        0x5B,
        0x5C,
        0xA0,
        0xA1,
        0xA2,
        0xA3,
        0xA4,
        0xA5,
    }
)


def vk_to_name(vk):
    if vk in VK_NAMES:
        return VK_NAMES[vk]
    if 0x30 <= vk <= 0x39:
        return chr(vk)
    if 0x41 <= vk <= 0x5A:
        return chr(vk)
    if 0x60 <= vk <= 0x69:
        return f"Numpad{vk - 0x60}"
    if 0x70 <= vk <= 0x87:
        return f"F{vk - 0x6F}"
    return f"VK{vk:02X}"


# ------------------------------------------------------------------ أدوات واجهة


def load_stylesheet(app):
    if os.path.exists(THEME_PATH):
        try:
            with open(THEME_PATH, encoding="utf-8") as f:
                app.setStyleSheet(f.read())
        except OSError:
            pass  # بدون الثيم تعمل الواجهة بالشكل الافتراضي


def vline():
    line = QFrame()
    line.setObjectName("StripDivider")
    line.setFrameShape(QFrame.Shape.VLine)
    line.setFixedHeight(36)
    return line


class StatCard(QWidget):
    """قيمة إحصائية داخل الشريط العلوي (بلا إطار — الإطار للشريط كله)."""

    def __init__(self, label, value="--", mono=False):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(3)
        self.value_label = QLabel(value)
        self.value_label.setObjectName("StatValueMono" if mono else "StatValue")
        self.value_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.text_label = QLabel(label)
        self.text_label.setObjectName("StatLabel")
        self.text_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.value_label)
        lay.addWidget(self.text_label)

    def set_value(self, value):
        self.value_label.setText(str(value))

    def set_value_object_name(self, name):
        """تبديل هوية التنسيق (مثل تلوين حالة وضع التسريع) مع إعادة التلوين."""
        self.value_label.setObjectName(name)
        style = self.value_label.style()
        style.unpolish(self.value_label)
        style.polish(self.value_label)


# ------------------------------------------------------------------ حوار اكتشاف المفتاح


class KeyDetectDialog(QMessageBox):
    """ينتظر ضغط مفتاح فعلي ويكشف رمزه (مثل DetectKey في AHK)."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("اكتشاف المفتاح")
        self.setText(
            "اضغط المفتاح الذي تريد رصده الآن…\n(سيتم الإلغاء تلقائيًا بعد 10 ثوانٍ)"
        )
        self.setIcon(QMessageBox.Icon.Information)
        self.setStandardButtons(QMessageBox.StandardButton.Cancel)
        self.detected = None
        self._elapsed = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self._poll)
        self.timer.start(25)

    def _poll(self):
        self._elapsed += 25
        if self._elapsed >= 10000:
            self.timer.stop()
            self.reject()
            return
        for vk in range(0x07, 0xFE):
            if vk in EXCLUDED_VKS:
                continue
            if is_key_pressed(vk):
                self.timer.stop()
                self.detected = vk_to_name(vk)
                self.accept()
                return

    @staticmethod
    def detect(parent=None):
        dlg = KeyDetectDialog(parent)
        dlg.exec()
        return dlg.detected


# ------------------------------------------------------------------ حوار التقاط نافذة


class WindowPickMixin(QWidget):
    """منطق "انقر على نافذة لالتقاط ahk_exe الخاص بها"."""

    def pick_window_condition(self, line_edit):
        main = self.window()
        main.hide()
        QApplication.processEvents()
        info = QMessageBox(
            QMessageBox.Icon.Information,
            "التقاط نافذة",
            "انقر على النافذة المستهدفة خلال 12 ثانية.\n"
            "النقر على نوافذ هذه الأداة لا يُحتسب.",
        )
        info.show()
        QApplication.processEvents()
        QTimer.singleShot(400, info.hide)

        my_pid = os.getpid()

        def wait_for_click(timeout_ms):
            """ينتظر ضغطة يسرى على نافذة خارجية. يعيد (تم، hwnd الجذر)."""
            waited = 0
            while waited < 1500 and is_key_pressed(0x01):
                QApplication.processEvents()
                QThread.msleep(25)
                waited += 25
            while waited < timeout_ms:
                QApplication.processEvents()
                if is_key_pressed(0x01):
                    x, y = get_cursor_pos()
                    hwnd = window_from_point(x, y)
                    root = get_root_window(hwnd) if hwnd else None
                    if root and get_window_pid(root) != my_pid:
                        return True, root
                    # نقرة على نوافذ الأداة نفسها — تُتجاهل ويُعاد الانتظار
                    release = 0
                    while release < 1500 and is_key_pressed(0x01):
                        QApplication.processEvents()
                        QThread.msleep(25)
                        release += 25
                        waited += 25
                    continue
                QThread.msleep(30)
                waited += 30
            return False, None

        clicked, root_hwnd = wait_for_click(12000)
        condition = ""
        if clicked:
            exe = get_window_exe(root_hwnd)
            if exe:
                condition = "ahk_exe " + exe

        info.hide()
        main.show()
        main.activateWindow()
        if condition:
            line_edit.setText(condition)
        elif clicked:
            QMessageBox.warning(
                main, "خطأ", "لم يتم العثور على عملية مرتبطة بالنافذة المختارة."
            )
        else:
            QMessageBox.warning(main, "خطأ", "لم يتم النقر على أي نافذة خلال المهلة.")


# ------------------------------------------------------------------ بناء نص الإجراء

ACTION_TYPES = [
    ("app", "فتح تطبيق"),
    ("file", "فتح ملف"),
    ("folder", "فتح مجلد"),
    ("manual", "أمر يدوي"),
    ("text", "إرسال نص"),
    ("script_existing", "سكربت موجود"),
    ("script_code", "كود سكربت جديد"),
]

TYPE_INDEX = {code: i for i, (code, _label) in enumerate(ACTION_TYPES)}


def build_action(atype, payload):
    """تحويل نوع الإضافة وقيمتها إلى سطر الإجراء المخزن في INI."""
    if atype in ("app", "file", "folder"):
        return "Run " + payload.strip()
    if atype == "manual":
        return payload.strip()
    if atype == "text":
        return "Send " + payload
    if atype == "script_existing":
        raise ValueError("script_existing يجب أن يُعالج عبر مسار خاص")
    raise ValueError(f"نوع غير معروف: {atype}")


# ------------------------------------------------------------------ حوار تعديل اختصار


class HotkeyEditDialog(WindowPickMixin, QDialog):
    """تعديل اختصار موجود — حوار مشروط (Modal) يمنع تضارب الحفظ."""

    MAX_INLINE_SCRIPT_BYTES = 150 * 1024

    def __init__(self, parent, cfg: FlxConfig, entry: HotkeyEntry, on_saved):
        super().__init__(parent)
        self.cfg = cfg
        self.entry = entry
        self.on_saved = on_saved
        self.setWindowTitle("تعديل الاختصار")
        self.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        self.setMinimumWidth(560)
        self._build_ui()
        self._load_entry()

    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setSpacing(10)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(8)

        grid.addWidget(QLabel("المفتاح:"), 0, 0)
        self.key_edit = QLineEdit()
        grid.addWidget(self.key_edit, 0, 1)
        self.detect_btn = QPushButton("اكتشاف")
        self.detect_btn.clicked.connect(self._detect_key)
        grid.addWidget(self.detect_btn, 0, 2)

        mods = QHBoxLayout()
        self.chk_flx = QCheckBox("Flx")
        self.chk_ctrl = QCheckBox("Ctrl")
        self.chk_shift = QCheckBox("Shift")
        self.chk_alt = QCheckBox("Alt")
        self.chk_win = QCheckBox("Win")
        for c in (
            self.chk_flx,
            self.chk_ctrl,
            self.chk_shift,
            self.chk_alt,
            self.chk_win,
        ):
            mods.addWidget(c)
        mods.addStretch()
        grid.addLayout(mods, 1, 1, 1, 2)

        grid.addWidget(QLabel("النافذة النشطة (اختياري):"), 2, 0)
        self.cond_edit = QLineEdit()
        self.cond_edit.setPlaceholderText("مثال: ahk_exe explorer.exe")
        grid.addWidget(self.cond_edit, 2, 1)
        pick_btn = QPushButton("التقاط نافذة")
        pick_btn.clicked.connect(lambda: self.pick_window_condition(self.cond_edit))
        grid.addWidget(pick_btn, 2, 2)

        root.addLayout(grid)

        # منطقة الإجراء حسب النوع
        self.action_stack = QStackedWidget()

        # صفحة إجراء نصي بسيط
        simple_page = QWidget()
        sl = QVBoxLayout(simple_page)
        sl.addWidget(QLabel("الإجراء:"))
        self.simple_action = QLineEdit()
        sl.addWidget(self.simple_action)
        self.action_stack.addWidget(simple_page)

        # صفحة سكربت متقدم
        adv_page = QWidget()
        al = QVBoxLayout(adv_page)
        mode_row = QHBoxLayout()
        self.rb_existing = QRadioButton("سكربت موجود:")
        self.rb_code = QRadioButton("كود يدوي:")
        self.rb_existing.setChecked(True)
        mode_row.addWidget(self.rb_existing)
        mode_row.addWidget(self.rb_code)
        mode_row.addStretch()
        al.addLayout(mode_row)
        self.script_combo = QComboBox()
        self.script_combo.addItems(list_scripts())
        al.addWidget(self.script_combo)
        al.addWidget(QLabel("أو حرّر الكود مباشرة (سيُحفظ في ملف السكربت):"))
        self.code_edit = QPlainTextEdit()
        self.code_edit.setMinimumHeight(140)
        al.addWidget(self.code_edit)
        self.script_name_edit = QLineEdit()
        self.script_name_edit.setPlaceholderText(
            "اسم ملف السكربت عند الحفظ (بدون .ahk)"
        )
        al.addWidget(self.script_name_edit)
        self.rb_existing.toggled.connect(self._sync_adv_mode)
        self._sync_adv_mode()
        self.action_stack.addWidget(adv_page)

        root.addWidget(self.action_stack)

        btns = QHBoxLayout()
        save_btn = QPushButton("حفظ")
        save_btn.setObjectName("PrimaryButton")
        save_btn.setDefault(True)
        save_btn.clicked.connect(self._save)
        del_btn = QPushButton("حذف")
        del_btn.setObjectName("DangerButton")
        del_btn.clicked.connect(self._delete)
        cancel_btn = QPushButton("إلغاء")
        cancel_btn.clicked.connect(self.reject)
        self.locate_btn = QPushButton("فتح موقع السكربت")
        self.locate_btn.clicked.connect(self._open_location)
        btns.addWidget(save_btn)
        btns.addWidget(del_btn)
        btns.addWidget(cancel_btn)
        btns.addStretch()
        btns.addWidget(self.locate_btn)
        root.addLayout(btns)

    def _sync_adv_mode(self):
        self.script_combo.setEnabled(self.rb_existing.isChecked())
        self.code_edit.setEnabled(not self.rb_existing.isChecked())
        self.script_name_edit.setEnabled(not self.rb_existing.isChecked())

    def _detect_key(self):
        name = KeyDetectDialog.detect(self)
        if name:
            self.key_edit.setText(name)

    def _load_entry(self):
        e = self.entry
        self.key_edit.setText(display_key(e.key))
        self.cond_edit.setText(e.condition)
        self.chk_flx.setChecked(e.kind != "noflx")
        self.chk_ctrl.setChecked("^" in e.key)
        self.chk_shift.setChecked("+" in e.key)
        self.chk_alt.setChecked("!" in e.key)
        self.chk_win.setChecked("#" in e.key)

        if e.kind == "advanced":
            self.action_stack.setCurrentIndex(1)
            path = e.resolved_script_path(BASE_DIR)
            too_big = False
            size_kb = 0
            if path and os.path.exists(path):
                try:
                    size_kb = os.path.getsize(path) // 1024
                    too_big = size_kb * 1024 > self.MAX_INLINE_SCRIPT_BYTES
                except OSError:
                    too_big = False
            if path and os.path.exists(path) and not too_big:
                try:
                    with open(path, encoding="utf-8-sig", errors="replace") as f:
                        self.code_edit.setPlainText(f.read())
                except OSError:
                    too_big = True
            elif too_big:
                self.code_edit.setPlaceholderText(
                    f"الملف كبير على العرض هنا ({size_kb} KB).\n"
                    'استخدم "سكربت موجود" للاحتفاظ به كما هو، أو زر "فتح موقع السكربت" '
                    "لتحريره بمحرر خارجي."
                )
            self.script_name_edit.setText(
                os.path.splitext(os.path.basename(e.action))[0]
            )
            idx = self.script_combo.findText(
                os.path.splitext(os.path.basename(e.action))[0]
            )
            if idx >= 0:
                self.script_combo.setCurrentIndex(idx)
            self.rb_code.setEnabled(not too_big)
            if too_big:
                self.rb_existing.setChecked(True)
                self.rb_code.setToolTip(
                    "معطّل لأن ملف السكربت كبير جدًا على التحرير المضمّن"
                )
            self.locate_btn.setVisible(True)
        else:
            self.action_stack.setCurrentIndex(0)
            self.simple_action.setText(e.action)
            self.locate_btn.setVisible(False)

    def _compose_fullkey(self):
        key = self.key_edit.text().strip()
        if not key:
            raise ValueError("يرجى إدخال مفتاح.")
        prefix = (
            ("^" if self.chk_ctrl.isChecked() else "")
            + ("+" if self.chk_shift.isChecked() else "")
            + ("!" if self.chk_alt.isChecked() else "")
            + ("#" if self.chk_win.isChecked() else "")
        )
        return join_fullkey(prefix + key, self.cond_edit.text().strip())

    def _ask_script_name(self, default):
        name, ok = QInputDialog.getText(
            self, "اسم السكربت", "أدخل اسمًا للسكربت (بدون .ahk):", text=default
        )
        if not ok or not name.strip():
            return None
        name = name.strip()
        if not name.lower().endswith(".ahk"):
            name += ".ahk"
        return name

    def _write_script_file(self, filename, content):
        path = os.path.join(SCRIPTS_DIR, filename)
        try:
            with open(path, "w", encoding="utf-8-sig", newline="\r\n") as f:
                f.write(content.rstrip("\n") + "\n")
        except OSError as exc:
            QMessageBox.critical(self, "خطأ", f"فشل حفظ ملف السكربت:\n{exc}")
            return None
        return path

    def _check_script_name_conflict(self, script_path_rel, exclude_fullkey):
        for hk in self.cfg.iter_hotkeys():
            if hk.fullkey.lower() == exclude_fullkey.lower():
                continue
            if hk.action.replace("/", "\\") == script_path_rel.replace("/", "\\"):
                return hk
        return None

    def _save(self):
        try:
            new_fullkey = self._compose_fullkey()
        except ValueError as exc:
            QMessageBox.warning(self, "خطأ", str(exc))
            return

        use_flx = self.chk_flx.isChecked()
        old = self.entry
        exclude_fk = None if self._is_new_entry(old) else old.fullkey
        conflict = self.cfg.find_conflict(
            new_fullkey, exclude_kind=None, exclude_fullkey=exclude_fk
        )
        if conflict:
            ans = QMessageBox.question(
                self,
                "تحذير",
                f"المفتاح مستخدم بالفعل:\n{describe_conflict(conflict)}\nهل تريد استبداله؟",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if ans != QMessageBox.StandardButton.Yes:
                return

        kind = (
            "advanced"
            if use_flx and old.kind == "advanced"
            else ("noflx" if not use_flx else "simple")
        )

        try:
            if old.kind == "advanced":
                # متقدم: إما سكربت موجود أو كود يدوي
                if self.rb_existing.isChecked():
                    name = self.script_combo.currentText().strip()
                    if not name:
                        QMessageBox.warning(self, "خطأ", "اختر سكربتًا من القائمة.")
                        return
                    if use_flx:
                        rel = "Scripts\\" + name + ".ahk"
                    else:
                        rel = name + ".ahk"
                    if not os.path.exists(os.path.join(SCRIPTS_DIR, name + ".ahk")):
                        QMessageBox.warning(self, "خطأ", "السكربت غير موجود: " + name)
                        return
                    clash = self._check_script_name_conflict(rel, new_fullkey)
                    if clash:
                        QMessageBox.warning(
                            self,
                            "خطأ",
                            f"السكربت مستخدم بالفعل لاختصار آخر:\n{clash.fullkey}",
                        )
                        return
                    kind = "advanced" if use_flx else "noflx"
                    new_action = rel
                else:
                    code = self.code_edit.toPlainText()
                    if not code.strip():
                        QMessageBox.warning(self, "خطأ", "يرجى إدخال كود السكربت.")
                        return
                    warn = v2_syntax_warning(code)
                    if warn and not confirm_v2_code(self, warn):
                        return
                    default_name = (
                        strip_modifiers(split_fullkey(new_fullkey)[0]) or "script"
                    )
                    name = self._ask_script_name(
                        self.script_name_edit.text() or default_name
                    )
                    if not name:
                        return
                    clash = self._check_script_name_conflict(
                        "Scripts\\" + name, new_fullkey
                    )
                    if clash:
                        QMessageBox.warning(
                            self,
                            "خطأ",
                            f"اسم السكربت مستخدم بالفعل لاختصار آخر:\n{clash.fullkey}",
                        )
                        return
                    self._write_script_file(name, code)
                    new_action = ("Scripts\\" + name) if use_flx else name
                    kind = "advanced" if use_flx else "noflx"
            else:
                action_text = self.simple_action.text().strip()
                if not action_text:
                    QMessageBox.warning(self, "خطأ", "يرجى إدخال الإجراء.")
                    return
                new_action = action_text
                kind = "simple" if use_flx else "noflx"

            self.cfg.upsert_hotkey(kind, new_fullkey, new_action)
            self.cfg.save()
        except Exception as exc:  # noqa: BLE001
            QMessageBox.critical(self, "خطأ", f"فشل الحفظ:\n{exc}")
            return

        post_reload()
        self.on_saved()
        self.accept()

    @staticmethod
    def _is_new_entry(entry):
        return entry is None or getattr(entry, "kind", None) is None

    def _delete(self):
        if self._is_new_entry(self.entry):
            self.reject()
            return
        cond_text = self.entry.condition or "غير محدد"
        ans = QMessageBox.question(
            self,
            "تأكيد",
            f'هل تريد حذف الاختصار "{display_key(self.entry.key)}" '
            f'مع شرط النافذة "{cond_text}"؟',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if ans != QMessageBox.StandardButton.Yes:
            return
        self.cfg.remove_hotkey_everywhere(self.entry.fullkey)
        self.cfg.save()
        post_reload()
        self.on_saved()
        self.accept()

    def _open_location(self):
        path = self.entry.resolved_script_path(BASE_DIR)
        if path and os.path.exists(path):
            subprocess.run(["explorer.exe", "/select,", path], check=False)
        else:
            QMessageBox.warning(self, "خطأ", "لا يمكن العثور على موقع السكربت.")


def describe_conflict(entry):
    return f"{display_key(entry.key)} -> {entry.action[:80]} ({entry.type_label})"


def list_scripts():
    files = sorted(glob.glob(os.path.join(SCRIPTS_DIR, "*.ahk")))
    return [
        os.path.splitext(os.path.basename(f))[0]
        for f in files
        if os.path.basename(f).lower() not in ("gdip.ahk", "test_image.ahk")
    ]


# ------------------------------------------------------------------ فحص صيغة v2

V2_MARKERS = ("#Requires AutoHotkey v2", "#Requires AutoHotkey")


def v2_syntax_warning(code):
    """يكشف كودًا بصيغة AutoHotkey v2 — محرك Flx يشغل السكربتات بـ v1 فتنكسر.

    الدليلان الحاسمان: توجيه #Requires، أو نصوص بعلامة اقتباس مفردة
    '…' في موضع تعبير (حصرية v2 — v1 لا يقبلها ويطلق
    "leftmost character is illegal in an expression").
    """
    head = "\n".join(code.splitlines()[:30])
    for marker in V2_MARKERS:
        if marker in head:
            return f"السكربت يطلب AutoHotkey v2 صراحة: {marker}"
    for line in code.splitlines():
        if line.lstrip().startswith(";"):
            continue  # تعليق — لا يُفحص
        if re.search(r"(:=\s*|\(\s*)'", line):
            return "نصوص بعلامة اقتباس مفردة '…' — صيغة v2 فقط (v1 يستخدم \"…\" حصريًا)"
    return None


def confirm_v2_code(parent, reason):
    """تحذير موحد عند لصق كود v2 — يوقف الحفظ ما لم يصرّح المستخدم."""
    ans = QMessageBox.question(
        parent,
        "تحذير: الكود يبدو بصيغة AutoHotkey v2",
        f"{reason}\n\nمحرك Flx يشغّل السكربتات بـ AutoHotkey v1 —"
        " هذا السكربت سينكسر عند التشغيل غالبًا\n"
        "(الخطأ النموذجي: leftmost character is illegal in an expression).\n\n"
        'الحل: أعد كتابته بصيغة v1 (النصوص "…" فقط).\n'
        "حفظه كما هو رغم ذلك؟",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        QMessageBox.StandardButton.No,
    )
    return ans == QMessageBox.StandardButton.Yes


# ------------------------------------------------------------------ جدول الاختصارات المشترك

HOTKEY_COLUMNS = ["المفتاح", "النافذة", "الإجراء", "النوع"]

MONO_FONT = QFont("Consolas", 9)
MISSING_MARKER = "  — الملف غير موجود"


def fill_table(table: QTableWidget, entries):
    table.setRowCount(0)
    for entry in entries:
        row = table.rowCount()
        table.insertRow(row)
        item_key = QTableWidgetItem(display_key(entry.key))
        item_key.setData(Qt.ItemDataRole.UserRole, (entry.kind, entry.fullkey))
        item_key.setToolTip(entry.fullkey)
        table.setItem(row, 0, item_key)
        table.setItem(row, 1, QTableWidgetItem(entry.condition or "غير محدد"))
        action_display = entry.action
        if entry.kind == "advanced" and not os.path.exists(
            entry.resolved_script_path(BASE_DIR) or ""
        ):
            action_display += MISSING_MARKER
        item_action = QTableWidgetItem(action_display)
        item_action.setFont(MONO_FONT)
        item_action.setToolTip(entry.action)
        table.setItem(row, 2, item_action)
        table.setItem(row, 3, QTableWidgetItem(entry.type_label))
    table.resizeColumnsToContents()
    if table.columnCount() == 4 and table.columnWidth(2) < 260:
        table.setColumnWidth(2, 260)
    return table.rowCount()


def make_table():
    table = QTableWidget(0, 4)
    table.setHorizontalHeaderLabels(HOTKEY_COLUMNS)
    table.verticalHeader().setVisible(False)
    table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
    table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
    table.setAlternatingRowColors(True)
    header = table.horizontalHeader()
    header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
    return table


def apply_search(table: QTableWidget, term):
    term = term.strip().lower()
    for row in range(table.rowCount()):
        visible = term == ""
        if not visible:
            for col in range(table.columnCount()):
                item = table.item(row, col)
                if item and term in item.text().lower():
                    visible = True
                    break
        table.setRowHidden(row, not visible)


def selected_entry(table: QTableWidget):
    row = table.currentRow()
    if row < 0:
        return None
    item = table.item(row, 0)
    if not item:
        return None
    kind, fullkey = item.data(Qt.ItemDataRole.UserRole)
    item_action = table.item(row, 2)
    action = (item_action.text() if item_action else "").replace(MISSING_MARKER, "")
    return HotkeyEntry(kind, fullkey, action)


# ------------------------------------------------------------------ حالة الفراغ + قائمة السياق


def attach_empty_state(
    view, empty_text="لا يوجد شيء هنا بعد", filtered_text="لا نتائج مطابقة للبحث"
):
    """يعرض رسالة وسط الجدول/القائمة عند الفراغ أو عدم وجود نتائج بحث."""
    lbl = QLabel(empty_text, view.viewport())
    lbl.setObjectName("EmptyState")
    lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
    lbl.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
    lbl.hide()

    def reposition():
        vp = view.viewport()
        lbl.setGeometry(0, 0, vp.width(), vp.height())

    def update():
        if isinstance(view, QTableWidget):
            total = view.rowCount()
            visible = sum(1 for r in range(total) if not view.isRowHidden(r))
        else:
            total = view.count()
            visible = total
        if total == 0:
            lbl.setText(empty_text)
            lbl.show()
        elif visible == 0:
            lbl.setText(filtered_text)
            lbl.show()
        else:
            lbl.hide()
        reposition()

    class _ResizeFilter(QObject):
        def eventFilter(self, obj, event):
            if event.type() == QEvent.Type.Resize:
                reposition()
            return False

    view.installEventFilter(_ResizeFilter(view))
    view._update_empty_state = update
    return update


def delete_entries(ctx, entries):
    """حذف مجموعة اختصارات مع تأكيد واحد ونسخة احتياطية تلقائية."""
    entries = [e for e in entries if e]
    if not entries:
        return False
    names = "\n".join(display_key(e.key) for e in entries[:6])
    if len(entries) > 6:
        names += "\n…"
    ans = QMessageBox.question(
        ctx,
        "تأكيد الحذف",
        f"سيُزال {len(entries)} اختصارًا نهائيًا من الإعدادات:\n{names}\n"
        "(تُحفظ نسخة احتياطية قبل التعديل)",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
    )
    if ans != QMessageBox.StandardButton.Yes:
        return False
    cfg = ctx.config()
    for entry in entries:
        cfg.remove_hotkey_everywhere(entry.fullkey)
    cfg.save()
    sent = post_reload()
    ctx.refresh_all()
    ctx.show_status(
        f"تم حذف {len(entries)} اختصارًا" + ("" if sent else " (المحرك غير مشغّل)")
    )
    return True


def show_hotkey_context_menu(parent, entry, on_edit, on_delete):
    """قائمة زر أيمن موحدة لصفوف الاختصارات."""
    if entry is None:
        return
    menu = QMenu(parent)
    act_edit = menu.addAction("تعديل…")
    act_copy = menu.addAction("نسخ الإجراء")
    act_locate = None
    script_path = entry.resolved_script_path(BASE_DIR)
    if entry.is_script_action and script_path and os.path.exists(script_path):
        act_locate = menu.addAction("فتح موقع السكربت")
    menu.addSeparator()
    act_del = menu.addAction("حذف")
    chosen = menu.exec(QCursor.pos())
    if chosen == act_edit:
        on_edit()
    elif chosen == act_copy:
        QApplication.clipboard().setText(entry.action)
    elif act_locate is not None and chosen == act_locate:
        subprocess.run(["explorer.exe", "/select,", script_path], check=False)
    elif chosen == act_del:
        on_delete()


# ------------------------------------------------------------------ الصفحة 1: الرئيسية


class HomePage(QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        lay = QVBoxLayout(self)
        lay.setContentsMargins(20, 20, 20, 24)
        lay.setSpacing(12)

        title = QLabel("الرئيسية")
        title.setObjectName("PageTitle")
        subtitle = QLabel(
            "كل الاختصارات وحالة النظام في مكان واحد — نقرة مزدوجة للتعديل، زر أيمن للمزيد"
        )
        subtitle.setObjectName("Subtitle")
        lay.addWidget(title)
        lay.addWidget(subtitle)

        strip = QFrame()
        strip.setObjectName("StatStrip")
        row = QHBoxLayout(strip)
        row.setContentsMargins(22, 14, 22, 14)
        row.setSpacing(16)
        self.stat_total = StatCard("إجمالي الاختصارات")
        self.stat_advanced = StatCard("سكربتات متقدمة")
        self.stat_files = StatCard("ملفات Scripts")
        self.stat_basekey = StatCard("زر Flx", mono=True)
        self.stat_secure = StatCard("وضع التسريع")
        cards = (
            self.stat_total,
            self.stat_advanced,
            self.stat_files,
            self.stat_basekey,
            self.stat_secure,
        )
        for i, card in enumerate(cards):
            row.addWidget(card, 1)
            if i < len(cards) - 1:
                row.addWidget(vline())
        lay.addWidget(strip)

        search_row = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setObjectName("SearchField")
        self.search.setPlaceholderText("بحث فوري في كل الأعمدة…  (Ctrl+F)")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self._filter)
        search_row.addWidget(self.search, 1)
        refresh_btn = QPushButton("تحديث  (F5)")
        refresh_btn.setToolTip("إعادة قراءة الإعدادات من الملف ومزامنة العرض")
        refresh_btn.clicked.connect(self.refresh)
        search_row.addWidget(refresh_btn)
        lay.addLayout(search_row)

        self.table = make_table()
        self.table.doubleClicked.connect(self._edit_selected)
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self._context_menu)
        lay.addWidget(self.table, 1)

        self._empty = attach_empty_state(self.table)
        delete_shortcut = QShortcut(QKeySequence.StandardKey.Delete, self.table)
        delete_shortcut.activated.connect(self._delete_selected)

    def _filter(self, term):
        apply_search(self.table, term)
        self._empty()

    def refresh(self):
        cfg = self.ctx.config()
        entries = list(cfg.iter_hotkeys())
        fill_table(self.table, entries)
        self._empty()
        self.stat_total.set_value(len(entries))
        self.stat_advanced.set_value(sum(1 for e in entries if e.kind == "advanced"))
        self.stat_files.set_value(len(glob.glob(os.path.join(SCRIPTS_DIR, "*.ahk"))))
        self.stat_basekey.set_value(cfg.get_base_hotkey())
        settings = cfg.get_settings()
        secure_on = settings.get("IsSecureMode", "0") in ("1", "true", "True")
        self.stat_secure.set_value_object_name("StateOk" if secure_on else "StateBad")
        self.stat_secure.set_value("مفعّل" if secure_on else "متوقف")

    def _edit_selected(self):
        entry = selected_entry(self.table)
        if entry:
            self.ctx.open_edit_dialog(entry)

    def _delete_selected(self):
        entry = selected_entry(self.table)
        if entry and delete_entries(self.ctx, [entry]):
            self.refresh()

    def _context_menu(self, pos):
        entry = selected_entry(self.table)
        show_hotkey_context_menu(
            self.table,
            entry,
            on_edit=self._edit_selected,
            on_delete=self._delete_selected,
        )


# ------------------------------------------------------------------ الصفحة 2: اختصار جديد


class AddPage(WindowPickMixin, QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        self.setAcceptDrops(True)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(18, 18, 18, 18)
        lay.setSpacing(12)

        title = QLabel("⌨ اختصار جديد")
        title.setObjectName("PageTitle")
        subtitle = QLabel("كل أنواع الاختصارات من نموذج واحد بدل خمس نوافذ")
        subtitle.setObjectName("Subtitle")
        lay.addWidget(title)
        lay.addWidget(subtitle)

        form = QGridLayout()
        form.setHorizontalSpacing(10)
        form.setVerticalSpacing(8)

        form.addWidget(QLabel("المفتاح:"), 0, 0)
        self.key_edit = QLineEdit()
        self.key_edit.setPlaceholderText("مثال: T  أو  =  أو  Numpad1")
        self.key_edit.textChanged.connect(
            lambda: self._mark_invalid(self.key_edit, False)
        )
        form.addWidget(self.key_edit, 0, 1)
        detect_btn = QPushButton("اكتشاف")
        detect_btn.setToolTip("اضغط هنا ثم اضغط أي مفتاح على الكيبورد لرصده تلقائيًا")
        detect_btn.clicked.connect(self._detect_key)
        form.addWidget(detect_btn, 0, 2)

        mods = QHBoxLayout()
        self.chk_flx = QCheckBox("Flx")
        self.chk_flx.setChecked(True)
        self.chk_ctrl = QCheckBox("Ctrl")
        self.chk_shift = QCheckBox("Shift")
        self.chk_alt = QCheckBox("Alt")
        self.chk_win = QCheckBox("Win")
        for c in (
            self.chk_flx,
            self.chk_ctrl,
            self.chk_shift,
            self.chk_alt,
            self.chk_win,
        ):
            mods.addWidget(c)
        mods.addStretch()
        form.addLayout(mods, 1, 1, 1, 2)

        form.addWidget(QLabel("النافذة النشطة (اختياري):"), 2, 0)
        self.cond_edit = QLineEdit()
        self.cond_edit.setPlaceholderText(
            "اتركه فارغًا ليعمل في كل النوافذ — مثال: ahk_exe chrome.exe"
        )
        form.addWidget(self.cond_edit, 2, 1)
        pick_btn = QPushButton("التقاط نافذة")
        pick_btn.setToolTip("اختر نافذة بالماوس ليعمل الاختصار داخلها فقط")
        pick_btn.clicked.connect(lambda: self.pick_window_condition(self.cond_edit))
        form.addWidget(pick_btn, 2, 2)

        form.addWidget(QLabel("نوع الاختصار:"), 3, 0)
        self.type_combo = QComboBox()
        for _code, label in ACTION_TYPES:
            self.type_combo.addItem(label)
        form.addWidget(self.type_combo, 3, 1, 1, 2)

        lay.addLayout(form)

        # حقول ديناميكية حسب النوع
        self.fields = QStackedWidget()
        self.path_edits = {}
        for _index, (code, _label) in enumerate(ACTION_TYPES):
            page = QWidget()
            pl = QVBoxLayout(page)
            if code == "script_existing":
                self.script_combo = QComboBox()
                self.script_combo.addItems(list_scripts())
                pl.addWidget(QLabel("اختر السكربت:"))
                pl.addWidget(self.script_combo)
            elif code == "script_code":
                self.script_name_edit = QLineEdit()
                self.script_name_edit.setPlaceholderText(
                    "اسم السكربت (بدون .ahk) — يُترك فارغًا ليؤخذ من المفتاح"
                )
                pl.addWidget(self.script_name_edit)
                self.code_edit = QPlainTextEdit()
                self.code_edit.setPlaceholderText(
                    "ألصق كود AutoHotkey هنا…\nتنبيه: السكربت يُنفذ تسلسليًا بدون Hotkeys داخليّة،"
                    " وينتهي بـ ExitApp (انظر القاعدة الذهبية في README)."
                )
                pl.addWidget(self.code_edit)
            else:
                row = QHBoxLayout()
                edit = QLineEdit()
                btn = QPushButton("تصفح…")
                btn.clicked.connect(lambda _=False, c=code, e=edit: self._browse(c, e))
                row.addWidget(edit, 1)
                row.addWidget(btn)
                self.path_edits[code] = edit
                hints = {
                    "app": "مسار البرنامج التنفيذي (.exe)",
                    "file": "مسار أي ملف لفتحه",
                    "folder": "مسار المجلد",
                    "manual": "أمر كامل مثل: explorer.exe shell:appsFolder\\...",
                    "text": "النص المراد إرساله — يدعم الإيموجي 😊",
                }
                lab = QLabel(hints.get(code, ""))
                lab.setProperty("role", "hint")
                pl.addWidget(lab)
                pl.addLayout(row)
            self.fields.addWidget(page)
        lay.addWidget(self.fields, 1)

        self.type_combo.currentIndexChanged.connect(self.fields.setCurrentIndex)

        save_row = QHBoxLayout()
        save_btn = QPushButton("➕ إضافة الاختصار")
        save_btn.setObjectName("PrimaryButton")
        save_btn.clicked.connect(self._save)
        clear_btn = QPushButton("تفريغ الحقول")
        clear_btn.clicked.connect(self._clear)
        save_row.addWidget(save_btn)
        save_row.addWidget(clear_btn)
        save_row.addStretch()
        lay.addLayout(save_row)

    # ----- تفاعلات -----

    def _browse(self, code, edit):
        if code == "app":
            path, _ = QFileDialog.getOpenFileName(
                self, "اختر تطبيقًا", "", "Executable Files (*.exe);;All Files (*.*)"
            )
        elif code == "file":
            path, _ = QFileDialog.getOpenFileName(
                self, "اختر ملفًا", "", "All Files (*.*)"
            )
        elif code == "folder":
            path = QFileDialog.getExistingDirectory(self, "اختر مجلدًا")
        else:
            return
        if path:
            edit.setText(path)

    def _detect_key(self):
        name = KeyDetectDialog.detect(self)
        if name:
            self.key_edit.setText(name)

    def _drag_acceptable(self, urls):
        return any(
            u.toLocalFile().lower().endswith((".exe", ".ahk"))
            or os.path.isdir(u.toLocalFile())
            for u in urls
        )

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls() and self._drag_acceptable(
            event.mimeData().urls()
        ):
            event.acceptProposedAction()

    def dropEvent(self, event):
        for url in event.mimeData().urls():
            path = url.toLocalFile()
            lower = path.lower()
            if lower.endswith(".exe"):
                self.type_combo.setCurrentIndex(TYPE_INDEX["app"])
                self.path_edits["app"].setText(path)
            elif lower.endswith(".ahk"):
                self.type_combo.setCurrentIndex(TYPE_INDEX["script_code"])
                try:
                    with open(path, encoding="utf-8-sig", errors="replace") as f:
                        self.code_edit.setPlainText(f.read())
                except OSError:
                    pass
                name = os.path.splitext(os.path.basename(path))[0]
                self.script_name_edit.setText(
                    "" if os.path.dirname(path) == SCRIPTS_DIR else name
                )
            elif os.path.isdir(path):
                self.type_combo.setCurrentIndex(TYPE_INDEX["folder"])
                self.path_edits["folder"].setText(path)
            event.acceptProposedAction()
            return

    @staticmethod
    def _mark_invalid(widget, invalid):
        """تلوين حقل كإدخال غير صالح (حدود حمراء) أو إعادة الحالة الطبيعية."""
        widget.setProperty("invalid", bool(invalid))
        style = widget.style()
        style.unpolish(widget)
        style.polish(widget)

    def _compose_common(self):
        key = self.key_edit.text().strip()
        if not key:
            raise ValueError("يرجى إدخال مفتاح.")
        prefix = (
            ("^" if self.chk_ctrl.isChecked() else "")
            + ("+" if self.chk_shift.isChecked() else "")
            + ("!" if self.chk_alt.isChecked() else "")
            + ("#" if self.chk_win.isChecked() else "")
        )
        return prefix + key, self.cond_edit.text().strip(), self.chk_flx.isChecked()

    def _resolve_script_payload(self, use_flx):
        """يعيد المسار النسبي المناسب حسب وجود Flx."""
        name = self.script_combo.currentText().strip()
        if not name:
            raise ValueError("اختر سكربتًا من القائمة.")
        if not os.path.exists(os.path.join(SCRIPTS_DIR, name + ".ahk")):
            raise ValueError("السكربت غير موجود: " + name)
        # مع Flx: Scripts\name.ahk — بدون Flx: name.ahk فقط
        # (محرك NoFlx يحل المسارات المجردة نسبةً إلى مجلد Scripts)
        return ("Scripts\\" + name + ".ahk") if use_flx else (name + ".ahk")

    def _save_new_code_script(self, key_for_default, content, exclude_fullkey, cfg):
        default = key_for_default or "new_script"
        name, ok = QInputDialog.getText(
            self, "اسم السكربت", "أدخل اسمًا للسكربت (بدون .ahk):", text=default
        )
        if not ok or not name.strip():
            return None
        name = name.strip()
        if not name.lower().endswith(".ahk"):
            name += ".ahk"
        rel = "Scripts\\" + name
        for hk in cfg.iter_hotkeys():
            if hk.fullkey.lower() != exclude_fullkey.lower() and hk.action.replace(
                "/", "\\"
            ) == rel.replace("/", "\\"):
                QMessageBox.warning(
                    self,
                    "خطأ",
                    f"اسم السكربت مستخدم بالفعل لاختصار آخر:\n{hk.fullkey}",
                )
                return None
        path = os.path.join(SCRIPTS_DIR, name)
        try:
            with open(path, "w", encoding="utf-8-sig", newline="\r\n") as f:
                f.write(content.rstrip("\n") + "\n")
        except OSError as exc:
            QMessageBox.critical(self, "خطأ", f"فشل حفظ ملف السكربت:\n{exc}")
            return None
        return name

    def _save(self):
        cfg = self.ctx.config()
        try:
            prefixed_key, cond, use_flx = self._compose_common()
        except ValueError as exc:
            self._mark_invalid(self.key_edit, True)
            self.key_edit.setFocus()
            QMessageBox.warning(self, "خطأ", str(exc))
            return
        fullkey = join_fullkey(prefixed_key, cond)

        conflict = cfg.find_conflict(fullkey)
        if conflict:
            ans = QMessageBox.question(
                self,
                "تحذير",
                f"المفتاح مستخدم بالفعل:\n{describe_conflict(conflict)}\nهل تريد استبداله؟",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if ans != QMessageBox.StandardButton.Yes:
                return

        code, _label = ACTION_TYPES[self.type_combo.currentIndex()]
        try:
            if code == "script_existing":
                rel = self._resolve_script_payload(use_flx)
                kind = "advanced" if use_flx else "noflx"
                action = rel
            elif code == "script_code":
                content = self.code_edit.toPlainText()
                if not content.strip():
                    raise ValueError("يرجى إدخال كود السكربت.")
                warn = v2_syntax_warning(content)
                if warn and not confirm_v2_code(self, warn):
                    return
                default_name = self.script_name_edit.text().strip() or strip_modifiers(
                    prefixed_key
                )
                name = self._save_new_code_script(default_name, content, fullkey, cfg)
                if not name:
                    return
                kind = "advanced" if use_flx else "noflx"
                action = ("Scripts\\" + name) if use_flx else name
            else:
                edit = self.path_edits[code]
                payload = edit.text().strip()
                if not payload:
                    raise ValueError("يرجى إدخال القيمة أو استخدام زر التصفح.")
                action = build_action(code, payload)
                kind = "simple" if use_flx else "noflx"
        except ValueError as exc:
            QMessageBox.warning(self, "خطأ", str(exc))
            return

        cfg.upsert_hotkey(kind, fullkey, action)
        cfg.save()
        sent = post_reload()
        self.ctx.refresh_all()
        self._clear()
        self.ctx.show_status(
            "تمت إضافة الاختصار"
            + ("" if sent else " (المحرك غير مشغّل — ستُطبَّق عند تشغيله)")
        )

    def _clear(self):
        self.key_edit.clear()
        self.cond_edit.clear()
        for edit in self.path_edits.values():
            edit.clear()
        self.code_edit.clear()
        self.script_name_edit.clear()
        self.chk_flx.setChecked(True)
        for chk in (self.chk_ctrl, self.chk_shift, self.chk_alt, self.chk_win):
            chk.setChecked(False)


# ------------------------------------------------------------------ الصفحة 3: الإدارة


class ManagePage(QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        lay = QVBoxLayout(self)
        lay.setContentsMargins(20, 20, 20, 24)
        lay.setSpacing(12)

        title = QLabel("الإدارة")
        title.setObjectName("PageTitle")
        subtitle = QLabel(
            "تعديل وحذف الاختصارات، وتنظيف السكربتات اليتيمة — كل عمليات الحذف مؤكدة ومحمية بنسخة احتياطية"
        )
        subtitle.setObjectName("Subtitle")
        lay.addWidget(title)
        lay.addWidget(subtitle)

        search_row = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setObjectName("SearchField")
        self.search.setPlaceholderText("بحث…  (Ctrl+F)")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self._filter)
        search_row.addWidget(self.search, 1)
        refresh_btn = QPushButton("تحديث  (F5)")
        refresh_btn.clicked.connect(self.refresh)
        search_row.addWidget(refresh_btn)
        lay.addLayout(search_row)

        self.table = make_table()
        self.table.doubleClicked.connect(self._edit_selected)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self._context_menu)
        lay.addWidget(self.table, 1)

        btns = QHBoxLayout()
        edit_btn = QPushButton("تعديل")
        edit_btn.setObjectName("PrimaryButton")
        edit_btn.setToolTip("نقرة مزدوجة على الصف تؤدي نفس الغرض")
        edit_btn.clicked.connect(self._edit_selected)
        delete_btn = QPushButton("حذف المحدد")
        delete_btn.setObjectName("DangerButton")
        delete_btn.setToolTip(
            "يمكن تحديد عدة صفوف بـ Ctrl أو Shift ثم الحذف دفعة واحدة"
        )
        delete_btn.clicked.connect(self._delete_selected)
        btns.addWidget(edit_btn)
        btns.addWidget(delete_btn)
        btns.addStretch()
        lay.addLayout(btns)

        # --- السكربتات غير المستخدمة ---
        self.unused_group = QGroupBox("سكربتات غير مستخدمة في أي اختصار")
        ug_layout = QHBoxLayout(self.unused_group)
        self.unused_list = QListWidget()
        self.unused_list.setMaximumHeight(110)
        self.unused_list.setToolTip(
            "سكربتات في مجلد Scripts لا يشير إليها أي اختصار — مكتبة Gdip مستثناة دائمًا"
        )
        ug_layout.addWidget(self.unused_list, 1)
        ucol = QVBoxLayout()
        del_unused_btn = QPushButton("حذف المحدد")
        del_unused_btn.setObjectName("DangerButton")
        del_unused_btn.clicked.connect(self._delete_unused)
        reload_unused_btn = QPushButton("تحديث القائمة")
        reload_unused_btn.clicked.connect(self._refresh_unused)
        ucol.addWidget(del_unused_btn)
        ucol.addWidget(reload_unused_btn)
        ucol.addStretch()
        ug_layout.addLayout(ucol)
        lay.addWidget(self.unused_group)

        self._table_empty = attach_empty_state(self.table)
        self._unused_empty = attach_empty_state(
            self.unused_list,
            empty_text="لا سكربتات يتيمة — كلها مستخدمة",
            filtered_text="",
        )

    def _filter(self, term):
        apply_search(self.table, term)
        self._table_empty()

    def refresh(self):
        cfg = self.ctx.config()
        fill_table(self.table, list(cfg.iter_hotkeys()))
        self._table_empty()
        self._refresh_unused()

    def _refresh_unused(self):
        self.unused_list.clear()
        used = {p.replace("/", "\\") for p in self.ctx.config().used_scripts()}
        for f in sorted(glob.glob(os.path.join(SCRIPTS_DIR, "*.ahk"))):
            name = os.path.basename(f)
            if name.lower() == "gdip.ahk":
                continue  # مكتبة أساسية لا تُعرض ولا تُحذف
            rel = "Scripts\\" + name
            if rel not in used:
                self.unused_list.addItem(name)
        count = self.unused_list.count()
        self.unused_group.setTitle(f"سكربتات غير مستخدمة ({count})")
        self._unused_empty()

    def _edit_selected(self):
        entry = selected_entry(self.table)
        if entry:
            self.ctx.open_edit_dialog(entry)

    def _selected_entries(self):
        rows = sorted({i.row() for i in self.table.selectedIndexes()})
        entries = []
        for row in rows:
            item = self.table.item(row, 0)
            if item:
                kind, fullkey = item.data(Qt.ItemDataRole.UserRole)
                item_action = self.table.item(row, 2)
                action = (item_action.text() if item_action else "").replace(
                    MISSING_MARKER, ""
                )
                entries.append(HotkeyEntry(kind, fullkey, action))
        return entries

    def _delete_selected(self):
        if delete_entries(self.ctx, self._selected_entries()):
            self.refresh()

    def _context_menu(self, pos):
        entry = selected_entry(self.table)
        show_hotkey_context_menu(
            self.table,
            entry,
            on_edit=self._edit_selected,
            on_delete=self._delete_selected,
        )

    def _delete_unused(self):
        items = self.unused_list.selectedItems()
        if not items:
            QMessageBox.information(self, "تنبيه", "حدد سكربتًا لحذفه أولًا.")
            return
        name = items[0].text()
        ans = QMessageBox.question(
            self,
            "تأكيد",
            f'سيُحذف السكربت "{name}" نهائيًا من القرص. متابعة؟',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if ans != QMessageBox.StandardButton.Yes:
            return
        path = os.path.join(SCRIPTS_DIR, name)
        try:
            os.remove(path)
            self.ctx.show_status("تم حذف السكربت " + name)
        except OSError as exc:
            QMessageBox.critical(self, "خطأ", f"فشل الحذف:\n{exc}")
        self._refresh_unused()
        self.ctx.refresh_all()


# ------------------------------------------------------------------ الصفحة 4: الإعدادات


class SettingsPage(WindowPickMixin, QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        lay = QVBoxLayout(self)
        lay.setContentsMargins(20, 20, 20, 24)
        lay.setSpacing(12)

        title = QLabel("الإعدادات")
        title.setObjectName("PageTitle")
        subtitle = QLabel("تُطبَّق التغييرات فور الحفظ عبر إعادة تحميل المحرك تلقائيًا")
        subtitle.setObjectName("Subtitle")
        lay.addWidget(title)
        lay.addWidget(subtitle)

        form = QGridLayout()
        form.setHorizontalSpacing(10)
        form.setVerticalSpacing(10)

        self.folder_rows = {}
        rows = [
            ("MonitoredFolders", "المجلدات المراقبة (بدون تفرعات):", "folder"),
            ("MonitoredFoldersWithSub", "المجلدات المراقبة (مع تفرعاتها):", "folder"),
            ("ExcludedFolders", "المجلدات المستثناة:", "folder"),
            ("ProcessNames", "العمليات المراقبة (افصل بفواصل):", "exe"),
        ]
        for r, (field_key, label, browse_kind) in enumerate(rows):
            form.addWidget(QLabel(label), r, 0)
            edit = QLineEdit()
            self.folder_rows[field_key] = (edit, browse_kind)
            form.addWidget(edit, r, 1)
            btn = QPushButton("+ إضافة")
            btn.setToolTip(
                "يُضاف المسار إلى نهاية القائمة الحالية مفصولًا بفاصلة — "
                "وللاستبدال عدّل النص يدويًا"
            )
            btn.clicked.connect(lambda _=False, k=field_key: self._append_browse(k))
            form.addWidget(btn, r, 2)

        form.addWidget(QLabel("فترة الفحص (بالميلي ثانية):"), len(rows), 0)
        self.interval_spin = QSpinBox()
        self.interval_spin.setRange(100, 600000)
        self.interval_spin.setSingleStep(100)
        self.interval_spin.setGroupSeparatorShown(True)
        self.interval_spin.setToolTip(
            "كل كم ميلي ثانية يفحص المحرك العمليات والمجلدات أثناء وضع التسريع"
        )
        form.addWidget(self.interval_spin, len(rows), 1)

        form.addWidget(QLabel("زر Flx الأساسي (BaseKey):"), len(rows) + 1, 0)
        base_row = QHBoxLayout()
        self.basekey_edit = QLineEdit()
        self.basekey_edit.setPlaceholderText("SC056")
        self.basekey_edit.setToolTip(
            "رمز المفتاح الفيزيائي مثل SC056 أو VK07 — "
            "يُستخدم كبادئة لكل الاختصارات مثل Flx+T"
        )
        base_detect = QPushButton("اكتشاف")
        base_detect.clicked.connect(self._detect_basekey)
        base_row.addWidget(self.basekey_edit, 1)
        base_row.addWidget(base_detect)
        form.addLayout(base_row, len(rows) + 1, 1, 1, 2)

        lay.addLayout(form)
        lay.addStretch()

        save_btn = QPushButton("حفظ الإعدادات")
        save_btn.setObjectName("PrimaryButton")
        save_btn.clicked.connect(self._save)
        save_row = QHBoxLayout()
        save_row.addStretch()
        save_row.addWidget(save_btn)
        lay.addLayout(save_row)

    def _detect_basekey(self):
        name = KeyDetectDialog.detect(self)
        if name:
            self.basekey_edit.setText(name)

    def _append_browse(self, field_key):
        edit, kind = self.folder_rows[field_key]
        if kind == "folder":
            path = QFileDialog.getExistingDirectory(self, "اختر مجلدًا")
        else:
            path, _ = QFileDialog.getOpenFileName(
                self, "اختر عملية", "", "Executable Files (*.exe)"
            )
            if path:
                path = os.path.basename(path)
        if not path:
            return
        current = edit.text().strip()
        edit.setText(f"{current},{path}" if current else path)

    def refresh(self):
        cfg = self.ctx.config()
        settings = cfg.get_settings()
        for field_key, (edit, _kind) in self.folder_rows.items():
            edit.setText(settings.get(field_key, ""))
        try:
            self.interval_spin.setValue(int(settings.get("CheckInterval", "1000")))
        except ValueError:
            self.interval_spin.setValue(1000)
        self.basekey_edit.setText(cfg.get_base_hotkey())

    def _save(self):
        cfg = self.ctx.config()
        values = {}
        for field_key, (edit, _kind) in self.folder_rows.items():
            values[field_key] = edit.text().strip()
        values["CheckInterval"] = str(self.interval_spin.value())
        basekey = self.basekey_edit.text().strip()
        if not basekey:
            QMessageBox.warning(self, "خطأ", "لا يمكن ترك زر Flx فارغًا.")
            return
        cfg.update_settings(values)
        cfg.set_base_hotkey(basekey)
        cfg.save()
        sent = post_reload()
        self.ctx.refresh_all()
        self.ctx.show_status(
            "تم حفظ الإعدادات"
            + (
                " وأُعيد تحميل المحرك"
                if sent
                else " (المحرك غير مشغّل — ستُطبَّق عند تشغيله)"
            )
        )


# ------------------------------------------------------------------ الصفحة 5: الأمان


class SecurityPage(QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        lay = QVBoxLayout(self)
        lay.setContentsMargins(18, 18, 18, 18)
        lay.setSpacing(12)

        title = QLabel("الأمان — وضع التسريع")
        title.setObjectName("PageTitle")
        subtitle = QLabel(
            "إغلاق تلقائي للعمليات والمجلدات المراقبة. التبديل اللحظي يبقى متاحًا عبر Flx + D"
        )
        subtitle.setObjectName("Subtitle")
        lay.addWidget(title)
        lay.addWidget(subtitle)

        state_group = QGroupBox("الحالة الحالية")
        sg = QHBoxLayout(state_group)
        self.state_label = QLabel("--")
        self.state_label.setObjectName("GoldHeader")
        sg.addWidget(self.state_label)
        sg.addStretch()
        self.toggle_btn = QPushButton()
        self.toggle_btn.setObjectName("PrimaryButton")
        self.toggle_btn.clicked.connect(self._toggle_mode)
        sg.addWidget(self.toggle_btn)
        lay.addWidget(state_group)

        proc_group = QGroupBox("العمليات التي تُغلق فورًا عند تفعيل الوضع")
        pg = QVBoxLayout(proc_group)
        self.proc_edit = QLineEdit()
        self.proc_edit.setPlaceholderText("telegram.exe,ui32.exe")
        pg.addWidget(self.proc_edit)
        prow = QHBoxLayout()
        add_proc = QPushButton("إضافة عملية…")
        add_proc.clicked.connect(self._add_process)
        prow.addWidget(add_proc)
        prow.addStretch()
        pg.addLayout(prow)
        lay.addWidget(proc_group)

        folders_group = QGroupBox("المجلدات المراقبة (تُدار تفصيليًا من صفحة الإعدادات)")
        fg = QVBoxLayout(folders_group)
        self.folders_hint = QLabel("")
        self.folders_hint.setProperty("role", "hint")
        self.folders_hint.setWordWrap(True)
        fg.addWidget(self.folders_hint)
        go_settings = QPushButton("فتح صفحة الإعدادات")
        go_settings.clicked.connect(lambda: self.ctx.goto_page(3))
        fg.addWidget(go_settings, 0, Qt.AlignmentFlag.AlignLeft)
        lay.addWidget(folders_group)

        lay.addStretch()
        save_btn = QPushButton("حفظ قائمة العمليات")
        save_btn.setObjectName("PrimaryButton")
        save_btn.clicked.connect(self._save_processes)
        srow = QHBoxLayout()
        srow.addStretch()
        srow.addWidget(save_btn)
        lay.addLayout(srow)

    def refresh(self):
        cfg = self.ctx.config()
        settings = cfg.get_settings()
        active = settings.get("IsSecureMode", "0") in ("1", "true", "True")
        self.state_label.setObjectName("StateOk" if active else "StateBad")
        style = self.state_label.style()
        style.unpolish(self.state_label)
        style.polish(self.state_label)
        self.state_label.setText("وضع التسريع مفعّل" if active else "وضع التسريع متوقف")
        self.toggle_btn.setText("إيقاف الوضع الآن" if active else "تفعيل الوضع الآن")
        self.proc_edit.setText(settings.get("ProcessNames", ""))
        folders = " / ".join(
            filter(
                None,
                [
                    settings.get("MonitoredFolders", ""),
                    settings.get("MonitoredFoldersWithSub", ""),
                ],
            )
        )
        excluded = settings.get("ExcludedFolders", "")
        self.folders_hint.setText(
            (f"مراقب: {folders}" if folders else "لا توجد مجلدات مراقبة")
            + ((f"   —   مستثنى: {excluded}") if excluded else "")
        )

    def _toggle_mode(self):
        cfg = self.ctx.config()
        settings = cfg.get_settings()
        active = settings.get("IsSecureMode", "0") in ("1", "true", "True")

        if not active:
            # تفعيل إجراء هجومي (قتل عمليات) — يستحق تأكيدًا صريحًا يوضح العواقب
            procs = [
                p.strip()
                for p in settings.get("ProcessNames", "").split(",")
                if p.strip()
            ]
            lines = ["عند التفعيل سيعمل المحرك فورًا ودوريًا على إغلاق العمليات:"]
            lines += ["• " + p for p in (procs[:8] or ["—"])]
            if len(procs) > 8:
                lines.append(f"… و{len(procs) - 8} أخرى")
            watched = settings.get("MonitoredFoldersWithSub", "") or settings.get(
                "MonitoredFolders", ""
            )
            if watched:
                lines += ["", "وسيُغلق أي مجلد مستكشف داخل:", watched]
            ans = QMessageBox.question(
                self,
                "تفعيل وضع التسريع",
                "\n".join(lines),
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if ans != QMessageBox.StandardButton.Yes:
                return

        new_state = "1" if not active else "0"
        cfg.update_settings({"IsSecureMode": new_state})
        cfg.save()
        sent = post_reload()
        self.ctx.refresh_all()
        msg = "تم تحديث وضع التسريع"
        if not sent:
            msg += " (المحرك غير مشغّل — ستُطبَّق الحالة عند تشغيله)"
        self.ctx.show_status(msg)

    def _add_process(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "اختر عملية", "", "Executable Files (*.exe)"
        )
        if not path:
            return
        name = os.path.basename(path)
        current = [p.strip() for p in self.proc_edit.text().split(",") if p.strip()]
        if name.lower() not in [p.lower() for p in current]:
            current.append(name)
        self.proc_edit.setText(",".join(current))

    def _save_processes(self):
        cfg = self.ctx.config()
        cfg.update_settings({"ProcessNames": self.proc_edit.text().strip()})
        cfg.save()
        sent = post_reload()
        self.ctx.refresh_all()
        self.ctx.show_status(
            "تم حفظ قائمة العمليات" + ("" if sent else " (المحرك غير مشغّل)")
        )


# ------------------------------------------------------------------ النافذة الرئيسية

PAGES = [
    ("🏠", "الرئيسية", "نظرة عامة على كل الاختصارات وحالة النظام"),
    ("⌨", "اختصار جديد", "إضافة اختصار من أي نوع من نموذج واحد"),
    ("📋", "الإدارة", "تعديل وحذف الاختصارات وتنظيف السكربتات"),
    ("⚙", "الإعدادات", "المجلدات المراقبة والعمليات وزر Flx الأساسي"),
    ("🛡", "الأمان", "التحكم بوضع التسريع وقائمة العمليات"),
]


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("FlxAHK — لوحة التحكم")
        self.resize(980, 640)
        self.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        self._cfg = FlxConfig(INI_PATH)
        self.settings_store = QSettings("FlxAHK", "GUI")

        central = QWidget()
        self.setCentralWidget(central)
        root = QHBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # الشريط الجانبي (يمين لأن الاتجاه RTL)
        sidebar = QWidget()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(200)
        side_lay = QVBoxLayout(sidebar)
        side_lay.setContentsMargins(10, 8, 10, 14)
        side_lay.setSpacing(4)

        app_title = QLabel("⚡ FlxAHK")
        app_title.setObjectName("AppTitle")
        app_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        side_lay.addWidget(app_title)

        self.sidebar_group = QButtonGroup(self)
        self.sidebar_group.setExclusive(True)
        self.nav_buttons = []
        for i, (icon, label, tip) in enumerate(PAGES):
            btn = QPushButton(f"{icon}  {label}")
            btn.setObjectName("SidebarButton")
            btn.setCheckable(True)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setToolTip(tip)
            btn.clicked.connect(lambda _=False, idx=i: self.goto_page(idx))
            self.sidebar_group.addButton(btn)
            side_lay.addWidget(btn)
            self.nav_buttons.append(btn)
        self.nav_buttons[0].setChecked(True)
        side_lay.addStretch()

        version = QLabel("v2 · PySide6")
        version.setObjectName("SidebarHint")
        version.setAlignment(Qt.AlignmentFlag.AlignCenter)
        version.setToolTip("تعمل هذه الواجهة مستقلة أيضًا:\npythonw Scripts\\FlxGUI.py")
        side_lay.addWidget(version)
        root.addWidget(sidebar)

        # المحتوى
        self.stack = QStackedWidget()
        root.addWidget(self.stack, 1)

        self.home_page = HomePage(self)
        self.add_page = AddPage(self)
        self.manage_page = ManagePage(self)
        self.settings_page = SettingsPage(self)
        self.security_page = SecurityPage(self)
        for page in (
            self.home_page,
            self.add_page,
            self.manage_page,
            self.settings_page,
            self.security_page,
        ):
            self.stack.addWidget(page)

        self.statusBar().showMessage(
            "جاهز — F5 تحديث · Ctrl+F بحث · Ctrl+N اختصار جديد"
        )

        self.refresh_all()
        self._switch_animate(0)

        # استرجاع هندسة النافذة من الجلسة السابقة
        geometry = self.settings_store.value("geometry")
        if geometry is not None:
            self.restoreGeometry(geometry)

    # ---------- API للصفحات ----------

    def config(self):
        """نسخة جديدة من الإعدادات مقروءة من القرص (تضمن رؤية تغييرات خارجية)."""
        self._cfg = FlxConfig(INI_PATH)
        return self._cfg

    def show_status(self, message):
        self.statusBar().showMessage(message, 5000)

    def goto_page(self, index):
        self.stack.setCurrentIndex(index)
        self._switch_animate(index)
        self.nav_buttons[index].setChecked(True)
        self.refresh_page(index)

    def refresh_page(self, index):
        page = self.stack.widget(index)
        refresh = getattr(page, "refresh", None)
        if callable(refresh):
            refresh()

    def refresh_all(self):
        for i in range(self.stack.count()):
            self.refresh_page(i)

    def open_edit_dialog(self, entry):
        cfg = FlxConfig(INI_PATH)
        dlg = HotkeyEditDialog(self, cfg, entry, on_saved=self.refresh_all)
        dlg.exec()

    def _focus_search(self):
        page = self.stack.currentWidget()
        search = getattr(page, "search", None)
        if search is not None:
            search.setFocus()
            search.selectAll()

    def closeEvent(self, event):
        # زر X يخفي النافذة للجوار بدل الإنهاء — الواجهة تبقى مقيمة بالخلفية
        # (الإغلاق الفعلي من قائمة جوار النظام)
        event.ignore()
        self.hide_to_tray()

    # ---------- الإقامة في جوار النظام ----------

    def show_window(self):
        self.showNormal()
        self.raise_()
        self.activateWindow()

    def hide_to_tray(self):
        self.settings_store.setValue("geometry", self.saveGeometry())
        self.hide()
        # نفرّغ الذاكرة الفيزيائية فورًا — وينوزع النظام يعيدها عند الحاجة
        with contextlib.suppress(OSError):
            ctypes.windll.kernel32.SetProcessEmptyWorkingSet(-1)
        self._tray_hint()

    def _create_tray(self):
        icon = self.style().standardIcon(QStyle.StandardPixmap.SP_DesktopIcon)
        self.tray = QSystemTrayIcon(icon, self)
        self.tray.setToolTip("FlxAHK — لوحة التحكم\nنقرة مزدوجة: إظهار")
        menu = QMenu()
        act_show = menu.addAction("إظهار")
        act_hide = menu.addAction("إخفاء")
        menu.addSeparator()
        act_quit = menu.addAction("خروج")
        act_show.triggered.connect(self.show_window)
        act_hide.triggered.connect(self.hide_to_tray)
        act_quit.triggered.connect(self._quit_from_tray)
        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._tray_activated)
        self.tray.show()

    def _tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            if self.isVisible():
                self.hide_to_tray()
            else:
                self.show_window()

    def _tray_hint(self):
        """تنبيه لمرة واحدة أول مرة تنخفي للجوار حتى لا يظن المستخدم أنها أُغلقت."""
        if getattr(self, "_hint_shown", False):
            return
        self._hint_shown = True
        self.tray.showMessage(
            "FlxAHK",
            "لا تزال الواجهة تعمل بالخلفية — أيقونتها في جوار النظام،\n"
            "والخروج الكامل من قائمتها (زر أيمن ← خروج).",
            QSystemTrayIcon.MessageIcon.Information,
            5000,
        )

    def _quit_from_tray(self):
        self.settings_store.setValue("geometry", self.saveGeometry())
        if getattr(self, "tray", None):
            self.tray.hide()
        QApplication.quit()

    def _switch_animate(self, index):
        page = self.stack.widget(index)
        if page is None:
            return
        effect = QGraphicsOpacityEffect(page)
        page.setGraphicsEffect(effect)
        anim = QPropertyAnimation(effect, b"opacity", page)
        anim.setDuration(180)
        anim.setStartValue(0.35)
        anim.setEndValue(1.0)
        anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        anim.finished.connect(
            lambda: page.setGraphicsEffect(None)  # type: ignore[arg-type]
        )
        anim.start(QPropertyAnimation.DeletionPolicy.DeleteWhenStopped)


# ------------------------------------------------------------------ نسخة واحدة فقط

from PySide6.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402

SINGLE_INSTANCE_KEY = "FlxAHK_GUI"


class SingleInstance:
    """قفل نسخة واحدة عبر named pipe + بروتوكول أوامر نصية:
    show / hide / toggle / quit"""

    def __init__(self, on_command):
        self.server = None
        self.on_command = on_command

    def try_lock(self):
        socket = QLocalSocket()
        socket.connectToServer(SINGLE_INSTANCE_KEY)
        if socket.waitForConnected(300):
            socket.write(b"show\n")
            socket.flush()
            socket.waitForBytesWritten(300)
            socket.disconnectFromServer()
            return False
        QLocalServer.removeServer(SINGLE_INSTANCE_KEY)
        self.server = QLocalServer()
        self.server.newConnection.connect(self._on_connection)
        self.server.listen(SINGLE_INSTANCE_KEY)
        return True

    def _on_connection(self):
        if self.server is None:
            return
        socket = self.server.nextPendingConnection()
        if not socket:
            return

        buffer = bytearray()

        def _handle_ready_read():
            while socket.bytesAvailable():
                buffer.extend(socket.read(64).data())
            while b"\n" in buffer:
                line, _, rest = buffer.partition(b"\n")
                del buffer[: len(line) + 1]
                cmd = line.decode("utf-8", errors="replace").strip()
                if cmd:
                    self.on_command(cmd)

        socket.readyRead.connect(_handle_ready_read)


# ------------------------------------------------------------------ التشغيل


def main():
    app = QApplication(sys.argv)
    app.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
    app.setQuitOnLastWindowClosed(False)  # النافذة تُخفى للجوار ولا تُنهي التطبيق
    load_stylesheet(app)

    def handle_command(cmd):
        win = window_holder.get("win")
        if not win:
            return
        if cmd == "show":
            win.show_window()
        elif cmd == "hide":
            win.hide_to_tray()
        elif cmd == "toggle":
            win.show_window() if not win.isVisible() else win.hide_to_tray()
        elif cmd == "quit":
            win._quit_from_tray()

    window_holder = {}
    guard = SingleInstance(handle_command)
    if not guard.try_lock():
        sys.exit(0)

    window = MainWindow()
    window_holder["win"] = window
    window._create_tray()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
