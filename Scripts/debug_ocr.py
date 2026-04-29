"""Debug: test what the new preprocessed OCR reads from the Antigravity panel."""
import ctypes, mss, pytesseract
from PIL import Image, ImageOps, ImageFilter, ImageEnhance

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
PANEL_START_RATIO = 0.65

def get_screen_size():
    u = ctypes.windll.user32
    return u.GetSystemMetrics(0), u.GetSystemMetrics(1)

sw, sh = get_screen_size()
panel_x = int(sw * PANEL_START_RATIO)
print(f"Screen: {sw}x{sh}, Panel starts at x={panel_x}")

with mss.mss() as sct:
    region = {"left": panel_x, "top": 0, "width": sw - panel_x, "height": sh}
    shot = sct.grab(region)
    raw = Image.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")

raw.save("debug_panel_raw.png")
print("Saved: debug_panel_raw.png")

# Preprocess
img = raw.resize((raw.width*2, raw.height*2), Image.LANCZOS)
img = img.convert("L")
img = ImageOps.invert(img)
img = ImageEnhance.Contrast(img).enhance(2.5)
img = img.filter(ImageFilter.SHARPEN)
img.save("debug_panel_processed.png")
print("Saved: debug_panel_processed.png")

data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT, config="--psm 6 -l eng")
n = len(data["text"])
found = []
for i in range(n):
    txt = data["text"][i].strip()
    conf = int(data["conf"][i])
    if txt and conf > 25:
        sx = (data["left"][i] // 2) + panel_x
        sy = data["top"][i] // 2
        found.append((txt.lower(), sx, sy, conf))

print(f"\nDetected {len(found)} words")
print("\n--- KEY WORDS ---")
for kw in ["allow", "retry", "dismiss", "terminated", "agent", "error", "servers", "reject", "retly"]:
    hits = [(t, x, y, c) for t, x, y, c in found if kw in t]
    if hits:
        for t, x, y, c in hits:
            print(f"  FOUND '{t}' conf={c}% screen=({x},{y})")
    else:
        print(f"  not found: '{kw}'")

print("\n--- ALL TEXT ---")
print(" ".join(t[0] for t in found))
