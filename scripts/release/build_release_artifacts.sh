#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CodexAccountHub.xcodeproj"
SCHEME="CodexAccountHub"
APP_NAME="CodexAccountHub"
APP_DISPLAY_NAME="Codex Account Hub"
CONFIGURATION="Release"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-${RUNNER_TEMP:-$ROOT_DIR/.release-work}/codex-account-hub-release}"
DERIVED_DATA_PATH="$WORK_DIR/DerivedData"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
STAGING_DIR="$WORK_DIR/dmg"
KEYCHAIN_PATH="$WORK_DIR/build.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-ci-temporary-password}"
CERTIFICATE_PATH="$WORK_DIR/developer-id.p12"
EXPORT_OPTIONS_PLIST="$WORK_DIR/ExportOptions.plist"
NOTARY_KEY_PATH="$WORK_DIR/AuthKey_${APPLE_NOTARY_KEY_ID:-unknown}.p8"
NOTARY_WAIT_TIMEOUT="${APPLE_NOTARY_WAIT_TIMEOUT:-15m}"
NOTARY_WAIT_FOR_COMPLETION="${NOTARY_WAIT_FOR_COMPLETION:-true}"
NOTARY_SUBMISSION_JSON="$WORK_DIR/notary-submission.json"
NOTARY_STATUS_JSON="$WORK_DIR/notary-status.json"
NOTARY_LOG_PATH="$WORK_DIR/notary-log.json"
NOTARY_METADATA_PATH="${NOTARY_METADATA_PATH:-$DIST_DIR/notary-metadata.json}"

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

cleanup() {
  if [[ -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_env "APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64"
require_env "APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD"
require_env "APPLE_TEAM_ID"
require_env "APPLE_NOTARY_KEY_ID"
require_env "APPLE_NOTARY_ISSUER_ID"
require_env "APPLE_NOTARY_API_PRIVATE_KEY"

mkdir -p "$DIST_DIR" "$WORK_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$STAGING_DIR"
mkdir -p "$EXPORT_PATH" "$STAGING_DIR"

APP_VERSION="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings |
    awk '/MARKETING_VERSION = / { print $3; exit }'
)"

if [[ -z "$APP_VERSION" ]]; then
  echo "Unable to resolve MARKETING_VERSION from Xcode build settings." >&2
  exit 1
fi

if [[ "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
  TAG_VERSION="${GITHUB_REF_NAME#v}"
  if [[ "$TAG_VERSION" != "$APP_VERSION" ]]; then
    echo "Tag version $TAG_VERSION does not match MARKETING_VERSION $APP_VERSION." >&2
    exit 1
  fi
fi

if ! printf '%s' "$APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64" | base64 -d > "$CERTIFICATE_PATH" 2>/dev/null; then
  printf '%s' "$APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64" | base64 -D > "$CERTIFICATE_PATH"
fi

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productbuild \
  -T /usr/bin/xcodebuild
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH"

printf '%s' "$APPLE_NOTARY_API_PRIVATE_KEY" > "$NOTARY_KEY_PATH"
chmod 600 "$NOTARY_KEY_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
  <key>teamID</key>
  <string>$APPLE_TEAM_ID</string>
</dict>
</plist>
EOF

pushd "$ROOT_DIR/Packages/CodexAuthCore" >/dev/null
swift test
popd >/dev/null

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  test

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH"

APP_PATH="$EXPORT_PATH/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Exported app not found at $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_NAME="$APP_NAME-v$APP_VERSION-macOS.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
rm -f "$DMG_PATH" "$DMG_PATH.sha256"

hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -ov \
  -format UDZO \
  "$DMG_PATH"

codesign \
  --force \
  --sign "Developer ID Application" \
  --keychain "$KEYCHAIN_PATH" \
  --timestamp \
  "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"

xcrun notarytool submit \
  "$DMG_PATH" \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --output-format json > "$NOTARY_SUBMISSION_JSON"

NOTARY_SUBMISSION_ID="$(extract_json_field id "$NOTARY_SUBMISSION_JSON")"

if [[ -z "$NOTARY_SUBMISSION_ID" ]]; then
  echo "Unable to determine Apple notarization submission ID." >&2
  cat "$NOTARY_SUBMISSION_JSON" >&2
  exit 1
fi

echo "Submitted Apple notarization request:"
echo "  id: $NOTARY_SUBMISSION_ID"
echo "  timeout: $NOTARY_WAIT_TIMEOUT"

cat > "$NOTARY_METADATA_PATH" <<EOF
{
  "tag_name": "${GITHUB_REF_NAME:-}",
  "app_version": "$APP_VERSION",
  "dmg_name": "$DMG_NAME",
  "dmg_path": "$DMG_PATH",
  "submission_id": "$NOTARY_SUBMISSION_ID"
}
EOF

echo "Saved notarization metadata to $NOTARY_METADATA_PATH"

if [[ "$NOTARY_WAIT_FOR_COMPLETION" != "true" ]]; then
  echo "Skipping Apple notarization wait. Submission can be resumed later with ID $NOTARY_SUBMISSION_ID."
  exit 0
fi

set +e
xcrun notarytool wait \
  "$NOTARY_SUBMISSION_ID" \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --timeout "$NOTARY_WAIT_TIMEOUT" \
  --output-format json > "$NOTARY_STATUS_JSON"
NOTARY_WAIT_EXIT=$?
set -e

if [[ $NOTARY_WAIT_EXIT -ne 0 ]]; then
  echo "Apple notarization did not finish within $NOTARY_WAIT_TIMEOUT." >&2
  echo "Submission ID: $NOTARY_SUBMISSION_ID" >&2
  xcrun notarytool info \
    "$NOTARY_SUBMISSION_ID" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --output-format json || true
  exit $NOTARY_WAIT_EXIT
fi

NOTARY_STATUS="$(extract_json_field status "$NOTARY_STATUS_JSON")"

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

echo "Created release artifacts:"
echo "  $DMG_PATH"
echo "  $DMG_PATH.sha256"
