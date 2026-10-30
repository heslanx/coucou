#!/usr/bin/env python3
"""Turn the orange eye discs of the chosen icon art white, as Koru's eyes are now (white discs, dark ink pupils).

  python3 design/konclui/icon/white_eyes.py

candidates/koru-icon-B-warm.png -> candidates/koru-icon-B-warm-white-eyes.png, which build_icons.py uses. Only the two eye
discs change: they are the two largest orange regions (the beak is the third), and inside them every pixel moves from orange
towards white by its orange share (pixel - share x orange + share x white), so the pupils, the highlights and the anti-aliased rims keep their shape. The disc's own
shading carries over as a light grey-blue at the rim (Koru's eye edge, #DAE2E4) and near-white (#F8FAFA) inside.

Needs Pillow, numpy and scipy.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'candidates', 'koru-icon-B-warm.png')
OUT = os.path.join(HERE, 'candidates', 'koru-icon-B-warm-white-eyes.png')
EYE_IN, EYE_EDGE = np.array([0xF8, 0xFA, 0xFA], float), np.array([0xDA, 0xE2, 0xE4], float)


def main():
    img = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    # Orange share of a pixel: red over blue, 0 on the teal disc, the dark pupils and the white highlights, 1 on the iris.
    share = np.clip((r - b - 20) / 150, 0, 1) * (g > 60)
    labels, n = ndimage.label(share > .5)
    sizes = ndimage.sum(np.ones_like(share), labels, range(1, n + 1))
    eyes = 1 + np.argsort(sizes)[::-1][:2]                 # the two biggest orange regions are the eyes; the beak is smaller
    disc = np.isin(labels, eyes)
    disc = ndimage.binary_fill_holes(disc)                 # the pupils and highlights inside
    region = ndimage.binary_dilation(disc, iterations=6)   # and the anti-aliased rim outside
    # The iris's local orange, spread from its pure pixels into the pupil edge and the rim (normalised blur), sets both what
    # to remove and how light the white is there (its value between the iris's darkest and lightest orange).
    pure = (disc & (share > .95)).astype(float)
    w = ndimage.gaussian_filter(pure, 8)
    orange = np.stack([ndimage.gaussian_filter(img[..., c] * pure, 8) for c in range(3)], -1) / np.maximum(w, 1e-6)[..., None]
    orange[w < 1e-3] = np.median(img[pure > 0], axis=0)
    value = orange[..., 0] + orange[..., 1]
    lo, hi = np.percentile(value[pure > 0], [5, 95])
    lit = np.clip((value - lo) / (hi - lo), 0, 1)
    white = EYE_EDGE + (EYE_IN - EYE_EDGE) * lit[..., None]
    # A pixel is share x orange + the rest; its orange part becomes white.
    a = np.where(region, share, 0)[..., None]
    out = img + a * (white - orange)
    Image.fromarray(np.clip(out + .5, 0, 255).astype(np.uint8)).save(OUT, optimize=True)
    print(f'{OUT}: {int(disc.sum())} px of eye disc, {n} orange regions')


if __name__ == '__main__':
    main()
