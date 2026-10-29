#!/usr/bin/env python3
"""Koncluí's 29 UI sounds and 4 ambient loops, in Koru's official sonic identity (v2).

Koru's sounds (konclui-project/koru: docs/sound.md, lib/koru-sound.js) are short synthesized owl
chirps: sine voices gliding in pitch, a 6 Hz vibrato, quiet 2nd and 3rd partials, slow linear
attacks, exponential decays and a 3 ms fade at the end of every voice; band-passed noise for the
tap of a tick and the air of a whoosh; one soft thump. `koru_render()` is a straight port of
`KoruSound.render()`, so Koncluí's set is built from the same recipes; the Koncluí events then use
that language in one key (C major pentatonic around C5-G5), warmed by a gentle low-pass, every
file peak-normalised to the same peak. Decorative or high-frequency events are silent files, so
SoundEngine needs no change. The loops (opt-in ambient beds for continuous states) are exactly
periodic: every partial and LFO makes whole cycles over the loop, so the end joins the start.
Mapping, rules and levels: design/prototype/koru/docs/SOUND.md (prototype checkout).

numpy + stdlib only; every noise is seeded, so a rerun writes byte-identical files.

    python3 scripts/konclui/sounds.py                    # 29 app files + the loop masters
    python3 scripts/konclui/sounds.py --out /tmp/k --loops-out /tmp/k/loops --only greet,finish
"""
import argparse
import math
import wave
from pathlib import Path

import numpy as np

SR = 48_000
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "NotchBuddy/Resources/sounds"
LOOPS_OUT = ROOT / "design/konclui/sound/loops"

# Every app file peaks here. SoundEngine plays at AppState.soundVolume, 0.12 by default
# (-18.4 dB); Koru's doctrine is a -12 dBFS file at host volume 0.3, about -22.5 dBFS heard.
# -4 dBFS x 0.12 lands on the same -22.4 dBFS.
PEAK_DBFS = -4.0
# The ambient beds sit 12 dB under the one-shots: -34.4 dBFS heard at the default volume.
LOOP_PEAK_DBFS = -16.0
# Warm low-pass on every one-shot (2nd-order Butterworth): softens the tick transients and the
# whoosh's top, leaves the voices (<= 3 kHz with their partials) untouched.
WARM_LP_HZ = 6000.0
SILENT_MS = 50

# C major pentatonic, the one key of the set.
C4, D4, E4, G4, A4 = 261.63, 293.66, 329.63, 392.00, 440.00
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.26, 783.99, 880.00
C6, D6 = 1046.50, 1174.66


# MARK: - Koru's DSP, ported from lib/koru-sound.js

KORU_PEAK = 0.25118864315  # -12 dBFS
VOICE_FADE_S = 0.003


def mulberry32(seed):
    """lib/koru-sound.js seededRandom(): the same sequence, so Koru's noise matches."""
    a = seed & 0xFFFFFFFF

    def rnd():
        nonlocal a
        a = (a + 0x6D2B79F5) & 0xFFFFFFFF
        t = a
        t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
        t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296

    return rnd


def biquad(kind):
    """RBJ biquad, coefficients recomputed per sample (sweeps), as in lib/koru-sound.js."""
    x1 = x2 = y1 = y2 = 0.0

    def step(x, freq, q, sr):
        nonlocal x1, x2, y1, y2
        w0 = 2 * math.pi * freq / sr
        cosw = math.cos(w0)
        alpha = math.sin(w0) / (2 * q)
        if kind == "bandpass":
            b0, b1, b2 = alpha, 0.0, -alpha
        else:
            b0 = (1 - cosw) / 2
            b1, b2 = 1 - cosw, b0
        y = (b0 * x + b1 * x1 + b2 * x2 - (-2 * cosw) * y1 - (1 - alpha) * y2) / (1 + alpha)
        x2, x1, y2, y1 = x1, x, y1, y
        return y

    return step


