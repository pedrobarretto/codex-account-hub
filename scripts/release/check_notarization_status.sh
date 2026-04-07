#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-${RUNNER_TEMP:-$ROOT_DIR/.release-work}/codex-account-hub-release-status}"
NOTARY_METADATA_PATH="${NOTARY_METADATA_PATH:-$DIST_DIR/notary-metadata.json}"
NOTARY_KEY_PATH="$WORK_DIR/AuthKey_${APPLE_NOTARY_KEY_ID:-unknown}.p8"
NOTARY_STATUS_JSON="$DIST_DIR/notary-status.json"
NOTARY_LOG_PATH="$DIST_DIR/notary-log.json"

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

require_env "APPLE_NOTARY_KEY_ID"
require_env "APPLE_NOTARY_ISSUER_ID"
require_env "APPLE_NOTARY_API_PRIVATE_KEY"

mkdir -p "$DIST_DIR" "$WORK_DIR"
rm -f "$NOTARY_STATUS_JSON" "$NOTARY_LOG_PATH"
require_file "$NOTARY_METADATA_PATH"

NOTARY_SUBMISSION_ID="$(extract_json_field submission_id "$NOTARY_METADATA_PATH")"

if [[ -z "$NOTARY_SUBMISSION_ID" ]]; then
  echo "Notarization metadata is missing submission_id." >&2
  cat "$NOTARY_METADATA_PATH" >&2
  exit 1
fi

printf '%s' "$APPLE_NOTARY_API_PRIVATE_KEY" > "$NOTARY_KEY_PATH"
chmod 600 "$NOTARY_KEY_PATH"

xcrun notarytool info \
  "$NOTARY_SUBMISSION_ID" \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --output-format json > "$NOTARY_STATUS_JSON"

NOTARY_STATUS="$(extract_json_field status "$NOTARY_STATUS_JSON")"
NOTARY_MESSAGE="$(extract_json_field message "$NOTARY_STATUS_JSON")"
CREATED_DATE="$(extract_json_field createdDate "$NOTARY_STATUS_JSON")"

echo "Apple notarization status:"
echo "  id: $NOTARY_SUBMISSION_ID"
echo "  status: ${NOTARY_STATUS:-unknown}"
if [[ -n "$CREATED_DATE" ]]; then
  echo "  created: $CREATED_DATE"
fi
if [[ -n "$NOTARY_MESSAGE" ]]; then
  echo "  message: $NOTARY_MESSAGE"
fi

case "$NOTARY_STATUS" in
  Accepted)
    exit 0
    ;;
  "In Progress"|"")
    exit 75
    ;;
  Invalid|Rejected)
    xcrun notarytool log \
      "$NOTARY_SUBMISSION_ID" \
      "$NOTARY_LOG_PATH" \
      --key "$NOTARY_KEY_PATH" \
      --key-id "$APPLE_NOTARY_KEY_ID" \
      --issuer "$APPLE_NOTARY_ISSUER_ID" || true
    if [[ -f "$NOTARY_LOG_PATH" ]]; then
      echo "Saved Apple notarization log to $NOTARY_LOG_PATH" >&2
    fi
    echo "Apple notarization returned status '${NOTARY_STATUS}'." >&2
    exit 1
    ;;
  *)
    xcrun notarytool log \
      "$NOTARY_SUBMISSION_ID" \
      "$NOTARY_LOG_PATH" \
      --key "$NOTARY_KEY_PATH" \
      --key-id "$APPLE_NOTARY_KEY_ID" \
      --issuer "$APPLE_NOTARY_ISSUER_ID" || true
    if [[ -f "$NOTARY_LOG_PATH" ]]; then
      echo "Saved Apple notarization log to $NOTARY_LOG_PATH" >&2
    fi
    echo "Apple notarization returned unexpected status '${NOTARY_STATUS:-unknown}'." >&2
    exit 1
    ;;
esac
