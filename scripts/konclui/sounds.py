#!/usr/bin/env python3
"""Koncluí's 29 UI sounds, synthesized from scratch for Koru, the velvet owl.

Every sound keeps the file name and length of the Coucou sound it replaces, so SoundEngine
plays them unchanged, and the level that sound had in the app: SoundEngine plays every file
at one volume, so the files themselves carry the in-app balance (hover and tick sit ~30 dB
under the alerts). Nothing is read from Coucou's files; the lengths and levels are numbers.

Palette, shared by the whole set: D major pentatonic; a soft-mallet marimba, soft bells,
Koru's round breathy "hoo" (short-long, a step down, is the greet motif), feathers and breath
noise, one small room. numpy only; every random source is seeded, so a rerun writes
byte-identical files.

    python3 scripts/konclui/sounds.py                  # writes NotchBuddy/Resources/sounds/*.wav
    python3 scripts/konclui/sounds.py --out /tmp/k --only greet,finish
"""
import argparse
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 48_000
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "NotchBuddy/Resources/sounds"
SEED = 0x4B6F7275  # "Koru"
CEILING = -1.0     # dBTP, 4x oversampled

# Frames of each sound (48 kHz): Coucou's lengths, which the app's animations are timed to.
FRAMES = {
    "annoyed": 28432, "approval": 42093, "approve": 28589, "attach": 43362, "blip": 4885,
    "close": 20586, "dizzy": 47158, "error": 40242, "finish": 55636, "greet": 36064,
    "greeting": 200316, "gulp": 35956, "hover": 4020, "love": 37966, "open": 24154,
    "peek": 21418, "pop": 18258, "proud": 41493, "question": 33771, "rate": 32375,
    "search": 21945, "send": 22981, "slap": 28892, "sleep": 21741, "think": 21142,
    "tick": 3433, "wink": 10206, "work": 18041, "yawn": 35055,
}

# Active loudness (LKFS-a, see active_loudness) of each sound: the level Coucou's sound had,
# so the mix in the app stays the same.
LEVEL = {
    "annoyed": -20.5, "approval": -15.5, "approve": -20.5, "attach": -18.0, "blip": -32.5,
    "close": -29.5, "dizzy": -19.5, "error": -16.5, "finish": -13.5, "greet": -17.0,
    "greeting": -14.0, "gulp": -17.0, "hover": -39.0, "love": -19.5, "open": -27.5, "peek": -23.0,
    "pop": -28.0, "proud": -16.5, "question": -18.0, "rate": -21.5, "search": -24.0, "send": -30.0,
    "slap": -22.0, "sleep": -29.5, "think": -25.0, "tick": -41.0, "wink": -33.0, "work": -29.0,
    "yawn": -24.5,
}


# MARK: - Basics

def frames(sec):
    return max(1, int(round(sec * SR)))


def time(n):
    return np.arange(n) / SR


_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(note):
    """'F#5' -> Hz (A4 = 440); numbers pass through."""
    if not isinstance(note, str):
        return float(note)
    pc = _PC[note[0]] + (1 if note[1] == "#" else 0)
    midi = pc + 12 * (int(note[-1]) + 1)
    return 440.0 * 2 ** ((midi - 69) / 12)


def ramp_in(n, sec):
    """Raised-cosine rise from exactly 0 to 1 over `sec`: attacks without clicks."""
    e = np.ones(n)
    k = min(n, frames(sec))
    e[:k] = 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / k)
    return e


def ramp_out(n, sec):
    """Raised-cosine fall from 1 to exactly 0 at the last sample."""
    e = np.ones(n)
    k = min(n, frames(sec))
    e[n - k:] = 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return e


def edges(n, attack, release=0.005):
    """Click-free start and end for one note or burst."""
    return ramp_in(n, attack) * ramp_out(n, min(release, n / SR * 0.3))


def phase(freq):
    """Phase (radians) of an oscillator following `freq` (Hz, one value per sample)."""
    return 2 * np.pi * np.cumsum(freq) / SR


def glide(f0, f1, n, start=0.0, sec=None):
    """f0 -> f1, exponential in pitch and smoothstepped, between `start` and `start + sec`."""
    sec = sec or n / SR - start
    u = np.clip((time(n) - start) / max(sec, 1e-6), 0, 1)
    return f0 * (f1 / f0) ** (u * u * (3 - 2 * u))


def next_pow2(n):
    return 1 << (int(n) - 1).bit_length()


