"""K7 measurements: per-file table, loop seam proof (3x concatenation + click detector), contact sheet, preview.

python3 measure.py <sounds dir> <loops dir> <decoded-m4a loops dir or -> <out dir>
"""
import json, sys, wave
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[3] / "scripts/konclui"))
import sounds  # noqa: E402

SND, LOOPS, DEC, OUT = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
OUT.mkdir(parents=True, exist_ok=True)
SR = sounds.SR


def read(path):
    with wave.open(str(path)) as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        x = np.frombuffer(w.readframes(n), "<i2").reshape(-1, ch).T / 32768.0
    return x, ch, sw, sr


def db(v):
    return 20 * np.log10(v) if v > 0 else -np.inf


def d2(x):
    return np.abs(x[2:] - 2 * x[1:-1] + x[:-2])


def seam_ratio(x, seams, guard=2, reach=480):
    """Second-difference spike at each seam over the largest one in the 10 ms around it (seam excluded).
    A click is a spike several times the local level; a seamless join reads <= ~1."""
    d = d2(x)
    out = []
    for s in seams:
        c = s - 1  # d[i] is centred on sample i + 1
        spike = d[c - guard:c + guard + 1].max()
        local = np.concatenate([d[c - reach:c - guard], d[c + guard + 1:c + reach]]).max()
        jump = abs(x[s] - x[s - 1])
        steps = np.abs(np.diff(x[s - reach:s + reach]))
        out.append((spike / local, jump, np.percentile(steps, 99), spike))
    return out


# 1. Per-file table (29 app files).
rows, meta = [], {}
for p in sorted(SND.glob("*.wav")):
    x, ch, sw, sr = read(p)
    m = x[0]
    peak = np.abs(x).max()
    spec = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(len(m), 1 / sr)
    hf = spec[f > 4000].sum() / spec.sum() * 100 if spec.sum() else 0
    cen = (spec * f).sum() / spec.sum() if spec.sum() else 0
    meta[p.stem] = dict(ms=round(len(m) / sr * 1000), peak=round(db(peak), 2), lr_equal=bool(np.array_equal(x[0], x[1])))
    rows.append(f"| {p.stem} | {ch} ch {sr} Hz {8 * sw}-bit | {len(m) / sr * 1000:.0f} | {db(peak):.2f} | "
                f"{db(np.sqrt(np.mean(m * m))) if peak else -np.inf:.1f} | {int((np.abs(x) >= 32767 / 32768).sum())} | "
                f"{x[:, 0].max() * 32768:.0f}/{x[:, -1].max() * 32768:.0f} | {cen:.0f} | {hf:.2f} |")
(OUT / "files.md").write_text("| file | format | ms | sample peak dBFS | RMS dBFS | clipped | first/last LSB | centroid Hz | energy > 4 kHz % |\n"
                              "|---|---|---|---|---|---|---|---|---|\n" + "\n".join(rows) + "\n")
(OUT / "files.json").write_text(json.dumps(meta, indent=1))

# 2. Loop seam proof.
lines = ["| loop | source | length (frames) | seam 1: d2 ratio / jump / p99 step / d2 spike | seam 2: same | click? |", "|---|---|---|---|---|---|"]
def proof(name, x, label):
    n = len(x)
    x3 = np.tile(x, 3)
    r = seam_ratio(x3, [n, 2 * n])
    click = any(a > 2 for a, *_ in r)
    cells = " | ".join(f"{a:.2f} / {j * 32768:.0f} / {p * 32768:.0f} LSB / {db(k):.1f} dBFS" for a, j, p, k in r)
    lines.append(f"| {name} | {label} | {n} | {cells} | {'CLICK' if click else 'no'} |")
for p in sorted(LOOPS.glob("*.wav")):
    x, *_ = read(p)
    proof(p.stem, x[0], "wav master")
    # Negative control: the same loop cut 1.37 ms short is no longer periodic; the detector must flag it.
    proof(p.stem, x[0][:-66], "control: cut 66 frames short")
    if DEC != "-":
        y, *_ = read(Path(DEC) / f"{p.stem}.wav")
        proof(p.stem, y[0], f"m4a decoded by afconvert ({len(y[0])} frames)")
(OUT / "seams.md").write_text("\n".join(lines) + "\n")

# 3. Contact sheet: waveform + spectrogram of every sounding file and the loops.
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
items = [(p.stem, read(p)[0][0]) for p in sorted(SND.glob("*.wav"))]
silent = [k for k, x in items if not x.any()]
items = [(k, x) for k, x in items if x.any()] + [(p.stem, read(p)[0][0]) for p in sorted(LOOPS.glob("*.wav"))]
cols = 6
rows_n = -(-len(items) // cols)
fig, axes = plt.subplots(rows_n * 2, cols, figsize=(cols * 3.2, rows_n * 3.0), gridspec_kw={"height_ratios": [1, 1.4] * rows_n})
fig.patch.set_facecolor("#111316")
for i in range(rows_n * cols):
    aw, asp = axes[(i // cols) * 2, i % cols], axes[(i // cols) * 2 + 1, i % cols]
    for a in (aw, asp):
        a.set_facecolor("#111316"); a.set_xticks([]); a.set_yticks([])
        for s in a.spines.values(): s.set_color("#333")
    if i >= len(items):
        aw.axis("off"); asp.axis("off"); continue
    name, x = items[i]
    t = np.arange(len(x)) / SR
    aw.plot(t, x, color="#3CCFD9", lw=0.5); aw.set_ylim(-0.7, 0.7); aw.set_xlim(0, t[-1])
    aw.set_title(f"{name}  {len(x) / SR * 1000:.0f} ms", color="#ddd", fontsize=9)
    nfft = 1024 if len(x) > 4096 else 256
    asp.specgram(x + 1e-9, NFFT=nfft, Fs=SR, noverlap=nfft * 3 // 4, cmap="magma", vmin=-140, vmax=-40)
    asp.set_ylim(0, 8000); asp.set_xlim(0, t[-1])
fig.suptitle(f"Koncluí sounds v2 (Koru): waveform (+-0.7 FS) and spectrogram 0-8 kHz.  Silent files (50 ms of zeros): {', '.join(silent)}",
             color="#eee", fontsize=11)
fig.tight_layout(rect=(0, 0, 1, 0.97))
fig.savefig(OUT / "contact-sheet.png", facecolor=fig.get_facecolor(), dpi=90)

# 4. Preview (AAC, small enough to keep): every sounding file 0.35 s apart, then each loop for two cycles; offsets in preview.txt.
gap = np.zeros(int(0.35 * SR))
parts, txt, at = [], [], 0.0
for name, x in items:
    reps = 2 if name.endswith("-loop") else 1
    y = np.tile(x, reps)
    txt.append(f"{at:7.2f} s  {name}")
    parts += [y, gap]; at += (len(y) + len(gap)) / SR
sounds.write_wav(Path("/tmp/k7-preview.wav"), np.concatenate(parts))
import subprocess
subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-q", "127", "/tmp/k7-preview.wav", str(OUT / "preview.m4a")], check=True)
(OUT / "preview.txt").write_text("\n".join(txt) + "\n")
print("ok", len(items), "items; silent:", silent)
