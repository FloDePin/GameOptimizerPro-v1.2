<#
.SYNOPSIS
    GameOptimizerPro v1.1 - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell optimizer with checkboxes and info tooltips.
    Tabs: Windows | Gaming | Network | RAM & Storage |
          Windows 11 | Audio | GPU Tweaks | Power Plan
    Features: Startup Manager, Revert All, DE/EN Language Toggle
.AUTHOR
    FloDePin
.VERSION
    1.1.0
#>

$ErrorActionPreference = "Continue"

# --- STARTUP LOG (mehrere Orte) ---
$logPaths = @(
    "$env:TEMP\GameOptimizerPro_Startup.txt"
)
$startupLog = $logPaths[0]
$logMsg = "[$(Get-Date -f 'HH:mm:ss')] Script gestartet - PS $($PSVersionTable.PSVersion) - User: $env:USERNAME - IsAdmin: $((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))"
foreach ($p in $logPaths) {
    try { $logMsg | Out-File $p -Force -ErrorAction SilentlyContinue } catch { }
}
Write-Host $logMsg -ForegroundColor Cyan

try {

Add-Type -AssemblyName PresentationFramework  -ErrorAction SilentlyContinue
Add-Type -AssemblyName PresentationCore       -ErrorAction SilentlyContinue
Add-Type -AssemblyName WindowsBase            -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms   -ErrorAction SilentlyContinue
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Assemblies geladen" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Assemblies geladen" -ForegroundColor DarkGray

# -----------------------------------------
# CONSOLE WINDOW CONTROL (Win32 API)
# Note: On Windows 11 with Windows Terminal as default host, GetConsoleWindow()
# returns a hidden ConPTY window, so ShowWindow cannot control the visible
# terminal. The reliable cleanup is process-based: the installer exits its own
# session after launching, and this script ends its own process on GUI close.
# The early hide below still helps on classic conhost hosts.
# -----------------------------------------
if (-not ([System.Management.Automation.PSTypeName]'Native.Win32Console').Type) {
    Add-Type -Name Win32Console -Namespace Native -MemberDefinition @"
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@ -ErrorAction SilentlyContinue
}
$Script:ConsoleHwnd = [IntPtr]::Zero
try {
    $Script:ConsoleHwnd = [Native.Win32Console]::GetConsoleWindow()
    if ($Script:ConsoleHwnd -ne [IntPtr]::Zero) {
        [Native.Win32Console]::ShowWindow($Script:ConsoleHwnd, 0) | Out-Null  # SW_HIDE
    }
} catch { }

# -----------------------------------------
# ADMIN CHECK
# -----------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.MessageBox]::Show("Please run this script as Administrator!", "GameOptimizerPro - Admin Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Admin-Check OK" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Admin-Check OK" -ForegroundColor DarkGray

# -----------------------------------------
# HARDWARE DETECTION
# -----------------------------------------
try {
    $GPU = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1).Name
} catch { $GPU = $null }
if ([string]::IsNullOrWhiteSpace($GPU)) { $GPU = "Unknown GPU" }

try {
    $CPU = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
} catch { $CPU = $null }
if ([string]::IsNullOrWhiteSpace($CPU)) { $CPU = "Unknown CPU" }

try {
    $RAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
} catch { $RAM = 0 }

$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"
$IsIntelGPU = $GPU -match "Intel"

