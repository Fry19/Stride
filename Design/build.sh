#!/usr/bin/env bash
# Regenerates the shoe images, app icons and icon previews in the asset catalog.
# Needs Python 3 with Pillow, Node, and Playwright with Chromium
# (set NODE_PATH to wherever Playwright is installed).
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD=Design/build
ASSETS=Stride/Assets.xcassets
rm -rf "$BUILD" && mkdir -p "$BUILD"

python3 Design/shoes.py "$BUILD"
node Design/render.mjs "$BUILD" 1100 600 "$BUILD"/shoe-*.svg
node Design/render.mjs "$BUILD" 1024 1024 "$BUILD"/icon-*.svg

for n in $(seq 1 10); do
  # In-app shoe image.
  dir="$ASSETS/Shoe$n.imageset"
  mkdir -p "$dir"
  cp "$BUILD/shoe-$n.png" "$dir/Shoe$n.png"
  cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "Shoe$n.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

  # App icon: tier 1 is the main icon, the rest are alternates.
  name=$([ "$n" = 1 ] && echo "AppIcon" || echo "AppIcon$n")
  dir="$ASSETS/$name.appiconset"
  mkdir -p "$dir"
  python3 -c "from PIL import Image; Image.open('$BUILD/icon-$n.png').convert('RGB').save('$dir/$name.png')"
  cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

  # Small copy of the icon for the in-app icon picker.
  dir="$ASSETS/IconPreview$n.imageset"
  mkdir -p "$dir"
  python3 -c "from PIL import Image; Image.open('$BUILD/icon-$n.png').convert('RGB').resize((240, 240), Image.LANCZOS).save('$dir/IconPreview$n.png')"
  cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "IconPreview$n.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
done
echo "Assets updated."
