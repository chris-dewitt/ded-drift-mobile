#!/usr/bin/env bash
# Downloads the pinned Godot editor (and optionally export templates) from the
# official GitHub release, verifies SHA-512 against the release's checksum
# file, and puts `godot` on PATH.
# Usage: GODOT_VERSION=4.5.1-stable [WITH_TEMPLATES=1] tools/ci/setup_godot.sh
set -euo pipefail

VER="${GODOT_VERSION:?set GODOT_VERSION, e.g. 4.5.1-stable}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?-[a-z0-9]+$ ]] || { echo "bad GODOT_VERSION"; exit 1; }
BASE="https://github.com/godotengine/godot/releases/download/${VER}"
DIR="${RUNNER_TEMP:-/tmp}/godot-${VER}"
mkdir -p "$DIR"
cd "$DIR"

fetch() { curl -fsSL --retry 3 --retry-delay 5 -o "$1" "$BASE/$1"; }
verify() {
  local line; line=$(grep -E "^[0-9a-f]{128}  $1\$" SHA512-SUMS.txt) || { echo "no checksum for $1"; exit 1; }
  echo "$line" | sha512sum -c -
}

fetch SHA512-SUMS.txt

EDITOR_ZIP="Godot_v${VER}_linux.x86_64.zip"
fetch "$EDITOR_ZIP"
verify "$EDITOR_ZIP"
unzip -qo "$EDITOR_ZIP"
mv -f "Godot_v${VER}_linux.x86_64" godot
chmod +x godot
echo "$DIR" >> "${GITHUB_PATH:-/dev/null}"
export PATH="$DIR:$PATH"
godot --version

if [ "${WITH_TEMPLATES:-0}" = "1" ]; then
  TPL="Godot_v${VER}_export_templates.tpz"
  fetch "$TPL"
  verify "$TPL"
  TPL_DIR="$HOME/.local/share/godot/export_templates/${VER/-/.}"
  mkdir -p "$TPL_DIR"
  unzip -qo "$TPL" 'templates/android_*' 'templates/version.txt' -d tpl
  mv -f tpl/templates/* "$TPL_DIR/"
  rm -rf tpl "$TPL"
  ls -la "$TPL_DIR"
fi
