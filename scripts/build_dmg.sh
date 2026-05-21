#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build"
APP_NAME="mmReader.app"
DMG_NAME="mmReader.dmg"
STAGE_DIR="$OUT_DIR/dmg-stage"
APP_DIR="$OUT_DIR/$APP_NAME"
DMG_PATH="$OUT_DIR/$DMG_NAME"
VOLUME_NAME="mmReader"

bash "$ROOT_DIR/scripts/build_app.sh"

if [ ! -d "$APP_DIR" ]; then
  echo "Missing app bundle at $APP_DIR" >&2
  exit 1
fi

rm -rf "$STAGE_DIR" "$DMG_PATH"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE_DIR"

echo "Built: $DMG_PATH"
