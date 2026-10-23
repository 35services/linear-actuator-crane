# CAD

OpenSCAD sources for the RC crane and the enclosed linear actuator. Every image and STL
in this folder is generated from the `.scad` files by [`render.sh`](render.sh). The
[Render CAD](../.github/workflows/render-cad.yml) GitHub Action re‑runs it on every push
that changes the CAD and commits the updated files, so they always match the sources.

| File | What it is |
|------|------------|
| [`crane.scad`](crane.scad) | Concept model: RC vehicle, turntable, telescopic boom, lift and telescope actuators. Not printable, used to check the geometry |
| [`actuator_housing.scad`](actuator_housing.scad) | 3D printable enclosure that turns the 15 mm mini stepper slider into an enclosed ram actuator |
| [`diag_wire_example.scad`](diag_wire_example.scad) | Illustration: the DIAG jumper wire from a TMC2209 module to the carrier PCB |
| [`stl/`](stl) | Printable parts, already turned for printing |
| [`renders/`](renders) | The images below |
| [`render.sh`](render.sh) | Regenerates `stl/` and `renders/` |

---

## Crane concept – `crane.scad`

![crane overview](renders/crane.png)

| Boom down, telescope in | Boom up 55°, telescope out |
|---|---|
| ![crane retracted](renders/crane_side_retracted.png) | ![crane extended](renders/crane_side_extended.png) |

* **Actuators:** both are the enclosed actuator from `actuator_housing.scad` (132.5 mm
  retracted, 75 mm stroke), included with `use <actuator_housing.scad>`.
* **Lift actuator:** sits between the mast plates and raises the boom through a short
  pushrod to a hanger under the boom. 0 → 55° uses 49.6 mm of the stroke.
* **Telescope actuator:** lies on top of the boom. Its ram pushes a bracket on the front of
  the inner section, for 75 mm of extension (reach 155–230 mm).
* **Console output:** the stroke the lift geometry needs, the reach, the tip‑force ratio
  for the current pose, and the speeds for `step_rate` (full steps/s): at 800 full steps/s
  the actuator runs 20 mm/s, the boom goes 0 → 55° in 2.5 s. Details in the
  [main README](../README.md#speed-how-fast-can-it-move).
* **Animation:** View → Animate (FPS 10, Steps 60) moves both axes together.

---

## Enclosed actuator – `actuator_housing.scad`

![housing section](renders/actuator_housing_section.png)

| Side section, ram half out | Fully extended, lid on |
|---|---|
| ![housing side](renders/actuator_housing_side.png) | ![housing extended](renders/actuator_housing_extended.png) |

* **Tray:** holds the motor in a cradle. The frame sits on a rib along the floor.
* **Ram:** slides around the frame. The slider's tab sits in a slot in the ram's ceiling,
  and a 1.75 mm filament pin behind the tab pulls the ram back in.
* **Mounting:** both ends take an M3 heat‑set insert for RC ball links.
* **Lead screw:** M3, 0.5 mm lead, about 172 turns on 86.6 mm, counted on the
  [listing photo](../docs/actuator_photo.png). That gives the 75 mm stroke.

**Printable parts** (as exported, no supports needed):

| Tray | Lid | Ram |
|---|---|---|
| ![tray](renders/actuator_tray.png) | ![lid](renders/actuator_lid.png) | ![ram](renders/actuator_ram.png) |
| [`actuator_tray.stl`](stl/actuator_tray.stl) | [`actuator_lid.stl`](stl/actuator_lid.stl) | [`actuator_ram.stl`](stl/actuator_ram.stl) |
| floor down | flat side down | on its side, layers along the length |

The parts list, assembly steps and the dimensions to measure are in the
[main README](../README.md#enclosed-actuator-housing-3d-printed).

---

## DIAG jumper wire – `diag_wire_example.scad`

![DIAG wire](renders/diag_wire_example.png)

* **What DIAG is:** the TMC2209 pulls its DIAG pin high when the motor stalls. That's how
  homing works without end switches.
* **Why a wire:** DIAG isn't one of the 16 socket pins. On most modules it's a separate pin
  on the board, and its position differs between brands.
* **How:** a short female‑to‑male Dupont jumper connects it to the single socket next to the
  driver:
  * driver #0 (lift) → **J12**
  * driver #1 (telescope) → **J13**

The module here is a generic mock. Its pot (VREF) is unused with UART current control.

---

## Regenerating locally

```bash
./cad/render.sh
```

This needs OpenSCAD 2021.01 or newer and `python3`. STL triangles are sorted after export,
so unchanged geometry produces byte‑identical files and git only shows real changes.

To export a single part by hand:

```bash
openscad -o ram.stl -D 'part="ram"' cad/actuator_housing.scad
```
