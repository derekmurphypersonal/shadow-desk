#!/usr/bin/env python3
"""Generate data/scenarios/*/countries.json.

Population, GDP, growth, military spending and undernourishment come from World Bank Open Data
(data/source/worldbank.json, fetched by tools/fetch_worldbank.py; CC BY 4.0). Where the World Bank
has no figure, values fall back to Natural Earth attributes scaled to the scenario year.
Indices (stability, freedom, ambition, relations...) are hand-tuned GAME values, not statistics.
For 1990, hand overrides win (exchange-rate artefacts make some 1990 dollar figures misleading);
for the modern scenario, World Bank data wins.

Usage: python3 tools/build_scenarios.py path/to/ne_110m_admin_0_countries.geojson
"""
import json, math, sys

NATO_2026 = "ALB BEL BGR CAN HRV CZE DNK EST FIN FRA DEU GRC HUN ISL ITA LVA LTU LUX MNE NLD MKD NOR POL PRT ROU SVK SVN ESP SWE TUR GBR".split()
WEST_PARTNERS_2026 = "JPN KOR AUS NZL TWN ISR UKR SAU ARE QAT KWT JOR PHL".split()
NATO_1990 = "BEL CAN DNK FRA DEU GRC ISL ITA LUX NLD NOR PRT ESP TUR GBR".split()
WEST_PARTNERS_1990 = "JPN KOR AUS NZL ISR SAU KWT PHL EGY PAK THA".split()
WARSAW_1990 = "POL HUN ROU BGR CUB VNM MNG LAO AFG AGO SYR ETH CSK".split()

