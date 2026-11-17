# Put KL-06 on your GitHub safely

No authenticated push or repository creation was performed from this chat. The available GitHub connector reports unsupported here; a password or personal access token must **not** be pasted into Arena.

## Recommended: a fresh app-only repository

Keep KL-06 separate from the historical Hackintosh EFI repository. That avoids importing old EFI/SMBIOS history or third-party driver binaries.

1. Sign in to **github.com in your own browser**. Choose **New repository**, name it `KL-06`, and choose private/public deliberately. Private is a sensible first review stage.
2. Extract `KL-06-0.2.1-update-and-report.zip` on your Mac. Its `KL-06-0.2.1` folder contains the application source/builders, standalone hardware script, documentation, MIT license and tests—not the EFI project or private reports.
3. For a browser upload, open the new repository → **Add file → Upload files** and select the source folder's *contents*. Review the file list before committing. Do not upload `Local-build/`, built apps/logs, restore journals, reports, `.private`, `.inputs`, EFI backups or identities. Upload the standalone report collector and complete share block only after checking their published contents.
4. For later updates, use a separate branch and review before merging. For full CLI history preservation, use Git on the Mac; if GitHub CLI is already installed, `gh auth login --web --git-protocol https` uses GitHub's browser authorization. Do not send anyone the token or recovery codes.
5. Share the **repository URL**, not credentials, with Arena after publication. Then a real immutable revision/download URL and checksum can be verified. No guessed `curl | bash` command is currently live.

The new app source uses Apple system frameworks but does not redistribute them. No ASUS firmware, DTS implementation, graphics/kernel driver or Windows MyASUS code is licensed or bundled here. Retain the included license and capability/verification qualifications.

An uploaded source project is not a compiled, signed/notarized, universally supported binary release. Do not label firmware controls, unknown hardware or macOS 27 as supported without exact tests.