try {
    $NVMeDisks = @(Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" | Where-Object { $_.Model -match "NVMe|NVME" })
} catch { $NVMeDisks = @() }
$HasNVMe  = $NVMeDisks.Count -gt 0
$NVMeInfo = if ($HasNVMe) { "NVMe: $($NVMeDisks.Count)x" } else { "NVMe: none" }

try {
    $OSInfo  = Get-WmiObject Win32_OperatingSystem
    $OSBuild = [int]$OSInfo.BuildNumber
    $OSName  = $OSInfo.Caption
} catch { $OSBuild = 0; $OSName = "Unknown OS" }
$IsWin11 = $OSBuild -ge 22000
$IsWin10 = $OSBuild -ge 10240 -and -not $IsWin11
$OSShort = if ($IsWin11) { "Win11 (Build $OSBuild)" } elseif ($IsWin10) { "Win10 (Build $OSBuild)" } else { $OSName }

$HWInfo  = "GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB   |   $NVMeInfo   |   $OSShort"
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Hardware erkannt: $HWInfo" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Hardware erkannt: $HWInfo" -ForegroundColor DarkGray

# -----------------------------------------
# LOGGING
# -----------------------------------------
$LogFile = "$env:TEMP\GameOptimizerPro_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}

# -----------------------------------------
# REGISTRY BACKUP
# System Restore Points are frequently skipped by Windows (24h creation-
# frequency limit), so they can't be relied on alone. This exports every
# registry key any tweak touches to .reg files before Apply/Revert, giving
# a always-available, tweak-specific fallback independent of VSS.
# -----------------------------------------
$Script:RegistryBackupRoot = "$env:TEMP\GameOptimizerPro_Backups"

$Script:RegistryBackupKeys = @(
    "HKCU\AppEvents\Schemes",
    "HKCU\Control Panel",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize",
    "HKCU\SOFTWARE\NVIDIA Corporation\Global\NVTweak",
    "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer",
    "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}",
    "HKCU\Software\Microsoft\GameBar",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot",
    "HKCU\System\GameConfigStore",
    "HKLM\SOFTWARE\ATI Technologies\CBT",
    "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction",
    "HKLM\SOFTWARE\Microsoft\DirectX",
    "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM\SOFTWARE\Policies\Microsoft\Dsh",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows",
    "HKLM\SYSTEM\CurrentControlSet\Control",
    "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
    "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak",
    "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device",
    "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio",
    "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio2"
)

function Backup-Registry {
    param([string]$Label = "Backup")
    $stamp     = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupDir = Join-Path $Script:RegistryBackupRoot "${stamp}_$Label"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $saved = 0
    $skipped = 0
    foreach ($key in $Script:RegistryBackupKeys) {
        $fileName = ($key -replace '[\\:\*\?"<>\|]', '_') + ".reg"
        $dest = Join-Path $backupDir $fileName
        try {
            $null = & reg.exe export "$key" "$dest" /y 2>&1
            if ($LASTEXITCODE -eq 0) { $saved++ } else { $skipped++ }
        } catch { $skipped++ }
    }
    Write-Log "Registry backup ($Label): $saved keys saved, $skipped skipped (not present on this system) -> $backupDir"
    return $backupDir
}

# -----------------------------------------
# TWEAK DEFINITIONS
# -----------------------------------------

$AllTweaks = @(

    # == WINDOWS / BLOATWARE ==============================================
    [PSCustomObject]@{
        Name     = "Remove Cortana"
        Desc     = "Deinstalliert Cortana vollstaendig. Cortana ist Microsofts Sprachassistent der Daten an Microsoft sendet. Fuer die meisten Nutzer nicht benoetigt."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Cortana removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Xbox Apps"
        Desc     = "Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI. Diese Apps laufen im Hintergrund und verbrauchen Ressourcen - auch wenn du keine Xbox hast."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $xboxApps = @("*XboxApp*","*XboxGameOverlay*","*XboxGamingOverlay*","*XboxIdentityProvider*","*XboxSpeechToTextOverlay*","*XboxTCUI*")
            foreach ($app in $xboxApps) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Xbox Apps removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Microsoft Teams (Personal)"
        Desc     = "Entfernt Microsoft Teams (die Consumer-Version). Nicht zu verwechseln mit Teams for Work. Blockiert automatische Neuinstallation."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Get-AppxPackage -AllUsers "*MicrosoftTeams*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Teams Personal removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Copilot"
        Desc     = "Deaktiviert und entfernt Windows Copilot (KI-Assistent). Verhindert dass Copilot im Hintergrund laeuft und Daten sendet."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
            Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Copilot disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove OneDrive"
        Desc     = "Deinstalliert OneDrive komplett inkl. Autostart und Explorer-Integration. Deine lokalen Dateien bleiben unangetastet."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
            Start-Sleep 1
            $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
            if (!(Test-Path $onedrive)) { $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
            if (Test-Path $onedrive) { & $onedrive /uninstall }
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
            Write-Log "OneDrive removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Windows Recall"
        Desc     = "Deaktiviert Windows Recall - das KI-Feature das Screenshots deiner Aktivitaeten macht und lokal speichert. Datenschutzkritisch."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Recall disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Other Bloatware"
        Desc     = "Entfernt vorinstallierte Apps wie: Candy Crush, TikTok, Disney+, Facebook, Instagram, Spotify, News, Weather, Solitaire, Clipchamp, ToDo, Paint3D und weitere Microsoft-Bloatware."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $bloat = @(
                "*king.com*","*Facebook*","*Spotify*","*Disney*","*TikTok*","*Instagram*",
                "*Netflix*","*Twitter*","*BubbleWitch*","*MarchofEmpires*","*CandyCrush*",
                "*Microsoft.News*","*Microsoft.BingWeather*","*Microsoft.BingNews*",
                "*Microsoft.MicrosoftSolitaireCollection*","*Microsoft.ZuneMusic*",
                "*Microsoft.ZuneVideo*","*Microsoft.WindowsFeedbackHub*","*Microsoft.Todos*",
                "*Microsoft.Paint3D*","*Microsoft.MixedReality*","*Clipchamp*",
                "*Microsoft.GetHelp*","*Microsoft.Getstarted*","*Microsoft.PowerAutomateDesktop*"
            )
            foreach ($app in $bloat) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Bloatware removed"
        }
    },

    # == WINDOWS / PRIVACY ================================================
    [PSCustomObject]@{
        Name     = "Disable Telemetry & Data Collection"
        Desc     = "Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice). Windows sendet dann keine Nutzungsdaten mehr an Microsoft. Empfohlen fuer alle Nutzer."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
            Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
            Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Telemetry disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Activity History"
        Desc     = "Deaktiviert die Windows Aktivitaetsverlauf-Funktion (Timeline). Windows speichert dann nicht mehr welche Apps und Dateien du geoeffnet hast."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Activity History disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Advertising ID"
        Desc     = "Deaktiviert die Werbe-ID die Windows jedem Nutzer zuweist. Apps koennen dich dann nicht mehr geraeteuebergreifend tracken um personalisierte Werbung zu schalten."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Advertising ID disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Location Tracking"
        Desc     = "Deaktiviert den Windows Standortdienst systemweit. Apps koennen deinen Standort nicht mehr abfragen - gut fuer Datenschutz und leicht besser fuer Performance."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
            Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Location tracking disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Block Telemetry Hosts (hosts file)"
        Desc     = "Fuegt Microsoft Telemetrie-Server in die Windows hosts-Datei ein und blockt sie. Damit koennen diese Server nicht mehr erreicht werden - auch wenn Telemetry-Services laufen sollten."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            $hosts = @(
                "0.0.0.0 telemetry.microsoft.com",
                "0.0.0.0 vortex.data.microsoft.com",
                "0.0.0.0 vortex-win.data.microsoft.com",
                "0.0.0.0 telecommand.telemetry.microsoft.com",
                "0.0.0.0 oca.telemetry.microsoft.com",
                "0.0.0.0 sqm.telemetry.microsoft.com",
                "0.0.0.0 watson.telemetry.microsoft.com",
                "0.0.0.0 redir.metaservices.microsoft.com",
                "0.0.0.0 choice.microsoft.com",
                "0.0.0.0 df.telemetry.microsoft.com",
                "0.0.0.0 reports.wes.df.telemetry.microsoft.com",
                "0.0.0.0 wes.df.telemetry.microsoft.com"
            )
            $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
            $existing  = Get-Content $hostsFile
            foreach ($entry in $hosts) {
                if ($existing -notcontains $entry) { Add-Content $hostsFile $entry }
            }
            Write-Log "Telemetry hosts blocked"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Telemetry Tasks"
        Desc     = "Deaktiviert alle geplanten Windows-Aufgaben die Telemetriedaten sammeln und senden (z.B. Microsoft Compatibility Appraiser, Customer Experience Improvement)."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            $tasks = @(
                "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                "\Microsoft\Windows\Autochk\Proxy",
                "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
            )
            foreach ($task in $tasks) { schtasks /Change /TN $task /Disable 2>$null }
            Write-Log "Telemetry tasks disabled"
        }
    },

    # == WINDOWS / PERFORMANCE ============================================
    [PSCustomObject]@{
        Name     = "Ultimate Performance Plan"
        Desc     = "Aktiviert den 'Ultimative Leistung' Energiesparplan. Windows drosselt dann keine CPU-Kerne mehr - maximale Performance zu jeder Zeit. Erhoeht Stromverbrauch."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $planMatch = powercfg -list | Select-String "Ultimative Leistung|Ultimate Performance" | Select-Object -First 1
            if ($planMatch) {
                $guid = $planMatch.ToString().Split()[3]
                if ($guid) {
                    powercfg -setactive $guid
                    Write-Log "Ultimate Performance Plan activated (GUID: $guid)"
                } else {
                    Write-Log "Ultimate Performance Plan: could not parse GUID from: $($planMatch.ToString())"
                }
            } else {
                Write-Log "Ultimate Performance Plan: plan not found after duplication attempt"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable HPET (High Precision Event Timer)"
        Desc     = "Deaktiviert den High Precision Event Timer. Kann die System-Latenz reduzieren und Gaming-Performance verbessern. Auf manchen Systemen sorgt dies fuer niedrigere Frame-Zeiten."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            bcdedit /deletevalue useplatformclock 2>$null | Out-Null
            bcdedit /set useplatformtick yes | Out-Null
            bcdedit /set disabledynamictick yes | Out-Null
            Write-Log "HPET disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Set 0.5ms Timer Resolution"
        Desc     = "Setzt die Windows Timer-Aufloesung auf 0.5ms (statt Standard 15.6ms). Verbessert die Praezision von Frame-Timing und reduziert Input-Lag in Spielen spuerbar."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Timer resolution set to 0.5ms"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Prefetch & Superfetch"
        Desc     = "Deaktiviert Prefetch und SysMain (Superfetch). Sinnvoll bei SSDs - auf HDDs nicht empfohlen. Reduziert Hintergrund-Schreibzugriffe und leichten RAM-Verbrauch."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service SysMain -Force -ErrorAction SilentlyContinue
            Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Prefetch / Superfetch disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize Visual Effects (Performance Mode)"
        Desc     = "Schaltet alle Windows-Animationen und visuelle Effekte aus. Windows reagiert dadurch spuerbar schneller - besonders auf schwaecheren Systemen oder beim Gaming."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-ItemProperty $path -Name "TaskbarAnimations" -Value 0
            reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Visual effects set to performance mode"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Search Indexing"
        Desc     = "Deaktiviert den Windows Search Indexer (WSearch). Reduziert staendige Festplattenzugriffe im Hintergrund. Suche in Explorer funktioniert weiterhin, aber langsamer ohne Index."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Search Indexing disabled"
        }
    },

    # == WINDOWS / MOUSE & UI =============================================

    [PSCustomObject]@{
        Name     = "Disable Power Throttling"
        Desc     = "Verhindert dass Windows Prozesse zur Energieeinsparung drosselt (EcoQoS). Nuetzlich bei Spielen mit mehreren Prozessen -- Hintergrundprozesse des Spiels werden nicht mehr gedrosselt."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Power Throttling disabled (EcoQoS off)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Bing in Windows Search"
        Desc     = "Deaktiviert die Bing-Integration in der Windows-Suche. Das Startmenue sucht nur noch lokal -- schneller, kein Datenaustausch mit Microsoft bei jeder Suche."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Bing in Windows Search disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Process Count Reduction (Svchost)"
        Desc     = "Setzt den Svchost-Split-Schwellwert auf die RAM-Groesse. Windows teilt Dienste in weniger separate Prozesse auf -- reduziert Hintergrundprozesse spuerbar. Reboot empfohlen."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            $ramKB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1024)
            reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d $ramKB /f | Out-Null
            Write-Log ("Svchost split threshold set to " + [math]::Round($ramKB/1024) + " MB (RAM size)")
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Mouse Acceleration"
        Desc     = "Deaktiviert die Mausbeschleunigung (Enhance Pointer Precision). Wichtig fuer FPS-Spiele: Deine Mausbewegung wird 1:1 uebertragen ohne dynamische Verstaerkung."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Mouse acceleration disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Sticky Keys"
        Desc     = "Deaktiviert den Sticky Keys Dialog (der beim 5x Shift-Druecken aufpoppt). Verhindert ungewollte Unterbrechungen mitten im Spiel."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
            Write-Log "Sticky Keys disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Dark Mode"
        Desc     = "Aktiviert den dunklen Modus fuer Windows und Apps systemweit. Schont die Augen bei langen Sessions - besonders nachts beim Gaming."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Dark Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Transparency Effects"
        Desc     = "Deaktiviert die Transparenz-Effekte in Taskleiste und Startmenue. Spart GPU-Ressourcen und reduziert leicht den RAM-Verbrauch."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Transparency disabled"
        }
    },

    # == GAMING / IN-GAME BOOSTS ==========================================
    [PSCustomObject]@{
        Name     = "Enable Game Mode"
        Desc     = "Aktiviert den Windows Game Mode. Windows priorisiert dann CPU/GPU-Ressourcen fuer das aktive Spiel und unterdrueckt Windows Update Neustarts waehrend du spielst."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Game Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Xbox Game Bar"
        Desc     = "Deaktiviert die Xbox Game Bar (Win+G Overlay). Verhindert dass die Game Bar im Hintergrund laeuft und Ressourcen verbraucht. Game Mode bleibt davon unberuehrt."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Xbox Game Bar disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Priority for Games (Win32Priority)"
        Desc     = "Setzt Win32PrioritySeparation auf 26 (Hex). Windows gibt dann aktiven Spielen deutlich mehr CPU-Zeit und reduziert Hintergrundprozesse. Spuerbar bei CPU-limitierten Spielen."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
            Write-Log "CPU Priority set for gaming"
        }
    },
    [PSCustomObject]@{
        Name     = "MMCSS Gaming Profile (High Priority)"
        Desc     = "Setzt die Multimedia Class Scheduler Service (MMCSS) Profile fuer Spiele auf High Priority. Windows priorisiert dann Audio und Timer-Interrupts fuer besseres Gaming-Erlebnis."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
            Write-Log "MMCSS Gaming profile set"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Fullscreen Optimizations"
        Desc     = "Deaktiviert die Windows Fullscreen Optimizations global. Manche Spiele laufen im 'Borderless Windowed' statt echtem Fullscreen - dieser Tweak erzwingt echtes Fullscreen fuer niedrigeren Input-Lag."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Update during Gaming"
        Desc     = "Deaktiviert automatische Windows Update Downloads und Installationen dauerhaft via Registry. Windows fragt weiterhin nach Updates, installiert sie aber nicht mehr automatisch im Hintergrund. Verhindert unerwuenschte Reboots und Performance-Einbrueche waehrend des Gamings. Manuelles Update ueber Windows Update bleibt jederzeit moeglich."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetActiveHours /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursStart /t REG_DWORD /d 8 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursEnd /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Windows Update during Gaming disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Background App Throttling"
        Desc     = "Deaktiviert das Windows-interne CPU-Throttling fuer Hintergrundprozesse. Verhindert dass Windows heimlich die CPU-Zeit fuer Spiele reduziert wenn Hintergrundprozesse aktiv sind. Wichtig bei CPU-intensiven Spielen."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableLowQosTimerResolution /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Background App Throttling disabled"
        }
    },

    # == GAMING / GPU & DRIVER ============================================
    [PSCustomObject]@{
        Name     = "NVIDIA Low Latency Mode (Reflex)"
        Desc     = "Aktiviert NVIDIA Ultra Low Latency Mode via Registry. Reduziert den Render-Queue auf 1 Frame - weniger Input-Lag. Nur wirksam auf NVIDIA GPUs. Wird automatisch uebersprungen wenn keine NVIDIA GPU erkannt."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            if ($IsNVIDIA) {
                $nvPath = "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak"
                reg add $nvPath /v NVLatency /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "NVIDIA Low Latency Mode enabled"
            } else {
                Write-Log "NVIDIA Low Latency skipped (no NVIDIA GPU detected: $GPU)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Enable MSI Mode (Message Signaled Interrupts)"
        Desc     = "Aktiviert MSI-Modus fuer GPU und NVMe. Reduziert Interrupt-Latenz erheblich. Standard-Windows nutzt Line-Based Interrupts - MSI ist moderner und schneller. Reboot empfohlen."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            $gpuDev = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
            if ($gpuDev) {
                $pnpId   = $gpuDev.PNPDeviceID
                $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                reg add $regPath /v MSISupported /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "MSI Mode enabled for: $($gpuDev.Name)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Hardware-Accelerated GPU Scheduling (HAGS)"
        Desc     = "Aktiviert HAGS - Windows uebergibt GPU-Scheduling direkt an die Hardware statt Software. Reduziert CPU-Overhead und leicht den Input-Lag. Erfordert NVIDIA RTX 2000+ oder AMD RX 5000+ und Windows 10 2004+."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear Shader Cache"
        Desc     = "Leert den NVIDIA bzw. AMD Shader-Cache auf der Festplatte. Erzwingt beim naechsten Spielstart eine frische Kompilierung der Shader. Sinnvoll nach Treiberupdates oder bei Grafikfehlern."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            if ($IsNVIDIA) {
                $nvcache = "$env:LOCALAPPDATA\NVIDIA\DXCache"
                if (Test-Path $nvcache) { Remove-Item "$nvcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
                $nvcache2 = "$env:LOCALAPPDATA\NVIDIA\GLCache"
                if (Test-Path $nvcache2) { Remove-Item "$nvcache2\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            if ($IsAMD) {
                $amdcache = "$env:TEMP\AMD"
                if (Test-Path $amdcache) { Remove-Item "$amdcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $dxcache = "$env:LOCALAPPDATA\D3DSCache"
            if (Test-Path $dxcache) { Remove-Item "$dxcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Log "Shader Cache cleared"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable DirectX 12 Optimization"
        Desc     = "Optimiert DirectX 12 Einstellungen fuer maximale Gaming-Performance. Aktiviert DX12 Multi-Threading und reduziert Draw-Call-Overhead. Besonders effektiv bei modernen AAA-Spielen die DX12 nutzen."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_CPU_PAGE_PROPERTY /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 10 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDdiDelay /t REG_DWORD /d 10 /f | Out-Null
            Write-Log "DirectX 12 Optimization enabled"
        }
    },

    # == NETWORK / LATENCY ================================================
    [PSCustomObject]@{
        Name     = "Disable Nagle's Algorithm (TCPNoDelay)"
        Desc     = "Deaktiviert Nagles Algorithmus auf allen Netzwerkadaptern. Nagle buendelt kleine Datenpakete um Effizienz zu steigern - auf Kosten von Latenz. Deaktivieren senkt Ping in Online-Spielen spuerbar."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            $adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
            foreach ($adapter in $adapters) {
                $path = $adapter.PSPath
                Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
            Write-Log "Nagle's Algorithm disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Large Send Offload (LSO)"
        Desc     = "Deaktiviert Large Send Offload auf allen aktiven Netzwerkadaptern. LSO kann auf manchen Systemen zu Ping-Spikes fuehren. Deaktivieren hilft bei instabilem Ping in Online-Spielen."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Disable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
            }
            Write-Log "LSO disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Network Throttling Index"
        Desc     = "Deaktiviert den Windows Network Throttling Index der Netzwerkpakete bei hoher CPU-Last drosselt. Besonders wirksam bei latenzsensitvem Gaming wenn CPU ausgelastet ist. Gibt dem Netzwerk-Stack hoechste Prioritaet."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Network Throttling Index disabled"
        }
    },

    # == NETWORK / DNS ====================================================
    [PSCustomObject]@{
        Name     = "Set DNS to Cloudflare (1.1.1.1)"
        Desc     = "Setzt den DNS-Server auf Cloudflare 1.1.1.1 (Primary) und 1.0.0.1 (Secondary). Cloudflare DNS ist einer der schnellsten und datenschutzfreundlichsten DNS-Anbieter weltweit."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
            }
            Write-Log "DNS set to Cloudflare 1.1.1.1"
        }
    },
    [PSCustomObject]@{
        Name     = "Set DNS to Google (8.8.8.8)"
        Desc     = "Setzt den DNS-Server auf Google 8.8.8.8 (Primary) und 8.8.4.4 (Secondary). Googles DNS ist global verteilt, sehr schnell und zuverlaessig. Alternative zu Cloudflare."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction SilentlyContinue
            }
            Write-Log "DNS set to Google 8.8.8.8"
        }
    },
    [PSCustomObject]@{
        Name     = "Flush DNS Cache"
        Desc     = "Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Aenderungen oder bei Verbindungsproblemen. Schnell und ohne Nebenwirkungen."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            ipconfig /flushdns | Out-Null
            Write-Log "DNS Cache flushed"
        }
    },

    # == NETWORK / TCP ====================================================
    [PSCustomObject]@{
        Name     = "Disable TCP Auto-Tuning"
        Desc     = "Deaktiviert die automatische TCP-Empfangsfenstergroeesse. Kann auf manchen Systemen Latenz-Spikes reduzieren. Bei Highspeed-Internet (1 Gbit+) kann dies den Durchsatz leicht verringern."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global autotuninglevel=disabled | Out-Null
            Write-Log "TCP Auto-Tuning disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize TCP Settings (ECN/SACK/Timestamps)"
        Desc     = "Optimiert fortgeschrittene TCP-Einstellungen: Deaktiviert ECN (Explicit Congestion Notification), aktiviert SACK (Selective Acknowledgment) und deaktiviert TCP Timestamps. Reduziert Overhead und verbessert Stabilitaet bei Online-Spielen."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global ecncapability=disabled 2>$null | Out-Null
            netsh int tcp set global timestamps=disabled 2>$null | Out-Null
            netsh int tcp set global rss=enabled 2>$null | Out-Null
            netsh int tcp set global chimney=disabled 2>$null | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SackOpts /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxDupAcks /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "TCP Settings optimized (ECN/SACK/Timestamps)"
        }
    },

    # == NETWORK / QOS ====================================================
    [PSCustomObject]@{
        Name     = "Disable QoS Packet Scheduler Limit"
        Desc     = "Entfernt das Standard-Limit von 20% Bandbreite das Windows fuer QoS reserviert. Gibt dir die volle verfuegbare Bandbreite - relevant besonders in Netzwerken mit hohem Traffic."
        Category = "Network"
        Group    = "QoS"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "QoS bandwidth limit removed"
        }
    },

    # == NETWORK / ADAPTER =================================================
    [PSCustomObject]@{
        Name     = "Disable Network Adapter Power Saving"
        Desc     = "Deaktiviert 'Computer kann Geraet ausschalten um Strom zu sparen' fuer alle Netzwerkadapter. Verhindert Verbindungsabbrueche und Latenz-Spitzen durch Energiesparfunktionen des Adapters."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            Get-ChildItem $netClass -ErrorAction SilentlyContinue | ForEach-Object {
                if (Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Network adapter power saving disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Delivery Optimization (P2P Windows Update)"
        Desc     = "Deaktiviert Windows Delivery Optimization. Windows laedt Updates nur noch direkt von Microsoft statt Bandbreite mit anderen PCs im Netzwerk/Internet zu teilen (P2P). Verhindert unerwartete Bandbreitennutzung waehrend des Spielens."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Delivery Optimization (P2P updates) disabled"
        }
    },

    # == RAM & STORAGE / PAGE FILE ========================================
    [PSCustomObject]@{
        Name     = "Optimize PageFile (System Managed)"
        Desc     = "Setzt die PageFile-Verwaltung auf automatisch durch Windows. Windows passt die Auslagerungsdatei dynamisch an den RAM-Bedarf an - verhindert sowohl zu kleine als auch zu grosse PageFiles."
        Category = "RAM & Storage"
        Group    = "Page File"
        Action   = {
            $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
            $cs.AutomaticManagedPagefile = $true
            $cs.Put() | Out-Null
            Write-Log "PageFile set to system managed"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear PageFile on Shutdown"
        Desc     = "Loescht die Auslagerungsdatei bei jedem Herunterfahren. Verhindert dass sensible Daten im Speicher nach dem Neustart noch auf der Festplatte liegen. Gut fuer Datenschutz. Macht den Shutdown minimal langsamer."
        Category = "RAM & Storage"
        Group    = "Page File"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "PageFile cleared on shutdown enabled"
        }
    },

    # == RAM & STORAGE / MEMORY ===========================================
    [PSCustomObject]@{
        Name     = "Disable Memory Compression"
        Desc     = "Deaktiviert die RAM-Komprimierung in Windows. Memory Compression verbraucht CPU-Ressourcen um RAM-Inhalte zu komprimieren. Bei ausreichend RAM (16GB+) bringt Deaktivieren weniger CPU-Last waehrend des Spielens."
        Category = "RAM & Storage"
        Group    = "Memory"
        Action   = {
            try {
                Disable-MMAgent -MemoryCompression -ErrorAction Stop
                Write-Log "Memory Compression disabled"
            } catch {
                Write-Log "Memory Compression could not be disabled (Windows 24h limit, already disabled, or unsupported build): $_"
            }
        }
    },

    # == RAM & STORAGE / SSD ==============================================
    [PSCustomObject]@{
        Name     = "Enable SSD TRIM"
        Desc     = "Aktiviert TRIM fuer alle angeschlossenen SSDs. TRIM informiert die SSD ueber nicht mehr benoetigte Datenbloecke - haelt die SSD-Performance langfristig auf hohem Niveau und verlaengert die Lebensdauer."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            fsutil behavior set DisableDeleteNotify 0 | Out-Null
            Write-Log "SSD TRIM enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Defragmentation"
        Desc     = "Deaktiviert die automatische geplante Defragmentierung. Auf SSDs absolut nicht empfohlen - Defrag schadet SSDs und ist voellig unnoetig. Windows erkennt SSDs normalerweise korrekt, aber dieser Tweak stellt es sicher ab."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" /v Enable /t REG_SZ /d N /f | Out-Null
            Write-Log "Scheduled Defragmentation disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize NVMe Queue Depth"
        Desc     = "Optimiert die Queue Depth fuer NVMe-Laufwerke. Erhoehte Queue Depth erlaubt mehr parallele I/O-Operationen - verbessert Lese-/Schreibgeschwindigkeit bei NVMe SSDs merklich. Wird automatisch uebersprungen wenn kein NVMe erkannt."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            if ($HasNVMe) {
                foreach ($disk in $NVMeDisks) {
                    $pnpId = $disk.PNPDeviceID
                    # Path 1: per-device StorPort queue depth (most controllers)
                    $regPath1 = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\StorPort"
                    reg add $regPath1 /v QueueDepth /t REG_DWORD /d 32 /f | Out-Null
                    # Path 2: interrupt affinity priority (Samsung/WD/Seagate NVMe)
                    $regPath2 = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy"
                    reg add $regPath2 /v DevicePriority /t REG_DWORD /d 2 /f | Out-Null
                }
                # Global stornvme driver: disable idle power management for lower latency
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
                Write-Log ("NVMe Queue Depth optimized (" + $NVMeDisks.Count + " drive(s))")
            } else {
                Write-Log "NVMe Queue Depth skipped (no NVMe drive detected)"
            }
        }
    },

    # == RAM & STORAGE / MAINTENANCE ======================================
    [PSCustomObject]@{
        Name     = "Disable Write-Cache Buffer Flushing"
        Desc     = "Deaktiviert das erzwungene Leeren des Schreibcache-Puffers bei SSDs. Verbessert die Schreibgeschwindigkeit spuerbar. Nur empfohlen bei Desktop-PCs mit stabiler Stromversorgung (kein Laptop ohne USV)."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            $disks = Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" |
                Where-Object {
                    $_.MediaType -eq 3 -or $_.MediaType -eq 4 -or
                    $_.MediaType -eq 'Fixed hard disk media' -or $null -eq $_.MediaType
                }
            if (-not $disks) {
                Write-Log "Write-Cache: no disks found -- skipped"
            } else {
                $count = 0
                foreach ($disk in $disks) {
                    $pnpId   = $disk.PNPDeviceID
                    $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Disk"
                    reg add $regPath /v UserWriteCacheSetting /t REG_DWORD /d 1 /f | Out-Null
                    $count++
                }
                Write-Log ("Write-Cache Buffer Flushing disabled (" + $count + " disks updated)")
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Hibernation"
        Desc     = "Deaktiviert den Ruhezustand (Hibernate) und loescht hiberfil.sys. Gibt mehrere GB Festplattenplatz (entspricht dem RAM) frei. Schnellstart bleibt davon unabhaengig. Empfohlen fuer Desktop-PCs."
        Category = "RAM & Storage"
        Group    = "Maintenance"
        Action   = {
            powercfg /hibernate off 2>$null | Out-Null
            Write-Log "Hibernation disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clean Temp Files"
        Desc     = "Loescht alle Dateien in %TEMP%, Windows\Temp und Prefetch-Ordner. Gibt Festplattenplatz frei und kann den Boot-Vorgang leicht beschleunigen. Laufende Anwendungen werden nicht beeinflusst."
        Category = "RAM & Storage"
        Group    = "Maintenance"
        Action   = {
            $tempPaths = @(
                $env:TEMP,
                "$env:SystemRoot\Temp",
                "$env:SystemRoot\Prefetch"
            )
            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Temp files cleaned"
        }
    },

    # == WINDOWS 11 SPECIFIC ==============================================
    [PSCustomObject]@{
        Name     = "Restore Classic Right-Click Menu"
        Desc     = "WIN11: Stellt das klassische Windows 10 Rechtsklick-Menue wieder her. Das neue Win11-Menue versteckt viele Optionen hinter 'Weitere Optionen anzeigen'. Wirkt nach Neustart des Explorers."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /t REG_SZ /d "" /f | Out-Null
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Write-Log "Win11: Classic right-click menu restored"
        }
    },
    [PSCustomObject]@{
        Name     = "Left-Align Taskbar"
        Desc     = "WIN11: Verschiebt die Taskleisten-Icons nach links (wie Windows 10). Windows 11 zentriert Icons standardmaessig. Wirkt nach Explorer-Neustart."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Taskbar left-aligned"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Widgets"
        Desc     = "WIN11: Deaktiviert das Widgets-Panel (Wetter, News, Aktien). Widgets laufen als MSN-Browser im Hintergrund und verbrauchen RAM. Icon wird aus der Taskleiste entfernt."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Widgets disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Chat Icon from Taskbar"
        Desc     = "WIN11: Entfernt das Teams Chat-Icon aus der Taskleiste. Das Icon kann ungewollt Teams installieren und laeuft im Hintergrund."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Chat icon removed from taskbar"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Recommended in Start Menu"
        Desc     = "WIN11: Entfernt den 'Empfohlen'-Bereich im Startmenue der zuletzt geoeffnete Dateien und Apps anzeigt. Mehr Platz fuer angeheftete Apps und saubereres Layout."
        Category = "Windows 11"
        Group    = "Start Menu"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Win11: Recommended section in Start Menu disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable End Task in Taskbar"
        Desc     = "WIN11: Aktiviert 'Task beenden' direkt im Rechtsklick-Menue der Taskleiste. Beendet haengende Prozesse ohne Task-Manager oeffnen zu muessen."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Win11: End Task in taskbar enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Snap Layout Hover Menu"
        Desc     = "WIN11: Deaktiviert das Snap Layout-Popup das erscheint wenn man mit der Maus ueber den Maximieren-Button faehrt. Verhindert ungewolltes Snappen beim Gaming."
        Category = "Windows 11"
        Group    = "Window Management"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Snap Layout hover menu disabled"
        }
    },

    # == AUDIO ============================================================
    [PSCustomObject]@{
        Name     = "Disable Audio Enhancements"
        Desc     = "Deaktiviert alle Windows-Audio-Effekte (Bass Boost, Raumklang, Equalizer) fuer alle Wiedergabegeraete. Reduziert Audio-Latenz und CPU-Last von audiodg.exe. Empfohlen fuer Gaming-Headsets und Low-Latency-Audio."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            $renderPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
            if (Test-Path $renderPath) {
                $count = 0
                Get-ChildItem $renderPath | ForEach-Object {
                    $fxPath = Join-Path $_.PSPath "FxProperties"
                    if (-not (Test-Path $fxPath)) { New-Item -Path $fxPath -Force | Out-Null }
                    Set-ItemProperty -Path $fxPath -Name "{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5" `
                        -Value 1 -Type DWord -ErrorAction SilentlyContinue
                    $count++
                }
                Write-Log ("Audio Enhancements disabled (" + $count + " device(s))")
            } else {
                Write-Log "Audio Enhancements: no render devices found"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize MMCSS Audio Profile"
        Desc     = "Optimiert das Multimedia Class Scheduler Profil fuer Audio. Setzt Audio auf 'Latency Sensitive' mit hoher Scheduling-Prioritaet. Reduziert Audio-Stottern und Knacken unter CPU-Last."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            $audioPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
            reg add $audioPath /v "Latency Sensitive" /t REG_SZ /d "True" /f | Out-Null
            reg add $audioPath /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add $audioPath /v "Scheduling Category" /t REG_SZ /d "High" /f | Out-Null
            reg add $audioPath /v "SFIO Priority" /t REG_SZ /d "High" /f | Out-Null
            Write-Log "MMCSS Audio profile optimized (Latency Sensitive, High Priority)"
        }
    },
    [PSCustomObject]@{
        Name     = "Set Audio Service High Priority"
        Desc     = "Erhoeht die Systemprioraet fuer Audio-Verarbeitung. Setzt SystemResponsiveness auf 0 (maximale Audio-CPU-Zeit). Verhindert Audio-Aussetzer wenn andere Prozesse die CPU belasten  --  spuerbar bei Gaming + Streaming gleichzeitig."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Audio SystemResponsiveness set to 0 (maximum audio priority)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Sound Scheme"
        Desc     = "Deaktiviert alle Windows-Systemklaenge (Start, Fehler, Benachrichtigungen usw.). Keine unerwarteten Sound-Unterbrechungen mehr waehrend Gaming oder Streaming."
        Category = "Audio"
        Group    = "System Sounds"
        Action   = {
            reg add "HKCU\AppEvents\Schemes" /ve /t REG_SZ /d ".None" /f | Out-Null
            Write-Log "Windows Sound Scheme disabled (.None)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Spatial Sound (Windows Sonic)"
        Desc     = "Deaktiviert Windows Sonic / Dolby Atmos Spatial Sound fuer alle Wiedergabegeraete. Spatial Sound erzeugt CPU-Overhead und kann bei stereo-only Headsets die Qualitaet verschlechtern."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            $renderPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
            if (Test-Path $renderPath) {
                Get-ChildItem $renderPath | ForEach-Object {
                    Set-ItemProperty -Path $_.PSPath -Name "SpatialAudioMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Spatial Sound disabled for all render devices"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Audio Device Power Save"
        Desc     = "Verhindert dass Windows Audio-Geraete (USB-Headset, Soundkarte) in den Energiesparmodus versetzt. Eliminiert das Knacken und kurze Aussetzen nach laengerer Stille wenn das Geraet wieder aufwacht."
        Category = "Audio"
        Group    = "Power"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio2" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f 2>$null | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f 2>$null | Out-Null
            $audioClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}"
            if (Test-Path $audioClass) {
                Get-ChildItem $audioClass -ErrorAction SilentlyContinue | ForEach-Object {
                    Set-ItemProperty -Path $_.PSPath -Name "PowerThrottlingOff" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Audio Device Power Save disabled (USB + class registry)"
        }
    },

    # == GPU TWEAKS (NVIDIA) ==============================================
    [PSCustomObject]@{
        Name     = "NVIDIA: Disable Threaded Optimization"
        Desc     = "NVIDIA only: Deaktiviert Threaded Optimization (nvcpl). In manchen Spielen verursacht TO Mikroruckler weil der Treiber Drawcalls auf extra Threads verteilt. Deaktivieren kann Frametimes stabiler machen."
        Category = "GPU Tweaks"
        Group    = "NVIDIA"
        Action   = {
            if ($IsNVIDIA) {
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v ThreadedOptimization /t REG_DWORD /d 0 /f | Out-Null
                Write-Log "NVIDIA: Threaded Optimization disabled"
            } else { Write-Log "GPU Tweak skipped: no NVIDIA GPU detected ($GPU)" }
        }
    },
    [PSCustomObject]@{
        Name     = "NVIDIA: Max Pre-Rendered Frames = 1"
        Desc     = "NVIDIA only: Setzt die maximale Anzahl vorberechneter Frames auf 1. Reduziert Input-Lag spuerbar. Standard ist 3  --  mit 1 Frame wartet die GPU weniger auf die CPU, Input-Reaktion wird direkter."
        Category = "GPU Tweaks"
        Group    = "NVIDIA"
        Action   = {
            if ($IsNVIDIA) {
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PrerenderedFrames /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "NVIDIA: Max Pre-Rendered Frames set to 1"
            } else { Write-Log "GPU Tweak skipped: no NVIDIA GPU detected ($GPU)" }
        }
    },
    [PSCustomObject]@{
        Name     = "NVIDIA: Shader Cache Size (Unlimited)"
        Desc     = "NVIDIA only: Setzt die NVIDIA Shader Cache Groesse auf unbegrenzt (0xffffffff). Verhindert dass Shader neu kompiliert werden muessen  --  weniger Stutter beim ersten Spielen einer Map/Szene."
        Category = "GPU Tweaks"
        Group    = "NVIDIA"
        Action   = {
            if ($IsNVIDIA) {
                reg add "HKCU\SOFTWARE\NVIDIA Corporation\Global\NVTweak" /v NvCplCacheShaderMaxSize /t REG_DWORD /d 0xffffffff /f | Out-Null
                Write-Log "NVIDIA: Shader Cache set to unlimited"
            } else { Write-Log "GPU Tweak skipped: no NVIDIA GPU detected ($GPU)" }
        }
    },
    [PSCustomObject]@{
        Name     = "NVIDIA: Power Management = Max Performance"
        Desc     = "NVIDIA only: Setzt NVIDIA Energieverwaltung auf 'Maximale Leistung bevorzugen'. Verhindert GPU-Downclocking unter Last. Erhoehter Stromverbrauch  --  empfohlen fuer Desktop-Systeme."
        Category = "GPU Tweaks"
        Group    = "NVIDIA"
        Action   = {
            if ($IsNVIDIA) {
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerEnable /t REG_DWORD /d 1 /f | Out-Null
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerLevel /t REG_DWORD /d 1 /f | Out-Null
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerLevelAC /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "NVIDIA: Power Management set to Max Performance"
            } else { Write-Log "GPU Tweak skipped: no NVIDIA GPU detected ($GPU)" }
        }
    },

    # == GPU TWEAKS (AMD) =================================================
    [PSCustomObject]@{
        Name     = "AMD: Disable ULPS (Ultra Low Power State)"
        Desc     = "AMD only: Deaktiviert Ultra Low Power State. ULPS versetzt inaktive GPUs (Multi-GPU) in extremen Stromsparmodus und kann beim Aufwachen zu Stottern fuehren. Auch bei Single-GPU sinnvoll deaktivieren."
        Category = "GPU Tweaks"
        Group    = "AMD"
        Action   = {
            if ($IsAMD) {
                $amdClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $amdClass) {
                    Get-ChildItem $amdClass -ErrorAction SilentlyContinue | ForEach-Object {
                        Set-ItemProperty -Path $_.PSPath -Name "EnableULPS" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $_.PSPath -Name "EnableULPS_NA" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    }
                }
                Write-Log "AMD: ULPS disabled"
            } else { Write-Log "GPU Tweak skipped: no AMD GPU detected ($GPU)" }
        }
    },
    [PSCustomObject]@{
        Name     = "AMD: Shader Cache (Unlimited)"
        Desc     = "AMD only: Setzt den AMD Shader Cache auf maximale Groesse. Verhindert Cache-Eviction und erzwingt weniger Shader-Rekompilierungen. Reduziert In-Game Stutter besonders in OpenGL/Vulkan-Titeln."
        Category = "GPU Tweaks"
        Group    = "AMD"
        Action   = {
            if ($IsAMD) {
                reg add "HKLM\SOFTWARE\ATI Technologies\CBT" /v ShaderCacheSizePC /t REG_DWORD /d 0xffffffff /f 2>$null | Out-Null
                $amdClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $amdClass) {
                    Get-ChildItem $amdClass -ErrorAction SilentlyContinue | ForEach-Object {
                        Set-ItemProperty -Path $_.PSPath -Name "KMD_EnableComputePreemption" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    }
                }
                Write-Log "AMD: Shader Cache size maximized"
            } else { Write-Log "GPU Tweak skipped: no AMD GPU detected ($GPU)" }
        }
    },
    [PSCustomObject]@{
        Name     = "AMD: Anti-Lag (Low Latency Mode)"
        Desc     = "AMD only: Aktiviert AMD Anti-Lag via Registry. Reduziert den Abstand zwischen CPU-Input und GPU-Ausgabe  --  aehnlich wie NVIDIA Reflex. Effektiv bei CPU-limitierten Spielen mit AMD RX 5000+."
        Category = "GPU Tweaks"
        Group    = "AMD"
        Action   = {
            if ($IsAMD) {
                $amdClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $amdClass) {
                    Get-ChildItem $amdClass -ErrorAction SilentlyContinue | ForEach-Object {
                        Set-ItemProperty -Path $_.PSPath -Name "EnableAntiLag" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                    }
                }
                Write-Log "AMD: Anti-Lag enabled"
            } else { Write-Log "GPU Tweak skipped: no AMD GPU detected ($GPU)" }
        }
    },

    # == POWER PLAN =======================================================
    [PSCustomObject]@{
        Name     = "Disable USB Selective Suspend"
        Desc     = "Deaktiviert USB Selective Suspend global. Windows schickt dann keine USB-Geraete mehr in den Schlafmodus. Verhindert Verbindungsabbrueche bei USB-Maus, Headset und Controllern unter Last."
        Category = "Power Plan"
        Group    = "USB & PCI"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "USB Selective Suspend disabled via powercfg"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable PCI-E Link State Power Management"
        Desc     = "Deaktiviert PCI-E ASPM (Active State Power Management). Verhindert dass die GPU ihre PCI-Express-Verbindung in den Stromsparmodus versetzt. Reduziert GPU-Latenzschwankungen unter Last."
        Category = "Power Plan"
        Group    = "USB & PCI"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "PCI-E Link State Power Management disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Hard Disk Sleep"
        Desc     = "Setzt die Festplatten-Schlaf-Zeit auf 0 (niemals). Verhindert das bekannte Stottern nach laenger Inaktivitaet wenn eine HDD/SSD aus dem Schlaf aufwacht. Empfohlen fuer Gaming-PCs."
        Category = "Power Plan"
        Group    = "Storage"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_DISK DISKIDLE 0 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_DISK DISKIDLE 0 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "Hard Disk Sleep disabled (timeout = 0)"
        }
    },
    [PSCustomObject]@{
        Name     = "Set Display Sleep = 15 Minutes"
        Desc     = "Setzt den Monitor-Schlaf-Timer auf 15 Minuten (AC) und 5 Minuten (Akku). Verhindert dass der Monitor mitten im Spielen abschaltet, spart aber trotzdem Energie bei laengerer Pause."
        Category = "Power Plan"
        Group    = "Display"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 900  | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 300  | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "Display Sleep set to 15 min (AC) / 5 min (DC)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Sleep (System)"
        Desc     = "Deaktiviert den System-Schlafmodus komplett. Der PC schlaeft nicht mehr nach Inaktivitaet ein. Empfohlen fuer Desktop-PCs die im Hintergrund laufen sollen (z.B. Downloads, Server)."
        Category = "Power Plan"
        Group    = "Sleep"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "System Sleep disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Minimum Processor State = 100%"
        Desc     = "Setzt den minimalen CPU-Zustand auf 100%. Die CPU laeuft dann staendig mit voller Taktrate ohne herunterzuregeln. Eliminiert die kurze Verzoegerung beim Hochregeln von Idle  --  wichtig fuer konstante FPS."
        Category = "Power Plan"
        Group    = "CPU"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "CPU Minimum Processor State set to 100%"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Maximum Processor State = 100%"
        Desc     = "Setzt den maximalen CPU-Zustand auf 100% und stellt sicher dass Windows die CPU nie kuenstlich deckelt. Relevant auf Laptops und Systemen mit aggressiver Thermal-Policy."
        Category = "Power Plan"
        Group    = "CPU"
        Action   = {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
            powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
            Write-Log "CPU Maximum Processor State set to 100%"
        }
    }
)

# -----------------------------------------
# REVERT ACTIONS  --  Windows Defaults
# Keyed by tweak Name. Run by BtnRevertAll.
# -----------------------------------------
$RevertActions = @{

    # == BLOATWARE (apps removed  --  registry parts only) ===================
    "Remove Cortana" = {
        Write-Log "Revert Cortana: app was removed  --  needs System Restore to reinstall"
    }
    "Remove Xbox Apps" = {
        Write-Log "Revert Xbox Apps: apps were removed  --  needs System Restore to reinstall"
    }
    "Remove Microsoft Teams (Personal)" = {
        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /f 2>$null
        Write-Log "Revert Teams: auto-install policy removed (app needs System Restore)"
    }
    "Remove Copilot" = {
        reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f 2>$null
        Write-Log "Revert Copilot: policy key removed (app needs System Restore)"
    }
    "Remove OneDrive" = {
        Write-Log "Revert OneDrive: app was removed  --  needs System Restore to reinstall"
    }
    "Remove Windows Recall" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f 2>$null
        Write-Log "Revert Recall: policy key removed"
    }
    "Remove Other Bloatware" = {
        Write-Log "Revert Bloatware: apps were removed  --  needs System Restore to reinstall"
    }

    # == PRIVACY ==========================================================
    "Disable Power Throttling" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /f 2>$null
        Write-Log "Revert: Power Throttling re-enabled (EcoQoS on)"
    }
    "Disable Bing in Windows Search" = {
        reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /f 2>$null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Bing in Windows Search re-enabled"
    }
    "Process Count Reduction (Svchost)" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d 380000 /f | Out-Null
        Write-Log "Revert: Svchost threshold reset to Windows default (380000 KB)"
    }

    "Disable Telemetry & Data Collection" = {
        Start-Service DiagTrack -ErrorAction SilentlyContinue
        Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service dmwappushservice -ErrorAction SilentlyContinue
        Set-Service dmwappushservice -StartupType Automatic -ErrorAction SilentlyContinue
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f 2>$null
        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /f 2>$null
        Write-Log "Revert: Telemetry services re-enabled"
    }
    "Disable Activity History" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /f 2>$null
        Write-Log "Revert: Activity History policy keys removed (default = enabled)"
    }
    "Disable Advertising ID" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /f 2>$null
        Write-Log "Revert: Advertising ID re-enabled"
    }
    "Disable Location Tracking" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f | Out-Null
        Set-Service lfsvc -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service lfsvc -ErrorAction SilentlyContinue
        Write-Log "Revert: Location tracking re-enabled"
    }
    "Block Telemetry Hosts (hosts file)" = {
        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
        $blocked = @(
            "0.0.0.0 telemetry.microsoft.com","0.0.0.0 vortex.data.microsoft.com",
            "0.0.0.0 vortex-win.data.microsoft.com","0.0.0.0 telecommand.telemetry.microsoft.com",
            "0.0.0.0 oca.telemetry.microsoft.com","0.0.0.0 sqm.telemetry.microsoft.com",
            "0.0.0.0 watson.telemetry.microsoft.com","0.0.0.0 redir.metaservices.microsoft.com",
            "0.0.0.0 choice.microsoft.com","0.0.0.0 df.telemetry.microsoft.com",
            "0.0.0.0 reports.wes.df.telemetry.microsoft.com","0.0.0.0 wes.df.telemetry.microsoft.com"
        )
        $clean = Get-Content $hostsFile | Where-Object { $blocked -notcontains $_.Trim() }
        Set-Content $hostsFile $clean -Encoding ASCII
        Write-Log "Revert: Telemetry host entries removed from hosts file"
    }
    "Disable Scheduled Telemetry Tasks" = {
        $tasks = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "\Microsoft\Windows\Autochk\Proxy",
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        )
        foreach ($task in $tasks) { schtasks /Change /TN $task /Enable 2>$null }
        Write-Log "Revert: Telemetry scheduled tasks re-enabled"
    }

    # == PERFORMANCE ======================================================
    "Ultimate Performance Plan" = {
        # "Balanced" is a built-in scheme with a fixed, well-known GUID on every
        # Windows install -- use it directly instead of matching the display
        # name, which is localized (e.g. "Ausbalanciert" on German Windows) and
        # would silently fail to find the plan on non-English systems.
        $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        if (powercfg -list | Select-String ([regex]::Escape($balancedGuid))) {
            powercfg -setactive $balancedGuid
            Write-Log "Revert: Power plan set back to Balanced"
        } else {
            # Fallback: built-in scheme was removed/recreated -- try matching by name (DE/EN)
            $match = powercfg -list | Select-String "Balanced|Ausbalanciert" | Select-Object -First 1
            if ($match) {
                $guid = $match.ToString().Split()[3]
                if ($guid) {
                    powercfg -setactive $guid
                    Write-Log "Revert: Power plan set back to Balanced (matched by name, GUID: $guid)"
                }
            } else {
                Write-Log "Revert WARNING: Balanced power plan not found -- could not revert power plan"
            }
        }
    }
    "Disable HPET (High Precision Event Timer)" = {
        bcdedit /set useplatformclock true 2>$null | Out-Null
        bcdedit /deletevalue useplatformtick 2>$null | Out-Null
        bcdedit /deletevalue disabledynamictick 2>$null | Out-Null
        Write-Log "Revert: HPET settings restored"
    }
    "Set 0.5ms Timer Resolution" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /f 2>$null
        Write-Log "Revert: Timer resolution key removed (Windows default restored)"
    }
    "Disable Prefetch & Superfetch" = {
        Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service SysMain -ErrorAction SilentlyContinue
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 3 /f | Out-Null
        Write-Log "Revert: SysMain + Prefetch re-enabled"
    }
    "Optimize Visual Effects (Performance Mode)" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f | Out-Null
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty $path -Name "TaskbarAnimations" -Value 1 -ErrorAction SilentlyContinue
        reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 1 /f | Out-Null
        Write-Log "Revert: Visual effects set back to Windows default"
    }
    "Disable Windows Search Indexing" = {
        Set-Service WSearch -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service WSearch -ErrorAction SilentlyContinue
        Write-Log "Revert: Windows Search Indexing re-enabled"
    }

    # == MOUSE & UI =======================================================
    "Disable Mouse Acceleration" = {
        reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f | Out-Null
        Write-Log "Revert: Mouse acceleration restored (Windows default)"
    }
    "Disable Sticky Keys" = {
        reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 510 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 126 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 62 /f | Out-Null
        Write-Log "Revert: Sticky Keys restored (Windows default)"
    }
    "Enable Dark Mode" = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Light Mode restored"
    }
    "Disable Transparency Effects" = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Transparency effects re-enabled"
    }

    # == GAMING  --  IN-GAME BOOSTS ==========================================
    "Enable Game Mode" = {
        reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Revert: Game Mode disabled"
    }
    "Disable Xbox Game Bar" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /f 2>$null
        Write-Log "Revert: Xbox Game Bar re-enabled"
    }
    "CPU Priority for Games (Win32Priority)" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 2 /f | Out-Null
        Write-Log "Revert: Win32PrioritySeparation restored to default (2)"
    }
    "MMCSS Gaming Profile (High Priority)" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 2 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d Normal /f | Out-Null
        Write-Log "Revert: MMCSS Gaming profile restored to default"
    }
    "Disable Fullscreen Optimizations" = {
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /f 2>$null
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /f 2>$null
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /f 2>$null
        Write-Log "Revert: Fullscreen Optimizations keys removed (Windows default)"
    }
    "Disable Windows Update during Gaming" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetActiveHours /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursStart /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursEnd /f 2>$null
        Write-Log "Revert: Windows Update policies removed (auto-update default restored)"
    }
    "Disable Background App Throttling" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableLowQosTimerResolution /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f 2>$null
        Write-Log "Revert: Background App Throttling restored"
    }

    # == GAMING  --  GPU & DRIVER ============================================
    "NVIDIA Low Latency Mode (Reflex)" = {
        if ($IsNVIDIA) {
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v NVLatency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Revert: NVIDIA Low Latency Mode disabled"
        } else {
            Write-Log "Revert: NVIDIA Low Latency skipped (no NVIDIA GPU)"
        }
    }
    "Enable MSI Mode (Message Signaled Interrupts)" = {
        $gpuDev = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
        if ($gpuDev) {
            $pnpId   = $gpuDev.PNPDeviceID
            $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            reg add $regPath /v MSISupported /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Revert: MSI Mode disabled for $($gpuDev.Name)"
        }
    }
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: HAGS disabled (HwSchMode=1)"
    }
    "Clear Shader Cache" = {
        Write-Log "Revert: Shader Cache cleared  --  nothing to restore (cache rebuilds automatically)"
    }
    "Enable DirectX 12 Optimization" = {
        reg delete "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE /f 2>$null
        reg delete "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_CPU_PAGE_PROPERTY /f 2>$null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /f 2>$null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDdiDelay /f 2>$null
        Write-Log "Revert: DirectX 12 optimization keys removed"
    }

    # == NETWORK  --  LATENCY ================================================
    "Disable Nagle's Algorithm (TCPNoDelay)" = {
        $adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
        foreach ($adapter in $adapters) {
            $path = $adapter.PSPath
            Remove-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: Nagle keys removed (default restored)"
    }
    "Disable Large Send Offload (LSO)" = {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: LSO re-enabled on all active adapters"
    }
    "Disable Network Throttling Index" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f | Out-Null
        Write-Log "Revert: Network Throttling Index restored to default (10)"
    }

    # == NETWORK  --  DNS ====================================================
    "Set DNS to Cloudflare (1.1.1.1)" = {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: DNS reset to automatic/DHCP on all adapters"
    }
    "Set DNS to Google (8.8.8.8)" = {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: DNS reset to automatic/DHCP on all adapters"
    }
    "Flush DNS Cache" = {
        Write-Log "Revert: DNS Flush  --  nothing to restore"
    }

    # == NETWORK  --  TCP ====================================================
    "Disable TCP Auto-Tuning" = {
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        Write-Log "Revert: TCP Auto-Tuning restored to normal"
    }
    "Optimize TCP Settings (ECN/SACK/Timestamps)" = {
        netsh int tcp set global ecncapability=enabled 2>$null | Out-Null
        netsh int tcp set global timestamps=enabled 2>$null | Out-Null
        netsh int tcp set global chimney=enabled 2>$null | Out-Null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SackOpts /f 2>$null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxDupAcks /f 2>$null
        Write-Log "Revert: TCP settings restored to Windows defaults"
    }

    # == NETWORK  --  QOS ====================================================
    "Disable QoS Packet Scheduler Limit" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /f 2>$null
        Write-Log "Revert: QoS bandwidth limit key removed (20% default restored)"
    }

    # == NETWORK  --  ADAPTER ================================================
    "Disable Network Adapter Power Saving" = {
        $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        Get-ChildItem $netClass -ErrorAction SilentlyContinue | ForEach-Object {
            if (Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Revert: Network adapter power saving restored to Windows default"
    }
    "Disable Delivery Optimization (P2P Windows Update)" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /f 2>$null
        Write-Log "Revert: Delivery Optimization (P2P updates) restored to Windows default"
    }

    # == RAM & STORAGE ====================================================
    "Optimize PageFile (System Managed)" = {
        Write-Log "Revert: PageFile was set to System Managed  --  already the Windows default"
    }
    "Clear PageFile on Shutdown" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Revert: ClearPageFileAtShutdown set back to 0 (disabled)"
    }
    "Disable Memory Compression" = {
        try {
            Enable-MMAgent -MemoryCompression -ErrorAction Stop
            Write-Log "Revert: Memory Compression re-enabled"
        } catch {
            Write-Log "Revert: Memory Compression re-enable failed: $_"
        }
    }
    "Enable SSD TRIM" = {
        Write-Log "Revert: SSD TRIM is the Windows default  --  no revert needed"
    }
    "Disable Scheduled Defragmentation" = {
        schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Enable 2>$null | Out-Null
        reg delete "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" /v Enable /f 2>$null
        Write-Log "Revert: Scheduled Defragmentation re-enabled"
    }
    "Optimize NVMe Queue Depth" = {
        if ($HasNVMe) {
            foreach ($disk in $NVMeDisks) {
                $pnpId = $disk.PNPDeviceID
                reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\StorPort" /v QueueDepth /f 2>$null
                reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy" /v DevicePriority /f 2>$null
            }
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerEnabled /f 2>$null
            Write-Log "Revert: NVMe registry keys removed (defaults restored)"
        } else {
            Write-Log "Revert: NVMe Queue Depth skipped (no NVMe detected)"
        }
    }
    "Disable Write-Cache Buffer Flushing" = {
        $disks = Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" |
            Where-Object { $_.MediaType -eq 3 -or $_.MediaType -eq 4 -or
                           $_.MediaType -eq 'Fixed hard disk media' -or $null -eq $_.MediaType }
        foreach ($disk in $disks) {
            $pnpId   = $disk.PNPDeviceID
            $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Disk"
            reg add $regPath /v UserWriteCacheSetting /t REG_DWORD /d 0 /f | Out-Null
        }
        Write-Log "Revert: Write-Cache Buffer Flushing set back to 0 (Windows default)"
    }
    "Disable Hibernation" = {
        powercfg /hibernate on 2>$null | Out-Null
        Write-Log "Revert: Hibernation re-enabled"
    }
    "Clean Temp Files" = {
        Write-Log "Revert: Temp files were deleted  --  nothing to restore"
    }

    # == WINDOWS 11 =====================================================
    "Restore Classic Right-Click Menu" = {
        reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Write-Log "Revert: Win11 new right-click menu restored"
    }
    "Left-Align Taskbar" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Taskbar alignment set back to center (Win11 default)"
    }
    "Disable Widgets" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /f 2>$null
        Write-Log "Revert: Widgets re-enabled"
    }
    "Remove Chat Icon from Taskbar" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Chat icon restored in taskbar"
    }
    "Disable Recommended in Start Menu" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /f 2>$null
        Write-Log "Revert: Recommended section in Start Menu re-enabled"
    }
    "Enable End Task in Taskbar" = {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /f 2>$null
        Write-Log "Revert: End Task in taskbar disabled (key removed)"
    }
    "Disable Snap Layout Hover Menu" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Snap Layout hover menu re-enabled"
    }

    # == AUDIO ============================================================
    "Disable Audio Enhancements" = {
        $renderPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
        if (Test-Path $renderPath) {
            Get-ChildItem $renderPath | ForEach-Object {
                $fxPath = Join-Path $_.PSPath "FxProperties"
                Set-ItemProperty -Path $fxPath -Name "{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5" `
                    -Value 0 -Type DWord -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Revert: Audio Enhancements re-enabled"
    }
    "Optimize MMCSS Audio Profile" = {
        $audioPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
        reg add $audioPath /v "Latency Sensitive" /t REG_SZ /d "False" /f | Out-Null
        reg add $audioPath /v "Priority" /t REG_DWORD /d 2 /f | Out-Null
        reg add $audioPath /v "Scheduling Category" /t REG_SZ /d "Medium" /f | Out-Null
        reg add $audioPath /v "SFIO Priority" /t REG_SZ /d "Normal" /f | Out-Null
        Write-Log "Revert: MMCSS Audio profile restored to defaults"
    }
    "Set Audio Service High Priority" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f | Out-Null
        Write-Log "Revert: SystemResponsiveness restored to 20 (default)"
    }
    "Disable Windows Sound Scheme" = {
        reg add "HKCU\AppEvents\Schemes" /ve /t REG_SZ /d "Windows Default" /f | Out-Null
        Write-Log "Revert: Sound Scheme set back to Windows Default"
    }
    "Disable Spatial Sound (Windows Sonic)" = {
        Write-Log "Revert: Spatial Sound  --  re-enable via Settings > Sound > Device properties if needed"
    }
    "Disable Audio Device Power Save" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio2" /v DisableSelectiveSuspend /f 2>$null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio" /v DisableSelectiveSuspend /f 2>$null
        $audioClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}"
        if (Test-Path $audioClass) {
            Get-ChildItem $audioClass -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-ItemProperty -Path $_.PSPath -Name "PowerThrottlingOff" -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Revert: Audio Device Power Save re-enabled"
    }

    # == GPU TWEAKS (NVIDIA) ==============================================
    "NVIDIA: Disable Threaded Optimization" = {
        if ($IsNVIDIA) {
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v ThreadedOptimization /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Revert: NVIDIA Threaded Optimization re-enabled"
        }
    }
    "NVIDIA: Max Pre-Rendered Frames = 1" = {
        if ($IsNVIDIA) {
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PrerenderedFrames /f 2>$null
            Write-Log "Revert: NVIDIA Pre-Rendered Frames key removed (driver default)"
        }
    }
    "NVIDIA: Shader Cache Size (Unlimited)" = {
        if ($IsNVIDIA) {
            reg delete "HKCU\SOFTWARE\NVIDIA Corporation\Global\NVTweak" /v NvCplCacheShaderMaxSize /f 2>$null
            Write-Log "Revert: NVIDIA Shader Cache size key removed (driver default)"
        }
    }
    "NVIDIA: Power Management = Max Performance" = {
        if ($IsNVIDIA) {
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerEnable /f 2>$null
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerLevel /f 2>$null
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v PowerMizerLevelAC /f 2>$null
            Write-Log "Revert: NVIDIA Power Management keys removed (driver default)"
        }
    }

    # == GPU TWEAKS (AMD) =================================================
    "AMD: Disable ULPS (Ultra Low Power State)" = {
        if ($IsAMD) {
            $amdClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            if (Test-Path $amdClass) {
                Get-ChildItem $amdClass -ErrorAction SilentlyContinue | ForEach-Object {
                    Set-ItemProperty -Path $_.PSPath -Name "EnableULPS" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $_.PSPath -Name "EnableULPS_NA" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Revert: AMD ULPS re-enabled"
        }
    }
    "AMD: Shader Cache (Unlimited)" = {
        if ($IsAMD) {
            reg delete "HKLM\SOFTWARE\ATI Technologies\CBT" /v ShaderCacheSizePC /f 2>$null
            Write-Log "Revert: AMD Shader Cache key removed (driver default)"
        }
    }
    "AMD: Anti-Lag (Low Latency Mode)" = {
        if ($IsAMD) {
            $amdClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            if (Test-Path $amdClass) {
                Get-ChildItem $amdClass -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-ItemProperty -Path $_.PSPath -Name "EnableAntiLag" -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Revert: AMD Anti-Lag key removed (driver default)"
        }
    }

    # == POWER PLAN =======================================================
    "Disable USB Selective Suspend" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: USB Selective Suspend re-enabled"
    }
    "Disable PCI-E Link State Power Management" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: PCI-E ASPM set back to Moderate (2)"
    }
    "Disable Hard Disk Sleep" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_DISK DISKIDLE 1800 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_DISK DISKIDLE 600  | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: Hard Disk Sleep restored (30 min AC / 10 min DC)"
    }
    "Set Display Sleep = 15 Minutes" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 600  | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 120  | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: Display Sleep restored (10 min AC / 2 min DC)"
    }
    "Disable Sleep (System)" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 3600 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 1800 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: System Sleep restored (60 min AC / 30 min DC)"
    }
    "CPU Minimum Processor State = 100%" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: CPU Minimum Processor State restored to 5%"
    }
    "CPU Maximum Processor State = 100%" = {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
        Write-Log "Revert: CPU Maximum Processor State confirmed at 100%"
    }
}

