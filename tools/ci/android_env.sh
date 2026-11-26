#!/usr/bin/env bash
# Points Godot at the runner's Android SDK + JDK 17 and sets up a debug
# keystore: the DEBUG_KEYSTORE_* repo secrets if present, else a throwaway.
# Exports GODOT_ANDROID_KEYSTORE_DEBUG_* through $GITHUB_ENV.
set -euo pipefail

mkdir -p ~/.config/godot
for f in editor_settings-4.tres editor_settings-4.5.tres; do
  cat > ~/.config/godot/$f <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_SDK_ROOT}"
export/android/java_sdk_path = "${JAVA_HOME_17_X64}"
TRES
done

KS="${RUNNER_TEMP:-/tmp}/debug.keystore"
if [ -n "${DEBUG_KEYSTORE_B64:-}" ] && [ -n "${DEBUG_KEYSTORE_PASS:-}" ]; then
  echo "$DEBUG_KEYSTORE_B64" | base64 -d > "$KS"
  ALIAS=dd
  PASS="$DEBUG_KEYSTORE_PASS"
  echo "Using fixed debug keystore from repo secrets."
else
  PASS=$(openssl rand -hex 16)
  ALIAS=androiddebugkey
  echo "::add-mask::$PASS"
  "$JAVA_HOME_17_X64/bin/keytool" -genkeypair -noprompt -keystore "$KS" \
    -alias "$ALIAS" -storepass "$PASS" -keypass "$PASS" -keyalg RSA -keysize 2048 \
    -validity 9999 -dname "CN=Ded Drift Debug,O=Ded Drift,C=US"
  echo "::warning::No DEBUG_KEYSTORE secrets: throwaway key, uninstall the old build before installing this one."
fi
{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$KS"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=$ALIAS"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$PASS"
} >> "$GITHUB_ENV"
