"""Shared board building for the generated PCBs (advanced board, stacked boards).

A design is any object (usually the generator module itself) with these attributes:

    BOARD_W, BOARD_H        outline in mm
    HOLES                   M3 mounting holes [(x, y)]
    KEEPOUTS                copper-free rectangles [(x0, y0, x1, y1)]
    PARTS                   [(ref, lib, footprint, value, x, y, rotation, {pad: net}, lcsc)]
    NET_CLASSES             [(name, track width, clearance, [nets])]
    DEFAULT_TRACK, DEFAULT_CLEARANCE
    SILK                    [(text, x, y, size, justify)]
    VERTICAL_SILK           [(text, x, y, size)]
    HIDE_REF, REF_POS       references to hide / to put at (x, y)
    GROUND_STUBS            [(ref, {pads})] fine-pitch GND pads the pour can't reach
    BOTTOM_SIDE             references mounted on the bottom side
    MODELS                  {ref: [(model file, (x, y, z) offset, (rx, ry, rz) rotation)]} replaces the 3D models
    JLCPCB                  write jlcpcb_bom.csv / jlcpcb_cpl.csv

Footprints from the library "rc_crane" are generated: "PinHeader_<rows>x<cols>_P2.54mm" is a
servo-style block (rows S, +, -), with the suffix "_Horizontal" a right-angle one.
"""

import json
import os
import sys

import pcbnew
from generate_pcb import FP_DIR, add_text, mm, pos, write_bom, write_jlcpcb_files, write_project_rules

HDR = "Connector_PinHeader_2.54mm"
MODEL_DIR = "${KICAD10_3DMODEL_DIR}"


def block_pads(cols, signal, rows=("S", "+", "-"), channel=lambda c: c):
    """Servo-style block: pad = row * cols + column + 1. `rows` names the rows from row 0 (the
    footprint's first row), `channel` maps a column to the channel number in `signal`."""
    nets = {"S": None, "+": "VBEC", "-": "GND"}
    pads = {}
    for r, kind in enumerate(rows):
        for c in range(cols):
            pads[str(r * cols + c + 1)] = signal.format(channel(c)) if kind == "S" else nets[kind]
    return pads


def add_vertical_text(board, text, x, y, size):
    t = pcbnew.PCB_TEXT(board)
    t.SetText(text)
    t.SetPosition(pos(x, y))
    t.SetLayer(pcbnew.F_SilkS)
    t.SetTextSize(pcbnew.VECTOR2I(mm(size), mm(size)))
    t.SetTextThickness(mm(size * 0.15))
    t.SetTextAngleDegrees(90)
    board.Add(t)


def setup_net_classes(board, d):
    # the autorouter necks tracks down next to fine-pitch pads; they are widened to 0.15 mm in finish()
    board.GetDesignSettings().m_TrackMinWidth = mm(0.15)
    ns = board.GetDesignSettings().m_NetSettings
    default = ns.GetDefaultNetclass()
    default.SetTrackWidth(mm(d.DEFAULT_TRACK))
    default.SetClearance(mm(d.DEFAULT_CLEARANCE))
    default.SetViaDiameter(mm(0.7))
    default.SetViaDrill(mm(0.35))
    for name, width, clearance, nets in d.NET_CLASSES:
        nc = pcbnew.NETCLASS(name)
        nc.SetTrackWidth(mm(width))
        nc.SetClearance(mm(clearance))
        nc.SetViaDiameter(mm(1.0))
        nc.SetViaDrill(mm(0.5))
        ns.SetNetclass(name, nc)
        for net in nets:
            ns.SetNetclassPatternAssignment(net, name)
    ns.RecomputeEffectiveNetclasses()


def model(filename, offset=(0, 0, 0), rotation=(0, 0, 0)):
    m = pcbnew.FP_3DMODEL()
    m.m_Filename = filename
    m.m_Offset = pcbnew.VECTOR3D(*offset)
    m.m_Rotation = pcbnew.VECTOR3D(*rotation)
    return m


