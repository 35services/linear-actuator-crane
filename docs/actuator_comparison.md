# Linear actuators compared – stepper vs. DC lead screw vs. DC with limit switches

The crane currently uses a **mini stepper slider** (see the [main README](../README.md)).
Goal of this comparison: find the cheapest actuator whose **end positions can be detected
without extra switches**, and compare it against actuators that bring their own limit
switches.

| | 1. Stepper slider (current) | 2. DC micro cylinder, 3–6 V | 3. DC mini actuator, 12 V, limit switches |
|---|---|---|---|
| Photo | ![stepper](actuator_photo.png) | ![dc micro](actuators/dc_micro_cylinder.jpg) | ![12 V](actuators/dc_12v_limit_switch.jpg) |
| Listing | [AliExpress](https://de.aliexpress.com/item/1005005779515640.html) | [AliExpress](https://a.aliexpress.com/_EyGPNzg) | [AliExpress, 10–25 mm](https://a.aliexpress.com/_Ez364hU), [AliExpress, 30 mm](https://a.aliexpress.com/_EzM5tL8) |
| Drive | 2‑phase stepper, 18°, M3 lead screw 0.5 mm | brushed DC gear motor + lead screw (2 wires) | brushed DC gear motor + lead screw (2 wires) |
| Supply | driver: 4.75–28 V (BEC is fine) | **3–6 V** (BEC 6 V setting) | **12 V** (3S LiPo or boost converter) |
| Stroke | **75 mm** | 10 / 15 / 20 / 25 mm | 10 / 15 / 20 mm, and 30 mm (second listing) |
| Length, retracted | 132.5 mm in the [printed housing](../cad/README.md#enclosed-actuator--actuator_housingscad) | 66 / 71 / 76 / 81 mm (pin to pin) | compact gearbox block + rod, see photo |
| Force | small motor, lots of force from the 0.5 mm lead (not measured yet) | **not stated – measure** | **30 / 60 / 100 / 150 N** (versions) |
| Speed | 15–20 mm/s realistic, see [Speed](../README.md#speed-how-fast-can-it-move) | not stated – measure | **15 mm/s** at 60 N (label); stronger versions are slower |
| Holds position unpowered | yes (lead screw) | probably (lead screw + gearbox) – check | usually (lead screw + gearbox) – check |
| Position known | **exactly** (step counting) after homing | only at the ends; in between estimated (time) | only at the ends; in between estimated (time) |
| End detection | StallGuard via DIAG, or hard‑stop homing | **current rise at stall** (this document) | **built‑in limit switches** cut the motor |
| Driver per actuator | TMC2209 StepStick (~€3–4) | small H‑bridge with current sense | any H‑bridge, current sense optional |
| ESP pins per actuator | STEP + DIR (+ shared UART, EN, DIAG) | 2 PWM + 1 ADC | 2 PWM |
| Mounting | needs the 3D printed housing | eyes on both ends, ready to use | eyes on both ends, brackets included |
| Look on a 1:8 model | printed box | **looks like a hydraulic cylinder** | black gearbox block |

Prices change too often to list; check the listings. Rough order: the DC micro cylinder is
the cheapest per axis, the stepper slider plus driver is in between, the 12 V actuator with
limit switches is the most expensive.

### The DC micro cylinder (option 2)

![sizes](actuators/dc_micro_cylinder_sizes.jpg)

Lengths from the listing (eye to eye, retracted → extended): 10 mm stroke 66 → 76 mm,
15 mm 71 → 86 mm, 20 mm 76 → 96 mm, 25 mm 81 → 106 mm. The shortest stepper housing is
132.5 mm, so these are far easier to fit in a 1:8 crane, but the stroke is much shorter: the
current boom lift needs 49.6 mm, so the geometry would need a much shorter lever (less tip
force) or a different layout.

### The 12 V actuator with limit switches (option 3)

![strokes](actuators/dc_12v_limit_switch_strokes.jpg)

The label on the 60 N version: *12 VDC, 60 N, 15 mm/s*, stroke 10, 15 or 20 mm. A
[30 mm version](https://a.aliexpress.com/_EzM5tL8) is longer and also has end switches,
30–150 N. In this type of actuator the limit switches usually sit inside, each bridged by a
diode: at an end the switch opens and the motor can only run back the other way. Reversing
the polarity always works, so the controller needs no end detection at all. (How these
particular ones are wired isn't in the listing – check with a multimeter.)

*Photos: from the AliExpress listings linked above.*

---

## Detecting the ends of a DC actuator with current sensing

A brushed DC motor draws a roughly constant current while it moves. When the rod reaches the
end of its travel, the motor stalls and the current jumps to the stall current
(≈ supply voltage / winding resistance). Watching for that jump replaces the limit switches.

```
current
  ▲                 stall at the end ──► ┌────────  ← stop here (threshold)
  │  inrush                              │
  │ ┌┐                                   │
  │ │└───────────────────────────────────┘  running current (load dependent)
  └─┴──────────────────────────────────────────► time
    │◄ ignore ►│
      blanking (~100 ms)
```

**Hardware:** an H‑bridge that reports its current.

| Driver | Supply | Current | Current sense | JLCPCB |
|---|---|---|---|---|
| **DRV8876** (recommended) | 4.5–37 V | 3.5 A peak | **IPROPI** pin: a current proportional to the motor current, one resistor → ESP ADC. Built‑in adjustable current limit | [C575551](https://www.lcsc.com/product-detail/C575551.html), extended |
| DRV8874 | 4.5–37 V | 6 A peak | IPROPI, as above | [C1855818](https://www.lcsc.com/product-detail/C1855818.html), extended |
| DRV8871 | 6.5–45 V | 3.6 A peak | no sense output, current limit only (add an INA180 + shunt) | [C75864](https://www.lcsc.com/product-detail/C75864.html), extended |
| DRV8833 / TB6612 modules | 2.7–10.8 V / 4.5–13.5 V | 1.5 A / 1.2 A per channel | DRV8833: shunt on its ISEN pin → ADC (small signal) / TB6612: none | modules from AliExpress |

The DRV8876 suits both DC options: its 4.5 V minimum works from the 6 V BEC, and its 37 V
maximum covers 12 V. Its **current limit** can be set just above the running current. The
motor then never pushes the end stop with full stall force, which protects the small plastic
gears when it hits the end on every homing run.

**Firmware logic, per axis:**

1. Drive with PWM. Ignore the current for the first ~100 ms (inrush).
2. Average the current (e.g. over 10 ms). If it stays above the threshold (about
   2 × running current) for ~30 ms → **end reached**, stop, remember which end.
3. **Timeout** as a fallback: if no stall is seen after the full‑stroke time + 50 %, stop
   anyway.
4. **Position in between:** estimate from the run time, using the speed measured during a
   full run from end to end at power‑up. Every time an end is hit, the estimate is corrected.
5. Better position, still without sensors: **ripple counting**. Each commutator segment
   change makes a small dip in the motor current. Counting them gives motor revolutions,
   and with the gear and screw ratio, the rod position. This needs a cleaner current signal
   (op‑amp band‑pass) and is a project of its own.

**Limits of the method:**

* **A heavy load looks like an end.** If the boom is overloaded, the current rises the same
  way. Treat it as "can't go further" and stop either way, which is the right reaction
  for a crane.
* **Threshold depends on the voltage.** With the BEC on 6 V or 7.4 V, the running and stall
  currents change. Measure both once and keep the threshold as a [web setting](../README.md#web-settings-page).
* **Wear:** with a hard current limit it's gentle, but every homing still presses the
  mechanical end stop.

---

## Summary

| | Stepper slider | DC micro cylinder + current sense | DC 12 V with limit switches |
|---|---|---|---|
| Position accuracy | **exact** | estimated between the ends | estimated between the ends |
| End detection | StallGuard / hard stop | current rise, needs a sense driver and tuning | **built in**, no tuning |
| Cost per axis | medium | **lowest** | highest |
| Fits 1:8 | needs a housing, 132 mm long | **small, looks right** | compact, 12 V needed |
| Stroke | **75 mm** | 10–25 mm | 10–30 mm |
| Force | good (measure) | unknown, probably low – measure | **specified, up to 150 N** |
| Board support today | **yes** (all boards) | no – needs a DC driver board | no – needs an H‑bridge and 12 V |

**Recommendation for the next step:** buy one DC micro cylinder (20 or 25 mm) and one 12 V
actuator (60 N, 20 mm) and measure:

| Test | How |
|---|---|
| Running and stall current at 6 V / 7.4 V (12 V for option 3) | lab supply or a USB power meter, block the rod |
| Speed | time a full stroke |
| Force | push against a kitchen or luggage scale until it stalls |
| Self‑locking | load the rod with the motor unpowered |
| End stop survives | 100 homing runs at the planned current limit |
| Option 3 at 7.4 V | does it still move and switch off at the ends (slower, less force)? |

With those numbers we can decide whether a DC driver variant of the advanced board makes
sense: e.g. 4 × DRV8876 instead of the TMC2209 sockets, with the IPROPI outputs on ESP32
ADC pins. The PCA9685 outputs could even drive the H‑bridge inputs.
