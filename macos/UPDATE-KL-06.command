#!/bin/bash
# Convenience wrapper only: fake-preference tests, then local app build.
# No auto-launch, downloads, sudo, installation or hardware/settings changes.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' 'KL-06 update: quit any old KL app first (Command-Q).' 'Testing with fake preferences before building the new app…'
/bin/bash "$ROOT/TEST-MAC.command"
/bin/bash "$ROOT/BUILD-MAC.command"
