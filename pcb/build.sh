#!/usr/bin/env bash
# Builds the carrier board end to end:
#   place parts (generate_pcb.py) -> autoroute (Freerouting) -> GND pour -> DRC
#   -> Gerbers + drill (fab/), renders (renders/)
#
# Three boards are built side by side:
#   tht       pcb/rc-crane-carrier.kicad_pcb                 everything through-hole, hand soldered
#   smd       pcb/smd/rc-crane-carrier-smd.kicad_pcb         SMD parts assembled by JLCPCB, connectors by hand
#   advanced  pcb/advanced/rc-crane-advanced.kicad_pcb       ESP32-S3, 4 drivers, 16 PWM outputs (SMD)
#   stack     pcb/advanced-stack/{top,bottom}/rc-crane-stack-*.kicad_pcb   the same as two stacked boards
#
# Needs KiCad 10 and Java 21+. Freerouting is downloaded on first run.
#   ./pcb/build.sh                 # all boards, full rebuild (re-routes)
#   ./pcb/build.sh smd             # one variant
#   ./pcb/build.sh smd outputs     # only DRC, fab files and renders from the existing board

set -euo pipefail
cd "$(dirname "$0")"

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

CACHE=$PWD/.cache
mkdir -p "$CACHE"

build() {  # build <variant> <dir> <board name> [outputs]
  local variant=$1 dir=$2 name=$3 mode=${4:-all}
  local BOARD=$dir/$name.kicad_pcb
  echo "######## $variant -> $BOARD"
  GEN_ARGS=()
  case $variant in
    tht|smd) GEN=("$KICAD_PYTHON" generate_pcb.py); GEN_ARGS=("$variant") ;;
    advanced) GEN=("$KICAD_PYTHON" advanced/generate_advanced.py) ;;
    stack-top) GEN=("$KICAD_PYTHON" advanced-stack/generate_stack.py top) ;;
    stack-bottom) GEN=("$KICAD_PYTHON" advanced-stack/generate_stack.py bottom) ;;
  esac
  mkdir -p "$dir/fab" "$dir/renders"

  if [[ "$mode" != "outputs" ]]; then
    JAR=$CACHE/freerouting-$FREEROUTING_VERSION.jar
    if [[ ! -f $JAR ]]; then
      echo "Downloading Freerouting $FREEROUTING_VERSION"
      curl -fsSL -o "$JAR" \
        "https://github.com/freerouting/freerouting/releases/download/v$FREEROUTING_VERSION/freerouting-$FREEROUTING_VERSION.jar"
    fi

    echo "== Place"
    "${GEN[@]}" place "$BOARD" "$CACHE/board.dsn" ${GEN_ARGS[@]+"${GEN_ARGS[@]}"}
    echo "== Route"
    java -jar "$JAR" -de "$CACHE/board.dsn" -do "$CACHE/board.ses" -mp 100 2>&1 \
      | grep -E "Auto-routing stage completed" | sed 's/.*final score/final score/'
    echo "== Pour"
    "${GEN[@]}" finish "$BOARD" "$CACHE/board.ses"
  fi

  echo "== DRC"
  "$KICAD_CLI" pcb drc --severity-all --exit-code-violations -o "$CACHE/drc.rpt" "$BOARD" \
    || { cat "$CACHE/drc.rpt"; exit 1; }

  echo "== Fab files"
  rm -rf "$dir/fab/gerbers"
  "$KICAD_CLI" pcb export gerbers -o "$dir/fab/gerbers/" \
    --layers F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts "$BOARD" >/dev/null
  "$KICAD_CLI" pcb export drill -o "$dir/fab/gerbers/" --format excellon --excellon-separate-th "$BOARD" >/dev/null
  (cd "$dir/fab/gerbers" && rm -f "../$name-gerbers.zip" && zip -qr "../$name-gerbers.zip" .)

  echo "== Renders"
  for side in top bottom; do
    "$KICAD_CLI" pcb render --side "$side" --quality high --width 1600 --height 1100 \
      --background opaque -o "$dir/renders/board_$side.png" "$BOARD" >/dev/null
  done
  "$KICAD_CLI" pcb render --side top --perspective --rotate "-35,0,25" --zoom 0.9 --quality high \
    --width 1600 --height 1100 --background opaque -o "$dir/renders/board_3d.png" "$BOARD" >/dev/null
  "$KICAD_CLI" pcb render --side bottom --perspective --rotate "35,0,-25" --zoom 0.9 --quality high \
    --width 1600 --height 1100 --background opaque -o "$dir/renders/board_3d_bottom.png" "$BOARD" >/dev/null

  # layout drawings (GitHub shows SVG directly)
  "$KICAD_CLI" pcb export svg --mode-single --fit-page-to-board --exclude-drawing-sheet \
    --layers F.Cu,F.Silkscreen,Edge.Cuts -o "$dir/renders/layout_front.svg" "$BOARD" >/dev/null
  "$KICAD_CLI" pcb export svg --mode-single --fit-page-to-board --exclude-drawing-sheet --mirror \
    --layers B.Cu,B.Silkscreen,Edge.Cuts -o "$dir/renders/layout_back.svg" "$BOARD" >/dev/null

  echo "Done: $dir/fab/$name-gerbers.zip, $dir/renders/, $dir/bom.csv"
}

variants=(tht smd advanced stack-top stack-bottom)
mode=all
for arg in "$@"; do
  case $arg in
    tht|smd|advanced) variants=("$arg") ;;
    stack) variants=(stack-top stack-bottom) ;;
    outputs) mode=outputs ;;
    *) echo "unknown argument: $arg"; exit 2 ;;
  esac
done
for v in "${variants[@]}"; do
  case $v in
    tht) build tht . rc-crane-carrier "$mode" ;;
    smd) build smd smd rc-crane-carrier-smd "$mode" ;;
    advanced) build advanced advanced rc-crane-advanced "$mode" ;;
    stack-top) build stack-top advanced-stack/top rc-crane-stack-top "$mode" ;;
    stack-bottom) build stack-bottom advanced-stack/bottom rc-crane-stack-bottom "$mode" ;;
  esac
done
