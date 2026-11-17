#!/bin/bash
set -eu
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
command -v gradle >/dev/null || { printf '%s\n' 'Install/configure Gradle 8.13 and JDK 17 through your trusted tools, or open this project in Android Studio. No tool was downloaded.' >&2; exit 78; }
# Dependency resolution is the normal declared Gradle build, not an app-runtime download.
gradle --no-daemon :app:assembleDebug
printf '%s\n' 'Debug-signed owner-testing APK: app/build/outputs/apk/debug/app-debug.apk. No installation or store publication was attempted.'
