"""Generates the RC crane carrier board (ESP32-C3 SuperMini + 2x TMC2209 StepStick).

Run with KiCad's bundled Python (it provides the pcbnew module), see build.sh:

    generate_pcb.py place  <board.kicad_pcb> <board.dsn> [tht|smd]   # place parts, nets, outline -> DSN for Freerouting
    generate_pcb.py finish <board.kicad_pcb> <board.ses>             # import routes, add GND pours

Variants:
    tht  everything through-hole, for hand soldering
    smd  small passives, diodes and the regulator as SMD with LCSC part numbers for JLCPCB
         assembly; sockets, headers, connectors and the two 100 uF capacitors stay
         through-hole and are hand-soldered

All placement and connectivity lives in the tables below. Coordinates in mm,
KiCad convention: y grows downwards, rotation in degrees counter-clockwise.
"""

import json
import os
import sys

import pcbnew

FP_DIR = os.environ.get(
    "KICAD_FOOTPRINT_DIR",
    "/Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints",
)

BOARD_W = 80
# The tables below were laid out for a 10 mm wider board; everything is shifted left by this
X_OFFSET = 10
BOARD_H = 64
HOLES = [(3.5, 3.5), (BOARD_W - 3.5, 3.5), (3.5, BOARD_H - 3.5), (BOARD_W - 3.5, BOARD_H - 3.5)]

# ESP32-C3 SuperMini, top view, USB-C towards the top edge.
# CHECK AGAINST THE SILKSCREEN OF YOUR BOARD - clones differ.
ESP_ROW_SPACING = 15.24
ESP_LEFT = ["GPIO5", "GPIO6", "GPIO7", "GPIO8", "GPIO9", "GPIO10", "GPIO20", "GPIO21"]
ESP_RIGHT = ["5V", "GND", "3V3", "GPIO4", "GPIO3", "GPIO2", "GPIO1", "GPIO0"]
ESP_LABELS = {"GPIO20": "RX", "GPIO21": "TX", "GND": "G"}

# What each ESP pin connects to (unlisted pins stay unconnected)
ESP_NETS = {
    "5V": "+5V", "GND": "GND", "3V3": "+3V3",
    "GPIO4": "STEP0", "GPIO5": "DIR0",
    "GPIO0": "STEP1", "GPIO1": "DIR1",
    "GPIO6": "EN", "GPIO7": "DIAG",
    "GPIO20": "UART", "GPIO21": "UART_TX",
    "GPIO3": "RC0", "GPIO10": "RC1",
}


def stepstick_pads(n, ms1):
    """TMC2209 StepStick pad -> net. Pads 1-8 left column top->bottom, 9-16 right column bottom->top."""
    return {
        "1": "EN", "2": ms1, "3": "GND", "4": f"U{n}_P4", "5": f"U{n}_P5", "6": "GND",
        "7": f"STEP{n}", "8": f"DIR{n}",
        "9": "GND", "10": "+3V3", "11": f"M{n}_1B", "12": f"M{n}_1A",
        "13": f"M{n}_2A", "14": f"M{n}_2B", "15": "GND", "16": "VBEC",
    }


