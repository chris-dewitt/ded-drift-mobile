#!/usr/bin/env bash
# Boots a headless x86_64 Android 14 emulator (SwiftShader GLES) and waits
# for it to finish booting. Needs KVM on the runner. Never waits forever:
# on failure it prints the emulator's own log.
set -uo pipefail

SDK="$ANDROID_SDK_ROOT"
BIN="$SDK/cmdline-tools/latest/bin"
IMG="system-images;android-34;google_apis;x86_64"
ADB="$SDK/platform-tools/adb"

fail() { echo "::error::$1"; echo "----- emulator.log -----"; tail -n 80 emulator.log 2>/dev/null; exit 1; }

ls -l /dev/kvm || echo "::warning::no /dev/kvm"
yes 2>/dev/null | "$BIN/sdkmanager" --licenses >/dev/null 2>&1 || true
"$BIN/sdkmanager" --install "emulator" "platform-tools" "$IMG" >/dev/null || fail "sdkmanager install failed"
echo no | "$BIN/avdmanager" create avd -n dd -k "$IMG" -d pixel_6 --force >/dev/null || fail "avd create failed"
"$SDK/emulator/emulator" -accel-check || true
nohup "$SDK/emulator/emulator" -avd dd -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -memory 4096 -accel on > emulator.log 2>&1 &
EMU_PID=$!

for i in $(seq 1 200); do
  if ! kill -0 "$EMU_PID" 2>/dev/null; then
    fail "emulator process exited during boot"
  fi
  if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    echo "emulator booted after ~$((i * 3))s"
    "$ADB" shell settings put global window_animation_scale 0 || true
    "$ADB" shell settings put global transition_animation_scale 0 || true
    "$ADB" shell input keyevent 82 || true
    exit 0
  fi
  sleep 3
done
fail "emulator did not finish booting in 10 minutes"