# -----------------------------------------
# TWEAK STATUS CHECK FUNCTIONS
# Returns $true = aktiv, $false = nicht aktiv, $null = unbekannt
# -----------------------------------------
function Get-RegVal($Path, $Name) {
    try { (Get-ItemProperty $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

$CheckFunctions = @{

    # BLOATWARE
    "Remove Cortana"                     = { $null -eq (Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" -EA SilentlyContinue | Select-Object -First 1) }
    "Remove Xbox Apps"                   = { $null -eq (Get-AppxPackage -AllUsers "*XboxGamingOverlay*" -EA SilentlyContinue | Select-Object -First 1) }
    "Remove Microsoft Teams (Personal)"  = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" "ConfigureChatAutoInstall") -eq 0 }
    "Remove Copilot"                     = { (Get-RegVal "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot") -eq 1 }
    "Remove OneDrive"                    = { -not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") }
    "Remove Windows Recall"              = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis") -eq 1 }
    "Remove Other Bloatware"             = { $null -eq (Get-AppxPackage -AllUsers "*CandyCrush*" -EA SilentlyContinue | Select-Object -First 1) }

    # PRIVACY
    "Disable Power Throttling" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff") -eq 1 }
    "Disable Bing in Windows Search" = { (Get-RegVal "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions") -eq 1 }
    "Process Count Reduction (Svchost)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB") -gt 380000 }

    "Disable Telemetry & Data Collection" = { (($s=Get-Service DiagTrack -EA SilentlyContinue) -and $s.StartType -eq "Disabled") -or ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry") -eq 0) }
    "Disable Activity History"           = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed") -eq 0 }
    "Disable Advertising ID"             = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled") -eq 0 }
    "Disable Location Tracking"          = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value") -eq "Deny" }
    "Block Telemetry Hosts (hosts file)" = { (Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -EA SilentlyContinue) -match "0.0.0.0 telemetry.microsoft.com" }
    "Disable Scheduled Telemetry Tasks"  = { ($t = Get-ScheduledTask -TaskName "Microsoft Compatibility Appraiser" -EA SilentlyContinue) -and $t.State -eq "Disabled" }

    # PERFORMANCE
    "Ultimate Performance Plan"          = { (powercfg /getactivescheme 2>$null) -match "e9a42b02|Ultimat" }
    "Disable HPET (High Precision Event Timer)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests") -eq 1 }
    "Set 0.5ms Timer Resolution"         = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests") -eq 1 }
    "Disable Prefetch & Superfetch"      = { (($s=Get-Service SysMain -EA SilentlyContinue) -and ($s.StartType -eq "Disabled" -or $s.Status -eq "Stopped")) }
    "Optimize Visual Effects (Performance Mode)" = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting") -eq 2 }
    "Disable Windows Search Indexing"    = { (($s=Get-Service WSearch -EA SilentlyContinue) -and $s.StartType -eq "Disabled") }

    # MOUSE & UI
    "Disable Mouse Acceleration"         = { (Get-RegVal "HKCU:\Control Panel\Mouse" "MouseSpeed") -eq "0" }
    "Disable Sticky Keys"                = { (Get-RegVal "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags") -eq "506" }
    "Enable Dark Mode"                   = { (Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme") -eq 0 }
    "Disable Transparency Effects"       = { (Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency") -eq 0 }

    # GAMING IN-GAME
    "Enable Game Mode"                   = { (Get-RegVal "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled") -eq 1 }
    "Disable Xbox Game Bar"              = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled") -eq 0 }
    "CPU Priority for Games (Win32Priority)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation") -eq 26 }
    "MMCSS Gaming Profile (High Priority)" = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category") -eq "High" }
    "Disable Fullscreen Optimizations"   = { (Get-RegVal "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode") -eq 2 }
    "Disable Windows Update during Gaming" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate") -eq 1 }
    "Disable Background App Throttling"  = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled") -eq 1 }

    # GAMING GPU
    "NVIDIA Low Latency Mode (Reflex)"   = { if (-not $IsNVIDIA) { return $null }; (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "NVLatency") -eq 1 }
    "Enable MSI Mode (Message Signaled Interrupts)" = {
        $g = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
        if (-not $g) { return $null }
        (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($g.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported") -eq 1
    }
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode") -eq 2 }
    "Clear Shader Cache"                 = { $null }
    "Enable DirectX 12 Optimization"    = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE") -eq 1 }

    # NETWORK
    "Disable Nagle's Algorithm (TCPNoDelay)" = {
        $ifaces = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -EA SilentlyContinue
        ($ifaces | Where-Object { $_.TCPNoDelay -eq 1 } | Select-Object -First 1) -ne $null
    }
    "Disable Large Send Offload (LSO)"   = {
        $a = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if (-not $a) { return $null }
        $lso = Get-NetAdapterLso -Name $a.Name -EA SilentlyContinue
        $lso -and -not $lso.IPv4Enabled -and -not $lso.IPv6Enabled
    }
    "Disable Network Throttling Index"   = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex") -eq 4294967295 }
    "Set DNS to Cloudflare (1.1.1.1)"   = {
        $a = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if (-not $a) { return $null }
        $dnsObj = Get-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -EA SilentlyContinue
        $dnsObj -and $dnsObj.ServerAddresses -contains "1.1.1.1"
    }
    "Set DNS to Google (8.8.8.8)"        = {
        $a = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if (-not $a) { return $null }
        $dnsObj = Get-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -EA SilentlyContinue
        $dnsObj -and $dnsObj.ServerAddresses -contains "8.8.8.8"
    }
    "Flush DNS Cache"                    = { $null }
    "Disable TCP Auto-Tuning"            = { (Get-NetTCPSetting -SettingName InternetCustom -EA SilentlyContinue).AutoTuningLevelLocal -eq "Disabled" }
    "Optimize TCP Settings (ECN/SACK/Timestamps)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts") -eq 1 }
    "Disable QoS Packet Scheduler Limit" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit") -eq 0 }
    "Disable Network Adapter Power Saving" = {
        $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        $adapters = Get-ChildItem $netClass -ErrorAction SilentlyContinue | Where-Object { Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -EA SilentlyContinue }
        if (-not $adapters) { return $null }
        $off = @($adapters | Where-Object { (Get-RegVal $_.PSPath "PnPCapabilities") -eq 24 })
        $off.Count -eq $adapters.Count
    }
    "Disable Delivery Optimization (P2P Windows Update)" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode") -eq 0 }

    # RAM & STORAGE
    "Optimize PageFile (System Managed)" = { (($cs=Get-WmiObject Win32_ComputerSystem -EA SilentlyContinue) -and $cs.AutomaticManagedPagefile -eq $true) }
    "Clear PageFile on Shutdown"         = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown") -eq 1 }
    "Disable Memory Compression"         = {
        try { $m = Get-MMAgent -EA Stop; -not $m.MemoryCompression } catch { $null }
    }
    "Enable SSD TRIM"                    = { (fsutil behavior query DisableDeleteNotify 2>$null) -match "= 0" }
    "Disable Scheduled Defragmentation"  = {
        $t = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" -EA SilentlyContinue
        $t -and $t.State -eq "Disabled"
    }
    "Optimize NVMe Queue Depth"          = {
        if (-not $HasNVMe) { return $null }
        $d = $NVMeDisks | Select-Object -First 1
        (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.PNPDeviceID)\Device Parameters\StorPort" "QueueDepth") -eq 32
    }
    "Disable Write-Cache Buffer Flushing" = {
        $d = Get-WmiObject "SELECT * FROM Win32_DiskDrive" -EA SilentlyContinue | Where-Object { $null -eq $_.MediaType -or $_.MediaType -eq 3 -or $_.MediaType -eq 4 } | Select-Object -First 1
        if (-not $d) { return $null }
        (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.PNPDeviceID)\Device Parameters\Disk" "UserWriteCacheSetting") -eq 1
    }
    "Disable Hibernation"                = { -not (Test-Path "$env:SystemRoot\hiberfil.sys") }
    "Clean Temp Files"                   = { $null }

    # WINDOWS 11
    "Restore Classic Right-Click Menu"   = { Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" }
    "Left-Align Taskbar"                 = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl") -eq 0 }
    "Disable Widgets"                    = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa") -eq 0 }
    "Remove Chat Icon from Taskbar"      = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn") -eq 0 }
    "Disable Recommended in Start Menu"  = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection") -eq 1 }
    "Enable End Task in Taskbar"         = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask") -eq 1 }
    "Disable Snap Layout Hover Menu"     = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout") -eq 0 }

    # AUDIO
    "Disable Audio Enhancements"         = {
        $rp = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
        if (-not (Test-Path $rp)) { return $null }
        $dev = Get-ChildItem $rp -EA SilentlyContinue | Select-Object -First 1
        if (-not $dev) { return $null }
        $fx = Join-Path $dev.PSPath "FxProperties"
        (($fp=Get-ItemProperty $fx -Name "{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5" -EA SilentlyContinue) -and $fp."{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5" -eq 1)
    }
    "Optimize MMCSS Audio Profile"       = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" "Latency Sensitive") -eq "True" }
    "Set Audio Service High Priority"    = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness") -eq 0 }
    "Disable Windows Sound Scheme"       = {
        try { (Get-ItemProperty "HKCU:\AppEvents\Schemes" -EA Stop)."(default)" -eq ".None" } catch { $null }
    }
    "Disable Spatial Sound (Windows Sonic)" = { $null }
    "Disable Audio Device Power Save"    = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\usbaudio2" "DisableSelectiveSuspend") -eq 1 }

    # GPU NVIDIA
    "NVIDIA: Disable Threaded Optimization" = { if (-not $IsNVIDIA) { return $null }; (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "ThreadedOptimization") -eq 0 }
    "NVIDIA: Max Pre-Rendered Frames = 1"   = { if (-not $IsNVIDIA) { return $null }; (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "PrerenderedFrames") -eq 1 }
    "NVIDIA: Shader Cache Size (Unlimited)" = { if (-not $IsNVIDIA) { return $null }; (Get-RegVal "HKCU:\SOFTWARE\NVIDIA Corporation\Global\NVTweak" "NvCplCacheShaderMaxSize") -ne $null }
    "NVIDIA: Power Management = Max Performance" = { if (-not $IsNVIDIA) { return $null }; (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "PowerMizerLevel") -eq 1 }

    # GPU AMD
    "AMD: Disable ULPS (Ultra Low Power State)" = {
        if (-not $IsAMD) { return $null }
        $ac = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        if (-not (Test-Path $ac)) { return $null }
        $first = Get-ChildItem $ac -EA SilentlyContinue | Select-Object -First 1
        if (-not $first) { return $null }
        (($p=Get-ItemProperty $first.PSPath -Name "EnableULPS" -EA SilentlyContinue) -and $p.EnableULPS -eq 0)
    }
    "AMD: Shader Cache (Unlimited)"      = { if (-not $IsAMD) { return $null }; (Get-RegVal "HKLM:\SOFTWARE\ATI Technologies\CBT" "ShaderCacheSizePC") -ne $null }
    "AMD: Anti-Lag (Low Latency Mode)"   = {
        if (-not $IsAMD) { return $null }
        $ac = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        if (-not (Test-Path $ac)) { return $null }
        $first = Get-ChildItem $ac -EA SilentlyContinue | Select-Object -First 1
        if (-not $first) { return $null }
        (($p=Get-ItemProperty $first.PSPath -Name "EnableAntiLag" -EA SilentlyContinue) -and $p.EnableAntiLag -eq 1)
    }

    # POWER PLAN
    "Disable USB Selective Suspend"      = { ($r = powercfg /QUERY SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 2>$null); $r -and ($r | Select-String "0x00000000") }
    "Disable PCI-E Link State Power Management" = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2>$null); $r -and ($r | Select-String "0x00000000") }
    "Disable Hard Disk Sleep"            = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_DISK DISKIDLE 2>$null); $r -and ($r | Select-String "0x00000000") }
    "Set Display Sleep = 15 Minutes"     = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>$null); $r -and ($r | Select-String "0x00000384") }
    "Disable Sleep (System)"             = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>$null); $r -and ($r | Select-String "0x00000000") }
    "CPU Minimum Processor State = 100%" = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 2>$null); $r -and ($r | Select-String "0x00000064") }
    "CPU Maximum Processor State = 100%" = { ($r = powercfg /QUERY SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 2>$null); $r -and ($r | Select-String "0x00000064") }
}

