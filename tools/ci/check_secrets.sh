#!/usr/bin/env bash
# Fails if anything that looks like a secret is tracked in git.
# Lightweight guard until a full scanner (gitleaks) is added before release builds.
set -euo pipefail

status=0

# 1. Files that must never be committed.
bad_files=$(git ls-files | grep -Ei '\.(keystore|jks|p12|pem|key)$|(^|/)\.env(\..*)?$|export_credentials\.cfg$' || true)
if [ -n "$bad_files" ]; then
  echo "::error::Secret-bearing files are tracked:"; echo "$bad_files"; status=1
fi

# 2. Secret-looking content in tracked text files (this script excluded).
patterns='-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-ant-[A-Za-z0-9_-]{10,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AIza[0-9A-Za-z_-]{35}'
hits=$(git ls-files -z | grep -zv '^tools/ci/check_secrets.sh$' | xargs -0 grep -IEn "$patterns" 2>/dev/null || true)
if [ -n "$hits" ]; then
  echo "::error::Secret-looking strings found:"; echo "$hits" | cut -c1-160; status=1
fi

# 3. Keystore passwords must never be filled in export_presets.cfg.
if git ls-files --error-unmatch export_presets.cfg >/dev/null 2>&1; then
  if grep -E '^keystore/(debug|release)(_user|_password)?="[^"]+"' export_presets.cfg; then
    echo "::error::export_presets.cfg contains keystore settings; use CI env vars instead."; status=1
  fi
fi

[ "$status" -eq 0 ] && echo "secret check: clean"
exit "$status"
