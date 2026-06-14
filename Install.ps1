<#
================================================================================
  MKBoard - Sindhi Keyboard for Windows 11/10
  Automatic Installer / Repair / Uninstaller
  (c) 2026 MurShidM - Ali Khan Jalbani

  Just run this file. It will:
    * Detect your CPU architecture (x64 / ARM64) and pick the right driver
    * Install the keyboard, language profile and all registry settings
    * After a reboot, switch layouts with  Win + Space

  First run (nothing installed yet) -> installs automatically.
  Already installed                -> shows a menu: Repair / Uninstall / Cancel

  Advanced / unattended use (optional):
    Install.ps1 -Action Install     # force install
    Install.ps1 -Action Repair      # re-apply everything
    Install.ps1 -Action Uninstall   # remove completely
    Install.ps1 -Silent             # never pause/prompt (for automation)
================================================================================
#>
param(
    [ValidateSet('Auto','Install','Repair','Uninstall')]
    [string]$Action = 'Auto',
    [switch]$Silent
)

# --------------------------------------------------------------------------- #
#  Determine script location (handle both local and remote / irm | iex usage)
# --------------------------------------------------------------------------- #
$ScriptDir = $null
if ($MyInvocation.MyCommand.Path) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    Write-Host "Downloading MKBoard from GitHub..." -ForegroundColor Yellow
    $tmpDir = Join-Path $env:TEMP "MKBoard-install"
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zipUrl = "https://github.com/MurShidM01/MKBoard/archive/refs/heads/main.zip"
    Invoke-WebRequest -Uri $zipUrl -OutFile (Join-Path $tmpDir "repo.zip")
    Expand-Archive -Path (Join-Path $tmpDir "repo.zip") -DestinationPath $tmpDir -Force
    $ScriptDir = Join-Path $tmpDir "MKBoard-main"
    Write-OK "Downloaded to $ScriptDir"
}

# --------------------------------------------------------------------------- #
#  Self-elevate to Administrator (required for System32 + HKLM registry).
#  The chosen -Action / -Silent flags are forwarded to the elevated instance.
# --------------------------------------------------------------------------- #
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    try {
        $scriptPath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { Join-Path $ScriptDir "Install.ps1" }
        $fwd = "-Action $Action"
        if ($Silent) { $fwd += " -Silent" }
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName  = (Get-Process -Id $PID).Path
        $psi.Verb      = 'runas'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $fwd"
        [Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "Administrator rights are required. Installation cancelled." -ForegroundColor Red
        Start-Sleep 3
    }
    exit
}

# --------------------------------------------------------------------------- #
#  Constants
# --------------------------------------------------------------------------- #
$KLID        = '00000859'                    # Sindhi (Pakistan) layout id
$LayoutId    = '00d9'                         # custom layout ordinal
$DllName     = 'MKBoard.dll'
$System32    = Join-Path $env:windir 'System32'
$TargetDll   = Join-Path $System32 $DllName
$LayoutText  = 'Sindhi Keyboard For Windows 11/10'
$LayoutName  = 'MKBoard'
$LangTag     = 'sd-Arab-PK'                    # BCP-47 tag from the .klc LOCALENAME
$LangTagAlt  = 'sd-Arab'                       # Windows often normalises to this
$Tip         = '0859:00000859'                 # langID:KLID input method tip
$LayoutKey   = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$KLID"

# --------------------------------------------------------------------------- #
#  Helpers
# --------------------------------------------------------------------------- #
function Write-Step($n, $m) { Write-Host "  [$n] $m" -ForegroundColor Gray }
function Write-OK($m)        { Write-Host "      $m" -ForegroundColor Green }
function Write-Warn2($m)     { Write-Host "      $m" -ForegroundColor Yellow }
function Write-Err($m)       { Write-Host "      $m" -ForegroundColor Red }
function Write-Title($m)     { Write-Host "`n$m" -ForegroundColor Cyan }

