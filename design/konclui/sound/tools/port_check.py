"""Port proof (python3 design/konclui/sound/tools/port_check.py > design/konclui/sound/port.md): KoruSound.render (node, lib/koru-sound.js) vs sounds.koru_render (Python) at 48 and 44.1 kHz."""
import subprocess, sys
from pathlib import Path
import numpy as np
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[3] / "scripts/konclui"))
import sounds
out = Path("/tmp/k7-port")
out.mkdir(exist_ok=True)
print("| sound | rate | samples js / py | correlation | max abs diff (full scale 1.0) | peak js / py (dBFS) |")
print("|---|---|---|---|---|---|")
for sr in (48000, 44100):
    subprocess.run(["node", str(HERE / "koru_dump.cjs"), str(sr), str(out)], check=True, capture_output=True)
    for name in sounds.KORU_SOUNDS:
        js = np.fromfile(out / f"{name}-{sr}.f32", dtype="<f4").astype(float)
        py = sounds.koru_render(name, sr)
        c = np.corrcoef(js, py)[0, 1]
        db = lambda x: 20 * np.log10(np.abs(x).max())
        print(f"| {name} | {sr} | {len(js)} / {len(py)} | {c:.6f} | {np.abs(js - py).max():.2e} | {db(js):.2f} / {db(py):.2f} |")
