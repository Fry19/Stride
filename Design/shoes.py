"""Generates the Stride shoe artwork: one running shoe per tier, plus a matching app icon.

    Design/build.sh    # generates the SVGs, renders them and copies them into the asset catalog

The shoe is drawn side-on, toe pointing right, in a 1000 x 640 box.
"""
import math
import random
import sys
from pathlib import Path

# --- Shoe geometry -----------------------------------------------------------

UPPER = (
    "M 100 412 C 86 340, 90 262, 118 204 "
    "C 132 178, 166 174, 192 190 "
    "C 228 212, 262 224, 302 212 "
    "C 318 200, 322 172, 342 160 "
    "C 362 149, 387 157, 392 176 "
    "C 397 196, 404 206, 424 216 "
    "C 524 262, 642 300, 762 334 "
    "C 852 358, 922 370, 946 394 "
    "C 956 404, 953 414, 944 418 "
    "L 940 452 L 100 452 Z"
)
MIDSOLE = (
    "M 96 384 C 140 392, 190 420, 300 428 "
    "C 480 440, 640 446, 800 433 "
    "C 880 426, 930 411, 951 398 "
    "C 966 410, 963 440, 940 456 "
    "C 870 495, 780 505, 600 505 "
    "L 190 505 C 128 504, 84 488, 80 452 "
    "C 77 424, 84 396, 96 384 Z"
)
# A sculpted line along the side of the midsole.
MIDSOLE_GROOVE = "M 110 452 C 200 470, 420 474, 620 470 C 760 466, 870 452, 930 430"
COLLAR = (
    "M 146 198 C 188 204, 242 226, 302 214 "
    "C 314 207, 319 194, 323 184 "
    "C 290 199, 232 197, 178 185 "
    "C 160 183, 148 189, 146 198 Z"
)
TONGUE = (
    "M 322 186 C 326 164, 346 149, 369 151 "
    "C 391 154, 397 175, 399 193 "
    "C 403 210, 421 222, 442 232 "
    "L 424 246 C 397 233, 361 216, 330 206 Z"
)
HEEL_COUNTER = (
    "M 100 412 C 86 340, 90 262, 116 210 "
    "C 156 238, 196 300, 214 418 Z"
)
TOE_CAP = (
    "M 768 336 C 852 358, 922 370, 946 394 "
    "C 956 404, 953 414, 944 418 L 778 420 "
    "C 760 392, 756 362, 768 336 Z"
)
STRIPE = (
    "M 214 352 C 330 300, 470 290, 610 334 "
    "C 640 344, 660 352, 676 362 "
    "C 540 330, 380 330, 222 378 Z"
)
STRIPE_THIN = (
    "M 236 392 C 360 352, 500 346, 640 380 "
    "C 520 362, 380 368, 240 404 Z"
)
HEEL_TAB = "M 114 210 C 104 188, 112 160, 138 162 L 156 186 Z"
# Points along the lacing, heel to toe.
LACE_POINTS = [(438, 226), (486, 248), (534, 268), (582, 286), (630, 302), (676, 316)]
EYESTAY = (
    "M 404 206 C 500 254, 620 292, 712 318 "
    "L 706 338 C 610 312, 492 274, 398 228 Z"
)


def lace_marks(color, width=11):
    marks = []
    for x, y in LACE_POINTS:
        marks.append(
            f'<path d="M {x - 22} {y - 6} Q {x - 2} {y - 22}, {x + 22} {y - 12}" '
            f'fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')
    return "\n".join(marks)


def eyelets(color):
    return "\n".join(
        f'<circle cx="{x + 4}" cy="{y + 12}" r="4.5" fill="{color}"/>' for x, y in LACE_POINTS)


def stitches(path, color="#000", opacity=0.22, offset=0):
    return (f'<path d="{path}" fill="none" stroke="{color}" stroke-opacity="{opacity}" '
            f'stroke-width="2.5" stroke-dasharray="7 7" transform="translate(0 {offset})"/>')


