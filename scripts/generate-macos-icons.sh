#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INPUT_PATH="${1:-}"
if [[ -z "$INPUT_PATH" ]]; then
  echo "usage: $0 <source.png|source.icon>" >&2
  exit 1
fi

if [[ ! -e "$INPUT_PATH" ]]; then
  echo "error: input path not found: $INPUT_PATH" >&2
  exit 1
fi

resolve_source_png() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "$path"
    return
  fi
  if [[ -d "$path" ]]; then
    local png
    png="$(find "$path" -type f -iname "*.png" | head -n 1 || true)"
    if [[ -n "$png" ]]; then
      echo "$png"
      return
    fi
  fi
  echo ""
}

SOURCE_PNG="$(resolve_source_png "$INPUT_PATH")"
if [[ -z "$SOURCE_PNG" ]]; then
  echo "error: could not resolve a PNG source from: $INPUT_PATH" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required (macOS built-in)." >&2
  exit 1
fi

ASSETS_DIR="$ROOT_DIR/Sources/GimMac/Resources/Assets.xcassets"
APPICON_DIR="$ASSETS_DIR/AppIcon.appiconset"
mkdir -p "$APPICON_DIR"

resize_icon() {
  local size="$1"
  local out="$2"
  sips -z "$size" "$size" "$SOURCE_PNG" --out "$APPICON_DIR/$out" >/dev/null
}

# macOS required icon representations
resize_icon 16 "icon_16x16.png"
resize_icon 32 "icon_16x16@2x.png"
resize_icon 32 "icon_32x32.png"
resize_icon 64 "icon_32x32@2x.png"
resize_icon 128 "icon_128x128.png"
resize_icon 256 "icon_128x128@2x.png"
resize_icon 256 "icon_256x256.png"
resize_icon 512 "icon_256x256@2x.png"
resize_icon 512 "icon_512x512.png"
resize_icon 1024 "icon_512x512@2x.png"

cat > "$ASSETS_DIR/Contents.json" <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "$APPICON_DIR/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png",      "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",      "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "Generated macOS AppIcon.appiconset from: $SOURCE_PNG"
echo "Output: $APPICON_DIR"
