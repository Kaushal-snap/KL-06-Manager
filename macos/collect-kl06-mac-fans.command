#!/bin/bash
# Requested lower-case entry point; exactly the same targeted read-only collector.
set -eu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$ROOT/COLLECT-MAC-FANS.command" "$@"
