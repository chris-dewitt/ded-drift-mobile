#!/usr/bin/env bash
# Installs the APK on a running Android emulator, turns on the debug-only
# autopilot, plays for a few minutes, and fails if the app dies or logs
# script errors / native crashes. Prints the relevant logcat either way.
# Usage: tools/ci/emulator_smoke.sh path/to/app.apk [seconds]
set -uo pipefail

APK="${1:?apk path}"
PLAY_SECONDS="${2:-240}"
PKG="org.chrisdewitt.deddrift"
ADB="${ANDROID_SDK_ROOT}/platform-tools/adb"

$ADB install -r -g "$APK" || { echo "::error::install failed"; exit 1; }
$ADB logcat -c

# Debug builds are debuggable, so run-as can drop the autopilot flag into
# the app's private storage (user://). Release builds can't do this.
$ADB shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 6
$ADB shell run-as "$PKG" sh -c "'echo on > files/autopilot.txt'" || echo "::warning::could not enable autopilot"
$ADB shell am force-stop "$PKG"
sleep 1
$ADB logcat -c
$ADB shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

status=0
elapsed=0
while [ "$elapsed" -lt "$PLAY_SECONDS" ]; do
  sleep 10
  elapsed=$((elapsed + 10))
  if [ -z "$($ADB shell pidof "$PKG" | tr -d '\r')" ]; then
    echo "::error::app process died after ~${elapsed}s"
    status=1
    break
  fi
done

$ADB exec-out screencap -p > build/emulator_last_frame.png 2>/dev/null || true
$ADB logcat -d > build/logcat.txt

echo "===== godot / crash logcat (tail) ====="
grep -E "godot|Godot|AUTOPILOT|AndroidRuntime|FATAL|Fatal signal|DEBUG  |libc  |SIGSEGV|SIGABRT|backtrace|ANR in" build/logcat.txt | tail -n 400

if grep -qE "FATAL EXCEPTION|Fatal signal|ANR in $PKG" build/logcat.txt; then
  echo "::error::native crash / fatal exception / ANR in logcat"
  status=1
fi
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access" build/logcat.txt; then
  echo "::error::script errors on device"
  status=1
fi
if [ "$status" -eq 0 ] && ! grep -q "AUTOPILOT" build/logcat.txt; then
  echo "::warning::autopilot never reported; app may be stuck before the title"
fi
grep "AUTOPILOT" build/logcat.txt | tail -n 60
exit "$status"
