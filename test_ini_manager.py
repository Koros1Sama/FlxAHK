# -*- coding: utf-8 -*-
"""اختبار round-trip لملف Flx_Settings.ini الحقيقي (على نسخة مؤقتة)."""
import os
import shutil
import sys
import tempfile

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "Scripts"))
import ini_manager

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Flx_Settings.ini")
TMP = os.path.join(tempfile.gettempdir(), "flx_ini_roundtrip_test.ini")
shutil.copyfile(SRC, TMP)

# 1) قراءة ثم كتابة بدون أي تعديل — يجب أن يبقى المحتوى مكافئًا
doc1 = ini_manager.IniDocument.load(TMP)
doc1.save(TMP)
doc2 = ini_manager.IniDocument.load(TMP)

sections_before = ini_manager.IniDocument.load(SRC).sections()
ok = True

if doc2.sections() != sections_before:
    print("FAIL: ترتيب الأقسام تغير", doc2.sections())
    ok = False

for section in sections_before:
    a = ini_manager.IniDocument.load(SRC).get_section(section)
    b = doc2.get_section(section)
    if list(a.keys()) != list(b.keys()):
        print("FAIL: ترتيب مفاتيح القسم تغير:", section)
        ok = False
    for k in a:
        if a[k] != b[k]:
            print("FAIL: قيمة تغيرت [%s] %s: %r -> %r" % (section, k, a[k], b[k]))
            ok = False

# 2) اختبار دوال المجال
cfg = ini_manager.FlxConfig(TMP)
entries = list(cfg.iter_hotkeys())
print("عدد الاختصارات المقروءة:", len(entries))
assert len(entries) > 30, "يجب قراءة كل الاختصارات"

# مفتاح بشرط نافذة
cond_entries = [e for e in entries if e.condition]
print("اختصارات بشرط نافذة:", [(e.fullkey, e.action[:40]) for e in cond_entries])
assert any(e.key == "k" and "explorer" in e.condition for e in cond_entries)

# 3) إضافة/تعديل/حذف اختصار
cfg.upsert_hotkey("simple", "T|ahk_exe test.exe", "Send hello")
conflict = cfg.find_conflict("t|AHK_EXE TEST.EXE")  # غير حساس للحالة
assert conflict is not None and conflict.action == "Send hello"
cfg.remove_hotkey_everywhere("T|ahk_exe test.exe")
assert cfg.find_conflict("t|ahk_exe test.exe") is None
print("إضافة/بحث/حذف: OK")

# 4) حفظ بعد تعديل حقيقي ثم إعادة القراءة
cfg.update_settings({"CheckInterval": "1500", "IsSecureMode": "1"})
cfg.save()
cfg2 = ini_manager.FlxConfig(TMP)
s = cfg2.get_settings()
assert s["CheckInterval"] == "1500" and s["IsSecureMode"] == "1"
print("حفظ الإعدادات وإعادة قراءتها: OK")

# 5) التأكد من الترميز UTF-16 LE BOM
with open(TMP, "rb") as f:
    head = f.read(2)
assert head == bytes((0xFF, 0xFE)), "الملف يجب أن يكون UTF-16 LE مع BOM"
print("ترميز UTF-16 LE BOM: OK")

# 6) تحويل ; <-> VKBA
assert ini_manager.normalize_stored_key(";") == "VKBA"
assert ini_manager.display_key("VKBA") == ";"
assert ini_manager.split_fullkey("k|ahk_exe explorer.exe") == ("k", "ahk_exe explorer.exe")
assert ini_manager.strip_modifiers("^+T") == "T"
print("دوال المفاتيح: OK")

os.remove(TMP)
print("\n=== ALL TESTS PASSED ===" if ok else "\n=== FAILURES ABOVE ===")
sys.exit(0 if ok else 1)
