$ErrorActionPreference = 'SilentlyContinue'
Set-StrictMode -Off

# ============================================================
#  SELF-ELEVATION
# ============================================================
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $principal.IsInRole($adminRole)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
    exit
}

# ============================================================
#  COLORS  (ANSI 24-bit)
# ============================================================
$ESC = [char]27

$CR     = "$ESC[0m"
$HEADER = "$ESC[38;2;0;120;215m"
$ACCENT = "$ESC[38;2;0;188;242m"
$COK    = "$ESC[38;2;16;185;129m"
$CWARN  = "$ESC[38;2;245;158;11m"
$CERR   = "$ESC[38;2;239;68;68m"
$CDIM   = "$ESC[38;2;120;120;140m"
$CWHITE = "$ESC[38;2;230;230;250m"
$CGOLD  = "$ESC[38;2;250;204;21m"
$CBORD  = "$ESC[38;2;60;80;160m"

# ============================================================
#  PATHS
# ============================================================
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "printers.json"
$DriverExe  = Join-Path $ScriptDir "install\pcl6\install.exe"

$script:Printers = [System.Collections.Generic.List[PSCustomObject]]::new()

# ============================================================
#  UI HELPERS
# ============================================================
function Write-Color {
    param([string]$Text, [string]$Color = $CWHITE, [switch]$NoNewline)
    if ($NoNewline) { Write-Host "$Color$Text$CR" -NoNewline }
    else            { Write-Host "$Color$Text$CR" }
}

function Show-Header {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Clear-Host
    Write-Host ""
    Write-Color "+--------------------------------------------------------------+" $CBORD
    Write-Color "|    HP Universal Printing PCL 6  --  Printer Installer       |" $HEADER
    Write-Color "|                       Version 2.0                           |" $CDIM
    Write-Color "+--------------------------------------------------------------+" $CBORD
    Write-Host ""
}

function Show-Line {
    param([string]$Label = "")
    if ($Label -ne "") {
        $dashes = "-" * [Math]::Max(1, 52 - $Label.Length)
        Write-Color "+-- $Label $dashes+" $ACCENT
    } else {
        Write-Color "+--------------------------------------------------------------+" $ACCENT
    }
}

