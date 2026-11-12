# Every K6 diff against the prototype and the comparison sheets; run from .scratch/konclui/k6 (writes diffs.txt, compare/).
import subprocess, sys
from PIL import Image, ImageChops, ImageStat, ImageDraw
def stat(a, b):
    d = ImageChops.difference(a, b); m = sum(ImageStat.Stat(d).mean) / 3
    big = sum(1 for px in d.getdata() if max(px) > 25) / (a.width * a.height) * 100
    return m, big
out = ["K6 diffs against the prototype (koru.html with the owner's white eye discs; targets in target/). Random parts:",
       "busy hops and darting looks, sweat drops, minis' wandering look, the sleepy z's place."]
for n in ['busy','hot','busyhot','tired','asleep','full']:
    m, big = stat(Image.open(f'target/mood-{n}.png').convert('RGB'), Image.open(f'swift/mood-{n}.png').convert('RGB'))
    out.append(f"mood {n:8s} mean |diff| {m:5.2f}/255  pixels off by >25: {big:5.2f} %")
for n in ['mini-idle','mini-working']:
    m, big = stat(Image.open(f'target/{n}.png').convert('RGB'), Image.open(f'swift/{n}.png').convert('RGB'))
    out.append(f"{n:13s} mean |diff| {m:5.2f}/255  pixels off by >25: {big:5.2f} %")
for f, label in [('suck-film','suck film (upload sequence clock)'), ('gulp-film','gulp film (prototype has a file, the island none)'),
                 ('mini-happy-film','mini happy hop film'), ('mini-love-film','mini love film')]:
    r = subprocess.run([sys.executable, __import__('os').path.join(__import__('os').path.dirname(__file__), 'celldiff.py'), f'target/{f}.png', f'swift/{f}.png', '6', '300'], capture_output=True, text=True).stdout.strip().splitlines()[-1]
    out.append(f"{label}: {r}")
r = subprocess.run([sys.executable, __import__('os').path.join(__import__('os').path.dirname(__file__), 'celldiff.py'), 'target/mini-happy-film.png', 'swift/mini-happy-film-mochi-constants.png', '6', '300'], capture_output=True, text=True).stdout.strip().splitlines()[-1]
out.append(f"mini happy hop film with Mochi's constants (before K6): {r}")
open('diffs.txt', 'w').write("\n".join(out) + "\n"); print("\n".join(out))
names = ['busy','hot','busyhot','tired','asleep','full']
W = Image.new('RGB', (300*6, 620), (16,17,21)); d = ImageDraw.Draw(W)
for i, n in enumerate(names):
    W.paste(Image.open(f'target/mood-{n}.png').convert('RGB').resize((300,300), Image.LANCZOS), (300*i, 0))
    W.paste(Image.open(f'swift/mood-{n}.png').convert('RGB').resize((300,300), Image.LANCZOS), (300*i, 310))
    d.text((300*i+6, 4), 'prototype ' + n, fill=(220,220,220)); d.text((300*i+6, 314), 'app ' + n, fill=(220,220,220))
W.save('compare/mood-cmp.png')
W = Image.new('RGB', (1200, 300))
for i, p in enumerate(['target/mini-idle.png','swift/mini-idle.png','target/mini-working.png','swift/mini-working.png']): W.paste(Image.open(p).convert('RGB'), (300*i, 0))
W.save('compare/mini-stills.png')
