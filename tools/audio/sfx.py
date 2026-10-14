"""Game SFX: soft, reverb-tailed and tuned to D major pentatonic so pickups,
checkpoints and the finish jingle sit inside the theme instead of fighting it.
Kenney CC0 recordings are layered in for the physical hits (landing, crash, UI).
"""
import numpy as np
from scipy import signal

from dsp import (SR, midi_hz, sos_lp, sos_hp, sos_bp, sosc, make_ir, conv_reverb, pad_tail, norm_lufs,
                 norm_peak, read_audio)

RNG = np.random.default_rng(42)
IR_SHORT = make_ir(1.4, 4000, 12, seed=3)
IR_LONG = make_ir(2.6, 3200, 20, seed=5)


def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def release(y, frac=0.3):
    """Cosine fade over the last part so a note never stops while still ringing."""
    n = max(16, int(len(y) * frac))
    y = y.copy()
    y[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    return y


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]
    return buf


# --- voices ----------------------------------------------------------------------

def chime(f, dur=1.4, bright=1.0, decay=1.0):
    """Celesta / kalimba hybrid: soft mallet, octave partial, faint tine overtones."""
    t = _t(dur)
    y = np.zeros_like(t)
    for ratio, amp, dec in ((1.0, 1.0, 1.1), (2.0, 0.16, 0.45), (3.0, 0.05, 0.22),
                            (5.4, 0.04 * bright, 0.07), (8.9, 0.015 * bright, 0.035)):
        y += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (dec * decay))
    y += 0.25 * np.sin(2 * np.pi * f * 1.0017 * t) * np.exp(-t / (0.9 * decay))  # shimmer
    y *= 1 - np.exp(-t / 0.002)
    click = RNG.standard_normal(int(0.004 * SR)) * np.linspace(1, 0, int(0.004 * SR)) * 0.08
    y[: len(click)] += signal.sosfilt(sos_lp(3000), click)
    return release(y)


def wood(f, dur=0.35, decay=1.0):
    """Marimba-like tuned bar (partials 1, 3.9, 9.2) for soft wooden knocks."""
    t = _t(dur)
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / (0.12 * decay))
         + 0.35 * np.sin(2 * np.pi * f * 3.9 * t) * np.exp(-t / (0.03 * decay))
         + 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / (0.012 * decay)))
    return release(y * (1 - np.exp(-t / 0.0015)), 0.2)


def thock(dur=0.4, low=140.0):
    """Wooden deck hit: damped modes + a short noise transient + sub thump."""
    t = _t(dur)
    y = np.zeros_like(t)
    for f, a, d in ((low, 1.0, 0.09), (low * 2.2, 0.6, 0.06), (low * 4.9, 0.3, 0.035), (low * 10.3, 0.12, 0.014)):
        y += a * np.sin(2 * np.pi * f * t + RNG.random()) * np.exp(-t / d)
    y += 0.8 * np.sin(2 * np.pi * 68 * t) * np.exp(-t / 0.07)
    n = int(0.006 * SR)
    y[:n] += signal.sosfilt(sos_lp(2500), RNG.standard_normal(n)) * np.linspace(1, 0, n) * 0.6
    return release(y * (1 - np.exp(-t / 0.001)), 0.2)


def pluck(f, dur=2.5, bright=0.55, t60=2.2, pick=0.18):
    """Karplus-Strong string with fractional-delay tuning (allpass in the loop)."""
    nf = SR / f - 0.5
    n = int(nf)
    frac = nf - n
    c = (1 - frac) / (1 + frac)
    g = 10 ** (-3.0 / (t60 * f))
    a = np.zeros(n + 3)
    a[0] = 1.0
    a[1] += c
    a[n] -= 0.5 * g * c
    a[n + 1] -= 0.5 * g * (1 + c)
    a[n + 2] -= 0.5 * g
    ex = RNG.standard_normal(n)
    ex = signal.lfilter([1 - bright], [1, -bright], ex)  # softer pick = darker
    k = max(1, int(pick * n))
    ex[k:] -= ex[:-k] * 0.9  # pick position comb
    x = np.zeros(int(dur * SR))
    x[:n] = ex
    y = signal.lfilter([1.0, c], a, x)
    return release(y / (np.max(np.abs(y)) + 1e-9), 0.15)