# Keys: g=GDP $bn, p=population m, gr=base growth %/yr, s=stability, f=freedom, m=military,
# h=hunger, a=ambition, r=relation with US, b=bloc, n=nuclear, t=terror sponsorship, cw=civil war
MODERN = {
 "USA": dict(g=30000, p=342, s=60, f=83, m=100, b="west", n=1, r=100),
 "CHN": dict(g=19000, p=1410, gr=4.5, s=72, f=9, m=88, a=72, r=-25, b="china", n=1),
 "RUS": dict(g=2100, p=144, gr=0.8, s=55, f=12, m=82, a=85, r=-55, b="russia", n=1),
 "UKR": dict(g=190, p=37, gr=2, s=40, f=50, m=62, a=15, r=60, h=20),
 "IND": dict(g=4100, p=1450, gr=6.5, s=65, f=62, m=72, a=40, r=30, n=1),
 "PAK": dict(g=380, p=245, gr=3, s=38, f=33, m=56, a=45, r=5, n=1, t=55),
 "IRN": dict(g=400, p=91, gr=1, s=42, f=11, m=52, a=70, r=-70, b="russia", t=80),
 "PRK": dict(g=30, p=26, gr=0.5, s=62, f=1, m=50, a=82, r=-85, b="china", n=1, t=40, h=55),
 "ISR": dict(g=540, p=10, s=52, f=74, m=72, a=55, r=75, n=1),
 "SAU": dict(g=1100, p=35, s=70, f=8, m=55, a=45, r=45),
 "TWN": dict(g=800, p=23.5, gr=3, s=75, f=93, m=55, a=8, r=65),
 "JPN": dict(g=4200, p=124, gr=0.8, s=85, f=96, m=60, r=80),
 "KOR": dict(g=1900, p=51.5, gr=1.8, s=74, f=83, m=66, r=75),
 "DEU": dict(g=4700, p=84, gr=0.4, s=78, f=94, m=55, r=68),
 "GBR": dict(g=3800, p=69, gr=1.1, s=74, f=93, m=65, r=80, n=1),
 "FRA": dict(g=3200, p=68, gr=0.9, s=66, f=89, m=67, r=62, n=1),
 "ITA": dict(g=2400, p=59, s=70, f=89, m=52, r=65),
 "CAN": dict(g=2300, p=41, s=82, f=97, m=45, r=60),
 "AUS": dict(g=1800, p=27, s=82, f=95, m=50, r=80),
 "POL": dict(g=900, p=37, gr=3, s=75, f=81, m=62, a=20, r=78),
 "BRA": dict(g=2300, p=213, gr=2.2, s=58, f=72, m=45, r=25),
 "MEX": dict(g=1900, p=131, gr=1.2, s=52, f=60, m=40, r=35, t=20),
 "TUR": dict(g=1400, p=86, gr=3, s=55, f=32, m=64, a=50, r=30),
 "EGY": dict(g=390, p=112, gr=4, s=50, f=18, m=52, r=40, h=30),
 "NGA": dict(g=250, p=230, gr=3, s=38, f=43, m=35, h=42, t=45),
 "ETH": dict(g=120, p=130, gr=6, s=30, f=20, m=38, h=55, a=40, cw=1),
 "SDN": dict(g=30, p=50, gr=-5, s=8, f=5, m=30, h=82, cw=1, t=35),
 "SDS": dict(s=15, f=10, h=72, cw=1),
 "SOM": dict(g=12, p=19, s=18, f=8, h=66, t=60, cw=1),
 "YEM": dict(g=20, p=34, s=12, f=7, h=78, t=65, a=45, cw=1, r=-40),
 "SYR": dict(g=20, p=24, s=30, f=12, h=50, t=40, r=5),
 "AFG": dict(g=17, p=42, s=35, f=4, h=70, t=70, r=-50),
 "IRQ": dict(g=260, p=46, s=45, f=30, m=45, r=25, t=35),
 "VEN": dict(g=100, p=29, gr=1, s=28, f=15, m=35, h=45, r=-15),
 "CUB": dict(g=100, p=11, gr=-1, s=40, f=12, h=40, r=-50, b="russia"),
 "MMR": dict(g=65, p=55, gr=-1, s=15, f=6, h=45, cw=1, r=-30, b="china"),
 "MLI": dict(s=22, f=10, h=50, t=60, r=-20, b="russia"),
 "BFA": dict(s=20, f=10, h=50, t=60, r=-20, b="russia"),
 "NER": dict(s=24, f=12, h=55, t=55, r=-20, b="russia"),
 "LBY": dict(s=25, f=10, cw=1, t=40),
 "HTI": dict(s=8, f=20, h=62, t=30, r=30),
 "COD": dict(s=20, f=20, h=62, a=20, cw=1),
 "RWA": dict(a=55, m=35, s=60, f=20),
 "BLR": dict(s=55, f=8, r=-45, b="russia"),
 "AZE": dict(a=50, f=8),
 "SRB": dict(r=15, a=30),
 "VNM": dict(g=480, p=101, gr=6.5, f=10, r=30),
 "PHL": dict(g=470, p=115, gr=5.5, s=55, f=56, r=55),
 "IDN": dict(g=1400, p=282, gr=5, s=62, f=57, m=50, r=30),
 "ZAF": dict(g=400, p=63, gr=1, s=48, f=79, h=25, r=10),
 "ARG": dict(g=640, p=46, gr=3, s=50, f=85, r=45),
 "KAZ": dict(g=280, p=20, gr=4.5, f=22, r=15),
 "QAT": dict(f=25, r=50), "ARE": dict(f=17, r=55), "KWT": dict(f=35, r=60), "JOR": dict(f=33, r=60),
 "NIC": dict(f=10, r=-35, b="russia"), "ERI": dict(f=2, s=40, r=-30, a=40),
 "CHE": dict(f=96), "SWE": dict(f=99), "NOR": dict(f=99), "FIN": dict(f=100), "DNK": dict(f=97),
 "NLD": dict(f=97), "ESP": dict(f=90), "PRT": dict(f=96), "HUN": dict(f=65, r=40), "GEO": dict(f=55, s=45),
 "ARM": dict(f=54), "LBN": dict(s=30, f=40, t=50, h=40), "COL": dict(s=48, f=69, t=35, r=40),
 "PER": dict(s=40, f=66), "ECU": dict(s=38, f=63, t=25), "BOL": dict(s=40, f=64),
}