# ref, library, footprint, value, x, y, rotation, {pad: net}
PARTS = [
    # ESP32-C3 SuperMini sockets
    ("J10", "Connector_PinSocket_2.54mm", "PinSocket_1x08_P2.54mm_Vertical", "SuperMini L", 66, 8, 0,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(ESP_LEFT)}),
    ("J11", "Connector_PinSocket_2.54mm", "PinSocket_1x08_P2.54mm_Vertical", "SuperMini R", 66 + ESP_ROW_SPACING, 8, 0,
     {str(i + 1): ESP_NETS.get(p) for i, p in enumerate(ESP_RIGHT)}),

    # TMC2209 drivers: #0 boom lift (address 0), #1 telescope (address 1 via MS1 = 3V3)
    ("U2", "Module", "Pololu_Breakout-16_15.2x20.3mm", "TMC2209 #0 lift", 24, 16, 0, stepstick_pads(0, "GND")),
    ("U3", "Module", "Pololu_Breakout-16_15.2x20.3mm", "TMC2209 #1 tele", 46, 16, 0, stepstick_pads(1, "+3V3")),
    ("C1", "Capacitor_THT", "CP_Radial_D8.0mm_P3.50mm", "100u 35V", 31, 9.5, 0, {"1": "VBEC", "2": "GND"}),
    ("C2", "Capacitor_THT", "CP_Radial_D8.0mm_P3.50mm", "100u 35V", 53, 9.5, 0, {"1": "VBEC", "2": "GND"}),

    # UART pin select: bridge centre to pin 4 or pin 5 depending on the driver brand
    ("JP1", "Jumper", "SolderJumper-3_P1.3mm_Open_RoundedPad1.0x1.5mm", "UART 4|5", 19.5, 24.9, 90,
     {"1": "U0_P5", "2": "UART", "3": "U0_P4"}),
    ("JP2", "Jumper", "SolderJumper-3_P1.3mm_Open_RoundedPad1.0x1.5mm", "UART 4|5", 41.3, 24.9, 90,
     {"1": "U1_P5", "2": "UART", "3": "U1_P4"}),
    ("R1", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", "1k", 69.8, 11, 0,
     {"1": "UART_TX", "2": "UART"}),

    # Stall detection: DIAG wire from each module -> diode OR -> GPIO7, 10k pull-down
    ("J12", "Connector_PinSocket_2.54mm", "PinSocket_1x01_P2.54mm_Vertical", "DIAG0", 24, 11, 0, {"1": "DIAG0"}),
    ("J13", "Connector_PinSocket_2.54mm", "PinSocket_1x01_P2.54mm_Vertical", "DIAG1", 46, 11, 0, {"1": "DIAG1"}),
    ("R2", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", "10k", 69.8, 14.6, 0,
     {"1": "DIAG", "2": "GND"}),
    ("D2", "Diode_THT", "D_DO-35_SOD27_P7.62mm_Horizontal", "1N4148", 69.8, 18.2, 0, {"1": "DIAG", "2": "DIAG0"}),
    ("D3", "Diode_THT", "D_DO-35_SOD27_P7.62mm_Horizontal", "1N4148", 69.8, 21.8, 0, {"1": "DIAG", "2": "DIAG1"}),

    # Motor connectors: 1A 1B 2A 2B (coil pairs next to each other)
    ("J2", "Connector_JST", "JST_XH_B4B-XH-A_1x04_P2.50mm_Vertical", "Motor lift", 26, 40, 0,
     {"1": "M0_1A", "2": "M0_1B", "3": "M0_2A", "4": "M0_2B"}),
    ("J3", "Connector_JST", "JST_XH_B4B-XH-A_1x04_P2.50mm_Vertical", "Motor tele", 48, 40, 0,
     {"1": "M1_1A", "2": "M1_1B", "3": "M1_2A", "4": "M1_2B"}),

    # Everything runs from the ESC's BEC (6 V / 7.4 V, 4 A), which arrives through the + pin of the
    # RC headers: the drivers' VM directly, the ESP32 through a 5 V regulator
    ("U4", "Package_TO_SOT_THT", "TO-220-3_Vertical", "LM2940-5.0", 24, 52, 0,
     {"1": "VBEC", "2": "GND", "3": "+5V_REG"}),
    ("C3", "Capacitor_THT", "C_Disc_D5.0mm_W2.5mm_P5.00mm", "470n", 34, 52, 0, {"1": "VBEC", "2": "GND"}),
    ("C4", "Capacitor_THT", "CP_Radial_D6.3mm_P2.50mm", "47u 16V", 43, 52, 0, {"1": "+5V_REG", "2": "GND"}),
    ("D4", "Diode_THT", "D_DO-41_SOD81_P10.16mm_Horizontal", "1N5817", 50, 52, 0, {"1": "+5V", "2": "+5V_REG"}),

    # RC inputs: S + -, 1k series + BAT85 clamp to 3V3
    ("J4", "Connector_PinHeader_2.54mm", "PinHeader_1x03_P2.54mm_Vertical", "RC lift", 66, 58, 90,
     {"1": "RC0_IN", "2": "VBEC", "3": "GND"}),
    ("J5", "Connector_PinHeader_2.54mm", "PinHeader_1x03_P2.54mm_Vertical", "RC tele", 76, 58, 90,
     {"1": "RC1_IN", "2": "VBEC", "3": "GND"}),
    ("R3", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", "1k", 66, 41, 90,
     {"1": "RC0_IN", "2": "RC0"}),
    ("D5", "Diode_THT", "D_DO-35_SOD27_P7.62mm_Horizontal", "BAT85", 70, 41, 90, {"1": "+3V3", "2": "RC0"}),
    ("R4", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", "1k", 76, 41, 90,
     {"1": "RC1_IN", "2": "RC1"}),
    ("D6", "Diode_THT", "D_DO-35_SOD27_P7.62mm_Horizontal", "BAT85", 80, 41, 90, {"1": "+3V3", "2": "RC1"}),
]