# -----------------------------------------
# SANITY CHECK
# A $CheckFunctions entry must be a read-only status check, never a copy of
# its $RevertActions entry -- that exact copy-paste mistake once caused
# "Disable Power Throttling", "Disable Bing in Windows Search" and
# "Process Count Reduction (Svchost)" to silently undo themselves every time
# the tweak list was built (i.e. on every app start), with no user action.
# This compares scriptblock bodies at startup and neutralizes (-> returns
# $null / "unknown") any CheckFunction found identical to its RevertAction,
# so a future copy-paste bug can never again execute revert logic as a
# side effect of simply displaying a status dot.
# -----------------------------------------
$Script:SanityCheckFailures = @()
foreach ($key in @($CheckFunctions.Keys)) {
    if ($RevertActions.ContainsKey($key)) {
        $checkBody  = $CheckFunctions[$key].ToString().Trim()
        $revertBody = $RevertActions[$key].ToString().Trim()
        if ($checkBody -eq $revertBody) {
            $Script:SanityCheckFailures += $key
            $CheckFunctions[$key] = { $null }
        }
    }
}
if ($Script:SanityCheckFailures.Count -gt 0) {
    $msg = "SANITY CHECK FAILED: $($Script:SanityCheckFailures.Count) CheckFunctions were identical to their RevertActions and have been neutralized: $($Script:SanityCheckFailures -join ', ')"
    Write-Log $msg
    Write-Host "[$(Get-Date -f 'HH:mm:ss')] $msg" -ForegroundColor Red
}

# -----------------------------------------
# LANGUAGE SUPPORT  --  EN Descriptions
# $TweakDescEN keyed by tweak Name
# -----------------------------------------
$Script:CurrentLang = "EN"
$LangState = @{ Current = "EN" }  # Reference type -- shared across all closures
$Script:TweakDots = @{}           # tweakName -> dot Border (for Verify button re-check)

# -----------------------------------------
# CENTRAL UI STRING TABLE  --  full DE/EN switch
# Every static UI label lives here, keyed by string id.
# Get-UIString "id" returns the text in the current language.
# -----------------------------------------
$Script:UIStrings = @{
    # Header / subtitle
    "subtitle"          = @{ EN = "Windows & Gaming Optimizer v1.1 -- by FloDePin";      DE = "Windows & Gaming Optimizer v1.1 -- von FloDePin" }
    "hw_detecting"      = @{ EN = "Detecting hardware...";                                DE = "Erkenne Hardware..." }

    # Tab headers
    "tab_windows"       = @{ EN = "[WIN]  Windows";        DE = "[WIN]  Windows" }
    "tab_gaming"        = @{ EN = "[GAME] Gaming";         DE = "[GAME] Gaming" }
    "tab_network"       = @{ EN = "[NET]  Network";        DE = "[NET]  Netzwerk" }
    "tab_ram"           = @{ EN = "[RAM]  RAM & Storage";  DE = "[RAM]  RAM & Speicher" }
    "tab_win11"         = @{ EN = "[W11]  Windows 11";     DE = "[W11]  Windows 11" }
    "tab_audio"         = @{ EN = "[AUDIO] Audio";         DE = "[AUDIO] Audio" }
    "tab_gpu"           = @{ EN = "[GPU]  GPU Tweaks";     DE = "[GPU]  GPU-Tweaks" }
    "tab_power"         = @{ EN = "[PWR]  Power Plan";     DE = "[PWR]  Energieplan" }
    "tab_bios"          = @{ EN = "[BIOS] BIOS Guide";     DE = "[BIOS] BIOS-Guide" }
    "tab_dashboard"     = @{ EN = "[DASH] Dashboard";      DE = "[DASH] Dashboard" }

    # Main buttons
    "btn_selectall"     = @{ EN = "[x] Select All";        DE = "[x] Alle auswaehlen" }
    "btn_deselectall"   = @{ EN = "[ ] Deselect All";      DE = "[ ] Alle abwaehlen" }
    "btn_verify"        = @{ EN = "$([char]0x2713) Verify"; DE = "$([char]0x2713) Pruefen" }
    "btn_apply"         = @{ EN = ">> Apply Selected";     DE = ">> Auswahl anwenden" }
    "btn_revertall"     = @{ EN = "$([char]0x21A9) Revert All"; DE = "$([char]0x21A9) Alles zuruecksetzen" }
    "btn_startup"       = @{ EN = "$([System.Char]::ConvertFromUtf32(0x1F680)) Startup Mgr"; DE = "$([System.Char]::ConvertFromUtf32(0x1F680)) Autostart" }
    "btn_services"      = @{ EN = "$([char]0x2699) Services Mgr"; DE = "$([char]0x2699) Dienste" }
    "btn_openlog"       = @{ EN = "[Log] Open Log";        DE = "[Log] Log oeffnen" }

    # Status bar
    "status_ready"      = @{ EN = "Ready -- select tweaks and click Apply Selected.";     DE = "Bereit -- Tweaks auswaehlen und 'Auswahl anwenden' klicken." }
    "status_lang_en"    = @{ EN = "Language switched to English.";                          DE = "Language switched to English." }
    "status_lang_de"    = @{ EN = "Sprache auf Deutsch umgestellt.";                        DE = "Sprache auf Deutsch umgestellt." }

    # Startup Manager
    "sw_title"          = @{ EN = "Startup Manager";       DE = "Autostart-Manager" }
    "sw_col_select"     = @{ EN = "Select";                DE = "Auswahl" }
    "sw_col_name"       = @{ EN = "Name";                  DE = "Name" }
    "sw_col_command"    = @{ EN = "Command";               DE = "Befehl" }
    "sw_col_location"   = @{ EN = "Location";              DE = "Ort" }
    "sw_col_status"     = @{ EN = "Status";                DE = "Status" }
    "sw_col_delay"      = @{ EN = "Boot Delay";            DE = "Boot-Verzoegerung" }
    "sw_btn_disable"    = @{ EN = "Disable Selected";      DE = "Auswahl deaktivieren" }
    "sw_btn_enable"     = @{ EN = "Enable Selected";       DE = "Auswahl aktivieren" }
    "sw_btn_refresh"    = @{ EN = "Refresh";               DE = "Aktualisieren" }
    "sw_btn_close"      = @{ EN = "Close";                 DE = "Schliessen" }
    "sw_loading"        = @{ EN = "Loading startup data...";  DE = "Lade Autostart-Daten..." }
    "sw_legend"         = @{ EN = "items  |  Green = fast (<1s)  |  Orange = medium (1-3s)  |  Red = slow (>3s)  |  Hover Boot Delay for details";
                             DE = "Eintraege  |  Gruen = schnell (<1s)  |  Orange = mittel (1-3s)  |  Rot = langsam (>3s)  |  Boot-Verzoegerung fuer Details" }
    "sw_none_sel"       = @{ EN = "No items selected.";       DE = "Keine Eintraege ausgewaehlt." }
    "sw_disabled_msg"   = @{ EN = "items disabled. Takes effect on next login.";  DE = "Eintraege deaktiviert. Wirkt beim naechsten Login." }
    "sw_enabled_msg"    = @{ EN = "items enabled. Takes effect on next login.";   DE = "Eintraege aktiviert. Wirkt beim naechsten Login." }

    # Services Manager
    "svc_title"         = @{ EN = "Services Manager";     DE = "Dienste-Manager" }
    "svc_subtitle"      = @{ EN = "Disable unnecessary Windows services for better performance and privacy.";
                             DE = "Deaktiviere unnoetige Windows-Dienste fuer bessere Performance und Datenschutz." }
    "svc_legend_safe"   = @{ EN = "Safe to disable";      DE = "Sicher deaktivierbar" }
    "svc_legend_caution"= @{ EN = "Caution -- system service"; DE = "Vorsicht -- Systemdienst" }
    "svc_legend_done"   = @{ EN = "Already disabled";     DE = "Bereits deaktiviert" }
    "svc_col_sel"       = @{ EN = "Sel";                  DE = "Ausw" }
    "svc_col_name"      = @{ EN = "Service Name";         DE = "Dienstname" }
    "svc_col_desc"      = @{ EN = "Description";          DE = "Beschreibung" }
    "svc_col_status"    = @{ EN = "Status";               DE = "Status" }
    "svc_col_starttype" = @{ EN = "Start Type";           DE = "Starttyp" }
    "svc_col_category"  = @{ EN = "Category";             DE = "Kategorie" }
    "svc_col_safe"      = @{ EN = "Safe";                 DE = "Sicher" }
    "svc_btn_disable"   = @{ EN = "Disable Selected";     DE = "Auswahl deaktivieren" }
    "svc_btn_enable"    = @{ EN = "Enable Selected";      DE = "Auswahl aktivieren" }
    "svc_btn_refresh"   = @{ EN = "Refresh";              DE = "Aktualisieren" }
    "svc_btn_close"     = @{ EN = "Close";                DE = "Schliessen" }
    "svc_found"         = @{ EN = "services found  |  Green = safe to disable  |  Red = system service (caution)";
                             DE = "Dienste gefunden  |  Gruen = sicher deaktivierbar  |  Rot = Systemdienst (Vorsicht)" }
    "svc_none_sel"      = @{ EN = "No services selected.";  DE = "Keine Dienste ausgewaehlt." }
    "svc_disabled_msg"  = @{ EN = "service(s) disabled. Full effect after restart.";  DE = "Dienst(e) deaktiviert. Wirkt nach Neustart vollstaendig." }
    "svc_enabled_msg"   = @{ EN = "service(s) set to Manual. Service starts on demand.";  DE = "Dienst(e) auf Manual gesetzt. Dienst startet bei Bedarf." }

    # Status words (managers)
    "word_enabled"      = @{ EN = "Enabled";      DE = "Aktiviert" }
    "word_disabled"     = @{ EN = "Disabled";     DE = "Deaktiviert" }
    "word_running"      = @{ EN = "Running";      DE = "Laeuft" }
    "word_stopped"      = @{ EN = "Stopped";      DE = "Gestoppt" }
    "word_automatic"    = @{ EN = "Automatic";    DE = "Automatisch" }
    "word_manual"       = @{ EN = "Manual";       DE = "Manuell" }
    "word_unknown"      = @{ EN = "Unknown";      DE = "Unbekannt" }
}

function Get-UIString {
    param([string]$Id)
    # UI language is permanently English. The DE/EN toggle only affects the
    # "?" info-popup descriptions, not the interface labels.
    if ($Script:UIStrings.ContainsKey($Id)) {
        return $Script:UIStrings[$Id]["EN"]
    }
    return $Id
}