def outsole_bottom(x):
    """Approximate y of the outsole's bottom edge at x."""
    if x < 190:
        return 521 - ((190 - x) / 110) ** 2 * 50
    if x <= 600:
        return 521
    return 521 - ((x - 600) / 345) ** 1.8 * 52


def tread(color):
    """Chunky lugs along the outsole, for the trail shoe."""
    lugs = []
    for x in range(120, 930, 44):
        y = outsole_bottom(x + 12)
        lugs.append(f'<rect x="{x}" y="{y - 10:.0f}" width="26" height="20" rx="5" fill="{color}"/>')
    return "\n".join(lugs)


# --- Tiers -------------------------------------------------------------------

def gradient(id_, stops, x1=0, y1=0, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def radial(id_, stops, cx=0.5, cy=0.5, r=0.5):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


TIERS = [
    dict(n=1, name="Fresh Kicks",
         upper=[(0, "#FFFFFF"), (0.6, "#F1F1F4"), (1, "#D9D9DF")],
         overlay=[(0, "#FAFAFC"), (1, "#E2E2E8")],
         midsole=[(0, "#FFFFFF"), (1, "#E6E6EB")],
         outsole="#C9C9D0", lace="#E9E9EE", stripe="#E3E3E8", collar="#B9B9C2",
         tongue="#F4F4F7", tab="#D6D6DC",
         bg=[(0, "#2A2A2E"), (1, "#0E0E10")], glow="#FFFFFF"),
    dict(n=2, name="Laced Up",
         upper=[(0, "#FFFFFF"), (0.6, "#F2F4F8"), (1, "#DCE0E8")],
         overlay=[(0, "#FBFCFE"), (1, "#E4E8F0")],
         midsole=[(0, "#FFFFFF"), (1, "#E8EBF0")],
         outsole="#2F6BFF", lace="#2F6BFF", stripe="#2F6BFF", collar="#1D2C55",
         tongue="#F6F8FC", tab="#2F6BFF",
         bg=[(0, "#16234A"), (1, "#070B18")], glow="#4D84FF"),
    dict(n=3, name="Trail Blazer",
         upper=[(0, "#6E7C78"), (0.7, "#55625E"), (1, "#3E4845")],
         overlay=[(0, "#9AA7A2"), (1, "#7A8681")],
         midsole=[(0, "#F3EEE4"), (1, "#D8D0C0")],
         outsole="#2B2B2B", lace="#FF7A2E", stripe="#FF7A2E", collar="#2A302E",
         tongue="#7D8A85", tab="#FF7A2E", chunky=True,
         bg=[(0, "#1F3B33"), (1, "#08110E")], glow="#FF8A3D"),
    dict(n=4, name="Neon Rush",
         upper=[(0, "#1B1B24"), (1, "#0D0D14")],
         overlay=[(0, "#262636"), (1, "#14141F")],
         midsole=[(0, "#FF3DA8"), (0.5, "#B15CFF"), (1, "#3DE0FF")],
         outsole="#0A0A10", lace="#3DE0FF", stripe="url(#neon)", collar="#3DE0FF",
         tongue="#20202C", tab="#FF3DA8", neon=True,
         bg=[(0, "#2A0F45"), (1, "#07030F")], glow="#C24DFF"),
    dict(n=5, name="Carbon Racer",
         upper=[(0, "#2C2C30"), (1, "#141416")],
         overlay=[(0, "#1E1E21"), (1, "#0E0E10")],
         midsole=[(0, "#FF8A3D"), (1, "#E04E14")],
         outsole="#111113", lace="#FF6A1F", stripe="#FF6A1F", collar="#FF6A1F",
         tongue="#232326", tab="#FF6A1F", carbon=True,
         bg=[(0, "#2E1608"), (1, "#060303")], glow="#FF6A1F"),
    dict(n=6, name="Chrome",
         upper=[(0, "#FFFFFF"), (0.18, "#9EA6B2"), (0.32, "#F4F6FA"), (0.5, "#5E6673"),
                (0.68, "#DDE2EA"), (0.85, "#7C8492"), (1, "#C9CED7")],
         overlay=[(0, "#F7F9FC"), (0.4, "#8B93A0"), (0.7, "#E9EDF3"), (1, "#6F7785")],
         midsole=[(0, "#F2F4F8"), (0.5, "#AEB4BE"), (1, "#E3E6EC")],
         outsole="#3B404A", lace="#EEF1F6", stripe="url(#chromeStripe)", collar="#2C313A",
         tongue="#C7CCD5", tab="#E8EBF0", metal=True,
         bg=[(0, "#3B4656"), (1, "#0B0E13")], glow="#BFD3FF"),
    dict(n=7, name="Solid Gold",
         upper=[(0, "#FFF2B8"), (0.2, "#E7B53C"), (0.38, "#FFE58A"), (0.55, "#B98516"),
                (0.75, "#F5CF5B"), (1, "#9C6A0A")],
         overlay=[(0, "#FFF0B0"), (0.5, "#D9A532"), (1, "#A8740E")],
         midsole=[(0, "#FFFBEA"), (1, "#E9D9A6")],
         outsole="#5A3E06", lace="#FFF6D6", stripe="#FFF6D6", collar="#4A3305",
         tongue="#F1CB57", tab="#FFF6D6", metal=True,
         bg=[(0, "#3A2A05"), (1, "#0A0702")], glow="#FFD25A"),
    dict(n=8, name="Diamond",
         upper=[(0, "#E9F7FF"), (0.25, "#C9C2FF"), (0.45, "#FFD6F2"), (0.65, "#BDF4FF"),
                (0.85, "#D8FFE9"), (1, "#C8D6FF")],
         overlay=[(0, "#FFFFFF"), (0.5, "#D6E4FF"), (1, "#F2D9FF")],
         midsole=[(0, "#FFFFFF"), (1, "#DDE9FF")],
         outsole="#8EA2FF", lace="#FFFFFF", stripe="url(#holo)", collar="#6B5BD6",
         tongue="#EEF6FF", tab="#FFFFFF", sparkle=True, metal=True,
         bg=[(0, "#231B5C"), (1, "#05041A")], glow="#B9C8FF"),
    dict(n=9, name="Winged",
         upper=[(0, "#FFF6CC"), (0.25, "#F2C44A"), (0.45, "#FFE68F"), (0.65, "#C9921C"),
                (1, "#F7D46A")],
         overlay=[(0, "#FFFFFF"), (1, "#F1E3B8")],
         midsole=[(0, "#FFFFFF"), (1, "#F0E6C8")],
         outsole="#6B4A08", lace="#FFFFFF", stripe="#FFFFFF", collar="#5A2D82",
         tongue="#FFE9A6", tab="#FFFFFF", wings=True, metal=True,
         bg=[(0, "#3D1F66"), (1, "#0C0618")], glow="#FFD86B"),
    dict(n=10, name="Cosmic",
         upper=[(0, "#2B1F6B"), (0.5, "#140F3A"), (1, "#07051A")],
         overlay=[(0, "#3A2A8C"), (1, "#120C35")],
         midsole=[(0, "#7DF9FF"), (0.5, "#9C7BFF"), (1, "#FF6BD5")],
         outsole="#05030F", lace="#7DF9FF", stripe="url(#aurora)", collar="#FF6BD5",
         tongue="#241A5C", tab="#7DF9FF", galaxy=True, wings=True, flames=True, sparkle=True,
         bg=[(0, "#1A0B3D"), (1, "#020108")], glow="#8C6BFF"),
]


def sparkle(x, y, r, color="#FFFFFF", opacity=1.0):
    return (f'<path d="M {x} {y - r} Q {x + r * 0.16} {y - r * 0.16}, {x + r} {y} '
            f'Q {x + r * 0.16} {y + r * 0.16}, {x} {y + r} Q {x - r * 0.16} {y + r * 0.16}, {x - r} {y} '
            f'Q {x - r * 0.16} {y - r * 0.16}, {x} {y - r} Z" fill="{color}" opacity="{opacity}"/>')


def wing(fill):
    """A swept-back feathered wing on the side of the heel, like a messenger's sandal."""
    feathers = []
    rows = 6
    for i in reversed(range(rows)):  # bottom row first so the long top feathers overlap it
        angle = 206 - i * 7
        length = 300 - i * 34
        width = 40 - i * 2
        bx, by = 268 - i * 4, 248 + i * 19
        feathers.append(
            f'<rect x="0" y="{-width / 2}" width="{length}" height="{width}" rx="{width / 2}" '
            f'transform="translate({bx} {by}) rotate({angle})" fill="{fill}" '
            f'stroke="#000" stroke-opacity="0.16" stroke-width="2"/>')
    # The wing's leading edge and the rounded shoulder where it meets the shoe.
    edge = ('<path d="M 300 236 C 230 206, 120 170, 6 104 C 90 176, 200 232, 286 266 Z" '
            f'fill="{fill}" stroke="#000" stroke-opacity="0.16" stroke-width="2"/>')
    shoulder = (f'<path d="M 252 236 C 286 226, 318 250, 314 290 C 310 326, 280 346, 252 340 '
                f'C 236 310, 236 262, 252 236 Z" fill="{fill}" stroke="#000" stroke-opacity="0.16" stroke-width="2"/>')
    return "<g>" + "".join(feathers) + edge + shoulder + "</g>"


def flames():
    """Speed streaks of fire trailing back from the heel."""
    streaks = []
    for y, length, half in [(430, 130, 16), (468, 170, 26), (504, 115, 14)]:
        x = 100
        streaks.append(
            f'<path d="M {x} {y - half} C {x - length * 0.4} {y - half}, {x - length * 0.8} {y - half * 0.35}, '
            f'{x - length} {y} C {x - length * 0.8} {y + half * 0.35}, {x - length * 0.4} {y + half}, {x} {y + half} Z" '
            f'fill="url(#flame)"/>')
    return "<g>" + "".join(streaks) + "</g>"


def shoe_defs(t):
    defs = [
        gradient(f"upper{t['n']}", t["upper"], 0, 0, 1 if t.get("metal") else 0, 1),
        gradient(f"overlay{t['n']}", t["overlay"], 0, 0, 0.6, 1),
        gradient(f"midsole{t['n']}", t["midsole"], 0, 0, 1 if t.get("neon") or t.get("galaxy") else 0,
                 0 if t.get("neon") or t.get("galaxy") else 1),
        gradient("shade", [(0, "rgba(0,0,0,0)"), (0.65, "rgba(0,0,0,0)"), (1, "rgba(0,0,0,0.22)")]),
        gradient("sheen", [(0, "rgba(255,255,255,0.75)"), (1, "rgba(255,255,255,0)")]),
        gradient("neon", [(0, "#FF3DA8"), (0.5, "#B15CFF"), (1, "#3DE0FF")], 0, 0, 1, 0),
        gradient("chromeStripe", [(0, "#2C313A"), (0.5, "#6F7785"), (1, "#2C313A")], 0, 0, 1, 0),
        gradient("holo", [(0, "#FF9DE2"), (0.33, "#9DB8FF"), (0.66, "#9DFFE6"), (1, "#FFF39D")], 0, 0, 1, 0),
        gradient("aurora", [(0, "#7DF9FF"), (0.5, "#9C7BFF"), (1, "#FF6BD5")], 0, 0, 1, 0),
        gradient("wingGold", [(0, "#FFFFFF"), (0.5, "#FFF1C2"), (1, "#E9B949")], 1, 0, 0, 1),
        gradient("wingCosmic", [(0, "#FFFFFF"), (0.45, "#BFA8FF"), (1, "#5B3CC4")], 1, 0, 0, 1),
        '<linearGradient id="flame" x1="1" y1="0" x2="0" y2="0">'
        '<stop offset="0" stop-color="#FFF6B0"/><stop offset="0.3" stop-color="#FF9E3D"/>'
        '<stop offset="0.65" stop-color="#FF3D7A" stop-opacity="0.85"/>'
        '<stop offset="1" stop-color="#7A3DFF" stop-opacity="0"/></linearGradient>',
        f'<clipPath id="upperClip"><path d="{UPPER}"/></clipPath>',
        f'<clipPath id="midClip"><path d="{MIDSOLE}"/></clipPath>',
        '<pattern id="mesh" width="14" height="14" patternUnits="userSpaceOnUse">'
        '<circle cx="7" cy="7" r="2.2" fill="#000" fill-opacity="0.07"/></pattern>',
        '<pattern id="carbon" width="24" height="24" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
        '<rect width="12" height="12" fill="#2A2A2E"/><rect x="12" y="12" width="12" height="12" fill="#2A2A2E"/>'
        '<rect x="12" width="12" height="12" fill="#18181B"/><rect y="12" width="12" height="12" fill="#18181B"/>'
        '</pattern>',
        '<filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>',
        '<filter id="glowBlur" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="22"/></filter>',
    ]
    if t.get("galaxy"):
        defs.append(radial("nebula1", [(0, "#FF6BD5", 0.85), (1, "#FF6BD5", 0)], 0.35, 0.45, 0.35))
        defs.append(radial("nebula2", [(0, "#7DF9FF", 0.7), (1, "#7DF9FF", 0)], 0.7, 0.55, 0.3))
    return "<defs>" + "".join(defs) + "</defs>"


def shoe_body(t):
    """The shoe itself, without ground shadow or background."""
    n = t["n"]
    rng = random.Random(n)
    parts = []
    if t.get("glow_behind", True) and (t.get("neon") or t.get("galaxy") or t.get("sparkle")):
        parts.append(f'<path d="{UPPER}" fill="{t["glow"]}" opacity="0.55" filter="url(#glowBlur)"/>')
    if t.get("flames"):
        parts.append(flames())

    # Outsole shows as a strip under the midsole.
    if t.get("chunky"):
        parts.append(tread(t["outsole"]))
    parts.append(f'<path d="{MIDSOLE}" fill="{t["outsole"]}" transform="translate(0 16)"/>')

    # Upper.
    parts.append(f'<path d="{UPPER}" fill="url(#upper{n})"/>')
    if t.get("carbon"):
        parts.append(f'<path d="{UPPER}" fill="url(#carbon)" opacity="0.9"/>')
    if t.get("galaxy"):
        parts.append('<g clip-path="url(#upperClip)">'
                     '<rect x="80" y="140" width="900" height="300" fill="url(#nebula1)"/>'
                     '<rect x="80" y="140" width="900" height="300" fill="url(#nebula2)"/>')
        for _ in range(70):
            x, y = rng.uniform(100, 940), rng.uniform(160, 420)
            parts.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rng.uniform(0.8, 2.6):.1f}" '
                         f'fill="#FFFFFF" opacity="{rng.uniform(0.4, 1):.2f}"/>')
        parts.append("</g>")
    if not (t.get("metal") or t.get("galaxy") or t.get("carbon")):
        parts.append(f'<path d="{UPPER}" fill="url(#mesh)"/>')
    parts.append(f'<path d="{HEEL_COUNTER}" fill="url(#overlay{n})"/>')
    parts.append(f'<path d="{TOE_CAP}" fill="url(#overlay{n})"/>')
    parts.append(stitches(HEEL_COUNTER))
    parts.append(stitches(TOE_CAP))
    parts.append(f'<path d="{EYESTAY}" fill="url(#overlay{n})"/>')
    parts.append(f'<path d="{STRIPE}" fill="{t["stripe"]}"/>')
    parts.append(f'<path d="{STRIPE_THIN}" fill="{t["stripe"]}" opacity="0.75"/>')
    parts.append(f'<path d="{COLLAR}" fill="{t["collar"]}"/>')
    parts.append(f'<path d="{TONGUE}" fill="{t["tongue"]}"/>')
    parts.append(stitches(TONGUE, opacity=0.18))
    parts.append(f'<path d="{HEEL_TAB}" fill="{t["tab"]}"/>')
    parts.append(eyelets("#000000" if n != 4 else "#3DE0FF"))
    parts.append(lace_marks(t["lace"]))
    if t.get("wings"):
        parts.append(wing("url(#wingCosmic)" if t.get("galaxy") else "url(#wingGold)"))
    # Shading: darker toward the sole, a sheen across the top.
    parts.append(f'<path d="{UPPER}" fill="url(#shade)"/>')
    sheen = 0.18 if t.get("carbon") or t.get("galaxy") or t.get("neon") else 0.5
    parts.append('<g clip-path="url(#upperClip)">'
                 f'<ellipse cx="760" cy="350" rx="190" ry="26" fill="url(#sheen)" opacity="{sheen}" '
                 'transform="rotate(14 760 350)"/>'
                 f'<ellipse cx="250" cy="250" rx="120" ry="20" fill="url(#sheen)" opacity="{sheen * 0.7:.2f}" '
                 'transform="rotate(-24 250 250)"/></g>')

    # Midsole.
    parts.append(f'<path d="{MIDSOLE}" fill="url(#midsole{n})"/>')
    parts.append('<g clip-path="url(#midClip)">'
                 '<path d="M 96 388 C 140 396, 190 424, 300 432 C 480 444, 640 450, 800 437 '
                 'C 880 430, 930 415, 951 402" fill="none" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="5"/>'
                 f'<path d="{MIDSOLE_GROOVE}" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="4"/>'
                 '<rect x="70" y="478" width="900" height="50" fill="#000" opacity="0.08"/></g>')
    if t.get("neon"):
        parts.append(f'<path d="{MIDSOLE}" fill="none" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="2"/>')
        parts.append(f'<path d="{UPPER}" fill="none" stroke="url(#neon)" stroke-width="5"/>')
    if t.get("sparkle"):
        for x, y, r in [(300, 200, 26), (690, 260, 18), (880, 330, 22), (520, 380, 14), (180, 160, 16)]:
            parts.append(sparkle(x, y, r))
    return "\n".join(parts)