function Get-ArchFolder {
    # Returns 'arm64' or 'amd64' (covers WOW emulation via ARCHITEW6432).
    $a = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $a = $env:PROCESSOR_ARCHITEW6432 }
    switch -Wildcard ($a.ToUpper()) {
        'ARM64' { return 'arm64' }
        'AMD64' { return 'amd64' }
        'X64'   { return 'amd64' }
        default { return 'amd64' }   # safe default for x86/unknown
    }
}

function Test-Installed {
    # Considered installed when the DLL is in System32 AND the layout key exists.
    return ((Test-Path $TargetDll) -and (Test-Path $LayoutKey))
}

# --------------------------------------------------------------------------- #
#  Core actions
# --------------------------------------------------------------------------- #
function Install-Keyboard {
    Write-Title "Installing MKBoard Sindhi Keyboard..."

    $arch       = Get-ArchFolder
    $sourceDll  = Join-Path (Join-Path $ScriptDir $arch) $DllName

    Write-Step 1 "Architecture detected: $arch"
    if (-not (Test-Path $sourceDll)) {
        Write-Err "Driver not found: $sourceDll"
        Write-Err "Make sure the '$arch' folder sits next to this script."
        return $false
    }
    Write-OK "Using driver: $sourceDll"

    # 1) Copy the DLL into System32
    Write-Step 2 "Copying driver to System32..."
    try {
        Copy-Item $sourceDll $TargetDll -Force -ErrorAction Stop
        Write-OK "Copied to $TargetDll"
    } catch {
        # File may be locked by an active session; schedule replace on reboot.
        Write-Warn2 "Direct copy failed (file in use). Scheduling replace on reboot."
        $tmp = "$TargetDll.new"
        Copy-Item $sourceDll $tmp -Force
        $sig = '[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool MoveFileEx(string a, string b, int f);'
        $mv = Add-Type -MemberDefinition $sig -Name Mv -Namespace Native -PassThru
        # MOVEFILE_REPLACE_EXISTING(1) | MOVEFILE_DELAY_UNTIL_REBOOT(4) = 5
        $mv::MoveFileEx($tmp, $TargetDll, 5) | Out-Null
        Write-Warn2 "Driver will be placed on next reboot."
    }

    # 2) Register the keyboard layout under HKLM
    Write-Step 3 "Writing keyboard layout registry key..."
    New-Item -Path $LayoutKey -Force | Out-Null
    Set-ItemProperty $LayoutKey -Name 'Layout File'         -Value $DllName
    Set-ItemProperty $LayoutKey -Name 'Layout Text'         -Value $LayoutText
    Set-ItemProperty $LayoutKey -Name 'Layout Display Name' -Value $LayoutText
    Set-ItemProperty $LayoutKey -Name 'Layout Id'           -Value $LayoutId
    Write-OK "Layout key created (KLID $KLID, Layout Id $LayoutId)"

    # 3) Remove any substitute that would hijack our KLID (e.g. -> Urdu)
    Write-Step 4 "Clearing conflicting substitutes..."
    $subs = 'HKCU:\Keyboard Layout\Substitutes'
    if (Test-Path $subs) {
        $s = Get-Item $subs
        foreach ($n in @($s.GetValueNames())) {
            if ($n -ieq $KLID -or $s.GetValue($n) -ieq $KLID) {
                Remove-ItemProperty $subs -Name $n -ErrorAction SilentlyContinue
                Write-OK "Removed substitute $n"
            }
        }
    }
    Write-OK "No conflicting substitutes remain."

    # 4) Add the Sindhi language + input method to the user language list
    Write-Step 5 "Adding Sindhi to your language list..."
    try {
        $list = Get-WinUserLanguageList
        $has  = $list | Where-Object { $_.LanguageTag -like 'sd*' }
        if (-not $has) {
            $list.Add($LangTag)
        }
        # Ensure our tip is on the Sindhi entry
        foreach ($l in $list) {
            if ($l.LanguageTag -like 'sd*') {
                if ($l.InputMethodTips -notcontains $Tip) {
                    $l.InputMethodTips.Clear()
                    $l.InputMethodTips.Add($Tip)
                }
            }
        }
        Set-WinUserLanguageList $list -Force
        Write-OK "Sindhi language registered with input method $Tip"
    } catch {
        Write-Warn2 "Language-list API failed; falling back to Preload registry."
    }

    # 5) Ensure a Preload entry exists for the KLID (belt-and-suspenders)
    Write-Step 6 "Ensuring keyboard Preload entry..."
    $pre = 'HKCU:\Keyboard Layout\Preload'
    if (-not (Test-Path $pre)) { New-Item $pre -Force | Out-Null }
    $item = Get-Item $pre
    $vals = @{}
    foreach ($n in $item.GetValueNames()) { $vals[$n] = $item.GetValue($n) }
    if ($vals.Values -notcontains $KLID) {
        $next = 1
        while ($vals.ContainsKey("$next")) { $next++ }
        New-ItemProperty $pre -Name "$next" -Value $KLID -PropertyType String -Force | Out-Null
        Write-OK "Preload entry $next = $KLID added."
    } else {
        Write-OK "Preload already contains $KLID."
    }

    Write-Title "INSTALLATION COMPLETE"
    Write-Host "  Please REBOOT, then press  Win + Space  to switch to Sindhi." -ForegroundColor Green
    return $true
}

