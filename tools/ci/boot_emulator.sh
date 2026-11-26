#!/usr/bin/env bash
# Boots a headless x86_64 Android 14 emulator (SwiftShader GLES) and waits
# for it to finish booting. Needs KVM on the runner.
set -euo pipefail

SDK="$ANDROID_SDK_ROOT"
BIN="$SDK/cmdline-tools/latest/bin"
IMG="system-images;android-34;google_apis;x86_64"
ADB="$SDK/platform-tools/adb"

yes | "$BIN/sdkmanager" --licenses >/dev/null 2>&1 || true
"$BIN/sdkmanager" --install "emulator" "platform-tools" "$IMG" >/dev/null
echo no | "$BIN/avdmanager" create avd -n dd -k "$IMG" -d pixel_6 --force >/dev/null
nohup "$SDK/emulator/emulator" -avd dd -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -memory 4096 > emulator.log 2>&1 &
"$ADB" wait-for-device
for _ in $(seq 1 180); do
  if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    echo "emulator booted"
    "$ADB" shell settings put global window_animation_scale 0 || true
    "$ADB" shell settings put global transition_animation_scale 0 || true
    "$ADB" shell input keyevent 82 || true
    exit 0
  fi
  sleep 2
done
echo "::error::emulator did not boot"; tail -n 50 emulator.log; exit 1
