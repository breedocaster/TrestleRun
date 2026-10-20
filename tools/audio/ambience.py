"""Turn the found nature recordings into seamless ambience loops, and synthesize the
trail beds.

For each recording, pick the loop window whose head and tail match best (RMS and
spectral balance), so the equal-power crossfade at the seam is inaudible. Recordings
stay stereo at 44.1 kHz (v0.8.2; they were mono 22 kHz to fit a size cap). Loops are
as long as the recordings allow, so the repeat is hard to hear.
"""
import numpy as np
from scipy import signal

from dsp import (SR, sos_hp, sos_lp, sos_bp, sosc, make_ir, conv_reverb, loop_xfade, norm_lufs,
                 read_audio, soft_clip)
from sfx import chime

# name: (source file, loop seconds, crossfade seconds, target LUFS, highpass Hz)
# Sources: birds 129.8 s, summer-night 49.3 s, rain 124.6 s, stream 145.5 s.
SPECS = {
    "day_birds": ("birds.ogg", 90.0, 4.0, -30.0, 180),
    "night_crickets": ("summer-night.ogg", 40.0, 3.0, -31.0, 250),
    "rain": ("rain.ogg", 88.0, 4.0, -25.0, 120),
    "creek": ("stream.ogg", 96.0, 4.0, -33.0, 150),
}
# The wind recording is only 14.8 s, too short for a long loop with a clean seam
# (the 10 s cut it made before had the worst seam of the set). Rebuilt from grains:
# random 4-7 s slices joined with 1.5 s equal-power crossfades, wrapped round.
WIND = ("wind.ogg", 42.0, -27.0, 80)


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


def grain_loop(x, length, rng, grain=(4.0, 7.0), xf=1.5):
    """A loop of `length` s made of random slices of x, each crossfaded into the next;
    the last one fades into the first, so there is no seam anywhere."""
    n, f = int(length * SR), int(xf * SR)
    total = x.shape[0]
    durs = []
    while sum(durs) < length - grain[0]:
        durs.append(rng.uniform(*grain))
    durs.append(length - sum(durs))
    ref = np.sqrt(np.mean(x ** 2))
    out = np.zeros((n,) + x.shape[1:])
    ramp = np.linspace(0, np.pi / 2, f)
    fi, fo = np.sin(ramp), np.cos(ramp)
    if x.ndim > 1:
        fi, fo = fi[:, None], fo[:, None]
    pos = 0
    last = -1e9
    for d in durs:
        m = int(d * SR) + f
        s = int(rng.uniform(0.5 * SR, total - m - 0.5 * SR))
        while abs(s - last) < 2 * SR:  # not straight on from the slice before
            s = int(rng.uniform(0.5 * SR, total - m - 0.5 * SR))
        last = s + m
        g = x[s:s + m].copy()
        g *= ref / (np.sqrt(np.mean(g ** 2)) + 1e-9) * rng.uniform(0.85, 1.15)
        g[:f] *= fi
        g[-f:] *= fo
        idx = (pos + np.arange(m)) % n
        np.add.at(out, idx, g)
        pos += m - f
    return out


def build(blanket_dir):
    out, info = {}, {}
    for name, (src, length, xf, target, hp) in SPECS.items():
        x = read_audio(f"{blanket_dir}/{src}")
        x = signal.sosfilt(sos_hp(hp), x, axis=0)
        length = min(length, x.shape[0] / SR - xf - 2.0)
        s, score = best_start(x, length, xf)
        y = loop_xfade(x, s, length, xf)
        out[name] = norm_lufs(y, target)
        info[name] = {"start": s, "seconds": round(length, 2), "seam_score": round(score, 3)}
    src, length, target, hp = WIND
    x = signal.sosfilt(sos_hp(hp), read_audio(f"{blanket_dir}/{src}"), axis=0)
    out["wind"] = norm_lufs(grain_loop(x, length, np.random.default_rng(77)), target)
    info["wind"] = {"seconds": length, "grains": True}
    beds = synth_beds()
    out.update(beds)
    for k in beds:
        info[k] = {"seconds": BED_SECONDS, "synth": True}
    return out, info


# --- synthesized trail beds ------------------------------------------------------
# Built as stereo loops from the start: noise is filtered circularly and events wrap
# around the end, so there is no seam to hide. 48 s (they were 16 s for the size cap);
# event counts scale with the length so the density stays the same.
BED_SECONDS = 48.0
DENSITY = BED_SECONDS / 16.0
BED_TARGET = {"mine": -31.0, "yard": -31.0, "canyon": -30.0, "alpine": -30.0, "collapse": -29.0,
              "farm": -31.0, "orchard": -31.0, "speedway": -30.0}


