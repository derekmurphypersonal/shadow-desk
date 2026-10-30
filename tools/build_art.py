#!/usr/bin/env python3
"""Original briefing illustrations: duotone poster scenes built from simple silhouettes.

Each scene is SVG -> PNG (cairosvg), then halftone grain is added with Pillow. A greyscale
newsprint version is saved alongside for the newspaper.
Usage: python3 tools/build_art.py
"""
import math, random, io
import cairosvg
from PIL import Image, ImageFilter, ImageOps, ImageEnhance

W, H = 720, 240
OUT = "assets/art"

PAL = {  # sky top, sky bottom, far, near, accent
    "war": ("#2a1410", "#c4502b", "#5a2418", "#1a0c08", "#ffb15c"),
    "diplomacy": ("#14223a", "#4e78a8", "#24395a", "#0e1828", "#f0c870"),
    "disaster": ("#1b2430", "#5f7486", "#2b3a48", "#121a22", "#d8e4f0"),
    "economy": ("#122418", "#3f7a52", "#1c3a26", "#0b170f", "#e8d070"),
    "covert": ("#0d0f18", "#2f3550", "#1a1d2e", "#07080e", "#e6e0c0"),
    "domestic": ("#1a1830", "#6a5a8e", "#2e2850", "#100e1e", "#f4d890"),
    "health": ("#0f2626", "#3f8a86", "#1a3e3c", "#0a1a1a", "#f2f2e8"),
    "space": ("#06070f", "#1e2450", "#121633", "#05060c", "#f6f0d0"),
    "naval": ("#0e1d2e", "#3d6e96", "#1a3550", "#0a1420", "#f0d8a0"),
    "protest": ("#2a1426", "#a0486a", "#4a2040", "#1a0a16", "#ffd27a"),
    "nuclear": ("#181a0c", "#8a8a2e", "#33341a", "#0e0f06", "#f8f0a0"),
    "election": ("#1a1e3a", "#8a3a46", "#2a2e5a", "#111428", "#f6f2e8"),
    "terror": ("#1e1410", "#7a4a30", "#3a2418", "#120c08", "#ffcf8a"),
    "tech": ("#081a1e", "#1e6a74", "#0f3238", "#061014", "#7ff0e0"),
    "famine": ("#2a1e0c", "#c49040", "#5a4018", "#1e1408", "#fff0c0"),
}

def sky(c1, c2):
    return (f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c1}"/>'
            f'<stop offset="1" stop-color="{c2}"/></linearGradient>'
            f'<radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#ffffff" stop-opacity=".55"/>'
            f'<stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient></defs>'
            f'<rect width="{W}" height="{H}" fill="url(#sky)"/>')

def sun(x, y, r, col, op=0.9):
    return f'<circle cx="{x}" cy="{y}" r="{r*2.2}" fill="url(#glow)" opacity=".5"/><circle cx="{x}" cy="{y}" r="{r}" fill="{col}" opacity="{op}"/>'

def skyline(rng, x0, x1, base, hmin, hmax, col, windows=None):
    out, x = [], x0
    while x < x1:
        w = rng.randint(18, 46)
        h = rng.randint(hmin, hmax)
        out.append(f'<rect x="{x}" y="{base-h}" width="{w}" height="{h+2}" fill="{col}"/>')
        if rng.random() < 0.3:
            out.append(f'<rect x="{x+w/2-1.5}" y="{base-h-14}" width="3" height="14" fill="{col}"/>')
        if windows:
            for wy in range(base - h + 8, base - 6, 10):
                for wx in range(x + 4, x + w - 4, 8):
                    if rng.random() < 0.28:
                        out.append(f'<rect x="{wx}" y="{wy}" width="3" height="4" fill="{windows}" opacity=".7"/>')
        x += w + rng.randint(0, 4)
    return "".join(out)

def hills(base, amp, col, seed, step=40):
    rng = random.Random(seed)
    pts = [f"0,{H}", f"0,{base}"]
    for x in range(0, W + step, step):
        pts.append(f"{x},{base - rng.uniform(0, amp)}")
    pts += [f"{W},{H}"]
    return f'<polygon points="{" ".join(pts)}" fill="{col}"/>'

def ground(y, col):
    return f'<rect x="0" y="{y}" width="{W}" height="{H-y}" fill="{col}"/>'

