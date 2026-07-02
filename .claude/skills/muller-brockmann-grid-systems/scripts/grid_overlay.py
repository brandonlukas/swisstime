#!/usr/bin/env python3
"""
grid_overlay.py — Müller-Brockmann grid geometry + visible overlay, any medium.

One source of truth (cols / gutter / margins / baseline / leading on a given
canvas) drives BOTH the content placement coordinates AND a visible grid
overlay — so the overlay's columns ARE the content's columns by construction
(this is the cross-medium version of the web "overlay must share the content
box" rule). Works for:

  • SVG posters/flyers/exhibition panels  -> a <g id="grid-guides"> overlay LAYER
    you drop on top of the artwork and show/hide (or delete for the final).
  • Web editorial pages                   -> the :root tokens + .guides overlay
    CSS + toggle JS + runtime optical-alignment JS (--web).

Plus helpers for the two subtle bits the web version got right:
  • PLACEMENT geometry as JSON (--geo): exact column x/width and baseline y, so
    every element is placed by line, never eyeballed.
  • OPTICAL ALIGNMENT for SVG <text> (--optical): a big display glyph's INK is
    inset by its left side-bearing, so a headline whose x is on the column line
    still looks indented. Given a font file we compute the side-bearing and
    return the x that puts the visible INK on the line (needs fontTools; if
    absent we explain the browser/runtime path).

No network, no credentials. Deterministic.

Canvas: give --w/--h in px, OR a DIN preset (--size A2 [--landscape] --dpi 150).

Examples:
  python3 grid_overlay.py --size A2 --dpi 150 --cols 6 --geo
  python3 grid_overlay.py --size A2 --dpi 150 --cols 6 --svg-overlay > guides.svg
  python3 grid_overlay.py --size A2 --dpi 150 --cols 6 --standalone > demo.svg
  python3 grid_overlay.py --w 1296 --h 1800 --cols 12 --web
  python3 grid_overlay.py --optical --font Inter.ttf --fontsize 180 --text "Helvetica" --targetx 144
"""
import argparse, json, sys

DIN_MM = {  # portrait, millimetres
    "A0": (841, 1189), "A1": (594, 841), "A2": (420, 594), "A3": (297, 420),
    "A4": (210, 297), "A5": (148, 210), "A6": (105, 148),
}

ACCENT = "#e4002b"

def canvas_px(cfg):
    if cfg.size:
        mm = DIN_MM[cfg.size.upper()]
        w_mm, h_mm = (mm[1], mm[0]) if cfg.landscape else mm
        f = cfg.dpi / 25.4
        return round(w_mm * f), round(h_mm * f)
    if not (cfg.w and cfg.h):
        sys.exit("error: give --w and --h, or a DIN --size (e.g. --size A2 --dpi 150)")
    return cfg.w, cfg.h

