"""Generates the advanced RC crane board: ESP32-S3-DevKitC-1, 4x TMC2209 StepStick,
PCA9685 with 16 servo/ESC outputs, 4 RC PWM inputs and a CRSF/SBUS receiver port.

Run with KiCad's bundled Python (it provides the pcbnew module), see ../build.sh:

    generate_advanced.py place  <board.kicad_pcb> <board.dsn>   # place parts, nets, outline -> DSN
    generate_advanced.py finish <board.kicad_pcb> <board.ses>   # import routes, add GND pours

SMD parts are assembled by JLCPCB (LCSC numbers below). Sockets, headers, connectors and
the electrolytic capacitors are through-hole and hand-soldered.

All placement and connectivity lives in the tables below. Coordinates in mm,
KiCad convention: y grows downwards, rotation in degrees counter-clockwise.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import board_tools  # noqa: E402
from board_tools import block_pads  # noqa: E402

BOARD_W = 100
BOARD_H = 100
HOLES = [(3.5, 3.5), (BOARD_W - 3.5, 3.5), (3.5, BOARD_H - 3.5), (BOARD_W - 3.5, BOARD_H - 3.5)]

# ESP32-S3-DevKitC-1 (v1.1, Espressif's drawing: 25.4 x 62.74 mm, rows 22.86 mm apart).
# Lying on its side: USB connectors over the left board edge, antenna to the right.
# J1 is the top row, J3 the bottom row, pin 1 of both at the antenna end (right).
DK_PIN1_X = 58.8
DK_J1_Y = 9
DK_J3_Y = DK_J1_Y + 22.86
DK_J1 = ["3V3", "3V3", "RST", "4", "5", "6", "7", "15", "16", "17", "18", "8", "3", "46",
         "9", "10", "11", "12", "13", "14", "5V", "G"]
DK_J3 = ["G", "TX", "RX", "1", "2", "42", "41", "40", "39", "38", "37", "36", "35", "0",
         "45", "48", "47", "21", "20", "19", "G", "G"]
# no copper under the module's PCB antenna
KEEPOUTS = [(49, DK_J1_Y + 2.5, 63, DK_J3_Y - 2.5)]

# What each ESP pin connects to (unlisted pins stay unconnected). Kept free: strapping pins
# 0/3/45/46, USB 19/20, 35-37 (octal PSRAM on N8R8/N16R8), 38 (RGB LED), 43/44 (USB-UART).
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
JUMPER = ("Jumper", "SolderJumper-3_P1.3mm_Open_RoundedPad1.0x1.5mm")
R0805 = ("Resistor_SMD", "R_0805_2012Metric")
C0805 = ("Capacitor_SMD", "C_0805_2012Metric")
SOD123 = ("Diode_SMD", "D_SOD-123")
HDR = "Connector_PinHeader_2.54mm"
JLCPCB = True

# TMC2209 #n: pad 1 position. Address = MS1 + 2 x MS2 (pads 2, 3).
DRIVER_X = [9 + 22 * n for n in range(4)]
DRIVER_Y = 43
ADDR_PINS = [("GND", "GND"), ("+3V3", "GND"), ("GND", "+3V3"), ("+3V3", "+3V3")]

OUT_X = 46        # servo outputs: channel 1 signal pin
OUT_Y = 89.5      # S row, + and - rows below
RC_X = 74         # RC inputs: channel 1 signal pin
RC_Y = 5.5


def stepstick_pads(n):
    ms1, ms2 = ADDR_PINS[n]
    return {
        "1": "EN", "2": ms1, "3": ms2, "4": f"U{n}_P4", "5": f"U{n}_P5", "6": "GND",
        "7": f"STEP{n}", "8": f"DIR{n}",
        "9": "GND", "10": "+3V3", "11": f"M{n}_1B", "12": f"M{n}_1A",
        "13": f"M{n}_2A", "14": f"M{n}_2B", "15": "GND", "16": "VM",
    }


def pca9685_pads():
    pads = {str(p): "GND" for p in (1, 2, 3, 4, 5, 14, 24, 25)}  # A0-A5 -> address 0x40, EXTCLK off
    pads.update({str(6 + i): f"LED{i}" for i in range(8)})
    pads.update({str(15 + i): f"LED{8 + i}" for i in range(8)})
    pads.update({"23": "PWM_OE", "26": "SCL", "27": "SDA", "28": "+3V3"})
    return pads


# ref, library, footprint, value, x, y, rotation, {pad: net}, LCSC (None = hand-soldered)
PARTS = [
    # rotation 270: pin 1 on the right, the pins run to the left; rotation 90 (headers): pin 1 left
    ("J10", *SOCKET, "DevKitC-1 J1", DK_PIN1_X, DK_J1_Y, 270,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(DK_J1)}, None),
    ("J11", *SOCKET, "DevKitC-1 J3", DK_PIN1_X, DK_J3_Y, 270,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(DK_J3)}, None),

    # shared TMC UART: TX through 1k, all PDN_UART pins on one line; EN pulled high = drivers off at boot
    ("R1", *R0805, "1k", 30, 15, 0, {"1": "UART_TX", "2": "UART"}, "C17513"),
    ("R2", *R0805, "10k", 30, 18, 0, {"1": "EN", "2": "+3V3"}, "C17414"),

    # power: everything from the BEC rail (the + pins of all 3-pin headers), 5 V regulator for the ESP
    # and the serial receiver, drivers' VM from the BEC or (jumper) from a 2-3S battery
    ("U4", "Package_TO_SOT_SMD", "SOT-223-3_TabPin2", "AMS1117-5.0", 72, 29, 0,
     {"1": "GND", "2": "+5V_REG", "3": "VBEC"}, "C6187"),
    ("C5", *C0805, "10u 25V", 79, 25.5, 90, {"1": "VBEC", "2": "GND"}, "C15850"),
    ("C6", *C0805, "22u 25V", 79, 32, 90, {"1": "+5V_REG", "2": "GND"}, "C45783"),
    ("D4", *SOD123, "B5819W", 66.5, 21, 90, {"1": "+5V", "2": "+5V_REG"}, "C8598"),
    ("C7", "Capacitor_THT", "CP_Radial_D10.0mm_P5.00mm", "1000u 16V", 25, 93, 0,
     {"1": "VBEC", "2": "GND"}, None),
    ("J9", "TerminalBlock_Phoenix", "TerminalBlock_Phoenix_MKDS-1,5-2-5.08_1x02_P5.08mm_Horizontal",
     "VM batt", 6, 84, 270, {"1": "VBAT_IN", "2": "GND"}, None),
    ("D9", "Diode_SMD", "D_SMA", "SS34", 16, 79, 0, {"1": "VBAT", "2": "VBAT_IN"}, "C8678"),
    ("JP9", *JUMPER, "VM BEC|BATT", 21, 84, 0, {"1": "VBAT", "2": "VM", "3": "VBEC"}, None),

    # RC inputs: block of S / + / - rows, 1k series + Schottky clamp to 3V3
    ("J4", "rc_crane", "PinHeader_3x04_P2.54mm", "RC in", RC_X, RC_Y, 90, block_pads(4, "RC{}_IN"), None),

    # serial receiver (CRSF / SBUS / iBUS): G 5V RX TX, seen from the ESP
    ("J7", HDR, "PinHeader_1x04_P2.54mm_Vertical", "Serial RX", 86, 21, 90,
     {"1": "GND", "2": "+5V_REG", "3": "SRX_IN", "4": "STX_OUT"}, None),
    ("R7", *R0805, "1k", 36, 15, 0, {"1": "SRX_IN", "2": "SRX"}, "C17513"),
    ("R8", *R0805, "1k", 36, 18, 0, {"1": "STX_OUT", "2": "STX"}, "C17513"),
    # I2C expansion (second PCA9685, display, ...): G 3V3 SDA SCL
    ("J8", HDR, "PinHeader_1x04_P2.54mm_Vertical", "I2C", 86, 31, 90,
     {"1": "GND", "2": "+3V3", "3": "SDA", "4": "SCL"}, None),

    # PCA9685: 16 PWM outputs, address 0x40, OE pulled high = outputs off until the firmware enables them
    # LED0-7 on the left side, LED8-15 on the right: both fan out to the resistor row without crossing
    ("U5", "Package_SO", "TSSOP-28_4.4x9.7mm_P0.65mm", "PCA9685PW", 65, 76.4, 0, pca9685_pads(), "C2678753"),
    ("C8", *C0805, "100n", 69.8, 69.8, 0, {"1": "+3V3", "2": "GND"}, "C49678"),
    ("C9", *C0805, "10u 25V", 44, 14, 0, {"1": "+3V3", "2": "GND"}, "C15850"),
    ("R9", *R0805, "4.7k", 15, 24, 0, {"1": "SDA", "2": "+3V3"}, "C17673"),
    ("R10", *R0805, "4.7k", 21, 24, 0, {"1": "SCL", "2": "+3V3"}, "C17673"),
    ("R11", *R0805, "10k", 27, 24, 0, {"1": "PWM_OE", "2": "+3V3"}, "C17414"),

    # servo / ESC outputs: S / + / - rows, 220R series resistor per channel
    ("J30", "rc_crane", "PinHeader_3x16_P2.54mm", "PWM out", OUT_X, OUT_Y, 90, block_pads(16, "PWM{}"), None),
]

for i in range(4):
    x = RC_X + i * 2.54
    PARTS += [
        # rotation 90: pad 2 on top (towards the header), pad 1 below
        (f"R{20 + i}", *R0805, "1k", x, 15, 90, {"1": f"RC{i}", "2": f"RC{i}_IN"}, "C17513"),
        (f"D{20 + i}", *SOD123, "B5819W", x, 19.5, 90, {"1": "+3V3", "2": f"RC{i}"}, "C8598"),
    ]

for n, x in enumerate(DRIVER_X):
    PARTS += [
        (f"U{10 + n}", "Module", "Pololu_Breakout-16_15.2x20.3mm", f"TMC2209 #{n}", x, DRIVER_Y, 0,
         stepstick_pads(n), None),
        (f"J{12 + n}", "Connector_PinSocket_2.54mm", "PinSocket_1x01_P2.54mm_Vertical", f"DIAG{n}",
         x, DRIVER_Y - 5, 0, {"1": f"DIAG{n}"}, None),
        # UART pin select: bridge the centre pad to pin 4 or pin 5, depending on the driver brand
        (f"JP{1 + n}", *JUMPER, "UART 4|5", x - 4.5, DRIVER_Y + 6, 90,
         {"1": f"U{n}_P5", "2": "UART", "3": f"U{n}_P4"}, None),
        (f"J{20 + n}", "Connector_JST", "JST_XH_B4B-XH-A_1x04_P2.50mm_Vertical", f"Motor {n}",
         x + 2, DRIVER_Y + 24, 0, {"1": f"M{n}_1A", "2": f"M{n}_1B", "3": f"M{n}_2A", "4": f"M{n}_2B"}, None),
        # VM buffer between the modules (5 mm, 25 V is enough for 3S)
        (f"C{1 + n}", "Capacitor_THT", "CP_Radial_D5.0mm_P2.00mm", "100u 25V", x + 16.35, DRIVER_Y + 13.5, 0,
         {"1": "VM", "2": "GND"}, None),
    ]

for i in range(16):
    x = OUT_X + i * 2.54
    # rotation 90: pad 1 below, next to the header
    PARTS.append((f"R{40 + i}", *R0805, "220", x, OUT_Y - 6, 90, {"1": f"PWM{i}", "2": f"LED{i}"}, "C17557"))

# references that need a hand-picked position (absolute mm)
REF_POS = {f"J{20 + n}": (x + 3.75, DRIVER_Y + 29.2) for n, x in enumerate(DRIVER_X)}
REF_POS["U5"] = (65, 76.4)  # inside the package outline

# references that would not fit: these get a group label in SILK instead
HIDE_REF = ({f"R{40 + i}" for i in range(16)} | {f"R{20 + i}" for i in range(4)} | {f"D{20 + i}" for i in range(4)}
            | {f"J{12 + n}" for n in range(4)} | {"J4", "J7", "J8", "J30", "C7", "J9"})

# name, track width, clearance, nets
NET_CLASSES = [
    ("Power", 0.8, 0.25, ["GND", "VBEC", "VM", "VBAT", "VBAT_IN"]
     + [f"M{n}_{c}" for n in range(4) for c in ("1A", "1B", "2A", "2B")]),
    ("Supply", 0.5, 0.2, ["+5V", "+5V_REG", "+3V3"]),
]
DEFAULT_TRACK = 0.25
DEFAULT_CLEARANCE = 0.2

# text, x, y, size, justify (-1 left, 0 centre, 1 right)
SILK = [
    ("RC CRANE ADVANCED v1", 25, 2.5, 1.2, 0),
    ("ESP32-S3-DevKitC-1   < USB", 25, 5.2, 0.8, 0),
    ("antenna", 56, 20.4, 0.8, 0),
    ("github.com/35services/linear-actuator-crane", 50, 98.6, 0.8, 0),
    ("RC IN", RC_X - 4.2, RC_Y + 2.54, 0.8, 1),
    ("S", RC_X - 2.6, RC_Y, 0.8, 1), ("+", RC_X - 2.6, RC_Y + 2.54, 0.8, 1), ("-", RC_X - 2.6, RC_Y + 5.08, 0.8, 1),
    ("G 5V RX TX", 89.8, 18.8, 0.8, 0),
    ("J7 CRSF/SBUS", 89.8, 23.2, 0.8, 0),
    ("G 3V3 SDA SCL", 89.8, 28.8, 0.8, 0),
    ("J8 I2C", 89.8, 33.2, 0.8, 0),
    ("PWM OUT", OUT_X - 4.2, OUT_Y + 2.54, 0.8, 1),
    ("S", OUT_X - 2.6, OUT_Y, 0.8, 1), ("+", OUT_X - 2.6, OUT_Y + 2.54, 0.8, 1),
    ("-", OUT_X - 2.6, OUT_Y + 5.08, 0.8, 1),
    ("220R", OUT_X - 2.6, OUT_Y - 6, 0.8, 1),
    ("VM from", 21, 81.6, 0.8, 0),
    ("BATT", 19.7, 86.4, 0.8, 1),
    ("BEC", 22.3, 86.4, 0.8, -1),
    ("J9 VM 2-3S", 6, 75.5, 0.8, 0),
    ("C7 1000u", 21.6, 97.2, 0.8, 1),
]
for i in range(16):
    SILK.append((str(i + 1), OUT_X + i * 2.54, OUT_Y + 7.4, 0.8, 0))
for i in range(4):
    SILK.append((str(i + 1), RC_X + i * 2.54, RC_Y - 2.1, 0.8, 0))
for n, x in enumerate(DRIVER_X):
    SILK += [
        (f"TMC2209 #{n}", x + 6.35, DRIVER_Y + 4, 0.9, 0),
        ("1A 1B 2A 2B", x + 5.75, DRIVER_Y + 20.4, 0.8, 0),
        ("DIAG", x - 2, DRIVER_Y - 5, 0.8, 1),
        ("UART", x - 4.5, DRIVER_Y + 2.3, 0.8, 0),
        ("5", x - 6.4, DRIVER_Y + 4.7, 0.8, 0),
        ("4", x - 6.4, DRIVER_Y + 7.3, 0.8, 0),
    ]

# DevKit pin names, vertical, outside the two socket rows
VERTICAL_SILK = ([(p, DK_PIN1_X - i * 2.54, DK_J1_Y - 2.6, 0.8) for i, p in enumerate(DK_J1)]
                 + [(p, DK_PIN1_X - i * 2.54, DK_J3_Y + 2.6, 0.8) for i, p in enumerate(DK_J3)])
GROUND_STUBS = [("U5", {"24", "25"})]  # PCA9685 A5 + EXTCLK sit between other pins
BOTTOM_SIDE = set()
MODELS = {}

if __name__ == "__main__":
    board_tools.main(sys.modules[__name__], sys.argv, __doc__)
