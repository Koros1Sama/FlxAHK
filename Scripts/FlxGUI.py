# -*- coding: utf-8 -*-
"""
FlxAHK Modern Management Interface (PySide6)
============================================
واجهة المستخدم الحديثة والشاملة لإدارة واختبار وإعداد اختصارات وبيئة FlxAHK.
"""

import sys
import os
import subprocess
from typing import Optional, Dict, Any, List

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QListWidget, QStackedWidget, QLabel, QPushButton, QLineEdit,
    QTableWidget, QTableWidgetItem, QHeaderView, QCheckBox, QComboBox,
    QFileDialog, QMessageBox, QFrame, QScrollArea, QTabWidget,
    QPlainTextEdit, QDialog, QSplitter, QAbstractItemView
)
from PySide6.QtCore import Qt, QTimer, QSize
from PySide6.QtGui import QIcon, QFont, QColor, QKeyEvent

from ini_manager import IniManager


class EditHotkeyDialog(QDialog):
    """نافذة منبثقة لتعديل اختصار موجود."""
    def __init__(self, hotkey_data: Dict[str, Any], ini_mgr: IniManager, parent=None):
        super().__init__(parent)
        self.hotkey_data = hotkey_data
        self.ini_mgr = ini_mgr
        self.setWindowTitle("تعديل الاختصار")
        self.resize(550, 480)
        self.setLayoutDirection(Qt.RightToLeft)
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(14)
        layout.setContentsMargins(20, 20, 20, 20)

        title = QLabel("✏️ تعديل بيانات الاختصار")
        title.setProperty("class", "SectionTitle")
        layout.addWidget(title)

        # Card: Key and Modifiers
        key_card = QFrame()
        key_card.setProperty("class", "Card")
        kc_layout = QVBoxLayout(key_card)

        k_row = QHBoxLayout()
        k_row.addWidget(QLabel("المفتاح الرئيسي:"))
        self.key_input = QLineEdit(self.hotkey_data.get("main_key", ""))
        k_row.addWidget(self.key_input)
        kc_layout.addLayout(k_row)

        mod_row = QHBoxLayout()
        self.cb_flx = QCheckBox("Flx Key")
        self.cb_flx.setChecked(self.hotkey_data.get("use_flx", True))
        self.cb_ctrl = QCheckBox("Ctrl (^)")
        self.cb_ctrl.setChecked(self.hotkey_data.get("ctrl", False))
        self.cb_shift = QCheckBox("Shift (+)")
        self.cb_shift.setChecked(self.hotkey_data.get("shift", False))
        self.cb_alt = QCheckBox("Alt (!)")
        self.cb_alt.setChecked(self.hotkey_data.get("alt", False))
        self.cb_win = QCheckBox("Win (#)")
        self.cb_win.setChecked(self.hotkey_data.get("win", False))

        mod_row.addWidget(self.cb_flx)
        mod_row.addWidget(self.cb_ctrl)
        mod_row.addWidget(self.cb_shift)
        mod_row.addWidget(self.cb_alt)
        mod_row.addWidget(self.cb_win)
        kc_layout.addLayout(mod_row)
        layout.addWidget(key_card)

        # Card: Window condition
        win_card = QFrame()
        win_card.setProperty("class", "Card")
        wc_layout = QHBoxLayout(win_card)
        wc_layout.addWidget(QLabel("شرط النافذة (اختياري):"))
        self.win_input = QLineEdit(self.hotkey_data.get("win_condition", ""))
        self.win_input.setPlaceholderText("مثال: ahk_exe chrome.exe")
        wc_layout.addWidget(self.win_input)
        layout.addWidget(win_card)

        # Card: Action
        act_card = QFrame()
        act_card.setProperty("class", "Card")
        ac_layout = QVBoxLayout(act_card)
        ac_layout.addWidget(QLabel("الأمر / الإجراء:"))
        self.action_input = QLineEdit(self.hotkey_data.get("action", ""))
        ac_layout.addWidget(self.action_input)
        layout.addWidget(act_card)

        # Buttons
        btn_layout = QHBoxLayout()
        btn_save = QPushButton("💾 حفظ التعديلات")
        btn_save.setProperty("class", "Primary")
        btn_save.clicked.connect(self.save_changes)

        btn_cancel = QPushButton("إلغاء")
        btn_cancel.clicked.connect(self.reject)

        btn_layout.addStretch()
        btn_layout.addWidget(btn_cancel)
        btn_layout.addWidget(btn_save)
        layout.addLayout(btn_layout)

    def save_changes(self):
        main_key = self.key_input.text().strip()
        if not main_key:
            QMessageBox.warning(self, "تنبيه", "يرجى كتابة المفتاح الرئيسي.")
            return

        use_flx = self.cb_flx.isChecked()
        is_script = self.hotkey_data.get("section") == "AdvancedScripts"

        section = "AdvancedScripts" if is_script else ("CustomHotkeys" if use_flx else "NoFlx")

        self.ini_mgr.save_hotkey(
            section=section,
            main_key=main_key,
            ctrl=self.cb_ctrl.isChecked(),
            shift=self.cb_shift.isChecked(),
            alt=self.cb_alt.isChecked(),
            win=self.cb_win.isChecked(),
            win_condition=self.win_input.text().strip(),
            action=self.action_input.text().strip(),
            old_raw_key=self.hotkey_data.get("raw_key"),
            old_section=self.hotkey_data.get("section")
        )
        self.accept()