def header_block(board, name):
    """rows x cols pin header block (rows S, +, -), built from KiCad's 1 x cols header.

    Vertical: the pins run along +y, the rows sit at -x, so rotation 90 puts them below row 0.
    Horizontal (right angle): the pins point to +x, row 0 is the lowest one, next to the
    board edge, the rows above it sit at -x."""
    rows, cols = (int(v) for v in name.split("_")[1].split("x"))
    horizontal = name.endswith("_Horizontal")
    base_name = f"PinHeader_1x{cols:02d}_P2.54mm_" + ("Horizontal" if horizontal else "Vertical")
    base = pcbnew.FootprintLoad(os.path.join(FP_DIR, HDR + ".pretty"), base_name)
    fp = pcbnew.FOOTPRINT(board)
    fp.SetFPID(pcbnew.LIB_ID("rc_crane", name))
    fp.SetAttributes(pcbnew.FP_THROUGH_HOLE)
    for row in range(rows):
        for pad in base.Pads():
            p = pcbnew.PAD(pad)
            p.SetParent(fp)
            p.SetNumber(str(row * cols + int(pad.GetNumber())))
            p.SetFPRelativePosition(pcbnew.VECTOR2I(pad.GetFPRelativePosition().x - mm(2.54 * row),
                                                    pad.GetFPRelativePosition().y))
            fp.Add(p)
        for m in base.Models():
            # right angle: each row sits one pitch higher
            fp.Models().append(model(m.m_Filename, (-2.54 * row, 0, 2.54 * row if horizontal else 0)))
    x0, x1, y0, y1 = -(rows - 1) * 2.54 - 1.27, 1.27, -1.27, (cols - 1) * 2.54 + 1.27
    courtyard_x1 = x1
    if horizontal:
        # the plastic body and the bent pins reach 10 mm towards +x
        courtyard_x1 = 10.5
    for layer, grow, width, right in ((pcbnew.F_SilkS, 0.11, 0.12, x1), (pcbnew.F_CrtYd, 0.5, 0.05, courtyard_x1)):
        r = pcbnew.PCB_SHAPE(fp, pcbnew.SHAPE_T_RECTANGLE)
        r.SetStart(pcbnew.VECTOR2I(mm(x0 - grow), mm(y0 - grow)))
        r.SetEnd(pcbnew.VECTOR2I(mm(right + grow), mm(y1 + grow)))
        r.SetLayer(layer)
        r.SetWidth(mm(width))
        fp.Add(r)
    return fp


def track(board, p0, p1, net):
    t = pcbnew.PCB_TRACK(board)
    t.SetStart(p0)
    t.SetEnd(p1)
    t.SetWidth(mm(0.25))
    t.SetLayer(pcbnew.F_Cu)
    t.SetNet(net)
    return t


def ground_stub(board, fp, pad_numbers, length=2.2):
    """Joins the given (adjacent, GND) pads and runs a short track outwards to a via into the
    ground pour - the pour can't reach pads that sit between other fine-pitch pads."""
    pads = [p for p in fp.Pads() if p.GetNumber() in pad_numbers]
    centre = fp.GetPosition()
    a = pads[0].GetPosition()
    d = a - centre
    # outward = along the axis where the pad is furthest from the centre
    step = pcbnew.VECTOR2I(0, mm(length) if d.y > 0 else -mm(length)) if abs(d.y) > abs(d.x) else \
        pcbnew.VECTOR2I(mm(length) if d.x > 0 else -mm(length), 0)
    net = pads[0].GetNet()
    points = [p.GetPosition() for p in pads] + [a + step]
    for p0, p1 in zip(points[:-2], points[1:-1]):
        board.Add(track(board, p0, p1, net))
    board.Add(track(board, a, a + step, net))
    via = pcbnew.PCB_VIA(board)
    via.SetPosition(a + step)
    via.SetWidth(mm(0.7))
    via.SetDrill(mm(0.35))
    via.SetNet(net)
    board.Add(via)


