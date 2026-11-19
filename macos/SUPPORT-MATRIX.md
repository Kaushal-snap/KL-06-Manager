# Mac capability gates — beta.2 / build 5

Whole-platform inventory: `../docs/SUPPORT-MATRIX.md`; concrete keys/APIs: `../docs/CONTROLS-AND-TELEMETRY.md`. These are implementation facts, **not physical-device certification**.

| Feature | Implemented | Native/physical verification |
|---|---|---|
| Cirrus local UI | 13 pages, dark/light, independent offline assets | Browser/mock pass; native rendering pending |
| Current CPU/RAM/battery/filesystem/display/audio | Existing public/native APIs, gap/freshness/source distinction | Actual target OS/provider/calibration pending |
| Fixed fan RPM | Existing SMC `FNum/F0Ac/F1Ac`, ≤2 fans, one worker, typed failures, ≥5s cadence, stale 12s | Synthetic C pass; Mac ABI/provider/hardware pending, may be unavailable |
| HWiNFO historical CSV | Native bounded picker + numeric/source-separated stats/graphs | Parser/browser pass; native picker pending; never live Mac |
| User preference/restore | 12 fixed keys, original/absence journal-before-write, readback, observed-conflict protection | Source/portable contracts pass; Apple SDK fake tests + real effects pending |
| Output volume | Settable default output, per-channel getter/readback/owned rollback on failure | Actual route/hardware operation pending |
| Temporary idle assertion | Fixed caffeinate, max 15min, normal quit release | Native execution pending; no lid/forced/display override |
| F13 / physical PrtSc | Running-only Carbon hotkey 105, no modifiers/remap/keylogger | Status/window policy tests only; real key/quit/dialog check pending |
| Optional power/frequency read | Explicit fixed five-sample powermetrics + native local authorization | Parser/contracts; actual provider/authorization pending, not continuous live |
| Phone companion host | Explicit private LAN TLS/Python, full pin/random code/local pair approval, per-write exact-value confirmation, revocation/expiry | Linux broker/TLS/clock/policy mocks pass; real Mac+phone pending |
| GPU/Metal descriptor | Existing public model/family flag | Not a GPU clock/load or Metal 3 workload certification |
| Firmware fan/ASUS mode/charge caps/voltage/clock tuning | **Unavailable** | No approved writable/readback/fail-safe contract |
| Privileged helper / root shell / security bypass | **Not supplied** | Separate narrow signed-helper/removal design would need approval |
| HDR/DTS/system-wide mic DSP/OLED compensation | **No control implemented** | Preserve working setup/HDR OFF; no licensing/processing claim |
| Cleanup/driver/boot/partition edits | **Not implemented** | Read-only storage; EFI/Windows/working drivers untouched |

Target x86_64 / macOS 13–26 APIs. **26 untested, 27+ blocked**; no ARM/universal-Hackintosh approval. Permission cannot invent a missing hardware provider, and imported Windows metadata cannot authorize a Mac write. Native compile/sign/launch/physical checks remain pending in `../BUILD-STATUS.json`.