def smoke(x, y, s, col, seed):
    rng = random.Random(seed)
    out = []
    for i in range(9):
        out.append(f'<circle cx="{x + rng.uniform(-14,14)*s + i*6*s}" cy="{y - i*14*s}" r="{(10+i*3)*s}" fill="{col}" opacity="{0.55 - i*0.05:.2f}"/>')
    return "".join(out)

def tank(x, y, s, col):
    return (f'<g transform="translate({x} {y}) scale({s})" fill="{col}">'
            '<rect x="-40" y="-14" width="80" height="16" rx="8"/>'
            '<path d="M-30 -14 L-22 -28 L22 -28 L30 -14 Z"/>'
            '<rect x="-14" y="-38" width="30" height="12" rx="4"/>'
            '<rect x="14" y="-35" width="46" height="5"/></g>')

def jet(x, y, s, col, rot=0):
    return (f'<g transform="translate({x} {y}) rotate({rot}) scale({s})" fill="{col}">'
            '<path d="M-40 0 L30 -3 L40 0 L30 3 Z"/><path d="M-4 0 L-22 -22 L-12 -22 L10 0 Z"/>'
            '<path d="M-4 0 L-22 22 L-12 22 L10 0 Z"/><path d="M-36 0 L-44 -10 L-38 -10 L-30 0 Z"/></g>')

def ship(x, y, s, col):
    return (f'<g transform="translate({x} {y}) scale({s})" fill="{col}">'
            '<path d="M-90 0 L90 0 L76 16 L-80 16 Z"/><rect x="-30" y="-18" width="50" height="18"/>'
            '<rect x="-14" y="-34" width="22" height="16"/><rect x="-4" y="-56" width="3" height="22"/>'
            '<rect x="30" y="-10" width="30" height="10"/><rect x="-70" y="-8" width="26" height="8"/></g>')

def dome(x, base, s, col):
    return (f'<g transform="translate({x} {base}) scale({s})" fill="{col}">'
            '<rect x="-120" y="-40" width="240" height="40"/><rect x="-60" y="-70" width="120" height="30"/>'
            '<path d="M-46 -70 C-46 -120 46 -120 46 -70 Z"/><rect x="-10" y="-132" width="20" height="22"/>'
            '<path d="M-4 -150 L4 -150 L3 -132 L-3 -132 Z"/>'
            + "".join(f'<rect x="{-110 + i*20}" y="-38" width="6" height="34" fill-opacity=".0"/>' for i in range(12)) + '</g>')

def columns(x, base, s, col, light):
    out = [f'<g transform="translate({x} {base}) scale({s})">']
    out.append(f'<rect x="-120" y="-40" width="240" height="40" fill="{col}"/>')
    for i in range(10):
        out.append(f'<rect x="{-108 + i*23}" y="-36" width="8" height="34" fill="{light}" opacity=".18"/>')
    out.append('</g>')
    return "".join(out)

def podium_flags(x, base, s, col, flag_cols):
    out = [f'<g transform="translate({x} {base}) scale({s})">']
    for i, fc in enumerate(flag_cols):
        fx = -120 + i * 48
        out.append(f'<rect x="{fx}" y="-150" width="3" height="150" fill="{col}"/>')
        out.append(f'<path d="M{fx+3} -148 C{fx+20} -156 {fx+30} -140 {fx+46} -146 L{fx+46} -118 C{fx+30} -112 {fx+20} -128 {fx+3} -120 Z" fill="{fc}"/>')
    out.append(f'<path d="M-40 0 L-30 -60 L30 -60 L40 0 Z" fill="{col}"/><rect x="-46" y="-66" width="92" height="8" fill="{col}"/>')
    out.append(f'<rect x="-3" y="-80" width="3" height="16" fill="{col}"/><circle cx="-1" cy="-82" r="4" fill="{col}"/>')
    out.append('</g>')
    return "".join(out)

def crowd(base, col, accent, seed, count=30):
    rng = random.Random(seed)
    out = []
    for row, (yoff, sc, n) in enumerate([(0, 1.0, count), (26, 1.35, int(count * 0.75))]):
        for i in range(n):
            x = i * (W / n) + rng.uniform(-8, 8) + row * 12
            h = rng.uniform(0, 12)
            b = base + yoff
            c = col
            out.append(f'<circle cx="{x}" cy="{b - 52*sc - h}" r="{11*sc}" fill="{c}"/>')
            out.append(f'<path d="M{x-20*sc} {b} C{x-20*sc} {b-40*sc-h} {x+20*sc} {b-40*sc-h} {x+20*sc} {b} Z" fill="{c}"/>')
            if rng.random() < 0.28 and row == 0:
                sx = x + rng.uniform(-6, 6)
                out.append(f'<rect x="{sx-1.5}" y="{b-120-h}" width="3" height="60" fill="{c}"/>')
                out.append(f'<rect x="{sx-24}" y="{b-148-h}" width="48" height="30" fill="{accent}" opacity=".92"/>')
                out.append(f'<rect x="{sx-14}" y="{b-136-h}" width="28" height="5" fill="{c}" opacity=".7"/>')
    return "".join(out)


