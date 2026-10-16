"""Turn the found nature recordings into seamless ambience loops.

For each recording, pick the loop window whose head and tail match best (RMS and
spectral balance), so the equal-power crossfade at the seam is inaudible.
"""
import numpy as np
from scipy import signal

from dsp import (SR, sos_hp, sos_lp, sos_bp, peak, sosc, make_ir, conv_reverb, loop_xfade, norm_lufs,
                 read_audio, soft_clip)

# name: (source file, loop seconds, crossfade seconds, target LUFS, highpass Hz)
SPECS = {
    "day_birds": ("birds.ogg", 26.0, 3.0, -30.0, 180),
    "night_crickets": ("summer-night.ogg", 24.0, 3.0, -31.0, 250),
    "wind": ("wind.ogg", 11.0, 2.5, -27.0, 80),
    "rain": ("rain.ogg", 22.0, 3.0, -25.0, 120),
    "creek": ("stream.ogg", 22.0, 3.0, -33.0, 150),
}


def _profile(x):
    mono = x.mean(axis=1) if x.ndim > 1 else x
    rms = np.sqrt(np.mean(mono ** 2)) + 1e-12
    f, p = signal.welch(mono, SR, nperseg=2048)
    cent = (f * p).sum() / (p.sum() + 1e-12)
    return np.log(rms), np.log(cent + 1)


def best_start(x, length, xf, step=0.5):
    n_total = x.shape[0] / SR
    best, best_s = 1e9, 0.0
    s = 1.0
    while s + length + xf < n_total - 0.5:
        a = x[int(s * SR):int((s + xf) * SR)]
        b = x[int((s + length) * SR):int((s + length + xf) * SR)]
        pa, pb = _profile(a), _profile(b)
        # Also avoid windows with big loudness swings inside the seam regions.
        score = abs(pa[0] - pb[0]) + 0.5 * abs(pa[1] - pb[1])
        if score < best:
            best, best_s = score, s
        s += step
    return best_s, best


def build(blanket_dir):
    out, info = {}, {}
    for name, (src, length, xf, target, hp) in SPECS.items():
        x = read_audio(f"{blanket_dir}/{src}")
        x = signal.sosfilt(sos_hp(hp), x, axis=0)
        length = min(length, x.shape[0] / SR - xf - 2.0)
        s, score = best_start(x, length, xf)
        y = loop_xfade(x, s, length, xf)
        y = y.mean(axis=1) if y.ndim > 1 else y  # mono: halves the size; phone speakers are mono anyway
        y = norm_lufs(y, target - 3.0)  # mono plays on both channels (+3 dB), keep the same in-game level
        out[name] = y
        info[name] = {"start": s, "seconds": round(length, 2), "seam_score": round(score, 3)}
    beds = synth_beds()
    out.update(beds)
    for k in beds:
        info[k] = {"seconds": BED_SECONDS, "synth": True}
    return out, info


# --- synthesized trail beds ------------------------------------------------------
# Built as loops from the start: noise is filtered circularly and events wrap around
# the end, so there is no seam to hide.
BED_SECONDS = 16.0
BED_TARGET = {"mine": -31.0, "yard": -31.0, "canyon": -30.0, "alpine": -30.0, "collapse": -29.0}


def _wrap_add(buf, x, at):
    i = int(at * SR) % len(buf)
    idx = (i + np.arange(len(x))) % len(buf)
    np.add.at(buf, idx, x)


def _slow(n, rng, rate_hz, depth):
    """Smooth random-ish loopable modulation 1 +/- depth from a few sines on whole cycles."""
    t = np.arange(n) / SR
    m = np.zeros(n)
    for k in range(3):
        cyc = max(1, round(rate_hz * (1 + k * 0.7) * n / SR))
        m += np.sin(2 * np.pi * cyc * t / (n / SR) + rng.uniform(0, 6.3)) / (k + 1)
    return 1.0 + depth * m / 1.83


def _sweep_bp(x, centers, q=4.0, bands=8):
    """Band-pass whose centre follows `centers`: a few fixed circular band-passes,
    crossfaded smoothly by where the centre sits between them (no block clicks)."""
    lo, hi = float(np.min(centers)), float(np.max(centers))
    fcs = np.geomspace(max(40.0, lo), hi + 1.0, bands)
    outs = [sosc(sos_bp(fc * (1 - 0.5 / q), fc * (1 + 0.5 / q)), x) for fc in fcs]
    pos = np.interp(np.log(centers), np.log(fcs), np.arange(bands))
    y = np.zeros(len(x))
    for k in range(bands):
        w = np.clip(1.0 - np.abs(pos - k), 0.0, 1.0)
        y += w * outs[k]
    return y


