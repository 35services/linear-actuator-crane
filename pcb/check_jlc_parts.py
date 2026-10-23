"""Lists every LCSC part in the JLCPCB BOMs with its library type (basic / extended) and stock.

Extended parts cost a one-time setup fee per part type and order (about $3), so this is
the list to look at when the assembly gets expensive. Uses JLCPCB's public parts search.

    python3 pcb/check_jlc_parts.py              # all pcb/**/jlcpcb_bom.csv
    python3 pcb/check_jlc_parts.py C2678753     # single parts
"""

import csv
import glob
import json
import os
import sys
import urllib.request

API = "https://jlcpcb.com/api/overseas-pcb-order/v1/shoppingCart/smtGood/selectSmtComponentList"


def lookup(lcsc):
    req = urllib.request.Request(
        API,
        data=json.dumps({"keyword": lcsc, "currentPage": 1, "pageSize": 5}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.load(r).get("data") or {}
    for c in (data.get("componentPageInfo") or {}).get("list") or []:
        if c.get("componentCode") == lcsc:
            kind = {"base": "basic", "expand": "extended"}.get(c.get("componentLibraryType"), c.get("componentLibraryType"))
            return kind, c.get("stockCount"), c.get("componentModelEn")
    return "not found", None, ""


def bom_parts():
    """{lcsc: [(bom file, designators)]} from every jlcpcb_bom.csv below pcb/."""
    root = os.path.dirname(os.path.abspath(__file__))
    parts = {}
    for path in sorted(glob.glob(os.path.join(root, "**", "jlcpcb_bom.csv"), recursive=True)):
        with open(path, newline="") as f:
            for row in csv.DictReader(f):
                parts.setdefault(row["LCSC Part #"], []).append((os.path.relpath(path, root), row["Designator"]))
    return parts


def main():
    parts = {c: [] for c in sys.argv[1:]} or bom_parts()
    extended = 0
    print(f"{'LCSC':<10} {'type':<9} {'stock':>9}  {'part':<22} used in")
    for lcsc, uses in sorted(parts.items()):
        kind, stock, model = lookup(lcsc)
        extended += kind == "extended"
        where = "; ".join(f"{b}: {d}" for b, d in uses)
        print(f"{lcsc:<10} {kind:<9} {stock if stock is not None else '-':>9}  {model:<22} {where}")
    print(f"\n{extended} extended part type(s)")


if __name__ == "__main__":
    main()
