#!/usr/bin/env python3
"""Original UI icons and emblem, drawn as SVG and rasterised with cairosvg. White on transparent; tinted in-game."""
import cairosvg, math

S = 'stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"'
ICONS = {
 "diplomacy": f'<path d="M10 26 C10 16 18 10 30 10 C42 10 50 16 50 26 C50 36 42 42 30 42 L22 42 L14 50 L15 40 C11 37 10 32 10 26 Z" {S}/><path d="M22 26 h16" {S}/>',
 "economic": f'<circle cx="32" cy="32" r="22" {S}/><path d="M39 23 C36 20 26 19 25 25 C24 31 40 30 39 38 C38 44 28 44 24 40 M32 16 v6 M32 42 v6" {S}/>',
 "military": f'<path d="M32 8 L52 16 L52 32 C52 44 43 52 32 56 C21 52 12 44 12 32 L12 16 Z" {S}/><path d="M32 22 L35 30 L43 30 L37 35 L39 43 L32 38 L25 43 L27 35 L21 30 L29 30 Z" fill="#fff"/>',
 "covert": f'<path d="M6 32 C14 20 22 15 32 15 C42 15 50 20 58 32 C50 44 42 49 32 49 C22 49 14 44 6 32 Z" {S}/><circle cx="32" cy="32" r="8" fill="#fff"/>',
 "approval": f'<circle cx="32" cy="20" r="9" {S}/><path d="M14 54 C14 40 22 33 32 33 C42 33 50 40 50 54" {S}/>',
 "pc": f'<path d="M36 6 L14 36 L30 36 L26 58 L50 26 L34 26 Z" fill="#fff"/>',
 "congress": f'<path d="M12 52 h40 M16 52 v-16 M24 52 v-16 M32 52 v-16 M40 52 v-16 M48 52 v-16 M12 36 h40 M16 36 C16 24 24 16 32 16 C40 16 48 24 48 36 M32 16 v-8" {S}/>',
 "scandal": f'<rect x="10" y="12" width="44" height="40" rx="4" {S}/><path d="M18 22 h28 M18 30 h12 M18 38 h12 M18 46 h28" {S}/><rect x="34" y="28" width="12" height="12" fill="#fff"/>',
 "deficit": f'<path d="M10 14 L24 30 L34 22 L54 46" {S}/><path d="M42 46 h12 v-12" {S}/>',
 "standing": f'<circle cx="32" cy="32" r="22" {S}/><path d="M10 32 h44 M32 10 C22 20 22 44 32 54 M32 10 C42 20 42 44 32 54" {S}/>',
 "election": f'<rect x="12" y="28" width="40" height="24" rx="3" {S}/><path d="M24 28 L28 8 L44 12 L40 28" {S}/><path d="M22 40 h20" {S}/>',
 "score": f'<path d="M32 8 L39 24 L56 25 L43 36 L47 53 L32 44 L17 53 L21 36 L8 25 L25 24 Z" fill="#fff"/>',
 "date": f'<rect x="10" y="14" width="44" height="40" rx="5" {S}/><path d="M10 26 h44 M22 8 v10 M42 8 v10" {S}/>',
 "speaker_on": f'<path d="M10 24 h10 l14 -12 v40 l-14 -12 h-10 z" fill="#fff"/><path d="M42 22 C47 27 47 37 42 42 M48 16 C57 25 57 39 48 48" {S}/>',
 "speaker_off": f'<path d="M10 24 h10 l14 -12 v40 l-14 -12 h-10 z" fill="#fff"/><path d="M42 24 l14 16 M56 24 l-14 16" {S}/>',
 "settings": f'<circle cx="32" cy="32" r="9" {S}/><path d="M32 6 v8 M32 50 v8 M6 32 h8 M50 32 h8 M13 13 l6 6 M45 45 l6 6 M13 51 l6 -6 M45 19 l6 -6" {S}/>',
 "war": f'<path d="M12 12 L52 52 M52 12 L12 52" {S}/><path d="M12 22 L22 12 M42 12 L52 22" {S}/>',
}

def emblem():
    stars = ""
    for i in range(13):
        a = -math.pi / 2 + i * 2 * math.pi / 13
        x, y = 128 + 96 * math.cos(a), 128 + 96 * math.sin(a)
        stars += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.5" fill="#e0a43a"/>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
<defs><radialGradient id="g" cx="50%" cy="40%" r="60%"><stop offset="0" stop-color="#1d2b46"/><stop offset="1" stop-color="#0b1220"/></radialGradient></defs>
<circle cx="128" cy="128" r="122" fill="url(#g)" stroke="#e0a43a" stroke-width="5"/>
<circle cx="128" cy="128" r="108" fill="none" stroke="#e0a43a" stroke-width="1.5" opacity=".6"/>
{stars}
<circle cx="128" cy="128" r="62" fill="none" stroke="#e0a43a" stroke-width="4"/>
<path d="M66 128 h124 M128 66 C100 92 100 164 128 190 M128 66 C156 92 156 164 128 190 M76 100 C110 108 146 108 180 100 M76 156 C110 148 146 148 180 156" stroke="#e0a43a" stroke-width="3" fill="none" opacity=".75"/>
<path d="M128 104 L134 120 L151 120 L137 130 L142 147 L128 137 L114 147 L119 130 L105 120 L122 120 Z" fill="#f2d28c"/>
</svg>'''

for name, body in ICONS.items():
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">{body}</svg>'
    cairosvg.svg2png(bytestring=svg.encode(), write_to=f"assets/icons/{name}.png", output_width=64, output_height=64)
cairosvg.svg2png(bytestring=emblem().encode(), write_to="assets/ui/emblem.png", output_width=512, output_height=512)
cairosvg.svg2png(bytestring=emblem().encode(), write_to="icon.png", output_width=512, output_height=512)
print(len(ICONS), "icons + emblem")
