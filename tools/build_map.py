#!/usr/bin/env python3
"""Build data/map/world.json from Natural Earth 1:110m admin-0 countries (public domain).

Usage: python3 tools/build_map.py path/to/ne_110m_admin_0_countries.geojson
Requires: shapely
"""
import json, sys, math
from shapely.geometry import shape, Polygon, MultiPolygon
from shapely.ops import unary_union
from shapely.validation import make_valid

W = 2048
LAT_TOP, LAT_BOT = 84.0, -58.0
H = round(W * (LAT_TOP - LAT_BOT) / 360.0)

# Territories drawn on the map but controlled by another country.
OWNER = {"GRL": "DNK", "FLK": "GBR", "ATF": "FRA", "NCL": "FRA", "PRI": "USA",
         "SOL": "SOM", "CYN": "CYP", "SAH": "MAR"}
DROP = {"ATA"}
# Sea or short-strait neighbours that a land-touch test misses.
EXTRA_NEIGHBORS = [("CHN", "TWN"), ("GBR", "FRA"), ("JPN", "KOR"), ("JPN", "RUS"), ("CUB", "USA"),
                   ("YEM", "DJI"), ("YEM", "ERI"), ("SAU", "EGY"), ("ITA", "TUN"), ("ESP", "MAR"),
                   ("IRN", "ARE"), ("IRN", "OMN"), ("QAT", "BHR"), ("PHL", "MYS"), ("IDN", "AUS"),
                   ("LKA", "IND"), ("HTI", "CUB"), ("JAM", "CUB"), ("DNK", "SWE"), ("FIN", "EST"),
                   ("TUR", "CYP"), ("GRC", "TUR"), ("KOR", "PRK")]

def proj(lon, lat):
    lat = max(min(lat, LAT_TOP), LAT_BOT)
    return ((lon + 180.0) / 360.0 * W, (LAT_TOP - lat) / (LAT_TOP - LAT_BOT) * H)

def polys(g):
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, MultiPolygon):
        return list(g.geoms)
    if hasattr(g, "geoms"):
        out = []
        for x in g.geoms:
            out += polys(x)
        return out
    return []

def main(src):
    d = json.load(open(src))
    geoms, names = {}, {}
    for f in d["features"]:
        p = f["properties"]
        iso = p["ADM0_A3"]
        if iso in DROP:
            continue
        g = make_valid(shape(f["geometry"]))
        geoms[iso] = g
        names[iso] = p["NAME"]
    countries = {}
    for iso, g in geoms.items():
        rings = []
        simp = g.simplify(0.12, preserve_topology=True)
        for poly in sorted(polys(simp), key=lambda q: -q.area):
            if poly.area < 0.05 and rings:
                continue
            coords = list(poly.exterior.coords)[:-1]
            pts = []
            for lon, lat in coords:
                x, y = proj(lon, lat)
                pts += [round(x, 1), round(y, 1)]
            if len(pts) >= 6:
                rings.append(pts)
        rp = g.representative_point()
        biggest = max(polys(g), key=lambda q: q.area)
        lp = biggest.representative_point()
        cx, cy = proj(lp.x, lp.y)
        countries[iso] = {"name": names[iso], "owner": OWNER.get(iso, iso), "rings": rings,
                          "centroid": [round(cx, 1), round(cy, 1)], "area": round(g.area, 2),
                          "neighbors": []}
    isos = list(geoms)
    nb = {i: set() for i in isos}
    buf = {i: geoms[i].buffer(0.4) for i in isos}
    for a_i, a in enumerate(isos):
        for b in isos[a_i + 1:]:
            if buf[a].intersects(geoms[b]):
                nb[a].add(b); nb[b].add(a)
    for a, b in EXTRA_NEIGHBORS:
        if a in nb and b in nb:
            nb[a].add(b); nb[b].add(a)
    for i in isos:
        countries[i]["neighbors"] = sorted(nb[i])
    out = {"source": "Natural Earth 1:110m Admin 0 Countries (public domain), naturalearthdata.com",
           "width": W, "height": H, "lat_top": LAT_TOP, "lat_bottom": LAT_BOT, "countries": countries}
    json.dump(out, open("data/map/world.json", "w"), separators=(",", ":"))
    print(f"{len(countries)} countries, {sum(len(c['rings']) for c in countries.values())} rings, {W}x{H}")

if __name__ == "__main__":
    main(sys.argv[1])
