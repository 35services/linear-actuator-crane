"""Generates the stacked version of the advanced board: two 84 x 76 mm boards on M3 standoffs,
connected by a 2x8 stacking header.

    top     ESP32-S3-DevKitC-1, 4x TMC2209 StepStick, motor connectors. All through-hole,
            hand-soldered, no assembly needed.
    bottom  PCA9685 + 16 servo/ESC outputs, 4 RC inputs, CRSF/SBUS, I2C, 5 V regulator,
            motor supply input. SMD parts assembled by JLCPCB. All connectors are right-angle
            headers pointing out of the board edges, so they stay reachable under the top board.

Run with KiCad's bundled Python (it provides the pcbnew module), see ../build.sh:

    generate_stack.py top|bottom place  <board.kicad_pcb> <board.dsn>
    generate_stack.py top|bottom finish <board.kicad_pcb> <board.ses>

Coordinates in mm, KiCad convention: y grows downwards, rotation in degrees counter-clockwise.
Both boards share the outline, the mounting holes and the position of the stacking header J1.
"""

import os
import sys
from types import SimpleNamespace

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import board_tools  # noqa: E402
from board_tools import MODEL_DIR, block_pads  # noqa: E402

BOARD_W = 84
BOARD_H = 76
HOLES = [(33.6, 36.5), (BOARD_W - 3.5, 3.5), (3.5, BOARD_H - 3.5), (BOARD_W - 3.5, BOARD_H - 3.5)]

# Stacking header J1, 2x8: odd pins in the lower row, even pins 2.54 mm above
LINK_X, LINK_Y = 9, 71
LINK = ["GND", "GND", "VM", "VM", "+5V", "+3V3", "RC0", "RC1",
        "RC2", "RC3", "SRX", "STX", "SDA", "SCL", "PWM_OE", "GND"]
LINK_PADS = {str(i + 1): n for i, n in enumerate(LINK)}
LINK_FP = ("Connector_PinHeader_2.54mm", "PinHeader_2x08_P2.54mm_Vertical")

R0805 = ("Resistor_SMD", "R_0805_2012Metric")
C0805 = ("Capacitor_SMD", "C_0805_2012Metric")
SOD123 = ("Diode_SMD", "D_SOD-123")
JUMPER = ("Jumper", "SolderJumper-3_P1.3mm_Open_RoundedPad1.0x1.5mm")
AXIAL = ("Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal")

NET_CLASSES = [
    ("Power", 0.8, 0.25, ["GND", "VBEC", "VM", "VBAT", "VBAT_IN"]
     + [f"M{n}_{c}" for n in range(4) for c in ("1A", "1B", "2A", "2B")]),
    ("Supply", 0.5, 0.2, ["+5V", "+5V_REG", "+3V3"]),
]
COMMON = dict(BOARD_W=BOARD_W, BOARD_H=BOARD_H, HOLES=HOLES, NET_CLASSES=NET_CLASSES,
              DEFAULT_TRACK=0.25, DEFAULT_CLEARANCE=0.2)


# ------------------------------------------------------------------ top board ----

# ESP32-S3-DevKitC-1 standing on its head: USB at the top board edge, antenna at the bottom.
# J1 (STEP/DIR/...) is the right row, next to the drivers; J3 (RC, I2C, ...) the left row.
DK_PIN1_Y = 59.84
DK_J1_X = 27.86
DK_J3_X = 5
DK_J1 = ["3V3", "3V3", "RST", "4", "5", "6", "7", "15", "16", "17", "18", "8", "3", "46",
         "9", "10", "11", "12", "13", "14", "5V", "G"]
DK_J3 = ["G", "TX", "RX", "1", "2", "42", "41", "40", "39", "38", "37", "36", "35", "0",
         "45", "48", "47", "21", "20", "19", "G", "G"]
