# Network Printer Installer

Universal PowerShell TUI for deploying and managing network printers.
Supports any printer driver distributed as an **EXE installer** or **INF file**.
Printer list is stored in `printers.json` and fully manageable without editing files manually.

---

## Requirements

| Component  | Requirement                          |
|------------|--------------------------------------|
| OS         | Windows 10 / 11, Server 2019 / 2022  |
| PowerShell | 5.1 or higher                        |
| Rights     | Administrator (UAC prompt at launch) |
| Driver     | EXE installer  **or**  INF file      |

---

## File Structure

Place all files in the same folder:

```
PrinterInstaller.ps1          <- main script
printers.json                 <- printer list (auto-created / managed via TUI)
install\
  <your_driver_folder>\
    install.exe               <- EXE driver installer   (if CFG_DriverType = EXE)
    oemsetup.inf              <- INF driver file        (if CFG_DriverType = INF)
```

> The subfolder name and file name are fully configurable via `$CFG_DriverRelPath`.

---

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File PrinterInstaller.ps1
```

The script will:
1. Request administrator rights via UAC
2. Check whether the driver is already installed (via `$CFG_DriverPattern`)
3. If not found — install it silently (EXE or INF, depending on `$CFG_DriverType`)
4. Open the main menu

---

## Main Menu

```
[1]  Install Network Printers   <- select printers from the list and install them
[2]  Manage Printer List        <- add / edit / rename / remove printers
[0]  Exit
```

### Install Network Printers

- Enter numbers separated by commas: `1,3,5`
- Enter `A` to install all printers at once
- Enter `Q` to go back
- Printers already present in Windows are skipped automatically
- The printer marked `[DEFAULT]` is set as the Windows default after installation

### Manage Printer List

```
[1]  Add new printer       <- name + IP + optional default flag
[2]  Edit printer IP       <- change the IP of an existing entry
[3]  Rename printer        <- change the display name
[4]  Set default printer   <- choose which printer gets [DEFAULT]
[5]  Remove printer        <- delete an entry from the list
[0]  Back
```

All changes are saved to `printers.json` immediately.

---

## printers.json

Stores the printer list as plain JSON. Editable manually or via the TUI.

```json
{
  "printers": [
    {
      "name": "BUH-PRT01",
      "ip": "10.108.0.101",
      "default": false
    },
    {
      "name": "FIN-PRT06",
      "ip": "10.108.0.106",
      "default": true
    }
  ]
}
```

| Field     | Type    | Description                                               |
|-----------|---------|-----------------------------------------------------------|
| `name`    | string  | Display name shown in Windows Devices & Printers          |
| `ip`      | string  | IP address in format `XX.XX.XX.XX`                        |
| `default` | boolean | Set `true` on exactly one printer to make it the system default |

> **IP format rule:** each octet must be `0–255`. Example: `10.108.0.101` is valid, `10.108.0.256` is not.

---

## Configuration

Open `PrinterInstaller.ps1` in any text editor.
All settings are at the **top of the file**, between:

```
>>>  USER CONFIGURATION  <<<
```
and
```
END OF CONFIGURATION
```

**Do not modify anything below the `END OF CONFIGURATION` line.**

---

### Branding

```powershell
$CFG_Title       = "Network Printer Installer"
$CFG_Version     = "2.1"
$CFG_CompanyName = "IT Department"
```

| Variable          | What it changes                        |
|-------------------|----------------------------------------|
| `$CFG_Title`      | Text shown in the TUI header banner    |
| `$CFG_Version`    | Version shown in the TUI header banner |
| `$CFG_CompanyName`| Documentation / comments only          |

---

### Driver Type

```powershell
$CFG_DriverType = "EXE"    # or "INF"
```

| Value | Behaviour |
|-------|-----------|
| `EXE` | Runs the installer with `$CFG_DriverSilentArgs` via `Start-Process -Wait` |
| `INF` | Injects the driver into the Windows driver store via `pnputil /add-driver /install`, then verifies via `Get-PrinterDriver` |

---

### Driver Path

```powershell
$CFG_DriverRelPath = "install\pcl6\install.exe"
```

Path to the driver file **relative to the script folder**.

| Driver type | Example value |
|-------------|---------------|
| EXE         | `"install\pcl6\install.exe"` |
| INF         | `"install\driver\oemsetup.inf"` |

---

### Silent Install Arguments  *(EXE only)*

```powershell
$CFG_DriverSilentArgs = '/s /v"/qn REBOOT=ReallySuppress"'
```

Ignored when `$CFG_DriverType = "INF"`.

| Installer type | Typical arguments |
|----------------|-------------------|
| HP UPD         | `/s /v"/qn REBOOT=ReallySuppress"` |
| MSI-based      | `/quiet /norestart` |
| NSIS-based     | `/S` |
| InstallShield  | `/s /v/qn` |

---

### Driver Detection Pattern

```powershell
$CFG_DriverPattern = "*HP*Universal*PCL*6*"
```

Wildcard pattern matched against `Get-PrinterDriver` output.
Used both to **skip installation** if the driver is already present and to **verify** after install.

To find the exact name of an installed driver, run in PowerShell:
```powershell
Get-PrinterDriver | Select-Object Name
```

| Driver                  | Pattern example               |
|-------------------------|-------------------------------|
| HP Universal PCL 6      | `"*HP*Universal*PCL*6*"`      |
| HP Universal PostScript | `"*HP*Universal*PostScript*"` |
| Canon UFRII             | `"*Canon*UFRII*"`             |
| Kyocera KX              | `"*Kyocera*KX*"`              |
| Xerox Global Print      | `"*Xerox*Global*Print*"`      |
| Any driver              | `"*YourDriverNameHere*"`      |

---

### Printer List File

```powershell
$CFG_JsonFile = "printers.json"
```

Name of the JSON file. Must be in the same folder as the script.
Change if you want to maintain multiple separate printer lists, e.g. `"printers_floor2.json"`.

---

### TCP/IP Port Prefix

```powershell
$CFG_PortPrefix = "PRN-"
```

Every created port is named `<PREFIX><IP>`, e.g. `PRN-10.108.0.101`.
Change if the default prefix conflicts with existing ports on your system.

---

### Color Scheme

All colors use ANSI 24-bit RGB format `"R;G;B"` where each channel is `0–255`.

```powershell
$CFG_Color_Header = "0;120;215"     # Title bar text   — blue
$CFG_Color_Accent = "0;188;242"     # Section borders  — light blue
$CFG_Color_OK     = "16;185;129"    # Success messages — green
$CFG_Color_Warn   = "245;158;11"    # Warnings         — amber
$CFG_Color_Err    = "239;68;68"     # Errors           — red
$CFG_Color_Dim    = "120;120;140"   # Subtle text      — grey
$CFG_Color_White  = "230;230;250"   # Normal text      — soft white
$CFG_Color_Gold   = "250;204;21"    # Numbers/accents  — yellow
$CFG_Color_Border = "60;80;160"     # Box borders      — dark blue
```

**Example — green corporate theme:**
```powershell
$CFG_Color_Header = "34;197;94"
$CFG_Color_Accent = "74;222;128"
$CFG_Color_Border = "22;101;52"
```

> Requires Windows 10 version 1511 or later for ANSI color rendering.

---

## Building a Self-Extracting EXE  *(optional)*

To distribute as a single clickable `.exe` using WinRAR:

1. Select: `PrinterInstaller.ps1`, `printers.json`, `install\` folder
2. Right-click → **Add to archive…**
3. Archive name: `PrinterInstaller.exe`
4. Format: **RAR**, enable **Create SFX archive**
5. **Advanced → SFX options:**
   - *Setup* tab → Run after extraction:
     ```
     powershell.exe -ExecutionPolicy Bypass -File PrinterInstaller.ps1
     ```
   - *Modes* tab → Unpack to temporary folder, Silent mode: Hide all
   - *Text and Icon* tab → Title: `Network Printer Installer`
6. Click OK

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Script exits immediately, no UAC | Execution policy blocks the script | Run with `-ExecutionPolicy Bypass` |
| `Driver file not found` | Path in `$CFG_DriverRelPath` is wrong | Check the path relative to the script folder |
| `Driver not found after installation` | `$CFG_DriverPattern` does not match the actual driver name | Run `Get-PrinterDriver \| Select-Object Name` and adjust the pattern |
| INF driver installs but printer fails | pnputil succeeded but driver name differs from pattern | Run `Get-PrinterDriver \| Select-Object Name` after INF install to confirm the name, then update `$CFG_DriverPattern` |
| `[FAIL] Could not install printer` | Port or driver name mismatch | Check that `$CFG_PortPrefix` does not duplicate an existing port, and that the driver name matched correctly |
| `No printers found in printers.json` | JSON syntax error | Validate at jsonlint.com — look for missing commas between `}` and `{` |
| Colors show as garbled text | Windows version too old | Update to Windows 10 1511+ or use Windows Terminal |