def clouds(y, col, seed, n=7, op=0.85):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        cx = rng.uniform(0, W)
        for j in range(5):
            out.append(f'<ellipse cx="{cx + j*24 - 48}" cy="{y + rng.uniform(-10, 10)}" rx="{rng.uniform(30,50)}" ry="{rng.uniform(16,26)}" fill="{col}" opacity="{op}"/>')
    return "".join(out)

def rain(col, seed):
    rng = random.Random(seed)
    return "".join(f'<line x1="{x}" y1="{y}" x2="{x-10}" y2="{y+26}" stroke="{col}" stroke-width="1.5" opacity=".45"/>'
                   for x, y in [(rng.uniform(0, W+40), rng.uniform(60, H)) for _ in range(140)])

def waves(base, col, n=4):
    out = []
    for k in range(n):
        y = base + k * 14
        d = f"M0 {y} " + " ".join(f"Q{x+20} {y-10} {x+40} {y} T{x+80} {y}" for x in range(0, W, 80))
        out.append(f'<path d="{d} L{W} {H} L0 {H} Z" fill="{col}" opacity="{0.5 + k*0.15:.2f}"/>')
    return "".join(out)

def virus(x, y, r, col, accent):
    out = [f'<circle cx="{x}" cy="{y}" r="{r}" fill="{col}"/>']
    for i in range(14):
        a = i * 2 * math.pi / 14
        x1, y1 = x + r * math.cos(a), y + r * math.sin(a)
        x2, y2 = x + (r + r*0.35) * math.cos(a), y + (r + r*0.35) * math.sin(a)
        out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="{r*0.12}"/>')
        out.append(f'<circle cx="{x2}" cy="{y2}" r="{r*0.12}" fill="{accent}"/>')
    out.append(f'<circle cx="{x - r*0.3}" cy="{y - r*0.2}" r="{r*0.18}" fill="{accent}" opacity=".5"/>')
    return "".join(out)

def rocket(x, y, s, col, accent):
    return (f'<g transform="translate({x} {y}) rotate(-28) scale({s})">'
            f'<path d="M0 -70 C14 -50 16 -10 12 30 L-12 30 C-16 -10 -14 -50 0 -70 Z" fill="{col}"/>'
            f'<path d="M-12 10 L-26 36 L-12 30 Z M12 10 L26 36 L12 30 Z" fill="{col}"/>'
            f'<circle cx="0" cy="-30" r="6" fill="{accent}"/>'
            f'<path d="M-8 32 C-6 60 6 60 8 32 Z" fill="{accent}" opacity=".9"/></g>')

def stars(seed, n, col):
    rng = random.Random(seed)
    return "".join(f'<circle cx="{rng.uniform(0,W)}" cy="{rng.uniform(0,H*0.7)}" r="{rng.uniform(0.6,1.8)}" fill="{col}" opacity="{rng.uniform(.4,1):.2f}"/>' for _ in range(n))

def figure(x, base, s, col):
    return (f'<g transform="translate({x} {base}) scale({s})" fill="{col}">'
            '<path d="M-30 0 C-34 -60 -24 -96 0 -98 C24 -96 34 -60 30 0 Z"/>'
            '<circle cx="0" cy="-112" r="14"/><path d="M-26 -118 L26 -118 L18 -126 L12 -140 L-12 -140 L-18 -126 Z"/></g>')

def atom(x, y, r, col):
    out = [f'<circle cx="{x}" cy="{y}" r="{r*0.18}" fill="{col}"/>']
    for a in (0, 60, 120):
        out.append(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*0.36}" fill="none" stroke="{col}" stroke-width="{r*0.07}" transform="rotate({a} {x} {y})"/>')
    return "".join(out)

def ballot(x, base, s, col, accent):
    return (f'<g transform="translate({x} {base}) scale({s})">'
            f'<rect x="-60" y="-80" width="120" height="80" fill="{col}"/><rect x="-40" y="-86" width="80" height="6" fill="{accent}"/>'
            f'<path d="M-24 -130 L22 -128 L18 -84 L-26 -86 Z" fill="{accent}"/>'
            f'<path d="M-12 -110 L-4 -100 L12 -120" stroke="{col}" stroke-width="5" fill="none"/></g>')

