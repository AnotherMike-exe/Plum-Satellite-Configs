#!/usr/bin/env bash
# Validate every template by fully resolving its packages.
#
# This is the real test for this repo: `esphome config` fetches the remote
# package, applies every substitution and vars: override, and binds every id
# reference. A broken pin, a renamed vendor id, or a bad !include fails here --
# no hardware required.
#
# Usage:
#   scripts/validate-all.sh            # validate templates against their pinned tag
#   scripts/validate-all.sh --local    # validate against the WORKING TREE instead,
#                                      # by rewriting the github:// ref to a local
#                                      # !include. Use this before tagging a release,
#                                      # when the tag the templates name does not
#                                      # exist yet.
#   scripts/validate-all.sh --clean    # clear the package cache first, proving the
#                                      # pinned refs actually fetch
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_ROOT/templates"
MODE="${1:-}"

command -v esphome >/dev/null 2>&1 || { echo "error: esphome not on PATH (pip install esphome)" >&2; exit 1; }

WORK="$TEMPLATES"
if [[ "$MODE" == "--local" ]]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  cp "$TEMPLATES"/*.yaml "$WORK"/
  # github://<owner>/<repo>/lib/profiles/<x>.yaml@<tag>  ->  local include
  sed -i '' -E 's|plum: github://[^/]+/[^/]+/(lib/profiles/[a-z0-9-]+\.yaml)@.*|plum: !include '"$REPO_ROOT"'/\1|' "$WORK"/*.yaml
  echo "==> --local: validating against the working tree, not the pinned tag"
fi

if [[ "$MODE" == "--clean" ]]; then
  echo "==> Clearing package cache to force a fresh fetch of the pinned refs"
  rm -rf "$TEMPLATES/.esphome/packages"
fi

# Templates ship placeholders; give them a throwaway secrets file to resolve against.
if [[ ! -f "$WORK/secrets.yaml" ]]; then
  cat > "$WORK/secrets.yaml" <<'SECRETS'
wifi_ssid: "ValidationOnly"
wifi_password: "ValidationOnlyPassword"
api_key_change_me: "Qw3rTy7UiOp2AsDfGh5JkLzXcVbNm8QwErTyUiOpAsE="
ota_password: "ValidationOnlyOtaPassword"
SECRETS
  CREATED_SECRETS=1
fi

failed=(); passed=()
for cfg in "$WORK"/*.yaml; do
  name="$(basename "$cfg")"
  [[ "$name" == secrets.yaml || "$name" == secrets.yaml.example ]] && continue
  echo; echo "==> $name"
  if esphome config "$cfg" >/dev/null 2>"$WORK/.err"; then
    echo "    OK"; passed+=("$name")
  else
    echo "    FAILED"; sed 's/^/    /' "$WORK/.err" | head -20; failed+=("$name")
  fi
done
rm -f "$WORK/.err"
[[ "${CREATED_SECRETS:-}" == 1 && "$WORK" == "$TEMPLATES" ]] && rm -f "$WORK/secrets.yaml"

echo; echo "================================"
echo "passed: ${#passed[@]}   failed: ${#failed[@]}"
if (( ${#failed[@]} )); then printf 'FAILED: %s\n' "${failed[@]}"; exit 1; fi
echo "All templates resolved cleanly."
