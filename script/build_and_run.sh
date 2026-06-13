#!/usr/bin/env bash
set -euo pipefail

RAW_MODE="${1:-run}"
MODE="$RAW_MODE"
MOCK_MODE=0
APP_NAME="RemoteInfo"
BUNDLE_ID="dev.firegnu.RemoteInfo"
MIN_SYSTEM_VERSION="14.0"
MOCK_MODE_ENV_KEY="REMOTE_INFO_MOCK_MODE"

case "$RAW_MODE" in
  --mock|mock)
    MODE="run"
    MOCK_MODE=1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_NAME="AppIcon.icns"
APP_ICON_SOURCE="$ROOT_DIR/Resources/$APP_ICON_NAME"
INSTALL_DIR="/Applications"
INSTALLED_APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/$APP_ICON_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIconFile</key>
  <string>${APP_ICON_NAME%.icns}</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  local bundle_path="${1:-$APP_BUNDLE}"

  if [[ "$MOCK_MODE" == "1" ]]; then
    /usr/bin/open --env "$MOCK_MODE_ENV_KEY=1" -n "$bundle_path"
  else
    /usr/bin/open -n "$bundle_path"
  fi
}

verify_bundle_metadata() {
  [[ -x "$APP_BINARY" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")" == "$APP_NAME" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")" == "$BUNDLE_ID" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")" == "${APP_ICON_NAME%.icns}" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST")" == "true" ]]
  [[ -f "$APP_RESOURCES/$APP_ICON_NAME" ]]
}

install_app() {
  verify_bundle_metadata

  rm -rf "$INSTALLED_APP_BUNDLE"
  cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
  xattr -dr com.apple.quarantine "$INSTALLED_APP_BUNDLE" >/dev/null 2>&1 || true
  [[ -x "$INSTALLED_APP_BUNDLE/Contents/MacOS/$APP_NAME" ]]
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    verify_bundle_metadata
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --install|install)
    install_app
    open_app "$INSTALLED_APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--mock|--debug|--logs|--telemetry|--verify|--install]" >&2
    exit 2
    ;;
esac
