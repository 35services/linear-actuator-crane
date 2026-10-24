# CAD

OpenSCAD sources for the RC crane and the enclosed linear actuator. Every image and STL
in this folder is generated from the `.scad` files by [`render.sh`](render.sh). The
[Render CAD](../.github/workflows/render-cad.yml) GitHub Action re‑runs it on every push
that changes the CAD and commits the updated files, so they always match the sources.

| File | What it is |
|------|------------|
| [`crane.scad`](crane.scad) | Concept model: RC vehicle, turntable, telescopic boom, lift and telescope actuators. Not printable, used to check the geometry |
| [`actuator_housing.scad`](actuator_housing.scad) | 3D printable enclosure that turns the 15 mm mini stepper slider into an enclosed ram actuator |
| [`n20_actuator.scad`](n20_actuator.scad) | 3D printable enclosure that turns the N20 DC gear motor with M4 lead screw into an enclosed ram actuator |
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

## N20 DC lead screw actuator – `n20_actuator.scad`

The same idea as the enclosed stepper actuator, built around a cheaper DC motor: the
**12GA‑N20 gear motor with an M4 × 100 mm lead screw**
([AliExpress](https://de.aliexpress.com/item/1005006668206749.html), about €5, 3 / 6 / 12 V,
15–1000 RPM). How it compares to the other actuators, and what driving it needs, is in
[`docs/actuator_comparison.md`](../docs/actuator_comparison.md#4-n20-gear-motor-with-m4-lead-screw-in-a-printed-housing).

| Listing photo | Drawing from the listing |
|---|---|
| ![N20 lead screw motor](../docs/actuators/n20_lead_screw.jpg) | ![N20 drawing](../docs/actuators/n20_lead_screw_drawing.jpg) |

![N20 section](renders/n20_actuator_section.png)

| Bulkhead, nut and piston | Fully extended, lid on |
|---|---|
| ![N20 detail](renders/n20_actuator_detail.png) | ![N20 extended](renders/n20_actuator_extended.png) |

![N20 side](renders/n20_actuator_side.png)

* **Motor, from the drawing:** gearbox 12 × 10 × 9 mm with two M1.6 holes 9 mm apart in the
  front plate, can Ø12.1 mm with 10 mm flats, 16 mm long. Screw 100 mm from the front plate,
  the last 4 mm a plain Ø3 tip.
* **Here the screw turns.** On the stepper slider the actuator brings its own nut and guide.
  This motor has neither, so the ram carries a standard **M4 hex nut** in a slot in its square
  piston. The piston slides in a square channel, so the nut can't turn with the screw.
* **Tray:** motor pocket, a **bulkhead** the gearbox screws to (two M1.6 × 2.5 screws in the
  front plate's own holes, heads counterbored on the ram side), the channel, and a **front
  wall** that guides the ram's rod.
* **Hard stops at both ends:** the piston hits the bulkhead when retracted and the front wall
  at 80 mm. The nut stays 6.8 mm from the end of the thread, so it can't run off. A DC motor
  stalls at the stop, and the driver sees the current rise (see the
  [comparison](../docs/actuator_comparison.md#detecting-the-ends-of-a-dc-actuator-with-current-sensing)).
* **Lid:** a tongue at the front closes the opening above the rod.
* **Size:** 151 mm retracted, 231 mm extended (80 mm stroke), housing 143 × 18 × 18 mm
  without the ears. The screw is a plain threaded rod: cut it shorter, and set `screw_len`
  and `stroke`, for a shorter actuator. The file warns if the nut would run off the thread.
* **Same interface** as `actuator_housing.scad` (`enclosed_actuator()`, `act_retracted()`,
  `act_stroke()`, …), so `crane.scad` can try it by changing its `use <…>` line. With the
  full 100 mm screw it's 12.4 mm too long for the boom lift there (the console warns). Cut
  to `screw_len = 87`, `stroke = 67` it is 138 mm long and fits, still more than the
  49.6 mm the lift needs. The telescope takes the full 80 mm version.

**Printable parts** (as exported, no supports needed):

| Tray | Lid | Ram |
|---|---|---|
| ![tray](renders/n20_tray.png) | ![lid](renders/n20_lid.png) | ![ram](renders/n20_ram.png) |
| [`n20_tray.stl`](stl/n20_tray.stl) | [`n20_lid.stl`](stl/n20_lid.stl) | [`n20_ram.stl`](stl/n20_ram.stl) |
| floor down | flat side down | standing on its flat floor, nut slot up |

**Other parts:**

| Part | Qty | Notes |
|------|-----|-------|
| 12GA‑N20 motor, M4 × 100 mm screw | 1 | 6 V version for the BEC, see the [comparison](../docs/actuator_comparison.md#4-n20-gear-motor-with-m4-lead-screw-in-a-printed-housing) for the RPM |
| M4 hex nut (DIN 934, 7 mm AF, 3.2 mm) | 1 | brass if you can get it, it runs smoother on the steel screw |
| M1.6 × 2.5 screws | 2 | bulkhead → gearbox. Longer ones reach into the gears |
| M3 heat‑set insert (Ø4 hole, 6 mm deep) | 2 | rear boss + ram nose |
| M2 × 6 self‑tapping screws | 6 | lid → tray ears |

**Assembly:**

1. Melt the heat‑set inserts into the rear boss and the ram nose.
2. Solder the wires to the motor and lead them out through the hole in the side wall.
3. Lay the motor into its pocket and screw the gearbox to the bulkhead with the two M1.6
   screws, from the front through the channel.
4. Drop the nut into the ram's slot. Lay the ram into the channel, rod through the front
   wall, and turn the screw by hand into the nut until the piston is near the bulkhead.
5. Screw on the lid.

> **Measure before printing:** the `(est.)` values at the top of the file (bearing boss,
> solder tabs) aren't on the drawing. Also count the thread: M4 is normally 0.7 mm pitch, but
> the nut drawing in the listing says "M4 × 1". Set `screw_lead` to what you count; it only
> changes the speed numbers. All parts were checked for collisions against the reference
> model at 0, 20, 40, 60 and 80 mm.

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
