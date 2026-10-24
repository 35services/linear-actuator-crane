# CAD

OpenSCAD sources for the RC crane and the enclosed linear actuators. Every image and STL
in this folder is generated from the `.scad` files by [`render.sh`](render.sh). The
[Render CAD](../.github/workflows/render-cad.yml) GitHub Action re‑runs it on every push
that changes the CAD and commits the updated files, so they always match the sources.

| File | What it is |
|------|------------|
| [`crane.scad`](crane.scad) | Concept model: RC vehicle, turntable, telescopic boom, lift and telescope actuators. Not printable, used to check the geometry |
| [`actuator_housing.scad`](actuator_housing.scad) | 3D printable enclosure that turns the 15 mm mini stepper slider into an enclosed ram actuator |
| [`actuator_28byj.scad`](actuator_28byj.scad) | The cheap variant: 3D printable lead screw actuator around a 28BYJ‑48 geared stepper |
| [`actuator_common.scad`](actuator_common.scad) | Pieces both housings share: lid ears with gussets, rear mounting boss, insert holes, section cut |
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

## 28BYJ-48 lead screw actuator – `actuator_28byj.scad`

The cheap variant: a 28BYJ‑48 geared stepper (under €2 with its driver board) turns a T8 lead
screw. It's built like the slider housing (tray + lid + square ram, M3 inserts at both ends,
the same shared pieces from `actuator_common.scad`). How it compares to the other actuators:
[`docs/actuator_comparison.md`](../docs/actuator_comparison.md).

![28BYJ section](renders/actuator_28byj_section.png)

| Side section, ram 40 mm out | Fully extended, lid on |
|---|---|
| ![side](renders/actuator_28byj_side.png) | ![extended](renders/actuator_28byj_extended.png) |

* **Drive train:** motor → printed **coupler** (5 mm D‑shaft to 8 mm screw) → **688 bearing**
  → T8 screw. The coupler and a printed **collar** clamp the screw to the bearing's inner ring
  from both sides, so all push and pull loads go into the housing and the motor's plastic
  gearbox only turns the screw.
* **Ram:** square printed bar, the T8 flange nut is screwed to its rear face. The square
  stops it from turning.
* **Motor:** clamped between tray and lid, its mounting ears sit in slots. The shaft is
  8 mm off the motor's centre, so the motor hangs below the screw.
* **Home sensor:** a 5 × 2 mm magnet in the ram's bottom face and a hall sensor (A3144,
  TO‑92) in a pocket under the floor detect the retracted end – with any driver
  (`home_sensor = false` removes both pockets).
* **Size:** 182 mm retracted, 257 mm extended (75 mm stroke), housing 30 × 30 mm, motor
  block 34 mm wide (plus ears), 43 mm high. Stroke, screw lead and all part sizes are
  parameters at the top of the file.
* **Speed and force (console output):** ≈ 2.7 mm/s and ≈ 14 N with a T8×8 screw at 20 rpm;
  T8×2 is 4 × slower and ≈ 4 × stronger. 256 full steps per mm with T8×8.
* **Checked for collisions** at retracted, half and full extension (`part = "collide"`
  shows any overlap).

**Printable parts** (as exported, no supports needed):

| Tray | Lid | Ram | Coupler | Collar |
|---|---|---|---|---|
| ![tray](renders/actuator_28byj_tray.png) | ![lid](renders/actuator_28byj_lid.png) | ![ram](renders/actuator_28byj_ram.png) | ![coupler](renders/actuator_28byj_coupler.png) | ![collar](renders/actuator_28byj_collar.png) |
| [`.stl`](stl/actuator_28byj_tray.stl) floor down | [`.stl`](stl/actuator_28byj_lid.stl) flat side down | [`.stl`](stl/actuator_28byj_ram.stl) on its side | [`.stl`](stl/actuator_28byj_coupler.stl) motor end down | [`.stl`](stl/actuator_28byj_collar.stl) big face down |

**Parts:**

| Part | Qty |
|---|---|
| 28BYJ‑48, **5 V** version (bipolar mod for the TMC2209, as shipped for the ULN2003 board) | 1 |
| T8 lead screw, lead 8 mm (T8×8) or 2 mm (T8×2), cut to 115 mm | 1 |
| T8 brass flange nut (22 mm flange) | 1 |
| 688ZZ ball bearing, 8 × 16 × 5 mm | 1 |
| M3 grub screws, 4 mm (2 in the coupler, 1 in the collar) | 3 |
| M3 × 8 screws for the nut flange (self‑tapping into the ram) | 2 |
| M2 × 6 self‑tapping screws for the lid | 8 |
| M3 heat‑set inserts (both ends) | 2 |
| Optional: 5 × 2 mm magnet, A3144 hall sensor, 3‑wire lead | 1 each |

**Assembly:**

1. Press in the heat‑set inserts, glue the magnet into the ram, screw the nut flange onto the
   ram's rear face.
2. Coupler onto the motor shaft (grub screw on a flat), screw into the coupler (grub screw),
   bearing onto the screw against the coupler's shoulder, collar against the bearing (grub
   screw). There must be no axial play.
3. Turn the screw into the nut.
4. Into the tray: motor with its ears in the slots, bearing into its seat, ram into the guide.
   Hall sensor into the floor pocket, wires out through the hole under the motor.
5. Lid on, 8 × M2.

**Firmware (TMC2209):** `FULL_STEPS_PER_REV = 2048` (the gearbox is included), `SCREW_LEAD_MM = 8`,
run current about 100 mA. With the ULN2003 board it needs different firmware (4 coil
signals per motor), see the [comparison](../docs/actuator_comparison.md#28byj-48-end-stops-uln2003-boards-and-4-motors).

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
