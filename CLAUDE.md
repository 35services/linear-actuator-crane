# Working on this repo

## Images and animations

- **Everything that moves gets an animated GIF.** When a CAD model has motion (its `$t`
  animation: an actuator extending, legs deploying, a boom luffing), add a `gif` line to
  [`cad/render.sh`](cad/render.sh) and show the GIF in every README that describes the model,
  next to the still images. Static poses and printable parts stay PNGs.
- All CAD images, GIFs and STLs come from `cad/render.sh`. The *Render CAD* GitHub Action
  re-renders them on Linux and commits them. Don't commit local macOS re-renders of unchanged
  PNGs/GIFs (they differ only by rendering); new ones are fine, CI replaces them.
- STLs must stay byte-identical when the geometry doesn't change (render.sh sorts the facets):
  use that to prove a refactor changed nothing.

## Checks before committing

- **Mechanisms:** check moving parts for collisions at several poses (intersection must be
  empty) and include a positive control that makes sure the check can fail. Put the numbers
  that matter (stroke, travel, bend radii, forces, times) in the model's `echo` output and
  quote them in the README.
- **PCBs:** `./pcb/build.sh <board>` must end with DRC 0 violations, 0 unconnected.
- **Firmware:** compile with arduino-cli for the ESP32-C3; rebuild the web preview with
  `python3 firmware/web_preview/build_preview.py` when settings change.

## Workflow

- Commit and push after each verified step. Other sessions work in this repo too: fetch and
  rebase before pushing, and merge finished worktree branches into `main`.
