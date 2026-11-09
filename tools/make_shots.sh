#!/usr/bin/env bash
# Renders a real frame natively and writes assets/screenshots/01-play.png (the full 384x216 screen,
# scaled 3x) and assets/portal.png (480x360, the map view cropped, for the oeuvre-of-splorr portal).
# Needs Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."
D="$(mktemp -d)"
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:DUMP_PLAY="$D/play.ppm" \
	-define:ODIN_TEST_NAMES=game.test_dump_play >/dev/null
python3 -I - "$D/play.ppm" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1])
im.resize((384 * 3, 216 * 3), Image.NEAREST).save("assets/screenshots/01-play.png")
# The map view is 252x180 at the top left; take a 4:3 240x180 window from its middle, doubled.
im.crop((6, 0, 246, 180)).resize((480, 360), Image.NEAREST).save("assets/portal.png")
print("assets/screenshots/01-play.png, assets/portal.png")
PY
rm -rf "$D"
