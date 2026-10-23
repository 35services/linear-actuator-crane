# SMD carrier board – ordering at JLCPCB

![SMD 3D](renders/board_3d.png)

JLCPCB assembles all SMD parts on the top side. You solder the through‑hole parts yourself
afterwards:

| Hand soldered (not in the assembly files) | |
|---|---|
| J10, J11 | Female header 1×8 – SuperMini socket |
| U2, U3 | 4 × female header 1×8 – TMC2209 sockets |
| J12, J13 | Female header 1×1 – DIAG |
| J2, J3 | JST‑XH 4‑pin B4B‑XH‑A – motors |
| J4, J5 | Pin header 1×3 – RC channels |
| C1, C2 | 100 µF 35 V electrolytic, D8 mm, 3.5 mm pitch – driver VM buffer, **required**. Mind the `+` mark. THT because the SMD version is a JLCPCB extended part |
| JP1, JP2 | Solder jumpers – bridge with a blob of solder, see [UART pin](../README.md#before-you-order-check-these-both-variants) |

## Files

| File | Upload as |
|------|-----------|
| [`fab/rc-crane-carrier-smd-gerbers.zip`](fab/rc-crane-carrier-smd-gerbers.zip) | Gerber file |
| [`jlcpcb_bom.csv`](jlcpcb_bom.csv) | BOM (columns: Comment, Designator, Footprint, LCSC Part #) |
| [`jlcpcb_cpl.csv`](jlcpcb_cpl.csv) | CPL / pick‑and‑place (Designator, Mid X, Mid Y, Layer, Rotation) |

## Ordering steps

1. On jlcpcb.com, upload the Gerber zip. 2 layers, 1.6 mm, HASL lead‑free is fine.
2. Enable **PCB Assembly** with these settings:
   - side: top
   - type: "Economic" works, since all parts are on one side
   - "Confirm Parts Placement": on
3. Upload `jlcpcb_bom.csv` and `jlcpcb_cpl.csv`. All 12 SMD parts should match an LCSC part
   automatically. They are all JLCPCB basic parts, so there are no extended‑part fees.
   Check that none show as out of stock.
4. **Check the placement preview carefully.** KiCad and JLCPCB don't always agree on the
   zero rotation of a footprint, so polarised parts can show up rotated 180° in the
   preview. Check these against the silkscreen:

   | Ref | Polarity mark |
   |---|---|
   | D2–D6 | cathode band (the `K` side / pad 1) |
   | U4 | tab = OUT, the three pins on the left |

   You can rotate parts in the preview. With "Confirm Parts Placement" on, a JLCPCB
   engineer also checks them before production.
5. Order.

## After delivery

1. Solder C1/C2 (`+` to the marked pad), then the female headers, the JST connectors and
   the RC headers.
2. Bridge **JP1/JP2** to the UART pin of your driver brand.
3. **Before plugging in any modules:** connect the BEC to an RC header. Check about 4.6–5 V
   at the SuperMini's 5V socket pin and about 0 V at its 3V3 pin (the 3V3 rail comes from
   the SuperMini itself). Also check the BEC voltage (6 or 7.4 V) at the drivers' VM pins
   (top right pin of each driver socket).
4. Plug in the SuperMini and the drivers. **Never plug or unplug a driver or motor while
   powered.**

The parts list with LCSC links, and the reasons for the AMS1117, are in the
[PCB README](../README.md#smd-variant).