def synth_beds():
    n = int(BED_SECONDS * SR)
    rng = np.random.default_rng(4242)
    out = {}
    t = np.arange(n) / SR

    # Lantern Mine: deep rumble, slow drips echoing off rock, a timber creak now and then.
    rumble = sosc(sos_lp(110), rng.standard_normal(n)) * _slow(n, rng, 0.08, 0.35)
    mine = 2.2 * rumble
    ir = make_ir(1.8, 2200, 30, seed=5, stereo=False)
    drips = np.zeros(n)
    for k in range(9):
        td = np.arange(int(0.06 * SR)) / SR
        f0 = rng.uniform(1300, 2200)
        blip = np.sin(2 * np.pi * np.cumsum(f0 * (1 - 0.45 * td / td[-1])) / SR) * np.exp(-td / 0.012)
        _wrap_add(drips, blip * rng.uniform(0.25, 0.6), rng.uniform(0, BED_SECONDS))
    for k in range(2):
        tc = np.arange(int(0.9 * SR)) / SR
        creak = sosc(sos_bp(300, 900), rng.standard_normal(len(tc)))
        creak *= (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (18 + 10 * tc) * tc))) * np.sin(np.pi * tc / tc[-1]) ** 2
        _wrap_add(drips, 0.22 * creak, rng.uniform(0, BED_SECONDS))
    wet = conv_reverb(drips, np.stack([ir, ir], 1), 0.55, circular=True).mean(axis=1)
    out["mine"] = mine + wet

    # Rustyard / Hoist Yard: machine hum, distant metal clanks in a big shed, steam hiss.
    hum = sum(np.sin(2 * np.pi * h * 50.0 * t) / h for h in (1, 2, 3, 5)) * 0.04 * _slow(n, rng, 0.1, 0.3)
    ev = np.zeros(n)
    for k in range(7):
        tk = np.arange(int(1.2 * SR)) / SR
        f = rng.uniform(220, 480)
        clank = sum(np.sin(2 * np.pi * f * r * tk) * np.exp(-tk / (0.35 / r)) / r for r in (1.0, 2.76, 5.4, 8.93))
        clank *= 1 - np.exp(-tk / 0.002)
        _wrap_add(ev, clank * rng.uniform(0.15, 0.35), rng.uniform(0, BED_SECONDS))
    for k in range(3):
        th = np.arange(int(1.6 * SR)) / SR
        hiss = sosc(sos_hp(2500), rng.standard_normal(len(th))) * np.minimum(1, th / 0.05) * np.exp(-th / 0.5)
        _wrap_add(ev, 0.12 * hiss, rng.uniform(0, BED_SECONDS))
    yard_ir = make_ir(2.6, 2600, 40, seed=6)
    out["yard"] = hum + conv_reverb(ev, yard_ir, 0.6, circular=True).mean(axis=1) \
        + 0.3 * sosc(sos_lp(300), rng.standard_normal(n)) * _slow(n, rng, 0.06, 0.4)

    # Copper Canyon / Hoodoo Loops: hollow wind moaning through rock.
    pink = sosc(sos_lp(900), rng.standard_normal(n))
    centers = 380 + 220 * (_slow(n, rng, 0.07, 1.0) - 1.0)
    moan = _sweep_bp(pink, centers, q=6.0) * _slow(n, rng, 0.09, 0.5)
    out["canyon"] = moan + 0.25 * sosc(sos_lp(200), rng.standard_normal(n))

    # Skyline Pass: thin, high mountain wind with a faint whistle on the gusts.
    gust = _slow(n, rng, 0.11, 0.6)
    air = sosc(sos_bp(700, 3200), rng.standard_normal(n)) * gust
    centers = 1500 + 500 * (_slow(n, rng, 0.05, 1.0) - 1.0)
    whistle = _sweep_bp(rng.standard_normal(n), centers, q=24.0) * np.clip(gust - 1.0, 0, None) * 3.0
    out["alpine"] = air + whistle

    # Last Trestle: the collapse behind you. Deep rumble, timbers snapping, debris.
    rum = sosc(sos_lp(90), rng.standard_normal(n)) * _slow(n, rng, 0.2, 0.5) * 2.5
    ev2 = np.zeros(n)
    for k in range(14):
        tk = np.arange(int(0.5 * SR)) / SR
        snap = sosc(sos_bp(400, 3000), rng.standard_normal(len(tk))) * np.exp(-tk / 0.03)
        snap += 0.6 * np.sin(2 * np.pi * rng.uniform(150, 300) * tk) * np.exp(-tk / 0.1)
        _wrap_add(ev2, snap * rng.uniform(0.2, 0.5), rng.uniform(0, BED_SECONDS))
    col_ir = make_ir(2.0, 1800, 30, seed=8)
    out["collapse"] = rum + conv_reverb(ev2, col_ir, 0.5, circular=True).mean(axis=1)

    for k in out:
        y = soft_clip(out[k] / (np.max(np.abs(out[k])) + 1e-9), 1.0)
        out[k] = norm_lufs(y, BED_TARGET[k] - 3.0)
    return out