$TweakDescEN = @{
    "Disable Power Throttling"            = "Prevents Windows from throttling processes for energy savings (EcoQoS). Useful for games with multiple processes -- background game processes are no longer throttled."
    "Disable Bing in Windows Search"      = "Disables Bing integration in Windows Search. Start menu searches only locally -- faster, no data exchange with Microsoft on every search."
    "Process Count Reduction (Svchost)"   = "Sets the Svchost split threshold to your RAM size. Windows combines services into fewer separate processes -- noticeably reduces background process count. Reboot recommended."
    "Remove Cortana"                              = "Uninstalls Cortana completely. Cortana is Microsoft's voice assistant that sends data to Microsoft. Not needed by most users."
    "Remove Xbox Apps"                            = "Removes Xbox Game Bar, Identity Provider and TCUI. These apps run in the background consuming resources even without an Xbox."
    "Remove Microsoft Teams (Personal)"           = "Removes the consumer version of Microsoft Teams and blocks automatic reinstallation via registry."
    "Remove Copilot"                              = "Disables and removes Windows Copilot AI assistant. Prevents Copilot from running in the background and sending data."
    "Remove OneDrive"                             = "Completely uninstalls OneDrive including autostart and Explorer integration. Local files remain untouched."
    "Remove Windows Recall"                       = "Disables Windows Recall  --  the AI feature that takes screenshots of your activity. Major privacy concern."
    "Remove Other Bloatware"                      = "Removes pre-installed apps: Candy Crush, TikTok, Disney+, Facebook, Solitaire, Clipchamp, ToDo, Paint3D and more."
    "Disable Telemetry & Data Collection"         = "Disables all Windows telemetry services (DiagTrack, dmwappushservice). Windows stops sending usage data to Microsoft."
    "Disable Activity History"                    = "Disables Windows Timeline/Activity History. Windows stops tracking which apps and files you open."
    "Disable Advertising ID"                      = "Disables the advertising ID Windows assigns each user. Apps can no longer track you across devices for targeted ads."
    "Disable Location Tracking"                   = "Disables the Windows location service system-wide. Apps can no longer request your location."
    "Block Telemetry Hosts (hosts file)"          = "Adds Microsoft telemetry servers to the Windows hosts file, blocking them even if telemetry services are still running."
    "Disable Scheduled Telemetry Tasks"           = "Disables all scheduled Windows tasks that collect and send telemetry data (e.g. Compatibility Appraiser, CEIP)."
    "Ultimate Performance Plan"                   = "Activates the 'Ultimate Performance' power plan. Windows stops throttling CPU cores for maximum performance at all times. Increases power consumption."
    "Disable HPET (High Precision Event Timer)"   = "Disables the High Precision Event Timer. Can reduce system latency and improve gaming performance on some systems with lower frame times."
    "Set 0.5ms Timer Resolution"                  = "Sets Windows timer resolution to 0.5ms (default 15.6ms). Improves frame timing precision and noticeably reduces input lag in games."
    "Disable Prefetch & Superfetch"               = "Disables Prefetch and SysMain (Superfetch). Recommended for SSDs  --  not for HDDs. Reduces background disk writes and RAM usage."
    "Optimize Visual Effects (Performance Mode)"  = "Turns off all Windows animations and visual effects. Windows responds noticeably faster, especially useful for gaming on weaker systems."
    "Disable Windows Search Indexing"             = "Disables the Windows Search Indexer (WSearch). Reduces constant background disk activity. Search still works but slower without index."
    "Disable Mouse Acceleration"                  = "Disables mouse acceleration (Enhance Pointer Precision). Essential for FPS games: mouse movement maps 1:1 without dynamic amplification."
    "Disable Sticky Keys"                         = "Disables the Sticky Keys dialog (triggered by pressing Shift 5 times). Prevents unwanted interruptions mid-game."
    "Enable Dark Mode"                            = "Enables dark mode for Windows and apps system-wide. Easier on the eyes during long gaming sessions, especially at night."
    "Disable Transparency Effects"                = "Disables transparency effects in taskbar and Start menu. Saves GPU resources and slightly reduces RAM usage."
    "Enable Game Mode"                            = "Enables Windows Game Mode. Windows prioritizes CPU/GPU resources for the active game and suppresses Windows Update restarts while gaming."
    "Disable Xbox Game Bar"                       = "Disables the Xbox Game Bar (Win+G overlay). Prevents the Game Bar from running in the background consuming resources. Game Mode remains unaffected."
    "CPU Priority for Games (Win32Priority)"      = "Sets Win32PrioritySeparation to 26. Windows gives active games significantly more CPU time and reduces background process priority."
    "MMCSS Gaming Profile (High Priority)"        = "Sets Multimedia Class Scheduler (MMCSS) profiles for games to High Priority. Better audio and timer interrupt handling while gaming."
    "Disable Fullscreen Optimizations"            = "Disables Windows Fullscreen Optimizations globally. Forces true exclusive fullscreen for lower input lag in games."
    "Disable Windows Update during Gaming"        = "Permanently disables Windows Update auto-download via registry. Windows Update won't interrupt or background-load during gaming."
    "Disable Background App Throttling"           = "Disables Windows CPU throttling for background processes. Prevents Windows from secretly reducing game CPU time when background tasks are active."
    "NVIDIA Low Latency Mode (Reflex)"            = "NVIDIA only: Enables Ultra Low Latency Mode via registry. Reduces render queue to 1 frame for lower input lag. Skipped on AMD/Intel."
    "Enable MSI Mode (Message Signaled Interrupts)" = "Enables MSI mode for GPU and NVMe. Significantly reduces interrupt latency compared to Line-Based Interrupts. Reboot recommended."
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = "Enables HAGS  --  Windows hands GPU scheduling directly to hardware instead of software. Reduces CPU overhead and slightly lowers input lag."
    "Clear Shader Cache"                          = "Clears the NVIDIA/AMD shader cache on disk. Forces fresh shader compilation on next game launch. Useful after driver updates or graphical glitches."
    "Enable DirectX 12 Optimization"             = "Optimizes DirectX 12 settings for maximum gaming performance. Enables DX12 multi-threading and reduces draw call overhead."
    "Disable Nagle's Algorithm (TCPNoDelay)"      = "Disables Nagle's Algorithm on all network adapters. Nagle buffers small packets at the cost of latency. Disabling noticeably reduces ping in online games."
    "Disable Large Send Offload (LSO)"            = "Disables Large Send Offload on all active network adapters. Can reduce ping spikes on some systems in online games."
    "Disable Network Throttling Index"            = "Disables Windows network packet throttling under high CPU load. Gives the network stack the highest priority."
    "Set DNS to Cloudflare (1.1.1.1)"            = "Sets DNS to Cloudflare 1.1.1.1 (Primary) and 1.0.0.1 (Secondary). One of the fastest and most privacy-friendly DNS providers worldwide."
    "Set DNS to Google (8.8.8.8)"                = "Sets DNS to Google 8.8.8.8 (Primary) and 8.8.4.4 (Secondary). Google's globally distributed, fast and reliable DNS. Alternative to Cloudflare."
    "Flush DNS Cache"                             = "Clears the local DNS cache. Useful after DNS changes or connection issues. Fast and has no side effects."
    "Disable TCP Auto-Tuning"                     = "Disables automatic TCP receive window sizing. Can reduce latency spikes on some systems. May slightly reduce throughput on gigabit+ connections."
    "Optimize TCP Settings (ECN/SACK/Timestamps)" = "Optimizes advanced TCP settings: disables ECN, enables SACK, disables TCP Timestamps. Reduces overhead and improves stability in online games."
    "Disable QoS Packet Scheduler Limit"          = "Removes the default 20% bandwidth limit that Windows reserves for QoS. Gives you the full available bandwidth."
    "Disable Network Adapter Power Saving"        = "Disables 'Allow the computer to turn off this device to save power' for all network adapters. Prevents dropped connections and latency spikes caused by adapter power management."
    "Disable Delivery Optimization (P2P Windows Update)" = "Disables Windows Delivery Optimization. Windows only downloads updates directly from Microsoft instead of sharing bandwidth with other PCs on your network/the internet (P2P). Prevents unexpected bandwidth usage while gaming."
    "Optimize PageFile (System Managed)"          = "Sets the pagefile to system managed. Windows dynamically adjusts it to RAM needs  --  prevents both too-small and too-large pagefiles."
    "Clear PageFile on Shutdown"                  = "Clears the pagefile on every shutdown. Prevents sensitive data from remaining on disk after reboot. Good for privacy."
    "Disable Memory Compression"                  = "Disables RAM compression in Windows. Saves CPU cycles during gaming. Recommended when you have enough RAM (16GB+)."
    "Enable SSD TRIM"                             = "Enables TRIM for all connected SSDs. Informs the SSD about unused blocks  --  maintains SSD performance long-term and extends lifespan."
    "Disable Scheduled Defragmentation"           = "Disables automatic scheduled defragmentation. Absolutely not recommended for SSDs  --  this tweak ensures it's turned off."
    "Optimize NVMe Queue Depth"                   = "Optimizes queue depth for NVMe drives. More parallel I/O operations noticeably improve NVMe SSD read/write performance."
    "Disable Write-Cache Buffer Flushing"         = "Disables forced write-cache buffer flushing for SSDs. Noticeably improves write speed. Desktop PCs with stable power supply only."
    "Disable Hibernation"                         = "Disables hibernate mode and removes hiberfil.sys. Frees several GB of disk space (equals your RAM amount). Recommended for desktop PCs."
    "Clean Temp Files"                            = "Deletes all files in %TEMP%, Windows\Temp and Prefetch folders. Frees disk space and can slightly speed up boot."
    "Restore Classic Right-Click Menu"            = "WIN11: Restores the Windows 10 classic right-click menu. No more 'Show more options' click needed to access common options."
    "Left-Align Taskbar"                          = "WIN11: Moves taskbar icons to the left like Windows 10. Windows 11 centers icons by default. Takes effect after Explorer restart."
    "Disable Widgets"                             = "WIN11: Disables the Widgets panel (Weather, News, Stocks). Widgets run as an MSN browser process in the background consuming RAM."
    "Remove Chat Icon from Taskbar"               = "WIN11: Removes the Teams Chat icon from the taskbar. The icon can unintentionally install Microsoft Teams."
    "Disable Recommended in Start Menu"           = "WIN11: Removes the 'Recommended' section from the Start menu. More space for pinned apps and a cleaner layout."
    "Enable End Task in Taskbar"                  = "WIN11: Enables 'End Task' directly in the taskbar right-click menu. Kill unresponsive processes without opening Task Manager."
    "Disable Snap Layout Hover Menu"              = "WIN11: Disables the Snap Layout popup when hovering over the maximize button. Prevents accidental snapping while gaming."
    "Disable Audio Enhancements"                  = "Disables all Windows audio effects (Bass Boost, Surround, EQ) for all playback devices. Reduces audio latency and audiodg.exe CPU load."
    "Optimize MMCSS Audio Profile"                = "Optimizes Multimedia Class Scheduler profile for audio. Sets Latency Sensitive with High scheduling priority. Reduces audio stuttering under CPU load."
    "Set Audio Service High Priority"             = "Increases system priority for audio processing. Sets SystemResponsiveness to 0. Prevents audio dropouts when other processes load the CPU."
    "Disable Windows Sound Scheme"                = "Disables all Windows system sounds (startup, errors, notifications). No unexpected sound interruptions during gaming or streaming."
    "Disable Spatial Sound (Windows Sonic)"       = "Disables Windows Sonic and Dolby Atmos Spatial Sound for all playback devices. Spatial Sound adds CPU overhead and can degrade quality for stereo headsets."
    "Disable Audio Device Power Save"             = "Prevents Windows from putting audio devices (USB headset, sound card) into power saving mode. Eliminates crackling and dropouts when the device wakes from sleep."
    "NVIDIA: Disable Threaded Optimization"       = "NVIDIA only: Disables Threaded Optimization. Can reduce micro-stutters in games where driver thread distribution causes frame time issues."
    "NVIDIA: Max Pre-Rendered Frames = 1"         = "NVIDIA only: Sets maximum pre-rendered frames to 1. Noticeably reduces input lag. Default is 3  --  with 1 frame the GPU waits less on the CPU."
    "NVIDIA: Shader Cache Size (Unlimited)"       = "NVIDIA only: Sets NVIDIA Shader Cache to unlimited. Prevents shaders from being recompiled  --  less stutter on first visit to a map or scene."
    "NVIDIA: Power Management = Max Performance"  = "NVIDIA only: Sets NVIDIA power management to 'Prefer Maximum Performance'. Prevents GPU downclocking under load. Increases power consumption."
    "AMD: Disable ULPS (Ultra Low Power State)"   = "AMD only: Disables Ultra Low Power State. ULPS puts inactive GPUs into extreme power saving and can cause stuttering on wake. Also useful for single GPU."
    "AMD: Shader Cache (Unlimited)"               = "AMD only: Maximizes AMD Shader Cache size. Prevents cache eviction and reduces shader recompilation. Reduces stutter in OpenGL/Vulkan titles."
    "AMD: Anti-Lag (Low Latency Mode)"            = "AMD only: Enables AMD Anti-Lag via registry. Reduces the gap between CPU input and GPU output  --  similar to NVIDIA Reflex. Effective on AMD RX 5000+."
    "Disable USB Selective Suspend"               = "Disables USB Selective Suspend globally. Windows no longer puts USB devices to sleep. Prevents disconnections with USB mice, headsets and controllers under load."
    "Disable PCI-E Link State Power Management"   = "Disables PCI-E ASPM. Prevents the GPU from putting its PCI Express connection into power saving mode. Reduces GPU latency spikes under load."
    "Disable Hard Disk Sleep"                     = "Sets disk sleep timeout to never (0). Prevents the known stuttering after inactivity when an HDD/SSD wakes from sleep."
    "Set Display Sleep = 15 Minutes"              = "Sets monitor sleep timer to 15 minutes (AC) and 5 minutes (battery). Prevents monitor from turning off mid-game while still saving power on breaks."
    "Disable Sleep (System)"                      = "Completely disables system sleep mode. The PC never sleeps after inactivity. Recommended for desktop PCs running downloads or servers in the background."
    "CPU Minimum Processor State = 100%"          = "Sets minimum CPU state to 100%. CPU always runs at full clock speed without throttling. Eliminates the brief ramp-up delay from idle  --  important for consistent FPS."
    "CPU Maximum Processor State = 100%"          = "Sets maximum CPU state to 100%. Ensures Windows never artificially caps the CPU. Relevant on laptops and systems with aggressive thermal policies."
}
# -----------------------------------------
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Tweaks definiert ($($AllTweaks.Count) Stueck)" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Tweaks definiert ($($AllTweaks.Count) Stueck)" -ForegroundColor DarkGray
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML wird geladen..." | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML wird geladen..." -ForegroundColor DarkGray

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameOptimizerPro v1.1 -- by FloDePin"
        Height="720" Width="860"
        ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e">

    <Window.Resources>
        <Style TargetType="Button" x:Key="PrimaryBtn">
            <Setter Property="Background" Value="#0f3460"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#e94560"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#c73652"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button" x:Key="InfoBtn">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Width" Value="22"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#444"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="ToolTipService.InitialShowDelay" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="11"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#e94560"/>
                                <Setter Property="BorderBrush" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#dddddd"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="{TemplateBinding Background}" CornerRadius="6,6,0,0" Margin="2,0" Padding="{TemplateBinding Padding}">
                            <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center"
                                              ContentSource="Header" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                    <Condition Property="IsSelected" Value="False"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="Border" Property="Background" Value="#0f3460"/>
                                <Setter Property="Foreground" Value="White"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollViewer">
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="GameOptimizerPro" FontSize="26" FontWeight="Bold" Foreground="#e94560"/>
            <TextBlock Name="SubtitleText" Text="Windows &amp; Gaming Optimizer v1.1 -- by FloDePin" FontSize="12" Foreground="#888" Margin="2,2,0,0"/>
        </StackPanel>

        <!-- HW INFO -->
        <Border Grid.Row="1" Background="#16213e" CornerRadius="8" Padding="12,8" Margin="0,0,0,12">
            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="11" Foreground="#00d4aa" FontFamily="Consolas" TextWrapping="Wrap" LineHeight="18"/>
        </Border>

        <!-- TABS -->
        <TabControl Grid.Row="2" Background="#16213e" BorderBrush="#333" Padding="0">

            <!-- WINDOWS TAB -->
            <TabItem Name="TabWindows" Header="[WIN]  Windows">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="WindowsPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- GAMING TAB -->
            <TabItem Name="TabGaming" Header="[GAME] Gaming">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="GamingPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- NETWORK TAB -->
            <TabItem Name="TabNetwork" Header="[NET]  Network">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="NetworkPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- RAM & STORAGE TAB -->
            <TabItem Name="TabRam" Header="[RAM]  RAM &amp; Storage">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="RamStoragePanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- WINDOWS 11 TAB -->
            <TabItem Name="TabWin11" Header="[W11]  Windows 11">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="Win11Panel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- AUDIO TAB -->
            <TabItem Name="TabAudio" Header="[AUDIO] Audio">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="AudioPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- GPU TWEAKS TAB -->
            <TabItem Name="TabGpu" Header="[GPU]  GPU Tweaks">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="GpuPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- POWER PLAN TAB -->
            <TabItem Name="TabPower" Header="[PWR]  Power Plan">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="PowerPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- BIOS GUIDE TAB -->
            <TabItem Name="TabBios" Header="[BIOS] BIOS Guide">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="BiosPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <!-- DASHBOARD TAB -->
            <TabItem Name="TabDashboard" Header="[DASH] Dashboard">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="DashboardPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

        </TabControl>

        <!-- BUTTONS -->
        <StackPanel Grid.Row="3" Margin="0,12,0,0" HorizontalAlignment="Right">
            <!-- Row 1: Main action buttons -->
            <WrapPanel HorizontalAlignment="Right" Margin="0,0,0,6">
                <Button Name="BtnSelectAll"   Content="[x] Select All"        Style="{StaticResource PrimaryBtn}" Margin="4,0"/>
                <Button Name="BtnDeselectAll" Content="[ ] Deselect All"      Style="{StaticResource PrimaryBtn}" Margin="4,0"/>
                <Button Name="BtnVerify"      Content="&#x2713; Verify"       Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#0f5c8c"/>
                <Button Name="BtnApply"       Content="&gt;&gt; Apply Selected" Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#e94560"/>
                <Button Name="BtnRevertAll"   Content="&#x21A9; Revert All"   Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#c47a00"/>
                <Button Name="BtnLang"        Content="[DE/EN]"                Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#2a2a6e"/>
            </WrapPanel>
            <!-- Row 2: Manager + Log -->
            <WrapPanel HorizontalAlignment="Right">
                <Button Name="BtnStartup"     Content="&#x1F680; Startup Mgr" Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#1a6b3c"/>
                <Button Name="BtnServices"    Content="&#x2699; Services Mgr" Style="{StaticResource PrimaryBtn}" Margin="4,0" Background="#1a3a6b"/>
                <Button Name="BtnOpenLog"     Content="[Log] Open Log"        Style="{StaticResource PrimaryBtn}" Margin="4,0"/>
                <Button Name="BtnOpenBackups" Content="[Backup] Open Backups" Style="{StaticResource PrimaryBtn}" Margin="4,0"/>
            </WrapPanel>
        </StackPanel>

        <!-- STATUS -->
        <Border Grid.Row="4" Background="#16213e" CornerRadius="6" Padding="10,6" Margin="0,14,0,0">
            <TextBlock Name="StatusText" Text="Ready -- select tweaks and click Apply Selected." Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
        </Border>
    </Grid>
</Window>
"@

# Parse XAML
# Parse XAML  --  eigener try/catch damit Fehler sichtbar bleibt
try {
    $Reader = New-Object System.Xml.XmlNodeReader $XAML
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
    foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML geladen, Fenster erstellt" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML geladen, Fenster erstellt" -ForegroundColor DarkGray
} catch {
    foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML FEHLER: $_" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML FEHLER: $_" -ForegroundColor DarkGray
    [System.Windows.Forms.MessageBox]::Show(
        "XAML-Ladefehler:`n$_`n`nDetails: $startupLog",
        "GameOptimizerPro - XAML Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Get controls
$HwInfoText     = $Window.FindName("HwInfoText")
$WindowsPanel   = $Window.FindName("WindowsPanel")
$GamingPanel    = $Window.FindName("GamingPanel")
$NetworkPanel   = $Window.FindName("NetworkPanel")
$RamStoragePanel= $Window.FindName("RamStoragePanel")
$Win11Panel     = $Window.FindName("Win11Panel")
$AudioPanel     = $Window.FindName("AudioPanel")
$GpuPanel       = $Window.FindName("GpuPanel")
$PowerPanel     = $Window.FindName("PowerPanel")
$BiosPanel      = $Window.FindName("BiosPanel")
$DashboardPanel = $Window.FindName("DashboardPanel")
$BtnApply       = $Window.FindName("BtnApply")
$BtnSelectAll   = $Window.FindName("BtnSelectAll")
$BtnDeselect    = $Window.FindName("BtnDeselectAll")
$BtnOpenLog     = $Window.FindName("BtnOpenLog")
$BtnOpenBackups = $Window.FindName("BtnOpenBackups")
$BtnServices    = $Window.FindName("BtnServices")
$BtnVerify      = $Window.FindName("BtnVerify")
$BtnRevertAll   = $Window.FindName("BtnRevertAll")
$BtnStartup     = $Window.FindName("BtnStartup")
$BtnLang        = $Window.FindName("BtnLang")
$StatusText     = $Window.FindName("StatusText")

# --- Localizable static elements (for full language switch) ---
$SubtitleText   = $Window.FindName("SubtitleText")
$TabWindows     = $Window.FindName("TabWindows")
$TabGaming      = $Window.FindName("TabGaming")
$TabNetwork     = $Window.FindName("TabNetwork")
$TabRam         = $Window.FindName("TabRam")
$TabWin11       = $Window.FindName("TabWin11")
$TabAudio       = $Window.FindName("TabAudio")
$TabGpu         = $Window.FindName("TabGpu")
$TabPower       = $Window.FindName("TabPower")
$TabBios        = $Window.FindName("TabBios")
$TabDashboard   = $Window.FindName("TabDashboard")

# -----------------------------------------
# APPLY-LANGUAGE  --  set every static main-window element to current language.
# The two manager windows read the language when they open, so they are
# already correct in whatever language is active at open time.
# -----------------------------------------
function Apply-Language {
    if ($SubtitleText) { $SubtitleText.Text = Get-UIString "subtitle" }

    if ($TabWindows) { $TabWindows.Header = Get-UIString "tab_windows" }
    if ($TabGaming)  { $TabGaming.Header  = Get-UIString "tab_gaming" }
    if ($TabNetwork) { $TabNetwork.Header = Get-UIString "tab_network" }
    if ($TabRam)     { $TabRam.Header     = Get-UIString "tab_ram" }
    if ($TabWin11)   { $TabWin11.Header   = Get-UIString "tab_win11" }
    if ($TabAudio)   { $TabAudio.Header   = Get-UIString "tab_audio" }
    if ($TabGpu)     { $TabGpu.Header     = Get-UIString "tab_gpu" }
    if ($TabPower)   { $TabPower.Header   = Get-UIString "tab_power" }
    if ($TabBios)    { $TabBios.Header    = Get-UIString "tab_bios" }
    if ($TabDashboard) { $TabDashboard.Header = Get-UIString "tab_dashboard" }

    if ($BtnSelectAll) { $BtnSelectAll.Content = Get-UIString "btn_selectall" }
    if ($BtnDeselect)  { $BtnDeselect.Content  = Get-UIString "btn_deselectall" }
    if ($BtnVerify)    { $BtnVerify.Content    = Get-UIString "btn_verify" }
    if ($BtnApply)     { $BtnApply.Content     = Get-UIString "btn_apply" }
    if ($BtnRevertAll) { $BtnRevertAll.Content = Get-UIString "btn_revertall" }
    if ($BtnStartup)   { $BtnStartup.Content   = Get-UIString "btn_startup" }
    if ($BtnServices)  { $BtnServices.Content  = Get-UIString "btn_services" }
    if ($BtnOpenLog)   { $BtnOpenLog.Content   = Get-UIString "btn_openlog" }
}

# Set HW info
# Split HW info across two lines so nothing gets cut off
$gpuRam   = "GPU: $GPU   |   RAM: $RAM GB   |   $NVMeInfo"
$cpuOs    = "CPU: $CPU   |   $OSShort"
$HwInfoText.Text = "$gpuRam`n$cpuOs"

# -----------------------------------------
# BUILD TWEAK ROWS DYNAMICALLY
# -----------------------------------------
$CheckBoxMap = @{}  # Name -> CheckBox

function New-GroupHeader {
    param([string]$Title)
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text       = $Title
    $tb.FontSize   = 12
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
    $tb.Margin     = New-Object Windows.Thickness(0,14,0,4)
    return $tb
}

function New-TweakRow {
    param($Tweak)

    $panel = New-Object Windows.Controls.StackPanel
    $panel.Orientation = "Horizontal"
    $panel.Margin      = New-Object Windows.Thickness(0,3,0,3)

    # Checkbox
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content           = $Tweak.Name
    $cb.Tag               = $Tweak.Name
    $cb.VerticalAlignment = "Center"
    $cb.FontSize          = 13
    $cb.Margin            = New-Object Windows.Thickness(0,0,8,0)

    # Gray out Win11-only tweaks when running on Win10
    $isWin11Only = ($Tweak.Category -eq "Windows 11") -and (-not $IsWin11)
    # Gray out NVIDIA tweaks on non-NVIDIA, AMD tweaks on non-AMD
    $isWrongGPU  = ($Tweak.Group -eq "NVIDIA" -and -not $IsNVIDIA) -or
                   ($Tweak.Group -eq "AMD"    -and -not $IsAMD)

    if ($isWin11Only) {
        $cb.IsEnabled  = $false
        $cb.Content    = "$($Tweak.Name)  [Win11 only]"
        $cb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(90,90,90))
    } elseif ($isWrongGPU) {
        $cb.IsEnabled  = $false
        $gpuLabel = if ($Tweak.Group -eq "NVIDIA") { "NVIDIA only" } else { "AMD only" }
        $cb.Content    = "$($Tweak.Name)  [$gpuLabel]"
        $cb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(90,90,90))
    } else {
        $cb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    }
    $CheckBoxMap[$Tweak.Name] = $cb

    # Info button  --  Style aus XAML, Hover-Effekte via ControlTemplate.Triggers
    $btn = New-Object Windows.Controls.Button
    $btn.Content              = "?"
    $btn.Width                = 22
    $btn.Height               = 22
    $btn.Cursor               = [System.Windows.Input.Cursors]::Hand
    $btn.VerticalAlignment    = "Center"
    $btn.Style                = $Window.FindResource("InfoBtn")

    $capturedDesc     = $Tweak.Desc
    $capturedName     = $Tweak.Name
    $capturedDescEN   = if ($TweakDescEN.ContainsKey($Tweak.Name)) { $TweakDescEN[$Tweak.Name] } else { $Tweak.Desc }
    $capturedLangRef  = $LangState   # reference to shared hashtable
    $btn.Add_Click({
        $n    = $capturedName
        $d    = if ($capturedLangRef.Current -eq "EN") { $capturedDescEN } else { $capturedDesc }
        $lang = $capturedLangRef.Current
        [System.Windows.MessageBox]::Show($d, "Info [$lang]: $n", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }.GetNewClosure())

    # Status-Dot: zeigt ob Tweak bereits aktiv ist
    $dot = New-Object Windows.Controls.Border
    $dot.Width           = 10
    $dot.Height          = 10
    $dot.CornerRadius    = New-Object Windows.CornerRadius(5)
    $dot.Margin          = New-Object Windows.Thickness(0,0,7,0)
    $dot.VerticalAlignment = "Center"

    Update-TweakDot $dot $Tweak.Name | Out-Null

    # Register dot for later re-verification
    $Script:TweakDots[$Tweak.Name] = $dot

    $panel.Children.Add($dot) | Out-Null
    $panel.Children.Add($cb)  | Out-Null
    $panel.Children.Add($btn) | Out-Null
    return $panel
}

# Shared status-dot update function (used at build time and by Verify button)
function Update-TweakDot($dot, $tweakName) {
    if ($CheckFunctions.ContainsKey($tweakName)) {
        try {
            $isActive = & $CheckFunctions[$tweakName]
            if ($isActive -eq $true) {
                $dot.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,80))
                $dot.ToolTip    = "Aktiv  --  Tweak ist bereits angewendet"
                return "active"
            } elseif ($isActive -eq $false) {
                $dot.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(70,70,70))
                $dot.ToolTip    = "Nicht aktiv"
                return "inactive"
            } else {
                $dot.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(50,50,60))
                $dot.ToolTip    = "Status unbekannt (einmalige Aktion)"
                return "unknown"
            }
        } catch {
            $dot.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(50,50,60))
            $dot.ToolTip    = "Status konnte nicht geprueft werden"
            return "unknown"
        }
    } else {
        $dot.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(50,50,60))
        return "unknown"
    }
}

