# KL-06 shareable hardware report

## Goal

Let another Hackintosh owner collect a **minimized text file** for Arena review without installing KL-06, Xcode, Python, drivers or a management agent. Report collection does not change their machine or enable hardware controls.

## Finding the file

Arena attachments are not automatically placed on the Mac. Download the presented **KL-06-0.2.1-update-and-report.zip** and unzip it; **KL-06-Hardware-Report.command** is inside **KL-06-0.2.1** beside the app builders. Run it directly from there using the README command, or share/copy that script into the next owner's Downloads for the short command below. The hardware script does not require building the app. The ZIP also includes the complete paste alternative `KL-06-SHARE-COMMAND.txt`.

## Bash 3.2 compatibility correction

The original generic collector shared the component collector's nested-heredoc loader problem. That failure was reproduced with GNU Bash 3.2.57 on Linux and the top-level literal loader in collector v1.1 fixes its syntax. Filter contents/privacy scope and report-format markers are unchanged. Current standalone exports include this correction; older app source ZIPs are snapshots and may contain the original collector. Replace that collector with the current export before distributing an app-only repository. A working native app does not establish that an older report script parses on the Mac.

## One short command after download

Share **KL-06-Hardware-Report.command**, and tell them to download it into Downloads. In a new Terminal window:

```bash
/bin/bash "$HOME/Downloads/KL-06-Hardware-Report.command"
```

They should inspect the script before running. No sudo. Allow roughly 1–2 minutes; missing/unsupported queries are not failures of the hardware. Ctrl-C is safe but leaves an incomplete report.

The output file is **REPORT.txt** inside a newly created `KL-06-Report.XXXXXX` folder on their Desktop (home folder fallback). It contains only projected/redacted output; no raw system report is saved. They should review it, add their **physical motherboard/laptop model**, actual tested features and requested controls/bugs, then attach **REPORT.txt only** to Arena.

## One self-contained paste, no separate script

`KL-06-SHARE-COMMAND.txt` contains ONE complete Bash here-document command, starting with `/bin/bash <<'KL06_REPORT'` and ending with `KL06_REPORT`. They may copy that whole block into a new Terminal window. Do not copy only the middle, paste raw source into zsh, add sudo, or reuse a previously malformed/truncated script.

The script and paste block are byte-verified exports of `scripts/collect-kl06-hardware.sh` in the maintenance project. A fake or guessed curl/download URL is not supplied. Once an actual repository/version is published, a short pinned download-and-verify command can be created from its real URL and digest.

## Collected

- Actual OS product/build/Darwin and architecture; reported CPU, core counts, RAM, optional XCPM flag; public SMBIOS **model only**.
- Allowlisted GPU/display/Metal/HDR fields, without display names or serials.
- Selected loaded driver identifiers/versions for Intel/AMD graphics, CPU/SMC, audio, input, USB and wireless stacks; no kernel addresses, UUIDs or dependency dumps. This is not a full driver/binary/runtime inventory.
- Selected numerical, possibly injected PCI/codec/layout properties; not independent physical PCI evidence.
- Audio channel/sample-rate/default-route fields with route/device names omitted.
- Numerical battery capacities/cycles and constrained condition strings; no battery identity.
- Read-only power settings, aggregate assertions, VM page counts, Data filesystem totals/free space; no process/window/volume names.
- Coarse service counts, not a physical port map or proof a device works.

Not collected: account/host name, SMBIOS serial/MLB/ROM/UUID, SSID/BSSID/MAC/IP, paired-device names, passwords/tokens, EFI/config contents, full registry, boot-argument dump, recovery keys or raw logs. Expected-output allowlists and generic redaction minimize privacy risks but cannot guarantee correctness against every customized/changed tool. **Always review before sharing.**

## What we can do with each report

1. Identify a *candidate* base platform: current KL-06 build is x86_64 using macOS 13+ APIs. Intel and AMD are candidates only, not universally validated. The report can still run on other macOS versions for intake.
2. Separate usable standard macOS APIs from missing sensors, drivers or unimplemented controls.
3. Ask for only the missing evidence (physical model/PCI IDs, symptoms, exact device behavior). No assumption that a spoofed MacBook SMBIOS is the real computer.
4. Add a narrowly scoped capability/provider, with its provenance, driver requirements, safety/permission boundary and device-specific verification.
5. Test that exact app build on that exact hardware before declaring a feature supported. Preserve working EFI/runtime/security and Windows throughout.

**Cannot infer from a report:** universal compatibility; stable GPU clocks or power; safe EC/fan/charge-limit methods; working HDR/DTS/system-wide microphone DSP; real USB wiring; successful sleep/Metal workloads; or a passed app control/restore test. KL-06 does not install a guessed driver, apply overclocks, enable HDR or clear a battery warning in response to an inventory.

## Minimum sanitized return template

```text
Attach: REPORT.txt (reviewed)
Physical motherboard/laptop model:
Intel/AMD CPU and physical GPU model, if known:
Working features actually tested:
Requested feature or exact reproducible bug:
AC/battery, external display, relevant conditions:
KL-06 version / native build result, if installed:
```

No raw EFI or complete original system report is needed. There is no automatic upload. Publishing other owners' reports requires their separate informed consent and privacy review; do not add reports to GitHub by default.
