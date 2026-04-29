"""Debug: scan VSCode via UI Automation and list all buttons and text controls."""
import uiautomation as auto
import time

print("Scanning VSCode UI Automation tree...")
print("Looking for Chrome_WidgetWin_1 (VSCode)...")

vscode = auto.WindowControl(searchDepth=1, ClassName="Chrome_WidgetWin_1")
if not vscode.Exists(1):
    print("ERROR: VSCode window not found!")
else:
    print(f"Found VSCode: '{vscode.Name}'")

print("\n--- Searching for buttons ---")
for name in ["Retry", "Allow", "Dismiss", "retry", "allow"]:
    btn = auto.ButtonControl(searchDepth=20, Name=name)
    exists = btn.Exists(0.3)
    print(f"  Button '{name}': {'FOUND at ' + str(btn.BoundingRectangle) if exists else 'not found'}")

print("\n--- All buttons in VSCode ---")
try:
    buttons = vscode.GetChildren()
    def scan(ctrl, depth=0):
        if depth > 12:
            return
        try:
            ct = ctrl.ControlTypeName
            n  = ctrl.Name
            if ct in ("ButtonControl", "Button") and n:
                print(f"  {'  '*depth}BUTTON: '{n}' at {ctrl.BoundingRectangle}")
            elif n and any(kw in n.lower() for kw in ["retry", "allow", "dismiss", "error", "terminated", "agent"]):
                print(f"  {'  '*depth}{ct}: '{n}'")
        except:
            pass
        try:
            for c in ctrl.GetChildren():
                scan(c, depth+1)
        except:
            pass
    
    scan(vscode)
except Exception as e:
    print(f"ERROR: {e}")

print("\nDone.")
