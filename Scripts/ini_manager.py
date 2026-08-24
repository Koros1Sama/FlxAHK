# -*- coding: utf-8 -*-
"""
ini_manager.py — قراءة وكتابة Flx_Settings.ini بنفس تنسيق AutoHotkey تمامًا.

- الترميز: UTF-16 LE مع BOM (نفس ما يكتبه AHK v1).
- الحفاظ على ترتيب الأقسام والمفاتيح والأقسام غير المعروفة (round-trip آمن).
- التعامل مع تحويل ";" <-> "VKBA" في أسماء المفاتيح.
- الفصل على أول "=" فقط (لأن القيم قد تحتوي فواصل مثل: Send, ^+{Left}{Del}).
"""

import os
import re
import shutil
import time

INI_ENCODING = "utf-16"

SECTION_RE = re.compile(r"^\[(.+)\]$")

# عدد النسخ الاحتياطية التي تُحتفظ بها قبل الحذف التلقائي للأقدم
MAX_BACKUPS = 10


def backup_file(path):
    """نسخة احتياطية مؤرخة قبل أي تعديل — تُحفظ في مجلد Backups بجوار الملف."""
    try:
        if not os.path.exists(path):
            return None
        backup_dir = os.path.join(os.path.dirname(path), "Backups")
        os.makedirs(backup_dir, exist_ok=True)
        stamp = time.strftime("%Y%m%d_%H%M%S")
        target = os.path.join(
            backup_dir,
            "%s_%s%s" % (os.path.splitext(os.path.basename(path))[0], stamp,
                         os.path.splitext(path)[1]),
        )
        shutil.copy2(path, target)
        # حذف الأقدم إذا تجاوزنا الحد
        pattern = re.compile(
            r"^%s_\d{8}_\d{6}%s$"
            % (re.escape(os.path.splitext(os.path.basename(path))[0]),
               re.escape(os.path.splitext(path)[1]))
        )
        backups = sorted(f for f in os.listdir(backup_dir) if pattern.match(f))
        for old in backups[:-MAX_BACKUPS]:
            try:
                os.remove(os.path.join(backup_dir, old))
            except OSError:
                pass
        return target
    except OSError:
        return None


class IniDocument:
    """مستند INI مرتّب يحافظ على الأقسام والمفاتيح كما هي."""

    def __init__(self):
        self._sections = {}  # dict محفوظ الترتيب: section -> OrderedDict(key -> value)

    # ---------- تحميل وحفظ ----------

    @classmethod
    def load(cls, path):
        doc = cls()
        with open(path, "r", encoding=INI_ENCODING) as f:
            raw = f.read()
        current = ""
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            m = SECTION_RE.match(line)
            if m:
                current = m.group(1).strip()
                if current not in doc._sections:
                    doc._sections[current] = {}
                continue
            if "=" in line and current:
                key, value = line.split("=", 1)
                doc._sections[current][key.strip()] = value.strip()
            elif current:
                # سطر بدون قيمة (مفتاح فارغ القيمة) — نحافظ عليه
                doc._sections[current].setdefault(line, "")
        return doc

    def save(self, path):
        lines = []
        for section, keys in self._sections.items():
            lines.append("[%s]" % section)
            for key, value in keys.items():
                if value:
                    lines.append("%s=%s" % (key, value))
                else:
                    lines.append("%s=" % key)
            lines.append("")
        tmp = path + ".tmp"
        with open(tmp, "w", encoding=INI_ENCODING) as f:
            f.write("\n".join(lines))
        os.replace(tmp, path)

    # ---------- وصول عام ----------

    def sections(self):
        return list(self._sections.keys())

    def get_section(self, name, create=False):
        if name not in self._sections:
            if not create:
                return {}
            self._sections[name] = {}
        return self._sections[name]

    def get_value(self, section, key, default=""):
        sec = self.get_section(section)
        if key in sec:
            return sec[key]
        # AHK غير حساس لحالة الحروف في أسماء المفاتيح
        for k, v in sec.items():
            if k.lower() == key.lower():
                return v
        return default

    def set_value(self, section, key, value):
        sec = self.get_section(section, create=True)
        # حذف أي صيغة بنفس الاسم بحالة مختلفة حتى لا تتكرر المفاتيح
        for k in list(sec.keys()):
            if k.lower() == key.lower():
                del sec[k]
        sec[key] = value

    def delete_value(self, section, key):
        sec = self.get_section(section)
        for k in list(sec.keys()):
            if k.lower() == key.lower():
                del sec[k]
                return True
        return False


# ================= أدوات خاصة بمجال FlxAHK =================

def normalize_stored_key(key):
    """توحيد اسم المفتاح قبل تخزينه في INI (كما يفعل محمل Flx.ahk)."""
    key = key.strip().strip('"')
    key = key.replace(";", "VKBA")
    return key


def display_key(key):
    """عرض المفتاح للمستخدم: VKBA تصبح ;"""
    return key.replace("VKBA", ";")