def whoosh(dur=0.45, f0=320, f1=1150, peak_at=0.13):
    """Noise shaped by a moving spectral band (STFT mask) - soft air past the rider."""
    n = int(dur * SR)
    noise = RNG.standard_normal(n)
    f, tt, Z = signal.stft(noise, SR, nperseg=512)
    fc = f0 + (f1 - f0) * np.clip(tt / dur, 0, 1)
    mask = np.exp(-0.5 * ((f[:, None] - fc[None, :]) / (0.45 * fc[None, :])) ** 2)
    _, y = signal.istft(Z * mask, SR, nperseg=512)
    y = y[:n]
    t = _t(dur)
    env = np.where(t < peak_at, (t / peak_at) ** 1.5, np.exp(-(t - peak_at) / 0.11))
    return y * env


def sparkle(dur=1.2, count=10, lo=2400, hi=5200):
    buf = np.zeros(int(dur * SR))
    for _ in range(count):
        f = RNG.uniform(lo, hi)
        at = RNG.uniform(0, dur * 0.6)
        place(buf, 0.12 * chime(f, 0.5, bright=0.2, decay=0.25), at)
    return buf


# --- finished sounds -------------------------------------------------------------

def _finish(x, ir=IR_SHORT, wet=0.3, tail=0.8, lufs=-20.0, hp=90):
    x = signal.sosfilt(sos_hp(hp), x)
    x = conv_reverb(pad_tail(x, tail), ir, wet)
    x = norm_lufs(x, lufs)
    return norm_peak(x, -1.0) if np.max(np.abs(x)) > db1 else x


db1 = 10 ** (-1 / 20)

D_PENT = [74, 76, 78, 81, 83, 86]  # D5 E5 F#5 A5 B5 D6


