#!/bin/bash
# Refuse EFI/kext fixes unless this is the exact ASUS K513EA the fixes were written for.
M=$(sysctl -n machdep.cpu.brand_string 2>/dev/null); B=$(ioreg -l | grep -m1 '"product-name"' )
if ! echo "$B" | grep -q "K513EA"; then echo "Ye fix sirf ASUS K513EA ke liye hai. Ruk gaya."; exit 1; fi
