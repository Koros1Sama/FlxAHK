# -*- coding: utf-8 -*-
"""
FlxAHK Settings INI Manager
===========================
قراءة وتعديل وحفظ ملف Flx_Settings.ini بدقة وبترميز UTF-16 LE المتوافق تماماً مع AutoHotkey.
"""

import os
import re
import glob
import ctypes
from typing import List, Dict, Any, Optional

class IniManager:
    def __init__(self, ini_path: Optional[str] = None):
        if ini_path is None:
            # افتراضياً، الملف في المجلد الأب لـ Scripts/
            script_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(script_dir)
            self.ini_path = os.path.join(parent_dir, "Flx_Settings.ini")
            self.scripts_dir = script_dir
            self.root_dir = parent_dir
        else:
            self.ini_path = os.path.abspath(ini_path)
            self.root_dir = os.path.dirname(self.ini_path)
            self.scripts_dir = os.path.join(self.root_dir, "Scripts")

        self.sections: Dict[str, List[str]] = {
            "Settings": [],
            "CustomHotkeys": [],
            "AdvancedScripts": [],
            "NoFlx": [],
            "HotkeySettings": []
        }
        self.load()

    def load(self):
        """قراءة ملف INI بترميز UTF-16 LE مع fallback لـ UTF-8."""
        if not os.path.isfile(self.ini_path):
            return

        raw = None
        for enc in ('utf-16', 'utf-16-le', 'utf-8-sig', 'utf-8', 'cp1256'):
            try:
                with open(self.ini_path, 'r', encoding=enc) as f:
                    raw = f.read()
                break
            except Exception:
                continue

        if raw is None:
            return

        current_section = None
        self.sections = {
            "Settings": [],
            "CustomHotkeys": [],
            "AdvancedScripts": [],
            "NoFlx": [],
            "HotkeySettings": []
        }

        for line in raw.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            if line_str.startswith('[') and line_str.endswith(']'):
                current_section = line_str[1:-1].strip()
                if current_section not in self.sections:
                    self.sections[current_section] = []
            elif current_section:
                self.sections[current_section].append(line_str)

    def save(self):
        """حفظ ملف INI بترميز UTF-16 LE مع BOM كما يفضله ويندوز و AHK."""
        lines = []
        # ترتيب الأقسام الافتراضي
        ordered_sections = ["Settings", "HotkeySettings", "CustomHotkeys", "AdvancedScripts", "NoFlx"]
        for sec in list(self.sections.keys()):
            if sec not in ordered_sections:
                ordered_sections.append(sec)

        for sec in ordered_sections:
            entries = self.sections.get(sec, [])
            lines.append(f"[{sec}]")
            for entry in entries:
                if entry.strip():
                    lines.append(entry.strip())

        content = "\r\n".join(lines) + "\r\n"
        with open(self.ini_path, 'w', encoding='utf-16', newline='') as f:
            f.write(content)

    # -------------------------------------------------------------
    # قراءة وكتابة إعدادات HotkeySettings
    # -------------------------------------------------------------
    def get_base_key(self) -> str:
        for entry in self.sections.get("HotkeySettings", []):
            if entry.startswith("BaseKey="):
                return entry.split("=", 1)[1].strip()
        return "SC056"

    def set_base_key(self, base_key: str):
        if "HotkeySettings" not in self.sections:
            self.sections["HotkeySettings"] = []
        
        found = False
        new_list = []
        for entry in self.sections["HotkeySettings"]:
            if entry.startswith("BaseKey="):
                new_list.append(f"BaseKey={base_key}")
                found = True
            else:
                new_list.append(entry)
        if not found:
            new_list.append(f"BaseKey={base_key}")
        self.sections["HotkeySettings"] = new_list
        self.save()

    # -------------------------------------------------------------
    # قراءة وكتابة إعدادات Settings العامة
    # -------------------------------------------------------------
    def get_general_settings(self) -> Dict[str, Any]:
        settings = {
            "MonitoredFolders": "",
            "MonitoredFoldersWithSub": "",
            "ExcludedFolders": "",
            "ProcessNames": "telegram.exe",
            "CheckInterval": "1000",
            "IsSecureMode": "0"
        }
        for entry in self.sections.get("Settings", []):
            if "=" in entry:
                k, v = entry.split("=", 1)
                settings[k.strip()] = v.strip()
        return settings

    def set_general_settings(self, settings_dict: Dict[str, Any]):
        if "Settings" not in self.sections:
            self.sections["Settings"] = []
        
        current_dict = self.get_general_settings()
        current_dict.update(settings_dict)

        self.sections["Settings"] = [
            f"MonitoredFolders={current_dict.get('MonitoredFolders', '')}",
            f"MonitoredFoldersWithSub={current_dict.get('MonitoredFoldersWithSub', '')}",
            f"ExcludedFolders={current_dict.get('ExcludedFolders', '')}",
            f"ProcessNames={current_dict.get('ProcessNames', '')}",
            f"CheckInterval={current_dict.get('CheckInterval', '1000')}",
            f"IsSecureMode={current_dict.get('IsSecureMode', '0')}"
        ]
        self.save()

    # -------------------------------------------------------------
    # قراءة جميع الاختصارات (CustomHotkeys, AdvancedScripts, NoFlx)
    # -------------------------------------------------------------
    def get_all_hotkeys(self) -> List[Dict[str, Any]]:
        self.load()
        hotkeys = []

        # 1. CustomHotkeys (بسيط مع Flx)
        for entry in self.sections.get("CustomHotkeys", []):
            item = self._parse_hotkey_entry(entry, section_type="CustomHotkeys")
            if item:
                hotkeys.append(item)

        # 2. AdvancedScripts (متقدم مع Flx)
        for entry in self.sections.get("AdvancedScripts", []):
            item = self._parse_hotkey_entry(entry, section_type="AdvancedScripts")
            if item:
                hotkeys.append(item)

        # 3. NoFlx (بسيط بدون Flx)
        for entry in self.sections.get("NoFlx", []):
            item = self._parse_hotkey_entry(entry, section_type="NoFlx")
            if item:
                hotkeys.append(item)

        return hotkeys

    def _parse_hotkey_entry(self, entry: str, section_type: str) -> Optional[Dict[str, Any]]:
        if "=" not in entry:
            return None
        key_part, action_part = entry.split("=", 1)
        key_part = key_part.strip().strip('"')
        action_part = action_part.strip()

        # استرجاع الفاصلة المنقوطة
        display_key_part = key_part.replace("VKBA", ";")

        # تفكيك شرط النافذة
        win_condition = ""
        key_pure = display_key_part
        if "|" in display_key_part:
            parts = display_key_part.split("|", 1)
            key_pure = parts[0].strip()
            win_condition = parts[1].strip()

        # استخراج المعدلات (Modifiers)
        # ^ = Ctrl, + = Shift, ! = Alt, # = Win
        ctrl = False
        shift = False
        alt = False
        win = False

        mod_chars = set("^!+#")
        raw_key = key_pure
        i = 0
        while i < len(raw_key) and raw_key[i] in mod_chars:
            ch = raw_key[i]
            if ch == '^': ctrl = True
            elif ch == '+': shift = True
            elif ch == '!': alt = True
            elif ch == '#': win = True
            i += 1
        
        main_key = raw_key[i:]

        # تحديد نوع الإجراء
        category = "command"
        if section_type == "AdvancedScripts":
            category = "script"
        elif action_part.startswith("Run "):
            target = action_part[4:].strip()
            if target.startswith("http://") or target.startswith("https://") or target.startswith("www."):
                category = "url"
            elif os.path.isdir(target) or target.startswith("shell:") or target.lower().endswith("folder"):
                category = "folder"
            elif target.lower().endswith(".exe") or "appsfolder" in target.lower():
                category = "app"
            else:
                category = "file"
        elif action_part.startswith("Send ") or action_part.startswith("Send, "):
            category = "text"
        elif action_part.startswith("Win"):
            category = "window"

        type_label = "بسيط (Flx)"
        if section_type == "AdvancedScripts":
            type_label = "متقدم (Flx)"
        elif section_type == "NoFlx":
            type_label = "مباشر (NoFlx)"

        return {
            "section": section_type,
            "raw_entry": entry,
            "raw_key": key_part,
            "display_key": display_key_part,
            "main_key": main_key,
            "ctrl": ctrl,
            "shift": shift,
            "alt": alt,
            "win": win,
            "use_flx": section_type != "NoFlx",
            "win_condition": win_condition,
            "action": action_part,
            "category": category,
            "type_label": type_label
        }

    # -------------------------------------------------------------
    # إضافة أو تعديل أو حذف اختصار
    # -------------------------------------------------------------
    def save_hotkey(self, 
                    section: str, 
                    main_key: str, 
                    ctrl: bool, 
                    shift: bool, 
                    alt: bool, 
                    win: bool, 
                    win_condition: str, 
                    action: str, 
                    old_raw_key: Optional[str] = None,
                    old_section: Optional[str] = None):
        """إضافة أو تعديل اختصار وحفظه في الملف."""
        # بناء المفتاح مع المعدلات
        mods = ""
        if ctrl: mods += "^"
        if shift: mods += "+"
        if alt: mods += "!"
        if win: mods += "#"
        
        full_key = mods + main_key
        # تحويل الفاصلة المنقوطة إلى VKBA
        encoded_key = full_key.replace(";", "VKBA")

        if win_condition.strip():
            encoded_key = f"{encoded_key}|{win_condition.strip()}"

        new_entry = f"{encoded_key}={action.strip()}"

        # إذا كان تعديلاً لاختصار قديم
        if old_raw_key and old_section:
            self.delete_hotkey(old_section, old_raw_key, save_now=False)

        # إضافة للإدخالات في القسم المناسب
        if section not in self.sections:
            self.sections[section] = []

        # إزالة أي تكرار لنفس المفتاح في نفس القسم
        self.sections[section] = [e for e in self.sections[section] if not e.startswith(f"{encoded_key}=")]
        self.sections[section].append(new_entry)
        self.save()
        self.notify_ahk_reload()

    def delete_hotkey(self, section: str, raw_key: str, save_now: bool = True):
        """حذف اختصار من قسم معين."""
        if section in self.sections:
            prefix = f"{raw_key}="
            self.sections[section] = [e for e in self.sections[section] if not e.startswith(prefix)]
            if save_now:
                self.save()
                self.notify_ahk_reload()

    # -------------------------------------------------------------
    # إدارة السكربتات غير المستخدمة
    # -------------------------------------------------------------
    def get_scripts_list(self) -> List[str]:
        """قائمة كل ملفات .ahk الموجودة في مجلد Scripts/"""
        ahk_files = glob.glob(os.path.join(self.scripts_dir, "*.ahk"))
        return [os.path.basename(f) for f in ahk_files]

    def get_unused_scripts(self) -> List[str]:
        """السكربتات الموجودة في Scripts/ وغير مربوطة بأي اختصار متقدم."""
        all_scripts = set(self.get_scripts_list())
        used_scripts = set()

        for entry in self.sections.get("AdvancedScripts", []):
            if "=" in entry:
                path = entry.split("=", 1)[1].strip()
                filename = os.path.basename(path.replace("\\", "/"))
                used_scripts.add(filename)

        # تجاهل السكربتات المساعدة الخاصة بالنظام مثل Gdip.ahk
        system_scripts = {"Gdip.ahk"}
        unused = (all_scripts - used_scripts) - system_scripts
        return sorted(list(unused))

    def delete_script_file(self, filename: str) -> bool:
        """حذف ملف سكربت فرعي من القرص."""
        path = os.path.join(self.scripts_dir, filename)
        if os.path.isfile(path):
            try:
                os.remove(path)
                return True
            except Exception:
                return False
        return False

    def create_or_save_script(self, filename: str, code_content: str) -> str:
        """حفظ أو إنشاء سكربت .ahk جديد بترميز UTF-8 with BOM."""
        if not filename.lower().endswith(".ahk"):
            filename += ".ahk"
        
        path = os.path.join(self.scripts_dir, filename)
        BOM = b'\xef\xbb\xbf'
        with open(path, 'wb') as f:
            f.write(BOM + code_content.encode('utf-8'))
        return f"Scripts\\{filename}"

    # -------------------------------------------------------------
    # إشعار Flx.ahk بإعادة التحميل فوراً
    # -------------------------------------------------------------
    def notify_ahk_reload(self):
        """إرسال إشارة لنافذة Flx.ahk لإعادة تحميل الاختصارات والإعدادات."""
        try:
            # محاولة إيجاد نافذة Flx.ahk وإرسال رسالة إعادة التشغيل
            user32 = ctypes.windll.user32
            # نبحث عن نافذة Flx.ahk المخفية
            # AutoHotkey window class: AutoHotkey
            # أمر إعادة التحميل القياسي لـ AHK هو WM_COMMAND بقيمة 65400 (Reload)
            WM_COMMAND = 0x0111
            ID_FILE_RELOADSCRIPT = 65400

            # نمر على كل نوافذ AHK ونبحث عن Flx.ahk
            def enum_proc(hwnd, lParam):
                length = user32.GetWindowTextLengthW(hwnd)
                if length > 0:
                    buf = ctypes.create_unicode_buffer(length + 1)
                    user32.GetWindowTextW(hwnd, buf, length + 1)
                    title = buf.value
                    if "Flx.ahk" in title:
                        user32.PostMessageW(hwnd, WM_COMMAND, ID_FILE_RELOADSCRIPT, 0)
                return True

            WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
            user32.EnumWindows(WNDENUMPROC(enum_proc), 0)
        except Exception:
            pass