function Uninstall-Keyboard {
    Write-Title "Uninstalling MKBoard Sindhi Keyboard..."

    # 1) Remove Sindhi from the language list
    Write-Step 1 "Removing Sindhi from your language list..."
    try {
        $list = Get-WinUserLanguageList
        $new  = New-Object 'System.Collections.Generic.List[Microsoft.InternationalSettings.Commands.WinUserLanguage]'
        foreach ($l in $list) { if ($l.LanguageTag -notlike 'sd*') { $new.Add($l) } }
        if ($new.Count -ne $list.Count) {
            Set-WinUserLanguageList $new -Force
            Write-OK "Sindhi removed from language list."
        } else { Write-OK "No Sindhi language present." }
    } catch { Write-Warn2 "Language-list step skipped: $($_.Exception.Message)" }

    # 2) Remove Preload entries pointing to our KLID, then renumber
    Write-Step 2 "Cleaning Preload entries..."
    $pre = 'HKCU:\Keyboard Layout\Preload'
    if (Test-Path $pre) {
        $item = Get-Item $pre
        $keep = @()
        foreach ($n in $item.GetValueNames()) {
            $v = $item.GetValue($n)
            if ($v -ine $KLID) { $keep += $v }
        }
        foreach ($n in @((Get-Item $pre).GetValueNames())) { Remove-ItemProperty $pre -Name $n -ErrorAction SilentlyContinue }
        $i = 1; foreach ($v in $keep) { New-ItemProperty $pre -Name "$i" -Value $v -PropertyType String -Force | Out-Null; $i++ }
        Write-OK "Preload cleaned."
    }

    # 3) Remove substitutes
    Write-Step 3 "Removing substitutes..."
    $subs = 'HKCU:\Keyboard Layout\Substitutes'
    if (Test-Path $subs) {
        $s = Get-Item $subs
        foreach ($n in @($s.GetValueNames())) {
            if ($n -ieq $KLID -or $s.GetValue($n) -ieq $KLID) { Remove-ItemProperty $subs -Name $n -ErrorAction SilentlyContinue }
        }
    }
    Write-OK "Substitutes cleaned."

    # 4) Remove the user-profile language registration
    Write-Step 4 "Removing language profile entries..."
    $prof = 'HKCU:\Control Panel\International\User Profile'
    if (Test-Path $prof) {
        Get-ChildItem $prof -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSChildName -like 'sd*') { Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
        $top = Get-Item $prof
        $langs = $top.GetValue('Languages')
        if ($langs) {
            $filtered = @($langs | Where-Object { $_ -notlike 'sd*' })
            Set-ItemProperty $prof -Name 'Languages' -Value $filtered
        }
    }
    Write-OK "Language profile cleaned."

    # 5) Remove the HKLM layout key(s) referencing our DLL
    Write-Step 5 "Removing keyboard layout registry key..."
    $lay = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
    Get-ChildItem $lay -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.'Layout File' -like '*MKBoard*' -or $_.PSChildName -ieq $KLID) {
            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-OK "Layout key removed."

    # 6) Delete the System32 DLL (schedule on reboot if locked)
    Write-Step 6 "Deleting driver from System32..."
    if (Test-Path $TargetDll) {
        try {
            Remove-Item $TargetDll -Force -ErrorAction Stop
            Write-OK "Driver deleted."
        } catch {
            $sig = '[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool MoveFileEx(string a, string b, int f);'
            $mv = Add-Type -MemberDefinition $sig -Name Mv2 -Namespace Native -PassThru
            $mv::MoveFileEx($TargetDll, $null, 4) | Out-Null   # delete on reboot
            Write-Warn2 "Driver in use; scheduled for deletion on reboot."
        }
    } else { Write-OK "Driver already absent." }

    Write-Title "UNINSTALL COMPLETE"
    Write-Host "  A REBOOT is recommended to finish removal." -ForegroundColor Green
}

