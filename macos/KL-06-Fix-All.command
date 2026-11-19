#!/bin/bash
# KL-06 Manager — One-Click Fix All Script Wrapper
DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$DIR/KL-06-Fix-All.sh"
exec /bin/bash "$DIR/KL-06-Fix-All.sh"