def chart(col, accent, up=True):
    pts = []
    rng = random.Random(4)
    y = 170 if up else 70
    for x in range(40, W - 30, 34):
        y += rng.uniform(-18, 8) if up else rng.uniform(-8, 18)
        pts.append(f"{x},{max(30, min(200, y))}")
    return (f'<polyline points="{" ".join(pts)}" fill="none" stroke="{accent}" stroke-width="5" stroke-linejoin="round"/>'
            + "".join(f'<line x1="40" y1="{yy}" x2="{W-30}" y2="{yy}" stroke="{col}" stroke-width="1" opacity=".35"/>' for yy in range(40, 220, 30)))

def circuit(col, accent, seed):
    rng = random.Random(seed)
    out = []
    for _ in range(40):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        dx = rng.choice([-1, 1]) * rng.uniform(30, 120)
        dy = rng.choice([-1, 1]) * rng.uniform(20, 70)
        out.append(f'<path d="M{x} {y} h{dx} v{dy}" stroke="{col}" stroke-width="2" fill="none" opacity=".7"/>')
        out.append(f'<circle cx="{x+dx}" cy="{y+dy}" r="3.5" fill="{accent}" opacity=".8"/>')
    out.append(f'<rect x="{W/2-60}" y="{H/2-60}" width="120" height="120" rx="10" fill="{col}"/>')
    out.append(f'<rect x="{W/2-40}" y="{H/2-40}" width="80" height="80" rx="6" fill="{accent}" opacity=".85"/>')
    for i in range(6):
        out.append(f'<rect x="{W/2-52 + i*20}" y="{H/2-74}" width="6" height="14" fill="{col}"/><rect x="{W/2-52 + i*20}" y="{H/2+60}" width="6" height="14" fill="{col}"/>')
    return "".join(out)

def wheat(base, col, seed):
    rng = random.Random(seed)
    out = []
    for i in range(70):
        x = rng.uniform(0, W)
        h = rng.uniform(30, 70)
        lean = rng.uniform(-10, 10)
        out.append(f'<path d="M{x} {base} Q{x+lean/2} {base-h/2} {x+lean} {base-h}" stroke="{col}" stroke-width="2" fill="none"/>')
        out.append(f'<ellipse cx="{x+lean}" cy="{base-h-6}" rx="3" ry="9" fill="{col}" transform="rotate({lean} {x+lean} {base-h})"/>')
    return "".join(out)

def cracks(y, col, seed):
    rng = random.Random(seed)
    out = []
    for _ in range(26):
        x = rng.uniform(0, W)
        yy = rng.uniform(y + 10, H)
        d = f"M{x} {yy}"
        for _ in range(4):
            x += rng.uniform(-30, 30)
            yy += rng.uniform(-8, 8)
            d += f" L{x} {yy}"
        out.append(f'<path d="{d}" stroke="{col}" stroke-width="2" fill="none" opacity=".7"/>')
    return "".join(out)

