# ⚡ GameOptimizerPro v1.2.1

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.2.1-red)

🇬🇧 **English** | 🇩🇪 [Deutsch](README.de.md)

---

## 🚀 Quick Start (One-Liner)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

---



## 📸 Visual Preview

### GUI Overview
The tool offers a modern, user-friendly interface with:
- 🎨 **Dark-Mode UI** — Modern WPF/XAML interface
- 🖱️ **Intuitive Navigation** — 7 tabs for all functions
- ℹ️ **Info Buttons** — Detailed explanations for every tweak
- 📊 **System Info** — GPU, CPU, RAM status in real time
- 🔧 **BIOS Guide** — Hardware-detected optimization recommendations

---

## ✨ Features

| Tab | Features | Description |
|-----|----------|-------------|
| 🪟 Windows | 22 Tweaks | Debloat, privacy, Win11 tweaks, performance tweaks + **7 new CTT Essentials** |
| 🌐 Network | 10 Tweaks | Nagle, LSO, DNS, TCP tuning, QoS, adapter power saving, delivery optimization + async ping test (latency, packet loss, jitter to gateway/1.1.1.1/8.8.8.8) |
| 🔊 Audio | 6 Tweaks | Audio tweaks, dedicated tab |
| 🎮 GPU Tweaks | 7 Tweaks | 4 NVIDIA + 3 AMD tweaks, GPU detection, brand grey-out |
| ⚡ Power Plan | 7 Tweaks | USB, PCI-E, HDD, display, sleep, CPU min/max |
| 🚀 Startup Manager | ✅ | Own window, HKCU/HKLM/Run32, disable/enable/refresh |
| 🔧 **[BIOS] BIOS Guide** | ✅ **NEW** | Hardware-specific BIOS recommendations with menu paths |
| 📊 **[DASH] Dashboard** | ✅ **NEW** | Live system status, snapshot & before/after comparison |
| 🌍 Language DE/EN | ✅ | 80+ EN descriptions, toggle button, switches live |

---

## 🪟 Windows Tab - 22 Tweaks

### 🧹 Debloat & System Cleanup
- **Remove Cortana** — Completely removes Windows' voice assistant
- **Remove Xbox Apps** — Disables Xbox and gaming-related apps
- **Remove Microsoft Teams (Personal)** — Removes the personal Teams installation
- **Remove Copilot** — Disables Windows Copilot
- **Remove OneDrive** — Removes the OneDrive integration
- **Remove Windows Recall** — Disables the Windows Recall feature
- **Remove Other Bloatware** — Removes additional pre-installed bloatware

### 🔐 Privacy Settings
- **Disable Telemetry & Data Collection** — Disables data collection
- **Disable Activity History** — Disables activity history storage

### 📦 Windows 11 & 10 Optimization
- **OS Scan** — Scans the operating system for optimization potential
- **Win11 Tweaks** — Specialized optimizations for Windows 11
- **Win10 Grey-out + Banner** — Optimized display for Windows 10 compatibility

### ⚡ Performance Tweaks (v1.1+)
- **Disable Power Throttling** — Prevents Windows from throttling gaming processes via EcoQoS
- **Disable Bing in Windows Search** — Start menu searches only locally, no data exchange with Microsoft
- **Process Count Reduction (Svchost)** — Fewer background processes via an increased split threshold

### 🎯 CTT Essentials (NEW in v1.2.0)
Registry keys sourced **1:1 from Chris Titus Tech WinUtil** for guaranteed accuracy:
- **Prevent Device Companion Apps** — Blocks device metadata downloads + auto-suggested companion apps
- **Disable Consumer Features** — Stops auto-installed suggested apps/games in the Start menu
- **Disable Windows Platform Binary Table (WPBT)** — Blocks OEM firmware from injecting programs at boot (Security hardening)
- **Disable Store Recommended Search Results** — Removes sponsored results in the Microsoft Store
- **Enable Start Menu Previous Layout** — Classic Start layout on supported Win11 builds
- **Disable File Explorer Automatic Folder Discovery** — Opens large folders faster
- **Run Disk Cleanup** — Automated cleanmgr + DISM component cleanup

**All 7 tweaks include:** Full Apply/Revert functionality + Status checks + EN/DE descriptions

---

## 🔊 Audio Tab - 6 Tweaks

### 🎵 Audio Optimizations
- **6 Audio Tweaks** — Professional audio optimizations in their own tab
- Improved latency and playback quality
- Dedicated window for audio settings

---

