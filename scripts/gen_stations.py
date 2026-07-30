#!/usr/bin/env python3
"""Regenerate Aurora/Resources/Stations.json from the official MTA dataset.

Source: data.ny.gov "MTA Subway Stations" (39hk-dx4f). NYC GTFS stop IDs are
sequential along each line, so sorting by (prefix, number) yields track order.
"""
import csv
import json
import re
import sys
import urllib.request
from collections import defaultdict

URL = "https://data.ny.gov/api/views/39hk-dx4f/rows.csv?accessType=DOWNLOAD"
OUT = "Aurora/Resources/Stations.json"
CSV_CACHE = "data/mta_stations.csv"


def main():
    raw = urllib.request.urlopen(URL, timeout=60).read().decode()
    with open(CSV_CACHE, "w") as f:
        f.write(raw)

    rows = list(csv.DictReader(raw.splitlines()))
    if len(rows) < 400:
        sys.exit(f"suspiciously few stations ({len(rows)}) — refusing to overwrite")

    routes = defaultdict(list)
    for r in rows:
        for rt in r["Daytime Routes"].split():
            routes[rt].append({
                "id": r["GTFS Stop ID"],
                "name": r["Stop Name"],
                "line": r["Line"],
                "borough": r["Borough"],
                "lat": float(r["GTFS Latitude"]),
                "lon": float(r["GTFS Longitude"]),
                "north": r["North Direction Label"],
                "south": r["South Direction Label"],
            })

    def key(s):
        m = re.match(r"([A-Z]*)(\d+)", s["id"])
        return (m.group(1), int(m.group(2)))

    out = {rt: sorted(stops, key=key) for rt, stops in routes.items()}
    out.update(path_routes())
    with open(OUT, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print(f"wrote {OUT}: {len(rows)} stations, {len(out)} routes")


def path_routes():
    """PATH (Port Authority Trans-Hudson). Station ids are RidePATH codes so
    the app can hit the official live feed (panynj.gov ridepath.json).
    Order is NJ end -> NY end, matching the north->south convention."""
    S = {
        "NWK": ("Newark Penn Station", 40.73454, -74.16375),
        "HAR": ("Harrison", 40.73925, -74.15555),
        "JSQ": ("Journal Square", 40.73301, -74.06289),
        "GRV": ("Grove Street", 40.71966, -74.04245),
        "EXP": ("Exchange Place", 40.71634, -74.03297),
        "WTC": ("World Trade Center", 40.71271, -74.01193),
        "HOB": ("Hoboken", 40.73586, -74.02922),
        "NEW": ("Newport", 40.72699, -74.03383),
        "CHR": ("Christopher Street", 40.73295, -74.00707),
        "09S": ("9th Street", 40.73424, -73.99910),
        "14S": ("14th Street", 40.73735, -73.99684),
        "23S": ("23rd Street", 40.74277, -73.99284),
        "33S": ("33rd Street", 40.74912, -73.98827),
    }
    LINES = {
        "P1": ["NWK", "HAR", "JSQ", "GRV", "EXP", "WTC"],          # Newark - WTC (red)
        "P2": ["HOB", "NEW", "EXP", "WTC"],                        # Hoboken - WTC (green)
        "P3": ["JSQ", "GRV", "NEW", "CHR", "09S", "14S", "23S", "33S"],  # JSQ - 33 St (yellow)
        "P4": ["HOB", "CHR", "09S", "14S", "23S", "33S"],          # Hoboken - 33 St (blue)
    }
    return {
        line: [{
            "id": code,
            "name": S[code][0],
            "line": "PATH",
            "borough": "NJ" if code in ("NWK", "HAR", "JSQ", "GRV", "EXP", "HOB", "NEW") else "M",
            "lat": S[code][1],
            "lon": S[code][2],
            "north": "To New Jersey",
            "south": "To New York",
        } for code in codes]
        for line, codes in LINES.items()
    }


if __name__ == "__main__":
    main()
