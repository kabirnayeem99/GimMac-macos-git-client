#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="GimMac"
SCHEME="${SCHEME:-GimMac}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.derivedData}"
PROJECT_FILE="$ROOT_DIR/${PROJECT_NAME}.xcodeproj"

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
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/${PROJECT_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Launching $APP_PATH"
open "$APP_PATH"
