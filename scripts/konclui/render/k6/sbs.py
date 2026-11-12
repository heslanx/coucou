# Side by side: sbs.py out.png scale label1 img1 label2 img2 ...  (images scaled by `scale`, stacked vertically with labels)
import sys
from PIL import Image, ImageDraw
out, sc = sys.argv[1], float(sys.argv[2])
pairs = list(zip(sys.argv[3::2], sys.argv[4::2]))
ims = []
for lab, p in pairs:
    im = Image.open(p).convert('RGB')
    im = im.resize((int(im.width*sc), int(im.height*sc)), Image.LANCZOS)
    ims.append((lab, im))
W = max(im.width for _, im in ims); H = sum(im.height + 22 for _, im in ims)
c = Image.new('RGB', (W, H), (16, 17, 21)); d = ImageDraw.Draw(c); y = 0
for lab, im in ims:
    d.text((6, y + 5), lab, fill=(230, 230, 230)); y += 22; c.paste(im, (0, y)); y += im.height
c.save(out); print(out, c.size)
