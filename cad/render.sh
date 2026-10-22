#!/usr/bin/env bash
# Renders the printable STLs and the PNG previews from the OpenSCAD sources.
# Used locally and by .github/workflows/render-cad.yml (there under xvfb-run,
# since PNG export needs an OpenGL context).
#
#   ./cad/render.sh            # everything
#   OPENSCAD=/path/to/openscad ./cad/render.sh

set -euo pipefail
cd "$(dirname "$0")"

OPENSCAD=${OPENSCAD:-openscad}
STL_DIR=stl
PNG_DIR=renders
mkdir -p "$STL_DIR" "$PNG_DIR"

stl() {  # stl <source.scad> <part> <output.stl>
  echo "STL  $3"
  "$OPENSCAD" --hardwarnings -o "$STL_DIR/$3" -D "part=\"$2\"" "$1"
  # OpenSCAD writes facets in a random order; sort them so unchanged geometry
  # gives a byte-identical file and CI only commits real changes
  python3 -I - "$STL_DIR/$3" <<'EOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
facets = re.findall(r"  facet .*?endfacet\n", text, re.S)
head = text[:text.index("\n") + 1]
tail = text[text.rindex("endsolid"):]
open(path, "w").write(head + "".join(sorted(facets)) + tail)
EOF
}

png() {  # png <source.scad> <output.png> <camera> [-D overrides...]
  local src=$1 out=$2 camera=$3
  shift 3
  echo "PNG  $out"
  "$OPENSCAD" --hardwarnings -o "$PNG_DIR/$out" --camera="$camera" --imgsize=1200,700 \
    --colorscheme=Tomorrow -D animate=false "$@" "$src"
}

# --- enclosed actuator: printable parts
for part in tray lid ram; do
  stl actuator_housing.scad "$part" "actuator_$part.stl"
done

# --- enclosed actuator: previews
png actuator_housing.scad actuator_housing_section.png  55,0,0,70,0,20,260  -D extension=0
png actuator_housing.scad actuator_housing_extended.png 90,0,0,60,0,25,380  -D extension=75 -D section=false -D show_lid=true
png actuator_housing.scad actuator_housing_side.png     70,0,0,90,0,0,330   -D extension=40 --projection=o
for part in tray lid ram; do
  png actuator_housing.scad "actuator_$part.png" 60,0,8,55,0,330,280 -D "part=\"$part\""
done

# --- DIAG wire illustration for the carrier PCB
png diag_wire_example.scad diag_wire_example.png 16,-18,18,62,0,300,125

# --- crane concept
png crane.scad crane.png                  40,0,80,60,0,40,820   -D boom_angle=30 -D tele_ext=25
png crane.scad crane_side_retracted.png   50,0,135,90,0,0,760   -D boom_angle=0  -D tele_ext=0  -D slew_angle=0 --projection=o
png crane.scad crane_side_extended.png    50,0,135,90,0,0,760   -D boom_angle=55 -D tele_ext=30 -D slew_angle=0 --projection=o