def fftconv(a, b):
    nfft = next_pow2(len(a) + len(b))
    return np.fft.irfft(np.fft.rfft(a, nfft) * np.fft.rfft(b, nfft), nfft)[: len(a)]


def biquad(x, b, a, pad=0.5):
    """Causal biquad, applied through its frequency response on a zero-padded signal."""
    n = x.shape[-1]
    nfft = next_pow2(n + frames(pad))
    z = np.exp(-2j * np.pi * np.fft.rfftfreq(nfft))
    h = (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)
    return np.fft.irfft(np.fft.rfft(x, nfft) * h, nfft)[..., :n]


def rbj(kind, f0, q=0.7071):
    """Audio EQ Cookbook low/high-pass coefficients."""
    w0 = 2 * np.pi * f0 / SR
    c, alpha = np.cos(w0), np.sin(w0) / (2 * q)
    b = [(1 - c) / 2, 1 - c, (1 - c) / 2] if kind == "lp" else [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    return b, [1 + alpha, -2 * c, 1 - alpha]


# ITU-R BS.1770 K-weighting at 48 kHz.
K_SHELF = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
K_HIGHPASS = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def active_loudness(x, block=0.010, gate=20.0):
    """Loudness while the sound sounds (LKFS-a): BS.1770 K-weighting, 10 ms blocks, mean power
    of the blocks within `gate` dB of the loudest. Unlike integrated LUFS it does not drop
    with the silence after a short sound."""
    y = biquad(biquad(x, *K_SHELF), *K_HIGHPASS)
    k = frames(block)
    nb = max(1, y.shape[-1] // k)
    y = np.pad(y, ((0, 0), (0, max(0, nb * k - y.shape[-1]))))
    p = (y[:, : nb * k].reshape(y.shape[0], nb, k) ** 2).mean(axis=2).sum(axis=0)
    keep = p >= p.max() * 10 ** (-gate / 10)
    return -0.691 + 10 * np.log10(p[keep].mean())


def true_peak_db(x, over=4):
    n = x.shape[-1]
    spec = np.fft.rfft(x)
    up = np.zeros((x.shape[0], over * n // 2 + 1), complex)
    up[:, : spec.shape[-1]] = spec
    return 20 * np.log10(np.abs(np.fft.irfft(up, over * n) * over).max())


# MARK: - Noise

def band_noise(rng, n, lo, hi, skirt=0.5):
    """White noise kept between lo and hi Hz, with soft `skirt`-octave edges; unit RMS."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 1.0)

    def edge(v):
        v = np.clip(v / skirt + 0.5, 0, 1)
        return v * v * (3 - 2 * v)

    y = np.fft.irfft(spec * edge(np.log2(f / lo)) * edge(np.log2(hi / f)), n)
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def swept_noise(rng, n, f0, f1, width=0.7):
    """Noise through a `width`-octave band whose centre glides f0 -> f1: whooshes. Unit RMS."""
    size, hop = 1024, 256
    x = rng.standard_normal(n + size)
    win = np.hanning(size + 1)[:-1]
    lf = np.log2(np.maximum(np.fft.rfftfreq(size, 1 / SR), 1.0))
    out = np.zeros(n + size)
    for start in range(0, n, hop):
        fc = f0 * (f1 / f0) ** min(start / max(n - 1, 1), 1.0)
        mask = np.exp(-0.5 * ((lf - np.log2(fc)) / (width / 2)) ** 2)
        out[start:start + size] += np.fft.irfft(np.fft.rfft(x[start:start + size] * win) * mask, size)
    y = out[:n]
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


# MARK: - Instruments

def marimba(rng, note, vel=1.0, mute=1.0):
    """Soft-mallet bar: tuned modes 1, ~4 and ~10, a little resonator warmth, a felt knock.
    `mute` < 1 damps the bar (staccato)."""
    f = hz(note)
    tau = float(np.clip(0.5 * (330 / f) ** 0.6, 0.12, 0.8)) * mute
    n = frames(tau * 6.5)
    t = time(n)
    bright = 0.6 + 0.4 * vel
    y = np.zeros(n)
    for ratio, gain, k in ((1.0, 1.0, 1.0), (2.0, 0.05, 0.5), (3.98, 0.2 * bright, 0.22), (9.3, 0.045 * bright, 0.07)):
        if f * ratio < 9000:
            y += gain * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (tau * k))
    y += 0.12 * bright * band_noise(rng, n, 300, 2400) * np.exp(-t / 0.0025)
    return vel * y * edges(n, 0.0015)


def bell(note, vel=1.0, tau=0.45):
    """Soft bell: a slowly beating fundamental pair, a quiet octave and two faint inharmonic modes."""
    f = hz(note)
    n = frames(tau * 6.5)
    t = time(n)
    y = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 1.0023 * t)) * np.exp(-t / tau)
    for ratio, gain, k in ((2.0, 0.14, 0.45), (2.76, 0.07, 0.3), (5.4, 0.02, 0.12)):
        if f * ratio < 9000:
            y += gain * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (tau * k))
    return vel * y * edges(n, 0.003) / 1.35


def hoot(rng, f0, f1, dur, vel=1.0, breath=0.18, vibrato=0.0, rate=5.2, scoop=0.6, bright=0.12):
    """Koru's voice: a round, ocarina-like "hoo" gliding f0 -> f1, with an airy "h" onset.
    `scoop` semitones below pitch it slides up in ~40 ms; `vibrato` is a depth in semitones."""
    n = frames(dur)
    t = time(n)
    f0, f1 = hz(f0), hz(f1)
    semis = -scoop * np.exp(-t / 0.018)
    if vibrato:
        semis = semis + vibrato * np.sin(2 * np.pi * rate * t) * np.clip((t - 0.06) / 0.12, 0, 1)
    ph = phase(glide(f0, f1, n) * 2 ** (semis / 12))
    tone = np.sin(ph) + bright * np.sin(2 * ph) + 0.25 * bright * np.sin(3 * ph)
    fm = (f0 * f1) ** 0.5
    air = band_noise(rng, n, 0.9 * fm, 3.2 * fm)
    release = min(0.09, dur * 0.4)
    h = band_noise(rng, n, 900, 2800) * np.exp(-t / 0.03) * ramp_in(n, 0.004) * ramp_out(n, release)
    env = ramp_in(n, 0.035) * ramp_out(n, release) * (0.85 + 0.15 * np.exp(-t / 0.1))
    return vel * ((tone + breath * air) * env + 0.5 * breath * h)


def tap(rng, centre=3200, length=0.010, vel=1.0):
    """Click: a 5-15 ms noise burst through a band around `centre` (Q about 3)."""
    n = frames(length)
    t = time(n)
    y = band_noise(rng, n, centre / 1.15, centre * 1.15, skirt=0.35) * np.exp(-t / (length / 4))
    return vel * y * edges(n, 0.0004, 0.004)


def wood(note, vel=1.0, tau=0.012):
    """Small wooden block: a fast-dying fundamental and two inharmonic modes."""
    f = hz(note)
    n = frames(tau * 7)
    t = time(n)
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
         + 0.35 * np.sin(2 * np.pi * 2.32 * f * t) * np.exp(-t / (tau * 0.5))
         + 0.12 * np.sin(2 * np.pi * 4.1 * f * t) * np.exp(-t / (tau * 0.3)))
    return vel * y * edges(n, 0.0005)


def thump(f0=150, f1=70, tau=0.05, vel=1.0):
    """Soft body impact: a sine falling fast from f0 to f1."""
    n = frames(tau * 7)
    t = time(n)
    y = np.sin(phase(f1 + (f0 - f1) * np.exp(-t / 0.025))) * np.exp(-t / tau)
    return vel * y * edges(n, 0.002)


def chirp(f0, f1, sweep, tau, vel=1.0, harmonic=0.0):
    """Sine sliding f0 -> f1 in `sweep` s (eased) and decaying with `tau`: pops, bubbles, gulps."""
    n = frames(sweep + tau * 6.5)
    t = time(n)
    u = np.clip(t / sweep, 0, 1)
    ph = phase(f0 * (f1 / f0) ** (1 - (1 - u) ** 2))
    y = np.sin(ph) + harmonic * np.sin(2 * ph)
    return vel * y * np.exp(-t / tau) * edges(n, 0.002)


def feathers(rng, dur, flaps, lo=700, hi=3200):
    """Wing flaps: band noise with one soft swell per flap time (s)."""
    n = frames(dur)
    env = np.zeros(n)
    for at in flaps:
        i = int(round(at * SR))
        tt = time(n - i)
        env[i:] += (1 - np.exp(-tt / 0.008)) * np.exp(-tt / 0.035)
    return band_noise(rng, n, lo, hi) * env * ramp_out(n, 0.02)


def puff(rng, dur, lo, hi, attack=0.02):
    """A breath: band noise that swells and fades."""
    n = frames(dur)
    return band_noise(rng, n, lo, hi) * ramp_in(n, attack) * ramp_out(n, dur - attack)


def whoosh(rng, dur, f0, f1, width=0.7):
    n = frames(dur)
    return swept_noise(rng, n, f0, f1, width) * np.sin(np.pi * np.arange(n) / n) ** 1.5


# MARK: - Mix and master

class Mix:
    """One sound: a stereo dry bus and a mono send to the shared room."""

    def __init__(self, name):
        self.n = FRAMES[name]
        self.dry = np.zeros((2, self.n))
        self.send = np.zeros(self.n)
        self.rng = np.random.default_rng([SEED, zlib.crc32(name.encode())])

    def add(self, sig, at=0.0, gain=1.0, pan=0.0, verb=1.0):
        """Places `sig` at `at` s; pan -1 (left) .. 1 (right), constant power, or one per sample."""
        i = int(round(at * SR))
        if i >= self.n:
            return
        seg = np.asarray(sig)[: self.n - i] * gain
        angle = (np.asarray(pan, dtype=float) + 1) * np.pi / 4
        if angle.ndim:
            angle = angle[: len(seg)]
        self.dry[0, i:i + len(seg)] += np.cos(angle) * seg
        self.dry[1, i:i + len(seg)] += np.sin(angle) * seg
        self.send[i:i + len(seg)] += verb * seg


_ROOM = None


def room(rt60=0.5, length=0.8):
    """The one small room every sound shares: decorrelated stereo noise tails whose highs die
    2.5x faster, 9 ms pre-delay, unit energy per channel."""
    global _ROOM
    if _ROOM is None:
        rng = np.random.default_rng([SEED, 0])
        n = frames(length)
        t = time(n)
        pre = frames(0.009)
        ir = np.zeros((2, n))
        for ch in range(2):
            y = (band_noise(rng, n, 80, 2500) * np.exp(-6.91 * t / rt60)
                 + 0.5 * band_noise(rng, n, 2500, 9000) * np.exp(-6.91 * t / (rt60 * 0.4)))
            y = np.concatenate([np.zeros(pre), y * ramp_in(n, 0.006)])[:n]
            ir[ch] = y / np.sqrt(np.sum(y * y))
        _ROOM = ir
    return _ROOM


def master(m, level, wet=0.22, fade=0.03):
    """Room, 40 Hz high-pass (no DC), gentle 11 kHz low-pass (no harsh highs), click-free
    edges, then the gain that brings the sound to `level`, under the true-peak ceiling."""
    ir = room()
    x = m.dry + wet * np.stack([fftconv(m.send, ir[0]), fftconv(m.send, ir[1])])
    x = biquad(x, *rbj("hp", 40))
    x = biquad(x, *rbj("lp", 11000, 0.6))
    x = x * ramp_in(m.n, 0.001) * ramp_out(m.n, fade)
    x = x * 10 ** ((level - active_loudness(x)) / 20)
    peak = true_peak_db(x)
    if peak > CEILING:
        x = x * 10 ** ((CEILING - peak) / 20)
    return x


def write_wav(path, x):
    pcm = np.clip(np.round(x.T * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# MARK: - The sounds

SOUNDS = {}


def sound(wet=0.22, fade=0.03):
    def register(fn):
        SOUNDS[fn.__name__.rstrip("_")] = (fn, wet, fade)  # open_ -> open
        return fn
    return register


@sound(wet=0.06, fade=0.015)
def hover(m):
    """Pointer over the island: a felt tap on a small wooden block."""
    m.add(wood(1650, tau=0.009), verb=0.3)
    m.add(tap(m.rng, 3000, 0.006), gain=0.25, verb=0.3)


@sound(wet=0.05, fade=0.012)
def tick(m):
    """Progress and capture ticks: a crisp, tiny woody click."""
    m.add(tap(m.rng, 3600, 0.008), verb=0.3)
    m.add(wood(2350, tau=0.005), gain=0.5, verb=0.3)


@sound(wet=0.08, fade=0.02)
def blip(m):
    """Dictation and notes start: a small bell blip that lifts into D6."""
    m.add(chirp(1050, hz("D6"), 0.015, 0.03, harmonic=0.08), verb=0.4)


@sound(wet=0.14, fade=0.03)
def wink(m):
    """A wink: a felt tick, then a bell that flicks up to B5, a sparkle on top."""
    m.add(wood(2000, tau=0.006), gain=0.35, pan=0.1)
    m.add(chirp(hz("A5"), hz("B5"), 0.025, 0.07, harmonic=0.1), at=0.035, pan=0.25)
    m.add(bell("F#6", tau=0.06), at=0.07, gain=0.25, pan=0.35)


@sound(wet=0.16)
def pop(m):
    """Something pops up: Koru's beak pops open, the bar answers F#5."""
    m.add(tap(m.rng, 1500, 0.005), gain=0.15)
    m.add(chirp(330, 700, 0.022, 0.06, harmonic=0.08))
    m.add(marimba(m.rng, "F#5", mute=0.5), at=0.012, gain=0.35)


@sound()
def peek(m):
    """Koru peeks out: a breath, then a grace note A4 -> D5."""
    m.add(puff(m.rng, 0.09, 700, 2200), gain=0.2)
    m.add(marimba(m.rng, "A4", vel=0.7, mute=0.7), at=0.0, pan=-0.15)
    m.add(marimba(m.rng, "D5", vel=0.9), at=0.07, pan=0.15)


@sound()
def open_(m):
    """The island opens: a rising breath of air, D5 on the bar, A5 on a bell."""
    m.add(whoosh(m.rng, 0.24, 500, 2200), gain=0.35, pan=np.linspace(-0.3, 0.3, frames(0.24)))
    m.add(marimba(m.rng, "D5", vel=0.7), at=0.10)
    m.add(bell("A5", vel=0.5, tau=0.18), at=0.16, pan=0.2)


@sound()
def close(m):
    """The island closes: the air falls back, A4 -> D4, damped."""
    m.add(whoosh(m.rng, 0.2, 2000, 450), gain=0.3, pan=np.linspace(0.3, -0.3, frames(0.2)))
    m.add(marimba(m.rng, "A4", vel=0.6, mute=0.7), at=0.06)
    m.add(marimba(m.rng, "D4", vel=0.7, mute=0.6), at=0.15)


@sound(wet=0.18)
def work(m):
    """An agent gets to work: a quick staccato D5 F#5 A5, left to right."""
    for i, (note, vel) in enumerate((("D5", 0.8), ("F#5", 0.75), ("A5", 0.9))):
        m.add(marimba(m.rng, note, vel=vel, mute=0.45), at=0.055 * i, pan=-0.2 + 0.2 * i)


@sound()
def think(m):
    """Thinking: a closed-mouth hum under two damped notes, B4 then D5."""
    m.add(hoot(m.rng, "A4", "B4", 0.3, breath=0.05, scoop=0.3, bright=0.05), gain=0.35)
    m.add(marimba(m.rng, "B4", vel=0.55, mute=0.6))
    m.add(marimba(m.rng, "D5", vel=0.55, mute=0.6), at=0.14)
    m.add(bell("F#5", tau=0.15), at=0.14, gain=0.2, pan=0.2)


@sound()
def search(m):
    """Searching: Koru looks left, right, left, then spots it."""
    for i, (note, pan) in enumerate((("E5", -0.5), ("A5", 0.5), ("E5", -0.2))):
        m.add(marimba(m.rng, note, vel=0.6, mute=0.55), at=0.09 * i, pan=pan)
    m.add(bell("B5", vel=0.35, tau=0.1), at=0.27, pan=0.15)


@sound(wet=0.24)
def approval(m):
    """Needs your OK: a gentle two-bell call A5 -> D6 over D5 and A5 on the bar."""
    m.add(marimba(m.rng, "D5", vel=0.6), pan=-0.1)
    m.add(bell("A5", vel=0.9, tau=0.3), pan=-0.1)
    m.add(marimba(m.rng, "A5", vel=0.6), at=0.14, pan=0.1)
    m.add(bell("D6", vel=1.0, tau=0.3), at=0.14, pan=0.1)


@sound(wet=0.24)
def question(m):
    """A question: Koru's "hoo?" rising D5 -> A5, landing on a bell."""
    m.add(marimba(m.rng, "E5", vel=0.5, mute=0.7), pan=-0.1)
    m.add(hoot(m.rng, "D5", "A5", 0.36, breath=0.16), at=0.05)
    m.add(bell("A5", vel=0.3, tau=0.15), at=0.36, pan=0.15)


@sound(wet=0.2)
def approve(m):
    """You said yes: F#5 A5 D6 up the bar, a bell on top."""
    for i, note in enumerate(("F#5", "A5", "D6")):
        m.add(marimba(m.rng, note, vel=0.75 + 0.1 * i, mute=0.7), at=0.06 * i, pan=-0.15 + 0.15 * i)
    m.add(bell("D6", vel=0.6, tau=0.25), at=0.12, pan=0.15)


@sound(wet=0.2, fade=0.05)
def error(m):
    """Something failed: a soft "uh-oh", G4 -> E4 bending down, on damped bars and a low knock."""
    m.add(marimba(m.rng, "G4", vel=0.7, mute=0.6))
    m.add(hoot(m.rng, "G4", "G4", 0.12, vel=0.45, breath=0.12), at=0.005)
    m.add(marimba(m.rng, "E4", vel=0.8, mute=0.6), at=0.16)
    m.add(hoot(m.rng, "E4", 300, 0.34, vel=0.5, breath=0.14), at=0.165)
    m.add(thump(110, 80, 0.06), at=0.16, gain=0.3)


@sound(wet=0.26, fade=0.06)
def finish(m):
    """Done: A4 D5 F#5 A5 up the bar, resolving into a ringing D6 and A5."""
    for i, note in enumerate(("A4", "D5", "F#5", "A5")):
        m.add(marimba(m.rng, note, vel=0.6 + 0.1 * i), at=0.07 * i, pan=-0.2 + 0.13 * i)
    m.add(bell("D6", vel=0.8, tau=0.3), at=0.21, pan=0.1)
    m.add(bell("A5", vel=0.4, tau=0.3), at=0.21, pan=-0.1)


@sound(wet=0.2)
def rate(m):
    """Rate limit: B4 A4 F#4, damped and slowing down."""
    for note, at, vel in (("B4", 0.0, 0.8), ("A4", 0.13, 0.65), ("F#4", 0.3, 0.55)):
        m.add(marimba(m.rng, note, vel=vel, mute=0.6), at=at)


@sound(wet=0.2, fade=0.05)
def sleep(m):
    """Falling asleep: a breathy hoot sinking A4 -> D4."""
    m.add(hoot(m.rng, "A4", "D4", 0.4, breath=0.35, scoop=0.0, bright=0.06))


@sound(wet=0.2, fade=0.06)
def yawn(m):
    """A yawn: "hooaah", F#5 sliding down to A4 as the beak opens and closes."""
    n = frames(0.62)
    t = time(n)
    y = hoot(m.rng, "F#5", "A4", 0.62, breath=0.4, scoop=0.0, bright=0.05)
    # The beak opening: a brighter, wider "aa" in the middle.
    wide = hoot(m.rng, "F#5", "A4", 0.62, breath=0.0, scoop=0.0, bright=0.35)
    m.add(y + 0.5 * wide * np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 2)


@sound(wet=0.26)
def love(m):
    """Petted: a warm "hoo" with vibrato, then F#5 and B5 bells (a sweet sixth), D6 above."""
    m.add(marimba(m.rng, "D4", vel=0.35))
    m.add(hoot(m.rng, "D5", "D5", 0.4, breath=0.15, vibrato=0.25))
    m.add(bell("F#5", vel=0.5, tau=0.25), at=0.18, pan=-0.2)
    m.add(bell("B5", vel=0.6, tau=0.25), at=0.30, pan=0.2)
    m.add(bell("D6", vel=0.35, tau=0.18), at=0.42, pan=0.3)


@sound(wet=0.24, fade=0.05)
def proud(m):
    """What's new: a little fanfare D5 F#5 A5 D6, crowned with D6 and F#6 bells."""
    for i, note in enumerate(("D5", "F#5", "A5", "D6")):
        m.add(marimba(m.rng, note, vel=0.65 + 0.1 * i), at=0.08 * i, pan=-0.2 + 0.13 * i)
    m.add(bell("D6", vel=0.6, tau=0.3), at=0.24)
    m.add(bell("F#6", vel=0.3, tau=0.25), at=0.24, pan=0.25)


@sound(wet=0.18)
def slap(m):
    """Slapped: a soft velvet thwap, ruffled feathers, a startled little "hu!"."""
    n = frames(0.12)
    m.add(band_noise(m.rng, n, 300, 2500) * np.exp(-time(n) / 0.025) * edges(n, 0.001, 0.02), gain=0.9)
    m.add(thump(150, 70, 0.06), gain=0.8)
    m.add(feathers(m.rng, 0.25, (0.06, 0.12), 800, 3500), gain=0.3, pan=0.2)
    m.add(hoot(m.rng, "A5", "B5", 0.08, breath=0.1, scoop=1.0), at=0.09, gain=0.35, pan=-0.1)


@sound(wet=0.16, fade=0.05)
def annoyed(m):
    """Annoyed: "hm-PH-mm", a low grumbling hum, a puff, a growl falling to F#3."""
    m.add(hoot(m.rng, "B3", "A3", 0.14, breath=0.2, bright=0.25))
    m.add(puff(m.rng, 0.06, 600, 1800, attack=0.006), at=0.15, gain=0.45)
    n = frames(0.26)
    growl = 1 - 0.35 * (0.5 + 0.5 * np.sin(2 * np.pi * 28 * time(n)))
    m.add(hoot(m.rng, "A3", "F#3", 0.26, breath=0.25, bright=0.3, scoop=0.0) * growl, at=0.22)


@sound(wet=0.24, fade=0.08)
def dizzy(m):
    """Dizzy: notes tumbling B5 -> D5 around the head, under a wobbling "wooo"."""
    for i, (note, vel) in enumerate((("B5", 0.5), ("A5", 0.46), ("F#5", 0.42), ("E5", 0.38), ("D5", 0.35))):
        m.add(marimba(m.rng, note, vel=vel, mute=0.7), at=0.11 * i, pan=0.5 if i % 2 else -0.5)
    n = frames(0.8)
    m.add(hoot(m.rng, "A5", "D5", 0.8, vel=0.5, breath=0.05, vibrato=0.7, rate=7.0, scoop=0.0, bright=0.08),
          pan=0.6 * np.sin(2 * np.pi * 2.2 * time(n)))
    m.add(wood(900, tau=0.02), at=0.62, gain=0.35)


@sound(wet=0.18)
def send(m):
    """Sent: two wing flaps carry it off, A5 -> D6."""
    n = frames(0.2)
    m.add(feathers(m.rng, 0.2, (0.0, 0.07), 600, 3000), gain=0.35, pan=np.linspace(-0.4, 0.6, n))
    m.add(whoosh(m.rng, 0.18, 600, 2600), gain=0.3, pan=np.linspace(-0.4, 0.6, frames(0.18)))
    m.add(marimba(m.rng, "A5", vel=0.6, mute=0.6), at=0.12, pan=0.3)
    m.add(marimba(m.rng, "D6", vel=0.7, mute=0.7), at=0.18, pan=0.5)


@sound(wet=0.24, fade=0.06)
def attach(m):
    """Attached: a two-click clasp, E5 -> A5 on the bar, a ringing A5 bell."""
    m.add(wood(1500, tau=0.008), gain=0.6, pan=-0.1)
    m.add(wood(1900, tau=0.008), at=0.05, gain=0.6, pan=0.1)
    m.add(marimba(m.rng, "E5", vel=0.6), at=0.08)
    m.add(marimba(m.rng, "A5", vel=0.7), at=0.16)
    m.add(bell("A5", vel=0.5, tau=0.3), at=0.16)
    m.add(bell("E6", vel=0.15, tau=0.2), at=0.16, pan=0.3)


@sound(wet=0.16, fade=0.05)
def gulp(m):
    """Koru swallows a file: "gl", a falling gulp, a smaller one, the beak closing, a content "mm"."""
    n = frames(0.03)
    m.add(band_noise(m.rng, n, 500, 1500) * ramp_in(n, 0.005) * ramp_out(n, 0.02), gain=0.3)
    m.add(chirp(480, 160, 0.14, 0.09, harmonic=0.2), at=0.03)
    m.add(chirp(360, 140, 0.1, 0.06, harmonic=0.15), at=0.2, gain=0.5)
    m.add(chirp(170, 420, 0.03, 0.04), at=0.32, gain=0.5)
    m.add(hoot(m.rng, "D4", "D4", 0.18, breath=0.1, scoop=0.3), at=0.42, gain=0.3)


@sound(wet=0.28, fade=0.06)
def greet(m):
    """Hello: Koru's motif, a short "hoo" on E5 and a longer one on D5, D4 and A4 underneath."""
    m.add(hoot(m.rng, "E5", "E5", 0.13), pan=-0.05)
    m.add(hoot(m.rng, "D5", 570, 0.36, vibrato=0.15), at=0.17, pan=0.05)
    m.add(marimba(m.rng, "D4", vel=0.35), at=0.17, pan=-0.2)
    m.add(marimba(m.rng, "A4", vel=0.3), at=0.17, pan=0.2)
    m.add(bell("D6", vel=0.12, tau=0.3), at=0.17)


@sound(wet=0.3, fade=0.15)
def greeting(m):
    """The first greeting (GreetingCanvasView, 4.6 s): falls in, lands, bounces, waves hello
    with the motif, tucks in with a badge, slides down, blinks, glows blue."""
    # 0-0.55 s: falls in through the warp streaks, a pentatonic shimmer coming down.
    m.add(whoosh(m.rng, 0.5, 3000, 700), gain=0.25)
    for i, note in enumerate(("D6", "B5", "A5", "F#5", "E5", "D5")):
        m.add(bell(note, vel=0.25 + 0.02 * i, tau=0.2), at=0.05 + 0.07 * i, pan=0.4 if i % 2 else -0.4)
    m.add(bell("A6", vel=0.15, tau=0.25), at=0.45, pan=0.3)  # burst ring
    # 0.58 lands, 0.73 bounces.
    m.add(thump(130, 75, 0.06), at=0.58, gain=0.5)
    m.add(marimba(m.rng, "D4", vel=0.7), at=0.58)
    m.add(marimba(m.rng, "A4", vel=0.5, mute=0.6), at=0.73)
    # 1.30 plunges, 1.38 springs up.
    m.add(marimba(m.rng, "D4", vel=0.5, mute=0.7), at=1.30)
    m.add(thump(120, 70, 0.05), at=1.30, gain=0.3)
    m.add(chirp(250, 520, 0.05, 0.05), at=1.38, gain=0.4)
    # 1.45 waves hello: the motif, then a little run while the hand waves.
    m.add(hoot(m.rng, "E5", "E5", 0.13), at=1.45, pan=-0.05)
    m.add(hoot(m.rng, "D5", "D5", 0.38, vibrato=0.15), at=1.62, pan=0.05)
    m.add(marimba(m.rng, "D4", vel=0.35), at=1.62, pan=-0.2)
    m.add(marimba(m.rng, "A4", vel=0.3), at=1.62, pan=0.2)
    for i, note in enumerate(("D5", "F#5", "A5")):
        m.add(marimba(m.rng, note, vel=0.4), at=2.0 + 0.08 * i, pan=-0.2 + 0.2 * i)
    # 2.70 sinks to tuck in, 2.72 the badge.
    m.add(wood(1400, tau=0.01), at=2.70, gain=0.3)
    m.add(marimba(m.rng, "A5", vel=0.4), at=2.72)
    m.add(bell("D6", vel=0.45, tau=0.35), at=2.72, pan=0.15)
    m.add(bell("F#6", vel=0.25, tau=0.3), at=2.72, pan=0.3)
    # 2.85-3.45 slides down.
    for i, note in enumerate(("A5", "F#5", "E5", "D5", "B4", "A4")):
        m.add(marimba(m.rng, note, vel=0.4 - 0.02 * i, mute=0.8), at=2.85 + 0.1 * i, pan=0.4 - 0.12 * i)
    # 3.70 blinks.
    m.add(wood(2000, tau=0.006), at=3.70, gain=0.3)
    # 3.85-4.15 the blue glow: a soft D chord fading out.
    for note, vel in (("D5", 0.3), ("A5", 0.25), ("D6", 0.2)):
        m.add(bell(note, vel=vel, tau=0.15), at=3.82)


def render(name):
    fn, wet, fade = SOUNDS[name]
    m = Mix(name)
    fn(m)
    return master(m, LEVEL[name], wet, fade)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--only", help="comma-separated names")
    args = parser.parse_args()
    assert set(SOUNDS) == set(FRAMES) == set(LEVEL), "every sound needs its frames and level"
    names = args.only.split(",") if args.only else sorted(SOUNDS)
    args.out.mkdir(parents=True, exist_ok=True)
    for name in names:
        x = render(name)
        write_wav(args.out / f"{name}.wav", x)
        print(f"{name:9s} {x.shape[-1] / SR:6.3f} s  {active_loudness(x):6.1f} LKFS-a  {true_peak_db(x):6.1f} dBTP")


if __name__ == "__main__":
    main()