def voice(f0, f1=None, ms=140, glide=0.06, vib_rate=6.0, vib_depth=0.015, attack=0.008, tau=0.045,
          p2=0.2, p3=0.1, sub=0.0, breath=0.0, seed=0):
    """One owl voice. The defaults are Koru's chirpVoice(); sub (an octave below) and breath
    (soft noise following the envelope) are Koncluí's warmth, 0 in every Koru recipe."""
    return dict(ms=ms, f0=f0, f1=f0 if f1 is None else f1, glide=glide, vib_rate=vib_rate,
                vib_depth=vib_depth, attack=attack, tau=tau, p2=p2, p3=p3, sub=sub, breath=breath, seed=seed)


def bell(f, ms=250):
    """Koru's bellVoice(): a pure sine with a quiet harmonic 2nd and 3rd, no inharmonic modes."""
    return voice(f, ms=ms, glide=1, vib_depth=0, attack=0.004, tau=0.07, p2=0.25, p3=0.06)


def add_voice(out, sr, start_ms, v, gain=1.0):
    """lib/koru-sound.js addVoice(): glide, vibrato, partials, linear attack, exponential decay,
    a 3 ms linear fade at the end (also when the buffer cuts the voice short)."""
    start = math.floor(start_ms / 1000 * sr)
    length = min(math.floor(v["ms"] / 1000 * sr), len(out) - start)
    if length <= 0:
        return
    fade = min(length, max(1, math.floor(VOICE_FADE_S * sr)))
    i = np.arange(length)
    t = i / sr
    vib = 1 + v["vib_depth"] * np.sin(2 * np.pi * v["vib_rate"] * t) if v["vib_depth"] else 1.0
    f = v["f0"] * (v["f1"] / v["f0"]) ** np.clip(t / v["glide"], 0, 1) * vib
    ph = np.cumsum(2 * np.pi * f / sr)
    env = np.where(t < v["attack"], t / v["attack"], np.exp(-(t - v["attack"]) / v["tau"]))
    env = env * np.minimum(1, (length - 1 - i) / fade)
    s = np.sin(ph) + v["p2"] * np.sin(2 * ph) + v["p3"] * np.sin(3 * ph)
    if v["sub"]:
        s = s + v["sub"] * np.sin(ph / 2)
    if v["breath"]:
        s = s + v["breath"] * band(np.random.default_rng(v["seed"]).standard_normal(length), sr,
                                   v["f0"] * 0.8, v["f1"] * 3)
    out[start:start + length] += gain * s * env


def tick_into(out, sr, start_ms, seed, tau=0.012, noise_gain=0.3, f=720.0, noise_f=4000.0, q=3.0, gain=1.0):
    """lib/koru-sound.js tickInto(): a short sine tap (6 ms attack) and 8 ms of band-passed noise.
    The defaults are Koru's; Koncluí tunes the tone to the key and the noise lower (wood, not click)."""
    add_voice(out, sr, start_ms, voice(f, ms=50, glide=1, vib_depth=0, attack=0.006, tau=tau, p2=0.15, p3=0), gain)
    rnd = mulberry32(seed)
    bp = biquad("bandpass")
    start = math.floor(start_ms / 1000 * sr)
    length = min(math.floor(0.008 * sr), len(out) - start)
    fade = min(length, max(1, math.floor(VOICE_FADE_S * sr)))
    for i in range(length):
        n = bp(rnd() * 2 - 1, noise_f, q, sr)
        out[start + i] += gain * noise_gain * n * math.exp(-i / (0.0025 * sr)) * min(1, (length - 1 - i) / fade)