# SMD variant: these parts replace their THT counterparts. Everything not listed here
# (sockets, headers, JST, solder jumpers) is kept and hand-soldered. All LCSC parts here
# are JLCPCB basic parts (no extended-part fee); the 100 uF VM capacitors C1/C2 stay
# THT on purpose, the only SMD option is an extended part. Check with check_jlc_parts.py.
# ref: library, footprint, value, x, y, rotation, {pad: net}, LCSC part number
SMD_PARTS = {
    "R1": ("Resistor_SMD", "R_0805_2012Metric", "1k", 73.6, 11, 0, {"1": "UART_TX", "2": "UART"}, "C17513"),
    "R2": ("Resistor_SMD", "R_0805_2012Metric", "10k", 73.6, 14.6, 0, {"1": "DIAG", "2": "GND"}, "C17414"),
    "D2": ("Diode_SMD", "D_SOD-123", "1N4148W", 73.6, 18.2, 0, {"1": "DIAG", "2": "DIAG0"}, "C81598"),
    "D3": ("Diode_SMD", "D_SOD-123", "1N4148W", 73.6, 21.8, 0, {"1": "DIAG", "2": "DIAG1"}, "C81598"),
    # AMS1117: 1 GND, 2 OUT (and tab), 3 IN
    "U4": ("Package_TO_SOT_SMD", "SOT-223-3_TabPin2", "AMS1117-5.0", 27, 52, 0,
           {"1": "GND", "2": "+5V_REG", "3": "VBEC"}, "C6187"),
    "C3": ("Capacitor_SMD", "C_0805_2012Metric", "10u 25V", 36, 52, 0, {"1": "VBEC", "2": "GND"}, "C15850"),
    "C4": ("Capacitor_SMD", "C_0805_2012Metric", "22u 25V", 41, 52, 0, {"1": "+5V_REG", "2": "GND"}, "C45783"),
    "D4": ("Diode_SMD", "D_SOD-123", "B5819W", 47, 52, 0, {"1": "+5V", "2": "+5V_REG"}, "C8598"),
    "R3": ("Resistor_SMD", "R_0805_2012Metric", "1k", 66, 37.2, 90, {"1": "RC0_IN", "2": "RC0"}, "C17513"),
    "D5": ("Diode_SMD", "D_SOD-123", "B5819W", 70, 37.2, 90, {"1": "+3V3", "2": "RC0"}, "C8598"),
    "R4": ("Resistor_SMD", "R_0805_2012Metric", "1k", 76, 37.2, 90, {"1": "RC1_IN", "2": "RC1"}, "C17513"),
    "D6": ("Diode_SMD", "D_SOD-123", "B5819W", 80, 37.2, 90, {"1": "+3V3", "2": "RC1"}, "C8598"),
}


def parts_for(variant):
    """PARTS as (ref, lib, name, value, x, y, rot, nets, lcsc) for the given variant."""
    if variant == "tht":
        return [p + (None,) for p in PARTS]
    return [(p[0],) + SMD_PARTS[p[0]] if p[0] in SMD_PARTS else p + (None,) for p in PARTS]


# references that need a hand-picked position (absolute mm)
REF_POS = {"JP1": (19.5, 28.4), "JP2": (41.3, 28.4)}

# name, track width, clearance, nets
NET_CLASSES = [
    ("Power", 0.8, 0.25, ["GND", "VBEC"] + [f"M{n}_{c}" for n in (0, 1) for c in ("1A", "1B", "2A", "2B")]),
    ("Supply", 0.5, 0.2, ["+5V", "+5V_REG", "+3V3"]),
]
DEFAULT_TRACK = 0.3
DEFAULT_CLEARANCE = 0.2

