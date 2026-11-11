#!/usr/bin/env bash
# Renders real frames natively (the frame-dump tests in src/game/dump_test.odin) and writes the
# screenshots in assets/screenshots/ (the full 384x216 screen, scaled 3x) and assets/portal.png
# (480x360, the map view cropped, for the oeuvre-of-splorr portal). Needs Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."
D="$(mktemp -d)"
dump() { # test name, then -define arguments
	local name="$1"
	shift
	odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 "$@" -define:ODIN_TEST_NAMES="game.$name" >/dev/null 2>&1
}
dump test_dump_play -define:DUMP_PLAY="$D/play.ppm"
dump test_dump_town -define:DUMP_TOWN="$D/town"
dump test_dump_fight -define:DUMP_FIGHT="$D/fight.ppm"
dump test_dump_magic -define:DUMP_MAGIC="$D/magic"
dump test_dump_supplies -define:DUMP_SUPPLIES="$D/supplies"
dump test_dump_boss -define:DUMP_BOSS="$D/boss"
python3 -I - "$D" <<'PY'
import os, sys
from PIL import Image
d = sys.argv[1]
shots = [
    ("01-play.png", "play.ppm"),
    ("02-town.png", "town-street.ppm"),
    ("03-shop.png", "town-smith.ppm"),
    ("04-fight.png", "fight.ppm"),
    ("05-magic.png", "magic-bolt.ppm"),
    ("06-inventory.png", "supplies-inv.ppm"),
    ("07-horde.png", "boss-hall.ppm"),
]
for out, src in shots:
    Image.open(os.path.join(d, src)).resize((384 * 3, 216 * 3), Image.NEAREST).save("assets/screenshots/" + out)
# The map view is 252x180 at the top left; take a 4:3 240x180 window from its middle, doubled.
Image.open(os.path.join(d, "play.ppm")).crop((6, 0, 246, 180)).resize((480, 360), Image.NEAREST).save("assets/portal.png")
print(", ".join("assets/screenshots/" + o for o, _ in shots) + ", assets/portal.png")
PY
rm -rf "$D"
