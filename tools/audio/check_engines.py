"""Render every engine loop to WAV and check it objectively:
- firing pattern: pulse intervals recovered from the audio envelope vs. the layout
- seam: jump at the loop wrap vs. typical sample-to-sample change
- phone band: share of energy 300 Hz-4 kHz (what a phone speaker can reproduce)
"""
import sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

from dsp import SR, sos_bp, sos_lp, lufs
import engines

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/engines"
import os
os.makedirs(out, exist_ok=True)

for name, p in engines.ENGINES.items():
    for state in ("idle", "cruise"):
        y, meta = engines.render(name, state)
        wavfile.write(f"{out}/{name}_{state}.wav", SR, (y * 32767).astype(np.int16))
        # Envelope-based pulse detection on 2 loops back-to-back.
        yy = np.concatenate([y, y])
        env = np.abs(signal.hilbert(signal.sosfilt(sos_bp(150, 3000), yy)))
        env = signal.sosfiltfilt(sos_lp(min(400, meta["fire_hz"] * 4)), env)
        min_gap = int(SR / meta["fire_hz"] * 0.45)
        pk, _ = signal.find_peaks(env, distance=min_gap, prominence=np.std(env) * 0.5)
        iv = np.diff(pk) / SR * 1000.0
        cyc_ms = 1000.0 * (2 if p["strokes"] == 4 else 1) * 60.0 / meta["rpm"]
        expected = sorted({round(cyc_ms * ((b - a) % (720 if p["strokes"] == 4 else 360)) / (720 if p["strokes"] == 4 else 360), 1)
                           for a, b in zip(p["fire"], p["fire"][1:] + [p["fire"][0]])})
        if len(iv):
            hist = np.round(np.percentile(iv, [20, 50, 80]), 1)
        else:
            hist = []
        d = np.abs(np.diff(y))
        seam = (d < abs(y[0] - y[-1])).mean() * 100  # percentile of the wrap step among all steps
        f, P = signal.welch(y, SR, nperseg=8192)
        phone = P[(f > 300) & (f < 4000)].sum() / P.sum()
        cent = (f * P).sum() / P.sum()
        print(f"{name:9s} {state:6s} rpm={meta['rpm']:5d} fire={meta['fire_hz']:6.1f}Hz loop={meta['seconds']:.2f}s "
              f"expect_ms={expected} got_ms(p20/50/80)={list(hist)} seam=p{seam:5.1f} "
              f"phone={phone*100:4.1f}% centroid={cent:5.0f}Hz lufs={lufs(y):5.1f} peak={20*np.log10(np.max(np.abs(y))):5.1f}")