# text, x, y, size, justify (-1 left, 0 centre, 1 right)
SILK = [
    ("RC CRANE CARRIER v1", 45, 2.2, 1.2, 0),
    ("github.com/35services/linear-actuator-crane", 45, 62.3, 0.8, 0),
    ("ESP32-C3 SuperMini  USB ^", 73.6, 3.3, 0.8, 0),
    ("TMC2209 #0", 30.35, 27, 0.9, 0),
    ("LIFT", 30.35, 28.5, 0.9, 0),
    ("TMC2209 #1", 52.35, 27, 0.9, 0),
    ("TELE", 52.35, 28.5, 0.9, 0),
    ("1A 1B 2A 2B", 29.75, 45.3, 0.8, 0),
    ("1A 1B 2A 2B", 51.75, 45.3, 0.8, 0),
    ("DIAG", 21.8, 11, 0.8, 1),
    ("DIAG", 43.8, 11, 0.8, 1),
    ("UART", 19.5, 21.2, 0.8, 0),
    ("5", 17.6, 23.6, 0.8, 0),
    ("4", 17.6, 26.2, 0.8, 0),
    ("UART", 41.3, 21.2, 0.8, 0),
    ("S + -", 68.54, 61.2, 0.8, 0),
    ("S + -", 78.54, 61.2, 0.8, 0),
    ("RC LIFT", 68.54, 54.6, 0.8, 0),
    ("RC TELE", 78.54, 54.6, 0.8, 0),
    ("BEC 6/7.4V", 28, 56.6, 0.8, 0),
]


def mm(v):
    return pcbnew.FromMM(v)


def pos(x, y):
    return pcbnew.VECTOR2I(mm(x), mm(y))


def add_text(board, text, x, y, size, justify=0, layer=pcbnew.F_SilkS):
    t = pcbnew.PCB_TEXT(board)
    t.SetText(text)
    t.SetPosition(pos(x, y))
    t.SetLayer(layer)
    t.SetTextSize(pcbnew.VECTOR2I(mm(size), mm(size)))
    t.SetTextThickness(mm(size * 0.15))
    t.SetHorizJustify({-1: pcbnew.GR_TEXT_H_ALIGN_LEFT, 0: pcbnew.GR_TEXT_H_ALIGN_CENTER,
                       1: pcbnew.GR_TEXT_H_ALIGN_RIGHT}[justify])
    board.Add(t)


def setup_net_classes(board):
    ns = board.GetDesignSettings().m_NetSettings
    default = ns.GetDefaultNetclass()
    default.SetTrackWidth(mm(DEFAULT_TRACK))
    default.SetClearance(mm(DEFAULT_CLEARANCE))
    default.SetViaDiameter(mm(0.8))
    default.SetViaDrill(mm(0.4))
    for name, width, clearance, nets in NET_CLASSES:
        nc = pcbnew.NETCLASS(name)
        nc.SetTrackWidth(mm(width))
        nc.SetClearance(mm(clearance))
        nc.SetViaDiameter(mm(1.0))
        nc.SetViaDrill(mm(0.5))
        ns.SetNetclass(name, nc)
        for net in nets:
            ns.SetNetclassPatternAssignment(net, name)
    ns.RecomputeEffectiveNetclasses()


# GND pads sit in the pour and are also connected by tracks, one thermal spoke is enough
DRC_RULES = """(version 1)
(rule "one thermal spoke is enough"
  (constraint min_resolved_spokes 1))
"""


def write_project_rules(board_path):
    """Custom DRC rules, and ignore 'library not configured' (footprints come from KiCad's stock libraries)."""
    base = os.path.splitext(board_path)[0]
    with open(base + ".kicad_dru", "w") as f:
        f.write(DRC_RULES)
    pro_path = base + ".kicad_pro"
    pro = {}
    if os.path.exists(pro_path):
        with open(pro_path) as f:
            pro = json.load(f)
    severities = pro.setdefault("board", {}).setdefault("design_settings", {}).setdefault("rule_severities", {})
    severities.update({"lib_footprint_issues": "ignore", "lib_footprint_mismatch": "ignore"})
    with open(pro_path, "w") as f:
        json.dump(pro, f, indent=2)