def whoosh_into(out, sr, start_ms=0, ms=180, f0=400.0, f1=1600.0, q=2.0, swell=0.06, tau=0.04, seed=3):
    """lib/koru-sound.js 'whoosh': seeded noise through a band-pass sweeping f0 -> f1."""
    rnd = mulberry32(seed)
    bp = biquad("bandpass")
    start = math.floor(start_ms / 1000 * sr)
    total = ms / 1000
    for i in range(min(math.floor(total * sr), len(out) - start)):
        t = i / sr
        fc = f0 * (f1 / f0) ** min(max(t / total, 0), 1)
        env = t / swell if t < swell else math.exp(-(t - swell) / tau)
        out[start + i] += bp(rnd() * 2 - 1, fc, q, sr) * env


def thump_into(out, sr, start_ms=0, f0=130.0, f1=65.0, p2=0.1, p3=0.0, noise_lp=500.0, noise_gain=0.6, seed=5, gain=1.0):
    """lib/koru-sound.js 'thump': a falling low sine and 8 ms of low-passed noise."""
    add_voice(out, sr, start_ms, voice(f0, f1, ms=120, glide=0.04, vib_depth=0, attack=0.002, tau=0.035, p2=p2, p3=p3), gain)
    rnd = mulberry32(seed)
    lp = biquad("lowpass")
    start = math.floor(start_ms / 1000 * sr)
    length = math.floor(0.008 * sr)
    for i in range(min(length, len(out) - start)):
        out[start + i] += gain * noise_gain * lp(rnd() * 2 - 1, noise_lp, 0.7, sr) * (1 - i / length)


KORU_SOUNDS = {"chirp": 140, "chirp-double": 300, "chime-rise": 400, "boop-down": 220,
               "tick": 50, "tick-double": 200, "whoosh": 180, "thump": 120}


def koru_recipe(name, out, sr):
    """lib/koru-sound.js RECIPES, verbatim."""
    if name == "chirp":
        add_voice(out, sr, 0, voice(620, 840))
    elif name == "chirp-double":
        add_voice(out, sr, 0, voice(620, 840))
        add_voice(out, sr, 150, voice(680, 900))
    elif name == "chime-rise":
        add_voice(out, sr, 0, bell(523.25))
        add_voice(out, sr, 110, bell(659.25))
        add_voice(out, sr, 220, bell(783.99, ms=180))
    elif name == "boop-down":
        add_voice(out, sr, 0, voice(520, 380, ms=220, glide=0.16, vib_depth=0, attack=0.03, tau=0.055, p2=0.12, p3=0))
    elif name == "tick":
        tick_into(out, sr, 0, 7)
    elif name == "tick-double":
        tick_into(out, sr, 0, 7, tau=0.022)
        tick_into(out, sr, 110, 11, tau=0.022)
    elif name == "whoosh":
        whoosh_into(out, sr)
    elif name == "thump":
        thump_into(out, sr)
    else:
        raise KeyError(name)


def koru_render(name, sr=44_100):
    """KoruSound.render(name, sampleRate): the recipe, normalised to -12 dBFS, a final 2 ms fade."""
    out = np.zeros(round(KORU_SOUNDS[name] / 1000 * sr))
    koru_recipe(name, out, sr)
    peak = np.abs(out).max()
    out *= KORU_PEAK / peak if peak > 0 else 0
    fade = min(len(out), math.floor(0.002 * sr))
    out[len(out) - fade:] *= (np.arange(fade) / fade)[::-1]
    return out


# MARK: - Koncluí's helpers

