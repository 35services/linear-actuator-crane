#!/usr/bin/env bash
# Builds the carrier board end to end:
#   place parts (generate_pcb.py) -> autoroute (Freerouting) -> GND pour -> DRC
#   -> Gerbers + drill (fab/), renders (renders/)
#
# Needs KiCad 10 and Java 21+. Freerouting is downloaded on first run.
#   ./pcb/build.sh             # full rebuild, re-routes the board
#   ./pcb/build.sh outputs     # only DRC, fab files and renders from the existing board

set -euo pipefail
cd "$(dirname "$0")"

BOARD=rc-crane-carrier.kicad_pcb
FREEROUTING_VERSION=2.5.0

if [[ "$(uname)" == "Darwin" ]]; then
  KICAD=/Applications/KiCad/KiCad.app/Contents
  KICAD_PYTHON=${KICAD_PYTHON:-$KICAD/Frameworks/Python.framework/Versions/Current/bin/python3}
  KICAD_CLI=${KICAD_CLI:-$KICAD/MacOS/kicad-cli}
else
  KICAD_PYTHON=${KICAD_PYTHON:-python3}
  KICAD_CLI=${KICAD_CLI:-kicad-cli}
  export KICAD_FOOTPRINT_DIR=${KICAD_FOOTPRINT_DIR:-/usr/share/kicad/footprints}
fi

CACHE=.cache
mkdir -p "$CACHE" fab renders

if [[ "${1:-all}" != "outputs" ]]; then
  JAR=$CACHE/freerouting-$FREEROUTING_VERSION.jar
  if [[ ! -f $JAR ]]; then
    echo "Downloading Freerouting $FREEROUTING_VERSION"
    curl -fsSL -o "$JAR" \
      "https://github.com/freerouting/freerouting/releases/download/v$FREEROUTING_VERSION/freerouting-$FREEROUTING_VERSION.jar"
  fi

  echo "== Place"
  "$KICAD_PYTHON" generate_pcb.py place "$BOARD" "$CACHE/board.dsn"
  echo "== Route"
  java -jar "$JAR" -de "$CACHE/board.dsn" -do "$CACHE/board.ses" -mp 100 2>&1 \
    | grep -E "Auto-routing stage completed" | sed 's/.*final score/final score/'
  echo "== Pour"
  "$KICAD_PYTHON" generate_pcb.py finish "$BOARD" "$CACHE/board.ses"
fi

echo "== DRC"
"$KICAD_CLI" pcb drc --severity-all --exit-code-violations -o "$CACHE/drc.rpt" "$BOARD" \
  || { cat "$CACHE/drc.rpt"; exit 1; }

echo "== Fab files"
rm -rf fab/gerbers
"$KICAD_CLI" pcb export gerbers -o fab/gerbers/ \
  --layers F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts "$BOARD" >/dev/null
"$KICAD_CLI" pcb export drill -o fab/gerbers/ --format excellon --excellon-separate-th "$BOARD" >/dev/null
(cd fab/gerbers && rm -f ../rc-crane-carrier-gerbers.zip && zip -qr ../rc-crane-carrier-gerbers.zip .)

echo "== Renders"
for side in top bottom; do
  "$KICAD_CLI" pcb render --side "$side" --quality high --width 1600 --height 1100 \
    --background opaque -o "renders/board_$side.png" "$BOARD" >/dev/null
done
"$KICAD_CLI" pcb render --side top --perspective --rotate "-35,0,25" --zoom 0.9 --quality high \
  --width 1600 --height 1100 --background opaque -o renders/board_3d.png "$BOARD" >/dev/null

echo "Done: fab/rc-crane-carrier-gerbers.zip, renders/, bom.csv"