def write_bom(path, parts):
    groups = {}
    for ref, lib, name, value, *_, lcsc in parts:
        groups.setdefault((value, f"{lib}:{name}", lcsc or ""), []).append(ref)
    with open(path, "w") as f:
        f.write("Qty,References,Value,Footprint,LCSC\n")
        for (value, footprint, lcsc), refs in sorted(groups.items(), key=lambda g: g[1][0]):
            f.write(f'{len(refs)},"{" ".join(refs)}","{value}","{footprint}","{lcsc}"\n')


def write_jlcpcb_files(board, out_dir, parts):
    """BOM + CPL in JLCPCB's format, only the parts JLCPCB places (those with an LCSC number)."""
    assembled = {p[0]: p for p in parts if p[-1]}
    groups = {}
    for ref, lib, name, value, *_, lcsc in assembled.values():
        groups.setdefault((value, name, lcsc), []).append(ref)
    with open(os.path.join(out_dir, "jlcpcb_bom.csv"), "w") as f:
        f.write("Comment,Designator,Footprint,LCSC Part #\n")
        for (value, name, lcsc), refs in sorted(groups.items(), key=lambda g: g[1][0]):
            f.write(f'"{value}","{",".join(refs)}","{name}","{lcsc}"\n')
    with open(os.path.join(out_dir, "jlcpcb_cpl.csv"), "w") as f:
        f.write("Designator,Mid X,Mid Y,Layer,Rotation\n")
        for fp in sorted(board.GetFootprints(), key=lambda fp: fp.GetReference()):
            if fp.GetReference() in assembled:
                p = fp.GetPosition()
                # Gerber coordinates: y axis points up
                f.write(f"{fp.GetReference()},{pcbnew.ToMM(p.x):.3f}mm,{-pcbnew.ToMM(p.y):.3f}mm,Top,"
                        f"{fp.GetOrientationDegrees() % 360:.0f}\n")


