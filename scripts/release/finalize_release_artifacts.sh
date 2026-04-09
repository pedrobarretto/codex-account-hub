#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-${RUNNER_TEMP:-$ROOT_DIR/.release-work}/codex-account-hub-release-finalize}"
NOTARY_METADATA_PATH="${NOTARY_METADATA_PATH:-$DIST_DIR/notary-metadata.json}"
NOTARY_STATUS_JSON="$DIST_DIR/notary-status.json"

extract_json_field() {
  /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null | tr -d '\n'
}

require_env() {
  local name="$1"
  if [[ -z "${(P)name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Required file not found: $path" >&2
    exit 1
  fi
}

mkdir -p "$DIST_DIR" "$WORK_DIR"
require_file "$NOTARY_METADATA_PATH"
require_file "$NOTARY_STATUS_JSON"

DMG_NAME="$(extract_json_field dmg_name "$NOTARY_METADATA_PATH")"
NOTARY_SUBMISSION_ID="$(extract_json_field submission_id "$NOTARY_METADATA_PATH")"
NOTARY_STATUS="$(extract_json_field status "$NOTARY_STATUS_JSON")"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ -z "$DMG_NAME" || -z "$NOTARY_SUBMISSION_ID" ]]; then
  echo "Notarization metadata is missing dmg_name or submission_id." >&2
  cat "$NOTARY_METADATA_PATH" >&2
  exit 1
fi

require_file "$DMG_PATH"

if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
  echo "Cannot finalize notarization status '${NOTARY_STATUS:-unknown}'." >&2
  echo "Run scripts/release/check_notarization_status.sh before finalizing." >&2
  exit 1
fi

echo "Finalizing accepted Apple notarization:"
echo "  id: $NOTARY_SUBMISSION_ID"
echo "  dmg: $DMG_PATH"

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Finalized release artifacts:"
echo "  $DMG_PATH"
echo "  $DMG_PATH.sha256"