# =============================================================================
# BIOS GUIDE TAB
# =============================================================================

# -- BIOS setting data (hardware-aware) ----------------------------------------
$BiosProfiles = @(
    @{
        Name    = "AMD Ryzen 9000 / 7000 (Zen 5 / Zen 4) + AM5"
        Match   = @("9800X3D","9900X","9700X","9600X","7800X3D","7900X3D","7900X","7700X","7600X","7950X")
        Color   = "#e94560"
        Settings = @(
            @{ Cat="Memory";      Name="EXPO / XMP Profile";           Rec="Profile 1 (EXPO)";     Path="MIT --> Advanced Memory Settings --> EXPO/XMP";                        Desc="Without EXPO, DDR5 runs at 4800 MHz instead of rated speed. Definitely enable.";        Risk="Safe" }
            @{ Cat="CPU";         Name="Precision Boost Overdrive (PBO)"; Rec="Enabled / Auto";     Path="MIT --> Advanced CPU Core Settings --> AMD Overclocking --> PBO";       Desc="Lets the CPU dynamically clock higher. Auto is optimal for most users.";                Risk="Moderate" }
            @{ Cat="CPU";         Name="CPU Core Performance Boost";    Rec="Auto";                 Path="MIT --> Advanced CPU Core Settings --> CPU Core Performance Boost";      Desc="Must be active for PBO to work.";                                                       Risk="Safe" }
            @{ Cat="CPU";         Name="FCLK Frequency (X3D CPUs)";     Rec="Auto (not manual)";    Path="MIT --> Advanced Memory Settings --> FCLK Frequency";                  Desc="On X3D CPUs, leave FCLK on Auto. Setting it manually can cause instability.";           Risk="Safe" }
            @{ Cat="GPU";         Name="Resizable BAR";                 Rec="Enabled";              Path="Settings --> IO Ports --> Above 4G Decoding + Re-Size BAR Support";     Desc="Important for NVIDIA RTX 30/40 and AMD RX 6000/7000. Up to 15% more FPS.";              Risk="Safe" }
            @{ Cat="GPU";         Name="Above 4G Decoding";             Rec="Enabled";              Path="Settings --> IO Ports --> Above 4G Decoding";                          Desc="Must be active for Resizable BAR to work.";                                             Risk="Safe" }
            @{ Cat="Power";       Name="ErP Power Saving";              Rec="Disabled";             Path="Settings --> Miscellaneous --> ErP";                                   Desc="Disabling prevents unwanted USB wake-ups and network glitches.";                        Risk="Safe" }
            @{ Cat="Fan/Cooling"; Name="Fan Curve";                     Rec="Silent / Custom";      Path="Settings --> Hardware Monitor --> Fan Speed Control";                  Desc="The default curve is often too aggressive. Silent up to 70C, then steeper.";           Risk="Safe" }
            @{ Cat="Boot";        Name="Fast Boot";                     Rec="Disabled";             Path="Settings --> Boot --> Fast Boot";                                      Desc="Disabling allows full POST diagnostics. No real boot-time savings.";                    Risk="Safe" }
            @{ Cat="Security";    Name="Secure Boot";                   Rec="Enabled";              Path="Settings --> Boot --> Secure Boot --> Secure Boot";                    Desc="Should be active (Windows 11 requirement). Only disable for dual-boot.";                Risk="Safe" }
        )
    }
    @{
        Name    = "Intel Core 13th / 14th Gen (Raptor Lake)"
        Match   = @("i9-14","i7-14","i5-14","i9-13","i7-13","i5-13","13900","13700","13600","14900","14700","14600")
        Color   = "#0071c5"
        Settings = @(
            @{ Cat="Memory";  Name="XMP / Intel Extreme Memory Profile"; Rec="Profile 1 (XMP 3.0)"; Path="Advanced --> Memory Configuration --> XMP";                            Desc="DDR5 runs at only 4800 MHz without XMP. Enable XMP 3.0 on modern boards.";              Risk="Safe" }
            @{ Cat="CPU";     Name="Intel Thermal Velocity Boost";      Rec="Enabled";              Path="Advanced --> CPU Configuration --> Intel TVB";                         Desc="Allows boost above TDP with good cooling.";                                             Risk="Safe" }
            @{ Cat="CPU";     Name="CPU Base Clock (BCLK)";             Rec="Auto (100 MHz)";       Path="Advanced --> CPU Configuration --> BCLK Frequency";                    Desc="Do not adjust manually without experience -- it affects everything.";                   Risk="Moderate" }
            @{ Cat="GPU";     Name="Resizable BAR";                     Rec="Enabled";              Path="Advanced --> PCI Subsystem Settings --> Resizable BAR Support";        Desc="Important for RTX 30/40. Requires Above 4G Decoding active.";                            Risk="Safe" }
            @{ Cat="Power";   Name="Power Limit 1 / 2 (PL1/PL2)";       Rec="Auto or Board Max";    Path="Advanced --> CPU Configuration --> CPU Power Limits";                  Desc="With good cooling, leave on Auto. Only reduce manually if throttling.";                 Risk="Moderate" }
            @{ Cat="Boot";    Name="Fast Boot";                         Rec="Disabled";             Path="Boot --> Fast Boot";                                                   Desc="Disabling prevents POST issues.";                                                       Risk="Safe" }
            @{ Cat="Security"; Name="Secure Boot";                      Rec="Enabled";              Path="Boot --> Secure Boot";                                                 Desc="Mandatory for Windows 11. Only disable for Linux dual-boot.";                           Risk="Safe" }
        )
    }
    @{
        Name    = "AMD Ryzen 5000 (Zen 3) + AM4"
        Match   = @("5950X","5900X","5800X3D","5800X","5700X","5600X","5600")
        Color   = "#ed1c24"
        Settings = @(
            @{ Cat="Memory";  Name="DOCP / XMP Profile";                Rec="Profile 1 (DOCP)";     Path="MIT --> Advanced Memory Settings --> Extreme Memory Profile";          Desc="AM4/DDR4 calls XMP DOCP. DDR4-3600 with 1:1 FCLK is optimal.";                          Risk="Safe" }
            @{ Cat="Memory";  Name="FCLK Frequency";                    Rec="1800 MHz (at DDR4-3600)"; Path="MIT --> Advanced Memory Settings --> FCLK Frequency";              Desc="1:1 FCLK=MCLK at 3600 MHz gives maximum Infinity Fabric bandwidth.";                    Risk="Moderate" }
            @{ Cat="CPU";     Name="Precision Boost Overdrive (PBO)";   Rec="Enabled / Advanced";   Path="MIT --> Advanced CPU Core Settings --> AMD Overclocking --> PBO";       Desc="Very mature on Zen 3. PBO2 with Curve Optimizer for max FPS.";                          Risk="Moderate" }
            @{ Cat="GPU";     Name="Resizable BAR";                     Rec="Enabled";              Path="Settings --> IO Ports --> Above 4G Decoding + Re-Size BAR Support";     Desc="Important for RTX 30+ and RX 6000+.";                                                   Risk="Safe" }
            @{ Cat="Power";   Name="Global C-State Control";            Rec="Auto";                 Path="MIT --> Advanced CPU Core Settings --> Global C-state Control";         Desc="Leave on Auto -- disabling manually can reduce performance.";                           Risk="Moderate" }
            @{ Cat="Security"; Name="Secure Boot";                      Rec="Enabled";              Path="Settings --> Boot --> Windows OS Configuration --> Secure Boot";        Desc="Mandatory for Windows 11. Only disable for dual-boot.";                                 Risk="Safe" }
        )
    }
)

# -- Detect which profile matches this system ---------------------------------
function Get-BiosProfile {
    $cpu = $Script:HWInfo_CPU
    if (-not $cpu) { return $null }
    foreach ($biosProfile in $BiosProfiles) {
        foreach ($key in $biosProfile.Match) {
            if ($cpu -like "*$key*") { return $biosProfile }
        }
    }
    return $null
}

# -- Build BIOS Guide Panel ----------------------------------------------------
function Build-BiosPanel {
    $BiosPanel.Children.Clear()

    $biosProfile = Get-BiosProfile

    # Header notice
    $notice = New-Object Windows.Controls.TextBlock
    $notice.TextWrapping = [Windows.TextWrapping]::Wrap
    $notice.Margin = New-Object Windows.Thickness(0,4,0,14)
    $notice.FontSize = 11

    if ($biosProfile) {
        $notice.Text = "Detected platform: $($biosProfile.Name)"
        $notice.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,80))
    } else {
        $notice.Text = "CPU not recognized: $Script:HWInfo_CPU`nShowing general BIOS recommendations."
        $notice.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,120,0))
        # Use first profile as fallback
        $biosProfile = $BiosProfiles[0]
    }
    $BiosPanel.Children.Add($notice) | Out-Null

    # Warning banner
    $warnBorder = New-Object Windows.Controls.Border
    $warnBorder.Background      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(40,25,10))
    $warnBorder.BorderBrush     = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,120,0))
    $warnBorder.BorderThickness = New-Object Windows.Thickness(0,0,0,2)
    $warnBorder.CornerRadius    = New-Object Windows.CornerRadius(6)
    $warnBorder.Padding         = New-Object Windows.Thickness(12,8,12,8)
    $warnBorder.Margin          = New-Object Windows.Thickness(0,0,0,16)
    $warnTb = New-Object Windows.Controls.TextBlock
    $warnTb.Text = "Incorrect BIOS changes can make the system unbootable. This guide is purely informational -- nothing is changed automatically. When in doubt, research first."
    $warnTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,160,60))
    $warnTb.FontSize = 11
    $warnTb.TextWrapping = [Windows.TextWrapping]::Wrap
    $warnBorder.Child = $warnTb
    $BiosPanel.Children.Add($warnBorder) | Out-Null

    # Settings by category
    # Note: $biosProfile.Settings are hashtables. Select-Object -ExpandProperty
    # does NOT reliably read hashtable keys, so extract categories manually.
    $categories = @()
    foreach ($s in $biosProfile.Settings) {
        if ($categories -notcontains $s.Cat) { $categories += $s.Cat }
    }
    foreach ($cat in $categories) {
        # Category header
        $catHdr = New-Object Windows.Controls.TextBlock
        $catHdr.Text       = "-- $cat"
        $catHdr.FontSize   = 12
        $catHdr.FontWeight = "SemiBold"
        $catHdr.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
        $catHdr.Margin     = New-Object Windows.Thickness(0,10,0,4)
        $BiosPanel.Children.Add($catHdr) | Out-Null

        foreach ($setting in ($biosProfile.Settings | Where-Object { $_.Cat -eq $cat })) {
            $row = New-Object Windows.Controls.Border
            $row.Background      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
            $row.BorderBrush     = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(40,50,80))
            $row.BorderThickness = New-Object Windows.Thickness(1)
            $row.CornerRadius    = New-Object Windows.CornerRadius(6)
            $row.Padding         = New-Object Windows.Thickness(14,10,14,10)
            $row.Margin          = New-Object Windows.Thickness(0,2,0,2)

            $grid = New-Object Windows.Controls.Grid
            $col1 = New-Object Windows.Controls.ColumnDefinition; $col1.Width = New-Object Windows.GridLength(200)
            $col2 = New-Object Windows.Controls.ColumnDefinition; $col2.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $col3 = New-Object Windows.Controls.ColumnDefinition; $col3.Width = New-Object Windows.GridLength(65)
            $grid.ColumnDefinitions.Add($col1)
            $grid.ColumnDefinitions.Add($col2)
            $grid.ColumnDefinitions.Add($col3)

            # Setting name
            $tbName = New-Object Windows.Controls.TextBlock
            $tbName.Text      = $setting.Name
            $tbName.FontSize  = 13
            $tbName.FontWeight = "SemiBold"
            $tbName.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,220,220))
            $tbName.VerticalAlignment = "Top"
            $tbName.TextWrapping = [Windows.TextWrapping]::Wrap
            [Windows.Controls.Grid]::SetColumn($tbName, 0)

            # Path + Desc
            $tbDesc = New-Object Windows.Controls.StackPanel
            $tbPath = New-Object Windows.Controls.TextBlock
            $tbPath.Text      = "Path: $($setting.Path)"
            $tbPath.FontSize  = 10
            $tbPath.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
            $tbPath.TextWrapping = [Windows.TextWrapping]::Wrap
            $tbPath.Margin    = New-Object Windows.Thickness(0,0,0,2)
            $tbExpl = New-Object Windows.Controls.TextBlock
            $tbExpl.Text      = $setting.Desc
            $tbExpl.FontSize  = 11
            $tbExpl.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            $tbExpl.TextWrapping = [Windows.TextWrapping]::Wrap
            $tbDescRec = New-Object Windows.Controls.TextBlock
            $tbDescRec.Text   = "Recommended: $($setting.Rec)"
            $tbDescRec.FontSize = 11
            $tbDescRec.FontWeight = "SemiBold"
            $tbDescRec.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,200,80))
            $tbDescRec.Margin = New-Object Windows.Thickness(0,4,0,0)
            $tbDesc.Children.Add($tbPath)    | Out-Null
            $tbDesc.Children.Add($tbExpl)    | Out-Null
            $tbDesc.Children.Add($tbDescRec) | Out-Null
            [Windows.Controls.Grid]::SetColumn($tbDesc, 1)

            # Risk badge
            $riskColor = if ($setting.Risk -eq "Safe") { [Windows.Media.Color]::FromRgb(0,160,60) } else { [Windows.Media.Color]::FromRgb(200,120,0) }
            $riskBorder = New-Object Windows.Controls.Border
            $riskBorder.Background      = New-Object Windows.Media.SolidColorBrush ($riskColor)
            $riskBorder.CornerRadius    = New-Object Windows.CornerRadius(4)
            $riskBorder.Padding         = New-Object Windows.Thickness(6,2,6,2)
            $riskBorder.HorizontalAlignment = "Center"
            $riskBorder.VerticalAlignment   = "Top"
            $riskBorder.Margin = New-Object Windows.Thickness(8,0,0,0)
            $riskTb = New-Object Windows.Controls.TextBlock
            $riskTb.Text      = $setting.Risk
            $riskTb.FontSize  = 10
            $riskTb.FontWeight = "Bold"
            $riskTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
            $riskBorder.Child = $riskTb
            [Windows.Controls.Grid]::SetColumn($riskBorder, 2)

            $grid.Children.Add($tbName)    | Out-Null
            $grid.Children.Add($tbDesc)    | Out-Null
            $grid.Children.Add($riskBorder)| Out-Null
            $row.Child = $grid
            $BiosPanel.Children.Add($row) | Out-Null
        }
    }
}

# -----------------------------------------
# PERFORMANCE DASHBOARD
# Live system snapshot + Vorher/Nachher tweak-status comparison, built on top
# of the existing $CheckFunctions (same functions the Verify button uses).
# -----------------------------------------
$Script:DashboardSnapshot = $null

function Get-DashboardLiveInfo {
    $powerPlan = try { ((powercfg /getactivescheme 2>$null) -replace '.*\(([^)]+)\).*', '$1') } catch { "unknown" }
    $timerRes  = if ((Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests") -eq 1) { "0.5ms (enabled)" } else { "default" }
    $active = 0; $inactive = 0; $unknown = 0
    foreach ($tweak in $AllTweaks) {
        if ($CheckFunctions.ContainsKey($tweak.Name)) {
            try { $v = & $CheckFunctions[$tweak.Name] } catch { $v = $null }
            if ($v -eq $true) { $active++ } elseif ($v -eq $false) { $inactive++ } else { $unknown++ }
        } else { $unknown++ }
    }
    [PSCustomObject]@{
        PowerPlan = $powerPlan
        TimerRes  = $timerRes
        Active    = $active
        Inactive  = $inactive
        Unknown   = $unknown
    }
}

function New-DashboardStatRow($label, $value) {
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"
    $row.Margin      = New-Object Windows.Thickness(0,2,0,2)
    $tbLabel = New-Object Windows.Controls.TextBlock
    $tbLabel.Text     = "${label}: "
    $tbLabel.FontSize = 12
    $tbLabel.FontWeight = "SemiBold"
    $tbLabel.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
    $tbLabel.Width    = 150
    $tbValue = New-Object Windows.Controls.TextBlock
    $tbValue.Text       = "$value"
    $tbValue.FontSize   = 12
    $tbValue.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    $tbValue.TextWrapping = [Windows.TextWrapping]::Wrap
    $row.Children.Add($tbLabel) | Out-Null
    $row.Children.Add($tbValue) | Out-Null
    return $row
}

function Build-DashboardPanel {
    $DashboardPanel.Children.Clear()

    $intro = New-Object Windows.Controls.TextBlock
    $intro.Text        = "Live system status and a Vorher/Nachher (before/after) comparison of tweak states. Take a snapshot, apply or revert tweaks in the other tabs, then compare."
    $intro.FontSize    = 11
    $intro.Foreground  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    $intro.TextWrapping = [Windows.TextWrapping]::Wrap
    $intro.Margin      = New-Object Windows.Thickness(0,4,0,14)
    $DashboardPanel.Children.Add($intro) | Out-Null

    # --- Live info box ---
    $infoBorder = New-Object Windows.Controls.Border
    $infoBorder.Background      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
    $infoBorder.CornerRadius    = New-Object Windows.CornerRadius(6)
    $infoBorder.Padding         = New-Object Windows.Thickness(14,10,14,10)
    $infoBorder.Margin          = New-Object Windows.Thickness(0,0,0,16)
    $infoStack = New-Object Windows.Controls.StackPanel

    $liveInfo = Get-DashboardLiveInfo
    $infoStack.Children.Add((New-DashboardStatRow "GPU / CPU / RAM" "$GPU | $CPU | ${RAM} GB")) | Out-Null
    $infoStack.Children.Add((New-DashboardStatRow "OS"              $OSShort)) | Out-Null
    $infoStack.Children.Add((New-DashboardStatRow "Active Power Plan" $liveInfo.PowerPlan)) | Out-Null
    $infoStack.Children.Add((New-DashboardStatRow "Timer Resolution"  $liveInfo.TimerRes)) | Out-Null
    $summaryRow = New-DashboardStatRow "Tweaks Active" "$($liveInfo.Active) active / $($liveInfo.Inactive) inactive / $($liveInfo.Unknown) unknown (of $($AllTweaks.Count) total)"
    $infoStack.Children.Add($summaryRow) | Out-Null

    $infoBorder.Child = $infoStack
    $DashboardPanel.Children.Add($infoBorder) | Out-Null

    # --- Snapshot / Compare buttons ---
    $btnRow = New-Object Windows.Controls.StackPanel
    $btnRow.Orientation = "Horizontal"
    $btnRow.Margin      = New-Object Windows.Thickness(0,0,0,14)

    $btnSnapshot = New-Object Windows.Controls.Button
    $btnSnapshot.Content = "[SNAP] Take Snapshot"
    $btnSnapshot.Style   = $Window.FindResource("PrimaryBtn")
    $btnSnapshot.Margin  = New-Object Windows.Thickness(0,0,8,0)
    $btnSnapshot.Padding = New-Object Windows.Thickness(8,4,8,4)

    $btnCompare = New-Object Windows.Controls.Button
    $btnCompare.Content = "[CMP] Compare to Snapshot"
    $btnCompare.Style   = $Window.FindResource("PrimaryBtn")
    $btnCompare.Padding = New-Object Windows.Thickness(8,4,8,4)

    $btnRow.Children.Add($btnSnapshot) | Out-Null
    $btnRow.Children.Add($btnCompare)  | Out-Null
    $DashboardPanel.Children.Add($btnRow) | Out-Null

    # --- Result area (snapshot status + diff list) ---
    $resultPanel = New-Object Windows.Controls.StackPanel
    $DashboardPanel.Children.Add($resultPanel) | Out-Null

    $btnSnapshot.Add_Click({
        $states = @{}
        foreach ($tweak in $AllTweaks) {
            if ($CheckFunctions.ContainsKey($tweak.Name)) {
                try { $states[$tweak.Name] = & $CheckFunctions[$tweak.Name] } catch { $states[$tweak.Name] = $null }
            }
        }
        $Script:DashboardSnapshot = @{ Time = Get-Date; States = $states }

        $resultPanel.Children.Clear()
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text       = "Snapshot taken at $((Get-Date).ToString('HH:mm:ss')) -- $($states.Count) tweaks recorded."
        $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,80))
        $tb.FontSize   = 12
        $tb.Margin     = New-Object Windows.Thickness(0,4,0,0)
        $resultPanel.Children.Add($tb) | Out-Null
    }.GetNewClosure())

    $btnCompare.Add_Click({
        $resultPanel.Children.Clear()
        if (-not $Script:DashboardSnapshot) {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text       = "No snapshot yet -- click 'Take Snapshot' first."
            $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,120,0))
            $tb.FontSize   = 12
            $resultPanel.Children.Add($tb) | Out-Null
            return
        }

        $hdr = New-Object Windows.Controls.TextBlock
        $hdr.Text       = "Changes since snapshot ($($Script:DashboardSnapshot.Time.ToString('HH:mm:ss'))):"
        $hdr.FontSize   = 12
        $hdr.FontWeight = "SemiBold"
        $hdr.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
        $hdr.Margin     = New-Object Windows.Thickness(0,4,0,6)
        $resultPanel.Children.Add($hdr) | Out-Null

        $changeCount = 0
        foreach ($tweak in $AllTweaks) {
            if (-not $CheckFunctions.ContainsKey($tweak.Name)) { continue }
            if (-not $Script:DashboardSnapshot.States.ContainsKey($tweak.Name)) { continue }
            $before = $Script:DashboardSnapshot.States[$tweak.Name]
            try { $after = & $CheckFunctions[$tweak.Name] } catch { $after = $null }
            if ($before -ne $after) {
                $changeCount++
                $line = New-Object Windows.Controls.TextBlock
                $toLabel = @{ $true = "active"; $false = "inactive"; $null = "unknown" }
                $line.Text       = "$($tweak.Name): $($toLabel[$before]) -> $($toLabel[$after])"
                $line.FontSize   = 12
                $line.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
                $line.Margin     = New-Object Windows.Thickness(0,1,0,1)
                $resultPanel.Children.Add($line) | Out-Null
            }
        }
        if ($changeCount -eq 0) {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text       = "No changes detected since the snapshot."
            $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            $tb.FontSize   = 12
            $resultPanel.Children.Add($tb) | Out-Null
        }
    }.GetNewClosure())
}

# -- Store HW info for BIOS panel lookup --------------------------------------
$Script:HWInfo_CPU  = $CPU
$Script:HWInfo_GPU  = $GPU


# Fill panels
$categories = @{
    "Windows"      = $WindowsPanel
    "Gaming"       = $GamingPanel
    "Network"      = $NetworkPanel
    "RAM & Storage"  = $RamStoragePanel
    "Windows 11"   = $Win11Panel
    "Audio"        = $AudioPanel
    "GPU Tweaks"   = $GpuPanel
    "Power Plan"   = $PowerPanel
}

