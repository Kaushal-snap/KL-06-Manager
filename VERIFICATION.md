# KL-06 0.2.1 — local verification

2026-11-16. Source/software-tested update, not a native- or universally certified release.

## Evidence levels

- Owner says **KL -Asus v0.1 is working good** after their local build. No individual feature/test logs or full control/EFI hardware certification follows.
- The rename/generic-UI/report revision and **new v0.2.1 F13 shortcut have not been compiled or executed on a Mac here**. No claim that the real PrtSc shortcut already works on that laptop.
- Other Intel/AMD Hackintoshes are candidates for per-feature evaluation, not approved by architecture, GPU name or a report alone.

## Owner's native compile attempt / correction

The owner supplied a v0.2.1 **compile failure**, not a passed native test: `Sources/HotKey.swift:45` converted `buffer.count` to `UInt32`, but their SDK's `InstallEventHandler` third argument expects `Int`. The fake-preference test binary did not run and the gated app build was not reached. This is a source bug, not a permissions/driver/EFI issue.

The corrected source passes **`buffer.count` unchanged**. Nearby fixed key/event IDs and modifiers retain their explicit API types; `GetEventParameter`'s byte count already uses inferred `numericCast`. No broader keyboard monitor or permission workaround was added. A new source regression and sed-replacement fixture cover this exact mistake; neither can prove native SDK compilation. **Owner native retry is still pending.** The reissued preview ZIP retains v0.2.1/build 3 and records its new source revision/checksums; it is not an immutable published release.

## Executed here on Linux for corrected 0.2.1

- **98/98 project/app/report Python tests passed**: prior 97 plus the event-count/patch regression. One Python check invokes the portable Node suite; this is not an independent native test.
- Source-only simulation: **98 discovered, OK with 3 private-input/schema integrations skipped**. No private inputs copied.
- **28/28 portable Node tests passed**: UI model/actions, preference IDs, true-load colors, capability limits, demo isolation and source boundaries.
- Historical v0.2.1 browser flow passed: eight pages, nine preferences/filtering, demo isolation, appearance toggle, desktop/390px layout, no external requests, mocked native volume/apply/restore IPC and hostile-field escaping. Resources/ is byte-unchanged by this count-only native fix; browser checks are not a new macOS test.
- Those browser checks cover About's **demo-only**, mocked **F13 registered**, and mocked **registration unavailable** labels. Playwright's key-name table has no F13; the browser test uses a **synthetic DOM F13 event only**. It cannot exercise Carbon, a physical key, AppKit focus/minimization, a real modal loop, OS conflict or global key delivery.
- Swift grammar parsed: Core.swift, HotKey.swift, main.swift and native tests. **Not SDK type/API checking, linking or execution.**
- Bash syntax / non-macOS refusal / no-output tests passed for the builders, new test-gated update wrapper and unchanged generic report. No actual Mac Bash 3.2 report collected.
- Public source and explicit app/collector/hotkey-test privacy scans: **0 findings**. Minimization/redaction is not a privacy guarantee; each report still requires owner review. No raw report, identity, credentials, EFI or foreign-owner observation is in the package.
- Input/schema verification: Sequoia **0 errors / 9 blockers**; Tahoe **0 / 10**; future **blocked / 0 / 1**. Both normalized configs remain `d8763853719bfc155b2055f5ce5e6d3d83c48c9cb8410f8297dfc5711ca2021c`.

## New native checks supplied, not run here

`TEST-MAC.command` compiles HotKey.swift/Carbon plus the existing Core logic. Tests inspect keyCode 105/no modifiers, all 16 combinations of active/visible/minimized/dialog window policy, and press/repeat/release/reset latch transitions. They **never register a real global key**, touch actual desktop preferences or invoke a sensor/power read. The app build compiles the actual AppKit host separately; only opening that app can verify the runtime behavior.

## Target-owner F13 checklist

Build with installed Apple tools as a normal user, after quitting every older KL copy. Keep existing restore data.

1. Open the new app; About must say **0.2.1**. Check shortcut status, not just the version.
2. In another normal app, tap physical PrtSc (reported to send F13): KL-06 should come forward. Tap again with KL-06 in front: it should hide. F13 must not apply a tweak or authorize anything.
3. Close/minimize the window, then tap F13: it should reopen/deminiaturize. Holding then releasing must toggle only once; a later separate press must work.
4. With a native KL confirmation/save dialog open, F13 must not strand it. Cancel the dialog if you do not intend its action. If you separately chose optional power authorization/sampling, F13 should do nothing until that operation finishes, leaving the separate OS prompt alone. Browser dialogs/mocks do not validate this step.
5. Quit KL-06 with Command-Q. F13 must no longer invoke it. No startup helper or keyboard remap should exist.
6. If registration fails or the key is suppressed by macOS/another app, retain the warning/status; use the menu bar/Dock. Review competing shortcuts, then quit/reopen to retry. No security bypass or broad key-monitor fallback is appropriate.

Native build/Carbon API compatibility, real focus/menu/modal/minimize/repeat/conflict/quit behavior, old-journal restore continuity, actual counters/Core Audio/Settings/keep-awake/power sample and per-owner report review remain pending. A software check or report alone cannot approve a firmware control, workload or future OS.

## Historical 0.2.0 evidence

91/91 Python, 28/28 Node, source-only 91 with 3 skips, browser and Swift grammar checks passed before the F13 change. A separate mocked AMD Ryzen/Radeon desktop verified generic branding/no inherited ASUS/battery/audio/USB claim, actual fixture CPU-load color and no fabricated GPU utilization. That was a browser mock, not native AMD certification. The collector source remains byte-unchanged in this patch.

## Rename / safety continuity

Visible app name/executable is KL-06. Bundle ID `app.klasus.controlcenter` and restore journal `KL-Asus/Restore-v1.plist` remain intentionally unchanged. No journal migration/deletion/overwritten original is performed.

No CPU/GPU clock write, fan/EC command, auto HDR, DTS, system-wide mic DSP, destructive disk cleaner, driver installation, EFI/security/persistent power/Windows change or OS support-gate expansion. The F13 shortcut is only an app-owned Carbon reservation released on quit, not an EFI/keyboard remap, raw key log, Accessibility/Input Monitoring request or system-wide preference write. No GitHub push/repository/PR/public download URL was created.