def band(x, sr, lo, hi):
    """x kept between lo and hi Hz (raised-cosine half-octave skirts, done in the spectrum), unit RMS."""
    spec = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / sr), 1.0)

    def edge(v):
        v = np.clip(v / 0.5 + 0.5, 0, 1)
        return v * v * (3 - 2 * v)

    y = np.fft.irfft(spec * edge(np.log2(f / lo)) * edge(np.log2(hi / f)), len(x))
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def warm(x, sr, fc=WARM_LP_HZ):
    """2nd-order Butterworth low-pass (magnitude response applied in the spectrum, zero phase)
    on a zero-padded copy, so nothing wraps around."""
    n = len(x)
    nfft = 1 << (n + sr // 10 - 1).bit_length()
    f = np.fft.rfftfreq(nfft, 1 / sr)
    h = 1 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(np.fft.rfft(x, nfft) * h, nfft)[:n]


def master(out, sr, peak_dbfs=PEAK_DBFS):
    """Warm low-pass, peak to `peak_dbfs`, a 2 ms fade to exact zero at the end (as render())."""
    x = warm(out, sr)
    x *= 10 ** (peak_dbfs / 20) / np.abs(x).max()
    fade = min(len(x), math.floor(0.002 * sr))
    x[len(x) - fade:] *= (np.arange(fade) / fade)[::-1]
    x[0] = 0.0
    return x


# MARK: - The 29 events

SOUNDS = {}
SILENT = ("annoyed", "close", "hover", "open", "sleep", "yawn")


def sound(ms):
    def register(fn):
        SOUNDS[fn.__name__] = (fn, ms)
        return fn
    return register


@sound(300)
def greet(o, sr):
    """The signature: Koru's wave hello (chirp-double), two rising chirps, the second higher."""
    add_voice(o, sr, 0, voice(D5, G5))
    add_voice(o, sr, 150, voice(E5, A5))


@sound(2260)
def greeting(o, sr):
    """The sonic logo, on the first greeting's wave (GreetingCanvasView GT.pop1 = 1.45 s, waves
    until 2.40 s): the signature, then Koru's chime-rise C5 E5 G5."""
    greet(o[int(1.45 * sr):], sr)
    add_voice(o, sr, 1780, bell(C5))
    add_voice(o, sr, 1890, bell(E5))
    add_voice(o, sr, 2000, bell(G5, ms=250))


@sound(300)
def finish(o, sr):
    """Done: a chirp up to G5 resolving on a soft C6 bell. Light, it plays for every finished task."""
    add_voice(o, sr, 0, voice(C5, G5, ms=160, glide=0.07, sub=0.08))
    add_voice(o, sr, 110, bell(C6, ms=190), gain=0.5)


@sound(140)
def approve(o, sr):
    """The smallest yes: Koru's chirp, D5 -> G5."""
    add_voice(o, sr, 0, voice(D5, G5))


@sound(90)
def pop(o, sr):
    """A little bubble of a chirp: popups, the toggle, the desktop landing, a battery plugged in."""
    add_voice(o, sr, 0, voice(E5, A5, ms=90, glide=0.03, vib_depth=0, attack=0.005, tau=0.025))


@sound(280)
def question(o, sr):
    """Curious: one chirp rising a sixth, C5 -> A5, held a little longer."""
    add_voice(o, sr, 0, voice(C5, A5, ms=280, glide=0.16, attack=0.012, tau=0.08))


@sound(250)
def approval(o, sr):
    """Must not be missed, never an alarm: Koru's tick-double, two wooden taps, the second a fourth up."""
    tick_into(o, sr, 0, 7, tau=0.026, noise_gain=0.22, f=G5, noise_f=2500, q=2.5)
    tick_into(o, sr, 120, 11, tau=0.026, noise_gain=0.22, f=C6, noise_f=2500, q=2.5)


@sound(200)
def peek(o, sr):
    """Something new beside the notch (update, desktop peek): a lighter, lower tick-double."""
    tick_into(o, sr, 0, 13, tau=0.014, noise_gain=0.18, f=E5, noise_f=2200, q=2.5)
    tick_into(o, sr, 100, 17, tau=0.014, noise_gain=0.18, f=G5, noise_f=2200, q=2.5)


@sound(220)
def error(o, sr):
    """Koru's boop-down, C5 -> G4: a soft slow-attack sine sliding down. Informs, never scolds."""
    add_voice(o, sr, 0, voice(C5, G4, ms=220, glide=0.16, vib_depth=0, attack=0.03, tau=0.055, p2=0.12, p3=0))


@sound(230)
def rate(o, sr):
    """Rate limit, a wait rather than a fault: a soft low tick-double on G4."""
    tick_into(o, sr, 0, 19, tau=0.03, noise_gain=0.15, f=G4, noise_f=1500, q=2.0)
    tick_into(o, sr, 120, 23, tau=0.03, noise_gain=0.15, f=G4, noise_f=1500, q=2.0)


@sound(120)
def slap(o, sr):
    """A soft thump (Koru's), an octave higher with stronger partials: 65 Hz is lost on laptop speakers."""
    thump_into(o, sr, 0, f0=220, f1=110, p2=0.3, p3=0.12, noise_lp=900)


@sound(200)
def gulp(o, sr):
    """A playful swallow: a quick chirp down G5 -> C5 and a tiny thump. Faster and higher than error."""
    add_voice(o, sr, 0, voice(G5, C5, ms=110, glide=0.05, vib_depth=0, attack=0.006, tau=0.03))
    thump_into(o, sr, 85, f0=200, f1=100, p2=0.3, p3=0.1, noise_lp=800, noise_gain=0.4, seed=29, gain=0.6)


@sound(180)
def send(o, sr):
    """Koru's whoosh: one wing flap of air."""
    whoosh_into(o, sr)


@sound(150)
def attach(o, sr):
    """Two soft wooden taps, C5 then E5: a file clipped on."""
    tick_into(o, sr, 0, 31, tau=0.015, noise_gain=0.2, f=C5, noise_f=2200, q=2.5)
    tick_into(o, sr, 70, 37, tau=0.015, noise_gain=0.2, f=E5, noise_f=2200, q=2.5)


@sound(50)
def blip(o, sr):
    """Listening or a note starts: one bright wooden tick on C6."""
    tick_into(o, sr, 0, 41, tau=0.01, noise_gain=0.2, f=C6, noise_f=3000, q=2.5)


@sound(50)
def tick(o, sr):
    """Koru's tick on G5, the noise lowered to 2.5 kHz: a soft wooden tap."""
    tick_into(o, sr, 0, 7, noise_gain=0.25, f=G5, noise_f=2500, q=2.5)


@sound(80)
def work(o, sr):
    """An agent starts: a tiny "hu", C5 -> D5."""
    add_voice(o, sr, 0, voice(C5, D5, ms=80, glide=0.03, vib_depth=0, attack=0.008, tau=0.02))


@sound(110)
def think(o, sr):
    """Thinking: a soft "hm", A4 -> C5, slower in and out."""
    add_voice(o, sr, 0, voice(A4, C5, ms=110, glide=0.05, attack=0.015, tau=0.035))


@sound(130)
def search(o, sr):
    """Searching: two tiny quick chirps, pip-pip."""
    add_voice(o, sr, 0, voice(G5, A5, ms=55, glide=0.02, vib_depth=0, attack=0.005, tau=0.014))
    add_voice(o, sr, 70, voice(G5, A5, ms=55, glide=0.02, vib_depth=0, attack=0.005, tau=0.014))


@sound(380)
def love(o, sr):
    """Petting: a warm low coo, G4 -> C5, a wider slower vibrato, a little breath and body."""
    add_voice(o, sr, 0, voice(G4, C5, ms=380, glide=0.12, vib_rate=5.5, vib_depth=0.025, attack=0.025,
                              tau=0.11, p3=0.06, sub=0.15, breath=0.03, seed=43))


@sound(400)
def proud(o, sr):
    """What's New: Koru's chime-rise, C5 E5 G5, the one medium-weight celebration."""
    add_voice(o, sr, 0, bell(C5))
    add_voice(o, sr, 110, bell(E5))
    add_voice(o, sr, 220, bell(G5, ms=180))


@sound(70)
def wink(o, sr):
    """A tiny high chirp, A5 -> D6."""
    add_voice(o, sr, 0, voice(A5, D6, ms=70, glide=0.025, vib_depth=0, attack=0.004, tau=0.018, p2=0.1, p3=0.05))


@sound(380)
def dizzy(o, sr):
    """Wobbly and playful, never sad: a chirp rising E5 -> A5 through a wide 9 Hz wobble."""
    add_voice(o, sr, 0, voice(E5, A5, ms=380, glide=0.3, vib_rate=9, vib_depth=0.045, attack=0.015, tau=0.14))


def render(name, sr=SR):
    if name in SILENT:
        return np.zeros(round(SILENT_MS / 1000 * sr))
    fn, ms = SOUNDS[name]
    out = np.zeros(round(ms / 1000 * sr))
    fn(out, sr)
    return master(out, sr)


# MARK: - Ambient loops

LOOP_S = 4.0  # Koru's breathe carrier period (spec/motion.json breathe, 4000 ms)


def snap(f, period=LOOP_S):
    """The nearest frequency that makes whole cycles over the loop."""
    return round(f * period) / period


def bump(t, t0, t1, period=LOOP_S):
    """A sin^2 swell from t0 to t1 (seconds, may wrap past the loop end): smooth, periodic."""
    u = ((t - t0) % period) / ((t1 - t0) % period)
    return np.where(u <= 1, np.sin(np.pi * np.minimum(u, 1)) ** 2, 0.0)


def loop_noise(rng, n, sr, lo, hi):
    """Exactly periodic band noise: random phases on the loop's own FFT bins, unit RMS."""
    f = np.maximum(np.fft.rfftfreq(n, 1 / sr), 1.0)
    mag = np.clip((np.log2(f / lo) + 0.5) / 0.5, 0, 1) * np.clip((np.log2(hi / f) + 0.5) / 0.5, 0, 1)
    spec = mag * np.exp(2j * np.pi * rng.random(len(f)))
    spec[0] = 0
    y = np.fft.irfft(spec, n)
    return y / np.sqrt(np.mean(y * y))


def loop_sweep(rng, n, sr, fc, width=0.6, frame=2048):
    """Periodic noise through a band whose centre follows fc(t) (Hz, periodic): overlap-add on the
    circle (frames wrap around the loop end), so the result is exactly periodic. Unit RMS."""
    x = loop_noise(rng, n, sr, 100, 8000)
    hop = frame // 4
    win = np.hanning(frame + 1)[:-1]
    lf = np.log2(np.maximum(np.fft.rfftfreq(frame, 1 / sr), 1.0))
    y = np.zeros(n)
    for s in range(0, n, hop):
        idx = (s + np.arange(frame)) % n
        mask = np.exp(-0.5 * ((lf - np.log2(fc((s + frame / 2) / sr % LOOP_S))) / (width / 2)) ** 2)
        y[idx] += np.fft.irfft(np.fft.rfft(x[idx] * win) * mask, frame) * win
    return y / np.sqrt(np.mean(y * y))


def loop_voice(n, sr, f, p2=0.2, p3=0.1, vib_rate=5.0, vib_depth=0.01):
    """Koru's voice as an endless tone: the frequency and the vibrato make whole cycles over the loop."""
    f, vib_rate = snap(f), snap(vib_rate)
    t = np.arange(n) / sr
    ph = 2 * np.pi * f * t + (f * vib_depth / vib_rate) * np.sin(2 * np.pi * vib_rate * t)
    return np.sin(ph) + p2 * np.sin(2 * ph) + p3 * np.sin(3 * ph)


LOOPS = {}


def loop(fn):
    LOOPS[fn.__name__.replace("_", "-")] = fn
    return fn


@loop
def sleep_loop(n, sr, t, rng):
    """Sleeping: one slow breath per 4 s, in through the beak (airy), out longer and warmer with a
    faint low "hoo", over a constant hush of air; the seam sits in the pause after the breath out."""
    hush = 0.12 * loop_noise(rng, n, sr, 200, 900)
    inhale = 0.55 * loop_noise(rng, n, sr, 700, 2600) * bump(t, 0.25, 1.65)
    exhale = loop_noise(rng, n, sr, 250, 1300) * bump(t, 1.55, 3.75)
    hoo = 0.3 * loop_voice(n, sr, C4) * bump(t, 1.9, 3.6)
    return hush + inhale + exhale + hoo


@loop
def think_loop(n, sr, t, rng):
    """Thinking: two soft "hm"s a cycle, E4 then G4, over a faint air; near-quiet at the seam."""
    hm = loop_voice(n, sr, E4) * bump(t, 0.2, 1.8) + 0.85 * loop_voice(n, sr, G4) * bump(t, 2.2, 3.8)
    air = 0.35 * loop_noise(rng, n, sr, 300, 1600) * (0.4 + 0.6 * bump(t, 0.0, 2.0) + 0.6 * bump(t, 2.0, 4.0))
    return 0.6 * hm + air


@loop
def work_loop(n, sr, t, rng):
    """Working: a soft busy breath pulsing twice a second (8 per cycle) and a faint C5-G5 hum
    swelling once per cycle."""
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * 2.0 * t) ** 2
    air = loop_noise(rng, n, sr, 350, 1800) * pulse
    hum = 0.25 * (loop_voice(n, sr, C5) + 0.7 * loop_voice(n, sr, G5)) * (0.3 + 0.7 * bump(t, 0.5, 3.5))
    return air + hum


