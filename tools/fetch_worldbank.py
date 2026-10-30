#!/usr/bin/env python3
"""Fetch World Bank indicators into data/source/worldbank.json (cached, committed).

World Bank Open Data, CC BY 4.0. Military expenditure series originate with SIPRI.
Usage: python3 tools/fetch_worldbank.py
"""
import json, urllib.request

INDICATORS = {
    "pop": "SP.POP.TOTL",
    "gdp": "NY.GDP.MKTP.CD",
    "growth": "NY.GDP.MKTP.KD.ZG",
    "mil": "MS.MIL.XPND.CD",
    "undernourished": "SN.ITK.DEFC.ZS",
    "life": "SP.DYN.LE00.IN",
}
BASE = "https://api.worldbank.org/v2/country/all/indicator/{ind}?format=json&per_page=20000&{q}"

def fetch(ind, q):
    url = BASE.format(ind=ind, q=q)
    with urllib.request.urlopen(url, timeout=60) as r:
        data = json.load(r)
    out = {}
    for row in data[1] or []:
        iso = row.get("countryiso3code")
        if iso and row.get("value") is not None:
            out[iso] = {"value": row["value"], "year": int(row["date"])}
    return out

def main():
    result = {"source": "World Bank Open Data (CC BY 4.0), data.worldbank.org. Military expenditure: SIPRI via World Bank.",
              "1990": {}, "latest": {}}
    for key, ind in INDICATORS.items():
        result["1990"][key] = fetch(ind, "date=1990")
        result["latest"][key] = fetch(ind, "mrnev=1")
        print(key, len(result["1990"][key]), len(result["latest"][key]))
    json.dump(result, open("data/source/worldbank.json", "w"), separators=(",", ":"), sort_keys=True)

if __name__ == "__main__":
    main()