function Repair-Keyboard {
    Write-Title "Repairing MKBoard Sindhi Keyboard..."
    Write-Host "  (re-applying driver and all registry settings)" -ForegroundColor Gray
    # Repair == clean reinstall of all artifacts.
    Install-Keyboard | Out-Null
}

# --------------------------------------------------------------------------- #
#  Banner
# --------------------------------------------------------------------------- #
function Show-Banner {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        MKBoard  -  Sindhi Keyboard for Windows 11 / 10"          -ForegroundColor White
    Write-Host "        (c) 2026 MurShidM - Ali Khan Jalbani"                     -ForegroundColor DarkGray
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ("  CPU architecture : {0}" -f (Get-ArchFolder))                  -ForegroundColor Gray
    Write-Host ("  Status           : {0}" -f $(if (Test-Installed) {'INSTALLED'} else {'NOT INSTALLED'})) -ForegroundColor Gray
    Write-Host ""
}

# --------------------------------------------------------------------------- #
#  Main
# --------------------------------------------------------------------------- #
Show-Banner

# Explicit action requested on the command line (overrides the menu).
switch ($Action) {
    'Install'   { Install-Keyboard | Out-Null }
    'Repair'    { Repair-Keyboard }
    'Uninstall' { Uninstall-Keyboard }
    'Auto' {
        if (-not (Test-Installed)) {
            # First run -> install automatically, no menu.
            Install-Keyboard | Out-Null
        }
        elseif ($Silent) {
            # Already installed and unattended -> repair silently.
            Repair-Keyboard
        }
        else {
            # Already installed -> show the menu.
            do {
                Write-Host "  The Sindhi keyboard is already installed. Choose an option:" -ForegroundColor White
                Write-Host ""
                Write-Host "    [1] Repair    - re-install the driver and all settings" -ForegroundColor Gray
                Write-Host "    [2] Uninstall - remove the keyboard completely"          -ForegroundColor Gray
                Write-Host "    [3] Cancel    - exit without changes"                     -ForegroundColor Gray
                Write-Host ""
                $choice = Read-Host "  Enter choice (1/2/3)"
                switch ($choice.Trim()) {
                    '1' { Repair-Keyboard;   break }
                    '2' { Uninstall-Keyboard; break }
                    '3' { Write-Host "`n  Cancelled. No changes made." -ForegroundColor Yellow; break }
                    default { Write-Host "  Invalid choice, try again.`n" -ForegroundColor Red; $choice = $null }
                }
            } while (-not $choice)
        }
    }
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  Press any key to close..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