class KeyDetectorDialog(QDialog):
    """نافذة لاكتشاف ضغطة المفتاح تلقائياً."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("🎯 اضغط أي زر على الكيبورد")
        self.resize(380, 180)
        self.setLayoutDirection(Qt.RightToLeft)
        self.detected_key = ""
        self.ctrl = False
        self.shift = False
        self.alt = False
        self.win = False
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignCenter)
        lbl = QLabel("اضغط المفتاح المطلوب الآن...\n(المفاتيح الخاصة أو الحروف أو الأرقام)")
        lbl.setAlignment(Qt.AlignCenter)
        lbl.setFont(QFont("Segoe UI", 13, QFont.Bold))
        layout.addWidget(lbl)

        self.status_lbl = QLabel("في انتظار الضغطة...")
        self.status_lbl.setAlignment(Qt.AlignCenter)
        self.status_lbl.setStyleSheet("color: #7aa2f7; font-size: 14px;")
        layout.addWidget(self.status_lbl)

    def keyPressEvent(self, event: QKeyEvent):
        key = event.key()
        text = event.text()

        # استبعاد أزرار المعدلات لوحدها
        if key in (Qt.Key_Control, Qt.Key_Shift, Qt.Key_Alt, Qt.Key_Meta):
            return

        mods = event.modifiers()
        self.ctrl = bool(mods & Qt.ControlModifier)
        self.shift = bool(mods & Qt.ShiftModifier)
        self.alt = bool(mods & Qt.AltModifier)
        self.win = bool(mods & Qt.MetaModifier)

        # تحويل المفتاح لاسم مناسب لـ AHK
        special_keys = {
            Qt.Key_Escape: "ESC",
            Qt.Key_Tab: "Tab",
            Qt.Key_Backspace: "Backspace",
            Qt.Key_Return: "Enter",
            Qt.Key_Enter: "NumpadEnter",
            Qt.Key_Insert: "Insert",
            Qt.Key_Delete: "Delete",
            Qt.Key_Pause: "Pause",
            Qt.Key_Print: "PrintScreen",
            Qt.Key_Home: "Home",
            Qt.Key_End: "End",
            Qt.Key_Left: "Left",
            Qt.Key_Up: "Up",
            Qt.Key_Right: "Right",
            Qt.Key_Down: "Down",
            Qt.Key_PageUp: "PgUp",
            Qt.Key_PageDown: "PgDn",
            Qt.Key_CapsLock: "CapsLock",
            Qt.Key_NumLock: "NumLock",
            Qt.Key_ScrollLock: "ScrollLock",
            Qt.Key_Space: "Space"
        }

        # أزرار F1-F24
        if Qt.Key_F1 <= key <= Qt.Key_F24:
            self.detected_key = f"F{key - Qt.Key_F1 + 1}"
        elif key in special_keys:
            self.detected_key = special_keys[key]
        elif text and len(text) == 1 and text.isprintable():
            self.detected_key = text.upper()
        else:
            # استخدام Virtual Key Code
            native_vk = event.nativeVirtualKey()
            if native_vk:
                self.detected_key = f"VK{native_vk:02X}"
            else:
                self.detected_key = f"Key_{key}"

        self.status_lbl.setText(f"تم التقاط: {self.detected_key}")
        QTimer.singleShot(250, self.accept)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.ini_mgr = IniManager()
        self.setWindowTitle("FlxAHK - لوحة التحكم الشاملة")
        self.resize(1020, 680)
        self.setMinimumSize(850, 550)
        self.setLayoutDirection(Qt.RightToLeft)

        self.init_ui()
        self.load_theme()
        self.refresh_all_data()

    def load_theme(self):
        qss_path = os.path.join(os.path.dirname(__file__), "flx_theme.qss")
        if os.path.isfile(qss_path):
            with open(qss_path, "r", encoding="utf-8") as f:
                self.setStyleSheet(f.read())

    def init_ui(self):
        central = QWidget()
        central.setObjectName("CentralWidget")
        self.setCentralWidget(central)

        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # -------------------------------------------------------------
        # 1. Sidebar
        # -------------------------------------------------------------
        sidebar = QWidget()
        sidebar.setObjectName("Sidebar")
        sb_layout = QVBoxLayout(sidebar)
        sb_layout.setContentsMargins(10, 10, 10, 15)
        sb_layout.setSpacing(6)

        logo_title = QLabel("⚡ FlxAHK")
        logo_title.setObjectName("LogoTitle")
        logo_sub = QLabel("مدير الإنتاجية والاختصارات")
        logo_sub.setObjectName("LogoSubtitle")

        sb_layout.addWidget(logo_title)
        sb_layout.addWidget(logo_sub)

        self.nav_list = QListWidget()
        self.nav_list.setObjectName("NavList")
        self.nav_list.addItem("🏠 الرئيسية والاختصارات")
        self.nav_list.addItem("➕ إضافة اختصار جديد")
        self.nav_list.addItem("📋 إدارة السكربتات")
        self.nav_list.addItem("⚙️ الإعدادات العامة")
        self.nav_list.addItem("🛡️ وضع الأمان (Secure)")
        self.nav_list.currentRowChanged.connect(self.switch_page)
        sb_layout.addWidget(self.nav_list)

        sb_layout.addStretch()

        # Quick AHK Reload button in sidebar
        btn_reload = QPushButton("🔄 إعادة تحميل AHK")
        btn_reload.clicked.connect(self.manual_reload_ahk)
        sb_layout.addWidget(btn_reload)

        main_layout.addWidget(sidebar)

        # -------------------------------------------------------------
        # 2. Content Pages Stack
        # -------------------------------------------------------------
        self.pages_stack = QStackedWidget()
        self.pages_stack.setObjectName("ContentArea")

        self.page_home = self.create_page_home()
        self.page_add = self.create_page_add()
        self.page_scripts = self.create_page_scripts()
        self.page_settings = self.create_page_settings()
        self.page_secure = self.create_page_secure()

        self.pages_stack.addWidget(self.page_home)
        self.pages_stack.addWidget(self.page_add)
        self.pages_stack.addWidget(self.page_scripts)
        self.pages_stack.addWidget(self.page_settings)
        self.pages_stack.addWidget(self.page_secure)

        main_layout.addWidget(self.pages_stack)
        self.nav_list.setCurrentRow(0)

    def switch_page(self, index: int):
        self.pages_stack.setCurrentIndex(index)
        if index == 0:
            self.refresh_hotkeys_table()
        elif index == 2:
            self.refresh_scripts_list()
        elif index == 3:
            self.load_general_settings()

    # =========================================================================
    # Page 1: 🏠 الرئيسية (Overview & Table)
    # =========================================================================
    def create_page_home(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Header Stats Row
        stats_row = QHBoxLayout()
        stats_row.setSpacing(12)

        self.stat_total = self._create_stat_card("إجمالي الاختصارات", "0")
        self.stat_scripts = self._create_stat_card("السكربتات المتقدمة", "0")
        self.stat_base = self._create_stat_card("زر Flx الأساسي", "SC056")
        self.stat_mode = self._create_stat_card("وضع التسريع", "معطل")

        stats_row.addWidget(self.stat_total)
        stats_row.addWidget(self.stat_scripts)
        stats_row.addWidget(self.stat_base)
        stats_row.addWidget(self.stat_mode)
        layout.addLayout(stats_row)

        # Filter & Search Row
        search_row = QHBoxLayout()
        search_row.setSpacing(10)

        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("🔍 ابحث عن أي اختصار، أمر، تطبيق، أو شرط نافذة...")
        self.search_input.textChanged.connect(self.filter_hotkeys_table)
        search_row.addWidget(self.search_input, stretch=3)

        self.type_filter = QComboBox()
        self.type_filter.addItems(["جميع الأنواع", "بسيط (Flx)", "متقدم (Flx)", "مباشر (NoFlx)"])
        self.type_filter.currentIndexChanged.connect(self.filter_hotkeys_table)
        search_row.addWidget(self.type_filter, stretch=1)

        layout.addLayout(search_row)

        # Hotkeys Table
        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["المفتاح", "شرط النافذة", "الإجراء / الأمر", "النوع"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeToContents)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.doubleClicked.connect(self.edit_selected_hotkey)
        layout.addWidget(self.table)

        # Bottom Actions Bar
        actions_row = QHBoxLayout()
        actions_row.setSpacing(10)

        btn_add = QPushButton("➕ إضافة اختصار")
        btn_add.setProperty("class", "Primary")
        btn_add.clicked.connect(lambda: self.nav_list.setCurrentRow(1))

        btn_edit = QPushButton("✏️ تعديل المحدد")
        btn_edit.clicked.connect(self.edit_selected_hotkey)

        btn_del = QPushButton("🗑️ حذف المحدد")
        btn_del.setProperty("class", "Danger")
        btn_del.clicked.connect(self.delete_selected_hotkey)

        btn_run = QPushButton("▶️ تجربة الإجراء")
        btn_run.clicked.connect(self.run_selected_action)

        actions_row.addWidget(btn_add)
        actions_row.addWidget(btn_edit)
        actions_row.addWidget(btn_del)
        actions_row.addWidget(btn_run)
        actions_row.addStretch()

        layout.addLayout(actions_row)
        return page

    def _create_stat_card(self, label_text: str, value_text: str) -> QFrame:
        card = QFrame()
        card.setProperty("class", "StatCard")
        c_layout = QVBoxLayout(card)
        c_layout.setContentsMargins(12, 10, 12, 10)
        c_layout.setSpacing(4)

        val = QLabel(value_text)
        val.setProperty("class", "StatValue")
        lbl = QLabel(label_text)
        lbl.setProperty("class", "StatLabel")

        c_layout.addWidget(val)
        c_layout.addWidget(lbl)
        card.value_label = val
        return card

    # =========================================================================
    # Page 2: ➕ إضافة اختصار جديد (Unified Form)
    # =========================================================================
    def create_page_add(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(14)

        title = QLabel("➕ إنشاء وربط اختصار جديد")
        title.setProperty("class", "SectionTitle")
        layout.addWidget(title)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        container = QWidget()
        c_layout = QVBoxLayout(container)
        c_layout.setSpacing(14)

        # 1. Key Card
        key_card = QFrame()
        key_card.setProperty("class", "Card")
        kc_layout = QVBoxLayout(key_card)

        k_title = QLabel("1. المفتاح والمعدلات")
        k_title.setFont(QFont("Segoe UI", 11, QFont.Bold))
        kc_layout.addWidget(k_title)

        k_row = QHBoxLayout()
        k_row.addWidget(QLabel("المفتاح:"))
        self.add_key_input = QLineEdit()
        self.add_key_input.setPlaceholderText("مثال: T أو 1 أو SC028 أو F1")
        k_row.addWidget(self.add_key_input, stretch=2)

        btn_detect = QPushButton("🎯 التقاط المفتاح")
        btn_detect.clicked.connect(self.detect_key_for_add)
        k_row.addWidget(btn_detect)
        kc_layout.addLayout(k_row)

        mod_row = QHBoxLayout()
        self.add_cb_flx = QCheckBox("زر Flx الأساسي (BaseKey)")
        self.add_cb_flx.setChecked(True)
        self.add_cb_ctrl = QCheckBox("Ctrl (^)")
        self.add_cb_shift = QCheckBox("Shift (+)")
        self.add_cb_alt = QCheckBox("Alt (!)")
        self.add_cb_win = QCheckBox("Win (#)")

        mod_row.addWidget(self.add_cb_flx)
        mod_row.addWidget(self.add_cb_ctrl)
        mod_row.addWidget(self.add_cb_shift)
        mod_row.addWidget(self.add_cb_alt)
        mod_row.addWidget(self.add_cb_win)
        kc_layout.addLayout(mod_row)
        c_layout.addWidget(key_card)

        # 2. Window Condition Card
        win_card = QFrame()
        win_card.setProperty("class", "Card")
        wc_layout = QVBoxLayout(win_card)

        w_title = QLabel("2. شرط النافذة (Context-Aware)")
        w_title.setFont(QFont("Segoe UI", 11, QFont.Bold))
        wc_layout.addWidget(w_title)

        w_row = QHBoxLayout()
        self.add_win_input = QLineEdit()
        self.add_win_input.setPlaceholderText("اتركه فارغاً ليعمل في كل مكان، أو اكتب: ahk_exe chrome.exe")
        w_row.addWidget(self.add_win_input)
        wc_layout.addLayout(w_row)
        c_layout.addWidget(win_card)

        # 3. Action Card
        act_card = QFrame()
        act_card.setProperty("class", "Card")
        ac_layout = QVBoxLayout(act_card)

        a_title = QLabel("3. نوع الإجراء والأمر")
        a_title.setFont(QFont("Segoe UI", 11, QFont.Bold))
        ac_layout.addWidget(a_title)

        self.add_action_type = QComboBox()
        self.add_action_type.addItems([
            "🚀 تشغيل تطبيق أو ملف (Run App/File)",
            "📂 فتح مجلد (Open Folder)",
            "🌐 فتح موقع ويب أو رابط (Open URL)",
            "✍️ إرسال نص أو إيموجي (Send Text)",
            "📜 تشغيل سكريبت فرعي (Advanced Script)",
            "⚙️ أمر مخصص (Custom Run/Win Command)"
        ])
        self.add_action_type.currentIndexChanged.connect(self.on_add_action_type_changed)
        ac_layout.addWidget(self.add_action_type)

        # Dynamic Action Inputs
        self.action_input_row = QHBoxLayout()
        self.add_action_val = QLineEdit()
        self.add_action_val.setPlaceholderText("اختر أو اكتب المسار أو النص...")
        self.action_input_row.addWidget(self.add_action_val)

        self.btn_browse = QPushButton("📁 تصفح")
        self.btn_browse.clicked.connect(self.browse_for_add_action)
        self.action_input_row.addWidget(self.btn_browse)

        self.scripts_dropdown = QComboBox()
        self.scripts_dropdown.setVisible(False)
        self.action_input_row.addWidget(self.scripts_dropdown)

        ac_layout.addLayout(self.action_input_row)

        # Mini Code Editor for Advanced Scripts
        self.script_editor = QPlainTextEdit()
        self.script_editor.setPlaceholderText("; اكتب كود AutoHotkey هنا إذا كنت تنشئ سكريبت جديد...")
        self.script_editor.setMinimumHeight(120)
        self.script_editor.setVisible(False)
        ac_layout.addWidget(self.script_editor)

        c_layout.addWidget(act_card)

        # Save Button
        btn_save_new = QPushButton("💾 حفظ وإضافة الاختصار")
        btn_save_new.setProperty("class", "Primary")
        btn_save_new.setMinimumHeight(40)
        btn_save_new.clicked.connect(self.save_new_hotkey)
        c_layout.addWidget(btn_save_new)

        scroll.setWidget(container)
        layout.addWidget(scroll)
        return page

    def on_add_action_type_changed(self, index: int):
        # 0: App/File, 1: Folder, 2: URL, 3: Text, 4: Script, 5: Custom
        self.btn_browse.setVisible(index in (0, 1))
        self.scripts_dropdown.setVisible(index == 4)
        self.add_action_val.setVisible(index != 4)
        self.script_editor.setVisible(index == 4)

        if index == 0:
            self.add_action_val.setPlaceholderText("مسار التطبيق أو الملف...")
        elif index == 1:
            self.add_action_val.setPlaceholderText("مسار المجلد...")
        elif index == 2:
            self.add_action_val.setPlaceholderText("https://example.com")
        elif index == 3:
            self.add_action_val.setPlaceholderText("النص أو الإيموجي المراد كتابته...")
        elif index == 4:
            self.populate_scripts_dropdown()
        elif index == 5:
            self.add_action_val.setPlaceholderText("WinMinimize, A أو explorer.exe shell:...")

    def populate_scripts_dropdown(self):
        self.scripts_dropdown.clear()
        self.scripts_dropdown.addItem("-- إنشاء سكريبت جديد من المحرر أدناه --")
        for s in self.ini_mgr.get_scripts_list():
            self.scripts_dropdown.addItem(s)

    def browse_for_add_action(self):
        idx = self.add_action_type.currentIndex()
        if idx == 0:  # File/App
            path, _ = QFileDialog.getOpenFileName(self, "اختر التطبيق أو الملف", "", "All Files (*.*)")
            if path:
                self.add_action_val.setText(os.path.normpath(path))
        elif idx == 1:  # Folder
            folder = QFileDialog.getExistingDirectory(self, "اختر المجلد")
            if folder:
                self.add_action_val.setText(os.path.normpath(folder))

    def detect_key_for_add(self):
        dlg = KeyDetectorDialog(self)
        if dlg.exec():
            if dlg.detected_key:
                self.add_key_input.setText(dlg.detected_key)
                self.add_cb_ctrl.setChecked(dlg.ctrl)
                self.add_cb_shift.setChecked(dlg.shift)
                self.add_cb_alt.setChecked(dlg.alt)
                self.add_cb_win.setChecked(dlg.win)

    def save_new_hotkey(self):
        main_key = self.add_key_input.text().strip()
        if not main_key:
            QMessageBox.warning(self, "خطأ", "يرجى تحديد المفتاح الرئيسي.")
            return

        idx = self.add_action_type.currentIndex()
        action_str = ""
        is_script = False

        if idx == 0:  # App/File
            val = self.add_action_val.text().strip()
            if not val:
                QMessageBox.warning(self, "خطأ", "يرجى تحديد مسار الملف.")
                return
            action_str = f"Run {val}"
        elif idx == 1:  # Folder
            val = self.add_action_val.text().strip()
            if not val:
                QMessageBox.warning(self, "خطأ", "يرجى تحديد مسار المجلد.")
                return
            action_str = f"Run {val}"
        elif idx == 2:  # URL
            val = self.add_action_val.text().strip()
            if not val:
                QMessageBox.warning(self, "خطأ", "يرجى كتابة الرابط.")
                return
            if not (val.startswith("http://") or val.startswith("https://")):
                val = "https://" + val
            action_str = f"Run {val}"
        elif idx == 3:  # Text
            val = self.add_action_val.text()
            if not val:
                QMessageBox.warning(self, "خطأ", "يرجى كتابة النص.")
                return
            action_str = f"Send {val}"
        elif idx == 4:  # Script
            is_script = True
            selected_script = self.scripts_dropdown.currentText()
            if self.scripts_dropdown.currentIndex() == 0 or selected_script.startswith("--"):
                # إنشاء سكريبت جديد
                code = self.script_editor.toPlainText().strip()
                if not code:
                    QMessageBox.warning(self, "خطأ", "يرجى كتابة كود السكريبت أو اختيار سكريبت موجود.")
                    return
                filename = f"Custom_{main_key}.ahk"
                action_str = self.ini_mgr.create_or_save_script(filename, code)
            else:
                action_str = f"Scripts\\{selected_script}"
        elif idx == 5:  # Custom
            val = self.add_action_val.text().strip()
            if not val:
                QMessageBox.warning(self, "خطأ", "يرجى كتابة الأمر.")
                return
            action_str = val

        use_flx = self.add_cb_flx.isChecked()
        section = "AdvancedScripts" if is_script else ("CustomHotkeys" if use_flx else "NoFlx")

        self.ini_mgr.save_hotkey(
            section=section,
            main_key=main_key,
            ctrl=self.add_cb_ctrl.isChecked(),
            shift=self.add_cb_shift.isChecked(),
            alt=self.add_cb_alt.isChecked(),
            win=self.add_cb_win.isChecked(),
            win_condition=self.add_win_input.text().strip(),
            action=action_str
        )

        QMessageBox.information(self, "نجاح", "تمت إضافة الاختصار بنجاح وتحديث FlxAHK!")
        # مسح الحقول والانتقال للرئيسية
        self.add_key_input.clear()
        self.add_win_input.clear()
        self.add_action_val.clear()
        self.script_editor.clear()
        self.nav_list.setCurrentRow(0)

    # =========================================================================
    # Page 3: 📋 إدارة السكربتات والأدوات
    # =========================================================================
    def create_page_scripts(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(14)

        title = QLabel("📋 إدارة سكربتات مجلد Scripts/")
        title.setProperty("class", "SectionTitle")
        layout.addWidget(title)

        splitter = QSplitter(Qt.Horizontal)

        # Left: Scripts List
        list_frame = QFrame()
        list_frame.setProperty("class", "Card")
        lf_layout = QVBoxLayout(list_frame)

        lf_layout.addWidget(QLabel("قائمة السكربتات المتوفرة:"))
        self.scripts_list_widget = QListWidget()
        self.scripts_list_widget.currentRowChanged.connect(self.on_script_selected)
        lf_layout.addWidget(self.scripts_list_widget)

        btn_row = QHBoxLayout()
        btn_del_script = QPushButton("🗑️ حذف السكربت")
        btn_del_script.setProperty("class", "Danger")
        btn_del_script.clicked.connect(self.delete_selected_script)

        btn_open_folder = QPushButton("📂 فتح مجلد Scripts")
        btn_open_folder.clicked.connect(lambda: os.startfile(self.ini_mgr.scripts_dir))

        btn_row.addWidget(btn_del_script)
        btn_row.addWidget(btn_open_folder)
        lf_layout.addLayout(btn_row)

        splitter.addWidget(list_frame)

        # Right: Script Code Viewer / Editor
        view_frame = QFrame()
        view_frame.setProperty("class", "Card")
        vf_layout = QVBoxLayout(view_frame)

        self.current_script_title = QLabel("معاينة كود السكربت:")
        vf_layout.addWidget(self.current_script_title)

        self.script_viewer = QPlainTextEdit()
        vf_layout.addWidget(self.script_viewer)

        btn_save_script = QPushButton("💾 حفظ التعديل على ملف السكربت")
        btn_save_script.setProperty("class", "Primary")
        btn_save_script.clicked.connect(self.save_current_script_code)
        vf_layout.addWidget(btn_save_script)

        splitter.addWidget(view_frame)
        splitter.setSizes([320, 580])
        layout.addWidget(splitter)
        return page

    def refresh_scripts_list(self):
        self.scripts_list_widget.clear()
        scripts = self.ini_mgr.get_scripts_list()
        unused = set(self.ini_mgr.get_unused_scripts())

        for s in scripts:
            is_unused = s in unused
            item_text = f"⚠️ {s} (غير مربوط)" if is_unused else f"✅ {s}"
            self.scripts_list_widget.addItem(item_text)

        if scripts:
            self.scripts_list_widget.setCurrentRow(0)

    def on_script_selected(self, row: int):
        if row < 0:
            self.script_viewer.clear()
            return
        scripts = self.ini_mgr.get_scripts_list()
        if row < len(scripts):
            filename = scripts[row]
            self.current_script_title.setText(f"معاينة كود: {filename}")
            path = os.path.join(self.ini_mgr.scripts_dir, filename)
            if os.path.isfile(path):
                for enc in ('utf-8-sig', 'utf-8', 'cp1256', 'latin-1'):
                    try:
                        with open(path, 'r', encoding=enc) as f:
                            self.script_viewer.setPlainText(f.read())
                        break
                    except Exception:
                        continue

    def save_current_script_code(self):
        row = self.scripts_list_widget.currentRow()
        scripts = self.ini_mgr.get_scripts_list()
        if 0 <= row < len(scripts):
            filename = scripts[row]
            code = self.script_viewer.toPlainText()
            self.ini_mgr.create_or_save_script(filename, code)
            QMessageBox.information(self, "نجاح", f"تم حفظ التعديلات على {filename} بترميز UTF-8 BOM بنجاح.")

    def delete_selected_script(self):
        row = self.scripts_list_widget.currentRow()
        scripts = self.ini_mgr.get_scripts_list()
        if 0 <= row < len(scripts):
            filename = scripts[row]
            reply = QMessageBox.question(self, "تأكيد الحذف", f"هل أنت متأكد من حذف السكربت {filename} من القرص؟", QMessageBox.Yes | QMessageBox.No)
            if reply == QMessageBox.Yes:
                self.ini_mgr.delete_script_file(filename)
                self.refresh_scripts_list()

    # =========================================================================
    # Page 4: ⚙️ الإعدادات العامة
    # =========================================================================
    def create_page_settings(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(14)

        title = QLabel("⚙️ الإعدادات العامة ومفتاح Flx")
        title.setProperty("class", "SectionTitle")
        layout.addWidget(title)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        container = QWidget()
        c_layout = QVBoxLayout(container)
        c_layout.setSpacing(14)

        # 1. Base Key Card
        base_card = QFrame()
        base_card.setProperty("class", "Card")
        bc_layout = QVBoxLayout(base_card)
        bc_layout.addWidget(QLabel("🔑 المفتاح الأساسي لـ Flx (BaseKey):"))

        bk_row = QHBoxLayout()
        self.base_key_input = QLineEdit()
        self.base_key_input.setText(self.ini_mgr.get_base_key())
        bk_row.addWidget(self.base_key_input)

        btn_detect_base = QPushButton("🎯 التقاط المفتاح")
        btn_detect_base.clicked.connect(self.detect_base_key)
        bk_row.addWidget(btn_detect_base)
        bc_layout.addLayout(bk_row)
        c_layout.addWidget(base_card)

        # 2. General Paths Card
        paths_card = QFrame()
        paths_card.setProperty("class", "Card")
        pc_layout = QVBoxLayout(paths_card)
        pc_layout.addWidget(QLabel("📁 المجلدات والعمليات المراقبة:"))

        # Monitored Folders
        pc_layout.addWidget(QLabel("المجلدات المراقبة (بدون مجلدات فرعية):"))
        self.mon_folders_input = QLineEdit()
        pc_layout.addWidget(self.mon_folders_input)

        # Monitored Folders with sub
        pc_layout.addWidget(QLabel("المجلدات المراقبة (مع المجلدات الفرعية):"))
        self.mon_sub_folders_input = QLineEdit()
        pc_layout.addWidget(self.mon_sub_folders_input)

        # Excluded Folders
        pc_layout.addWidget(QLabel("المجلدات المستثناة:"))
        self.excl_folders_input = QLineEdit()
        pc_layout.addWidget(self.excl_folders_input)

        # Process Names
        pc_layout.addWidget(QLabel("العمليات والبرامج المحظورة في وضع التسريع:"))
        self.proc_names_input = QLineEdit()
        pc_layout.addWidget(self.proc_names_input)

        # Check Interval
        pc_layout.addWidget(QLabel("سرعة فحص وضع الأمان (بالميللي ثانية):"))
        self.interval_input = QLineEdit()
        pc_layout.addWidget(self.interval_input)

        c_layout.addWidget(paths_card)

        # Save Settings Button
        btn_save_settings = QPushButton("💾 حفظ الإعدادات وتطبيقها")
        btn_save_settings.setProperty("class", "Primary")
        btn_save_settings.setMinimumHeight(40)
        btn_save_settings.clicked.connect(self.save_general_settings)
        c_layout.addWidget(btn_save_settings)

        scroll.setWidget(container)
        layout.addWidget(scroll)
        return page

    def load_general_settings(self):
        self.base_key_input.setText(self.ini_mgr.get_base_key())
        settings = self.ini_mgr.get_general_settings()
        self.mon_folders_input.setText(settings.get("MonitoredFolders", ""))
        self.mon_sub_folders_input.setText(settings.get("MonitoredFoldersWithSub", ""))
        self.excl_folders_input.setText(settings.get("ExcludedFolders", ""))
        self.proc_names_input.setText(settings.get("ProcessNames", ""))
        self.interval_input.setText(settings.get("CheckInterval", "1000"))

    def detect_base_key(self):
        dlg = KeyDetectorDialog(self)
        if dlg.exec():
            if dlg.detected_key:
                self.base_key_input.setText(dlg.detected_key)

    def save_general_settings(self):
        base_key = self.base_key_input.text().strip()
        if base_key:
            self.ini_mgr.set_base_key(base_key)

        settings_dict = {
            "MonitoredFolders": self.mon_folders_input.text().strip(),
            "MonitoredFoldersWithSub": self.mon_sub_folders_input.text().strip(),
            "ExcludedFolders": self.excl_folders_input.text().strip(),
            "ProcessNames": self.proc_names_input.text().strip(),
            "CheckInterval": self.interval_input.text().strip()
        }
        self.ini_mgr.set_general_settings(settings_dict)
        self.ini_mgr.notify_ahk_reload()
        QMessageBox.information(self, "نجاح", "تم حفظ الإعدادات وتحديث FlxAHK بنجاح.")
        self.refresh_all_data()

    # =========================================================================
    # Page 5: 🛡️ وضع الأمان (Secure Mode)
    # =========================================================================
    def create_page_secure(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        title = QLabel("🛡️ وضع التسريع / الأمان (Secure Mode)")
        title.setProperty("class", "SectionTitle")
        layout.addWidget(title)

        card = QFrame()
        card.setProperty("class", "Card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(14)

        desc = QLabel(
            "عند تفعيل وضع التسريع، يقوم FlxAHK تلقائياً وبشكل دوري بإغلاق أي نوافذ لمستكشف الملفات "
            "مفتوحة داخل المجلدات المراقبة، بالإضافة إلى إنهاء العمليات المحددة فوراً (مثل Telegram)."
        )
        desc.setWordWrap(True)
        c_layout.addWidget(desc)

        self.secure_status_label = QLabel("الحالة الحالية: معطل ⚪")
        self.secure_status_label.setFont(QFont("Segoe UI", 13, QFont.Bold))
        c_layout.addWidget(self.secure_status_label)

        btn_toggle = QPushButton("⚡ تبديل حالة وضع التسريع (Toggle)")
        btn_toggle.setProperty("class", "Primary")
        btn_toggle.setMinimumHeight(42)
        btn_toggle.clicked.connect(self.toggle_secure_mode)
        c_layout.addWidget(btn_toggle)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def toggle_secure_mode(self):
        settings = self.ini_mgr.get_general_settings()
        curr = settings.get("IsSecureMode", "0")
        new_val = "0" if curr == "1" else "1"
        self.ini_mgr.set_general_settings({"IsSecureMode": new_val})
        self.ini_mgr.notify_ahk_reload()
        self.refresh_secure_status()

    def refresh_secure_status(self):
        settings = self.ini_mgr.get_general_settings()
        is_on = settings.get("IsSecureMode", "0") == "1"
        if is_on:
            self.secure_status_label.setText("الحالة الحالية: مفعل ومراقب 🟢")
            self.secure_status_label.setStyleSheet("color: #9ece6a;")
            self.stat_mode.value_label.setText("مفعل 🟢")
        else:
            self.secure_status_label.setText("الحالة الحالية: معطل ⚪")
            self.secure_status_label.setStyleSheet("color: #565f89;")
            self.stat_mode.value_label.setText("معطل ⚪")

    # =========================================================================
    # Data Refresh & Table Logic
    # =========================================================================
    def refresh_all_data(self):
        self.refresh_hotkeys_table()
        self.refresh_secure_status()
        self.load_general_settings()

    def refresh_hotkeys_table(self):
        hotkeys = self.ini_mgr.get_all_hotkeys()
        self.all_hotkeys_cache = hotkeys

        self.stat_total.value_label.setText(str(len(hotkeys)))
        scripts_count = sum(1 for h in hotkeys if h["section"] == "AdvancedScripts")
        self.stat_scripts.value_label.setText(str(scripts_count))
        self.stat_base.value_label.setText(self.ini_mgr.get_base_key())

        self.filter_hotkeys_table()

    def filter_hotkeys_table(self):
        query = self.search_input.text().strip().lower()
        filter_type = self.type_filter.currentText()

        filtered = []
        for hk in getattr(self, "all_hotkeys_cache", []):
            if filter_type != "جميع الأنواع" and hk["type_label"] != filter_type:
                continue
            if query:
                match_key = query in hk["display_key"].lower()
                match_win = query in hk["win_condition"].lower()
                match_act = query in hk["action"].lower()
                if not (match_key or match_win or match_act):
                    continue
            filtered.append(hk)

        self.table.setRowCount(len(filtered))
        for row, hk in enumerate(filtered):
            # Key item
            item_key = QTableWidgetItem(hk["display_key"])
            item_key.setFont(QFont("Consolas", 11, QFont.Bold))
            item_key.setData(Qt.UserRole, hk)

            # Win condition item
            win_str = hk["win_condition"] if hk["win_condition"] else "الكل (عام)"
            item_win = QTableWidgetItem(win_str)
            if not hk["win_condition"]:
                item_win.setForeground(QColor("#565f89"))

            # Action item
            item_act = QTableWidgetItem(hk["action"])

            # Type badge item
            item_type = QTableWidgetItem(hk["type_label"])
            if "متقدم" in hk["type_label"]:
                item_type.setForeground(QColor("#bb9af7"))
            elif "NoFlx" in hk["type_label"]:
                item_type.setForeground(QColor("#e0af68"))
            else:
                item_type.setForeground(QColor("#7aa2f7"))

            self.table.setItem(row, 0, item_key)
            self.table.setItem(row, 1, item_win)
            self.table.setItem(row, 2, item_act)
            self.table.setItem(row, 3, item_type)

    def edit_selected_hotkey(self):
        row = self.table.currentRow()
        if row < 0:
            QMessageBox.information(self, "تنبيه", "يرجى تحديد اختصار من الجدول أولاً.")
            return

        item = self.table.item(row, 0)
        hk_data = item.data(Qt.UserRole)
        dlg = EditHotkeyDialog(hk_data, self.ini_mgr, self)
        if dlg.exec():
            self.refresh_hotkeys_table()

    def delete_selected_hotkey(self):
        row = self.table.currentRow()
        if row < 0:
            QMessageBox.information(self, "تنبيه", "يرجى تحديد اختصار من الجدول أولاً.")
            return

        item = self.table.item(row, 0)
        hk_data = item.data(Qt.UserRole)
        reply = QMessageBox.question(
            self,
            "تأكيد الحذف",
            f"هل أنت متأكد من حذف الاختصار [{hk_data['display_key']}]؟",
            QMessageBox.Yes | QMessageBox.No
        )
        if reply == QMessageBox.Yes:
            self.ini_mgr.delete_hotkey(hk_data["section"], hk_data["raw_key"])
            self.refresh_hotkeys_table()

    def run_selected_action(self):
        row = self.table.currentRow()
        if row < 0:
            return
        item = self.table.item(row, 0)
        hk_data = item.data(Qt.UserRole)
        action = hk_data["action"]

        if hk_data["section"] == "AdvancedScripts":
            # تشغيل السكربت الفرعي عبر AutoHotkey
            script_path = os.path.join(self.ini_mgr.root_dir, action)
            if os.path.isfile(script_path):
                os.startfile(script_path)
        elif action.startswith("Run "):
            target = action[4:].strip()
            try:
                os.startfile(target)
            except Exception as e:
                QMessageBox.warning(self, "خطأ في التشغيل", f"فشل تشغيل الهدف:\n{str(e)}")

    def manual_reload_ahk(self):
        self.ini_mgr.notify_ahk_reload()
        QMessageBox.information(self, "تم", "تم إرسال إشارة إعادة التحميل إلى Flx.ahk.")


def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
