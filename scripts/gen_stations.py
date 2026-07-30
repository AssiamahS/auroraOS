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
    with open(OUT, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print(f"wrote {OUT}: {len(rows)} stations, {len(out)} routes")


if __name__ == "__main__":
    main()
