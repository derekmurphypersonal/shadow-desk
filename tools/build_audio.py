#!/usr/bin/env python3
"""Synthesise Shadow Desk's original music and sound effects (numpy/scipy -> Ogg Vorbis via ffmpeg).

Everything here is generated from code: no samples, no third-party recordings.
Usage: python3 tools/build_audio.py
"""
import os, subprocess, tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
OUT = "assets/audio"
rng = np.random.default_rng(1993)

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

def n(name):
    """'D4' -> midi number."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE[pitch]

def t(dur):
    return np.arange(int(dur * SR)) / SR

def env(length, a=0.01, r=0.1, shape=1.0):
    e = np.ones(length)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    na = min(na, length)
    e[:na] = np.linspace(0, 1, na) ** shape
    nr = min(nr, length)
    e[-nr:] *= np.linspace(1, 0, nr) ** shape
    return e

def lowpass(x, cutoff, order=2):
    sos = butter(order, min(cutoff, SR / 2 - 100), btype="low", fs=SR, output="sos")
    return sosfilt(sos, x)

def highpass(x, cutoff, order=2):
    sos = butter(order, cutoff, btype="high", fs=SR, output="sos")
    return sosfilt(sos, x)

def saw(freq, dur, harmonics=None):
    tt = t(dur)
    out = np.zeros_like(tt)
    k = 1
    while freq * k < 6000 and k < 40:
        out += np.sin(2 * np.pi * freq * k * tt) / k
        k += 1
    return out

def pad(freqs, dur, cutoff=1400, detune=0.004, a=1.5, r=1.5):
    out = np.zeros(int(dur * SR))
    for f in freqs:
        for d in (-detune, 0, detune):
            out += saw(f * (1 + d), dur) * 0.33
    out = lowpass(out, cutoff)
    return out * env(len(out), a, r, 1.5) / max(1, len(freqs))

def brass(freq, dur, a=0.06, r=0.25, bright=1.0):
    tt = t(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt) * np.clip(tt / 0.4, 0, 1)
    out = np.zeros_like(tt)
    for k in range(1, 12):
        out += np.sin(2 * np.pi * freq * k * np.cumsum(vib) / SR) / (k ** (1.6 - 0.4 * bright))
    out = lowpass(out, 2600 * bright + 600)
    return out * env(len(out), a, r, 1.2)

def pluck(freq, dur=2.5, decay=1.6):
    tt = t(dur)
    out = np.zeros_like(tt)
    for k, amp in ((1, 1.0), (2, 0.45), (3, 0.22), (4, 0.12), (6, 0.05)):
        f = freq * k * (1 + 0.0004 * k * k)
        out += amp * np.sin(2 * np.pi * f * tt) * np.exp(-tt * decay * (1 + 0.35 * k))
    return out * env(len(out), 0.004, 0.2)

def timpani(freq=73.4, dur=2.2):
    tt = t(dur)
    f = freq * (1 + 0.15 * np.exp(-tt * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 2.4)
    hit = lowpass(rng.standard_normal(len(tt)), 900) * np.exp(-tt * 30) * 0.5
    return (body + hit) * env(len(tt), 0.002, 0.3)

def noise_burst(dur, lo, hi, decay):
    x = rng.standard_normal(int(dur * SR))
    x = highpass(lowpass(x, hi), lo)
    return x * np.exp(-t(dur) * decay)

def reverb(x, seconds=2.6, mix=0.3, seed=0):
    r = np.random.default_rng(seed)
    length = int(seconds * SR)
    tt = np.arange(length) / SR
    out = []
    for ch in range(2):
        ir = r.standard_normal(length) * np.exp(-tt * 6.0 / seconds)
        ir = lowpass(ir, 5000)
        ir /= np.sqrt(np.sum(ir ** 2))
        dry = np.concatenate([x, np.zeros(length)])
        wet = np.zeros(len(dry))
        conv = fftconvolve(x, ir)[: len(dry)]
        wet[: len(conv)] = conv
        out.append(dry * (1 - mix) + wet * mix)
    return np.stack(out, axis=1)

def place(buf, sig, start, gain=1.0):
    i = int(start * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i] * gain

def loopify(stereo, length_s):
    """Wrap the reverb tail past the loop point back onto the start for a seamless loop."""
    n_ = int(length_s * SR)
    body = stereo[:n_].copy()
    tail = stereo[n_:]
    body[: len(tail)] += tail[: n_]
    return body

def normalise(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x

def write(name, stereo, quality=5):
    if stereo.ndim == 1:
        stereo = np.stack([stereo, stereo], axis=1)
    data = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wavfile.write(f.name, SR, data)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, "-c:a", "libvorbis", "-q:a", str(quality),
                        f"{OUT}/{name}.ogg"], check=True)
        os.unlink(f.name)

# ---------------------------------------------------------------- music

def chord(root, kind):
    iv = {"m": [0, 3, 7], "M": [0, 4, 7], "m9": [0, 3, 7, 10, 14], "M7": [0, 4, 7, 11], "sus": [0, 5, 7, 10], "m7": [0, 3, 7, 10]}[kind]
    return [midi(root + i) for i in iv]

def theme():
    """Main menu: stately D minor, brass motif over strings and timpani. 64 s loop."""
    L = 64.0
    buf = np.zeros(int((L + 4) * SR))
    prog = [("D3", "m"), ("Bb2", "M"), ("F3", "M"), ("C3", "M")] * 4
    for i, (root, kind) in enumerate(prog):
        st = i * 4.0
        place(buf, pad(chord(n(root), kind), 4.6, cutoff=1100 + 300 * (i // 4), a=0.9, r=1.2), st, 0.5)
        place(buf, pad([midi(n(root) - 12)], 4.4, cutoff=300, a=0.3, r=1.0), st, 0.6)
        if i % 2 == 0:
            place(buf, timpani(midi(n(root) - 12) * 2 if n(root) < 48 else midi(n(root) - 12)), st, 0.35)
    motif = [("D4", 1.5), ("A4", 0.5), ("A4", 1.0), ("G4", 1.0), ("F4", 2.0), ("E4", 1.0), ("F4", 1.0), ("C5", 3.0), ("A4", 1.0),
             ("Bb4", 1.5), ("A4", 0.5), ("G4", 1.0), ("F4", 1.0), ("E4", 2.0), ("D4", 1.0), ("E4", 1.0), ("F4", 2.0), ("E4", 1.0), ("C4", 1.0), ("D4", 4.0)]
    pos = 16.0
    for rep in range(2):
        p = pos + rep * 24.0
        for name, d in motif:
            place(buf, brass(midi(n(name)), d * 0.75 + 0.3, bright=0.7 + 0.3 * rep), p, 0.32)
            p += d * 0.75
    for k in range(0, 64, 2):
        place(buf, pluck(midi(n("D5") + [0, 7, 12, 3][k % 4]), 2.0, 2.2), k * 1.0 + 0.5, 0.05)
    return normalise(loopify(reverb(buf, 3.0, 0.32), L))

def situation():
    """In-game ambience: slow pads, sparse piano, a quiet pulse. 96 s loop."""
    L = 96.0
    buf = np.zeros(int((L + 4) * SR))
    prog = [("D3", "m9"), ("Bb2", "M7"), ("G2", "m9"), ("A2", "sus")] * 3
    for i, (root, kind) in enumerate(prog):
        place(buf, pad(chord(n(root), kind), 9.0, cutoff=800, a=2.5, r=2.5), i * 8.0, 0.42)
    scale = [n(x) for x in ("D4", "E4", "F4", "A4", "C5", "D5", "F5")]
    for k in range(40):
        st = rng.uniform(0, L - 2)
        place(buf, pluck(midi(scale[rng.integers(len(scale))]), 3.0, 1.2), st, 0.10)
    for k in np.arange(0, L, 2.0):
        place(buf, lowpass(timpani(55.0, 1.2), 200), k, 0.12)
    return normalise(loopify(reverb(buf, 3.5, 0.4, seed=3), L), 0.6)

def tension():
    """Crisis: 100 bpm ostinato, b2 harmony, timpani. 38.4 s loop."""
    bpm, bars = 100, 16
    beat = 60 / bpm
    L = bars * 4 * beat
    buf = np.zeros(int((L + 4) * SR))
    for bar in range(bars):
        root = n("D3") if (bar // 2) % 2 == 0 else n("Eb3")
        place(buf, pad(chord(root, "m"), 4 * beat + 0.4, cutoff=900, a=0.3, r=0.4), bar * 4 * beat, 0.32)
        for e in range(8):
            f = midi(n("D2") + (12 if e % 4 == 2 else 0))
            s = lowpass(saw(f, beat / 2), 1200) * env(int(beat / 2 * SR), 0.005, 0.12)
            place(buf, s, bar * 4 * beat + e * beat / 2, 0.30 if e % 2 == 0 else 0.20)
        place(buf, timpani(73.4), bar * 4 * beat, 0.5)
        if bar % 4 == 3:
            place(buf, timpani(73.4), bar * 4 * beat + 3 * beat, 0.4)
            place(buf, timpani(73.4), bar * 4 * beat + 3.5 * beat, 0.4)
    for bar in range(8, 16, 2):
        place(buf, brass(midi(n("A3")), 2 * beat * 4 * 0.9, bright=0.5), bar * 4 * beat, 0.18)
    return normalise(loopify(reverb(buf, 2.2, 0.25, seed=5), L), 0.75)

def fanfare(win=True):
    buf = np.zeros(int(7 * SR))
    if win:
        notes = [("D4", 0.0, 0.3), ("F#4", 0.3, 0.3), ("A4", 0.6, 0.3), ("D5", 0.9, 2.2)]
        place(buf, pad(chord(n("D3"), "M"), 4.0, cutoff=1800, a=0.4, r=2.0), 0.9, 0.5)
        place(buf, timpani(73.4), 0.9, 0.6)
    else:
        notes = [("A4", 0.0, 0.6), ("F4", 0.6, 0.6), ("D4", 1.2, 0.6), ("C#4", 1.8, 2.4)]
        place(buf, pad(chord(n("D3"), "m"), 4.5, cutoff=700, a=0.6, r=2.5), 1.2, 0.5)
    for name, st, d in notes:
        place(buf, brass(midi(n(name)), d + 0.2, bright=1.0 if win else 0.5), st, 0.45)
    return normalise(reverb(buf, 2.5, 0.3)[: int(7 * SR)])

# ---------------------------------------------------------------- sfx

def sfx_click():
    x = noise_burst(0.04, 2000, 9000, 160) * 0.6 + np.sin(2 * np.pi * 1800 * t(0.04)) * np.exp(-t(0.04) * 120) * 0.4
    return normalise(x, 0.5)

def sfx_hover():
    return normalise(np.sin(2 * np.pi * 2400 * t(0.03)) * np.exp(-t(0.03) * 150), 0.15)

def sfx_paper():
    d = 0.45
    x = noise_burst(d, 600, 6000, 4)
    sweep = np.interp(t(d), [0, d], [0.2, 1.0])
    return normalise(x * np.sin(np.pi * t(d) / d) * sweep, 0.5)

def sfx_stamp():
    thump = np.sin(2 * np.pi * np.cumsum(90 * (1 + np.exp(-t(0.3) * 40))) / SR) * np.exp(-t(0.3) * 18)
    return normalise(thump + noise_burst(0.3, 200, 3000, 35) * 0.6, 0.8)

def sfx_teletype():
    d = 1.1
    buf = np.zeros(int(d * SR))
    for k in range(14):
        place(buf, noise_burst(0.025, 1500, 7000, 200), 0.05 + k * 0.055 + rng.uniform(0, 0.01), 0.6)
    place(buf, pluck(midi(n("A6")), 1.0, 3.0), 0.85, 0.5)
    return normalise(buf, 0.6)

def sfx_alert():
    d = 1.2
    buf = np.zeros(int(d * SR))
    for k, f in enumerate((880, 660, 880, 660)):
        s = np.sign(np.sin(2 * np.pi * f * t(0.18))) * 0.3 + np.sin(2 * np.pi * f * t(0.18))
        place(buf, lowpass(s, 3000) * env(int(0.18 * SR), 0.005, 0.05), k * 0.25, 0.5)
    return normalise(buf, 0.55)

def sfx_coin():
    buf = np.zeros(int(0.6 * SR))
    place(buf, pluck(midi(n("B5")), 0.5, 6), 0, 0.6)
    place(buf, pluck(midi(n("E6")), 0.5, 5), 0.08, 0.6)
    return normalise(buf, 0.5)

def sfx_key():
    return normalise(noise_burst(0.02, 2500, 8000, 300) + np.sin(2 * np.pi * 3000 * t(0.02)) * np.exp(-t(0.02) * 300) * 0.3, 0.35)

def sfx_boom():
    d = 2.0
    rumble = lowpass(rng.standard_normal(int(d * SR)), 160) * np.exp(-t(d) * 2.2)
    return normalise(rumble + timpani(45, d) * 0.6, 0.8)

def main():
    os.makedirs(OUT, exist_ok=True)
    write("music_theme", theme(), 4)
    write("music_situation", situation(), 4)
    write("music_tension", tension(), 4)
    write("sting_win", fanfare(True))
    write("sting_loss", fanfare(False))
    for name, fn in [("click", sfx_click), ("hover", sfx_hover), ("paper", sfx_paper), ("stamp", sfx_stamp),
                     ("teletype", sfx_teletype), ("alert", sfx_alert), ("coin", sfx_coin), ("key", sfx_key), ("boom", sfx_boom)]:
        write("sfx_" + name, fn())
    print("audio done")

if __name__ == "__main__":
    main()