# Build BIOS Guide + Dashboard tabs (separate from tweak panels)
Build-BiosPanel
Build-DashboardPanel
foreach ($cat in @("Windows","Gaming","Network","RAM & Storage","Windows 11","Audio","GPU Tweaks","Power Plan")) {  # Note: BIOS Guide + Dashboard are built separately
    $panel  = $categories[$cat]

    # Windows 11 tab: show OS notice at top
    if ($cat -eq "Windows 11") {
        $noticeBlock = New-Object Windows.Controls.TextBlock
        if ($IsWin11) {
            $noticeBlock.Text       = "[OK] Windows 11 Build $OSBuild detected  --  all tweaks available."
            $noticeBlock.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
        } else {
            $noticeBlock.Text       = "[WIN10 DETECTED] These tweaks require Windows 11 and are disabled. Build: $OSBuild"
            $noticeBlock.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,120,0))
        }
        $noticeBlock.FontSize     = 12
        $noticeBlock.FontWeight   = "SemiBold"
        $noticeBlock.Margin       = New-Object Windows.Thickness(0,4,0,10)
        $noticeBlock.TextWrapping = [Windows.TextWrapping]::Wrap
        $panel.Children.Add($noticeBlock) | Out-Null
    }

    # Network tab: live adapter/DNS/gateway info + ping test
    if ($cat -eq "Network") {
        $netInfoBorder = New-Object Windows.Controls.Border
        $netInfoBorder.Background      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
        $netInfoBorder.CornerRadius    = New-Object Windows.CornerRadius(6)
        $netInfoBorder.Padding         = New-Object Windows.Thickness(10,8,10,8)
        $netInfoBorder.Margin          = New-Object Windows.Thickness(0,0,0,12)

        $netInfoStack = New-Object Windows.Controls.StackPanel

        $netInfoText = New-Object Windows.Controls.TextBlock
        $netInfoText.FontSize      = 12
        $netInfoText.FontFamily    = New-Object Windows.Media.FontFamily("Consolas")
        $netInfoText.Foreground    = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
        $netInfoText.TextWrapping  = [Windows.TextWrapping]::Wrap
        try {
            $activeAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
            $ipConfig      = if ($activeAdapter) { Get-NetIPConfiguration -InterfaceIndex $activeAdapter.InterfaceIndex -ErrorAction SilentlyContinue }
            $gateway       = if ($ipConfig) { ($ipConfig.IPv4DefaultGateway | Select-Object -First 1).NextHop }
            $dnsServers    = if ($ipConfig) { ($ipConfig.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses) -join ", " }
            $adapterLine   = if ($activeAdapter) { "$($activeAdapter.Name): $($activeAdapter.InterfaceDescription)  ($($activeAdapter.LinkSpeed))" } else { "No active adapter detected" }
            $netInfoText.Text = "Adapter: $adapterLine`nGateway: $(if ($gateway) { $gateway } else { 'unknown' })   |   DNS: $(if ($dnsServers) { $dnsServers } else { 'unknown' })"
        } catch { $netInfoText.Text = "Network info unavailable" }
        $netInfoStack.Children.Add($netInfoText) | Out-Null

        $pingRow = New-Object Windows.Controls.StackPanel
        $pingRow.Orientation = "Horizontal"
        $pingRow.Margin      = New-Object Windows.Thickness(0,8,0,0)

        $pingBtn = New-Object Windows.Controls.Button
        $pingBtn.Content   = "[PING] Ping Test (Gateway + 1.1.1.1)"
        $pingBtn.Style     = $Window.FindResource("PrimaryBtn")
        $pingBtn.Padding   = New-Object Windows.Thickness(8,4,8,4)

        $pingResult = New-Object Windows.Controls.TextBlock
        $pingResult.FontSize     = 12
        $pingResult.FontFamily   = New-Object Windows.Media.FontFamily("Consolas")
        $pingResult.Margin       = New-Object Windows.Thickness(10,0,0,0)
        $pingResult.VerticalAlignment = "Center"
        $pingResult.Foreground   = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
        $pingResult.Text         = "Not tested yet"

        $capturedGateway = $gateway
        $pingBtn.Add_Click({
            $pingResult.Text = "Testing..."
            $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
            $lines = @()
            if ($capturedGateway) {
                try {
                    $r = Test-Connection -ComputerName $capturedGateway -Count 3 -ErrorAction Stop
                    $avg = [math]::Round(($r | Measure-Object -Property ResponseTime -Average).Average, 1)
                    $lines += "Gateway ($capturedGateway): ${avg}ms"
                } catch { $lines += "Gateway: unreachable" }
            }
            try {
                $r2 = Test-Connection -ComputerName "1.1.1.1" -Count 3 -ErrorAction Stop
                $avg2 = [math]::Round(($r2 | Measure-Object -Property ResponseTime -Average).Average, 1)
                $lines += "Internet (1.1.1.1): ${avg2}ms"
            } catch { $lines += "Internet: unreachable" }
            $pingResult.Text = $lines -join "   |   "
        }.GetNewClosure())

        $pingRow.Children.Add($pingBtn)    | Out-Null
        $pingRow.Children.Add($pingResult) | Out-Null
        $netInfoStack.Children.Add($pingRow) | Out-Null

        $netInfoBorder.Child = $netInfoStack
        $panel.Children.Add($netInfoBorder) | Out-Null
    }

    # GPU tab: show detected GPU and info about brand-specific tweaks
    if ($cat -eq "GPU Tweaks") {
        $gpuNotice = New-Object Windows.Controls.TextBlock
        if ($IsNVIDIA) {
            $gpuNotice.Text       = "[NVIDIA] $GPU detected  --  NVIDIA tweaks active, AMD tweaks grayed out."
            $gpuNotice.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(118,185,0))
        } elseif ($IsAMD) {
            $gpuNotice.Text       = "[AMD] $GPU detected  --  AMD tweaks active, NVIDIA tweaks grayed out."
            $gpuNotice.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(237,28,36))
        } else {
            $gpuNotice.Text       = "[INTEL/OTHER] $GPU detected  --  no brand-specific tweaks available."
            $gpuNotice.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,120,0))
        }
        $gpuNotice.FontSize     = 12
        $gpuNotice.FontWeight   = "SemiBold"
        $gpuNotice.Margin       = New-Object Windows.Thickness(0,4,0,10)
        $gpuNotice.TextWrapping = [Windows.TextWrapping]::Wrap
        $panel.Children.Add($gpuNotice) | Out-Null
    }

    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat } | Select-Object -ExpandProperty Group -Unique
    foreach ($group in $groups) {
        $panel.Children.Add((New-GroupHeader "-- $group")) | Out-Null
        $tweaks = $AllTweaks | Where-Object { $_.Category -eq $cat -and $_.Group -eq $group }
        foreach ($tweak in $tweaks) {
            $panel.Children.Add((New-TweakRow $tweak)) | Out-Null
        }
    }
}

# -----------------------------------------
# BUTTON EVENTS
# -----------------------------------------
$BtnSelectAll.Add_Click({
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true }
})

$BtnDeselect.Add_Click({
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false }
})

$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else {
        [System.Windows.MessageBox]::Show("No log file yet. Apply some tweaks first.", "Log", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$BtnOpenBackups.Add_Click({
    if (Test-Path $Script:RegistryBackupRoot) { Start-Process explorer.exe $Script:RegistryBackupRoot }
    else {
        [System.Windows.MessageBox]::Show("No registry backups yet. Apply or revert some tweaks first.", "Backups", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$BtnVerify.Add_Click({
    $StatusText.Text = "Verifiziere Tweak-Status..."
    $active = 0; $inactive = 0; $unknown = 0
    foreach ($tweak in $AllTweaks) {
        if ($Script:TweakDots.ContainsKey($tweak.Name)) {
            $result = Update-TweakDot $Script:TweakDots[$tweak.Name] $tweak.Name
            switch ($result) {
                "active"   { $active++ }
                "inactive" { $inactive++ }
                default    { $unknown++ }
            }
        }
    }
    $checkable = $active + $inactive
    if ($LangState.Current -eq "EN") {
        $StatusText.Text = "Verify complete: $active of $checkable checkable tweaks active  |  $unknown one-time/unknown  |  green = active, grey = inactive"
    } else {
        $StatusText.Text = "Verify fertig: $active von $checkable pruefbaren Tweaks aktiv  |  $unknown einmalig/unbekannt  |  gruen = aktiv, grau = inaktiv"
    }
})

$BtnApply.Add_Click({
    $selected = @($AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true })

    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!", "GameOptimizerPro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # DNS conflict check  --  warn if both Cloudflare AND Google DNS are selected
    $dnsCloudflare = $selected | Where-Object { $_.Name -like "*Cloudflare*" }
    $dnsGoogle     = $selected | Where-Object { $_.Name -like "*Google*" }
    if ($dnsCloudflare -and $dnsGoogle) {
        $dnsWarn = [System.Windows.MessageBox]::Show(
            "DNS Conflict detected!`n`nYou selected both:`n  - Set DNS to Cloudflare (1.1.1.1)`n  - Set DNS to Google (8.8.8.8)`n`nOnly the LAST one applied will be active.`nRecommendation: select only one DNS tweak.`n`nContinue anyway?",
            "GameOptimizerPro -- DNS Conflict",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($dnsWarn -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) selected tweak(s)?`n`nA system restore point will be created first.",
        "GameOptimizerPro -- Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    # Create Restore Point
    $StatusText.Text = "Creating restore point..."
    try {
        Checkpoint-Computer -Description "GameOptimizerPro Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
        $StatusText.Text = "Restore point created. Backing up registry..."
    } catch {
        Write-Log "Restore point skipped (Windows 24h frequency limit or VSS error): $_"
        $StatusText.Text = "Restore point skipped (24h limit). Backing up registry..."
    }

    # Registry backup (independent of restore-point success -- always runs)
    $Script:LastBackupDir = Backup-Registry -Label "PreApply"
    $StatusText.Text = "Registry backup saved. Applying tweaks..."

    # Apply tweaks
    $done  = 0
    $total = $selected.Count
    foreach ($tweak in $selected) {
        $StatusText.Text = "Applying: $($tweak.Name) ($done/$total)..."
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try {
            & $tweak.Action
            Write-Log "OK: $($tweak.Name)"
        } catch {
            Write-Log "FAILED: $($tweak.Name) -- $_"
        }
        $done++
    }

    $StatusText.Text = "Done! $done tweaks applied. Log: $LogFile"

    # Refresh status dots so the user sees what changed
    foreach ($tweak in $selected) {
        if ($Script:TweakDots.ContainsKey($tweak.Name)) {
            Update-TweakDot $Script:TweakDots[$tweak.Name] $tweak.Name | Out-Null
        }
    }

    [System.Windows.MessageBox]::Show(
        "$done tweaks applied successfully!`n`nSome changes require a restart to take effect.`nLog saved to:`n$LogFile`n`nRegistry backup (.reg files) saved to:`n$Script:LastBackupDir",
        "GameOptimizerPro -- Done",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )

    # Neustart-Empfehlung
    $restart = [System.Windows.MessageBox]::Show(
        "Fuer optimale Wirkung wird ein Neustart empfohlen.`n`nJetzt neu starten?",
        "GameOptimizerPro -- Neustart empfohlen",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($restart -eq [System.Windows.MessageBoxResult]::Yes) {
        Restart-Computer -Force
    }
})

# -----------------------------------------
# REVERT ALL BUTTON
# -----------------------------------------
$BtnRevertAll.Add_Click({

    # Step 1: Let user choose: System Restore or Quick Registry Reset
    $choice = [System.Windows.MessageBox]::Show(
        "REVERT ALL  --  Undo GameOptimizerPro Changes`n`n" +
        "Choose how to revert:`n`n" +
        "  YES  ->  System Restore (Recommended)`n" +
        "           - Restores EVERYTHING including removed apps`n" +
        "           - Opens the Windows System Restore wizard`n" +
        "           - Your PC will reboot (~5-10 min)`n`n" +
        "  NO   ->  Quick Registry Reset`n" +
        "           - Resets all registry & service changes`n" +
        "           - No reboot required`n" +
        "           - Removed apps (OneDrive, Cortana etc.) need System Restore`n`n" +
        "  CANCEL  ->  Do nothing",
        "GameOptimizerPro  --  Revert All",
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($choice -eq [System.Windows.MessageBoxResult]::Cancel) { return }

    # Option A: Open System Restore wizard
    if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Start-Process "rstrui.exe"
        } catch {
            [System.Windows.MessageBox]::Show(
                "Could not open System Restore (rstrui.exe).`nRun it manually via: Start -> type 'rstrui'",
                "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        [System.Windows.MessageBox]::Show(
            "Windows System Restore is opening.`n`n" +
            "In the wizard, select the restore point:`n" +
            "  'GameOptimizerPro Backup'`n`n" +
            "Then follow the on-screen steps.`n" +
            "Your PC will restart automatically to complete the restore.",
            "System Restore  --  Instructions",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
        return
    }

    # Option B: Quick Registry Reset
    $confirm = [System.Windows.MessageBox]::Show(
        "Quick Registry Reset`n`n" +
        "This will restore all registry, service and network settings`n" +
        "to Windows defaults.`n`n" +
        "NOTE: Removed apps (Cortana, Xbox, Teams, OneDrive, Bloatware)`n" +
        "cannot be restored this way  --  use System Restore for those.`n`n" +
        "A new restore point will be created first. Continue?",
        "GameOptimizerPro  --  Confirm Quick Reset",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    # Restore point before reverting
    $StatusText.Text = "Creating safety restore point..."
    try {
        Checkpoint-Computer -Description "GameOptimizerPro Pre-Revert Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Revert restore point created"
        $StatusText.Text = "Safety restore point created. Backing up registry..."
    } catch {
        Write-Log "Revert restore point skipped (24h limit or VSS error): $_"
        $StatusText.Text = "Restore point skipped (24h limit). Backing up registry..."
    }

    # Registry backup (independent of restore-point success -- always runs)
    $Script:LastBackupDir = Backup-Registry -Label "PreRevert"
    $StatusText.Text = "Registry backup saved. Starting revert..."

    # Run all revert actions
    $done  = 0
    $failed = 0
    $total = $RevertActions.Count
    $appWarnings = 0

    foreach ($tweakName in $RevertActions.Keys) {
        $StatusText.Text = "Reverting [$done/$total]: $tweakName..."
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try {
            & $RevertActions[$tweakName]
            $done++
        } catch {
            Write-Log "Revert FAILED: $tweakName -- $_"
            $failed++
            $done++
        }
        # Count app-restore warnings
        if ($tweakName -match "Remove Cortana|Remove Xbox|Remove.*Teams|Remove OneDrive|Remove Other Bloat") {
            $appWarnings++
        }
    }

    $StatusText.Text = "Revert complete! $done/$total settings processed. Log: $LogFile"
    Write-Log "Revert All complete: $done processed, $failed failed"

    $appNote = if ($appWarnings -gt 0) {
        "`n`nIMPORTANT: $appWarnings removed apps (Cortana, Xbox, Teams etc.) cannot be`nrestored via Quick Reset  --  use System Restore for those."
    } else { "" }

    [System.Windows.MessageBox]::Show(
        "Quick Registry Reset complete!`n`n" +
        "$done settings reverted to Windows defaults." +
        $(if ($failed -gt 0) { "`n$failed actions failed (see log for details)." } else { "" }) +
        $appNote +
        "`n`nSome changes require a restart to take effect.`nLog: $LogFile`n`nPre-revert registry backup (.reg files):`n$Script:LastBackupDir",
        "GameOptimizerPro  --  Revert Complete",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

$BtnLang.Add_Click({
    # UI stays permanently English. This toggle ONLY switches the language of
    # the "?" info-popup descriptions (DE/EN).
    if ($LangState.Current -eq "EN") {
        $LangState.Current   = "DE"
        $Script:CurrentLang  = "DE"
        $BtnLang.Content     = "[DE/EN]"
        $BtnLang.Background  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(42,42,110))
        $StatusText.Text     = "Info descriptions (?) now in German. Interface stays English."
    } else {
        $LangState.Current   = "EN"
        $Script:CurrentLang  = "EN"
        $BtnLang.Content     = "[EN/DE]"
        $BtnLang.Background  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(15,90,150))
        $StatusText.Text     = "Info descriptions (?) now in English."
    }
})

# -----------------------------------------
# STARTUP MANAGER
# -----------------------------------------
# -----------------------------------------
# STARTUP DELAY DATA (Windows Event Log)
# Event 902 = Diagnostics-Performance boot delays
# Returns hashtable: { "process.exe" -> delay_ms }
# -----------------------------------------
function Get-StartupDelays {
    $delays = @{}
    try {
        $events = Get-WinEvent -LogName "Microsoft-Windows-Diagnostics-Performance/Operational" `
            -FilterHashtable @{ LogName="Microsoft-Windows-Diagnostics-Performance/Operational"; Id=902 } `
            -MaxEvents 200 -ErrorAction SilentlyContinue
        foreach ($evt in $events) {
            try {
                $xml  = [xml]$evt.ToXml()
                $ns   = $xml.Event.EventData.Data
                $name = ($ns | Where-Object { $_.Name -eq "FileName" })."#text"
                $ms   = ($ns | Where-Object { $_.Name -eq "DegradationInterval" })."#text"
                if ($name -and $ms) {
                    $exe = [System.IO.Path]::GetFileName($name).ToLower()
                    if (-not $delays.ContainsKey($exe) -or $delays[$exe] -lt [int]$ms) {
                        $delays[$exe] = [int]$ms
                    }
                }
            } catch { }
        }
    } catch { }
    return $delays
}

function Get-DelayColor($ms) {
    if     ($ms -gt 3000) { return [Windows.Media.Color]::FromRgb(220, 50,  50)  }  # rot > 3s
    elseif ($ms -gt 1000) { return [Windows.Media.Color]::FromRgb(255, 160, 0)   }  # orange 1-3s
    elseif ($ms -gt 0)    { return [Windows.Media.Color]::FromRgb(0,   200, 80)  }  # gruen < 1s
    else                  { return [Windows.Media.Color]::FromRgb(100, 100, 100) }  # grau: keine Daten
}

function Get-DelayLabel($ms) {
    if     ($ms -gt 3000) { return "Slow: $('{0:0.0}' -f ($ms/1000))s" }
    elseif ($ms -gt 1000) { return "Med:  $('{0:0.0}' -f ($ms/1000))s" }
    elseif ($ms -gt 0)    { return "Fast: $('{0:0.0}' -f ($ms/1000))s" }
    else                  { return "No data" }
}

function Get-StartupEntries {
    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $sources = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKCU\Run"
           App  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKLM\Run"
           App  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKLM\Run32"
           App  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32" }
    )
    foreach ($src in $sources) {
        if (-not (Test-Path $src.Path)) { continue }
        try {
            Get-ItemProperty $src.Path | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                    $name    = $_.Name
                    $cmd     = if ($_.Value -and $_.Value.Length -gt 65) { $_.Value.Substring(0,62)+"..." } else { $_.Value }
                    $enabled = $true
                    if (Test-Path $src.App) {
                        $av = Get-ItemProperty $src.App -Name $name -ErrorAction SilentlyContinue
                        if ($av -and $av.$name -and $av.$name[0] -eq 3) { $enabled = $false }
                    }
                    $entries.Add([PSCustomObject]@{
                        Name        = $name
                        Command     = $cmd
                        FullCmd     = $_.Value
                        Location    = $src.Loc
                        Status      = if ($enabled) { "Enabled" } else { "Disabled" }
                        RegPath     = $src.Path
                        ApprovedPath = $src.App
                    })
                }
            }
        } catch { }
    }
    return $entries
}

$BtnStartup.Add_Click({
    # Build sub-window XAML
    [xml]$swXml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GameOptimizerPro  --  Startup Manager"
        Height="540" Width="920"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Name="SwTitle" Text="Startup Manager" FontSize="18" FontWeight="Bold"
                   Foreground="#e94560" Margin="0,0,0,4"/>
        <Border Grid.Row="1" Background="#16213e" CornerRadius="6" Padding="8,5" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
                <TextBlock Name="SwColSelect" Text="Select" Foreground="#888" FontSize="11" Width="38"/>
                <TextBlock Name="SwColName" Text="Name" Foreground="#888" FontSize="11" FontWeight="Bold" Width="165"/>
                <TextBlock Name="SwColCommand" Text="Command" Foreground="#888" FontSize="11" FontWeight="Bold" Width="280"/>
                <TextBlock Name="SwColLocation" Text="Location" Foreground="#888" FontSize="11" FontWeight="Bold" Width="90"/>
                <TextBlock Name="SwColStatus" Text="Status" Foreground="#888" FontSize="11" FontWeight="Bold" Width="75"/>
                <TextBlock Name="SwColDelay" Text="Boot Delay" Foreground="#888" FontSize="11" FontWeight="Bold" Width="110"/>
            </StackPanel>
        </Border>
        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="SwList"/>
        </ScrollViewer>
        <TextBlock Grid.Row="3" Name="SwStatus" Text="" Foreground="#aaaaaa"
                   FontSize="11" FontFamily="Consolas" Margin="0,8,0,4"/>
        <WrapPanel Grid.Row="4" HorizontalAlignment="Center">
            <Button Name="SwBtnDisable" Content="Disable Selected"  Width="155" Height="32"
                    Margin="6,0" Background="#e94560" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnEnable"  Content="Enable Selected"   Width="155" Height="32"
                    Margin="6,0" Background="#1a7a3c" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnRefresh" Content="Refresh"           Width="100" Height="32"
                    Margin="6,0" Background="#0f3460" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnClose"   Content="Close"             Width="100" Height="32"
                    Margin="6,0" Background="#444"    Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </WrapPanel>
    </Grid>
</Window>
"@
    $swReader = New-Object System.Xml.XmlNodeReader $swXml
    $sw       = [Windows.Markup.XamlReader]::Load($swReader)

    $swList      = $sw.FindName("SwList")
    $swStatus    = $sw.FindName("SwStatus")
    $swDisable   = $sw.FindName("SwBtnDisable")
    $swEnable    = $sw.FindName("SwBtnEnable")
    $swRefresh   = $sw.FindName("SwBtnRefresh")
    $swClose     = $sw.FindName("SwBtnClose")

    # --- Localize Startup Manager labels to current language ---
    $sw.Title = "GameOptimizerPro  --  " + (Get-UIString "sw_title")
    ($sw.FindName("SwTitle")).Text       = Get-UIString "sw_title"
    ($sw.FindName("SwColSelect")).Text   = Get-UIString "sw_col_select"
    ($sw.FindName("SwColName")).Text     = Get-UIString "sw_col_name"
    ($sw.FindName("SwColCommand")).Text  = Get-UIString "sw_col_command"
    ($sw.FindName("SwColLocation")).Text = Get-UIString "sw_col_location"
    ($sw.FindName("SwColStatus")).Text   = Get-UIString "sw_col_status"
    ($sw.FindName("SwColDelay")).Text    = Get-UIString "sw_col_delay"
    $swDisable.Content = Get-UIString "sw_btn_disable"
    $swEnable.Content  = Get-UIString "sw_btn_enable"
    $swRefresh.Content = Get-UIString "sw_btn_refresh"
    $swClose.Content   = Get-UIString "sw_btn_close"

    $swCbMap     = @{}   # name -> @{Cb=checkbox; Item=psobject}

    function Build-StartupRows {
        $swList.Children.Clear()
        $swCbMap.Clear()
        $swStatus.Text = Get-UIString "sw_loading"
        $allEntries = Get-StartupEntries
        $bootDelays  = Get-StartupDelays
        foreach ($entry in $allEntries) {
            $row             = New-Object Windows.Controls.StackPanel
            $row.Orientation = "Horizontal"
            $row.Margin      = New-Object Windows.Thickness(0,2,0,2)

            $cb              = New-Object Windows.Controls.CheckBox
            $cb.Width        = 38
            $cb.VerticalAlignment = "Center"

            $tbName          = New-Object Windows.Controls.TextBlock
            $tbName.Text     = $entry.Name
            $tbName.Width    = 165
            $tbName.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,220,220))
            $tbName.VerticalAlignment = "Center"
            $tbName.ToolTip  = $entry.FullCmd

            $tbCmd           = New-Object Windows.Controls.TextBlock
            $tbCmd.Text      = $entry.Command
            $tbCmd.Width     = 280
            $tbCmd.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,150,150))
            $tbCmd.VerticalAlignment = "Center"
            $tbCmd.ToolTip   = $entry.FullCmd

            $tbLoc           = New-Object Windows.Controls.TextBlock
            $tbLoc.Text      = $entry.Location
            $tbLoc.Width     = 90
            $tbLoc.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            $tbLoc.VerticalAlignment = "Center"

            $tbStatus        = New-Object Windows.Controls.TextBlock
            $tbStatus.Text   = if ($entry.Status -eq "Enabled") { Get-UIString "word_enabled" } else { Get-UIString "word_disabled" }
            $tbStatus.Width  = 75
            $tbStatus.FontWeight = "SemiBold"
            $tbStatus.VerticalAlignment = "Center"
            if ($entry.Status -eq "Enabled") {
                $tbStatus.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,100))
            } else {
                $tbStatus.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,80,80))
            }

            # Boot delay column
            $exeName  = try { [System.IO.Path]::GetFileName($entry.FullCmd.Split('"')[0].Trim()).ToLower() } catch { "" }
            if ($exeName -eq "") { $exeName = $entry.Name.ToLower() + ".exe" }
            $delayMs  = if ($bootDelays.ContainsKey($exeName)) { $bootDelays[$exeName] } else { 0 }

            $tbDelay  = New-Object Windows.Controls.TextBlock
            $tbDelay.Width  = 110
            $tbDelay.Text   = if ($entry.Status -eq "Disabled") { Get-UIString "word_disabled" } else { Get-DelayLabel $delayMs }
            $tbDelay.FontSize    = 11
            $tbDelay.FontWeight  = "SemiBold"
            $tbDelay.VerticalAlignment = "Center"
            $tbDelay.Foreground  = if ($entry.Status -eq "Disabled") {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(100,100,100))
            } else {
                New-Object Windows.Media.SolidColorBrush (Get-DelayColor $delayMs)
            }
            $tbDelay.ToolTip = if ($delayMs -gt 0) {
                "Letzter gemessener Boot-Delay: $delayMs ms`nQuelle: Windows Diagnostics-Performance Log"
            } else {
                "Keine Delay-Daten vorhanden.`nNach naechstem Neustart verfuegbar."
            }

            $row.Children.Add($cb)       | Out-Null
            $row.Children.Add($tbName)   | Out-Null
            $row.Children.Add($tbCmd)    | Out-Null
            $row.Children.Add($tbLoc)    | Out-Null
            $row.Children.Add($tbStatus) | Out-Null
            $row.Children.Add($tbDelay)  | Out-Null
            $swList.Children.Add($row)   | Out-Null

            $swCbMap[$entry.Name] = @{ Cb = $cb; Item = $entry; StatusTb = $tbStatus }
        }
        $swStatus.Text = "$($allEntries.Count) " + (Get-UIString "sw_legend")
    }

    Build-StartupRows

    $swDisable.Add_Click({
        $sel = $swCbMap.Values | Where-Object { $_.Cb.IsChecked -eq $true }
        if (-not $sel) { $swStatus.Text = Get-UIString "sw_none_sel"; return }
        $count = 0
        foreach ($entry in $sel) {
            $item = $entry.Item
            if (-not (Test-Path $item.ApprovedPath)) {
                New-Item -Path $item.ApprovedPath -Force | Out-Null
            }
            $disableBytes = [byte[]](3,0,0,0,0,0,0,0,0,0,0,0)
            Set-ItemProperty -Path $item.ApprovedPath -Name $item.Name -Value $disableBytes -Type Binary -ErrorAction SilentlyContinue
            $entry.StatusTb.Text       = Get-UIString "word_disabled"
            $entry.StatusTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,80,80))
            $entry.Cb.IsChecked        = $false
            $count++
            Write-Log "Startup Manager: Disabled '$($item.Name)'"
        }
        $swStatus.Text = "$count " + (Get-UIString "sw_disabled_msg")
    })

    $swEnable.Add_Click({
        $sel = $swCbMap.Values | Where-Object { $_.Cb.IsChecked -eq $true }
        if (-not $sel) { $swStatus.Text = Get-UIString "sw_none_sel"; return }
        $count = 0
        foreach ($entry in $sel) {
            $item = $entry.Item
            if (-not (Test-Path $item.ApprovedPath)) {
                New-Item -Path $item.ApprovedPath -Force | Out-Null
            }
            $enableBytes = [byte[]](2,0,0,0,0,0,0,0,0,0,0,0)
            Set-ItemProperty -Path $item.ApprovedPath -Name $item.Name -Value $enableBytes -Type Binary -ErrorAction SilentlyContinue
            $entry.StatusTb.Text       = Get-UIString "word_enabled"
            $entry.StatusTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,100))
            $entry.Cb.IsChecked        = $false
            $count++
            Write-Log "Startup Manager: Enabled '$($item.Name)'"
        }
        $swStatus.Text = "$count " + (Get-UIString "sw_enabled_msg")
    })

    $swRefresh.Add_Click({ Build-StartupRows })
    $swClose.Add_Click({  $sw.Close() })

    $sw.ShowDialog() | Out-Null
})