def geometry(cfg):
    """Single source of truth: derive every grid line once."""
    W, H = canvas_px(cfg)
    ml = cfg.margin_left if cfg.margin_left is not None else cfg.margin
    mr = cfg.margin_right if cfg.margin_right is not None else cfg.margin
    mt = cfg.margin_top if cfg.margin_top is not None else cfg.margin
    mb = cfg.margin_bottom if cfg.margin_bottom is not None else cfg.margin
    content_w = W - ml - mr
    content_h = H - mt - mb
    col_w = (content_w - (cfg.cols - 1) * cfg.gutter) / cfg.cols
    columns = []
    for i in range(cfg.cols):
        left = ml + i * (col_w + cfg.gutter)
        columns.append({"i": i + 1, "left": round(left, 2),
                        "right": round(left + col_w, 2), "width": round(col_w, 2)})
    bl = cfg.baseline
    lh = bl * cfg.leading_mult
    # baseline lines down from the top margin, within the content height
    n_minor = int(content_h // bl)
    baselines = [round(mt + k * bl, 2) for k in range(n_minor + 1)]
    majors = [round(mt + k * lh, 2) for k in range(int(content_h // lh) + 1)]
    return {
        "canvas": {"w": W, "h": H},
        "margins": {"left": ml, "right": mr, "top": mt, "bottom": mb},
        "cols": cfg.cols, "gutter": cfg.gutter, "colWidth": round(col_w, 2),
        "baseline": bl, "leading": lh,
        "columns": columns, "baselines": baselines, "majorLines": majors,
        "accent": cfg.accent,
    }

def svg_overlay(g, inner_only=False):
    """A <g id='grid-guides'> layer drawn from the geometry. Drop it as the TOP
    child of any SVG with the same width/height; toggle by show/hide; delete for
    the final. Because it reads the same geometry as your placed content, its
    columns ARE the content columns."""
    a = g["accent"]
    W, H = g["canvas"]["w"], g["canvas"]["h"]
    m = g["margins"]
    parts = ['<g id="grid-guides" class="grid-guides" '
             'inkscape:label="grid-guides" inkscape:groupmode="layer" '
             'style="pointer-events:none">']
    # column fields + numbers
    for c in g["columns"]:
        parts.append(
            f'<rect x="{c["left"]}" y="{m["top"]}" width="{c["width"]}" '
            f'height="{H-m["top"]-m["bottom"]}" fill="{a}" fill-opacity="0.075" '
            f'stroke="{a}" stroke-opacity="0.40" stroke-width="1"/>')
        cx = c["left"] + c["width"] / 2
        parts.append(
            f'<text x="{round(cx,2)}" y="{m["top"]+22}" fill="{a}" '
            f'font-family="monospace" font-size="11" text-anchor="middle">{c["i"]}</text>')
    # baseline: minor every bl, major every leading
    major = set(g["majorLines"])
    for y in g["baselines"]:
        is_major = y in major
        parts.append(
            f'<line x1="{m["left"]}" y1="{y}" x2="{W-m["right"]}" y2="{y}" '
            f'stroke="#00968c" stroke-opacity="{0.34 if is_major else 0.12}" stroke-width="1"/>')
    # margin lines
    for x in (m["left"], W - m["right"]):
        parts.append(f'<line x1="{x}" y1="0" x2="{x}" y2="{H}" '
                     f'stroke="{a}" stroke-opacity="0.40" stroke-width="1"/>')
    for y in (m["top"], H - m["bottom"]):
        parts.append(f'<line x1="0" y1="{y}" x2="{W}" y2="{y}" '
                     f'stroke="{a}" stroke-opacity="0.40" stroke-width="1"/>')
    parts.append("</g>")
    body = "\n".join(parts)
    if inner_only:
        return body
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
            f'width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n{body}\n</svg>')

def standalone(g):
    """A full SVG: white paper + a sample headline placed on column line 1 +
    the overlay on top, so you can render it and SEE the system immediately."""
    W, H = g["canvas"]["w"], g["canvas"]["h"]
    c1 = g["columns"][0]
    base = g["majorLines"][2] if len(g["majorLines"]) > 2 else g["margins"]["top"]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
            f'width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n'
            f'<text x="{c1["left"]}" y="{base}" fill="#111315" '
            f'font-family="Helvetica, Arial, sans-serif" font-weight="700" '
            f'font-size="{g["leading"]*5}" '
            f'>Grid</text>\n'
            f'<!-- NOTE: nudge that x left by the first glyph side-bearing for true optical alignment (see the optical helper) -->\n'
            f'{svg_overlay(g, inner_only=True)}\n</svg>')

def web_scaffold(g):
    """Preserve the web capability: :root tokens + .guides overlay (same content
    box) + toggle (button + G key) + runtime optical-alignment JS."""
    bl, lh = g["baseline"], g["leading"]
    css = f""":root{{
  --cols:{g['cols']}; --bl:{bl}px; --lh:{lh}px;
  --gutter:{g['gutter']}px; --margin:{g['margins']['left']}px; --maxw:{g['canvas']['w']}px;
  --paper:#fff; --ink:#111315; --accent:{g['accent']};
}}
*{{box-sizing:border-box;}}
body{{margin:0;background:var(--paper);color:var(--ink);font-family:"Inter",system-ui,sans-serif;line-height:var(--lh);}}
.wrap{{position:relative;max-width:var(--maxw);margin:0 auto;padding:var(--lh) var(--margin);}}
.grid{{display:grid;grid-template-columns:repeat(var(--cols),1fr);column-gap:var(--gutter);row-gap:var(--lh);}}
.band{{grid-column:1 / -1;display:grid;grid-template-columns:subgrid;column-gap:var(--gutter);align-items:start;}}
@supports not (grid-template-columns:subgrid){{.band{{grid-template-columns:repeat(var(--cols),1fr);}}}}
.guides{{position:absolute;inset:0;pointer-events:none;opacity:0;transition:opacity .26s;}}
body.grid-on .guides{{opacity:1;}}
.guides .cols{{position:absolute;top:0;bottom:0;left:var(--margin);right:var(--margin);
  display:grid;grid-template-columns:repeat(var(--cols),1fr);column-gap:var(--gutter);}}
.guides .col{{background:rgba(228,0,43,.075);box-shadow:inset 1px 0 0 rgba(228,0,43,.4),inset -1px 0 0 rgba(228,0,43,.4);}}
.guides .rows{{position:absolute;left:var(--margin);right:var(--margin);top:var(--lh);bottom:0;
  background-image:repeating-linear-gradient(to bottom,rgba(0,150,140,.34) 0 1px,transparent 1px var(--lh)),
    repeating-linear-gradient(to bottom,rgba(0,150,140,.12) 0 1px,transparent 1px var(--bl));}}
.toggle{{position:fixed;top:18px;right:18px;background:var(--ink);color:#fff;border:0;cursor:pointer;
  font-family:monospace;font-size:12px;letter-spacing:.14em;text-transform:uppercase;padding:11px 14px;}}
body.grid-on .toggle{{background:var(--accent);}}"""
    js = """var btn=document.getElementById('gridToggle');
function setGrid(o){document.body.classList.toggle('grid-on',o);if(btn){var l=btn.querySelector('.lbl');if(l)l.textContent=o?'Hide grid':'Show grid';}}
if(btn)btn.addEventListener('click',function(){setGrid(!document.body.classList.contains('grid-on'));});
document.addEventListener('keydown',function(e){if((e.key==='g'||e.key==='G')&&!e.metaKey&&!e.ctrlKey)setGrid(!document.body.classList.contains('grid-on'));});
document.querySelectorAll('.guides .cols').forEach(function(h){var n=parseInt(getComputedStyle(document.documentElement).getPropertyValue('--cols'),10)||12;for(var i=0;i<n;i++){var d=document.createElement('div');d.className='col';h.appendChild(d);}});
/* OPTICAL ALIGNMENT: put display INK (not its box) on the column line */
(function(){var cv=document.createElement('canvas'),cx=cv.getContext('2d');
function align(){document.querySelectorAll('.masthead,.numeral,.shead h2,.h2b').forEach(function(el){el.style.marginLeft='0px';
  var s=getComputedStyle(el),ch=(el.textContent||'').trim().charAt(0);if(!ch)return;if(s.textTransform==='uppercase')ch=ch.toUpperCase();
  cx.font=s.fontStyle+' '+s.fontWeight+' '+s.fontSize+' '+s.fontFamily;cx.textAlign='left';
  var abl=cx.measureText(ch).actualBoundingBoxLeft;if(isFinite(abl))el.style.marginLeft=abl.toFixed(2)+'px';});}
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(align);align();
var t;addEventListener('resize',function(){clearTimeout(t);t=setTimeout(align,120);});})();"""
    return (f"<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"UTF-8\">\n"
            f"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n"
            f"<link href=\"https://fonts.googleapis.com/css2?family=Inter:wght@400;700;900&family=Space+Mono&display=swap\" rel=\"stylesheet\">\n"
            f"<style>\n{css}\n</style></head>\n<body>\n"
            f"<button class=\"toggle\" id=\"gridToggle\"><span class=\"lbl\">Show grid</span></button>\n"
            f"<section style=\"position:relative\"><div class=\"wrap\">\n"
            f"  <div class=\"grid\"><div class=\"band\"><h1 class=\"masthead\" style=\"grid-column:1 / -1\">Headline</h1></div></div>\n"
            f"  <div class=\"guides\"><div class=\"cols\"></div><div class=\"rows\"></div></div>\n"
            f"</div></section>\n<script>\n{js}\n</script>\n</body></html>")

def optical_x(cfg):
    """Return the SVG <text> x that puts the first glyph's visible INK on
    --targetx, by subtracting its left side-bearing (font-specific)."""
    try:
        from fontTools.ttLib import TTFont
    except Exception:
        sys.exit("optical alignment needs fontTools: pip install fonttools\n"
                 "(In a browser you can instead measure el.getBBox()/canvas "
                 "actualBoundingBoxLeft on the LOADED font and shift x by it.)")
    try:
        font = TTFont(cfg.font, fontNumber=0)   # fontNumber picks face 0 in a .ttc
    except TypeError:
        font = TTFont(cfg.font)
    upm = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    ch = cfg.text.strip()[0]
    if cfg.upper:
        ch = ch.upper()
    gname = cmap.get(ord(ch))
    if gname is None:
        sys.exit(f"glyph for {ch!r} not found in {cfg.font}")
    adv, lsb = font["hmtx"][gname]            # left side-bearing in font units
    lsb_px = lsb / upm * cfg.fontsize
    x = cfg.targetx - lsb_px                   # pen x so ink-left lands on targetx
    return {"char": ch, "lsb_px": round(lsb_px, 2),
            "targetx": cfg.targetx, "text_x": round(x, 2)}

def main():
    ap = argparse.ArgumentParser(description="Müller-Brockmann grid geometry + overlay (SVG / web)")
    ap.add_argument("--w", type=int); ap.add_argument("--h", type=int)
    ap.add_argument("--size", help="DIN preset: A0..A6"); ap.add_argument("--dpi", type=float, default=150)
    ap.add_argument("--landscape", action="store_true")
    ap.add_argument("--cols", type=int, default=12)
    ap.add_argument("--gutter", type=float, default=24)
    ap.add_argument("--margin", type=float, default=72)
    ap.add_argument("--margin-left", type=float); ap.add_argument("--margin-right", type=float)
    ap.add_argument("--margin-top", type=float); ap.add_argument("--margin-bottom", type=float)
    ap.add_argument("--baseline", type=float, default=8)
    ap.add_argument("--leading-mult", type=int, default=3, help="leading = baseline x this")
    ap.add_argument("--accent", default=ACCENT)
    # outputs
    ap.add_argument("--geo", action="store_true", help="print geometry JSON")
    ap.add_argument("--svg-overlay", action="store_true", help="emit a <g> overlay layer SVG")
    ap.add_argument("--standalone", action="store_true", help="emit a full demo SVG with overlay")
    ap.add_argument("--web", action="store_true", help="emit a web scaffold (tokens+overlay+toggle+optical JS)")
    # optical helper
    ap.add_argument("--optical", action="store_true")
    ap.add_argument("--font"); ap.add_argument("--fontsize", type=float, default=180)
    ap.add_argument("--text", default="H"); ap.add_argument("--targetx", type=float, default=0)
    ap.add_argument("--upper", action="store_true")
    cfg = ap.parse_args()

    if cfg.optical:
        print(json.dumps(optical_x(cfg), indent=2)); return
    for nm, v in (("gutter", cfg.gutter), ("margin", cfg.margin)):
        if v % cfg.baseline != 0:
            print(f"# WARNING: --{nm} ({v}) is not a multiple of --baseline ({cfg.baseline}); "
                  f"vertical rhythm will drift.", file=sys.stderr)
    g = geometry(cfg)
    if cfg.web:        print(web_scaffold(g))
    elif cfg.standalone: print(standalone(g))
    elif cfg.svg_overlay: print(svg_overlay(g))
    else:              print(json.dumps(g, indent=2))   # --geo / default

if __name__ == "__main__":
    main()
