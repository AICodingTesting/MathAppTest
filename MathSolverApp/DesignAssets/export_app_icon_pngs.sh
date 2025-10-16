#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <source-svg> <appiconset-dir>" >&2
  exit 1
fi

SRC=$1
DEST=$2

if [[ ! -f "$SRC" ]]; then
  echo "Source SVG '$SRC' not found" >&2
  exit 2
fi

if [[ ! -d "$DEST" ]]; then
  echo "Destination app icon set '$DEST' not found" >&2
  exit 3
fi

command -v sips >/dev/null 2>&1 || {
  echo "This script requires the macOS 'sips' utility." >&2
  exit 4
}

sizes=(
  "20x20@1x"
  "20x20@2x"
  "20x20@3x"
  "29x29@1x"
  "29x29@2x"
  "29x29@3x"
  "40x40@1x"
  "40x40@2x"
  "40x40@3x"
  "60x60@2x"
  "60x60@3x"
  "76x76@1x"
  "76x76@2x"
  "83.5x83.5@2x"
  "1024x1024@1x"
)

pushd "$DEST" >/dev/null
rm -f Icon-App-*.png
popd >/dev/null

for spec in "${sizes[@]}"; do
  size=${spec%%@*}
  scale=${spec##*@}
  filename="Icon-App-${size}@${scale}.png"
  base_pixels=${size%x*}
  scale_factor=${scale%x}

  if [[ $size == "83.5x83.5" ]]; then
    pixels=167
  else
    pixels=$((base_pixels * scale_factor))
  fi

  sips -s format png -z "$pixels" "$pixels" "$SRC" --out "$DEST/$filename" >/dev/null
  echo "Generated $filename"
done
