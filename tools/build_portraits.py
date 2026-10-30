#!/usr/bin/env python3
"""Generate original flat-illustration advisor portraits (SVG -> PNG via cairosvg).

Every portrait is drawn procedurally from the parameters below: no source artwork, no real people.
Usage: python3 tools/build_portraits.py
"""
import os, re
import cairosvg

OUT = "assets/portraits"
SKIN = ["#f3d5b5", "#e9bb92", "#d29c6f", "#b47a4f", "#8c5a38", "#5e3a25"]
HAIR = {"black": "#1e1a18", "dark": "#3a2a20", "brown": "#6b4a32", "blonde": "#cfa864", "auburn": "#8b4a2c",
        "grey": "#a7a5a2", "white": "#e2dfda", "salt": "#77736e"}
SUIT = {"navy": "#1f2d4a", "charcoal": "#33363d", "grey": "#5b6270", "black": "#16181d", "olive": "#3f4a33",
        "burgundy": "#5a2430", "teal": "#1d4a4f", "camel": "#8a6a45"}
TIE = {"red": "#a3262e", "navy": "#203a6b", "teal": "#1f7a7a", "gold": "#c79a3b", "burgundy": "#6e1f2e", "green": "#2f6b3f"}
BG = ["#2b3a55", "#3a2f4f", "#24464a", "#4a3a2b", "#2d3f2f", "#4a2b33", "#2b4057"]

def shade(hex_, f):
    h = hex_.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if f < 1:
        r, g, b = (int(c * f) for c in (r, g, b))
    else:
        r, g, b = (int(c + (255 - c) * (f - 1)) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)

def hair_back(style, c):
    if style == "bob":
        return f'<path d="M160 250 C150 150 210 118 256 118 C306 118 364 150 352 250 C356 300 350 340 336 356 L176 356 C162 340 156 300 160 250 Z" fill="{c}"/>'
    if style == "long":
        return f'<path d="M158 250 C146 150 206 112 256 112 C310 112 368 150 354 250 C362 330 376 400 360 430 L152 430 C136 400 150 330 158 250 Z" fill="{c}"/>'
    if style == "bun":
        return f'<circle cx="256" cy="128" r="38" fill="{c}"/>'
    return ""

def hair_front(style, c):
    hi = shade(c, 1.25)
    if style == "short":
        return (f'<path d="M172 238 C164 150 226 122 262 124 C318 126 350 168 342 238 C334 206 318 186 300 182 C262 176 222 178 204 190 C186 202 176 220 172 238 Z" fill="{c}"/>'
                f'<path d="M220 140 C250 128 290 130 314 146" stroke="{hi}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".5"/>')
    if style == "side_part":
        return (f'<path d="M170 246 C160 150 228 118 268 122 C322 126 352 170 342 244 C338 214 330 196 318 186 C290 170 250 168 228 176 C206 186 190 200 186 214 C180 226 174 236 170 246 Z" fill="{c}"/>'
                f'<path d="M228 176 C236 150 270 136 318 150" stroke="{shade(c, .7)}" stroke-width="4" fill="none" stroke-linecap="round"/>'
                f'<path d="M244 140 C270 130 300 134 322 150" stroke="{hi}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".45"/>')
    if style == "buzz":
        return f'<path d="M174 232 C168 156 222 128 258 128 C300 128 346 156 340 232 C330 200 300 180 256 178 C214 180 184 200 174 232 Z" fill="{c}" opacity=".9"/>'
    if style == "bald":
        return (f'<path d="M172 262 C168 236 172 214 182 200 C186 222 186 244 190 268 Z" fill="{c}"/>'
                f'<path d="M340 262 C344 236 340 214 330 200 C326 222 326 244 322 268 Z" fill="{c}"/>'
                f'<ellipse cx="236" cy="150" rx="34" ry="14" fill="#ffffff" opacity=".12"/>')
    if style == "bob":
        return (f'<path d="M168 260 C160 170 214 130 262 132 C312 134 352 176 344 262 C336 222 318 196 292 186 C276 210 230 214 196 206 C182 222 172 240 168 260 Z" fill="{c}"/>'
                f'<path d="M226 150 C252 140 290 142 316 160" stroke="{hi}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".45"/>')
    if style == "long":
        return (f'<path d="M166 270 C156 168 214 126 262 128 C314 130 356 172 346 270 C336 220 316 192 286 182 C262 200 214 206 192 200 C178 220 170 244 166 270 Z" fill="{c}"/>'
                f'<path d="M224 148 C252 136 292 138 318 158" stroke="{hi}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".45"/>')
    if style == "bun":
        return (f'<path d="M172 240 C166 160 222 132 258 132 C302 132 348 160 340 240 C330 206 304 186 256 184 C212 186 182 206 172 240 Z" fill="{c}"/>'
                f'<path d="M222 150 C250 140 288 142 312 158" stroke="{hi}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".45"/>')
    if style == "curly":
        circles = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>' for x, y, r in [
            (184, 220, 22), (190, 186, 24), (214, 158, 26), (248, 144, 28), (284, 146, 27), (314, 164, 25),
            (330, 194, 23), (334, 226, 20), (176, 246, 16), (340, 250, 15)])
        return circles + f'<path d="M196 196 C230 180 290 178 320 200" stroke="{hi}" stroke-width="5" fill="none" opacity=".35"/>'
    return ""