def _count(k):
    return int(round(k * DENSITY))


def _times(rng, count, length=BED_SECONDS):
    """Event times spread through the loop (jittered slots, so no clumps or long gaps)."""
    slots = (np.arange(count) + rng.uniform(0.15, 0.85, count)) * length / count
    rng.shuffle(slots)
    return slots


def _wrap_add(buf, x, at, pan=0.0):
    """Add mono x into a stereo loop at `at` s, panned -1 (left) .. 1 (right)."""
    i = int(at * SR) % len(buf)
    idx = (i + np.arange(len(x))) % len(buf)
    th = (pan + 1.0) * np.pi / 4
    np.add.at(buf[:, 0], idx, x * np.cos(th) * 1.414)
    np.add.at(buf[:, 1], idx, x * np.sin(th) * 1.414)


def _noise2(rng, n, corr=0.35):
    """Stereo noise, partly shared between the sides (fully separate sounds too wide)."""
    c = rng.standard_normal(n)
    return np.stack([np.sqrt(corr) * c + np.sqrt(1 - corr) * rng.standard_normal(n) for _ in range(2)], 1)


def _mod(rng, n, hz, corr=0.0):
    """Unit-variance random wobble below `hz`, stereo, loopable (for flutter and syllables)."""
    x = sosc(sos_lp(hz), _noise2(rng, n, corr))
    return x / (np.std(x, axis=0) + 1e-12)


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
    if x.ndim > 1:
        pos = pos[:, None]
    y = np.zeros_like(x)
    for k in range(bands):
        w = np.clip(1.0 - np.abs(pos - k), 0.0, 1.0)
        y += w * outs[k]
    return y


def _creak(rng, dur=0.9, lo=300, hi=900):
    tc = np.arange(int(dur * SR)) / SR
    c = sosc(sos_bp(lo, hi), rng.standard_normal(len(tc)))
    rate = rng.uniform(14, 22)
    return c * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (rate + 10 * tc) * tc))) * np.sin(np.pi * tc / tc[-1]) ** 2