## 🎮 GPU Tweaks Tab - 7 Tweaks

### NVIDIA Optimizations (4 Tweaks)
- **NVIDIA GPU Detection** — Automatic GPU detection
- **NVIDIA-Specific Tweaks** — 4 optimizations for NVIDIA graphics cards

### AMD Optimizations (3 Tweaks)
- **AMD-Specific Tweaks** — 3 optimizations for AMD graphics cards
- **Automatic GPU Detection** — Greys out incompatible tweaks

### Additional GPU Features
- **Brand Grey-out** — Only compatible GPU tweaks are shown

---

## ⚡ Power Plan Tab - 7 Tweaks

### 🔋 System Power Optimizations
- **USB Power Management** — Optimizes USB power management
- **PCI-E Optimizations** — Reduces PCIe latency
- **HDD/SSD Tweaks** — Disk power management
- **Display Power Tweaks** — Monitor power saving
- **Sleep Mode Optimizations** — Improved sleep behavior
- **CPU Min/Max Settings** — CPU frequency management
- **Comprehensive Power Plan Configuration** — 7 dedicated tweaks

---

## 🚀 Startup Manager

### 🖥️ Manage Startup Programs
- **Own Window** — Dedicated UI for startup management
- **Registry Integration** — HKCU/HKLM/Run32 entries
- **3-State Management** — Disable/enable/refresh functionality
- **Quick Control** — Start/stop auto-start programs

---

## 🔧 [BIOS] BIOS Guide Tab - NEW in v1.1

### 🎯 Hardware-Specific BIOS Recommendations
- **Automatic Hardware Detection** — Detects CPU, motherboard, and GPU
- **Concrete Menu Paths** — Exact BIOS navigation with detailed descriptions
- **Safety Rating** — Every recommendation comes with a risk badge (Safe / Moderate)
- **3 Predefined Profiles:**
  - **Zen 5/4 (AM5)** — Ryzen 7000/9000 series with Gigabyte/ASUS/MSI
  - **Intel 13th/14th Gen** — i9-13900/14900 with corresponding boards
  - **Zen 3 (AM4)** — Ryzen 5000 series for older AM4 systems

### 📋 Example Recommendations for Ryzen 7 9800X3D + Gigabyte X870 + RTX 4080:
- **Enable EXPO Profile 1** — Without it, RAM runs at 4800 MHz instead of its rated speed (Safe)
- **PBO set to Auto** — Optimizes Precision Boost Overdrive (Safe)
- **Enable Resizable BAR** — Better GPU/CPU communication (Safe)
- **FCLK/UCLK Ratio for X3D CPUs** — Optimal memory timing (Moderate)
- **Curve Optimizer for Extra Performance** — CPU undervolting possible (Moderate)

### 📖 Read-Only Guide
- No automatic changes — informational only
- User must make BIOS changes manually
- Ideal as a checklist before tuning

---

## 🌍 Language Toggle - DE/EN

### 🗣️ Multilingual Support
- **80+ English Descriptions** — Full EN localization
- **Toggle Button** — Quick switch between German and English
- **Switches Live** — No restart required
- **All Tweaks Translated** — Consistent multilingual UI

---

## 📋 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+**
- **Run as Administrator** (required!)
- **Internet Connection** — For download (first launch only)

---

## ✅ Compatibility

### Tested Windows Versions
- ✅ **Windows 11 21H2+** — Fully tested
- ✅ **Windows 11 22H2+** — Fully tested
- ✅ **Windows 10 20H2** — Fully compatible
- ✅ **Windows 10 21H2** — Fully compatible

### GPU Compatibility
- ✅ **NVIDIA** — GeForce RTX series (all modern GPUs)
- ✅ **AMD** — Radeon RX series (all modern GPUs)
- ⚠️ **Intel Arc** — Limited support (uses AMD tweaks)