def portrait(p):
    skin = SKIN[p["skin"]]
    sd = shade(skin, .82)
    hair = HAIR[p["hair"]]
    suit = SUIT[p["suit"]]
    bg = p.get("bg", BG[0])
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">',
             '<defs>',
             f'<radialGradient id="bg" cx="50%" cy="38%" r="70%"><stop offset="0" stop-color="{shade(bg, 1.35)}"/><stop offset="1" stop-color="{shade(bg, .55)}"/></radialGradient>',
             f'<linearGradient id="suit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(suit, 1.15)}"/><stop offset="1" stop-color="{shade(suit, .8)}"/></linearGradient>',
             '</defs>',
             '<rect width="512" height="512" rx="64" fill="url(#bg)"/>',
             f'<circle cx="256" cy="230" r="170" fill="#ffffff" opacity=".05"/>']
    parts.append('<g transform="translate(256 300) scale(1.28) translate(-256 -270)">')
    parts.append(hair_back(p["style"], hair))
    # neck + shoulders
    parts.append(f'<path d="M222 320 L290 320 L294 400 L218 400 Z" fill="{sd}"/>')
    parts.append(f'<path d="M36 512 C38 440 110 398 206 388 L306 388 C402 398 474 440 476 512 Z" fill="url(#suit)"/>')
    top = p.get("top", "tie")
    if top == "tie":
        parts.append('<path d="M214 388 L256 470 L298 388 Z" fill="#f4f1ea"/>')
        tie = TIE[p.get("tie", "red")]
        parts.append(f'<path d="M244 396 L268 396 L264 414 L276 470 L256 492 L236 470 L248 414 Z" fill="{tie}"/>')
        parts.append(f'<path d="M244 396 L268 396 L264 414 L248 414 Z" fill="{shade(tie, .75)}"/>')
    elif top == "blouse":
        parts.append(f'<path d="M210 388 L256 452 L302 388 Z" fill="{p.get("blouse", "#e9e3d8")}"/>')
        if p.get("pearls"):
            parts.append("".join(f'<circle cx="{256 + 44 * __import__("math").cos(a / 10)}" cy="{372 + 34 * __import__("math").sin(a / 10)}" r="5" fill="#f6f1e6"/>' for a in range(6, 26, 2)))
    elif top == "turtleneck":
        parts.append(f'<path d="M214 372 C230 392 282 392 298 372 L306 404 C280 420 232 420 206 404 Z" fill="{shade(suit, .6)}"/>')
    # lapels
    parts.append(f'<path d="M206 388 L256 476 L228 408 L186 398 Z" fill="{shade(suit, .78)}"/>')
    parts.append(f'<path d="M306 388 L256 476 L284 408 L326 398 Z" fill="{shade(suit, .78)}"/>')
    if p.get("pin"):
        parts.append('<circle cx="330" cy="430" r="7" fill="#d6b25e"/><circle cx="330" cy="430" r="3" fill="#a3262e"/>')
    # ears
    parts.append(f'<ellipse cx="176" cy="258" rx="15" ry="24" fill="{sd}"/><ellipse cx="336" cy="258" rx="15" ry="24" fill="{sd}"/>')
    if p.get("earrings"):
        parts.append('<circle cx="176" cy="288" r="6" fill="#e2c26b"/><circle cx="336" cy="288" r="6" fill="#e2c26b"/>')
    # face
    jaw = p.get("jaw", 0)
    parts.append(f'<path d="M176 236 C176 150 336 150 336 236 C336 {300 + jaw} {300 + jaw} {346 + jaw} 256 {350 + jaw} C{212 - jaw} {346 + jaw} 176 {300 + jaw} 176 236 Z" fill="{skin}"/>')
    parts.append(f'<path d="M300 300 C292 330 276 {344 + jaw} 256 {350 + jaw} C{286 + jaw // 2} {346 + jaw} 322 {316 + jaw} 334 260 C326 280 314 294 300 300 Z" fill="{sd}" opacity=".45"/>')
    parts.append(f'<ellipse cx="216" cy="292" rx="16" ry="9" fill="#d9776a" opacity=".15"/><ellipse cx="296" cy="292" rx="16" ry="9" fill="#d9776a" opacity=".15"/>')
    # facial hair
    fh = p.get("facial")
    hc = HAIR[p.get("beard_color", p["hair"])]
    if fh in ("beard", "full"):
        parts.append(f'<path d="M180 262 C186 320 214 {352 + jaw} 256 {356 + jaw} C298 {352 + jaw} 326 320 332 262 C324 300 302 318 286 316 C270 312 242 312 226 316 C210 318 188 300 180 262 Z" fill="{hc}" opacity=".95"/>')
    if fh in ("mustache", "full", "beard"):
        parts.append(f'<path d="M226 306 C236 296 250 298 256 302 C262 298 276 296 286 306 C276 312 264 310 256 308 C248 310 236 312 226 306 Z" fill="{hc}"/>')
    # eyes, brows
    for x in (226, 286):
        parts.append(f'<ellipse cx="{x}" cy="254" rx="12" ry="8" fill="#fbf8f2"/>')
        parts.append(f'<circle cx="{x}" cy="254" r="6.5" fill="#2b1d16"/><circle cx="{x + 2}" cy="252" r="2" fill="#ffffff"/>')
    brow = shade(hair if p["hair"] not in ("white", "grey") else "#6d6a66", .9)
    tilt = p.get("brow", 0)
    parts.append(f'<path d="M208 {232 - tilt} C218 {224 - tilt} 234 224 244 230" stroke="{brow}" stroke-width="7" fill="none" stroke-linecap="round"/>')
    parts.append(f'<path d="M268 230 C278 224 294 {224 - tilt} 304 {232 - tilt}" stroke="{brow}" stroke-width="7" fill="none" stroke-linecap="round"/>')
    if p.get("age", 0) >= 1:
        parts.append(f'<path d="M214 268 C222 272 232 272 238 268 M274 268 C280 272 290 272 298 268" stroke="{shade(skin, .7)}" stroke-width="2" fill="none" opacity=".6"/>')
    # nose, mouth
    parts.append(f'<path d="M256 262 C252 276 246 286 248 292 C252 296 260 296 266 292" stroke="{shade(skin, .66)}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    smile = p.get("smile", 6)
    lip = "#9b4f45" if p.get("lipstick") else shade(skin, .55)
    if fh not in ("full", "mustache", "beard"):
        parts.append(f'<path d="M234 318 C246 {318 + smile} 266 {318 + smile} 278 318" stroke="{lip}" stroke-width="5" fill="none" stroke-linecap="round"/>')
    else:
        parts.append(f'<path d="M240 322 C250 {322 + smile // 2} 262 {322 + smile // 2} 272 322" stroke="{shade(skin, .5)}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    parts.append(hair_front(p["style"], hair))
    if p.get("glasses"):
        g = p.get("glasses_color", "#1b1b1b")
        parts.append(f'<rect x="200" y="236" width="52" height="38" rx="12" fill="#ffffff" fill-opacity=".08" stroke="{g}" stroke-width="5"/>'
                     f'<rect x="260" y="236" width="52" height="38" rx="12" fill="#ffffff" fill-opacity=".08" stroke="{g}" stroke-width="5"/>'
                     f'<path d="M252 252 C254 248 258 248 260 252" stroke="{g}" stroke-width="4" fill="none"/>'
                     f'<path d="M200 248 L180 244 M312 248 L332 244" stroke="{g}" stroke-width="4"/>')
    parts.append('</g>')
    parts.append(f'<rect width="512" height="512" rx="64" fill="none" stroke="#ffffff" stroke-opacity=".08" stroke-width="6"/>')
    parts.append('</svg>')
    svg = "".join(parts)
    # Clip the zoomed bust to the rounded frame.
    return svg.replace('<rect width="512" height="512" rx="64" fill="url(#bg)"/>',
        '<clipPath id="frame"><rect width="512" height="512" rx="64"/></clipPath><rect width="512" height="512" rx="64" fill="url(#bg)"/><g clip-path="url(#frame)">', 1).replace('</g><rect width="512" height="512" rx="64" fill="none"', '</g></g><rect width="512" height="512" rx="64" fill="none"', 1)

PEOPLE = {
 "Margaret Holloway": dict(skin=0, hair="grey", style="bob", suit="navy", top="blouse", pearls=True, glasses=True, age=1, bg=BG[0], lipstick=True, earrings=True),
 "Daniel Okafor": dict(skin=4, hair="black", style="buzz", suit="charcoal", tie="burgundy", facial="beard", bg=BG[2], pin=True),
 "Ray Castellano": dict(skin=1, hair="salt", style="bald", suit="olive", tie="navy", facial="mustache", age=1, jaw=6, bg=BG[4], brow=3),
 "Evelyn Strand": dict(skin=0, hair="blonde", style="bun", suit="grey", top="blouse", blouse="#cfd8e6", earrings=True, bg=BG[6], lipstick=True),
 "Victor Lindqvist": dict(skin=0, hair="brown", style="side_part", suit="charcoal", tie="navy", glasses=True, bg=BG[1], smile=3),
 "Ruth Abernathy": dict(skin=3, hair="grey", style="curly", suit="black", top="turtleneck", age=1, bg=BG[5], smile=3, brow=2),
 "Samuel Ito": dict(skin=1, hair="salt", style="side_part", suit="navy", tie="teal", glasses=True, glasses_color="#7a5a2a", bg=BG[3]),
 "Alan Pryce": dict(skin=0, hair="brown", style="short", suit="navy", tie="red", bg=BG[0]),
 "Grace Whitfield": dict(skin=5, hair="black", style="long", suit="burgundy", top="blouse", earrings=True, bg=BG[2], lipstick=True),
 "Tomas Reyes": dict(skin=2, hair="black", style="short", suit="grey", tie="gold", facial="mustache", bg=BG[3]),
 "Hannah Cole": dict(skin=0, hair="auburn", style="bob", suit="teal", top="blouse", bg=BG[5], lipstick=True),
 "Marcus Bell": dict(skin=5, hair="black", style="bald", suit="charcoal", tie="green", facial="full", beard_color="salt", bg=BG[4], jaw=4),
 "Ingrid Sato": dict(skin=1, hair="black", style="bob", suit="black", top="turtleneck", glasses=True, bg=BG[6]),
 "Paul Navarro": dict(skin=2, hair="grey", style="side_part", suit="navy", tie="burgundy", age=1, bg=BG[1]),
 "Lena Kowalski": dict(skin=0, hair="blonde", style="long", suit="navy", top="blouse", blouse="#f0e6d8", earrings=True, bg=BG[3]),
 "Owen Marsh": dict(skin=0, hair="auburn", style="buzz", suit="camel", tie="navy", facial="beard", bg=BG[0]),
 "Priya Raman": dict(skin=3, hair="black", style="bun", suit="teal", top="blouse", earrings=True, bg=BG[1], lipstick=True),
 "Carl Dunmore": dict(skin=1, hair="white", style="bald", suit="grey", tie="red", facial="mustache", glasses=True, age=1, bg=BG[5]),
 "June Halvorsen": dict(skin=0, hair="white", style="short", suit="burgundy", top="blouse", age=1, bg=BG[2], earrings=True),
}

def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, p in PEOPLE.items():
        svg = portrait(p)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=f"{OUT}/{slug(name)}.png", output_width=256, output_height=256)
    print(len(PEOPLE), "portraits")

if __name__ == "__main__":
    main()