CLASSIC = {
 "USA": dict(g=5960, p=250, s=72, f=92, m=100, b="west", n=1, r=100),
 "SUN": dict(name="Soviet Union", g=1000, p=289, gr=-2, s=40, f=22, m=94, h=15, a=50, r=-15, b="warsaw", n=1),
 "YUG": dict(name="Yugoslavia", g=80, p=23.5, gr=-6, s=30, f=30, m=45, a=30, r=10),
 "CSK": dict(name="Czechoslovakia", g=48, p=15.6, s=58, f=70, m=40, r=35, b="warsaw"),
 "ETH": dict(g=12, p=48, gr=-2, s=15, f=5, m=50, h=75, a=35, r=-20, b="warsaw", cw=1),
 "SDN": dict(g=13, p=25, s=20, f=5, h=62, t=55, r=-30, cw=1),
 "DEU": dict(name="West Germany", g=1600, p=63, gr=4, s=82, f=95, m=60, r=75),
 "CHN": dict(g=360, p=1135, gr=5, s=55, f=8, m=72, h=30, a=35, r=-10, n=1),
 "JPN": dict(g=3130, p=123, gr=4.5, s=86, f=92, m=45, r=70),
 "GBR": dict(g=1090, p=57, gr=0.7, s=72, f=92, m=70, r=85, n=1),
 "FRA": dict(g=1270, p=58, gr=2.5, s=74, f=92, m=68, r=60, n=1),
 "ITA": dict(g=1180, p=57, s=66, f=90, m=50, r=65),
 "CAN": dict(g=600, p=27.7, s=82, f=97, m=40, r=70),
 "AUS": dict(g=320, p=17, s=82, f=95, m=40, r=75),
 "ESP": dict(g=535, p=39, s=72, f=88, m=45, r=55),
 "IND": dict(g=320, p=870, gr=5, s=50, f=55, m=60, h=55, a=35, r=20, n=1),
 "PAK": dict(g=40, p=115, s=40, f=30, m=50, a=45, r=40, h=50, t=30),
 "BRA": dict(g=460, p=150, gr=-3, s=48, f=65, m=40, h=30, r=35),
 "MEX": dict(g=260, p=84, s=58, f=45, m=30, r=45),
 "KOR": dict(g=280, p=43, gr=8, s=60, f=65, m=60, r=75),
 "TWN": dict(g=165, p=20, gr=6, s=65, f=50, m=55, a=10, r=60),
 "SAU": dict(g=117, p=16, s=72, f=5, m=45, a=30, r=50),
 "IRQ": dict(g=50, p=18, gr=-1, s=62, f=3, m=72, a=92, r=-20, t=50),
 "KWT": dict(g=18, p=2.1, gr=2, s=72, f=25, m=10, a=5, r=40),
 "IRN": dict(g=120, p=56, s=50, f=10, m=55, a=55, r=-60, t=75),
 "ISR": dict(g=60, p=4.7, s=55, f=78, m=68, a=45, r=75, n=1),
 "EGY": dict(g=43, p=57, s=55, f=20, m=52, h=30, r=55),
 "SYR": dict(g=12, p=12, s=55, f=3, m=55, a=50, r=-40, t=70),
 "LBY": dict(g=30, p=4.4, s=60, f=2, m=40, a=55, r=-80, t=88),
 "CUB": dict(g=28, p=10.6, s=55, f=5, m=40, a=30, r=-70),
 "PRK": dict(g=15, p=20, s=65, f=1, m=55, a=70, r=-85, h=45, t=45),
 "AFG": dict(g=4, p=12, s=15, f=5, m=30, h=60, r=-40, cw=1),
 "NIC": dict(g=1, p=4, s=40, f=50, r=20), "SLV": dict(s=25, f=40, r=50, cw=1),
 "PAN": dict(s=45, f=55, r=40),
 "ZAF": dict(g=112, p=37, s=40, f=20, m=50, h=30, r=10, n=1),
 "AGO": dict(g=11, p=12, s=20, f=8, h=55, r=-40, cw=1),
 "MOZ": dict(g=2.5, p=13, s=20, f=10, h=65, cw=1),
 "SOM": dict(g=1, p=7, s=15, f=5, h=62, r=10, cw=1, a=30),
 "LBR": dict(g=0.4, p=2.1, s=10, f=10, h=50, r=30, cw=1),
 "RWA": dict(s=40, f=10, h=40),
 "KHM": dict(g=1, p=9, s=20, f=5, h=50, r=-30, cw=1),
 "VNM": dict(g=6.5, p=67, gr=5, s=55, f=3, m=55, h=45, r=-50),
 "POL": dict(g=60, p=38, gr=-8, s=55, f=70, m=45, r=50),
 "HUN": dict(g=33, p=10.4, s=60, f=75, r=50),
 "ROU": dict(g=38, p=23, gr=-5, s=40, f=30, r=10),
 "BGR": dict(g=20, p=8.8, s=50, f=40),
 "ALB": dict(g=2, p=3.3, s=45, f=3, r=-20),
 "PER": dict(g=26, p=22, s=25, f=50, h=40, t=60),
 "COL": dict(g=47, p=33, s=35, f=55, t=55, r=50),
 "IDN": dict(g=106, p=181, gr=7, s=60, f=20, m=45, r=40),
 "PHL": dict(g=44, p=61, s=40, f=60, r=60),
 "TUR": dict(g=200, p=55, s=60, f=55, m=55, r=60),
 "GRC": dict(g=95, p=10.2, f=85, r=60),
 "MMR": dict(g=6, p=41, s=30, f=3, h=45, r=-30),
 "VEN": dict(g=48, p=19.7, s=50, f=70, r=45),
 "ARG": dict(g=140, p=32.6, gr=-2, s=45, f=75, r=40),
 "NGA": dict(g=31, p=95, s=40, f=25, h=40),
 "YEM": dict(g=6, p=12, s=40, f=15, h=50, r=0),
 "MNG": dict(g=2.5, p=2.2, f=30, r=-10), "LAO": dict(g=1, p=4.2, f=3, r=-30),
 # Dormant successor states, activated by dissolution events.
 "RUS": dict(g=500, p=148, gr=-8, s=35, f=45, m=82, a=30, r=35, n=1),
 "UKR": dict(g=80, p=52, gr=-8, s=45, f=55, m=55, r=30),
 "BLR": dict(g=17, p=10.2, s=50, f=30, r=0), "KAZ": dict(g=25, p=16.4, s=50, f=20, r=10),
 "LTU": dict(f=80, r=60), "LVA": dict(f=80, r=60), "EST": dict(f=85, r=60),
 "GEO": dict(s=20, f=40, cw=1), "ARM": dict(s=30, f=50, a=45), "AZE": dict(s=30, f=20, a=45),
 "SRB": dict(name="Serbia-Montenegro", g=18, p=10.5, s=35, f=20, m=45, a=75, r=-20),
 "HRV": dict(g=12, p=4.7, s=30, f=50, m=25, r=30), "BIH": dict(g=6, p=4.4, s=10, f=40, cw=1, h=45),
 "SVN": dict(g=12, p=2, s=70, f=85, r=50),
 "CZE": dict(g=34, p=10.3, s=70, f=88, r=55), "SVK": dict(g=14, p=5.3, s=65, f=70, r=45),
}