### CPU Compatibility (BIOS Guide)
- ✅ **AMD Zen 5** — Ryzen 7000X3D / 9000 series (Threadripper)
- ✅ **AMD Zen 4** — Ryzen 5000X3D / 7000 series
- ✅ **Intel 13th/14th Gen** — Core i9-13900/14900, i7-13700/14700
- ✅ **AMD Zen 3** — Ryzen 5000 series (AM4)
- ⚠️ **Other CPUs** — BIOS Guide shows generic recommendations

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Automatically created before any tweaks are applied  
✅ **Registry Backup** — Before every Apply/Revert, all affected registry keys are additionally exported as `.reg` files to `%TEMP%\GameOptimizerPro_Backups\` (independent of the System Restore Point limit)  
✅ **Detailed Logging** — All actions are logged to `%TEMP%\GameOptimizerPro_*.log`  
✅ **Hardware Detection** — GPU-specific tweaks are filtered automatically  
✅ **BIOS Guide Read-Only** — No automatic system changes from the BIOS tab  
✅ **Fully Reversible** — All tweaks can be undone via System Restore or the registry backup  
✅ **Checksum Verification** — `install.ps1` checks the download against the SHA256 hash published in [CHECKSUMS.txt](CHECKSUMS.txt) before running the script with Admin rights  
✅ **No Malware** — Open source, fully auditable

---

## 🎨 GUI Features

- **Modern Dark-Mode UI** — Built on WPF/XAML
- **Info Buttons (?)** — Hover over `?` for explanations of every tweak
- **7 Tabs for Categories** — Windows | Audio | GPU Tweaks | Power Plan | Startup Manager | **[BIOS] BIOS Guide** | Language
- **Bulk Selection** — Select All / Deselect All buttons
- **Live Logging** — Log file can be opened at any time
- **Hardware Info** — Shows GPU, CPU, RAM
- **Language Toggle** — German/English switch
- **BIOS Recommendations** — Hardware-detected optimization suggestions

---


## 🆘 Troubleshooting

### Problem: "Execution of scripts is disabled"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: Script doesn't start
**Solution:**
- Make sure you have **Administrator rights**
- Try: `powershell -ExecutionPolicy Bypass -File GameOptimizerPro.ps1`

### Problem: GPU tweaks don't work
**Solution:**
- Make sure your GPU drivers are up to date
- A restart is required after GPU tweaks!
- Check the log file: `%TEMP%\GameOptimizerPro_*.log`

### Problem: BIOS Guide shows no recommendations
**Solution:**
- Make sure your CPU is supported
- BIOS recommendations require Admin rights for hardware detection
- Check the log file for detected hardware

### Problem: Tweaks weren't applied
**Solution:**
- A restart is required for many tweaks
- Check whether you actually enabled the tweaks
- Check the log file for error details

### Problem: System runs slower after tweaks
**Solution:**
- Use System Restore to undo all changes
- Start with fewer tweaks and test incrementally

---

## 📜 Changelog

### v1.2.1 ⭐ **CURRENT**
- 📶 **Enhanced Ping Test** in the Network tab — now measures **average latency, packet loss % and jitter** across **3 targets** (gateway, Cloudflare 1.1.1.1, Google 8.8.8.8), 10 pings each. Shows whether the network tweaks actually help.
- ⚡ Runs on a background runspace so the UI stays fully responsive during the ~30s test (no freeze), with locale-independent number formatting.

### v1.2.0
- 🧰 **7 new "CTT Essentials" tweaks** in the Windows tab (parity with Chris Titus Tech WinUtil), each with full Apply/Revert/Status-Check:
  - **Prevent Device Companion Apps** — blocks device metadata downloads + auto-suggested companion apps
  - **Disable Consumer Features** — stops auto-installed suggested apps/games in the Start menu
  - **Disable Windows Platform Binary Table (WPBT)** — blocks OEM firmware from injecting programs at boot
  - **Disable Store Recommended Search Results** — removes sponsored results in the Microsoft Store
  - **Enable Start Menu Previous Layout** — classic Start layout on supported Win11 builds
  - **Disable File Explorer Automatic Folder Discovery** — opens large folders faster
  - **Run Disk Cleanup** — automated cleanmgr + DISM component cleanup
- 📇 Registry keys sourced **1:1 from the upstream CTT WinUtil config** for accuracy
- 🪟 **Windows Tab: 15 → 22 Tweaks** (7 new CTT Essentials added)
- ✅ **92/92 Tweaks verified:** All have Apply + Revert + Status-Check (no gaps, no duplicates, no orphans)
- 🔒 **Sanity-Check:** No Check/Revert/Action collisions detected
- 🔐 Version 1.2.0 checksum updated in `install.ps1` + `CHECKSUMS.txt`
- 🔗 End-to-End integrity chain intact: Live-Raw-Hash = Installer-Pin (B7406760…2FEA)

### v1.1.1
- 🐛 **Bugfix:** 3 tweaks (Power Throttling, Bing Search, Svchost Reduction) were silently undone automatically on every program start due to a copy-paste error — fixed
- 🌍 **Bugfix (Localization):** On non-English Windows (e.g. German), the status check for "Disable TCP Auto-Tuning" always returned "unknown" instead of the real status
- 🌍 **Bugfix (Localization):** "Revert All" could never find the "Balanced" power plan on German Windows and logged the revert as successful even though nothing happened
- 🛡️ **Startup Sanity Check** — Automatically detects if a status check is ever again accidentally identical to a revert action
- 💾 **Registry Backup** — Before every Apply/Revert, affected registry keys are additionally backed up as `.reg` files (independent of the System Restore Point limit)
- 🔒 **Checksum Verification** — `install.ps1` checks the download against `CHECKSUMS.txt`
- 🌐 **2 New Network Tweaks** — Disable Network Adapter Power Saving, Disable Delivery Optimization (P2P Updates)
- 📶 **Live Network Info + Ping Test** in the Network tab (adapter, gateway, DNS, ping to gateway/1.1.1.1)
- 📊 **New [DASH] Dashboard Tab** — Live system status (power plan, timer resolution, active tweaks) plus snapshot/comparison for before/after evaluation

### v1.1
- ✨ **3 new performance tweaks** in the Windows tab:
  - **Disable Power Throttling** — Prevents EcoQoS throttling during gaming
  - **Disable Bing in Windows Search** — Local search only, no data exchange
  - **Process Count Reduction (Svchost)** — Fewer background processes
- 🔧 **New [BIOS] BIOS Guide Tab** — Hardware-detected BIOS recommendations
  - Automatic CPU/motherboard/GPU detection
  - Concrete menu paths with detailed descriptions
  - Support for Zen 5/4 (AM5), Intel 13th/14th Gen, Zen 3 (AM4)
  - Safety rating (Safe / Moderate) for every recommendation
  - Read-only guide — no automatic changes
- 🎯 **Optimized Hardware Integration** — Better CPU/GPU detection

### v1.0
- 🚀 **Initial release** with an extensive feature list
- 🪟 **Windows Tab** — 12 tweaks for OS optimization, debloat & privacy
- 🔊 **Audio Tab** — 6 dedicated audio optimizations
- 🎮 **GPU Tweaks Tab** — 7 tweaks (4 NVIDIA + 3 AMD) with automatic GPU detection
- ⚡ **Power Plan Tab** — 7 tweaks for system power optimization
- 🚀 **Startup Manager** — Manage auto-start programs
- 🌍 **Language Support** — 80+ descriptions in EN, switches live
- 🌐 **Multilingual UI** — Full German and English support

---

## ⚠️ Disclaimer

**Use at your own risk.** Please review the script before running it.  
A System Restore Point is automatically created before any changes.  
The author is not liable for system damage caused by improper use.

---

## 💡 Tips for Maximum Performance

1. **Start with Safety** — Test a few tweaks first, then add more
2. **Enable Debloat** — Remove unnecessary pre-installed apps for a faster system
3. **Use Performance Tweaks** — Especially Power Throttling & Bing disable
4. **Enable GPU Tweaks** — Automatic detection of your GPU for the best results
5. **BIOS Guide Before Hardware Tuning** — Read the recommendations before making BIOS changes
6. **Optimize Power Plan** — Adjust the settings to your needs
7. **Audio Tweaks for Gaming** — Reduce audio latency
8. **Use Startup Manager** — Speed up boot time via startup optimization
9. **Keep NVIDIA/AMD Drivers Updated** — Matters more than most tweaks
10. **Restart After GPU Tweaks** — GPU optimizations need a reboot
11. **Check the Logs** — Review the log file for error details if something goes wrong
12. **Use System Restore** — All tweaks can be undone at any time

---

## 🤝 Contributing & Feedback

### Report Bugs
If you find a bug, please open an [Issue](https://github.com/FloDePin/GameOptimizerPro/issues)

### Feature Requests
Have an idea for a new feature? [Share it with us!](https://github.com/FloDePin/GameOptimizerPro/issues)

### Support
- 📧 Email: flodepin@googlemail.com
- 🐛 GitHub Issues: [Issues](https://github.com/FloDePin/GameOptimizerPro/issues)

---

## 📋 Planned Features for Future Versions

- 🎮 **Gaming Boost Profile** — Predefined optimization profiles for popular games
- 💾 **Disk Cleanup** — Automatic disk cleanup
- 🌙 **Auto-Scheduler** — Time-based optimizations

---

## 📄 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## 👨‍💻 About the Author

**FloDePin** — Windows & Gaming Enthusiast  
Passionate about system optimization and performance tuning

---

*Made with ❤️ by FloDePin*