def synth_beds():
    n = int(BED_SECONDS * SR)
    rng = np.random.default_rng(4242)
    out = {}
    t = np.arange(n) / SR

    # Lantern Mine: deep rumble, slow drips echoing off rock, a timber creak now and then.
    mine = 2.2 * sosc(sos_lp(110), _noise2(rng, n, 0.6)) * _slow(n, rng, 0.08, 0.35)[:, None]
    drips = np.zeros((n, 2))
    for at in _times(rng, _count(9)):
        td = np.arange(int(0.06 * SR)) / SR
        f0 = rng.uniform(1300, 2200)
        blip = np.sin(2 * np.pi * np.cumsum(f0 * (1 - 0.45 * td / td[-1])) / SR) * np.exp(-td / 0.012)
        _wrap_add(drips, blip * rng.uniform(0.25, 0.6), at, rng.uniform(-0.8, 0.8))
    for at in _times(rng, _count(2)):
        _wrap_add(drips, 0.22 * _creak(rng), at, rng.uniform(-0.5, 0.5))
    out["mine"] = mine + conv_reverb(drips, make_ir(1.8, 2200, 30, seed=5), 0.55, circular=True)

    # Rustyard / Hoist Yard / the Rail Yard: machine hum, distant metal clanks in a big
    # shed, steam hiss.
    hum = sum(np.sin(2 * np.pi * h * 50.0 * t) / h for h in (1, 2, 3, 5)) * 0.04 * _slow(n, rng, 0.1, 0.3)
    ev = np.zeros((n, 2))
    for at in _times(rng, _count(7)):
        tk = np.arange(int(1.2 * SR)) / SR
        f = rng.uniform(220, 480)
        clank = sum(np.sin(2 * np.pi * f * r * tk) * np.exp(-tk / (0.35 / r)) / r for r in (1.0, 2.76, 5.4, 8.93))
        clank *= 1 - np.exp(-tk / 0.002)
        _wrap_add(ev, clank * rng.uniform(0.15, 0.35), at, rng.uniform(-0.9, 0.9))
    for at in _times(rng, _count(3)):
        th = np.arange(int(1.6 * SR)) / SR
        hiss = sosc(sos_hp(2500), rng.standard_normal(len(th))) * np.minimum(1, th / 0.05) * np.exp(-th / 0.5)
        _wrap_add(ev, 0.12 * hiss, at, rng.uniform(-0.7, 0.7))
    out["yard"] = hum[:, None] + conv_reverb(ev, make_ir(2.6, 2600, 40, seed=6), 0.6, circular=True) \
        + 0.3 * sosc(sos_lp(300), _noise2(rng, n)) * _slow(n, rng, 0.06, 0.4)[:, None]

    # Copper Canyon / Hoodoo Loops: hollow wind moaning through rock.
    pink = sosc(sos_lp(900), _noise2(rng, n, 0.3))
    centers = 380 + 220 * (_slow(n, rng, 0.07, 1.0) - 1.0)
    moan = _sweep_bp(pink, centers, q=6.0) * _slow(n, rng, 0.09, 0.5)[:, None]
    out["canyon"] = moan + 0.25 * sosc(sos_lp(200), _noise2(rng, n))

    # Skyline Pass: thin, high mountain wind with a faint whistle on the gusts.
    gust = _slow(n, rng, 0.11, 0.6)
    air = sosc(sos_bp(700, 3200), _noise2(rng, n, 0.25)) * gust[:, None]
    centers = 1500 + 500 * (_slow(n, rng, 0.05, 1.0) - 1.0)
    whistle = _sweep_bp(_noise2(rng, n, 0.5), centers, q=24.0) * (np.clip(gust - 1.0, 0, None) * 3.0)[:, None]
    out["alpine"] = air + whistle

    # Last Trestle: the collapse behind you. Deep rumble, timbers snapping, debris.
    rum = sosc(sos_lp(90), _noise2(rng, n, 0.6)) * _slow(n, rng, 0.2, 0.5)[:, None] * 2.5
    ev2 = np.zeros((n, 2))
    for at in _times(rng, _count(14)):
        tk = np.arange(int(0.5 * SR)) / SR
        snap = sosc(sos_bp(400, 3000), rng.standard_normal(len(tk))) * np.exp(-tk / 0.03)
        snap += 0.6 * np.sin(2 * np.pi * rng.uniform(150, 300) * tk) * np.exp(-tk / 0.1)
        _wrap_add(ev2, snap * rng.uniform(0.2, 0.5), at, rng.uniform(-0.6, 0.6))
    out["collapse"] = rum + conv_reverb(ev2, make_ir(2.0, 1800, 30, seed=8), 0.5, circular=True)

    out.update(story_beds(n, rng, t))
    for k in out:
        y = soft_clip(out[k] / (np.max(np.abs(out[k])) + 1e-9), 1.0)
        out[k] = norm_lufs(y, BED_TARGET[k])
    return out


# --- story areas (v0.8.2; story trails only had birds and crickets before) -----------
C_PENT = [72, 74, 76, 79, 81, 84]  # the farm theme is in C; these also sit in the boss loop's D minor