def scene(cat):
    s1, s2, far, near, acc = PAL[cat]
    rng = random.Random(hash(cat) % 1000)
    p = [sky(s1, s2)]
    if cat == "war":
        p += [sun(560, 120, 46, acc, .7), hills(170, 30, far, 1), smoke(150, 150, 1.4, near, 3), smoke(470, 160, 1.0, far, 5),
              jet(260, 60, 0.9, near, -8), jet(330, 84, 0.6, near, -8), ground(200, near), tank(420, 200, 1.4, near), tank(600, 204, 1.0, near)]
    elif cat == "diplomacy":
        p += [sun(360, 70, 34, acc, .55), columns(360, 236, 2.4, far, acc), podium_flags(360, 236, 1.0, near, [acc, "#c8d4e8", "#9a3a3a", "#3a6a9a", acc, "#c8d4e8"])]
    elif cat == "disaster":
        p += [clouds(40, far, 2, 9), clouds(70, near, 3, 6, .7), rain(acc, 4),
              f'<path d="M420 40 L396 110 L420 108 L398 170 L452 90 L426 92 L446 40 Z" fill="{acc}" opacity=".9"/>',
              skyline(rng, 0, W, 210, 30, 90, near), waves(196, far, 3)]
    elif cat == "economy":
        p += [chart(far, acc, True), skyline(rng, 0, W, 240, 40, 130, near, acc)]
    elif cat == "covert":
        p += [f'<path d="M360 0 L180 240 L540 240 Z" fill="{acc}" opacity=".10"/>', skyline(rng, 0, W, 240, 60, 160, far, acc),
              ground(222, near), figure(360, 222, 0.95, near)]
    elif cat == "domestic":
        p += [sun(520, 60, 30, acc, .6), stars(5, 40, acc), dome(360, 236, 1.3, near)]
    elif cat == "health":
        p += [virus(560, 110, 56, far, acc), virus(170, 70, 30, far, acc),
              f'<rect x="300" y="60" width="120" height="40" rx="6" fill="{acc}" opacity=".9"/><rect x="340" y="20" width="40" height="120" rx="6" fill="{acc}" opacity=".9"/>',
              skyline(rng, 0, W, 240, 20, 70, near)]
    elif cat == "space":
        p += [stars(7, 160, acc), f'<circle cx="560" cy="300" r="190" fill="{far}"/>', f'<circle cx="150" cy="60" r="34" fill="{acc}" opacity=".85"/><circle cx="162" cy="52" r="34" fill="{s1}"/>',
              rocket(380, 130, 1.1, acc, "#ff9a4a")]
    elif cat == "naval":
        p += [sun(160, 100, 40, acc, .6), waves(170, far, 2), ship(420, 176, 1.5, near), ship(160, 186, 0.7, near), waves(196, near, 3), jet(560, 50, 0.6, near, 6)]
    elif cat == "protest":
        p += [skyline(rng, 0, W, 200, 60, 140, far), crowd(222, near, acc, 9, 22)]
    elif cat == "nuclear":
        p += [sun(360, 90, 70, acc, .25), atom(360, 100, 70, acc), hills(190, 50, far, 6), hills(215, 20, near, 7)]
    elif cat == "election":
        p += [stars(11, 30, acc), ''.join(f'<path d="M{x} 0 Q{x+60} 34 {x+120} 0" fill="none" stroke="{c}" stroke-width="10"/>' for x, c in [(0, acc), (120, "#9a3a46"), (240, acc), (360, "#9a3a46"), (480, acc), (600, "#9a3a46")]),
              dome(560, 236, 0.8, far), ballot(250, 236, 1.2, near, acc)]
    elif cat == "terror":
        p += [smoke(380, 150, 1.6, far, 12), skyline(rng, 0, W, 240, 50, 130, near, acc),
              f'<circle cx="380" cy="170" r="40" fill="{acc}" opacity=".35"/><circle cx="380" cy="170" r="18" fill="{acc}" opacity=".6"/>']
    elif cat == "tech":
        p += [circuit(far, acc, 13)]
    elif cat == "famine":
        p += [sun(520, 80, 52, acc, .85), hills(170, 20, far, 14), ground(170, far), cracks(170, near, 15), wheat(240, near, 16)]
    # Vignette
    p.append(f'<rect width="{W}" height="{H}" fill="none" stroke="#000" stroke-opacity=".35" stroke-width="30"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{"".join(p)}</svg>'

def grain(img, amount=18, seed=0):
    noise = Image.effect_noise(img.size, amount).convert("L")
    noise = ImageOps.autocontrast(noise)
    rgb = img.convert("RGB")
    blended = Image.blend(rgb, Image.merge("RGB", (noise, noise, noise)), 0.06)
    return blended

def halftone(img, cell=5):
    g = img.convert("L").resize((W // cell, H // cell), Image.BILINEAR)
    out = Image.new("L", (W, H), 238)
    from PIL import ImageDraw
    d = ImageDraw.Draw(out)
    for y in range(g.height):
        for x in range(g.width):
            v = 1.0 - g.getpixel((x, y)) / 255.0
            r = v * cell * 0.72
            if r > 0.3:
                cx, cy = x * cell + cell / 2, y * cell + cell / 2
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=30)
    return out.convert("RGB")

def main():
    for cat in PAL:
        png = cairosvg.svg2png(bytestring=scene(cat).encode(), output_width=W, output_height=H)
        img = Image.open(io.BytesIO(png))
        g = grain(img)
        g.save(f"{OUT}/{cat}.png", optimize=True)
        halftone(ImageEnhance.Brightness(ImageEnhance.Contrast(g).enhance(1.15)).enhance(2.1)).save(f"{OUT}/{cat}_news.png", optimize=True)
    print(len(PAL), "scenes")

if __name__ == "__main__":
    main()
