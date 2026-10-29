#!/usr/bin/env python3
"""Build Koncluí's app icon and menu bar glyph from the sources in this folder.

  python3 design/konclui/icon/build_icons.py

- candidates/koru-icon-B-warm.png: the chosen full-bleed generated art (prompts.md). It is masked into the macOS plate (824 px
  rounded square centred on a 1024 canvas, 185 px corners, soft drop shadow) -> app-icon-1024.png, then downsampled
  (premultiplied Lanczos) to every size AppIcon.appiconset lists. 16 px is the hand-tuned pixel map below, since the
  downsample blurs Koru's eyes there.
- menubar.svg (2x, 3x) and menubar-1x.svg (pixel-snapped) render the MenuBarIcon template glyph, 24x18 pt.
- preview.png: the icon at 16/32/64/128/512 and the glyph on light and dark menu bars.

Needs Pillow, numpy and rsvg-convert (Homebrew librsvg).
"""
import json
import os
import subprocess

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ASSETS = os.path.join(ROOT, 'NotchBuddy', 'Assets.xcassets')
ART = os.path.join(HERE, 'candidates', 'koru-icon-B-warm.png')
MASTER = os.path.join(HERE, 'app-icon-1024.png')
GLYPH, GLYPH_1X = os.path.join(HERE, 'menubar.svg'), os.path.join(HERE, 'menubar-1x.svg')
PREVIEW = os.path.join(HERE, 'preview.png')

CANVAS, PLATE, RADIUS = 1024, 824, 185
ZOOM, LIFT = 1.06, 0.02         # crop of the art inside the plate: zoom >= 1, lift moves the art up (fraction of its side)
SS = 4                          # supersampling of the plate mask

# 16 px icon, one character per pixel. Plate edges (columns/rows 1 and 14) are cut by the plate mask.
SMALL_16 = [
    "................",
    ".cccccccccccccc.",
    ".cccccccccccccc.",
    ".ctcccccccccctc.",
    ".cttcttttttcttc.",
    ".ctbbbbbbbbbbtc.",
    ".bbllllddllllbb.",
    ".blloolllloollb.",
    ".wloppolloppolw.",
    ".wloppolloppolw.",
    ".wlloolkkloollw.",
    ".wwllllKKllllww.",
    ".wwdddyyyydddww.",
    ".ddddyyyyyydddd.",
    ".ddddyyyyyydddd.",
    "................",
]
SMALL_COLORS = {
    't': '#2FB3C6',   # tufts, top of the head
    'b': '#1A9DB1',   # body
    'd': '#12889A',   # lower body
    'w': '#0E6676',   # wings
    'l': '#46C3D1',   # facial disc
    'o': '#FEA92D',   # eyes
    'p': '#0F4652',   # pupils
    'k': '#F59B2A',   # beak
    'K': '#D97A1C',   # beak tip
    'y': '#5CCAD6',   # belly
}
BG_TOP, BG_BOTTOM = (0xFD, 0xF1, 0xDA), (0xFD, 0xCB, 0x7D)   # the art's cream -> apricot plate