def story_beds(n, rng, t):
    out = {}
    # Grandma's Farm: a breeze over the hay, the porch wind chimes, the windmill pump.
    gust = _slow(n, rng, 0.08, 0.6)
    breeze = sosc(sos_bp(250, 1800), _noise2(rng, n, 0.3)) * gust[:, None]
    hay = sosc(sos_hp(2800), _noise2(rng, n, 0.2)) * (np.clip(gust - 0.8, 0, None) ** 2)[:, None] * 0.8
    farm = breeze + hay
    chimes = np.zeros((n, 2))
    for at in _times(rng, _count(2)):  # a run of notes when the wind catches them
        k = rng.integers(3, 7)
        for j in range(k):
            m = C_PENT[rng.integers(0, len(C_PENT))]
            f = 440.0 * 2 ** ((m - 69) / 12.0)
            _wrap_add(chimes, 0.05 * rng.uniform(0.5, 1.0) * chime(f, 3.0, bright=0.5, decay=2.2),
                      at + j * rng.uniform(0.18, 0.45), 0.55 + rng.uniform(-0.1, 0.1))
    pump = np.zeros((n, 2))
    for at in _times(rng, _count(2)):
        for j in range(3):  # creak-clunk, three strokes
            _wrap_add(pump, 0.09 * _creak(rng, 0.7, 500, 1600), at + j * 1.6, -0.6)
            tk = np.arange(int(0.3 * SR)) / SR
            _wrap_add(pump, 0.12 * np.sin(2 * np.pi * 95 * tk) * np.exp(-tk / 0.05), at + j * 1.6 + 0.75, -0.6)
    out["farm"] = farm + conv_reverb(chimes + pump, make_ir(2.2, 3000, 25, seed=21), 0.45, circular=True)

    # Old Orchard: leaves rustling, an owl further off, an apple dropping in the grass.
    gust = _slow(n, rng, 0.1, 0.7)
    flutter = np.clip(0.35 + 0.65 * _mod(rng, n, 12.0, 0.4), 0, None)
    leaves = sosc(sos_bp(1600, 6500), _noise2(rng, n, 0.4)) * flutter * (np.clip(gust - 0.5, 0, None) ** 1.5)[:, None]
    low = 0.35 * sosc(sos_lp(350), _noise2(rng, n)) * gust[:, None]
    ev = np.zeros((n, 2))
    for at in _times(rng, _count(1)):  # hoo ... hoo-hoo
        pan = rng.uniform(-0.8, 0.8)
        for off, dur in ((0.0, 0.45), (0.95, 0.22), (1.25, 0.5)):
            th = np.arange(int(dur * SR)) / SR
            f = 370 * (1.0 - 0.06 * th / th[-1])
            hoot = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.12 * np.sin(4 * np.pi * np.cumsum(f) / SR))
            hoot *= np.sin(np.pi * th / th[-1]) ** 1.5
            _wrap_add(ev, 0.07 * hoot, at + off, pan)
    for at in _times(rng, _count(1)):
        tk = np.arange(int(0.25 * SR)) / SR
        thud = np.sin(2 * np.pi * 85 * tk) * np.exp(-tk / 0.04) + 0.3 * sosc(sos_lp(700), rng.standard_normal(len(tk))) * np.exp(-tk / 0.02)
        _wrap_add(ev, 0.18 * thud, at, rng.uniform(-0.5, 0.5))
    out["orchard"] = leaves + low + conv_reverb(ev, make_ir(2.4, 2400, 35, seed=22), 0.5, circular=True)

    # County Speedway: the crowd murmuring in the stands, a cheer now and then, bikes
    # buzzing round the far track.
    crowd = np.zeros((n, 2))
    for fc, bw in ((520, 160), (900, 260), (1450, 380), (2500, 700)):
        band = sosc(sos_bp(fc - bw / 2, fc + bw / 2), _noise2(rng, n, 0.5))
        syll = np.clip(0.55 + 0.45 * _mod(rng, n, 5.0, 0.4), 0, None)
        crowd += band * syll
    crowd *= _slow(n, rng, 0.05, 0.25)[:, None]
    cheer = np.zeros((n, 2))
    for at in _times(rng, _count(1)):
        tc = np.arange(int(4.5 * SR)) / SR
        env = np.minimum(1.0, tc / 0.7) * np.exp(-np.maximum(0, tc - 1.4) / 1.1)
        for c in range(2):
            idx = (int(at * SR) + np.arange(len(tc))) % n
            np.add.at(cheer[:, c], idx, 2.2 * sosc(sos_bp(400, 3200), rng.standard_normal(len(tc))) * env)
    bikes = np.zeros((n, 2))
    for at in _times(rng, _count(2)):
        dur = 3.4
        tb = np.arange(int(dur * SR)) / SR
        tc = dur / 2
        f0 = rng.uniform(95, 135)
        f = f0 * (1 + 0.06 * np.tanh(-(tb - tc) / 0.5))  # Doppler drop as it goes by
        ph = 2 * np.pi * np.cumsum(f) / SR
        buzz = sum(np.sin(k * ph) / k for k in range(1, 14))
        buzz = signal.sosfilt(sos_lp(1400), buzz) * np.exp(-((tb - tc) / 0.8) ** 2)
        d = rng.choice([-1.0, 1.0])
        th = (np.clip(d * (tb - tc) / tc, -1, 1) * 0.8 + 1.0) * np.pi / 4
        idx = (int(at * SR) + np.arange(len(tb))) % n
        np.add.at(bikes[:, 0], idx, 0.06 * buzz * np.cos(th) * 1.414)
        np.add.at(bikes[:, 1], idx, 0.06 * buzz * np.sin(th) * 1.414)
    stands = make_ir(2.8, 2200, 40, seed=23)
    out["speedway"] = conv_reverb(crowd * 0.5 + cheer * 0.08, stands, 0.5, circular=True) \
        + conv_reverb(bikes, stands, 0.4, circular=True)
    return out
