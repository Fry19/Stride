"""Generates Stride's level emblems: one mark, two forward-leaning strides, raised out of a
different material at each tier. The same artwork is the app icon and the in-app emblem.

    Design/build.sh    # generates the SVGs, renders them and copies them into the asset catalog
"""
import sys
from pathlib import Path

SIZE = 1024
# The mark: two capsules leaning forward, side by side, the right one a step ahead.
STRIDES = [(382, 552), (642, 478)]
STRIDE_LENGTH = 390
STRIDE_WIDTH = 156
LEAN = -24  # degrees


def stops(pairs):
    return "".join(
        f'<stop offset="{o}" stop-color="{c}"{"" if a == 1 else f" stop-opacity={chr(34)}{a}{chr(34)}"}/>'
        for o, c, *rest in pairs for a in [rest[0] if rest else 1])


def linear(id_, pairs, x1=0, y1=0, x2=0, y2=1):
    return f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops(pairs)}</linearGradient>'


def radial(id_, pairs, cx=0.5, cy=0.5, r=0.5):
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{stops(pairs)}</radialGradient>'


def capsule(cx, cy, attrs):
    return (f'<rect x="{cx - STRIDE_WIDTH / 2}" y="{cy - STRIDE_LENGTH / 2}" width="{STRIDE_WIDTH}" '
            f'height="{STRIDE_LENGTH}" rx="{STRIDE_WIDTH / 2}" transform="rotate({-LEAN} {cx} {cy})" {attrs}/>')


def mark(attrs):
    return "".join(capsule(x, y, attrs) for x, y in STRIDES)


# Each material: plate gradient, mark gradient, how shiny it is, and texture.
MATERIALS = [
    dict(n=1, name="Chalk", plate=[(0, "#F6F4F0"), (1, "#D9D5CC")], face=[(0, "#FFFFFF"), (1, "#E4E0D7")],
         shine=0.15, grain=0.09, shadow=0.20, rim=0.9),
    dict(n=2, name="Graphite", plate=[(0, "#4A4C52"), (1, "#1E1F23")], face=[(0, "#5C5F66"), (1, "#2A2C31")],
         shine=0.12, grain=0.10, shadow=0.55, rim=0.25),
    dict(n=3, name="Copper", plate=[(0, "#E7A27A"), (0.45, "#B8643A"), (1, "#7A3A1C")],
         face=[(0, "#F6C3A0"), (0.5, "#C8744A"), (1, "#8E4524")], shine=0.45, brushed=0.18, shadow=0.45, rim=0.6),
    dict(n=4, name="Bronze", plate=[(0, "#C9A26A"), (0.5, "#8C6634"), (1, "#4F3718")],
         face=[(0, "#E1BD86"), (0.5, "#9D763F"), (1, "#5E4220")], shine=0.4, brushed=0.18, shadow=0.5, rim=0.55),
    dict(n=5, name="Steel", plate=[(0, "#A9B1BB"), (0.5, "#6E7782"), (1, "#3D444D")],
         face=[(0, "#C8CED6"), (0.5, "#808994"), (1, "#4A525C")], shine=0.4, brushed=0.3, shadow=0.5, rim=0.6),
    dict(n=6, name="Silver", plate=[(0, "#FAFBFC"), (0.35, "#C5CAD1"), (0.65, "#EEF0F3"), (1, "#9AA1AA")],
         face=[(0, "#FFFFFF"), (0.5, "#D3D7DD"), (1, "#A7AEB7")], shine=0.6, brushed=0.14, shadow=0.35, rim=0.9),
    dict(n=7, name="Gold", plate=[(0, "#FCE7A6"), (0.35, "#D9A63C"), (0.65, "#F2CF6C"), (1, "#98680F")],
         face=[(0, "#FFF4CE"), (0.5, "#E4B44E"), (1, "#A8770F")], shine=0.6, brushed=0.1, shadow=0.45, rim=0.85),
    dict(n=8, name="Platinum", plate=[(0, "#F4F7FB"), (0.4, "#D3DAE4"), (0.7, "#EEF2F7"), (1, "#AEB8C6")],
         face=[(0, "#FFFFFF"), (0.5, "#E1E7EF"), (1, "#B9C3D1")], shine=0.7, brushed=0.08, shadow=0.3, rim=1.0),
    dict(n=9, name="Obsidian", plate=[(0, "#202029"), (1, "#060608")], face=[(0, "#6A6A84"), (0.35, "#22222C"), (1, "#060608")],
         shine=0.3, shadow=0.85, rim=0.9, edge=[(0, "#8FA2FF"), (0.5, "#C58BFF"), (1, "#FF8FC8")]),
    dict(n=10, name="Aurora", plate=[(0, "#0E2340"), (1, "#05060F")], face=[(0, "#FFFFFF"), (1, "#E9F2FF")],
         shine=0.3, shadow=0.5, rim=1.0, aurora=True),
]


