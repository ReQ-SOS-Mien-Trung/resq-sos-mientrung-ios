#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT_DIR/scripts/build_localizable_catalog.py" --check

if rg -n 'L10n\.tr\(' "$ROOT_DIR/SosMienTrung" --glob '*.swift' | grep -v 'Utilities/L10n.swift' >/dev/null; then
  echo "Found raw localization key usage outside L10n.swift." >&2
  exit 1
fi

if rg -n 'errorMessage = "|successMessage = "' \
  "$ROOT_DIR/SosMienTrung/ViewModels" \
  "$ROOT_DIR/SosMienTrung/Services" \
  "$ROOT_DIR/SosMienTrung/Managers" \
  "$ROOT_DIR/SosMienTrung/Models" >/dev/null; then
  echo "Found hardcoded error/success message assignments in core layers." >&2
  exit 1
fi

echo "Localization audit passed."
