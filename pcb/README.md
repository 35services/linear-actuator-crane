# Carrier PCB

A 90 × 64 mm, two‑layer, all through‑hole carrier board. The ESP32‑C3 SuperMini and both
TMC2209 StepStick drivers plug into female headers. Everything from the
[wiring diagram](../README.md#3-wiring-diagram) is on the board: the power path for the
6 V / 7.4 V BEC, the RC input clamps, the stall‑line diodes and the shared UART.

![3D render](renders/board_3d.png)

| Top | Bottom |
|---|---|
| ![top](renders/board_top.png) | ![bottom](renders/board_bottom.png) |

| File | What it is |
|------|------------|
| [`rc-crane-carrier.kicad_pcb`](rc-crane-carrier.kicad_pcb) | KiCad 10 board (open it with KiCad to inspect or edit) |
| [`fab/rc-crane-carrier-gerbers.zip`](fab/rc-crane-carrier-gerbers.zip) | Gerbers + drill files, upload as is to JLCPCB / PCBWay / Aisler |
| [`bom.csv`](bom.csv) | Parts list per reference |
| [`generate_pcb.py`](generate_pcb.py) | Placement, nets, net classes and silkscreen, all in tables at the top |
| [`build.sh`](build.sh) | Place → autoroute (Freerouting) → GND pour → DRC → Gerbers → renders |

The board passes KiCad's DRC with **0 violations and 0 unconnected items**.

---

## Before you order: check these

1. **SuperMini pinout.** Clones differ. The board assumes this layout, seen from the top
   with USB‑C pointing to the top board edge:

   | left row (J10) | right row (J11) |
   |---|---|
   | GPIO5 | 5V |
   | GPIO6 | GND |
   | GPIO7 | 3V3 |
   | GPIO8 | GPIO4 |
   | GPIO9 | GPIO3 |
   | GPIO10 | GPIO2 |
   | GPIO20 (RX) | GPIO1 |
   | GPIO21 (TX) | GPIO0 |

   Every socket pin is labelled on the silkscreen. Lay your SuperMini on the
   [top render](renders/board_top.png) and compare. If yours differs, change `ESP_LEFT` /
   `ESP_RIGHT` in `generate_pcb.py` and rebuild. The row spacing is 15.24 mm
   (`ESP_ROW_SPACING`).
2. **TMC2209 module pinout.** The board uses the standard StepStick layout. Pins 1–8 on
   the left: EN, MS1, MS2, (4), (5), CLK, STEP, DIR. Pins 16–9 on the right: VM, GND, 2B,
   2A, 1A, 1B, VIO, GND. BTT and FYSETC v3 modules match this.
   * **CLK (pin 6) is tied to GND,** so the driver uses its internal clock.
   * **UART is on pin 4 or pin 5, depending on the brand.** Bridge **JP1** (driver #0) and
     **JP2** (driver #1) to the matching side. The silkscreen says `5` / `4`. BTT v1.3 uses
     pin 4 ("RX"). If you aren't sure, bridge both sides: on BTT and FYSETC modules, pins 4
     and 5 are both PDN_UART.

---

## Parts

| Ref | Qty | Part | Notes |
|-----|-----|------|-------|
| J10, J11 | 2 | Female header 1×8, 2.54 mm | SuperMini socket |
| U2, U3 | 4 | Female header 1×8, 2.54 mm | Two per TMC2209 StepStick |
| J12, J13 | 2 | Female header 1×1 | DIAG wire from each module, see below |
| C1, C2 | 2 | 100 µF 35 V electrolytic, D8 mm, 3.5 mm pitch | Driver VM buffer, **required** |
| C3 | 1 | 470 nF ceramic, 5 mm pitch | LM2940 input |
| C4 | 1 | 47 µF 16 V electrolytic, D6.3 mm, 2.5 mm pitch | LM2940 output, needs ≥ 22 µF |
| U4 | 1 | LM2940CT‑5.0 (TO‑220) | 5 V from the BEC |
| D1 | 1 | 1N5822 | Reverse polarity, battery → VM |
| D2, D3 | 2 | 1N4148 | DIAG OR |
| D4 | 1 | 1N5817 | LDO → SuperMini 5V, blocks USB back‑feed |
| D5, D6 | 2 | BAT85 | RC signal clamp to 3V3 |
| R1, R3, R4 | 3 | 1 kΩ | UART TX, RC series resistors |
| R2 | 1 | 10 kΩ | DIAG pull‑down |
| J1 | 1 | Screw terminal 2‑pin, 5.08 mm | Battery 2–3S. Wires exit at the board edge |
| J2, J3 | 2 | JST‑XH 4‑pin (B4B‑XH‑A) | Motors, `1A 1B 2A 2B` (coil pairs next to each other) |
| J4, J5 | 2 | Pin header 1×3 | RC channels, **`S + −`** (signal on the square pad) |
| JP1, JP2 | – | Solder jumpers | UART pin select |
| H1–H4 | – | M3 holes | |

**Notes**

* The **SuperMini sits over R1, R2, D2 and D3.** Solder those flat on the board first,
  then the sockets.
* **DIAG:** the DIAG pin isn't part of the 16‑pin StepStick layout. Run a short jumper wire
  from the module's DIAG pin to J12 / J13. You don't need it if you set
  `USE_STALLGUARD false`.
* **Battery** goes to J1. The **BEC** arrives through the `+` pin of either RC header,
  because the receiver passes it through. Both RC headers share `+` and `−`.
* **Polarity:** the 1N5822 protects the drivers from a reversed battery. The BEC side is
  protected by the receiver plug, which only fits one way round.

**Order:** upload `fab/rc-crane-carrier-gerbers.zip`, 2 layers, 1.6 mm, any colour.
Minimum track and clearance is 0.2 mm, well within every cheap fab's rules.

---

## Rebuilding

```bash
./pcb/build.sh            # place, re-route, pour, DRC, Gerbers, renders
./pcb/build.sh outputs    # only DRC + Gerbers + renders from the current board
```

This needs KiCad 10 (`brew install --cask kicad`) and Java 21+. The
[Freerouting](https://github.com/freerouting/freerouting) autorouter is downloaded into
`pcb/.cache/` on first run. To change the circuit, edit the `PARTS` table in
`generate_pcb.py`. Each entry is a footprint, its position and a pad → net map.

The board can also be edited by hand in KiCad. A full `build.sh` overwrites manual
changes, so after hand edits use `build.sh outputs`.

There is no schematic file. The connectivity is defined in `generate_pcb.py`, and the
[wiring diagram](../README.md#3-wiring-diagram) in the main README is the schematic view.