# same pin assignment as the single advanced board
ESP_NETS = {
    "3V3": "+3V3", "5V": "+5V", "G": "GND",
    "4": "STEP0", "5": "DIR0", "6": "STEP1", "7": "DIR1",
    "15": "STEP2", "16": "DIR2", "17": "STEP3", "18": "DIR3",
    "8": "EN", "9": "UART_TX", "10": "UART",
    "11": "DIAG0", "12": "DIAG1", "13": "DIAG2", "14": "DIAG3",
    "1": "RC0", "2": "RC1", "42": "RC2", "41": "RC3",
    "40": "SRX", "39": "STX",
    "47": "SDA", "21": "SCL", "48": "PWM_OE",
}
SOCKET = ("Connector_PinSocket_2.54mm", "PinSocket_1x22_P2.54mm_Vertical")

# TMC2209 #n: pad 1 position, 2 x 2. Address = MS1 + 2 x MS2.
DRIVERS = [(40, 9), (62, 9), (40, 45), (62, 45)]
ADDR_PINS = [("GND", "GND"), ("+3V3", "GND"), ("GND", "+3V3"), ("+3V3", "+3V3")]


def stepstick_pads(n):
    ms1, ms2 = ADDR_PINS[n]
    return {
        "1": "EN", "2": ms1, "3": ms2, "4": f"U{n}_P4", "5": f"U{n}_P5", "6": "GND",
        "7": f"STEP{n}", "8": f"DIR{n}",
        "9": "GND", "10": "+3V3", "11": f"M{n}_1B", "12": f"M{n}_1A",
        "13": f"M{n}_2A", "14": f"M{n}_2B", "15": "GND", "16": "VM",
    }


TOP_PARTS = [
    # rotation 180: pin 1 at the bottom (antenna end), the pins run upwards
    ("J10", *SOCKET, "DevKitC-1 J1", DK_J1_X, DK_PIN1_Y, 180,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(DK_J1)}, None),
    ("J11", *SOCKET, "DevKitC-1 J3", DK_J3_X, DK_PIN1_Y, 180,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(DK_J3)}, None),
    # TMC UART TX through 1k; EN pulled high = drivers off at boot. Under the DevKit.
    ("R1", *AXIAL, "1k", 9.5, 22, 0, {"1": "UART_TX", "2": "UART"}, None),
    ("R2", *AXIAL, "10k", 9.5, 28, 0, {"1": "EN", "2": "+3V3"}, None),
    # male header, soldered in from the bottom side, plugs into J1 of the bottom board
    ("J1", *LINK_FP, "2x8 male, bottom side", LINK_X, LINK_Y, 90, LINK_PADS, None),
]
for n, (x, y) in enumerate(DRIVERS):
    TOP_PARTS += [
        (f"U{10 + n}", "Module", "Pololu_Breakout-16_15.2x20.3mm", f"TMC2209 #{n}", x, y, 0, stepstick_pads(n), None),
        (f"J{12 + n}", "Connector_PinSocket_2.54mm", "PinSocket_1x01_P2.54mm_Vertical", f"DIAG{n}",
         x, y - 4.5, 0, {"1": f"DIAG{n}"}, None),
        # UART pin select: bridge the centre pad to pin 4 or pin 5, depending on the driver brand
        (f"JP{1 + n}", *JUMPER, "UART 4|5", x - 4.5, y + 6, 90, {"1": f"U{n}_P5", "2": "UART", "3": f"U{n}_P4"}, None),
        (f"J{20 + n}", "Connector_JST", "JST_XH_B4B-XH-A_1x04_P2.50mm_Vertical", f"Motor {n}",
         x + 2, y + 24, 0, {"1": f"M{n}_1A", "2": f"M{n}_1B", "3": f"M{n}_2A", "4": f"M{n}_2B"}, None),
        (f"C{1 + n}", "Capacitor_THT", "CP_Radial_D5.0mm_P2.00mm", "100u 25V", x + 16.35, y + 13.5, 0,
         {"1": "VM", "2": "GND"}, None),
    ]

