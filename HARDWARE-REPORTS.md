<div align="center">

# 📊 KL-06 Shareable Hardware Report

[![Telemetry Intake](https://img.shields.io/badge/Telemetry-Intake%20Guidelines-EA580C?style=for-the-badge&logo=intel&logoColor=white)](HARDWARE-REPORTS.md)
[![Privacy Sanitized](https://img.shields.io/badge/Privacy-Sanitized%20%2F%20Redacted-059669?style=for-the-badge&logo=lock&logoColor=white)](HARDWARE-REPORTS.md)
[![Shell Compatibility](https://img.shields.io/badge/Shell-Bash%203.2%2B%20Compatible-0284C7?style=for-the-badge&logo=gnubash&logoColor=white)](HARDWARE-REPORTS.md)
[![Privilege Safety](https://img.shields.io/badge/Safety-Zero%20Sudo%20Required-7C3AED?style=for-the-badge&logo=shield&logoColor=white)](HARDWARE-REPORTS.md)

<p align="center">
  <a href="README.md">🏠 Home</a> •
  <a href="CHANGELOG.md">📋 Changelog</a> •
  <a href="ARCHITECTURE.md">🛡️ Architecture</a> •
  <a href="COMPONENT-REPORT.md">🧪 Component Intake</a>
</p>

---

</div>

<br/>

## 🎯 Goal

Let another Hackintosh owner collect a **minimized text file** for review without installing KL-06, Xcode, Python, drivers or a management agent. Report collection does not change their machine or enable hardware controls.

<br/>

## 🔍 Finding the Collector Script

Attachments are not automatically placed on the Mac. Download the presented **KL-06-0.2.1-update-and-report.zip** and unzip it; **KL-06-Hardware-Report.command** is inside **KL-06-0.2.1** beside the app builders. Run it directly from there using the README command, or share/copy that script into the next owner's Downloads for the short command below. The hardware script does not require building the app. The ZIP also includes the complete paste alternative `KL-06-SHARE-COMMAND.txt`.

<br/>

## ⚙️ Bash 3.2 Compatibility Correction

The original generic collector shared the component collector's nested-heredoc loader problem. That failure was reproduced with GNU Bash 3.2.57 on Linux and the top-level literal loader in collector v1.1 fixes its syntax. Filter contents/privacy scope and report-format markers are unchanged. Current standalone exports include this correction; older app source ZIPs are snapshots and may contain the original collector. Replace that collector with the current export before distributing an app-only repository. A working native app does not establish that an older report script parses on the Mac.

<br/>

## 💻 One Short Command After Download

Share **KL-06-Hardware-Report.command**, and download it into Downloads. In a new Terminal window:

```bash
/bin/bash "$HOME/Downloads/KL-06-Hardware-Report.command"
```

Inspect the script before running. No sudo required. Allow roughly 1–2 minutes; missing/unsupported queries are not failures of the hardware. Ctrl-C is safe but leaves an incomplete report.

The output file is **REPORT.txt** inside a newly created `KL-06-Report.XXXXXX` folder on your Desktop (home folder fallback). It contains only projected/redacted output; no raw system report is saved. Review it, add your **physical motherboard/laptop model**, actual tested features and requested controls/bugs, then attach **REPORT.txt only**.

<br/>

## 📋 Self-Contained Paste Alternative

`KL-06-SHARE-COMMAND.txt` contains ONE complete Bash here-document command, starting with `/bin/bash <<'KL06_REPORT'` and ending with `KL06_REPORT`. You may copy that whole block into a new Terminal window. Do not copy only the middle, paste raw source into zsh, add sudo, or reuse a previously malformed/truncated script.

The script and paste block are byte-verified exports of `scripts/collect-kl06-hardware.sh` in the maintenance project. A fake or guessed download URL is not supplied. Once an actual repository/version is published, a short pinned download-and-verify command can be created from its real URL and digest.

<br/>

## 🛡️ Telemetry Collected vs. Redacted

### ✅ Safely Collected
- Actual OS product/build/Darwin and architecture; reported CPU, core counts, RAM, optional XCPM flag; public SMBIOS **model only**.
- Allowlisted GPU/display/Metal/HDR fields, without display names or serials.
- Selected loaded driver identifiers/versions for Intel/AMD graphics, CPU/SMC, audio, input, USB and wireless stacks; no kernel addresses, UUIDs or dependency dumps. This is not a full driver/binary/runtime inventory.
- Selected numerical, possibly injected PCI/codec/layout properties; not independent physical PCI evidence.
- Audio channel/sample-rate/default-route fields with route/device names omitted.
- Numerical battery capacities/cycles and constrained condition strings; no battery identity.
- Read-only power settings, aggregate assertions, VM page counts, Data filesystem totals/free space; no process/window/volume names.
- Coarse service counts, not a physical port map or proof a device works.

### 🚫 Strictly Redacted / Never Collected
- Account or host name.
- SMBIOS serials, MLB, ROM, UUID, MAC address, SSID/BSSID, IP addresses.
- Paired Bluetooth device names, passwords, tokens, API keys.
- Full EFI folder or `config.plist` contents.
- Boot arguments dump, recovery keys, or full raw console logs.

<br/>

## 🔬 What We Can & Cannot Infer

1. **Identify a candidate platform:** Current KL-06 build is x86_64 using macOS 13+ APIs. Intel and AMD are candidates only, not universally validated.
2. **Separate usable standard macOS APIs:** Distinguish actual standard APIs from missing sensors, drivers, or unimplemented controls.
3. **Narrowly scoped capabilities:** Add verified capabilities with provenance, driver requirements, and hardware safety.
4. **Cannot infer from a report:** Universal compatibility, stable GPU clocks or power, safe EC/fan/charge-limit methods, working HDR/DTS/system-wide microphone DSP, real USB wiring, or a passed app control/restore test.

<br/>

## 📝 Minimum Sanitized Return Template

```text
Attach: REPORT.txt (reviewed)
Physical motherboard/laptop model:
Intel/AMD CPU and physical GPU model, if known:
Working features actually tested:
Requested feature or exact reproducible bug:
AC/battery, external display, relevant conditions:
KL-06 version / native build result, if installed:
```