# =============================================================================
# SERVICES MANAGER
# =============================================================================
$BtnServices.Add_Click({

    # Curated list: Name -> @{ Desc; Safe; Category }
    $KnownServices = @{
        "DiagTrack"              = @{ Desc="Telemetry & Diagnostics -- sendet Nutzungsdaten an Microsoft";        Safe=$true;  Cat="Privacy" }
        "dmwappushservice"       = @{ Desc="WAP Push Message Routing -- Teil der Telemetrie-Infrastruktur";     Safe=$true;  Cat="Privacy" }
        "SysMain"                = @{ Desc="Superfetch -- Praelaed Apps in RAM. Unnoetig bei SSDs.";            Safe=$true;  Cat="Performance" }
        "WSearch"                = @{ Desc="Windows Search -- Indexiert Festplatte. Hohe CPU/Disk-Last.";       Safe=$true;  Cat="Performance" }
        "RemoteRegistry"         = @{ Desc="Remote Registry -- Erlaubt Fernzugriff auf Registry. Sicherheitsrisiko."; Safe=$true;  Cat="Security" }
        "Fax"                    = @{ Desc="Fax-Dienst -- Wird von fast niemandem gebraucht.";                 Safe=$true;  Cat="Bloat" }
        "MapsBroker"             = @{ Desc="Maps Broker -- Fuer Windows Maps App. Kaum genutzt.";             Safe=$true;  Cat="Bloat" }
        "RetailDemo"             = @{ Desc="Retail Demo Service -- Nur fuer Store-Demogeraete.";              Safe=$true;  Cat="Bloat" }
        "WerSvc"                 = @{ Desc="Windows Error Reporting -- Sendet Absturzberichte an Microsoft."; Safe=$true;  Cat="Privacy" }
        "XblGameSave"            = @{ Desc="Xbox Game Save -- Cloud-Saves fuer Xbox. Unnoetig ohne Xbox.";    Safe=$true;  Cat="Bloat" }
        "XblAuthManager"         = @{ Desc="Xbox Live Auth -- Authentifizierung fuer Xbox. Unnoetig.";        Safe=$true;  Cat="Bloat" }
        "XboxNetApiSvc"          = @{ Desc="Xbox Live Networking -- Xbox Netzwerkdienst.";                    Safe=$true;  Cat="Bloat" }
        "xbgm"                   = @{ Desc="Xbox Game Monitoring -- Ueberwacht Xbox-Spiele.";                 Safe=$true;  Cat="Bloat" }
        "Spooler"                = @{ Desc="Print Spooler -- Nur benoetigt wenn Drucker angeschlossen.";      Safe=$false; Cat="System" }
        "BITS"                   = @{ Desc="Background Intelligent Transfer -- Windows Update Downloader.";   Safe=$false; Cat="System" }
        "wuauserv"               = @{ Desc="Windows Update -- Automatische Updates. Vorsicht beim Deaktivieren!"; Safe=$false; Cat="System" }
        "TabletInputService"     = @{ Desc="Touch Keyboard & Handwriting -- Nur fuer Touchscreens/Tablets."; Safe=$true;  Cat="Performance" }
        "WMPNetworkSvc"          = @{ Desc="Windows Media Player Network -- Medienfreigabe im Netzwerk.";    Safe=$true;  Cat="Bloat" }
        "lfsvc"                  = @{ Desc="Geolocation Service -- Standortabfragen durch Apps.";            Safe=$true;  Cat="Privacy" }
        "SharedAccess"           = @{ Desc="Internet Connection Sharing -- Nur fuer ICS/Hotspot benoetigt."; Safe=$true;  Cat="Network" }
        "PhoneSvc"               = @{ Desc="Phone Service -- Telefonie-Features. Selten benoetigt.";         Safe=$true;  Cat="Bloat" }
        "wisvc"                  = @{ Desc="Windows Insider Service -- Nur fuer Insider-Builds.";            Safe=$true;  Cat="Bloat" }
        "WpcMonSvc"              = @{ Desc="Parental Controls -- Jugendschutz-Monitoring.";                  Safe=$true;  Cat="Bloat" }
        "CscService"             = @{ Desc="Offline Files -- Cached Offline-Zugriff. Meist unnoetig.";       Safe=$true;  Cat="Performance" }
        "TrkWks"                 = @{ Desc="Distributed Link Tracking -- Verfolgt verschobene Dateien.";     Safe=$true;  Cat="Performance" }
        "WdiServiceHost"         = @{ Desc="Diagnostic Service Host -- Windows Diagnose-Tools.";             Safe=$true;  Cat="Bloat" }
        "icssvc"                 = @{ Desc="Windows Mobile Hotspot -- Mobiler Hotspot. Meist unnoetig.";     Safe=$true;  Cat="Bloat" }
        "vmicvss"                = @{ Desc="Hyper-V VSS -- Nur fuer Hyper-V VMs.";                          Safe=$true;  Cat="Bloat" }
        "HvHost"                 = @{ Desc="Hyper-V Host -- Nur fuer Hyper-V VMs.";                          Safe=$true;  Cat="Bloat" }
    }

    # Build XAML sub-window
    [xml]$svcXml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GameOptimizerPro  --  Services Manager"
        Height="600" Width="980"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Name="SvcTitle" Text="Services Manager" FontSize="18" FontWeight="Bold" Foreground="#e94560"/>
            <TextBlock Name="SvcSubtitle" Text="Deaktiviere unnoetige Windows-Dienste fuer bessere Performance und Datenschutz."
                       FontSize="11" Foreground="#888" Margin="0,2,0,0"/>
        </StackPanel>

        <!-- Legend -->
        <WrapPanel Grid.Row="1" Margin="0,0,0,10">
            <Border Background="#1e2e1e" CornerRadius="4" Padding="8,4" Margin="0,0,6,0">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#00c853" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegSafe" Text="Sicher deaktivierbar" FontSize="11" Foreground="#aaa" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
            <Border Background="#2e1e1e" CornerRadius="4" Padding="8,4" Margin="0,0,6,0">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#e94560" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegCaution" Text="Vorsicht -- Systemdienst" FontSize="11" Foreground="#aaa" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
            <Border Background="#1e1e2e" CornerRadius="4" Padding="8,4">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#555" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegDone" Text="Bereits deaktiviert" FontSize="11" Foreground="#aaa" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
        </WrapPanel>

        <!-- Column headers -->
        <Border Grid.Row="2" Background="#16213e" CornerRadius="6" Padding="8,6" Margin="0,0,0,4">
            <StackPanel Orientation="Horizontal">
                <TextBlock Name="SvcColSel" Text="Sel"         Foreground="#888" FontSize="11" Width="34"/>
                <TextBlock Name="SvcColName" Text="Service Name" Foreground="#888" FontSize="11" FontWeight="Bold" Width="160"/>
                <TextBlock Name="SvcColDesc" Text="Beschreibung" Foreground="#888" FontSize="11" FontWeight="Bold" Width="310"/>
                <TextBlock Name="SvcColStatus" Text="Status"      Foreground="#888" FontSize="11" FontWeight="Bold" Width="85"/>
                <TextBlock Name="SvcColStart" Text="Starttyp"    Foreground="#888" FontSize="11" FontWeight="Bold" Width="95"/>
                <TextBlock Name="SvcColCat" Text="Kategorie"   Foreground="#888" FontSize="11" FontWeight="Bold" Width="90"/>
                <TextBlock Name="SvcColSafe" Text="Sicher"      Foreground="#888" FontSize="11" FontWeight="Bold" Width="60"/>
            </StackPanel>
        </Border>

        <!-- Service list -->
        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="SvcList"/>
        </ScrollViewer>

        <!-- Status bar -->
        <TextBlock Grid.Row="4" Name="SvcStatus" Text="" Foreground="#aaaaaa"
                   FontSize="11" FontFamily="Consolas" Margin="0,8,0,4"/>

        <!-- Buttons -->
        <WrapPanel Grid.Row="5" HorizontalAlignment="Center">
            <Button Name="SvcBtnDisable" Content="Disable Selected"  Width="155" Height="32"
                    Margin="6,0" Background="#e94560" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnEnable"  Content="Enable Selected"   Width="155" Height="32"
                    Margin="6,0" Background="#1a7a3c" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnRefresh" Content="Refresh"           Width="100" Height="32"
                    Margin="6,0" Background="#0f3460" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnClose"   Content="Close"             Width="100" Height="32"
                    Margin="6,0" Background="#444"    Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </WrapPanel>
    </Grid>
</Window>
"@

    $svcReader  = New-Object System.Xml.XmlNodeReader $svcXml
    $svcWin     = [Windows.Markup.XamlReader]::Load($svcReader)
    $svcList    = $svcWin.FindName("SvcList")
    $svcStatus  = $svcWin.FindName("SvcStatus")
    $svcDisable = $svcWin.FindName("SvcBtnDisable")
    $svcEnable  = $svcWin.FindName("SvcBtnEnable")
    $svcRefresh = $svcWin.FindName("SvcBtnRefresh")
    $svcClose   = $svcWin.FindName("SvcBtnClose")

    # --- Localize Services Manager labels to current language ---
    $svcWin.Title = "GameOptimizerPro  --  " + (Get-UIString "svc_title")
    ($svcWin.FindName("SvcTitle")).Text      = Get-UIString "svc_title"
    ($svcWin.FindName("SvcSubtitle")).Text   = Get-UIString "svc_subtitle"
    ($svcWin.FindName("SvcLegSafe")).Text    = Get-UIString "svc_legend_safe"
    ($svcWin.FindName("SvcLegCaution")).Text = Get-UIString "svc_legend_caution"
    ($svcWin.FindName("SvcLegDone")).Text    = Get-UIString "svc_legend_done"
    ($svcWin.FindName("SvcColSel")).Text     = Get-UIString "svc_col_sel"
    ($svcWin.FindName("SvcColName")).Text    = Get-UIString "svc_col_name"
    ($svcWin.FindName("SvcColDesc")).Text    = Get-UIString "svc_col_desc"
    ($svcWin.FindName("SvcColStatus")).Text  = Get-UIString "svc_col_status"
    ($svcWin.FindName("SvcColStart")).Text   = Get-UIString "svc_col_starttype"
    ($svcWin.FindName("SvcColCat")).Text     = Get-UIString "svc_col_category"
    ($svcWin.FindName("SvcColSafe")).Text    = Get-UIString "svc_col_safe"
    $svcDisable.Content = Get-UIString "svc_btn_disable"
    $svcEnable.Content  = Get-UIString "svc_btn_enable"
    $svcRefresh.Content = Get-UIString "svc_btn_refresh"
    $svcClose.Content   = Get-UIString "svc_btn_close"
    $svcCbMap   = @{}   # serviceName -> @{ Cb; Safe }

    function Build-ServiceRows {
        $svcList.Children.Clear()
        $svcCbMap.Clear()
        $count = 0

        # Get all known services that exist on this system
        foreach ($svcName in ($KnownServices.Keys | Sort-Object)) {
            $info = $KnownServices[$svcName]
            try {
                $svc = Get-Service -Name $svcName -ErrorAction Stop
            } catch { continue }
            $count++

            $startType = try {
                (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName" -ErrorAction Stop).Start
            } catch { 3 }
            $startLabel = switch ($startType) { 2{Get-UIString "word_automatic"} 3{Get-UIString "word_manual"} 4{Get-UIString "word_disabled"} default{Get-UIString "word_unknown"} }
            $isDisabled = ($startType -eq 4)
            $isRunning  = ($svc.Status -eq "Running")

            # Row
            $row = New-Object Windows.Controls.StackPanel
            $row.Orientation = "Horizontal"
            $row.Margin      = New-Object Windows.Thickness(0,2,0,2)

            # Checkbox
            $cb       = New-Object Windows.Controls.CheckBox
            $cb.Width = 34
            $cb.VerticalAlignment = "Center"
            $cb.IsEnabled = $true

            # Safety dot
            $dot      = New-Object Windows.Shapes.Ellipse
            $dot.Width  = 8
            $dot.Height = 8
            $dot.VerticalAlignment = "Center"
            $dot.Margin = New-Object Windows.Thickness(0,0,6,0)
            if ($isDisabled) {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(85,85,85))
                $dot.ToolTip = Get-UIString "svc_legend_done"
            } elseif ($info.Safe) {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
                $dot.ToolTip = Get-UIString "svc_legend_safe"
            } else {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
                $dot.ToolTip = Get-UIString "svc_legend_caution"
            }

            # Name
            $tbName = New-Object Windows.Controls.TextBlock
            $tbName.Text  = $svc.DisplayName
            $tbName.Width = 160
            $tbName.FontSize = 12
            $tbName.Foreground = if ($isDisabled) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(90,90,90))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,220,220))
            }
            $tbName.VerticalAlignment = "Center"
            $tbName.ToolTip = "Service name: $svcName"
            $tbName.TextTrimming = "CharacterEllipsis"

            # Description
            $tbDesc = New-Object Windows.Controls.TextBlock
            $tbDesc.Text  = $info.Desc
            $tbDesc.Width = 310
            $tbDesc.FontSize = 11
            $tbDesc.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,150,150))
            $tbDesc.VerticalAlignment = "Center"
            $tbDesc.TextTrimming = "CharacterEllipsis"
            $tbDesc.ToolTip = $info.Desc

            # Status
            $tbStatus = New-Object Windows.Controls.TextBlock
            $tbStatus.Text  = if ($isRunning) { Get-UIString "word_running" } else { Get-UIString "word_stopped" }
            $tbStatus.Width = 85
            $tbStatus.FontSize = 11
            $tbStatus.FontWeight = "SemiBold"
            $tbStatus.VerticalAlignment = "Center"
            $tbStatus.Foreground = if ($isRunning) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130))
            }

            # Start type
            $tbStart = New-Object Windows.Controls.TextBlock
            $tbStart.Text  = $startLabel
            $tbStart.Width = 95
            $tbStart.FontSize = 11
            $tbStart.VerticalAlignment = "Center"
            $tbStart.Foreground = if ($isDisabled) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            }

            # Category
            $tbCat = New-Object Windows.Controls.TextBlock
            $tbCat.Text  = $info.Cat
            $tbCat.Width = 90
            $tbCat.FontSize = 10
            $tbCat.VerticalAlignment = "Center"
            $tbCat.Foreground = switch ($info.Cat) {
                "Privacy"     { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170)) }
                "Performance" { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,160,0)) }
                "Security"    { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96)) }
                "Bloat"       { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,100,200)) }
                default       { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130)) }
            }

            # Safe label
            $tbSafe = New-Object Windows.Controls.TextBlock
            $tbSafe.Text  = if ($info.Safe) { "Ja" } else { "Nein" }
            $tbSafe.Width = 60
            $tbSafe.FontSize = 11
            $tbSafe.FontWeight = "SemiBold"
            $tbSafe.VerticalAlignment = "Center"
            $tbSafe.Foreground = if ($info.Safe) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
            }

            $row.Children.Add($cb)       | Out-Null
            $row.Children.Add($dot)      | Out-Null
            $row.Children.Add($tbName)   | Out-Null
            $row.Children.Add($tbDesc)   | Out-Null
            $row.Children.Add($tbStatus) | Out-Null
            $row.Children.Add($tbStart)  | Out-Null
            $row.Children.Add($tbCat)    | Out-Null
            $row.Children.Add($tbSafe)   | Out-Null
            $svcList.Children.Add($row)  | Out-Null

            $svcCbMap[$svcName] = @{ Cb = $cb; Safe = $info.Safe; StatusTb = $tbStatus; StartTb = $tbStart }
        }
        $svcStatus.Text = "$count " + (Get-UIString "svc_found")
    }

    Build-ServiceRows

    $svcDisable.Add_Click({
        $sel = $svcCbMap.GetEnumerator() | Where-Object { $_.Value.Cb.IsChecked -eq $true }
        if (-not $sel) { $svcStatus.Text = Get-UIString "svc_none_sel"; return }
        $count = 0
        foreach ($entry in $sel) {
            $name = $entry.Key
            try {
                Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $name -StartupType Disabled -ErrorAction Stop
                $entry.Value.StatusTb.Text       = Get-UIString "word_stopped"
                $entry.Value.StatusTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130))
                $entry.Value.StartTb.Text        = Get-UIString "word_disabled"
                $entry.Value.StartTb.Foreground  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
                $entry.Value.Cb.IsChecked        = $false
                Write-Log "Services Manager: Disabled '$name'"
                $count++
            } catch {
                Write-Log "Services Manager: Failed to disable '$name' -- $_"
            }
        }
        $svcStatus.Text = "$count " + (Get-UIString "svc_disabled_msg")
    })

    $svcEnable.Add_Click({
        $sel = $svcCbMap.GetEnumerator() | Where-Object { $_.Value.Cb.IsChecked -eq $true }
        if (-not $sel) { $svcStatus.Text = Get-UIString "svc_none_sel"; return }
        $count = 0
        foreach ($entry in $sel) {
            $name = $entry.Key
            try {
                Set-Service -Name $name -StartupType Manual -ErrorAction Stop
                $entry.Value.StartTb.Text        = Get-UIString "word_manual"
                $entry.Value.StartTb.Foreground  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
                $entry.Value.Cb.IsChecked        = $false
                Write-Log "Services Manager: Enabled '$name' (set to Manual)"
                $count++
            } catch {
                Write-Log "Services Manager: Failed to enable '$name' -- $_"
            }
        }
        $svcStatus.Text = "$count " + (Get-UIString "svc_enabled_msg")
    })

    $svcRefresh.Add_Click({ Build-ServiceRows })
    $svcClose.Add_Click({  $svcWin.Close() })

    $svcWin.ShowDialog() | Out-Null
})


# -----------------------------------------
# LAUNCH
# -----------------------------------------
# Apply the default language (EN) to all static UI elements before showing.
$BtnLang.Content    = "[EN/DE]"
$BtnLang.Background  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(15,90,150))
Apply-Language
$StatusText.Text    = Get-UIString "status_ready"

Write-Log "GameOptimizerPro v1.1 started | $HWInfo"
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Alles OK  --  ShowDialog wird aufgerufen" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Alles OK  --  ShowDialog wird aufgerufen" -ForegroundColor DarkGray

# Console was already hidden at startup (where the host allows it).

$Window.ShowDialog() | Out-Null

# -----------------------------------------
# GUI CLOSED (clean exit)  --  terminate this PowerShell process so no
# console window (visible or hidden) is left behind. Works on both classic
# conhost and Windows Terminal: when the hosted process ends, the host
# closes the window/tab itself.
# Note: this only runs on a clean close. If the script crashes, the catch
# block below keeps the process alive so the error MessageBox can be read.
# -----------------------------------------
Write-Log "GameOptimizerPro v1.1 closed by user"
Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue

} catch {
    $errMsg  = $_.Exception.Message
    $errLine = $_.InvocationInfo.ScriptLineNumber
    $errFull = "STARTUP ERROR Zeile $errLine : $errMsg"
    Write-Host $errFull -ForegroundColor Red
    foreach ($p in $logPaths) {
        try { "[$(Get-Date -f 'HH:mm:ss')] $errFull" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { }
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "$errFull`n`nLog-Dateien:`n$($logPaths -join "`n")",
            "GameOptimizerPro - Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } catch {
        Write-Host "MessageBox fehlgeschlagen: $_" -ForegroundColor Red
        Read-Host "Fehler oben  --  Enter zum Beenden"
    }
}