TOP_SILK = [
    ("RC CRANE STACK - TOP v1", 58, 1.6, 1.0, 0),
    ("USB ^", 16.4, 2.2, 0.8, 0),
    ("antenna", 16.4, 58, 0.8, 0),
    ("J1 to bottom board", 18, 65.6, 0.8, 0),
]
for n, (x, y) in enumerate(DRIVERS):
    TOP_SILK += [
        (f"TMC2209 #{n}", x + 6.35, y + 4, 0.9, 0),
        ("1A 1B 2A 2B", x + 5.75, y + 20.4, 0.8, 0),
        ("DIAG", x - 2, y - 4.5, 0.8, 1),
        ("UART", x - 4.5, y + 2.3, 0.8, 0),
        ("5", x - 6.4, y + 4.7, 0.8, 0),
        ("4", x - 6.4, y + 7.3, 0.8, 0),
    ]
# DevKit pin names next to the sockets
TOP_SILK += [(p, DK_J3_X - 2.0, DK_PIN1_Y - i * 2.54, 0.8, 1) for i, p in enumerate(DK_J3)]
TOP_SILK += [(p, DK_J1_X + 2.0, DK_PIN1_Y - i * 2.54, 0.8, -1) for i, p in enumerate(DK_J1)]

TOP = SimpleNamespace(
    **COMMON,
    PARTS=TOP_PARTS,
    KEEPOUTS=[(7.5, 55, 25.4, 64.5)],   # no copper under the module's PCB antenna
    SILK=TOP_SILK,
    VERTICAL_SILK=[],
    HIDE_REF={f"J{12 + n}" for n in range(4)} | {"J1"},
    REF_POS={f"J{20 + n}": (x + 3.75, y + 29.2) for n, (x, y) in enumerate(DRIVERS)},
    GROUND_STUBS=[],
    BOTTOM_SIDE=set(),
    # the male header hangs below the board
    MODELS={"J1": [(f"{MODEL_DIR}/Connector_PinHeader_2.54mm.3dshapes/PinHeader_2x08_P2.54mm_Vertical.step",
                    (0, -17.78, -1.6), (180, 0, 0))]},
    JLCPCB=False,
)


# --------------------------------------------------------------- bottom board ----

OUT_PIN1_X = 75     # PWM out: right-angle 3 x 16 at the bottom edge, pin 1 on the right
OUT_EDGE_Y = 71.7   # pad row next to the edge, the plastic ends at the board edge
RC_EDGE_X = 4.3     # RC in: right-angle 3 x 4 at the left edge
RC_PIN1_Y = 18


def out_x(k):
    return OUT_PIN1_X - 2.54 * (15 - k)


def rc_y(k):
    return RC_PIN1_Y - 2.54 * (3 - k)


def pca9685_pads():
    pads = {str(p): "GND" for p in (1, 2, 3, 4, 5, 14, 24, 25)}  # A0-A5 -> address 0x40, EXTCLK off
    pads.update({str(6 + i): f"LED{i}" for i in range(8)})
    pads.update({str(15 + i): f"LED{8 + i}" for i in range(8)})
    pads.update({"23": "PWM_OE", "26": "SCL", "27": "SDA", "28": "+3V3"})
    return pads


