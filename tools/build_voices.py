"""Pre-record every briefing line with Kokoro neural voices (Apache 2.0).

Each cabinet seat has its own voice. Event and system-card templates are split at $TOKENS
(country names), and every country name is recorded once per seat, so the game can stitch
lines like "Famine warning: $NAME" around any country. Output:

    assets/voice/<seat>/<md5(text)[:16]>.voice   (mono Ogg Vorbis, 24 kHz; custom extension so Godot packs it raw)
    assets/voice/index.json

    pip install kokoro-onnx soundfile numpy
    python3 tools/build_voices.py --models /opt/models/kokoro
"""
import argparse
import glob
import hashlib
import json
import os
import re
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")
SEATS = ["chief", "state", "defense", "treasury", "nsa", "cia", "un"]
# seat: (voice mix, speed)
VOICES = {
    "chief": ({"af_heart": 1.0}, 1.0),
    "state": ({"am_michael": 1.0}, 0.98),
    "defense": ({"am_fenrir": 0.8, "am_onyx": 0.2}, 0.95),
    "treasury": ({"af_bella": 0.85, "af_sarah": 0.15}, 1.02),
    "nsa": ({"am_puck": 0.85, "am_michael": 0.15}, 1.0),
    "cia": ({"af_nicole": 0.7, "af_kore": 0.3}, 0.97),
    "un": ({"am_michael": 0.5, "bm_george": 0.5}, 0.98),
}
TOKEN = re.compile(r"\$[A-Z]+")


def normalize(text: str) -> str:
    """Must match Audio.normalize() in scripts/autoload/audio.gd."""
    t = text.strip()
    while t and t[0] in ",;:":
        t = t[1:].strip()
    return t if any(c.isalpha() for c in t) else ""


def key(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:16]


SAY = [
    (re.compile(r"\$(\d+(?:\.\d+)?)\s?bn\b"), r"\1 billion dollars"),
    (re.compile(r"\$(\d+(?:\.\d+)?)\s?m\b"), r"\1 million dollars"),
    (re.compile(r"(\d+(?:\.\d+)?)%"), r"\1 percent"),
    (re.compile(r"\bUS\b"), "U.S."),
    (re.compile(r"\bUN\b"), "U.N."),
    (re.compile(r"\bUSSR\b"), "U.S.S.R."),
    (re.compile(r"\bAI\b"), "A.I."),
    (re.compile(r"\bEU\b"), "E.U."),
    (re.compile(r"\bCIA\b"), "C.I.A."),
    (re.compile(r"\bIMF\b"), "I.M.F."),
    (re.compile(r"\bDRC\b"), "D.R.C."),
    (re.compile(r"\bMr\."), "Mister"),
    (re.compile(r"\s*·\s*"), ", "),
    (re.compile(r"—|–"), ", "),
]


def spoken(text: str) -> str:
    for rx, rep in SAY:
        text = rx.sub(rep, text)
    if text and text[-1].isalnum():
        text += "."
    return text


def pieces(tpl: str):
    pos = 0
    for m in TOKEN.finditer(tpl):
        yield tpl[pos:m.start()]
        pos = m.end()
    yield tpl[pos:]


def collect():
    lines = {s: set() for s in SEATS}
    cards = []
    for f in glob.glob(os.path.join(ROOT, "data", "scenarios", "**", "*events*.json"), recursive=True):
        data = json.load(open(f))
        data = data.get("events", data) if isinstance(data, dict) else data
        for ev in data:
            if not ev.get("choices"):
                continue
            cards.append((ev.get("speaker", "nsa"), ev.get("title", ""), ev.get("text", "")))
    for c in json.load(open(os.path.join(ROOT, "data", "scenarios", "system_cards.json"))).values():
        cards.append((c.get("speaker", "nsa"), c["title"], c["text"]))
    for speaker, title, text in cards:
        for seat in {speaker, "chief"}:
            for tpl in (title, text):
                for p in pieces(tpl):
                    t = normalize(p)
                    if t:
                        lines[seat].add(t)
    # Advisors arguing their case on a briefing: short lines, each in its own seat's voice.
    debate = json.load(open(os.path.join(ROOT, "data", "scenarios", "debate_lines.json")))
    for seat, sides in debate.items():
        for side in sides.values():
            for line in side:
                t = normalize(line)
                if t and seat in lines:
                    lines[seat].add(t)
    names = set()

    def walk(x):
        if isinstance(x, dict):
            for k, v in x.items():
                if k == "name" and isinstance(v, str):
                    names.add(v)
                else:
                    walk(v)
        elif isinstance(x, list):
            if len(x) == 3 and x[0] == "rename":
                names.add(x[2])
            for y in x:
                walk(y)

    for f in glob.glob(os.path.join(ROOT, "data", "scenarios", "**", "*.json"), recursive=True):
        walk(json.load(open(f)))
    for n in names:
        t = normalize(n)
        if t:
            for seat in SEATS:
                lines[seat].add(t)
    return lines


def trim(a: np.ndarray, sr: int) -> np.ndarray:
    thr = 10 ** (-42 / 20)
    idx = np.where(np.abs(a) > thr)[0]
    if idx.size == 0:
        return a
    pad = int(0.03 * sr)
    return a[max(0, idx[0] - pad): min(len(a), idx[-1] + pad)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default="/opt/models/kokoro")
    ap.add_argument("--seats", default=",".join(SEATS))
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(a.models, "kokoro-v1.0.onnx"), os.path.join(a.models, "voices-v1.0.bin"))
    lines = collect()
    total = sum(len(v) for v in lines.values())
    print("lines:", {s: len(v) for s, v in lines.items()}, "total", total, flush=True)
    done = 0
    for seat in a.seats.split(","):
        mix, speed = VOICES[seat]
        style = sum(k.get_voice_style(v) * w for v, w in mix.items())
        d = os.path.join(OUT, seat)
        os.makedirs(d, exist_ok=True)
        wanted = {key(t) + ".voice" for t in lines[seat]}
        for old in os.listdir(d):
            if old not in wanted:
                os.remove(os.path.join(d, old))
        for i, t in enumerate(sorted(lines[seat])):
            if a.limit and i >= a.limit:
                break
            path = os.path.join(d, key(t) + ".voice")
            done += 1
            if os.path.exists(path):
                continue
            audio, sr = k.create(spoken(t), voice=style, speed=speed, lang="en-us")
            audio = trim(np.asarray(audio, dtype=np.float32), sr)
            peak = float(np.max(np.abs(audio))) or 1.0
            audio = audio * (0.89 / peak)
            sf.write(path, audio, sr, format="OGG", subtype="VORBIS")
            if done % 100 == 0:
                print(f"{done}/{total} {seat}", flush=True)
    json.dump({"engine": "Kokoro-82M v1.0 (Apache 2.0)", "seats": {s: VOICES[s][0] for s in SEATS},
               "lines": {s: len(lines[s]) for s in SEATS}},
              open(os.path.join(OUT, "index.json"), "w"), indent=1)
    print("done", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
