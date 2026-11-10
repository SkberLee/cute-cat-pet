#!/usr/bin/env bash
# Regenerate pixel art, resave .aseprite via LibreSprite, rebuild previews.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
ASE="${ASE:-/home/box/bin/aseprite}"
python3 assets/pixel/tools/gen_pixel.py
find assets/pixel -name '*.aseprite' -print0 | sort -z | while IFS= read -r -d '' f; do
  "$ASE" -b "$f" --script assets/pixel/tools/finalize.js --save-as "$f"
done
python3 assets/pixel/tools/compose_preview.py
echo "rebuild done"