BOTTOM_PARTS = [
    # female header, plugs onto the top board's J1 (same footprint so the pads line up)
    ("J1", *LINK_FP, "2x8 female 8.5 mm", LINK_X, LINK_Y, 90, LINK_PADS, None),

    # outputs: rows from the edge "-", "+", "S"; channel 1 on the left
    ("J30", "rc_crane", "PinHeader_3x16_P2.54mm_Horizontal", "PWM out, right angle", OUT_PIN1_X, OUT_EDGE_Y, 270,
     block_pads(16, "PWM{}", rows=("-", "+", "S"), channel=lambda c: 15 - c), None),
    ("U5", "Package_SO", "TSSOP-28_4.4x9.7mm_P0.65mm", "PCA9685PW", 56, 52, 0, pca9685_pads(), "C2678753"),
    ("C8", *C0805, "100n", 62.5, 46.5, 0, {"1": "+3V3", "2": "GND"}, "C49678"),
    ("C9", *C0805, "10u 25V", 46, 46.5, 0, {"1": "+3V3", "2": "GND"}, "C15850"),
    ("R9", *R0805, "4.7k", 46, 42, 0, {"1": "SDA", "2": "+3V3"}, "C17673"),
    ("R10", *R0805, "4.7k", 52, 42, 0, {"1": "SCL", "2": "+3V3"}, "C17673"),
    ("R11", *R0805, "10k", 58, 42, 0, {"1": "PWM_OE", "2": "+3V3"}, "C17414"),

    # RC inputs: rows from the edge "-", "+", "S"; channel 1 at the top
    ("J4", "rc_crane", "PinHeader_3x04_P2.54mm_Horizontal", "RC in, right angle", RC_EDGE_X, RC_PIN1_Y, 180,
     block_pads(4, "RC{}_IN", rows=("-", "+", "S"), channel=lambda c: 3 - c), None),

    # serial receiver (CRSF / SBUS / iBUS) and I2C, right angle at the left edge
    ("J7", "rc_crane", "PinHeader_1x04_P2.54mm_Horizontal", "Serial RX, right angle", RC_EDGE_X, 31.62, 180,
     {"1": "GND", "2": "+5V_REG", "3": "SRX_IN", "4": "STX_OUT"}, None),
    ("R7", *R0805, "1k", 13, 29.1, 0, {"1": "SRX_IN", "2": "SRX"}, "C17513"),
    ("R8", *R0805, "1k", 13, 26.5, 0, {"1": "STX_OUT", "2": "STX"}, "C17513"),
    ("J8", "rc_crane", "PinHeader_1x04_P2.54mm_Horizontal", "I2C, right angle", RC_EDGE_X, 44.62, 180,
     {"1": "GND", "2": "+3V3", "3": "SDA", "4": "SCL"}, None),

    # power: 5 V for the ESP and the serial receiver, VM from the BEC or a 2-3S battery
    ("U4", "Package_TO_SOT_SMD", "SOT-223-3_TabPin2", "AMS1117-5.0", 24, 53, 0,
     {"1": "GND", "2": "+5V_REG", "3": "VBEC"}, "C6187"),
    ("C5", *C0805, "10u 25V", 18, 47.5, 0, {"1": "VBEC", "2": "GND"}, "C15850"),
    ("C6", *C0805, "22u 25V", 30, 47.5, 0, {"1": "+5V_REG", "2": "GND"}, "C45783"),
    ("D4", *SOD123, "B5819W", 30, 58.5, 0, {"1": "+5V", "2": "+5V_REG"}, "C8598"),
    ("C7", "Capacitor_THT", "CP_Radial_D10.0mm_P5.00mm", "1000u 16V", 45, 20, 0, {"1": "VBEC", "2": "GND"}, None),
    # side-entry JST-XH (7.5 mm high, fits under the top board), opening at the right edge
    ("J9", "Connector_JST", "JST_XH_S2B-XH-A_1x02_P2.50mm_Horizontal", "VM batt, side entry", 74, 44, 90,
     {"1": "VBAT_IN", "2": "GND"}, None),
    ("D9", "Diode_SMD", "D_SMA", "SS34", 70, 33, 90, {"1": "VBAT", "2": "VBAT_IN"}, "C8678"),
    ("JP9", *JUMPER, "VM BEC|BATT", 70, 25, 0, {"1": "VBAT", "2": "VM", "3": "VBEC"}, None),
]
for k in range(4):
    BOTTOM_PARTS += [
        (f"R{20 + k}", *R0805, "1k", 14, rc_y(k), 0, {"1": f"RC{k}_IN", "2": f"RC{k}"}, "C17513"),
        # rotation 180: anode (pad 2) on the left, next to the resistor
        (f"D{20 + k}", *SOD123, "B5819W", 18.6, rc_y(k), 180, {"1": "+3V3", "2": f"RC{k}"}, "C8598"),
    ]