def shoe_svg(t):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-80 20 1100 600">'
            f'{shoe_defs(t)}{shoe_body(t)}</svg>')


def icon_svg(t):
    n = t["n"]
    rng = random.Random(100 + n)
    extras = []
    if t.get("galaxy") or t.get("sparkle"):
        for _ in range(60 if t.get("galaxy") else 24):
            x, y = rng.uniform(0, 1024), rng.uniform(0, 1024)
            extras.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rng.uniform(1, 3.4):.1f}" fill="#FFFFFF" '
                          f'opacity="{rng.uniform(0.25, 0.9):.2f}"/>')
    if n in (7, 9):  # rays behind gold shoes
        for i in range(16):
            a = i * math.pi / 8
            extras.append(f'<path d="M 512 520 L {512 + 900 * math.cos(a - 0.08):.0f} {520 + 900 * math.sin(a - 0.08):.0f} '
                          f'L {512 + 900 * math.cos(a + 0.08):.0f} {520 + 900 * math.sin(a + 0.08):.0f} Z" '
                          f'fill="{t["glow"]}" opacity="0.07"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
{shoe_defs(t)}
<defs>
  {gradient(f"bg{n}", t["bg"], 0, 0, 0.3, 1)}
  {radial(f"halo{n}", [(0, t["glow"], 0.55), (0.55, t["glow"], 0.12), (1, t["glow"], 0)], 0.5, 0.55, 0.5)}
</defs>
<rect width="1024" height="1024" fill="url(#bg{n})"/>
{"".join(extras)}
<circle cx="512" cy="560" r="470" fill="url(#halo{n})"/>
<ellipse cx="520" cy="770" rx="330" ry="26" fill="#000" opacity="0.45" filter="url(#soft)"/>
<g transform="translate(512 548) scale(0.82) translate(-520 -360)">
{shoe_body(t)}
</g>
</svg>'''


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for t in TIERS:
        (out / f"shoe-{t['n']}.svg").write_text(shoe_svg(t))
        (out / f"icon-{t['n']}.svg").write_text(icon_svg(t))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Design/build")