@loop
def search_loop(n, sr, t, rng):
    """Searching: a soft band of air scanning up and down (600 <-> 1700 Hz) twice per cycle."""
    fc = lambda s: 600 * (1700 / 600) ** (0.5 - 0.5 * np.cos(2 * np.pi * s / 2.0))
    return loop_sweep(rng, n, sr, fc) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * t) ** 2)


def render_loop(name, sr=SR):
    n = round(LOOP_S * sr)
    t = np.arange(n) / sr
    x = LOOPS[name](n, sr, t, np.random.default_rng(sum(map(ord, name))))
    return x * 10 ** (LOOP_PEAK_DBFS / 20) / np.abs(x).max()


# MARK: - Files

def write_wav(path, x, sr=SR):
    """48 kHz stereo 16-bit, the same signal in both channels (Koru sits in the middle of the notch)."""
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(np.repeat(pcm, 2).tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--loops-out", type=Path, default=LOOPS_OUT)
    parser.add_argument("--only", help="comma-separated names (events or loops)")
    args = parser.parse_args()
    names = sorted(set(SOUNDS) | set(SILENT))
    assert len(names) == 29 and not set(SOUNDS) & set(SILENT), "29 events, each sounding or silent"
    only = set(args.only.split(",")) if args.only else None
    args.out.mkdir(parents=True, exist_ok=True)
    for name in names:
        if only and name not in only:
            continue
        x = render(name)
        write_wav(args.out / f"{name}.wav", x)
        peak = 20 * math.log10(np.abs(x).max()) if x.any() else -math.inf
        print(f"{name:9s} {len(x) / SR * 1000:6.0f} ms  peak {peak:6.1f} dBFS")
    args.loops_out.mkdir(parents=True, exist_ok=True)
    for name in sorted(LOOPS):
        if only and name not in only:
            continue
        x = render_loop(name)
        write_wav(args.loops_out / f"{name}.wav", x)
        rms = 20 * math.log10(np.sqrt(np.mean(x * x)))
        print(f"{name:12s} {len(x) / SR:4.1f} s loop  peak {LOOP_PEAK_DBFS:6.1f} dBFS  rms {rms:6.1f} dBFS")


if __name__ == "__main__":
    main()