GROUPS_1990 = {
 "SUN": "RUS UKR BLR KAZ UZB TKM KGZ TJK GEO ARM AZE MDA LTU LVA EST".split(),
 "YUG": "SRB HRV BIH SVN MKD MNE KOS".split(),
 "CSK": ["CZE", "SVK"], "ETH": ["ETH", "ERI"], "SDN": ["SDN", "SDS"], "IDN": ["IDN", "TLS"],
}
# Map polygons that stay folded into a successor after a split.
SPLIT_FOLD_1990 = {"MNE": "SRB", "KOS": "SRB"}

INCOME_MOD = {"1": "high", "2": "high", "3": "umid", "4": "lmid", "5": "low"}
DEF = {
 "high": dict(gr=1.8, s=78, f=82), "umid": dict(gr=3.0, s=58, f=50),
 "lmid": dict(gr=4.0, s=50, f=45), "low": dict(gr=4.0, s=40, f=35),
}
POP90 = {"Africa": 0.5, "Asia": 0.72, "South America": 0.73, "Europe": 0.97, "North America": 0.8, "Oceania": 0.75}
GDP90 = {"high": 0.35, "umid": 0.17, "lmid": 0.15, "low": 0.25}

def hunger_target(gdp, pop):
    pc = max(gdp * 1000.0 / max(pop, 0.01), 50)
    return max(0.0, min(95.0, 130 - 30 * math.log10(pc)))

def military_from_gdp(gdp):
    return max(5, min(70, 12 * math.log10(max(gdp, 1)) + 2))

WB = json.load(open("data/source/worldbank.json"))

def wb(year, key, iso):
    row = WB["1990" if year == 1990 else "latest"].get(key, {}).get(iso)
    return None if row is None else row["value"]

def mil_index(usd):
    bn = max(usd / 1e9, 0.01)
    return max(5, min(100, round(18 * math.log10(bn) + 47)))

