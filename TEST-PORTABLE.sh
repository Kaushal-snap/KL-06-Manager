#!/bin/bash
# Portable/synthetic logic only. No OS preference/control/provider access or app upload.
set -eu
set -o pipefail
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for tool in node python3 cc; do command -v "$tool" >/dev/null || { printf '%s\n' "Missing developer tool: $tool. Nothing was downloaded." >&2; exit 78; }; done
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kl06-all-portable.XXXXXX")
trap 'rm -rf -- "$WORK"' EXIT
cd "$ROOT"
node --test macos/tests/model.test.js macos/tests/history.test.js tests/common.test.js
python3 macos/tests/package.test.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
set --; if [ "$(uname -s)" = Darwin ]; then set -- -framework IOKit -framework CoreFoundation; fi
cc -std=c11 -O2 -Wall -Wextra -Werror -DKL06_SMC_TEST -Imacos/Sources macos/Sources/SMCReader.c macos/tests/smc/test_smc.c "$@" -lm -o "$WORK/SMCTests"
"$WORK/SMCTests"
if command -v javac >/dev/null && command -v java >/dev/null; then
  mkdir -p "$WORK/java"
  javac -d "$WORK/java" android/app/src/main/java/app/klasus/controlcenter/LANPolicy.java tests/java/LANPolicyTest.java
  java -cp "$WORK/java" app.klasus.controlcenter.LANPolicyTest
else printf '%s\n' 'Optional Java policy tests NOT RUN: developer JDK absent.'; fi
if [ -f SOURCE-MANIFEST.json ]; then python3 automation/source_manifest.py; else printf '%s\n' 'Source hash verification NOT RUN: export manifest has not been generated yet.'; fi
printf '%s\n' 'Portable checks complete. Native Mac/Windows/mobile builds, physical devices and real-service activation are separate; none is approved by this script.'
