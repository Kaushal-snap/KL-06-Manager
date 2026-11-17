<div align="center">

# 🧪 KL-06 Component Audit Report

[![Component Audit](https://img.shields.io/badge/Component%20Audit-Evidence%20Intake-7C3AED?style=for-the-badge&logo=speedtest&logoColor=white)](COMPONENT-REPORT.md)
[![Diagnostics Safety](https://img.shields.io/badge/Diagnostics-Read--Only%20Sampling-2563EB?style=for-the-badge&logo=apple&logoColor=white)](COMPONENT-REPORT.md)
[![Parser Safety](https://img.shields.io/badge/Parser%20Fix-Bash%203.2%20Literal%20Loader-059669?style=for-the-badge&logo=gnubash&logoColor=white)](COMPONENT-REPORT.md)

<p align="center">
  <a href="README.md">🏠 Home</a> •
  <a href="CHANGELOG.md">📋 Changelog</a> •
  <a href="ARCHITECTURE.md">🛡️ Architecture</a> •
  <a href="HARDWARE-REPORTS.md">📊 Hardware Reports</a>
</p>

---

</div>

<br/>

The owner reports the repaired app is “working fine.” The next request is a more polished, independent MyASUS-inspired interface and more useful hardware controls. **Collect evidence first; no new control is enabled by this report.** Documentation and release assets for the next app build must describe only what is actually implemented and tested.

<br/>

## 🛠️ Corrected v1.1: Bash 3.2 Parser Fix

The owner reported an unexpected-EOF/quote syntax error at lines 185/187 in v1. It was reproduced with GNU Bash 3.2.57 on Linux. The quoted AWK filter inside a command substitution was the cause; v1.1 loads it literally at top level instead. The filter body, two privileged commands and read-only scope are unchanged. Do not upgrade the Mac shell or change drivers/security to solve this.

Use the newly named v1.1 file, not the old downloaded copy. A safe preflight is:

```bash
/bin/bash -n "$HOME/Downloads/KL-06-Components-v1.1.command"
```

No output means the syntax check passed. Then run the collection command below.

<br/>

## 📥 Download + One Terminal Line

Download **KL-06-Components-v1.1.command** into Downloads, then run as your normal user:

```bash
/bin/bash "$HOME/Downloads/KL-06-Components-v1.1.command" --power
```

> [!WARNING]
> **Do not put sudo before the script.** `--power` requests two fixed built-in read-only samples: CPU/GPU, then SMC, five samples each at 1000 ms. Only the first sudo call may ask for the Mac password; the SMC follow-up is noninteractive and can be unavailable if authorization is not cached. Type a password only into Terminal if requested; typing is normally invisible. Never send it to chat. No `sudo -S`, password capture, root shell or general privileged collector is used.

Without `--power`, there is no administrator request. `--stdout` skips file creation. `--help` performs no collection. No Python, Xcode, app build or GitHub connection is needed.

**Full-paste alternative:** `KL-06-COMPONENT-PASTE-v1.1.txt` is one complete Bash here-document including `--power`. Copy all of it, including the first and last lines. No separate download URL or script file is needed for that alternative. If Terminal shows an unfinished-quote prompt, press Control-C and restart with the complete command; do not paste truncated fragments.

<br/>

## 📄 Return Sanitized Report, Not Raw Dumps

Allow roughly 1–2 minutes, plus any authorization wait. Only minimized/projected/redacted output is saved to **REPORT.txt** in a new **KL-06-Components.XXXXXX** Desktop folder (home fallback). Look for `END KL06_COMPONENT_REPORT_V1` at the end; Control-C can leave an incomplete report.

Inspect the file locally before attaching **REPORT.txt only**. Add:
- Physical laptop/motherboard model, not just injected SMBIOS.
- AC/battery and external-display conditions.
- Actually tested fan/CPU/GPU/display/sound/mic/USB behavior and exact requested control/bug. A normal idle report is useful; no stress test is needed.

Do not post reports to the public repository by default. Do not send EFI backups, serials, tokens, passwords or recovery keys. Allowlists/redaction minimize data; they are not an absolute privacy guarantee for customized macOS output.

<br/>

## 🔍 What It Can and Cannot Establish

- **CPU/GPU:** Selected identifiers, software-reported frequency keys, optional numerical IOAccelerator performance fields and bounded power/frequency/temperature samples. Missing fields stay unavailable. Multiple-GPU registry statistics are not automatically mapped to a particular GPU; no clock/voltage write is attempted.
- **Fan:** Selected loaded SMC/sensor-provider IDs, coarse service observations and RPM only if powermetrics really returns it. Driver presence/RPM does **not** establish a writable fan controller or safe fan curve. Unsupported SMC sampling is common and is not proof of faulty hardware.
- **Display:** Reported resolution/Metal/HDR context, not a passed graphics workload or reason to enable HDR. Preserve custom WEX/OLED/DPCD/Fn and the known-good **HDR-off** baseline.
- **Sound/mic:** Selected codec/layout and route/channel/sample-rate fields, with private device names omitted. No playback, microphone recording, permission request, codec change, DTS or noise-cancellation implementation.
- **USB:** Selected controller numerics and coarse counts, **not** a physical port map/function test. The owner says USB works; do not remap/reset it based on this inventory.

No driver/install, network upload, EFI/Windows/security/persistent-power change, firmware/EC/SMC write, overclock, benchmark, cache purge or disk optimization. This is not a universal compatibility certificate.

<br/>

## 🔬 Linux Verification Boundary

14 component parser/privacy/safety tests pass on Linux, including the fixed privileged-command allowlist and literal-loader round-trip regression. Syntax and literal-loader execution were also checked with GNU Bash 3.2.57 on Linux. This is not the Apple macOS binary, BSD-tool execution, actual sudo authorization or supported sensor sampling on the target. **No real Mac report has been collected here.** The next step is the owner's reviewed report, then feature-by-feature implementation and actual target testing—not cosmetic fake controls.