def add_keepout(board, x0, y0, x1, y1):
    zone = pcbnew.ZONE(board)
    zone.SetIsRuleArea(True)
    zone.SetDoNotAllowTracks(True)
    zone.SetDoNotAllowVias(True)
    zone.SetDoNotAllowZoneFills(True)
    zone.SetDoNotAllowPads(False)
    zone.SetDoNotAllowFootprints(False)
    zone.SetLayerSet(pcbnew.LSET.AllCuMask())
    o = zone.Outline()
    o.NewOutline()
    for x, y in [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]:
        o.Append(mm(x), mm(y))
    board.Add(zone)


def place(d, board_path, dsn_path):
    board = pcbnew.CreateEmptyBoard()
    setup_net_classes(board, d)
    nets = {}

    def net(name):
        if name not in nets:
            item = pcbnew.NETINFO_ITEM(board, name)
            board.Add(item)
            nets[name] = item
        return nets[name]

    for ref, lib, name, value, x, y, rot, pad_nets, lcsc in d.PARTS:
        if lib == "rc_crane":  # generated here, not from KiCad's library
            fp = header_block(board, name)
        else:
            fp = pcbnew.FootprintLoad(os.path.join(FP_DIR, lib + ".pretty"), name)
            if fp is None:
                sys.exit(f"footprint not found: {lib}:{name}")
            fp.SetFPID(pcbnew.LIB_ID(lib, name))
        fp.SetReference(ref)
        fp.SetValue(value)
        fp.Value().SetVisible(False)
        fp.SetPosition(pos(x, y))
        fp.SetOrientationDegrees(rot)
        if ref in d.MODELS:
            fp.Models().clear()
            for filename, offset, rotation in d.MODELS[ref]:
                fp.Models().append(model(filename, offset, rotation))
        board.Add(fp)
        pads = list(fp.Pads())
        ref_text = fp.Reference()
        ref_text.SetTextSize(pcbnew.VECTOR2I(mm(0.8), mm(0.8)))
        ref_text.SetTextThickness(mm(0.12))
        if ref in d.HIDE_REF:
            ref_text.SetVisible(False)
        elif lib.endswith("_SMD") or lib == "Jumper":
            # small parts: reference just beside the pads
            box = pads[0].GetBoundingBox()
            for pad in pads[1:]:
                box.Merge(pad.GetBoundingBox())
            ref_text.SetTextAngleDegrees(0)
            if rot % 180 == 0:
                ref_text.SetHorizJustify(pcbnew.GR_TEXT_H_ALIGN_LEFT)
                ref_text.SetPosition(pcbnew.VECTOR2I(box.GetRight() + mm(0.6), box.GetCenter().y))
            else:
                ref_text.SetPosition(pcbnew.VECTOR2I(box.GetCenter().x, box.GetBottom() + mm(1.0)))
        elif lib == "Module":
            # driver modules have empty space between their pin rows
            ref_text.SetPosition(pcbnew.VECTOR2I(sum(p.GetPosition().x for p in pads) // len(pads),
                                                 sum(p.GetPosition().y for p in pads) // len(pads)))
            ref_text.SetTextAngleDegrees(0)
        if ref in d.REF_POS:
            ref_text.SetPosition(pos(*d.REF_POS[ref]))
        for pad in pads:
            n = pad_nets.get(pad.GetNumber())
            if n:
                pad.SetNet(net(n))
        if ref in d.BOTTOM_SIDE:
            fp.Flip(fp.GetPosition(), pcbnew.FLIP_DIRECTION_LEFT_RIGHT)

    for i, (x, y) in enumerate(d.HOLES, start=1):
        fp = pcbnew.FootprintLoad(os.path.join(FP_DIR, "MountingHole.pretty"), "MountingHole_3.2mm_M3")
        fp.SetFPID(pcbnew.LIB_ID("MountingHole", "MountingHole_3.2mm_M3"))
        fp.SetReference(f"H{i}")
        fp.Reference().SetVisible(False)
        fp.Value().SetVisible(False)
        fp.SetPosition(pos(x, y))
        board.Add(fp)

    outline = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_RECTANGLE)
    outline.SetStart(pos(0, 0))
    outline.SetEnd(pos(d.BOARD_W, d.BOARD_H))
    outline.SetLayer(pcbnew.Edge_Cuts)
    outline.SetWidth(mm(0.1))
    board.Add(outline)

    for keepout in d.KEEPOUTS:
        add_keepout(board, *keepout)
    for ref, pad_numbers in d.GROUND_STUBS:
        ground_stub(board, board.FindFootprintByReference(ref), pad_numbers)

    for text, x, y, size in d.VERTICAL_SILK:
        add_vertical_text(board, text, x, y, size)
    for text, x, *args in d.SILK:
        add_text(board, text, x, *args)

    board.Save(board_path)
    write_project_rules(board_path)
    pro_path = os.path.splitext(board_path)[0] + ".kicad_pro"
    with open(pro_path) as f:
        pro = json.load(f)
    pro["board"]["design_settings"].setdefault("rules", {})["min_track_width"] = 0.15
    with open(pro_path, "w") as f:
        json.dump(pro, f, indent=2)
    out_dir = os.path.dirname(os.path.abspath(board_path))
    write_bom(os.path.join(out_dir, "bom.csv"), d.PARTS)
    if d.JLCPCB:
        write_jlcpcb_files(board, out_dir, d.PARTS)
    if not pcbnew.ExportSpecctraDSN(board, dsn_path):
        sys.exit("DSN export failed")
    print(f"placed {len(d.PARTS)} parts, {len(nets)} nets -> {board_path}, {dsn_path}")


def remove_redundant_vias(board):
    """The autorouter leaves some vias that only connect tracks on one layer."""
    ends = {}
    for t in board.GetTracks():
        if t.Type() != pcbnew.PCB_VIA_T:
            for p in (t.GetStart(), t.GetEnd()):
                ends.setdefault((p.x, p.y, t.GetNetCode()), set()).add(t.GetLayer())
    removed = 0
    for v in [t for t in board.GetTracks() if t.Type() == pcbnew.PCB_VIA_T]:
        p, netcode = v.GetPosition(), v.GetNetCode()
        if v.GetNetname() != "GND" and len(ends.get((p.x, p.y, netcode), ())) < 2:
            board.Delete(v)
            removed += 1
    return removed


def remove_dangling_tracks(board):
    """Deletes track segments with an end that touches nothing, until there are none left."""
    pads = [pad for fp in board.GetFootprints() for pad in fp.Pads()]
    removed = 0
    while True:
        tracks = list(board.GetTracks())

        def connected(t, p):
            for o in tracks:
                if o is not t and o.GetNetCode() == t.GetNetCode():
                    if o.Type() == pcbnew.PCB_VIA_T and o.GetPosition() == p:
                        return True
                    if o.Type() != pcbnew.PCB_VIA_T and o.GetLayer() == t.GetLayer() and p in (o.GetStart(), o.GetEnd()):
                        return True
            return any(pad.GetNetCode() == t.GetNetCode() and pad.IsOnLayer(t.GetLayer()) and pad.HitTest(p)
                       for pad in pads)

        dangling = [t for t in tracks if t.Type() != pcbnew.PCB_VIA_T
                    and not (connected(t, t.GetStart()) and connected(t, t.GetEnd()))]
        if not dangling:
            return removed
        for t in dangling:
            board.Delete(t)
        removed += len(dangling)


def widen_necked_tracks(board, width=0.15):
    for t in board.GetTracks():
        if t.Type() != pcbnew.PCB_VIA_T and t.GetWidth() < mm(width):
            t.SetWidth(mm(width))


def dist_to_segment(p, a, b):
    ax, ay, bx, by, px, py = a.x, a.y, b.x, b.y, p[0], p[1]
    dx, dy = bx - ax, by - ay
    if dx == dy == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    u = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return ((px - ax - u * dx) ** 2 + (py - ay - u * dy) ** 2) ** 0.5


def stitch_ground(board, d, pitch=5.0, via=0.7, drill=0.35, clearance=0.35):
    """GND vias on a grid wherever there's room, so the top and bottom pours form one net."""
    gnd = board.FindNet("GND")
    obstacles = []  # (kind, data)
    for t in board.GetTracks():
        if t.Type() == pcbnew.PCB_VIA_T:
            obstacles.append(("circle", (t.GetPosition(), mm(0.5))))
        else:
            obstacles.append(("seg", (t.GetStart(), t.GetEnd(), t.GetWidth() / 2)))
    for fp in board.GetFootprints():
        for pad in fp.Pads():
            obstacles.append(("box", pad.GetBoundingBox()))
    keep = mm(via / 2 + clearance)
    added = 0
    y = 2.0
    while y < d.BOARD_H - 2:
        x = 2.0
        while x < d.BOARD_W - 2:
            inside_keepout = any(x0 - 1 < x < x1 + 1 and y0 - 1 < y < y1 + 1 for x0, y0, x1, y1 in d.KEEPOUTS)
            near_hole = any(abs(x - hx) < 4 and abs(y - hy) < 4 for hx, hy in d.HOLES)
            pt = (mm(x), mm(y))
            ok = not inside_keepout and not near_hole
            for kind, data in obstacles if ok else ():
                if kind == "circle":
                    dist = ((pt[0] - data[0].x) ** 2 + (pt[1] - data[0].y) ** 2) ** 0.5 - data[1]
                elif kind == "seg":
                    dist = dist_to_segment(pt, data[0], data[1]) - data[2]
                else:
                    dx = max(data.GetLeft() - pt[0], 0, pt[0] - data.GetRight())
                    dy = max(data.GetTop() - pt[1], 0, pt[1] - data.GetBottom())
                    dist = (dx * dx + dy * dy) ** 0.5
                if dist < keep:
                    ok = False
                    break
            if ok:
                v = pcbnew.PCB_VIA(board)
                v.SetPosition(pcbnew.VECTOR2I(*pt))
                v.SetWidth(mm(via))
                v.SetDrill(mm(drill))
                v.SetNet(gnd)
                board.Add(v)
                obstacles.append(("circle", (v.GetPosition(), mm(via / 2))))
                added += 1
            x += pitch
        y += pitch
    return added


def finish(d, board_path, ses_path):
    board = pcbnew.LoadBoard(board_path)
    if not pcbnew.ImportSpecctraSES(board, ses_path):
        sys.exit("SES import failed")
    removed = remove_redundant_vias(board)
    removed_tracks = remove_dangling_tracks(board)
    widen_necked_tracks(board)
    stitched = stitch_ground(board, d)
    print(f"removed {removed} redundant vias and {removed_tracks} dead-end tracks, "
          f"added {stitched} GND stitching vias")

    gnd = board.FindNet("GND")
    for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
        zone = pcbnew.ZONE(board)
        zone.SetLayer(layer)
        zone.SetNet(gnd)
        zone.SetLocalClearance(mm(0.25))
        zone.SetMinThickness(mm(0.2))
        zone.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
        zone.SetThermalReliefGap(mm(0.4))
        zone.SetThermalReliefSpokeWidth(mm(0.5))
        o = zone.Outline()
        o.NewOutline()
        for x, y in [(0.3, 0.3), (d.BOARD_W - 0.3, 0.3), (d.BOARD_W - 0.3, d.BOARD_H - 0.3), (0.3, d.BOARD_H - 0.3)]:
            o.Append(mm(x), mm(y))
        board.Add(zone)

    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    board.Save(board_path)
    print(f"routed and poured -> {board_path}")


def main(d, argv, usage):
    if argv[1:2] == ["place"] and len(argv) == 4:
        place(d, argv[2], argv[3])
    elif argv[1:2] == ["finish"] and len(argv) == 4:
        finish(d, argv[2], argv[3])
    else:
        sys.exit(usage)
