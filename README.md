<div align="center">

<h1>
  MKBoard &nbsp;·&nbsp;
  <span dir="rtl" lang="sd">سنڌي</span>
</h1>

**Sindhi Keyboard Layout for Windows 10 / 11**

*Unofficial keyboard driver for typing Sindhi in Arabic script —
AltGr support · extended characters · ligatures · AMD64 & ARM64*

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-3B6D11?logo=windows&logoColor=white)](https://github.com/MurShidM01/MKBoard)
[![Architecture](https://img.shields.io/badge/architecture-AMD64%20%7C%20ARM64-185FA5?logo=windows-terminal&logoColor=white)](https://github.com/MurShidM01/MKBoard)
[![License](https://img.shields.io/badge/license-MIT-854F0B)](LICENSE)

</div>

---

## ⚡ Quick Install

> Run in **PowerShell as Administrator**

```powershell
irm "https://github.com/MurShidM01/MKBoard/blob/main/install.ps1?raw=1" | iex
```

Reboot → press **Win + Space** → select **Sindhi**. Done.

---

## ✨ Features

| | Feature | Detail |
|---|---|---|
| 🔍 | **Auto-architecture detection** | Picks the correct AMD64 or ARM64 driver automatically |
| ⚡ | **Auto-install on first run** | No prompts — installs itself, then asks for a reboot |
| 🔧 | **Repair / Uninstall menu** | Shows up on subsequent runs for easy maintenance |
| ⌨️ | **AltGr support** | Sindhi extended characters via AltGr modifier |
| 🔤 | **Extended Sindhi characters** | `ڦ` `ٻ` `ٽ` `ٿ` `ڙ` — script-specific glyphs |
| 🔗 | **Ligature support** | Two-character ligatures: `ٻَ` `ٺَ` `ٽَ` `ڄَ` `ڙَ` |
| 📐 | **IEEE-1265 compliant** | Built to the standard keyboard layout spec |
| ✅ | **Byte-accurate across architectures** | Character data verified identical in AMD64 and ARM64 builds |

---

## 🔧 Post-Install Usage

After rebooting:

1. Press **Win + Space** to open the language switcher
2. Select **Sindhi** from the list
3. Start typing

To switch back to your previous layout, press **Win + Space** again.

---

## 🛠️ Repair or Uninstall

Re-running the installer after installation shows a menu:

```
[1] Repair    - re-install the driver and all settings
[2] Uninstall - remove the keyboard completely
[3] Cancel    - exit without changes
```

Or use command-line flags directly:

```powershell
# Force a clean install
.\install.ps1 -Action Install

# Re-apply all settings
.\install.ps1 -Action Repair

# Remove completely
.\install.ps1 -Action Uninstall
```

---

## 📁 File Structure

```
MKBoard/
├── install.ps1          ← One-line installer (same as the raw URL target)
├── amd64/
│   └── MKBoard.dll      ← AMD64 driver
├── arm64/
│   └── MKBoard.dll      ← ARM64 driver
├── MKBoard.klc          ← Source layout definition
└── LICENSE
```

---

## 🏗️ Technical Details

```
KLID               : 00000859  (Sindhi - Pakistan)
Layout Id          : 00d9
Input Method Tip   : 0859:00000859
Language Tag       : sd-Arab-PK
```

| File | Size | Architecture |
|------|------|--------------|
| `MKBoard.dll` | 7,168 bytes | AMD64 / x64 |
| `MKBoard.dll` | 7,680 bytes | ARM64 |

---

## 📜 License

MIT License — free to use, modify, and distribute. See [LICENSE](LICENSE) for details.

---

<div align="center">

**© 2026 MurShidM · Ali Khan Jalbani**

</div>