def place(board_path, dsn_path, variant="tht"):
    parts = parts_for(variant)
    board = pcbnew.CreateEmptyBoard()
    setup_net_classes(board)

    nets = {}

    def net(name):
        if name not in nets:
            item = pcbnew.NETINFO_ITEM(board, name)
            board.Add(item)
            nets[name] = item
        return nets[name]

    for ref, lib, name, value, x, y, rot, pad_nets, lcsc in parts:
        x -= X_OFFSET
        fp = pcbnew.FootprintLoad(os.path.join(FP_DIR, lib + ".pretty"), name)
        if fp is None:
            sys.exit(f"footprint not found: {lib}:{name}")
        fp.SetFPID(pcbnew.LIB_ID(lib, name))
        fp.SetReference(ref)
        fp.SetValue(value)
        fp.Value().SetVisible(False)
        fp.SetPosition(pos(x, y))
        fp.SetOrientationDegrees(rot)
        board.Add(fp)
        pads = list(fp.Pads())
        if ref[0] in "RD" and lib.endswith("_SMD"):
            # SMD parts are too small for text inside: put the reference just beside the pads
            box = pads[0].GetBoundingBox()
            for pad in pads[1:]:
                box.Merge(pad.GetBoundingBox())
            ref_text = fp.Reference()
            ref_text.SetTextSize(pcbnew.VECTOR2I(mm(0.8), mm(0.8)))
            ref_text.SetTextThickness(mm(0.12))
            ref_text.SetTextAngleDegrees(0)
            if rot % 180 == 0:
                ref_text.SetHorizJustify(pcbnew.GR_TEXT_H_ALIGN_LEFT)
                ref_text.SetPosition(pcbnew.VECTOR2I(box.GetRight() + mm(0.6), box.GetCenter().y))
            else:
                ref_text.SetPosition(pcbnew.VECTOR2I(box.GetCenter().x, box.GetBottom() + mm(1.0)))
        elif ref[0] in "RD" or ref in ("U2", "U3"):
            # axial parts are packed tightly: put the reference inside the body outline,
            # the driver modules have empty space between their pin rows
            ref_text = fp.Reference()
            ref_text.SetPosition(pcbnew.VECTOR2I(sum(p.GetPosition().x for p in pads) // len(pads),
                                                 sum(p.GetPosition().y for p in pads) // len(pads)))
            ref_text.SetTextSize(pcbnew.VECTOR2I(mm(0.8), mm(0.8)))
            ref_text.SetTextThickness(mm(0.12))
            ref_text.SetTextAngleDegrees(rot)
        if ref in REF_POS:
            fp.Reference().SetPosition(pos(REF_POS[ref][0] - X_OFFSET, REF_POS[ref][1]))
            fp.Reference().SetTextAngleDegrees(0)
        for pad in pads:
            n = pad_nets.get(pad.GetNumber())
            if n:
                pad.SetNet(net(n))

    for i, (x, y) in enumerate(HOLES, start=1):
        fp = pcbnew.FootprintLoad(os.path.join(FP_DIR, "MountingHole.pretty"), "MountingHole_3.2mm_M3")
        fp.SetFPID(pcbnew.LIB_ID("MountingHole", "MountingHole_3.2mm_M3"))
        fp.SetReference(f"H{i}")
        fp.Reference().SetVisible(False)
        fp.Value().SetVisible(False)
        fp.SetPosition(pos(x, y))
        board.Add(fp)

    outline = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_RECTANGLE)
    outline.SetStart(pos(0, 0))
    outline.SetEnd(pos(BOARD_W, BOARD_H))
    outline.SetLayer(pcbnew.Edge_Cuts)
    outline.SetWidth(mm(0.1))
    board.Add(outline)

    # ESP pin names next to the sockets
    for i, p in enumerate(ESP_LEFT):
        add_text(board, ESP_LABELS.get(p, p.replace("GPIO", "")), 66 - X_OFFSET - 2.2, 8 + i * 2.54, 0.8, 1)
    for i, p in enumerate(ESP_RIGHT):
        add_text(board, ESP_LABELS.get(p, p.replace("GPIO", "")), 66 - X_OFFSET + ESP_ROW_SPACING + 2.2, 8 + i * 2.54, 0.8, -1)
    for text, x, *args in SILK:
        if variant == "smd" and text.startswith("RC CRANE CARRIER"):
            text += " SMD"
        add_text(board, text, x - X_OFFSET, *args)

    board.Save(board_path)
    write_project_rules(board_path)
    out_dir = os.path.dirname(os.path.abspath(board_path))
    write_bom(os.path.join(out_dir, "bom.csv"), parts)
    if variant == "smd":
        write_jlcpcb_files(board, out_dir, parts)
    if not pcbnew.ExportSpecctraDSN(board, dsn_path):
        sys.exit("DSN export failed")
    print(f"placed {len(parts)} parts ({variant}), {len(nets)} nets -> {board_path}, {dsn_path}")


def finish(board_path, ses_path):
    board = pcbnew.LoadBoard(board_path)
    if not pcbnew.ImportSpecctraSES(board, ses_path):
        sys.exit("SES import failed")

    gnd = board.FindNet("GND")
    for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
        zone = pcbnew.ZONE(board)
        zone.SetLayer(layer)
        zone.SetNet(gnd)
        zone.SetLocalClearance(mm(0.3))
        zone.SetMinThickness(mm(0.25))
        zone.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
        zone.SetThermalReliefGap(mm(0.4))
        zone.SetThermalReliefSpokeWidth(mm(0.5))
        o = zone.Outline()
        o.NewOutline()
        for x, y in [(0.3, 0.3), (BOARD_W - 0.3, 0.3), (BOARD_W - 0.3, BOARD_H - 0.3), (0.3, BOARD_H - 0.3)]:
            o.Append(mm(x), mm(y))
        board.Add(zone)

    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    board.Save(board_path)
    print(f"routed and poured -> {board_path}")


if __name__ == "__main__":
    if sys.argv[1:2] == ["place"] and len(sys.argv) in (4, 5) and sys.argv[4:5] in ([], ["tht"], ["smd"]):
        place(*sys.argv[2:])
    elif sys.argv[1:2] == ["finish"] and len(sys.argv) == 4:
        finish(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
