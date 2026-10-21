#!/usr/bin/env bash
# Regenerates the level emblems (also the app icons) in the asset catalog.
# Needs Python 3 with Pillow, Node, and Playwright with Chromium
# (set NODE_PATH to wherever Playwright is installed).
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD=Design/build
ASSETS=Stride/Assets.xcassets
rm -rf "$BUILD" && mkdir -p "$BUILD"

python3 Design/emblems.py "$BUILD"
node Design/render.mjs "$BUILD" 1024 1024 "$BUILD"/emblem-*.svg

for n in $(seq 1 10); do
  # App icon: tier 1 is the main icon, the rest are alternates.
  name=$([ "$n" = 1 ] && echo "AppIcon" || echo "AppIcon$n")
  dir="$ASSETS/$name.appiconset"
  mkdir -p "$dir"
  python3 -c "from PIL import Image; Image.open('$BUILD/emblem-$n.png').convert('RGB').save('$dir/$name.png')"
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

  # The same artwork for use inside the app.
  dir="$ASSETS/Emblem$n.imageset"
  mkdir -p "$dir"
  python3 -c "from PIL import Image; Image.open('$BUILD/emblem-$n.png').convert('RGB').resize((512, 512), Image.LANCZOS).save('$dir/Emblem$n.png')"
  cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "Emblem$n.png",
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
