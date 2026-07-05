$ErrorActionPreference = "Stop"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/GameOptimizerPro.ps1"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

# SHA256 of the last known-good GameOptimizerPro.ps1 release. Bump this
# whenever GameOptimizerPro.ps1 changes (see CHECKSUMS.txt). This is an
# integrity check against corruption/tampering in transit -- it does not
# replace reading the source, but lets users verify what they're about
# to run with Admin rights without having to read all 3800 lines by hand.
$ExpectedHash = "D0AF863BB1E79B765504D431A3BB1CA1FA0E692FBCEAB1879FA73414E9566F73"

Write-Host ""
Write-Host "  GameOptimizerPro v1.1 Installer" -ForegroundColor Red
Write-Host "  ---------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading GameOptimizerPro v1.1..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Make sure you have internet access and the file exists on GitHub." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}

# --- INTEGRITY CHECK (SHA256) ---
$actualHash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash
Write-Host "  SHA256: $actualHash" -ForegroundColor DarkGray
if ($actualHash -ne $ExpectedHash) {
    Write-Host ""
    Write-Host "  [WARNING] Checksum mismatch!" -ForegroundColor Red
    Write-Host "  Expected: $ExpectedHash" -ForegroundColor Gray
    Write-Host "  Actual:   $actualHash" -ForegroundColor Gray
    Write-Host "  The downloaded file does not match the published checksum in CHECKSUMS.txt." -ForegroundColor Gray
    Write-Host "  This can mean the script was updated since this installer was published," -ForegroundColor Gray
    Write-Host "  or that the download was corrupted/tampered with." -ForegroundColor Gray
    Write-Host ""
    $proceed = Read-Host "  Type YES to run it anyway, or press Enter to abort"
    if ($proceed -ne "YES") {
        Write-Host "  Aborted." -ForegroundColor Yellow
        exit
    }
} else {
    Write-Host "  Checksum verified OK." -ForegroundColor Green
}

# Force UTF-8 re-encode so PowerShell reads it correctly
$raw = [System.IO.File]::ReadAllText($dest, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($dest, $raw, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  Encoding verified (UTF-8)." -ForegroundColor DarkGray

Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
Write-Host ""

# Check if already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$launched = $false

if ($isAdmin) {
    # Already admin -- launch the GUI in its own hidden PowerShell process.
    try {
        Start-Process powershell.exe -ArgumentList "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`"" -WindowStyle Hidden
        $launched = $true
    } catch {
        Write-Host "  [ERROR] Script launch failed: $_" -ForegroundColor Red
        Read-Host "  Press Enter to exit"
    }
} else {
    # Need elevation -- launch the GUI elevated and hidden.
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = "powershell.exe"
        $psi.Arguments       = "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`""
        $psi.Verb            = "runas"
        $psi.UseShellExecute = $true
        $psi.WindowStyle     = "Hidden"

        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $launched = $true
    } catch {
        Write-Host ""
        Write-Host "  [ERROR] Failed to launch as Administrator: $_" -ForegroundColor Red
        Write-Host "  Try running PowerShell as Administrator manually and execute:" -ForegroundColor Gray
        Write-Host "  powershell -ExecutionPolicy Bypass -File `"$dest`"" -ForegroundColor White
        Write-Host ""
        Read-Host "  Press Enter to exit"
    }
}

if ($launched) {
    # Close this PowerShell session so the terminal window disappears.
    # The GUI keeps running in its own hidden process.
    # NOTE: If you ran this via 'irm | iex' in a terminal you want to KEEP,
    # be aware the window will close -- this is intentional (clean launch).
    Write-Host "  GameOptimizerPro is starting. This window will close..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 800
    exit
}
