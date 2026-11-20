#!/bin/bash
# Reversible, no-EFI fixes. Usage: bash safe_fixes.sh [apply|rollback|report]
case "${1:-report}" in
apply)
  mkdir -p "$HOME/.kl06"; pmset -g custom > "$HOME/.kl06/pmset_before.txt"
  sudo pmset -a tcpkeepalive 0 powernap 0 proximitywake 0
  echo "APPLIED. Undo: bash safe_fixes.sh rollback";;
rollback)
  sudo pmset -a tcpkeepalive 1 powernap 1 proximitywake 1; echo "ROLLED BACK (macOS defaults).";;
report)
  { date; sw_vers; sysctl -n machdep.cpu.brand_string; system_profiler SPDisplaysDataType | head -30
    pmset -g; pmset -g log | grep -iE "wake|sleep" | tail -30; } 2>&1 | tee "$HOME/kl06_report.txt"
  echo "Saved: $HOME/kl06_report.txt (personal info check karke share karo)";;
esac