function Read-Key {
    Write-Color "  Press any key to continue..." $CDIM
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

function Read-Input {
    param([string]$Prompt)
    Write-Host "  $ACCENT$Prompt$CR " -NoNewline
    return (Read-Host).Trim()
}

# ============================================================
#  IP VALIDATION   format: XX.XX.XX.XX
# ============================================================
function Test-IP {
    param([string]$IP)
    if ([string]::IsNullOrWhiteSpace($IP)) { return $false }
    if ($IP -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { return $false }
    foreach ($octet in $IP.Split('.')) {
        $v = [int]$octet
        if ($v -lt 0 -or $v -gt 255) { return $false }
    }
    return $true
}

# ============================================================
#  CONFIG  LOAD / SAVE
# ============================================================
function Load-Config {
    $script:Printers.Clear()
    if (-not (Test-Path $ConfigFile)) { return }
    try {
        $raw  = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json
        foreach ($p in $json.printers) {
            $script:Printers.Add([PSCustomObject]@{
                Name    = [string]$p.name
                IP      = [string]$p.ip
                Default = [bool]$p.default
            })
        }
    } catch {
        Write-Color "  [WARN]  Cannot read printers.json: $_" $CWARN
        Read-Key
    }
}

function Save-Config {
    $list = @(foreach ($p in $script:Printers) {
        [ordered]@{ name = $p.Name; ip = $p.IP; default = $p.Default }
    })
    $out = [ordered]@{ printers = $list }
    $out | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
}

# ============================================================
#  PRINTER TABLE
# ============================================================
function Show-Table {
    Write-Host ""
    Show-Line "Available Printers"
    Write-Host ""
    if ($script:Printers.Count -eq 0) {
        Write-Color "  No printers configured. Use Manage Printers to add some." $CWARN
        Write-Host ""
        Show-Line
        return
    }
    for ($i = 0; $i -lt $script:Printers.Count; $i++) {
        $p   = $script:Printers[$i]
        $num = $i + 1
        $def = ""
        if ($p.Default) { $def = "  $CGOLD[DEFAULT]$CR" }
        Write-Host "  $CBORD[$CGOLD$num$CBORD]$CR  $CWHITE$($p.Name)$CR$def"
        Write-Host "  $CDIM       IP: $($p.IP)$CR"
        Write-Host ""
    }
    Show-Line
}

# ============================================================
#  DRIVER
# ============================================================
function Get-DriverName {
    return (Get-PrinterDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*HP*Universal*PCL*6*' } |
        Select-Object -ExpandProperty Name -First 1)
}

function Install-Driver {
    Show-Header
    Show-Line "Driver Check"
    Write-Host ""

    $drv = Get-DriverName
    if ($drv) {
        Write-Color "  [SKIP]  Driver already installed:" $COK
        Write-Color "          $drv" $CGOLD
        Write-Host ""
        Show-Line
        Write-Host ""
        return $drv
    }

    if (-not (Test-Path $DriverExe)) {
        Write-Color "  [ERR]   Driver installer not found:" $CERR
        Write-Color "          $DriverExe" $CDIM
        Write-Host ""
        Show-Line
        Read-Key
        return $null
    }

    Write-Color "  [....]  Installing HP Universal Printing PCL 6..." $CWHITE
    Write-Color "          This may take 1-3 minutes. Please wait." $CDIM
    Write-Host ""

    Start-Process -FilePath $DriverExe -ArgumentList '/s /v"/qn REBOOT=ReallySuppress"' -Wait
    Start-Sleep -Seconds 5

    $drv = Get-DriverName
    if (-not $drv) {
        Write-Color "  [FAIL]  Driver installation failed." $CERR
        Write-Color "          Verify install\pcl6\install.exe is a valid HP UPD file." $CDIM
        Write-Host ""
        Show-Line
        Read-Key
        return $null
    }

    Write-Color "  [ OK ]  Driver installed:" $COK
    Write-Color "          $drv" $CGOLD
    Write-Host ""
    Show-Line
    Write-Host ""
    return $drv
}

# ============================================================
#  MENU: INSTALL
# ============================================================
function Menu-Install {
    $drv = Install-Driver
    if (-not $drv) { return }

    Show-Header
    Show-Table

    if ($script:Printers.Count -eq 0) { Read-Key; return }

    Write-Host ""
    Show-Line "Select Printers to Install"
    Write-Host ""
    Write-Color "  Numbers separated by commas  e.g.  1,2,3" $CWHITE
    Write-Color "  A  =  install all     Q  =  back" $CWHITE
    Write-Host ""

    while ($true) {
        $raw = Read-Input "Your choice:"

        if ($raw -eq "") {
            Write-Color "  [WARN]  Empty input." $CWARN
            Write-Host ""
            continue
        }

        if ($raw -eq "Q" -or $raw -eq "q") { return }

        $indices = [System.Collections.Generic.List[int]]::new()

        if ($raw -eq "A" -or $raw -eq "a") {
            0..($script:Printers.Count - 1) | ForEach-Object { $indices.Add($_) }
        } else {
            if ($raw -notmatch '^[\d,]+$') {
                Write-Color "  [ERR]   Use digits and commas only." $CERR
                Write-Host ""
                continue
            }
            $bad = $false
            foreach ($tok in ($raw -split ',')) {
                if ($tok -eq '') { continue }
                $n = [int]$tok
                if ($n -lt 1 -or $n -gt $script:Printers.Count) {
                    Write-Color "  [ERR]   $n is out of range. Valid: 1 - $($script:Printers.Count)" $CERR
                    $bad = $true
                    break
                }
                $idx = $n - 1
                if (-not $indices.Contains($idx)) { $indices.Add($idx) }
            }
            if ($bad) { Write-Host ""; continue }
        }

        if ($indices.Count -eq 0) {
            Write-Color "  [WARN]  Nothing selected." $CWARN
            Write-Host ""
            continue
        }

        Show-Header
        Show-Line "Installing Printers"
        Write-Host ""

        $ok = 0; $fail = 0; $cur = 0

        foreach ($idx in $indices) {
            $cur++
            $p    = $script:Printers[$idx]
            $port = "$($p.IP)"

            Write-Host "  $CGOLD[$cur/$($indices.Count)]$CR  $CWHITE$($p.Name)$CR"
            Write-Host "  $CDIM         IP: $($p.IP)$CR"

            if (Get-Printer -Name $p.Name -ErrorAction SilentlyContinue) {
                Write-Color "  [SKIP]  Already installed." $CWARN
                Write-Host ""
                $ok++
                continue
            }

            try {
                Add-PrinterPort -Name $port -PrinterHostAddress $p.IP -ErrorAction Stop
                Write-Color "  [ OK ]  Port created: $port" $COK
            } catch {
                Write-Color "  [INFO]  Port exists: $port" $CWARN
            }

            try {
                Add-Printer -Name $p.Name -DriverName $drv -PortName $port -ErrorAction Stop
                Write-Color "  [ OK ]  Printer installed." $COK
                if ($p.Default) {
                    (New-Object -ComObject WScript.Network).SetDefaultPrinter($p.Name)
                    Write-Color "  [DEF]   Set as default." $CGOLD
                }
                $ok++
            } catch {
                Write-Color "  [FAIL]  $($_.Exception.Message)" $CERR
                $fail++
            }
            Write-Host ""
        }

        Show-Line
        Write-Host ""
        Show-Line "Summary"
        Write-Host ""
        Write-Color "  Successfully installed  : $ok"   $COK
        Write-Color "  Failed                  : $fail" $CERR
        Write-Host ""
        Show-Line
        Read-Key
        return
    }
}

# ============================================================
#  MENU: ADD PRINTER
# ============================================================
function Menu-Add {
    Show-Header
    Show-Line "Add New Printer"
    Write-Host ""

    $name = Read-Input "Printer display name:"
    if ($name -eq "") {
        Write-Color "  [ERR]   Name cannot be empty." $CERR
        Read-Key; return
    }
    if ($script:Printers | Where-Object { $_.Name -eq $name }) {
        Write-Color "  [ERR]   Name already exists." $CERR
        Read-Key; return
    }

    $ip = ""
    while ($true) {
        $ip = Read-Input "IP address  (e.g. 192.168.1.101):"
        if (Test-IP $ip) { break }
        Write-Color "  [ERR]   Invalid IP. Required format: XX.XX.XX.XX" $CERR
    }

    $def = Read-Input "Set as default? [Y/N]:"
    $isDefault = ($def -eq "Y" -or $def -eq "y")

    if ($isDefault) {
        foreach ($p in $script:Printers) { $p.Default = $false }
    }

    $script:Printers.Add([PSCustomObject]@{ Name = $name; IP = $ip; Default = $isDefault })
    Save-Config

    Write-Host ""
    Write-Color "  [ OK ]  Printer added and saved." $COK
    Read-Key
}

# ============================================================
#  MENU: EDIT IP
# ============================================================
function Menu-EditIP {
    Show-Header
    Show-Table
    if ($script:Printers.Count -eq 0) { Read-Key; return }

    $inp = Read-Input "Printer number to edit IP  (Q = back):"
    if ($inp -eq "Q" -or $inp -eq "q") { return }
    if ($inp -notmatch '^\d+$') { Write-Color "  [ERR]   Invalid." $CERR; Read-Key; return }
    $n = [int]$inp
    if ($n -lt 1 -or $n -gt $script:Printers.Count) {
        Write-Color "  [ERR]   Out of range. Valid: 1 - $($script:Printers.Count)" $CERR
        Read-Key; return
    }
    $idx = $n - 1
    $p   = $script:Printers[$idx]

    Write-Host ""
    Write-Host "  $CWHITE$($p.Name)$CR"
    Write-Host "  $CDIM  Current IP: $($p.IP)$CR"
    Write-Host ""

    while ($true) {
        $newIP = Read-Input "New IP address:"
        if (Test-IP $newIP) { break }
        Write-Color "  [ERR]   Invalid IP. Required format: XX.XX.XX.XX" $CERR
    }

    $script:Printers[$idx].IP = $newIP
    Save-Config

    Write-Host ""
    Write-Color "  [ OK ]  IP updated: $($p.Name) -> $newIP" $COK
    Read-Key
}

# ============================================================
#  MENU: RENAME
# ============================================================
function Menu-Rename {
    Show-Header
    Show-Table
    if ($script:Printers.Count -eq 0) { Read-Key; return }

    $inp = Read-Input "Printer number to rename  (Q = back):"
    if ($inp -eq "Q" -or $inp -eq "q") { return }
    if ($inp -notmatch '^\d+$') { Write-Color "  [ERR]   Invalid." $CERR; Read-Key; return }
    $n = [int]$inp
    if ($n -lt 1 -or $n -gt $script:Printers.Count) {
        Write-Color "  [ERR]   Out of range. Valid: 1 - $($script:Printers.Count)" $CERR
        Read-Key; return
    }
    $idx = $n - 1
    $p   = $script:Printers[$idx]

    Write-Host ""
    Write-Host "  $CDIM  Current name: $($p.Name)$CR"
    Write-Host ""

    $newName = Read-Input "New display name:"
    if ($newName -eq "") { Write-Color "  [ERR]   Name cannot be empty." $CERR; Read-Key; return }
    if ($script:Printers | Where-Object { $_.Name -eq $newName }) {
        Write-Color "  [ERR]   Name already exists." $CERR; Read-Key; return
    }

    $oldName = $p.Name
    $script:Printers[$idx].Name = $newName
    Save-Config

    Write-Host ""
    Write-Color "  [ OK ]  Renamed: $oldName -> $newName" $COK
    Read-Key
}

# ============================================================
#  MENU: SET DEFAULT
# ============================================================
function Menu-SetDefault {
    Show-Header
    Show-Table
    if ($script:Printers.Count -eq 0) { Read-Key; return }

    $inp = Read-Input "Printer number to set as default  (Q = back):"
    if ($inp -eq "Q" -or $inp -eq "q") { return }
    if ($inp -notmatch '^\d+$') { Write-Color "  [ERR]   Invalid." $CERR; Read-Key; return }
    $n = [int]$inp
    if ($n -lt 1 -or $n -gt $script:Printers.Count) {
        Write-Color "  [ERR]   Out of range. Valid: 1 - $($script:Printers.Count)" $CERR
        Read-Key; return
    }
    $idx = $n - 1
    for ($i = 0; $i -lt $script:Printers.Count; $i++) {
        $script:Printers[$i].Default = ($i -eq $idx)
    }
    Save-Config

    Write-Host ""
    Write-Color "  [ OK ]  Default set: $($script:Printers[$idx].Name)" $COK
    Read-Key
}

# ============================================================
#  MENU: REMOVE
# ============================================================
function Menu-Remove {
    Show-Header
    Show-Table
    if ($script:Printers.Count -eq 0) { Read-Key; return }

    $inp = Read-Input "Printer number to remove  (Q = back):"
    if ($inp -eq "Q" -or $inp -eq "q") { return }
    if ($inp -notmatch '^\d+$') { Write-Color "  [ERR]   Invalid." $CERR; Read-Key; return }
    $n = [int]$inp
    if ($n -lt 1 -or $n -gt $script:Printers.Count) {
        Write-Color "  [ERR]   Out of range. Valid: 1 - $($script:Printers.Count)" $CERR
        Read-Key; return
    }
    $idx  = $n - 1
    $name = $script:Printers[$idx].Name

    Write-Host ""
    $conf = Read-Input "Remove '$name'?  [Y/N]:"
    if ($conf -ne "Y" -and $conf -ne "y") { return }

    $script:Printers.RemoveAt($idx)
    Save-Config

    Write-Host ""
    Write-Color "  [ OK ]  Removed: $name" $COK
    Read-Key
}

# ============================================================
#  MENU: MANAGE
# ============================================================
function Menu-Manage {
    while ($true) {
        Show-Header
        Show-Table
        Write-Host ""
        Show-Line "Manage Printers"
        Write-Host ""
        Write-Color "  [1]  Add new printer" $CWHITE
        Write-Color "  [2]  Edit printer IP" $CWHITE
        Write-Color "  [3]  Rename printer" $CWHITE
        Write-Color "  [4]  Set default printer" $CWHITE
        Write-Color "  [5]  Remove printer" $CWHITE
        Write-Color "  [0]  Back" $CDIM
        Write-Host ""
        Show-Line
        Write-Host ""

        $ch = Read-Input "Your choice:"
        switch ($ch) {
            "1" { Menu-Add        }
            "2" { Menu-EditIP     }
            "3" { Menu-Rename     }
            "4" { Menu-SetDefault }
            "5" { Menu-Remove     }
            "0" { return }
            default {
                Write-Color "  [WARN]  Choose 0-5." $CWARN
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ============================================================
#  MAIN LOOP
# ============================================================
Load-Config

while ($true) {
    Show-Header
    Show-Line "Main Menu"
    Write-Host ""
    Write-Color "  [1]  Install Network Printers" $CWHITE
    Write-Color "  [2]  Manage Printer List" $CWHITE
    Write-Color "  [0]  Exit" $CDIM
    Write-Host ""
    Show-Line
    Write-Host ""

    $ch = Read-Input "Your choice:"
    switch ($ch) {
        "1" { Menu-Install }
        "2" { Menu-Manage  }
        "0" { Clear-Host; exit 0 }
        default {
            Write-Color "  [WARN]  Choose 0, 1 or 2." $CWARN
            Start-Sleep -Seconds 1
        }
    }
}
