#!/usr/bin/env python3
"""Static checks on scenario event JSON: known ops, known countries, known advisors."""
import json, sys
OPS = {"add","set","mul","us","funds","war","end_war","civil_war","deploy","withdraw","regime","budget_base","sanction","rename",
       "split","bloc_all","trust","log","chance","start_op","flag","pact","betray"}
ADV = {"chief","state","defense","treasury","nsa","cia","un"}
bad = 0
for scen in ["classic_1990", "modern_2026"]:
    countries = json.load(open(f"data/scenarios/{scen}/countries.json"))
    evs = json.load(open(f"data/scenarios/{scen}/events.json")) + json.load(open("data/scenarios/common_events.json"))
    def chk(effs, eid):
        global bad
        for e in effs:
            if e[0] not in OPS: print(scen, eid, "unknown op", e); bad += 1
            if e[0] in ("add","set","mul","war","deploy","sanction","end_war","civil_war","regime","withdraw","start_op","pact","betray") and e[1] != "$C" and e[1] not in countries:
                print(scen, eid, "unknown country", e); bad += 1
            if e[0] == "war" and e[2] not in countries: print(scen, eid, "unknown country", e); bad += 1
            if e[0] == "chance": chk(e[2], eid); chk(e[3] if len(e) > 3 else [], eid)
    ids = set()
    for ev in evs:
        if ev["id"] in ids: print(scen, "duplicate id", ev["id"]); bad += 1
        ids.add(ev["id"])
        chk(ev.get("effects", []), ev["id"])
        for c in ev.get("choices", []):
            chk(c["effects"], ev["id"])
            for a in c.get("advisors", {}):
                if a not in ADV: print(scen, ev["id"], "unknown advisor", a); bad += 1
        for cnd in ev.get("when", {}).get("if", []) + ev.get("if", []):
            if cnd[0] in ("stat","active","at_war","civil_war") and cnd[1] not in countries:
                print(scen, ev["id"], "unknown country in condition", cnd); bad += 1
    print(scen, len(evs), "events")
sys.exit(1 if bad else 0)
