"""Turn the found nature recordings into seamless ambience loops.

For each recording, pick the loop window whose head and tail match best (RMS and
spectral balance), so the equal-power crossfade at the seam is inaudible.
"""
import numpy as np
from scipy import signal

from dsp import SR, sos_hp, loop_xfade, norm_lufs, read_audio

# name: (source file, loop seconds, crossfade seconds, target LUFS, highpass Hz)
SPECS = {
    "day_birds": ("birds.ogg", 48.0, 3.0, -30.0, 180),
    "night_crickets": ("summer-night.ogg", 42.0, 3.0, -31.0, 250),
    "wind": ("wind.ogg", 11.0, 2.5, -27.0, 80),
    "rain": ("rain.ogg", 44.0, 3.0, -25.0, 120),
    "creek": ("stream.ogg", 36.0, 3.0, -33.0, 150),
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
    return out, info
