# ⚡ GameOptimizerPro v1.2.1

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.2.1-red)

🇬🇧 [English](README.md) | 🇩🇪 **Deutsch**

---

## 🚀 Quick Start (One-Liner)

Öffne **PowerShell als Administrator** und führe aus:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro-v1.1/main/install.ps1 | iex
```

---



## 📸 Visual Preview

### GUI Übersicht
Das Tool bietet eine moderne, benutzerfreundliche Oberfläche mit:
- 🎨 **Dark-Mode UI** — Moderne WPF/XAML Oberfläche
- 🖱️ **Intuitive Navigation** — 7 Tabs für alle Funktionen
- ℹ️ **Info-Buttons** — Detaillierte Erklärungen für jeden Tweak
- 📊 **System Info** — GPU, CPU, RAM Status in Echtzeit
- 🔧 **BIOS Guide** — Hardware-erkannte Optimierungsempfehlungen

---

## ✨ Features

| Tab | Features | Description |
|-----|----------|-------------|
| 🪟 Windows | 22 Tweaks | Debloat, Datenschutz, Win11-Tweaks, Performance-Tweaks + CTT Essentials |
| 🌐 Network | 10 Tweaks | Nagle, LSO, DNS, TCP-Tuning, QoS, Adapter Power Saving, Delivery Optimization + asynchroner Ping-Test (Latenz, Paketverlust, Jitter zu Gateway/1.1.1.1/8.8.8.8) |
| 🔊 Audio | 6 Tweaks | Audio-Tweaks, eigener Tab |
| 🎮 GPU Tweaks | 7 Tweaks | 4 NVIDIA + 3 AMD Tweaks, GPU-Erkennung, Brand-Grauausblendung |
| ⚡ Power Plan | 7 Tweaks | USB, PCI-E, HDD, Display, Sleep, CPU Min/Max |
| 🚀 Startup Manager | ✅ | Eigenes Fenster, HKCU/HKLM/Run32, Disable/Enable/Refresh |
| 🔧 **[BIOS] BIOS Guide** | ✅ **NEW** | Hardware-spezifische BIOS-Empfehlungen mit Menüpfaden |
| 📊 **[DASH] Dashboard** | ✅ **NEW** | Live-Systemstatus, Snapshot & Vorher/Nachher-Vergleich |
| 🌍 Language DE/EN | ✅ | 80+ EN-Beschreibungen, Toggle-Button, live umschaltbar |

---

## 🪟 Windows Tab - 15 Tweaks

### 🧹 Debloat & System Cleanup
- **Remove Cortana** — Entfernt den Windows Sprachassistenten
- **Remove Xbox Apps** — Deaktiviert Xbox und Gaming-bezogene Apps
- **Remove Microsoft Teams (Personal)** — Entfernt die persönliche Teams-Installation
- **Remove Copilot** — Deaktiviert Windows Copilot
- **Remove OneDrive** — Entfernt die OneDrive-Integration
- **Remove Windows Recall** — Deaktiviert Windows Recall Feature
- **Remove Other Bloatware** — Entfernt zusätzliche vorinstallierte Bloatware

### 🔐 Privacy-Einstellungen
- **Disable Telemetry & Data Collection** — Deaktiviert Datenerfassung
- **Disable Activity History** — Deaktiviert die Aktivitätsverlauf-Speicherung

### 📦 Windows 11 & 10 Optimization
- **OS-Scan** — Scannt das Betriebssystem auf Optimierungspotenziale
- **Win11 Tweaks** — Spezialisierte Optimierungen für Windows 11
- **Win10 Grauausblendung + Banner** — Optimierte Darstellung für Windows 10-Kompatibilität

### ⚡ Performance-Tweaks (NEW in v1.1)
- **Disable Power Throttling** — Verhindert, dass Windows Gaming-Prozesse per EcoQoS drosselt
- **Disable Bing in Windows Search** — Startmenü sucht nur noch lokal, kein Datenaustausch mit Microsoft
- **Process Count Reduction (Svchost)** — Weniger Hintergrundprozesse durch erhöhten Split-Threshold

---

## 🔊 Audio Tab - 6 Tweaks

### 🎵 Audio-Optimierungen
- **6 Audio-Tweaks** — Professionelle Audiooptimierungen in eigenem Tab
- Verbesserte Latenz und Wiedergabequalität
- Dediziertes Fenster für Audio-Einstellungen

---

## 🎮 GPU Tweaks Tab - 7 Tweaks

### NVIDIA Optimierungen (4 Tweaks)
- **NVIDIA GPU Detection** — Automatische Erkennung der GPU
- **NVIDIA-spezifische Tweaks** — 4 Optimierungen für NVIDIA-Grafikkarten

### AMD Optimierungen (3 Tweaks)
- **AMD-spezifische Tweaks** — 3 Optimierungen für AMD-Grafikkarten
- **Automatische GPU-Erkennung** — Greyt-out von nicht-kompatiblen Tweaks

### Weitere GPU-Features
- **Brand Grauausblendung** — Nur kompatible GPU-Tweaks werden angezeigt

---

## ⚡ Power Plan Tab - 7 Tweaks

### 🔋 Systemenergie-Optimierungen
- **USB Power Management** — USB-Energieverwaltung optimieren
- **PCI-E Optimierungen** — PCIe-Latenz reduzieren
- **HDD/SSD Tweaks** — Festplatte Energieverwaltung
- **Display Power Tweaks** — Monitor-Energiesparen
- **Sleep Mode Optimierungen** — Verbessertes Schlafverhalten
- **CPU Min/Max Einstellungen** — CPU-Frequenz-Management
- **Umfassende Power Plan Konfiguration** — 7 dedizierte Tweaks

---

## 🚀 Startup Manager

### 🖥️ Startup-Programme verwalten
- **Eigenes Fenster** — Dedizierte UI für Startup-Verwaltung
- **Registry-Integration** — HKCU/HKLM/Run32-Einträge
- **3-State-Management** — Disable/Enable/Refresh Funktionalität
- **Schnelle Kontrolle** — Starten/Stoppen von Auto-Start-Programmen

---

## 🔧 [BIOS] BIOS Guide Tab - NEW in v1.1

### 🎯 Hardware-spezifische BIOS-Empfehlungen
- **Automatische Hardware-Erkennung** — Erkennt CPU, Motherboard und GPU
- **Konkrete Menüpfade** — Genaue Navigation im BIOS mit deutschen Beschreibungen
- **Sicherheitsbewertung** — Jede Empfehlung mit Risiko-Badge (Sicher / Moderat)
- **3 vordefinierte Profile:**
  - **Zen 5/4 (AM5)** — Ryzen 7000/9000 Serie mit Gigabyte/ASUS/MSI
  - **Intel 13./14. Gen** — i9-13900/14900 mit entsprechenden Boards
  - **Zen 3 (AM4)** — Ryzen 5000 Serie für ältere AM4-Systeme

### 📋 Beispiel-Empfehlungen für Ryzen 7 9800X3D + Gigabyte X870 + RTX 4080:
- **EXPO Profil 1 aktivieren** — RAM läuft sonst auf 4800 MHz statt Nennwert (Sicher)
- **PBO auf Auto** — Precision Boost Overdrive optimieren (Sicher)
- **Resizable BAR aktivieren** — Bessere GPU/CPU-Kommunikation (Sicher)
- **FCLK/UCLK Ratio für X3D CPUs** — Optimale Memory-Timing (Moderat)
- **Curve Optimizer für Extra-Performance** — CPU-Undervolting möglich (Moderat)

### 📖 Read-Only Ratgeber
- Keine automatischen Änderungen — Nur informativ
- Benutzer muss BIOS-Änderungen manuell vornehmen
- Ideal als Checkliste vor dem Tuning

---

## 🌍 Language Toggle - DE/EN

### 🗣️ Mehrsprachigkeit
- **80+ englische Beschreibungen** — Vollständige EN-Lokalisierung
- **Toggle-Button** — Schneller Wechsel zwischen Deutsch und Englisch
- **Live-Umschaltbar** — Keine Neustart erforderlich
- **Alle Tweaks übersetzt** — Konsistente mehrsprachige UI

---

## 📋 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+**
- **Run as Administrator** (erforderlich!)
- **Internet Connection** — Für Download (nur beim ersten Start)

---

## ✅ Kompatibilität

### Getestete Windows Versionen
- ✅ **Windows 11 21H2+** — Vollständig getestet
- ✅ **Windows 11 22H2+** — Vollständig getestet
- ✅ **Windows 10 20H2** — Vollständig kompatibel
- ✅ **Windows 10 21H2** — Vollständig kompatibel

### GPU Kompatibilität
- ✅ **NVIDIA** — GeForce RTX Serie (alle modernen GPUs)
- ✅ **AMD** — Radeon RX Serie (alle modernen GPUs)
- ⚠️ **Intel Arc** — Begrenzte Unterstützung (nutzt AMD-Tweaks)

### CPU Kompatibilität (BIOS Guide)
- ✅ **AMD Zen 5** — Ryzen 7000X3D / 9000 Series (Threadripper)
- ✅ **AMD Zen 4** — Ryzen 5000X3D / 7000 Series
- ✅ **Intel 13./14. Gen** — Core i9-13900/14900, i7-13700/14700
- ✅ **AMD Zen 3** — Ryzen 5000 Series (AM4)
- ⚠️ **Andere CPUs** — BIOS Guide zeigt generische Empfehlungen

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Wird vor allen Tweaks automatisch erstellt  
✅ **Registry-Backup** — Vor jedem Apply/Revert werden alle betroffenen Registry-Keys zusätzlich als `.reg`-Dateien nach `%TEMP%\GameOptimizerPro_Backups\` exportiert (unabhängig vom System Restore Point, der Windows' 24h-Limit unterliegt)  
✅ **Detailliertes Logging** — Alle Aktionen werden in `%TEMP%\GameOptimizerPro_*.log` protokolliert  
✅ **Hardware Detection** — GPU-spezifische Tweaks werden automatisch gefiltert  
✅ **BIOS Guide Read-Only** — Keine automatischen Systemänderungen vom BIOS-Tab  
✅ **Vollständig reversibel** — Alle Tweaks können über System Restore oder das Registry-Backup rückgängig gemacht werden  
✅ **Checksum-Verifizierung** — `install.ps1` prüft den Download gegen den in [CHECKSUMS.txt](CHECKSUMS.txt) veröffentlichten SHA256-Hash, bevor das Skript mit Admin-Rechten läuft  
✅ **Keine Malware** — Open-Source, vollständig überprüfbar

---

## 🎨 GUI Features

- **Moderne Dark-Mode UI** — Basierend auf WPF/XAML
- **Info-Buttons (?)** — Hover über `?` für Erklärungen zu jedem Tweak
- **7 Tabs für Kategorien** — Windows | Audio | GPU Tweaks | Power Plan | Startup Manager | **[BIOS] BIOS Guide** | Language
- **Bulk Selektionen** — Select All / Deselect All Buttons
- **Live Logging** — Log-Datei kann jederzeit geöffnet werden
- **Hardware Info** — Zeigt GPU, CPU, RAM an
- **Language Toggle** — Deutsch/Englisch Umschaltung
- **BIOS-Empfehlungen** — Hardware-erkannte Optimierungsvorschläge

---


## 🆘 Troubleshooting

### Problem: "Execution of scripts is disabled"
**Lösung:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: Script startet nicht
**Lösung:**
- Stelle sicher, dass du **Administrator-Rechte** hast
- Versuche: `powershell -ExecutionPolicy Bypass -File GameOptimizerPro.ps1`

### Problem: GPU-Tweaks funktionieren nicht
**Lösung:**
- Stelle sicher, dass deine GPU-Treiber aktuell sind
- Neustarten nach GPU-Tweaks erforderlich!
- Überprüfe die Log-Datei: `%TEMP%\GameOptimizerPro_*.log`

### Problem: BIOS Guide zeigt keine Empfehlungen
**Lösung:**
- Stelle sicher, dass deine CPU unterstützt wird
- BIOS-Empfehlungen benötigen Admin-Rechte für Hardware-Erkennung
- Überprüfe die Log-Datei für erkannte Hardware

### Problem: Tweaks wurden nicht angewendet
**Lösung:**
- Neustarten erforderlich für viele Tweaks
- Überprüfe, ob du die Tweaks wirklich aktiviert hast
- Schaue in die Log-Datei für Fehlerdetails

### Problem: System läuft langsamer nach Tweaks
**Lösung:**
- Nutze System Restore um alle Änderungen rückgängig zu machen
- Starte mit weniger Tweaks und teste dann mehr

---

## 📜 Changelog

### v1.2.1 ⭐ **CURRENT**
- 📶 **Erweiterter Ping-Test** im Network-Tab — misst jetzt **durchschnittliche Latenz, Paketverlust % und Jitter** über **3 Ziele** (Gateway, Cloudflare 1.1.1.1, Google 8.8.8.8), je 10 Pings. Zeigt, ob die Network-Tweaks wirklich etwas bringen.
- ⚡ Läuft in einem Hintergrund-Runspace, damit die Oberfläche während des ~30s-Tests flüssig bleibt (kein Einfrieren), mit sprachunabhängiger Zahlenformatierung.

### v1.2.0
- 🧰 **7 neue „CTT Essentials"-Tweaks** im Windows-Tab (Parität zu Chris Titus Tech WinUtil), jeder mit Apply/Revert/Status-Check:
  - **Prevent Device Companion Apps** — blockiert Geräte-Metadaten-Downloads + automatisch vorgeschlagene Companion-Apps
  - **Disable Consumer Features** — stoppt automatisch installierte Vorschlags-Apps/Spiele im Startmenü
  - **Disable Windows Platform Binary Table (WPBT)** — verhindert, dass OEM-Firmware beim Boot Programme einschleust
  - **Disable Store Recommended Search Results** — entfernt gesponserte Ergebnisse im Microsoft Store
  - **Enable Start Menu Previous Layout** — klassisches Startmenü auf unterstützten Win11-Builds
  - **Disable File Explorer Automatic Folder Discovery** — öffnet große Ordner schneller
  - **Run Disk Cleanup** — automatisierte cleanmgr- + DISM-Komponentenbereinigung
- 📇 Registry-Keys 1:1 aus der originalen CTT-WinUtil-Config übernommen (Genauigkeit)

### v1.1.1
- 🐛 **Bugfix:** 3 Tweaks (Power Throttling, Bing-Suche, Svchost-Reduktion) wurden durch einen Copy-Paste-Fehler bei jedem Programmstart automatisch wieder rückgängig gemacht — behoben
- 🌍 **Bugfix (Sprache):** Auf nicht-englischem Windows (z.B. Deutsch) lieferte der Status-Check für "Disable TCP Auto-Tuning" immer "unbekannt" statt des echten Status (netsh-Textsuche war auf Englisch hartkodiert) — jetzt sprachunabhängig via `Get-NetTCPSetting`
- 🌍 **Bugfix (Sprache):** "Revert All" konnte den Energiesparplan "Balanced" auf deutschem Windows nie finden ("Ausbalanciert") und hat den Revert fälschlich als erfolgreich geloggt, obwohl nichts passiert ist — jetzt über die feste, sprachunabhängige Windows-GUID gelöst
- 🛡️ **Sanity-Check beim Start** — Erkennt automatisch, falls ein Status-Check jemals wieder mit einer Revert-Aktion verwechselt wird
- 💾 **Registry-Backup** — Vor jedem Apply/Revert werden betroffene Registry-Keys zusätzlich als `.reg`-Dateien gesichert (unabhängig vom System-Restore-Point-Limit)
- 🔒 **Checksum-Verifizierung** — `install.ps1` prüft den Download gegen `CHECKSUMS.txt`
- 🌐 **2 neue Network-Tweaks** — Disable Network Adapter Power Saving, Disable Delivery Optimization (P2P Updates)
- 📶 **Live Netzwerk-Info + Ping-Test** im Network-Tab (Adapter, Gateway, DNS, Ping zu Gateway/1.1.1.1)
- 📊 **Neuer [DASH] Dashboard Tab** — Live-Systemstatus (Power Plan, Timer-Auflösung, aktive Tweaks) sowie Snapshot/Vergleich für Vorher-Nachher-Auswertung

### v1.1
- ✨ **3 neue Performance-Tweaks** im Windows-Tab:
  - **Disable Power Throttling** — Verhindert EcoQoS-Drosselung bei Gaming
  - **Disable Bing in Windows Search** — Nur lokale Suche, kein Datenaustausch
  - **Process Count Reduction (Svchost)** — Weniger Hintergrundprozesse
- 🔧 **Neuer [BIOS] BIOS Guide Tab** — Hardware-erkannte BIOS-Empfehlungen
  - Automatische CPU/Motherboard/GPU-Erkennung
  - Konkrete Menüpfade mit deutschen Beschreibungen
  - Support für Zen 5/4 (AM5), Intel 13./14. Gen, Zen 3 (AM4)
  - Sicherheitsbewertung (Sicher / Moderat) für jede Empfehlung
  - Read-Only Ratgeber — keine automatischen Änderungen
- 🎯 **Optimierte Hardware-Integration** — Bessere CPU/GPU-Erkennung

### v1.0
- 🚀 **Initial release** mit umfangreicher Feature-Liste
- 🪟 **Windows Tab** — 12 Tweaks für OS-Optimierung, Debloat & Datenschutz
- 🔊 **Audio Tab** — 6 dedizierte Audio-Optimierungen
- 🎮 **GPU Tweaks Tab** — 7 Tweaks (4 NVIDIA + 3 AMD) mit automatischer GPU-Erkennung
- ⚡ **Power Plan Tab** — 7 Tweaks für Systemenergie-Optimierung
- 🚀 **Startup Manager** — Verwaltung von Auto-Start-Programmen
- 🌍 **Language Support** — 80+ Beschreibungen in EN, live umschaltbar
- 🌐 **Mehrsprachige UI** — Deutsch und Englisch voll unterstützt

---

## ⚠️ Disclaimer

**Use at your own risk.** Bitte überprüfe das Script vor der Ausführung.  
Ein System Restore Point wird automatisch vor Änderungen erstellt.  
Der Autor haftet nicht für Systemschäden durch unsachgemäße Verwendung.

---

## 💡 Tipps für maximale Performance

1. **Starte mit Safety** — Erst einige Tweaks testen, dann mehr hinzufügen
2. **Debloat aktivieren** — Entferne unnötige vorinstallierte Apps für schnelleres System
3. **Performance-Tweaks nutzen** — Besonders Power Throttling & Bing-Deaktivierung
4. **GPU-Tweaks aktivieren** — Automatische Erkennung deiner GPU für beste Ergebnisse
5. **BIOS Guide vor Hardware-Tuning** — Lese die Empfehlungen vor BIOS-Änderungen
6. **Power Plan optimieren** — Passe die Einstellungen nach deinen Bedürfnissen an
7. **Audio-Tweaks für Gaming** — Reduziere Audio-Latenz
8. **Startup Manager nutzen** — Beschleunige den Boot durch Startup-Optimierung
9. **NVIDIA/AMD Treiber aktuell halten** — Macht mehr aus als die meisten Tweaks
10. **Nach GPU Tweaks neustarten** — GPU-Optimierungen brauchen einen Reboot
11. **Logs überprüfen** — Bei Problemen die Log-Datei ansehen für Fehlerdetails
12. **System Restore nutzen** — Alle Tweaks können jederzeit rückgängig gemacht werden

---

## 🤝 Beitrag & Feedback

### Bugs melden
Falls du einen Bug findest, erstelle bitte einen [Issue](https://github.com/FloDePin/GameOptimizerPro-v1.1/issues)

### Feature-Wünsche
Hast du eine Idee für ein neues Feature? [Teile es mit uns!](https://github.com/FloDePin/GameOptimizerPro-v1.1/issues)

### Support
- 📧 E-Mail: flodepin@googlemail.com
- 🐛 GitHub Issues: [Issues](https://github.com/FloDePin/GameOptimizerPro-v1.1/issues)

---

## 📋 Geplante Features für zukünftige Versionen

- 🎮 **Gaming Boost Profile** — Vordefinierte Optimierungsprofile für beliebte Games
- 💾 **Disk Cleanup** — Automatische Speicherbereinigung
- 🌙 **Auto-Scheduler** — Zeitgesteuerte Optimierungen

---

## 📄 Lizenz

Dieses Projekt ist unter der **MIT License** lizenziert. Siehe [LICENSE](LICENSE) für Details.

---

## 👨‍💻 Über den Autor

**FloDePin** — Windows & Gaming Enthusiast  
Leidenschaft für System-Optimierung und Performance-Tuning

---

*Made with ❤️ by FloDePin*
