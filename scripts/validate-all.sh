#!/usr/bin/env bash
# Validate every device config by fully resolving its packages.
#
# This is the real test for this repo: `esphome config` fetches every remote
# package, applies every substitution and vars: override, and binds every id
# reference. A broken pin, a renamed vendor id, or a bad !include fails here --
# no flashing required.
#
# Usage:
#   scripts/validate-all.sh              # validate all devices
#   scripts/validate-all.sh --clean      # clear the package cache first, proving
#                                        # the pinned refs actually fetch
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICES_DIR="$REPO_ROOT/devices"

if ! command -v esphome >/dev/null 2>&1; then
  echo "error: esphome not found on PATH. Install with: pip install esphome" >&2
  exit 1
fi

if [[ "${1:-}" == "--clean" ]]; then
  echo "==> Clearing package cache to force a fresh fetch of all pinned refs"
  rm -rf "$DEVICES_DIR/.esphome/packages"
fi

if [[ ! -f "$DEVICES_DIR/secrets.yaml" ]]; then
  echo "error: $DEVICES_DIR/secrets.yaml is missing." >&2
  echo "       cp devices/secrets.yaml.example devices/secrets.yaml" >&2
  echo "       Placeholder values are fine for validation." >&2
  exit 1
fi

failed=()
passed=()

for cfg in "$DEVICES_DIR"/*.yaml; do
  name="$(basename "$cfg")"
  [[ "$name" == "secrets.yaml" || "$name" == "secrets.yaml.example" ]] && continue

  echo
  echo "==> $name"
  if esphome config "$cfg" >/dev/null 2>"$REPO_ROOT/.validate-err"; then
    echo "    OK"
    passed+=("$name")
  else
    echo "    FAILED"
    sed 's/^/    /' "$REPO_ROOT/.validate-err"
    failed+=("$name")
  fi
done

rm -f "$REPO_ROOT/.validate-err"

echo
echo "================================"
echo "passed: ${#passed[@]}   failed: ${#failed[@]}"
if (( ${#failed[@]} )); then
  printf 'FAILED: %s\n' "${failed[@]}"
  exit 1
fi
echo "All device configs resolved cleanly."