for k in range(16):
    # rotation 90: pad 1 below, next to the header
    BOTTOM_PARTS.append((f"R{40 + k}", *R0805, "220", out_x(k), 61, 90, {"1": f"PWM{k}", "2": f"LED{k}"}, "C17557"))

BOTTOM_SILK = [
    ("RC CRANE STACK - BOTTOM v1", 52, 2.0, 1.0, 0),
    ("github.com/35services/linear-actuator-crane", 52, 4.2, 0.8, 0),
    ("J1 to top board", 18, 65.6, 0.8, 0),
    ("PWM OUT", out_x(0) - 2.4, 64.1, 0.8, 1),
    ("S", out_x(0) - 2.2, OUT_EDGE_Y - 5.08, 0.8, 1), ("+", out_x(0) - 2.2, OUT_EDGE_Y - 2.54, 0.8, 1),
    ("-", out_x(0) - 2.2, OUT_EDGE_Y, 0.8, 1),
    ("RC IN", 6.84, 6.6, 0.8, 0),
    ("- + S", 6.84, 8.4, 0.8, 0),
    ("CRSF", 7.2, 22.4, 0.8, -1),
    ("I2C", 7.2, 35.4, 0.8, -1),
    ("VM from", 70, 22.3, 0.8, 0),
    ("BATT", 68.7, 27.4, 0.8, 1),
    ("BEC", 71.3, 27.4, 0.8, -1),
    ("VM 2-3S", 78.5, 37.6, 0.8, 0),
    ("+", 71.4, 44, 0.8, 1), ("-", 71.4, 41.5, 0.8, 1),
    ("C7 1000u (bottom side)", 45, 13.4, 0.8, 0),
]
BOTTOM_SILK += [(str(k + 1), out_x(k), 64.1, 0.8, 0) for k in range(16)]
BOTTOM_SILK += [(str(k + 1), 21.4, rc_y(k), 0.8, -1) for k in range(4)]
BOTTOM_SILK += [(t, 7.2, 31.62 - i * 2.54, 0.8, -1) for i, t in enumerate(("G", "5V", "RX", "TX"))]
BOTTOM_SILK += [(t, 7.2, 44.62 - i * 2.54, 0.8, -1) for i, t in enumerate(("G", "3V3", "SDA", "SCL"))]

BOTTOM = SimpleNamespace(
    **COMMON,
    PARTS=BOTTOM_PARTS,
    KEEPOUTS=[],
    SILK=BOTTOM_SILK,
    VERTICAL_SILK=[],
    HIDE_REF=({f"R{40 + k}" for k in range(16)} | {f"R{20 + k}" for k in range(4)} | {f"D{20 + k}" for k in range(4)}
              | {"J1", "J4", "J7", "J8", "J9", "J30", "C7"}),
    REF_POS={"U5": (56, 52)},
    GROUND_STUBS=[("U5", {"24", "25"}), ("C9", {"2"})],  # C9's GND pad ends up boxed in by the I2C lines
    BOTTOM_SIDE={"C7"},
    # female socket model on the header footprint (the socket's second row is mirrored)
    MODELS={"J1": [(f"{MODEL_DIR}/Connector_PinSocket_2.54mm.3dshapes/PinSocket_2x08_P2.54mm_Vertical.step",
                    (2.54, 0, 0), (0, 0, 0))]},
    JLCPCB=True,
)

if __name__ == "__main__":
    designs = {"top": TOP, "bottom": BOTTOM}
    if len(sys.argv) < 2 or sys.argv[1] not in designs:
        sys.exit(__doc__)
    board_tools.main(designs[sys.argv[1]], sys.argv[:1] + sys.argv[2:], __doc__)
