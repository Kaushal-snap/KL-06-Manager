#!/bin/bash
# Developer-only portable logic checks, not Mac hardware certification.
set -eu
set -o pipefail
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kl06-portable.XXXXXX")
trap 'rm -rf -- "$WORK"' EXIT
cd "$ROOT"
node --test tests/model.test.js tests/history.test.js
python3 tests/package.test.py
set --; if [ "$(uname -s)" = Darwin ]; then set -- -framework IOKit -framework CoreFoundation; fi
cc -std=c11 -O2 -Wall -Wextra -Werror -DKL06_SMC_TEST -ISources Sources/SMCReader.c tests/smc/test_smc.c "$@" -lm -o "$WORK/smc-tests"
"$WORK/smc-tests"
printf '%s\n' 'Portable assertions passed. macOS SDK build and actual fan/provider tests are separate.'