def build(kenney_dir):
    k_land = read_audio(f"{kenney_dir}/Starter-Kit-3D-Platformer/sounds/land.ogg", mono=True)
    k_impact = read_audio(f"{kenney_dir}/Starter-Kit-Racing/audio/impact.ogg", mono=True)
    k_break = read_audio(f"{kenney_dir}/Starter-Kit-3D-Platformer/sounds/break.ogg", mono=True)
    k_tap = read_audio(f"{kenney_dir}/Starter-Kit-City-Builder/sounds/placement-a.ogg", mono=True)
    k_toggle = read_audio(f"{kenney_dir}/Starter-Kit-City-Builder/sounds/toggle.ogg", mono=True)

    out = {}
    # Coin: A5; the game steps it up the pentatonic for coin streaks.
    out["coin"] = _finish(chime(midi_hz(81), 0.9, bright=0.8, decay=0.6), wet=0.28, tail=0.6, lufs=-22)

    b = np.zeros(int(1.4 * SR))
    for i, m in enumerate([74, 78, 81, 86]):
        place(b, chime(midi_hz(m), 1.1, decay=0.7) * (0.8 + 0.07 * i), i * 0.055)
    place(b, 0.35 * chime(midi_hz(62), 1.2, bright=0.3), 0.0)
    out["bag"] = _finish(b, wet=0.32, lufs=-20)

    g = np.zeros(int(2.4 * SR))
    for i, m in enumerate([74, 78, 81, 85, 88]):  # Dmaj9 rolled
        place(g, chime(midi_hz(m), 1.8, decay=1.1) * 0.8, i * 0.085)
    place(g, 0.5 * chime(midi_hz(50 + 12), 2.0, bright=0.2, decay=1.4), 0.0)
    place(g, sparkle(1.6, 12), 0.25)
    out["gear"] = _finish(g, IR_LONG, wet=0.38, tail=1.2, lufs=-19)

    c = np.zeros(int(1.6 * SR))
    place(c, chime(midi_hz(81), 1.2), 0.0)
    place(c, chime(midi_hz(86), 1.4), 0.14)
    out["checkpoint"] = _finish(c, wet=0.33, lufs=-21)

    s = np.zeros(int(0.6 * SR))
    t = _t(0.25)
    fsw = 520 * np.exp(-t / 0.09) + 240
    place(s, np.sin(2 * np.pi * np.cumsum(fsw) / SR) * np.exp(-t / 0.08), 0.0)
    place(s, 0.6 * wood(midi_hz(74), 0.35), 0.02)
    place(s, 0.25 * whoosh(0.2, 600, 300, 0.03), 0.0)
    out["stomp"] = _finish(s, wet=0.22, tail=0.4, lufs=-21)

    out["jump"] = _finish(whoosh(0.45), wet=0.2, tail=0.3, lufs=-27, hp=150)

    l = np.zeros(int(0.5 * SR))
    place(l, thock(0.45), 0.0)
    place(l, 0.6 * k_land / (np.max(np.abs(k_land)) + 1e-9), 0.0)
    l = signal.sosfilt(sos_lp(3500), l)
    out["land"] = _finish(l, wet=0.18, tail=0.3, lufs=-24, hp=50)

    sp = np.zeros(int(0.7 * SR))
    place(sp, whoosh(0.25, 4200, 2200, 0.01) * 1.2, 0.0)
    for _ in range(9):
        place(sp, 0.25 * chime(RNG.uniform(1500, 3400), 0.12, bright=0.1, decay=0.05), RNG.uniform(0.02, 0.32))
    out["splash"] = _finish(sp, wet=0.2, tail=0.3, lufs=-27, hp=600)

    cr = np.zeros(int(2.6 * SR))
    imp = signal.sosfilt(sos_lp(2200), k_impact)
    place(cr, imp / (np.max(np.abs(imp)) + 1e-9), 0.0)
    brk = signal.sosfilt(sos_lp(1600), k_break)
    place(cr, 0.3 * brk / (np.max(np.abs(brk)) + 1e-9), 0.06)
    t = _t(0.6)
    place(cr, 0.9 * np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.3), 0.0)
    for at, lvl, lo in ((0.26, 0.45, 120), (0.43, 0.3, 160), (0.57, 0.18, 190)):
        place(cr, lvl * thock(0.3, lo), at)
    place(cr, 0.35 * chime(midi_hz(69), 1.4, bright=0.3), 0.42)   # A4
    place(cr, 0.32 * chime(midi_hz(66), 1.6, bright=0.3), 0.78)   # F#4: gentle "aww"
    out["crash"] = _finish(cr, IR_LONG, wet=0.3, tail=0.8, lufs=-19, hp=40)

    fin = np.zeros(int(4.0 * SR))
    for i, m in enumerate([50, 57, 61, 64, 66, 69]):  # Dmaj9 strum on the guitar voice
        place(fin, 0.5 * pluck(midi_hz(m), 3.5, t60=3.0), i * 0.035)
    for i, m in enumerate([81, 86, 90, 93]):  # A5 D6 F#6 A6
        place(fin, 0.5 * chime(midi_hz(m), 1.8, decay=1.0), 0.25 + i * 0.16)
    place(fin, sparkle(2.0, 14), 0.8)
    out["finish"] = _finish(fin, IR_LONG, wet=0.4, tail=1.5, lufs=-17)

    pu = np.zeros(int(1.4 * SR))
    for i, m in enumerate([90, 86, 81, 78, 74]):
        place(pu, chime(midi_hz(m), 1.0, decay=0.7) * 0.7, i * 0.045)
    for at in (0.0, 0.07, 0.15):
        f0 = RNG.uniform(3000, 3600)
        tt = _t(0.12)
        clink = sum(np.sin(2 * np.pi * f0 * r * tt) * np.exp(-tt / 0.035) for r in (1.0, 1.47, 2.03))
        place(pu, 0.08 * clink, at)
    out["purchase"] = _finish(pu, wet=0.3, lufs=-20)

    d = np.zeros(int(0.5 * SR))
    place(d, 0.8 * wood(midi_hz(67), 0.3), 0.0)
    place(d, 0.8 * wood(midi_hz(62), 0.35), 0.11)
    out["deny"] = _finish(d, wet=0.15, tail=0.3, lufs=-24)

    tap = signal.sosfilt(sos_lp(4000), k_tap)
    out["tap"] = _finish(tap, wet=0.08, tail=0.15, lufs=-26, hp=120)
    tog = signal.sosfilt(sos_lp(5000), k_toggle)
    out["toggle"] = _finish(np.pad(tog, (0, 400)), wet=0.08, tail=0.15, lufs=-28, hp=200)

    # Distant train horn: a D6 chord (D F# A B D) so it lands in the theme's key.
    th = np.zeros(int(4.6 * SR))
    for start, length, bend in ((0.0, 1.25, 1.0), (1.5, 1.7, 0.985)):
        tt = _t(length)
        env = np.minimum(1, tt / 0.09) * np.minimum(1, (length - tt) / 0.25)
        blast = np.zeros_like(tt)
        for m in (62, 66, 69, 71, 74):
            f = midi_hz(m) * bend * (1 + RNG.uniform(-0.002, 0.002))
            ph = 2 * np.pi * f * tt
            blast += sum((1.0 / k) * np.sin(k * ph) for k in (1, 3, 5, 7))
        place(th, blast * env, start)
    th = signal.sosfilt(sos_lp(1300), th)
    out["train_horn"] = _finish(th, IR_LONG, wet=0.55, tail=1.6, lufs=-25, hp=180)

    # Distant thunder: a soft crack then a long rolling rumble.
    n = int(4.5 * SR)
    brown = np.cumsum(RNG.standard_normal(n))
    brown = signal.sosfilt(sos_hp(25), brown)
    brown = signal.sosfilt(sos_lp(220), brown)
    tt = _t(4.5)
    roll = np.convolve(np.abs(RNG.standard_normal(n)), np.hanning(int(0.35 * SR)), "same")
    roll /= roll.max()
    env = np.minimum(1, tt / 0.25) * np.exp(-tt / 1.6) * (0.5 + 0.5 * roll)
    thunder = brown / (np.abs(brown).max() + 1e-9) * env
    crack = signal.sosfilt(sos_bp(300, 1800), RNG.standard_normal(int(0.25 * SR))) * np.exp(-_t(0.25) / 0.06)
    place(thunder, 0.25 * crack / (np.abs(crack).max() + 1e-9), 0.02)
    out["thunder"] = _finish(thunder, IR_LONG, wet=0.4, tail=1.0, lufs=-24, hp=30)

    # Rolling over deck plank joints: front then rear wheel, every 64 px at 128 px/s.
    period, wheelbase, n = 0.5, 0.125, int(4.0 * SR)
    roll = np.zeros(n)
    for i in range(8):
        for off, lvl in ((0.0, 1.0), (wheelbase, 0.8)):
            hit = wood(RNG.uniform(380, 430), 0.12, decay=0.25) + 0.5 * thock(0.12, 120)
            j = int((i * period + off + RNG.normal(0, 0.003)) * SR) % n
            seg = hit * lvl * RNG.uniform(0.8, 1.0)
            idx = (j + np.arange(len(seg))) % n
            np.add.at(roll, idx, seg)
    rumble = sosc(sos_lp(160), RNG.standard_normal(n)) * 0.5
    roll = sosc(sos_lp(2400), roll) + rumble
    out["deck_roll"] = norm_lufs(roll, -30)
    return out
