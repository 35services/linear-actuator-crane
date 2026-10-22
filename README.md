# RC Crane – Stepper Linear Actuator Controller

[![Render CAD](https://github.com/35services/linear-actuator-crane/actions/workflows/render-cad.yml/badge.svg)](https://github.com/35services/linear-actuator-crane/actions/workflows/render-cad.yml)

![crane concept](cad/renders/crane.png)

**All CAD renderings and printable STLs:** [`cad/`](cad/README.md). The concept sketch
that started it is [`gemini.jpeg`](gemini.jpeg).

Drive two mini stepper‑motor linear actuators (2‑phase, 4‑wire, lead screw + slider) from
normal RC receiver channels to work a crane on an RC model vehicle:

* **Boom lift:** actuator 1 raises and lowers the boom.
* **Telescope:** actuator 2, lying on top of the boom, extends the inner boom section.

Features:

* **No end switches.** On power‑up both actuators home themselves using **sensorless
  homing** (TMC2209 StallGuard). If stall detection isn't reliable on your motors, they fall
  back to **hard‑stop homing**: each one drives into its mechanical end at low current.
* **Plug‑and‑play with RC.** The ESP32 reads a standard servo PWM signal (1000–2000 µs) from
  one receiver channel per actuator.
* **Battery friendly.** Lead screws are self‑locking, so the drivers are switched off when
  idle and the load still holds.

---

## 1. How it works

```
                          ┌──── servo PWM (CH a) ──┐
 Transmitter ──radio──► RC receiver                ▼
                          └──── servo PWM (CH b) ──► ESP32-C3
                                                     │   ▲
                       shared UART + EN, own STEP/DIR│   │ DIAG (OR'ed)
                                     ┌───────────────┴───┴──────────────┐
                                     ▼                                  ▼
                              TMC2209 #0 (addr 0)               TMC2209 #1 (addr 1)
                                     │                                  │
                              actuator 1: boom lift             actuator 2: telescope
```

1. **Power‑up:** the ESP32 configures both TMC2209s over one shared UART line. They have
   different addresses, set with the MS1/MS2 pins.
2. **Homing,** one actuator at a time. The **telescope goes first**, so the boom moves with
   the shortest lever.
   * The actuator drives toward its retracted end at low current.
   * With **StallGuard**, the homing driver sees the motor load spike and pulls `DIAG`
     high, so the ESP32 stops right away. Only the homing driver has its stall output
     enabled, so the two `DIAG` lines can share one GPIO.
   * Without StallGuard (or if no stall is detected), the motor runs for the full stroke
     plus a small margin. At low current it just skips a few steps against the end, which
     does no harm, and that point becomes position 0.
3. **Run:** each RC channel controls one actuator, in either
   * **Position mode:** stick or knob position = actuator position. The default for the
     boom lift, best on a knob or slider.
   * **Rate mode:** stick deflection = speed. The default for the telescope, best on a
     self‑centring stick.
   Soft limits keep each slider a little away from both ends, so it never crashes again
   after homing.
4. **Failsafe:** if no valid RC pulse arrives on a channel for 250 ms, that actuator stops.

---

## 2. Components

| # | Qty | Part | Notes | ~Price |
|---|-----|------|-------|--------|
| 1 | **2** | Mini stepper linear actuator (the AliExpress part) | 2‑phase, 4‑wire. Note the **step angle** (often 18° = 20 steps/rev), **screw lead** (often M3 = 0.5 mm) and **stroke** | 2 × €11 |
| 2 | 1 | **ESP32‑C3 SuperMini** (or Seeed XIAO ESP32‑C3) | Tiny, 3.3 V logic, USB‑C | €3 |
| 3 | **2** | **TMC2209 stepper driver module** (BigTreeTech v1.3, FYSETC or similar, *UART version*) | Quiet (StealthChop), current set over UART, **StallGuard for sensorless homing**, 4.75–29 V | 2 × €4 |
| 4 | **2** | Electrolytic capacitor **100 µF, ≥ 25 V** | One across each driver's VM/GND, close to the module. **Required.** | €0.40 |
| 5 | 1 | Resistor **1 kΩ** | Single‑wire UART (between TX and the shared PDN_UART line) | – |
| 6 | 2 | Diode **1N4148** (or any small signal diode) | OR both `DIAG` outputs onto one GPIO | – |
| 7 | 1 | Resistor **10 kΩ** | Pull‑down on the shared `DIAG` line | – |
| 8 | 2 | Resistors **1 kΩ + 2 kΩ** per channel (optional) | Voltage divider, only if your receiver outputs 5 V signals | – |
| 9 | 1 | Mini buck converter 5 V (MP1584 / Mini‑360) (optional) | Only if your BEC isn't 5.0–5.5 V. See [Power](#4-power) | €1 |
| 10 | 2 | Servo extension lead | Receiver channels → ESP32 | €2 |
| 11 | 1 | Inline fuse 2 A (optional) | In the battery line to the drivers | €1 |
| 12 | 1 set | Nesting square tubes (aluminium/brass, e.g. 16×12 and 11×7 mm) | Telescopic boom. See [Mechanics](#5-mechanics) | €5 |
| 13 | | Perfboard, JST‑XH/Dupont connectors, heat‑shrink | | |

### Why the TMC2209?

| Driver | Sensorless homing | Noise | Current setting | Verdict |
|--------|-------------------|-------|-----------------|---------|
| **TMC2209** | ✅ StallGuard4 | silent | software (UART) | **Recommended** |
| TMC2208 | ❌ | silent | potentiometer/UART | OK, hard‑stop homing only |
| A4988 / DRV8825 | ❌ | loud | potentiometer | Works, but crude for tiny motors |
| DRV8833 (H‑bridge) | ❌ | – | none (voltage‑driven) | Only for 5 V motors on a 5 V supply. No current limit |

---

## 3. Wiring diagram

Both drivers are wired the same way. The only differences are **STEP/DIR**, the **address
pins** and the **diode on DIAG**.

```
                         ┌──────────────────────────────┐
  2S/3S LiPo  (+) ──fuse─┤                              │
  7.4–12.6 V             │      vehicle ESC + BEC       ├── BEC 5 V ──► RC receiver (+ / -)
              (-) ───────┤                              │
                         └──────────────────────────────┘
       │ (+)  │ (-)
       ├──────┼────────────────────────────────────────┐
       │      │      100 µF                    │      │      100 µF
       ▼      ▼     ┌─┤├─┐                     ▼      ▼     ┌─┤├─┐
   ┌───────────────────────────┐           ┌───────────────────────────┐
   │   TMC2209 #0 (boom lift)  │           │   TMC2209 #1 (telescope)  │
   │                           │           │                           │
   │  VM / GND ◄── battery     │           │  VM / GND ◄── battery     │
   │  1A 1B 2A 2B ──► actuator 1           │  1A 1B 2A 2B ──► actuator 2
   │                           │           │                           │
   │  VIO ◄── 3V3              │           │  VIO ◄── 3V3              │
   │  GND ◄── GND              │           │  GND ◄── GND              │
   │  MS1 ◄── GND  ┐ addr 0    │           │  MS1 ◄── 3V3  ┐ addr 1    │
   │  MS2 ◄── GND  ┘           │           │  MS2 ◄── GND  ┘           │
   │                           │           │                           │
   │  STEP ◄── GPIO4           │           │  STEP ◄── GPIO0           │
   │  DIR  ◄── GPIO5           │           │  DIR  ◄── GPIO1           │
   │  EN   ◄── GPIO6 (shared)  │           │  EN   ◄── GPIO6 (shared)  │
   │  DIAG ──►|──┐  1N4148     │           │  DIAG ──►|──┐  1N4148     │
   │             │             │           │             │             │
   │  PDN_UART ◄─┼──────┬──────────────────────── PDN_UART              │
   └─────────────┼──────┼──────┘           └─────────────┼─────────────┘
                 │      │                                │
                 │      │       DIAG (shared) ◄──────────┘
                 ├──────┼──────────────────────► GPIO7 ──[10 kΩ]── GND
                        │
                        ├──────────────────────► GPIO20 (RX)
                        └──[1 kΩ]──────────────► GPIO21 (TX)

   ┌────────────────────────┐                ┌───────────────────────┐
   │     ESP32-C3 SuperMini │                │      RC receiver      │
   │                        │                │                       │
   │  5V  ◄─────────────────────────────────── + (BEC 5 V)  any CH   │
   │  GND ◄─────────────────────────────────── −                     │
   │  GPIO3  ◄─────────(divider if 5 V)──────── S  CH a: boom lift   │
   │  GPIO10 ◄─────────(divider if 5 V)──────── S  CH b: telescope   │
   │                        │                └───────────────────────┘
   └────────────────────────┘
```

Each actuator connects to its driver exactly as before: one coil on `1A/1B`, the other on
`2A/2B`.

### Pin table

| ESP32‑C3 | → | Connects to | Purpose |
|----------|---|-------------|---------|
| GPIO4 | → | TMC2209 #0 STEP | boom lift step pulses |
| GPIO5 | → | TMC2209 #0 DIR | boom lift direction |
| GPIO0 | → | TMC2209 #1 STEP | telescope step pulses |
| GPIO1 | → | TMC2209 #1 DIR | telescope direction |
| GPIO6 | → | EN of **both** drivers | LOW = drivers on, HIGH = off |
| GPIO7 | ← | DIAG of **both**, through a diode each, plus 10 kΩ to GND | HIGH = stall detected |
| GPIO21 (TX) | → 1 kΩ → | PDN_UART of **both** | UART write |
| GPIO20 (RX) | ← | PDN_UART of **both** | UART read (direct) |
| GPIO3 | ← | receiver CH a signal | boom lift servo PWM in |
| GPIO10 | ← | receiver CH b signal | telescope servo PWM in |
| 3V3 | → | VIO of both, MS1 of #1 | logic supply / address |
| GND | – | GND of both drivers (logic side) | **common ground** |
| 5V | ← | receiver + (BEC) | ESP32 supply |

### Wiring gotchas

* **Driver addresses:** #0 has MS1 = MS2 = GND (address 0). #1 has **MS1 = 3V3**,
  MS2 = GND (address 1). If both drivers have the same address, the UART check at boot
  fails for one of them.
* **DIAG diodes:** anode at the driver's DIAG pin, cathode (the band) toward GPIO7. The
  10 kΩ pull‑down holds the line low when neither driver signals a stall.
* **Find the coil pairs** with a multimeter. The two wires that show resistance between them
  (typically 5–30 Ω) are one coil. If an actuator moves the wrong way, swap the two wires of
  **one** coil, or flip that axis's `invert` flag in the firmware.
* **Never plug or unplug a motor while its driver is powered.** That kills TMC drivers.
* Pin order differs between TMC2209 brands. Go by the labels, not by position.
  * BTT v1.3: `PDN_UART` is the pin marked **RX** (`TX` is the same net). `DIAG` is on the
    extra pin header at the top.
  * Some clones need a solder bridge to connect PDN to the header pin. Check the module's
    pinout.
* **All grounds are common:** battery −, ESC/BEC −, receiver −, ESP32 GND, both TMC2209 GNDs.
* **Receiver signal level:** most modern receivers output 3.3 V, so a direct connection is
  fine. If yours outputs 5 V, use a divider on each channel: signal → 1 kΩ → GPIO → 2 kΩ →
  GND.
* **Strapping pins:** GPIO2, 8 and 9 on the C3 are strapping pins and are avoided. GPIO0/1
  are normal GPIOs on the SuperMini.

---

## 4. Power

* **Motors (TMC2209 VM):** both drivers straight from the drive battery (2S/3S LiPo).
  * A "5 V" mini stepper is fine on 8–12 V. The TMC2209 limits the **current**, and the
    higher voltage gives more torque at speed.
  * Set the current per axis in firmware (the `run` column in `AXES`). Rule of thumb:
    `I = rated voltage / coil resistance`. Example: 5 V / 15 Ω ≈ 330 mA → use about 300 mA.
* **ESP32:** from the receiver's BEC rail (any free channel's + pin), **if the BEC gives
  5.0–5.5 V**. Many BECs default to 6 V or more. In that case, use a small 5 V buck
  converter from the battery.
* The ESP32 plus idle drivers draw about 30–60 mA. With both actuators moving, expect about
  0.6–1 A from the battery.

---

## 5. Mechanics

### Boom lift: actuator as a boom cylinder

```
               load F_tip
                  ▼
   ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━●  boom (length L)
   pivot ╲      ▲ attach point at distance d from pivot
          ╲    ╱
           ╲  ╱ actuator (pushrod with ball links at both ends)
            ●  base mount on chassis
```

* Torque balance: `F_actuator × d_perp ≈ F_tip × L`
  (`d_perp` = perpendicular distance from the pivot to the actuator's line of action).
* Mini lead‑screw actuators typically push **about 5–20 N**. If you mount the actuator close
  to the pivot, you get a large boom angle from a short stroke but little force at the tip,
  and the reverse if you mount it far out. Example: 10 N actuator, d = 20 mm, L = 200 mm →
  about 1 N (≈ 100 g) at the tip. Add a counterweight or a gas/elastic spring to carry the
  boom's own weight.
* **Extending the telescope makes `L` longer**, so the lift capacity at the tip drops.
  Lift loads with the telescope retracted where you can.
* The slider block is **not** built for side loads. Connect it to the boom with a short
  pushrod and **ball links / clevises** at both ends. Don't bolt the boom straight to the
  slider.
* The lead screw is self‑locking, so the boom holds its position with the driver off.

### Telescope: actuator on top of the boom

```
            actuator 2 (motor at the back, near the pivot)
          ┌──■■■■[slider]────────┐
          │        │  pin through a slot in the top of the outer tube
   ●══════╪════════╪═════════════════════╗
   pivot  │  outer │tube  ┌──────────────╫──────────────┐
          │        └─────►│ inner section║              ├──► tip sheave + hook
          │               └──────────────╫──────────────┘
   ●══════╧══════════════════════════════╝
```

* Use **nesting square tubes** (e.g. 16×12 mm outer, 11×7 mm inner). A little PTFE tape or
  a 3D‑printed sliding pad at the rear of the inner section and at the front of the outer
  tube keeps it from rattling.
* Mount actuator 2 **flat on top of the outer tube, near the pivot**. That keeps its weight
  close to the pivot, so it barely loads the lift actuator.
* A pin or small bracket on the slider reaches through a **slot in the top of the outer
  tube** into the rear end of the inner section. The tubes carry the bending load. The
  actuator only has to overcome sliding friction plus `load × sin(boom angle)`, which is
  well within what it can do.
* **Extension equals the actuator stroke** (e.g. 30 mm). For more reach, use a **2:1 rope
  multiplier**: put a pulley on the slider, anchor the rope to the outer tube, and attach
  the other end to the inner section. The inner section then moves twice as far as the
  slider, at half the force. You'll also need a return spring or a second rope to pull it
  back in.

### CAD concept

[`cad/crane.scad`](cad/crane.scad) is a rough, parametric OpenSCAD model of the layout:
turntable, mast plates, telescopic boom, counterweight, hook, the lift actuator under the
boom and the telescope actuator on top.

![crane concept](cad/renders/crane.png)

* Use **View → Animate** (FPS 10, Steps 60) to sweep the boom between `boom_min` and
  `boom_max` while the telescope extends and retracts.
* Set `animate = false` to pose it by hand with `boom_angle` and `tele_ext`.
* The console prints the **stroke the lift geometry needs** (with the defaults, 28.6 mm of
  a 30 mm stroke), the **reach** (155–185 mm from pivot to tip) and the **tip‑force ratio**
  for the current pose. It warns if the stroke isn't enough.
* Tip force as a fraction of lift actuator force, with the defaults:

  | | telescope in | telescope out |
  |---|---|---|
  | boom level | 26 % | 22 % |
  | boom at 55° | 11 % | 9 % |

* Change `attach_d`, `pivot_h`, `outer_len`/`inner_len` and the boom range to trade reach
  and lift range against force.

### Enclosed actuator housing (3D printed)

[`cad/actuator_housing.scad`](cad/actuator_housing.scad) turns the bare slider into an
enclosed actuator, like a small electric cylinder: a fixed housing, and a **ram** that
slides in and out at the front. Ready‑to‑print STLs are in [`cad/stl/`](cad/stl).

![housing section](cad/renders/actuator_housing_section.png)
![housing extended](cad/renders/actuator_housing_extended.png)

Dimensions come from the product photo: motor Ø15 × 12.5 mm, 90 mm frame, 104 mm overall,
Ø2.9 mm (M3) lead screw. With about 75 mm of slider travel:

* **End to end:** 132.5 mm retracted, 207.5 mm extended, plus ball links.
* **Housing:** 127.5 × 21 × 32 mm.

**How it works**

* The **tray** holds the motor in a half cradle. The frame sits on a narrow rib along the
  floor. The **lid** clamps the motor from above.
* The **ram** is a rectangular sleeve around the frame.
  * The slider's tall tab sits in a slot in the ram's ceiling. The front end of the slot
    pushes the ram out. A **1.75 mm filament pin** (or an M2 screw) across the slot behind
    the tab pulls it back in.
  * A slot in the ram's floor lets it slide past the support rib.
* The ram is guided by the tray walls, floor and lid. Side loads go into the housing, not
  into the actuator's thin guide rods. At full extension, 23 mm of the ram is still inside
  the housing.
* **Mounting:** both ends have a hole for an M3 heat‑set insert. Screw in standard RC ball
  studs or ball links, which also take up misalignment in the boom linkage.

**Parts**

| Part | Qty | Notes |
|------|-----|-------|
| `actuator_tray.stl` | 1 | print floor down |
| `actuator_lid.stl` | 1 | print flat side down |
| `actuator_ram.stl` | 1 | print on its side (as exported), so the layers run along its length |
| M3 heat‑set insert (Ø4 hole, 6 mm deep) | 2 | rear boss + ram nose |
| M2 × 6 self‑tapping screws | 6 | lid → tray ears |
| 1.75 mm filament, about 20 mm | 1 | retaining pin through the ram behind the tab |
| M3 ball link / ball stud | 2 | mounting |

PETG or PLA, 0.2 mm layers, 3–4 walls. The sliding clearance is `clr = 0.4`. If the ram is
loose, lower it. If it binds, raise it, or sand the ram and add a little dry PTFE lube.

**Assembly**

1. Melt the heat‑set inserts into the rear boss and the ram nose.
2. Solder or plug the motor wires, then feed them out through the hole at the back.
3. Lay the actuator into the tray: motor in the cradle, frame on the rib. Glue the frame's
   bottom sheet to the rib with a drop of CA glue, or drill through its holes for M2 screws.
4. Move the slider fully back (turn the lead screw by hand). Slide the ram over the frame
   from the front, so that the slider tab enters the ceiling slot.
5. Push a piece of 1.75 mm filament through the pin hole behind the tab. Trim it flush and
   melt the ends slightly.
6. Screw on the lid.

> **Measure before printing:** several dimensions (frame depth, slider depth, tab width,
> retracted tab position) can't be read off the photo. They are marked `MEASURE` at the
> top of the file. The file prints warnings if the ram would hit the motor or the slider
> would hit the end plate. All parts were checked for collisions along the full stroke
> against the reference model, so as long as the reference model matches your part, they
> fit.
>
> **Firmware:** this actuator has a lot more stroke than the 30 mm used in the firmware
> defaults. Set `stroke` in the `AXES` table to your measured travel. Homing doesn't change:
> it retracts until the slider stops at the motor end. The ram stays 1 mm clear of the motor.

---

## 6. Firmware

The firmware is in [`firmware/rc_crane/rc_crane.ino`](firmware/rc_crane/rc_crane.ino) (Arduino IDE / arduino‑cli).
It compiles for the ESP32‑C3 with esp32 core 2.0.14 (the API used also exists in 3.x). It
has **not yet been tested on hardware**.

**Board:** *ESP32C3 Dev Module*, with **USB CDC On Boot: Enabled** so the Serial monitor
works.

**Libraries** (Library Manager):

* `TMCStepper` by teemuatlut
* `AccelStepper` by Mike McCauley

### Configure before first run

Shared mechanics (both actuators are the same model), at the top of the sketch:

| Constant | Meaning | Typical mini actuator |
|----------|---------|-----------------------|
| `FULL_STEPS_PER_REV` | motor steps/rev (360° / step angle) | 20 (18°) |
| `SCREW_LEAD_MM` | travel per screw revolution | 0.5 (M3) |
| `MICROSTEPS` | driver microstepping | 16 |
| `USE_STALLGUARD` | sensorless stop on stall | `true` |

Per axis, in the `AXES` table:

```cpp
constexpr AxisConfig AXES[] = {
  // name         STEP DIR  RC  addr stroke invert  run  home  SG  mode
  {"boom lift",    4,   5,   3,  0,   30.0f, false, 300, 150, 30, ControlMode::POSITION},
  {"telescope",    0,   1,  10,  1,   30.0f, false, 300, 150, 30, ControlMode::RATE},
};
```

| Column | Meaning |
|--------|---------|
| `STEP`, `DIR`, `RC` | GPIOs for this axis |
| `addr` | TMC2209 UART address (MS1/MS2) |
| `stroke` | usable stroke in mm |
| `invert` | flip if "retract" moves outward |
| `run` / `home` | motor current in mA while running / homing (about 50 % of run) |
| `SG` | StallGuard threshold (higher = more sensitive) |
| `mode` | `POSITION` (knob) or `RATE` (stick) |

### Tuning sensorless homing

Do this once per axis:

1. Set `TUNE_STALLGUARD` to the axis index (`0` = boom lift, `1` = telescope) and flash.
   That actuator moves back and forth slowly and prints `SG_RESULT` to the Serial monitor.
2. Note the value while moving freely (e.g. 120) and while you block the slider with a
   finger (e.g. 10).
3. A stall triggers when `SG_RESULT ≤ 2 × SG`. Pick a threshold so that `2 × SG` lies
   between the two values (e.g. `SG = 30` → triggers at 60), and put it in the `AXES` table.
4. Set `TUNE_STALLGUARD` back to `-1` and flash again.

> **Honest caveat:** StallGuard needs some back‑EMF to work. Tiny 15–20 mm steppers at slow
> homing speeds sometimes give a weak, noisy signal. If you can't find a clean threshold, set
> `USE_STALLGUARD false`. You then get **hard‑stop homing**: low current, full stroke + 2 mm
> into the end stop. It's a bit buzzy for a moment, but it is reliable and needs no switch.

---

## 7. Ideas for later

* **Winch / slewing:** up to 4 TMC2209s can share the UART line (addresses 0–3). The C3 is
  almost out of free pins, though. For a third and fourth axis, switch to an
  **ESP32‑S3 SuperMini/Zero**, which has plenty of GPIOs.
* **Wi‑Fi tuning page** on the ESP32 for current, speed and threshold.
* Store the last positions in NVS and skip homing after a clean shutdown. It's risky if
  power drops mid‑move, so homing on every boot is the safe default.