def plate_mask(size=CANVAS):
    k = size / CANVAS
    big = Image.new('L', (size * SS, size * SS), 0)
    o, p, r = (CANVAS - PLATE) / 2 * k * SS, PLATE * k * SS, RADIUS * k * SS
    ImageDraw.Draw(big).rounded_rectangle((o, o, o + p - 1, o + p - 1), radius=r, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def framed(content, size=CANVAS):
    """Plate content (RGB, size x size, the plate area filled) -> rounded plate with its drop shadow."""
    mask = plate_mask(size)
    layer = content.convert('RGBA')
    layer.putalpha(mask)
    k = size / CANVAS
    shadow_mask = plate_mask(CANVAS)
    shadow_mask = ImageChops.offset(shadow_mask, 0, 12).filter(ImageFilter.GaussianBlur(16)).point(lambda v: v * 0.42)
    shadow = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow.putalpha(shadow_mask)
    if k != 1:
        shadow = downsample(shadow, size)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(layer)
    return out


def compose(art, zoom=ZOOM, lift=LIFT):
    """Full-bleed art -> 1024 icon."""
    art = art.convert('RGB')
    side = min(art.size)
    crop = side / zoom
    cx, cy = art.width / 2, art.height / 2 - lift * side
    art = art.crop((round(cx - crop / 2), round(cy - crop / 2), round(cx + crop / 2), round(cy + crop / 2)))
    content = Image.new('RGB', (CANVAS, CANVAS))
    content.paste(art.resize((PLATE, PLATE), Image.LANCZOS), ((CANVAS - PLATE) // 2,) * 2)
    return framed(content)


def downsample(image, px):
    """Lanczos in premultiplied alpha (no dark fringes at the plate edge), light unsharp at small sizes."""
    rgba = np.asarray(image.convert('RGBA')).astype(np.float64)
    alpha = rgba[..., 3:] / 255.0
    pm = Image.fromarray(np.clip(rgba[..., :3] * alpha, 0, 255).round().astype(np.uint8), 'RGB')
    pm = pm.resize((px, px), Image.LANCZOS)
    a = image.convert('RGBA').getchannel('A').resize((px, px), Image.LANCZOS)
    if px <= 64:
        pm = pm.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=0))
    av = np.asarray(a).astype(np.float64)[..., None]
    with np.errstate(divide='ignore', invalid='ignore'):
        rgb = np.where(av > 0, np.asarray(pm).astype(np.float64) * 255.0 / av, 0)
    out = Image.fromarray(np.clip(rgb, 0, 255).round().astype(np.uint8), 'RGB')
    out.putalpha(a)
    return out


def small_16():
    content = Image.new('RGB', (16, 16))
    for y, row in enumerate(SMALL_16):
        assert len(row) == 16
        t = min(max((y - 1) / 13, 0), 1)
        bg = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
        for x, ch in enumerate(row):
            hexc = SMALL_COLORS.get(ch)
            content.putpixel((x, y), tuple(int(hexc[i:i + 2], 16) for i in (1, 3, 5)) if hexc else bg)
    return framed(content, 16)


def app_icon_files(master):
    folder = os.path.join(ASSETS, 'AppIcon.appiconset')
    with open(os.path.join(folder, 'Contents.json')) as f:
        spec = json.load(f)
    for img in spec['images']:
        px = int(img['size'].split('x')[0]) * int(img['scale'].rstrip('x'))
        yield os.path.join(folder, img['filename']), (small_16() if px == 16 else downsample(master, px))


def write_menu_glyph():
    folder = os.path.join(ASSETS, 'MenuBarIcon.imageset')
    with open(os.path.join(folder, 'Contents.json')) as f:
        spec = json.load(f)
    for img in spec['images']:
        s = int(img['scale'].rstrip('x'))
        subprocess.run(['rsvg-convert', '-w', str(24 * s), '-h', str(18 * s),
                        '-o', os.path.join(folder, img['filename']), GLYPH_1X if s == 1 else GLYPH], check=True)


def tinted(glyph, rgb):
    out = Image.new('RGBA', glyph.size, rgb + (255,))
    out.putalpha(glyph.getchannel('A'))
    return out


def write_preview(master):
    """Light half on top, dark half below: icon sizes (and 16/32 zoomed), then the glyph in a menu bar at 1x/2x."""
    icons = {px: (small_16() if px == 16 else downsample(master, px)) for px in (16, 32, 64, 128, 512)}
    g1 = Image.open(os.path.join(ASSETS, 'MenuBarIcon.imageset', 'menubar.png')).convert('RGBA')
    g2 = Image.open(os.path.join(ASSETS, 'MenuBarIcon.imageset', 'menubar@2x.png')).convert('RGBA')
    width, half = 1320, 660
    sheet = Image.new('RGB', (width, half * 2), (0, 0, 0))
    themes = (((246, 246, 248), (233, 233, 236), (0, 0, 0), (30, 30, 34)),
              ((30, 30, 34), (44, 44, 48), (255, 255, 255), (230, 230, 232)))
    for i, (bg, bar, ink, text) in enumerate(themes):
        top = i * half
        panel = Image.new('RGBA', (width, half), bg + (255,))
        x = 30
        for px in (16, 32, 64, 128, 512):
            panel.alpha_composite(icons[px], (x, 40 + (512 - px) // 2))
            x += px + 30
        # 16 and 32 at 8x, nearest, to check the pixels
        panel.alpha_composite(icons[16].resize((128, 128), Image.NEAREST), (x, 40))
        panel.alpha_composite(icons[32].resize((128, 128), Image.NEAREST), (x, 40 + 160))
        # menu bar strips: 2x (Retina, 24 pt bar = 48 px) and 1x, plus the blue update hint
        sy = 40 + 512 + 10
        strip = Image.new('RGBA', (width - 60, 76), bar + (255,))
        strip.alpha_composite(tinted(g2, ink), (20, 20))
        strip.alpha_composite(tinted(g2, (0x3B, 0x82, 0xF6)), (90, 20))
        strip.alpha_composite(tinted(g1, ink), (170, 29))
        strip.alpha_composite(tinted(g1, ink).resize((96, 72), Image.NEAREST), (230, 2))
        ImageDraw.Draw(strip).text((350, 32), 'menu bar: 2x, 2x update hint, 1x, 1x zoomed', fill=text + (255,))
        panel.alpha_composite(strip, (30, sy))
        sheet.paste(panel.convert('RGB'), (0, top))
    sheet.save(PREVIEW, optimize=True)


if __name__ == '__main__':
    master = compose(Image.open(ART))
    master.save(MASTER, optimize=True)
    for path, icon in app_icon_files(master):
        icon.save(path, optimize=True)
    write_menu_glyph()
    write_preview(master)
