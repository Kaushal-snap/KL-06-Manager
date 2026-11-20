# KL06FanSMC (read-only fan RPM) - EXPERIMENTAL SKETCH, NOT COMPILED

Goal: expose `FNum`/`F0Ac` so KL-06's FanMonitor can show real RPM on the K513EA.
Source of the formula: user's DSDT (`EC0.TACH`, RPM = 0x0041CDB4 / (2*raw)).

Status honesty: this is a source sketch. The VirtualSMC key registration (marked in
`KL06FanSMC.cpp`) is not finished and nothing here was built or booted. It needs a
Mac with Xcode, VirtualSMC SDK and Lilu. Read-only: it never writes the EC.
Test only from a spare EFI; rollback = remove the kext + its config.plist entry.
Until it exists the app shows "Fan RPM unavailable" rather than a fake number.
