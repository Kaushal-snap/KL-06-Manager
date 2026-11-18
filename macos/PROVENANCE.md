# Mac provenance — beta.2 / build 5

See **`../docs/PROVENANCE.md`** and `../docs/DEPENDENCIES-LICENSES.md` for the whole-root source/third-party/toolchain record.

- Base app-only KL-06 0.2.1 project revision `95b2e9ea439d77a76f5982262c9400549c291378`; `BASE-SOURCE-SHA256.json` records 25 canonical **input** hashes. The original canonical files still match; this changed candidate is not claimed identical to them. Parent EFI/project history is not packaged or modified.
- Frozen beta.1/build 4 is lineage. This is the separate beta.2/build 5 multiplatform source export, not a remote commit/release or owner approval.
- Existing MIT project code/artwork retained. Cirrus styles, fixed read-only C/Swift SMC adapter, CSV parser/history, native control/companion logic and tests are project-authored. The public GPL smcFanControl header was an ABI/API cross-check, **not copied implementation/header/binary**; AsusSMC was reviewed, not adopted/installed/bundled. No ASUS/DTS/HWiNFO app/driver/SDK, Apple SDK, EFI, raw owner report or private Drive credential is included.
- Native Mac app remains **uncompiled/unsigned/unrun here**. Ad-hoc signing occurs only if its builder succeeds on installed Apple tools; no Developer ID/notarization or native sensor certification is claimed.
- The source manifests are at the **parent root**, `../SOURCE-MANIFEST.json` and `../SHA256SUMS`. They bind reviewed source contents; the outer handoff hashes bind whole-root source and separately labelled untested candidates. No hash is a device-test result.

The Mac builder requires sibling `../companion/server.py`. Do not package/import this subfolder alone or upload originals/private backups/reports/restore journals/logs/pairing keys. Required notices/license are described in the parent dependency guide.