def make(base, ov, year, bloc_of):
    inc = base["inc"]
    d = DEF[inc]
    iso = base["iso"]
    if year == 1990:
        pop = base["pop"] * POP90.get(base["continent"], 0.8)
        gdp = base["gdp"] * GDP90[inc]
    else:
        pop = base["pop"] * 1.05
        gdp = base["gdp"] * 1.25
    w_pop, w_gdp, w_gr, w_mil = wb(year, "pop", iso), wb(year, "gdp", iso), wb(year, "growth", iso), wb(year, "mil", iso)
    if year == 1990:
        pop = ov.get("p", w_pop / 1e6 if w_pop else pop)
        gdp = ov.get("g", w_gdp / 1e9 if w_gdp else gdp)
        growth = ov.get("gr", round(max(-4, min(7, w_gr)), 1) if w_gr is not None else d["gr"])
    else:
        pop = w_pop / 1e6 if w_pop else ov.get("p", pop)
        gdp = w_gdp / 1e9 if w_gdp else ov.get("g", gdp)
        growth = ov.get("gr", round(max(-8, min(9, w_gr)), 1) if w_gr is not None else d["gr"])
    c = {
        "name": ov.get("name", base["name"]), "region": base["region"],
        "pop": round(pop, 2), "gdp": round(gdp, 2),
        "growth": growth, "stability": ov.get("s", d["s"]), "freedom": ov.get("f", d["f"]),
        "military": 0, "hunger": 0, "ambition": ov.get("a", 25), "relation": 0,
        "bloc": ov.get("b", bloc_of(base["iso"])), "nuclear": bool(ov.get("n", 0)),
        "terror": ov.get("t", 5), "civil_war": bool(ov.get("cw", 0)),
    }
    c["military"] = ov.get("m", mil_index(w_mil) if w_mil else round(military_from_gdp(c["gdp"])))
    under = wb(year, "undernourished", iso)
    c["hunger"] = ov.get("h", round(min(95, under * 1.4)) if under is not None else round(hunger_target(c["gdp"], c["pop"])))
    return c

def main(src):
    feats = json.load(open(src))["features"]
    base = {}
    for f in feats:
        p = f["properties"]
        iso = p["ADM0_A3"]
        if iso in ("ATA", "GRL", "FLK", "ATF", "NCL", "PRI", "SOL", "CYN", "SAH"):
            continue
        base[iso] = dict(iso=iso, name=p["NAME"], pop=p["POP_EST"] / 1e6, gdp=p["GDP_MD"] / 1000.0,
                         inc=INCOME_MOD[p["INCOME_GRP"][0]], continent=p["CONTINENT"], region=p["SUBREGION"])
    # ---- Modern 2026
    west26 = set(NATO_2026 + WEST_PARTNERS_2026 + ["USA"])
    rel26 = {"west": 55, "china": -20, "russia": -35, "nonaligned": 10}
    out = {}
    for iso, b in base.items():
        ov = MODERN.get(iso, {})
        c = make(b, ov, 2026, lambda i: "west" if i in west26 else "nonaligned")
        c["relation"] = ov.get("r", rel26[c["bloc"]])
        out[iso] = c
    out["USA"]["player"] = True
    json.dump(out, open("data/scenarios/modern_2026/countries.json", "w"), indent=1, sort_keys=True)
    # ---- Classic 1990
    west90 = set(NATO_1990 + WEST_PARTNERS_1990 + ["USA"])
    warsaw90 = set(WARSAW_1990)
    rel90 = {"west": 55, "warsaw": -30, "nonaligned": 5}
    bloc90 = lambda i: "west" if i in west90 else ("warsaw" if i in warsaw90 else "nonaligned")
    out = {}
    grouped = {m: g for g, ms in GROUPS_1990.items() for m in ms}
    for gname, members in GROUPS_1990.items():
        if gname in base:
            continue
        ov = CLASSIC[gname]
        fake = dict(iso=gname, name=ov["name"], pop=0, gdp=0, inc="umid",
                    continent=base[members[0]]["continent"], region=base[members[0]]["region"])
        c = make(fake, ov, 1990, bloc90)
        c["relation"] = ov.get("r", rel90[c["bloc"]])
        out[gname] = c
    for iso, b in base.items():
        ov = CLASSIC.get(iso, {})
        c = make(b, ov, 1990, bloc90)
        if iso in grouped and grouped[iso] != iso:
            c["dormant"] = True
            if grouped[iso] == "SUN":
                c["bloc"] = ov.get("b", "nonaligned")
        if iso in SPLIT_FOLD_1990:
            c["dormant"] = True
            c["fold_into"] = SPLIT_FOLD_1990[iso]
        c["relation"] = ov.get("r", rel90.get(c["bloc"], 5))
        out[iso] = c
    out["USA"]["player"] = True
    json.dump(out, open("data/scenarios/classic_1990/countries.json", "w"), indent=1, sort_keys=True)
    json.dump(GROUPS_1990, open("data/scenarios/classic_1990/map_groups.json", "w"), indent=1)
    print("ok")

if __name__ == "__main__":
    main(sys.argv[1])