def emblem_svg(m):
    n = m["n"]
    defs = [
        linear("plate", m["plate"], 0, 0, 0.35, 1),
        linear("face", m["face"], 0, 0, 0.3, 1),
        linear("shine", [(0, "#FFFFFF", 0), (0.3, "#FFFFFF", 0), (0.5, "#FFFFFF", m["shine"] * 0.7),
                         (0.7, "#FFFFFF", 0), (1, "#FFFFFF", 0)], 0, 0, 1, 1),
        linear("rim", [(0, "#FFFFFF", m["rim"]), (0.5, "#FFFFFF", 0), (1, "#000000", 0.25)], 0, 0, 0.2, 1),
        radial("vignette", [(0, "#000000", 0), (0.75, "#000000", 0), (1, "#000000", 0.28)], 0.5, 0.45, 0.75),
        radial("top", [(0, "#FFFFFF", 0.22), (1, "#FFFFFF", 0)], 0.3, 0.05, 0.7),
        '<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">'
        # A soft wide shadow plus a tight contact shadow, so the mark sits on the plate.
        f'<feGaussianBlur in="SourceAlpha" stdDeviation="22" result="wide"/><feOffset in="wide" dy="22" result="wideOff"/>'
        f'<feComponentTransfer in="wideOff" result="wideShadow"><feFuncA type="linear" slope="{m["shadow"]}"/></feComponentTransfer>'
        f'<feGaussianBlur in="SourceAlpha" stdDeviation="4" result="tight"/><feOffset in="tight" dy="5" result="tightOff"/>'
        f'<feComponentTransfer in="tightOff" result="tightShadow"><feFuncA type="linear" slope="{min(1, m["shadow"] * 1.3):.2f}"/></feComponentTransfer>'
        '<feMerge><feMergeNode in="wideShadow"/><feMergeNode in="tightShadow"/><feMergeNode in="SourceGraphic"/></feMerge></filter>',
        '<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="4"/>'
        '<feColorMatrix type="saturate" values="0"/></filter>',
        '<filter id="brushed"><feTurbulence type="fractalNoise" baseFrequency="0.0015 0.75" numOctaves="2" seed="9"/>'
        '<feColorMatrix type="saturate" values="0"/></filter>',
        f'<clipPath id="markClip">{mark("")}</clipPath>',
    ]
    if m.get("edge"):
        defs.append(linear("edge", m["edge"], 0, 0, 1, 1))
    if m.get("aurora"):
        defs.append(radial("a1", [(0, "#3DF5C8", 0.9), (1, "#3DF5C8", 0)], 0.2, 0.25, 0.6))
        defs.append(radial("a2", [(0, "#7B6CFF", 0.9), (1, "#7B6CFF", 0)], 0.85, 0.35, 0.55))
        defs.append(radial("a3", [(0, "#FF6FB5", 0.85), (1, "#FF6FB5", 0)], 0.55, 0.95, 0.55))
        defs.append(linear("glassEdge", [(0, "#FFFFFF", 0.95), (1, "#FFFFFF", 0.3)], 0, 0, 0, 1))

    body = ['<rect width="1024" height="1024" fill="url(#plate)"/>']
    if m.get("aurora"):
        body += ['<rect width="1024" height="1024" fill="url(#a1)"/>',
                 '<rect width="1024" height="1024" fill="url(#a2)"/>',
                 '<rect width="1024" height="1024" fill="url(#a3)"/>']
    if m.get("grain"):
        body.append(f'<rect width="1024" height="1024" filter="url(#grain)" opacity="{m["grain"]}"/>')
    if m.get("brushed"):
        body.append(f'<rect width="1024" height="1024" filter="url(#brushed)" opacity="{m["brushed"]}" '
                    'style="mix-blend-mode:overlay"/>')
    body.append('<rect width="1024" height="1024" fill="url(#top)"/>')
    body.append('<rect width="1024" height="1024" fill="url(#shine)"/>')

    # The raised mark.
    if m.get("aurora"):
        body.append(f'<g filter="url(#shadow)" opacity="0.96">{mark("fill=\'url(#face)\'")}</g>')
        body.append(f'<g opacity="0.5">{mark("fill=\'none\' stroke=\'url(#glassEdge)\' stroke-width=\'4\'")}</g>')
    else:
        body.append(f'<g filter="url(#shadow)">{mark("fill=\'url(#face)\'")}</g>')
        body.append(f'<g clip-path="url(#markClip)"><rect width="1024" height="1024" fill="url(#shine)"/></g>')
        body.append(f'<g>{mark("fill=\'none\' stroke=\'url(#rim)\' stroke-width=\'4\'")}</g>')
        body.append(f'<g>{mark("fill=\'none\' stroke=\'#000\' stroke-opacity=\'0.12\' stroke-width=\'1.5\'")}</g>')
        if m.get("brushed"):
            body.append(f'<g clip-path="url(#markClip)"><rect width="1024" height="1024" filter="url(#brushed)" '
                        f'opacity="{m["brushed"] * 0.8}" style="mix-blend-mode:overlay"/></g>')
    if m.get("edge"):
        body.append(f'<g>{mark("fill=\'none\' stroke=\'url(#edge)\' stroke-width=\'5\'")}</g>')
    body.append('<rect width="1024" height="1024" fill="url(#vignette)"/>')

    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>')


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for m in MATERIALS:
        (out / f"emblem-{m['n']}.svg").write_text(emblem_svg(m))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Design/build")
