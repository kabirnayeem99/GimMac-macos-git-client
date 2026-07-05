#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="GimMac"
SCHEME="${SCHEME:-GimMac}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.derivedData}"
PROJECT_FILE="$ROOT_DIR/${PROJECT_NAME}.xcodeproj"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
BUNDLE_ID="io.github.kabirnayeem99.gimmac"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f "$ROOT_DIR/project.yml" ]]; then
  echo "error: project.yml not found at repo root." >&2
  exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "error: failed to generate $PROJECT_FILE" >&2
  exit 1
fi

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/${PROJECT_NAME}.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: built app not found at $BUILT_APP" >&2
  exit 1
fi

INSTALLED_APP="$INSTALL_DIR/${PROJECT_NAME}.app"

echo "==> Stopping running instance (if any)"
pgrep -f "${INSTALLED_APP}/Contents/MacOS/${PROJECT_NAME}" | xargs -r kill >/dev/null 2>&1 || true
sleep 0.5

echo "==> Installing to $INSTALLED_APP"
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALL_DIR/"

echo "==> Removing quarantine attribute"
xattr -dr com.apple.quarantine "$INSTALLED_APP" 2>/dev/null || true

echo "==> Launching $INSTALLED_APP"
open -n "$INSTALLED_APP"

echo "==> Done. Installed $BUNDLE_ID at $INSTALLED_APP"
