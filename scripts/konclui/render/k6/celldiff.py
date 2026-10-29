# celldiff.py target.png swift.png cols cell [caption] -> mean |diff| per cell (cell x cell px, caption strip below each)
import sys
from PIL import Image, ImageChops, ImageStat
t, s = Image.open(sys.argv[1]).convert('RGB'), Image.open(sys.argv[2]).convert('RGB')
cols, cell = int(sys.argv[3]), int(sys.argv[4]); cap = int(sys.argv[5]) if len(sys.argv) > 5 else 30
rows = min(t.height, s.height) // (cell + cap)
out = []
for r in range(rows):
    for c in range(cols):
        box = (c*cell, r*(cell+cap), c*cell+cell, r*(cell+cap)+cell)
        a, b = t.crop(box), s.crop(box)
        d = ImageChops.difference(a, b)
        m = sum(ImageStat.Stat(d).mean) / 3
        big = sum(1 for px in d.getdata() if max(px) > 25) / (cell*cell) * 100
        out.append((r*cols+c, m, big))
for i, m, big in out: print(f"cell {i:2d}  mean |diff| {m:5.2f}/255  pixels off by >25: {big:5.2f} %")
print(f"all     mean |diff| {sum(m for _,m,_ in out)/len(out):5.2f}/255  worst cell {max(out,key=lambda x:x[1])[0]} ({max(m for _,m,_ in out):.2f})")