def split_fullkey(fullkey):
    """'k|ahk_exe explorer.exe' -> ('k', 'ahk_exe explorer.exe')"""
    fullkey = fullkey.strip()
    if "|" in fullkey:
        key, cond = fullkey.split("|", 1)
        return key.strip(), cond.strip()
    return fullkey, ""


def join_fullkey(key, condition):
    key = normalize_stored_key(key)
    condition = condition.strip()
    if condition:
        return "%s|%s" % (key, condition)
    return key


def strip_modifiers(key):
    """إزالة رموز المعدلات +^!# من اسم المفتاح (نفس RegExReplace في AHK)."""
    return re.sub(r"[+^!#]", "", key)


HOTKEY_TYPES = {
    "simple": ("CustomHotkeys", "بسيط (Flx)"),
    "advanced": ("AdvancedScripts", "متقدم (Flx)"),
    "noflx": ("NoFlx", "بسيط (NoFlx)"),
}


class HotkeyEntry:
    """صف اختصار واحد موحّد من أي قسم."""

    def __init__(self, kind, fullkey, action):
        self.kind = kind              # simple | advanced | noflx
        self.fullkey = fullkey        # كما هو مخزن في INI
        self.action = action          # القيمة المخزنة
        self.key, self.condition = split_fullkey(fullkey)

    @property
    def type_label(self):
        return HOTKEY_TYPES[self.kind][1]

    @property
    def is_script_action(self):
        if self.kind == "advanced":
            return True
        return self.action.lower().endswith(".ahk")

    def resolved_script_path(self, base_dir):
        if not self.is_script_action:
            return None
        action = self.action.replace("/", "\\")
        if action.startswith("\\") or (len(action) > 1 and action[1] == ":"):
            return action
        return os.path.join(base_dir, action)


class FlxConfig:
    """واجهة عالية المستوى فوق IniDocument لمشروع FlxAHK."""

    SETTINGS_KEYS = (
        "MonitoredFolders",
        "MonitoredFoldersWithSub",
        "ExcludedFolders",
        "ProcessNames",
        "CheckInterval",
        "IsSecureMode",
    )

    def __init__(self, ini_path):
        self.ini_path = ini_path
        self.doc = IniDocument.load(ini_path)

    # ---------- حفظ ----------

    def save(self):
        backup_file(self.ini_path)
        self.doc.save(self.ini_path)

    # ---------- إعدادات عامة ----------

    def get_base_hotkey(self):
        return self.doc.get_value("HotkeySettings", "BaseKey", "SC056")

    def set_base_hotkey(self, value):
        self.doc.set_value("HotkeySettings", "BaseKey", value.strip())

    def get_settings(self):
        defaults = {
            "MonitoredFolders": "",
            "MonitoredFoldersWithSub": "",
            "ExcludedFolders": "",
            "ProcessNames": "telegram.exe",
            "CheckInterval": "1000",
            "IsSecureMode": "0",
        }
        out = {}
        for key, default in defaults.items():
            out[key] = self.doc.get_value("Settings", key, default)
        return out

    def update_settings(self, values):
        for key in self.SETTINGS_KEYS:
            if key in values:
                self.doc.set_value("Settings", key, str(values[key]).strip())

    # ---------- الاختصارات ----------

    def iter_hotkeys(self):
        for kind, (section, _label) in HOTKEY_TYPES.items():
            for fullkey, value in self.doc.get_section(section).items():
                yield HotkeyEntry(kind, fullkey, value)

    def find_conflict(self, fullkey, exclude_kind=None, exclude_fullkey=None):
        """البحث عن نفس الاختصار في كل الأقسام (غير حساس لحالة الحروف)."""
        wanted = fullkey.lower()
        for entry in self.iter_hotkeys():
            if exclude_kind and exclude_fullkey and \
               entry.kind == exclude_kind and entry.fullkey.lower() == exclude_fullkey.lower():
                continue
            if entry.fullkey.lower() == wanted:
                return entry
        return None

    def upsert_hotkey(self, kind, fullkey, action):
        section = HOTKEY_TYPES[kind][0]
        # إزالة أي نسخة قديمة من نفس المفتاح في أي قسم
        self.remove_hotkey_everywhere(fullkey)
        self.doc.set_value(section, fullkey, action)

    def remove_hotkey_everywhere(self, fullkey):
        removed = False
        for kind, (section, _label) in HOTKEY_TYPES.items():
            if self.doc.delete_value(section, fullkey):
                removed = True
        return removed

    # ---------- السكربتات ----------

    def used_scripts(self):
        used = set()
        adv = self.doc.get_section("AdvancedScripts")
        for value in adv.values():
            used.add(value.replace("/", "\\"))
        for value in self.doc.get_section("NoFlx").values():
            if value.lower().endswith(".ahk"):
                used.add(value.replace("/", "\\"))
        return used
