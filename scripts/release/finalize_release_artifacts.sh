#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-${RUNNER_TEMP:-$ROOT_DIR/.release-work}/codex-account-hub-release-finalize}"
NOTARY_METADATA_PATH="${NOTARY_METADATA_PATH:-$DIST_DIR/notary-metadata.json}"
NOTARY_WAIT_TIMEOUT="${APPLE_NOTARY_WAIT_TIMEOUT:-30m}"
NOTARY_POLL_INTERVAL="${APPLE_NOTARY_POLL_INTERVAL:-2m}"
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

duration_to_seconds() {
  local duration="$1"

  if [[ "$duration" =~ '^([0-9]+)([smhd])$' ]]; then
    local value="${match[1]}"
    local unit="${match[2]}"

    case "$unit" in
      s)
        echo "$value"
        ;;
      m)
        echo $((value * 60))
        ;;
      h)
        echo $((value * 60 * 60))
        ;;
      d)
        echo $((value * 60 * 60 * 24))
        ;;
    esac
    return 0
  fi

  echo "Unsupported duration format: $duration" >&2
  exit 1
}

require_env "APPLE_NOTARY_KEY_ID"
require_env "APPLE_NOTARY_ISSUER_ID"
require_env "APPLE_NOTARY_API_PRIVATE_KEY"

mkdir -p "$DIST_DIR" "$WORK_DIR"
rm -f "$NOTARY_STATUS_JSON" "$NOTARY_LOG_PATH"
require_file "$NOTARY_METADATA_PATH"

DMG_NAME="$(extract_json_field dmg_name "$NOTARY_METADATA_PATH")"
NOTARY_SUBMISSION_ID="$(extract_json_field submission_id "$NOTARY_METADATA_PATH")"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ -z "$DMG_NAME" || -z "$NOTARY_SUBMISSION_ID" ]]; then
  echo "Notarization metadata is missing dmg_name or submission_id." >&2
  cat "$NOTARY_METADATA_PATH" >&2
  exit 1
fi

require_file "$DMG_PATH"

printf '%s' "$APPLE_NOTARY_API_PRIVATE_KEY" > "$NOTARY_KEY_PATH"
chmod 600 "$NOTARY_KEY_PATH"

echo "Waiting for Apple notarization:"
echo "  id: $NOTARY_SUBMISSION_ID"
echo "  dmg: $DMG_PATH"
echo "  timeout: $NOTARY_WAIT_TIMEOUT"
echo "  poll interval: $NOTARY_POLL_INTERVAL"

TIMEOUT_SECONDS="$(duration_to_seconds "$NOTARY_WAIT_TIMEOUT")"
POLL_INTERVAL_SECONDS="$(duration_to_seconds "$NOTARY_POLL_INTERVAL")"
POLL_DEADLINE=$((SECONDS + TIMEOUT_SECONDS))

while true; do
  xcrun notarytool info \
    "$NOTARY_SUBMISSION_ID" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --output-format json > "$NOTARY_STATUS_JSON"

  NOTARY_STATUS="$(extract_json_field status "$NOTARY_STATUS_JSON")"
  NOTARY_MESSAGE="$(extract_json_field message "$NOTARY_STATUS_JSON")"
  CREATED_DATE="$(extract_json_field createdDate "$NOTARY_STATUS_JSON")"
  ELAPSED_SECONDS=$((SECONDS - (POLL_DEADLINE - TIMEOUT_SECONDS)))

  echo "Current Apple notarization status: ${NOTARY_STATUS:-unknown}"
  if [[ -n "$CREATED_DATE" ]]; then
    echo "  created: $CREATED_DATE"
  fi
  if [[ -n "$NOTARY_MESSAGE" ]]; then
    echo "  message: $NOTARY_MESSAGE"
  fi
  echo "  elapsed: ${ELAPSED_SECONDS}s"

  case "$NOTARY_STATUS" in
    Accepted)
      break
      ;;
    Invalid|Rejected)
      break
      ;;
    "In Progress"|"")
      if (( SECONDS >= POLL_DEADLINE )); then
        echo "Apple notarization did not finish within $NOTARY_WAIT_TIMEOUT." >&2
        echo "Submission ID: $NOTARY_SUBMISSION_ID" >&2
        exit 75
      fi
      sleep "$POLL_INTERVAL_SECONDS"
      ;;
    *)
      echo "Apple notarization returned unexpected status '${NOTARY_STATUS}'." >&2
      exit 1
      ;;
  esac
done

if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
  echo "Apple notarization returned status '${NOTARY_STATUS:-unknown}'." >&2
  xcrun notarytool log \
    "$NOTARY_SUBMISSION_ID" \
    "$NOTARY_LOG_PATH" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" || true
  if [[ -f "$NOTARY_LOG_PATH" ]]; then
    echo "Saved Apple notarization log to $NOTARY_LOG_PATH" >&2
  fi
  exit 1
fi

echo "Apple notarization accepted submission $NOTARY_SUBMISSION_ID."

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Finalized release artifacts:"
echo "  $DMG_PATH"
echo "  $DMG_PATH.sha256"
