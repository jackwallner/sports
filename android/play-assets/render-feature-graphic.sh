#!/bin/zsh
# Renders feature-graphic.svg to feature-graphic.png (1024 x 500, RGB, no alpha).
# Needs Google Chrome and a Python with Pillow (PYTHON=/path/to/python).
set -euo pipefail
cd "${0:A:h}"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp=$(mktemp -d)
"$chrome" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$tmp/profile" \
  --window-size=1024,500 --screenshot="$tmp/raw.png" "file://$PWD/feature-graphic.svg" >/dev/null 2>&1 &
pid=$!
until [[ -s "$tmp/raw.png" ]]; do sleep 1; done
sleep 1
kill $pid 2>/dev/null || true
"${PYTHON:-python3}" -c '
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
assert im.size == (1024, 500), im.size
im.save(sys.argv[2], optimize=True)
' "$tmp/raw.png" feature-graphic.png
rm -rf "$tmp"
