"""'Trestle Dreams' - original theme, rendered from code (no samples, no license
strings attached). Dreamy desert Americana at 78 BPM in D major:
fingerpicked Karplus-Strong guitar -> tremolo, chorus, dotted-8th echo, big reverb;
warm pad; round bass; brushed kit; pedal-steel style slide lead.
32 bars, rendered circularly so the loop point is seamless.
"""
import numpy as np
from scipy import signal

from dsp import (SR, midi_hz, sos_lp, sos_hp, sosc, peak, make_ir, conv_reverb, norm_lufs, soft_clip, lufs)
from sfx import pluck

BPM = 78.0
BEAT = 60.0 / BPM
BARS = 32
T = BARS * 4 * BEAT
N = int(round(T * SR))
RNG = np.random.default_rng(1978)
INTRO = 8      # bars of guitar + pad before bass and drums come in
STYLE = "brush"  # drum feel: brush (theme), train (driving 8ths), sparse (kick + one brush)
TRANS = 0      # semitones up from D
GTR_LP = 7500

CHORDS = {  # bass, upper voicing (MIDI)
    "Dmaj7": (50, [57, 61, 66, 69]),
    "F#m7": (42, [57, 61, 64, 69]),
    "Gmaj7": (43, [59, 62, 66, 71]),
    "Gm6": (43, [58, 62, 64, 70]),
    "Bm7": (47, [57, 62, 66, 69]),
    "Em9": (40, [55, 59, 62, 66]),
    "A7sus4": (45, [55, 62, 64, 69]),
    "A6": (45, [57, 61, 66, 69]),
}
A = ["Dmaj7", "F#m7", "Gmaj7", "Gm6", "Dmaj7", "Bm7", "Em9", "A7sus4"]
B = ["Gmaj7", "A6", "F#m7", "Bm7", "Gmaj7", "Gm6", "Dmaj7", "A7sus4"]
PROG = A + A + B + A
CHORDS.update({
    "Bm9": (47, [57, 61, 62, 66]),
    "F#7sus4": (42, [59, 61, 64, 66]),
})

# (bar, beat, beats, midi, glide_from or None)
MELODY_THEME = MELODY = [
    (16, 0, 2, 71, 69), (16, 2, 1, 69, None), (16, 3, 1, 66, None),
    (17, 0, 2, 64, None), (17, 2, 2, 66, 64),
    (18, 0, 3, 69, 66), (18, 3, 1, 73, None),
    (19, 0, 2, 71, 73), (19, 2, 2, 74, None),
    (20, 0, 2, 78, 76), (20, 2, 1, 76, None), (20, 3, 1, 74, None),
    (21, 0, 2, 76, None), (21, 2, 1.5, 74, None), (21, 3.5, 0.5, 70, None),
    (22, 0, 3, 69, 70), (22, 3, 1, 66, None),
    (23, 0, 2, 64, None), (23, 2, 2, 62, 64),
    (24, 0, 3, 78, 76), (24, 3, 1, 76, None),
    (25, 0, 2, 73, None), (25, 2, 2, 76, None),
    (26, 0, 2, 74, None), (26, 2, 2, 71, None),
    (27, 0, 4, 70, None),
    (28, 0, 4, 69, 70),
    (29, 0, 2, 66, None), (29, 2, 2, 69, None),
    (30, 0, 3, 71, None), (30, 3, 1, 69, None),
]


def configure(bpm=78.0, bars=32, prog=None, melody=None, intro=8, style="brush", trans=0,
              lead_from=16, seed=1978, gtr_lp=7500, mix_db=None):
    """Re-point the composer at another arrangement (module globals, read at render)."""
    global BPM, BEAT, BARS, T, N, RNG, PROG, MELODY, INTRO, STYLE, TRANS, ACTIVE, GTR_LP, MIX_DB
    BPM, BARS, INTRO, STYLE, TRANS, GTR_LP = bpm, bars, intro, style, trans, gtr_lp
    BEAT = 60.0 / BPM
    T = BARS * 4 * BEAT
    N = int(round(T * SR))
    RNG = np.random.default_rng(seed)
    PROG = prog if prog is not None else A + A + B + A
    MELODY = melody if melody is not None else MELODY_THEME
    ACTIVE = {"gtr": (0, bars), "pad": (0, bars), "bass": (intro, bars), "drums": (intro, bars - 1),
              "lead": (lead_from, bars - 1)}
    MIX_DB = dict(MIX_DB_THEME, **(mix_db or {}))


def seamless(f):
    return max(1.0, round(f * T)) / T


def bar_t(bar, beat=0.0):
    return (bar * 4 + beat) * BEAT


def add_wrapped(buf, x, at):
    """Add x into a loop buffer starting at time `at`, wrapping past the end."""
    i = int(round(at * SR)) % N
    idx = (i + np.arange(len(x))) % N
    if buf.ndim == 1:
        np.add.at(buf, idx, x)
    else:
        np.add.at(buf, idx, x)


def guitar():
    g = np.zeros(N)
    for bar, name in enumerate(PROG):
        bass, up = CHORDS[name]
        bass += TRANS
        up = [u + TRANS for u in up]
        alt = bass + 7 if bass + 7 <= 52 + TRANS else bass - 5
        pattern = [bass, up[1], up[0], up[2], alt, up[3], up[1], up[2]]
        intro = bar < INTRO
        for i, m in enumerate(pattern):
            if intro and i in (5, 7) and bar < INTRO // 2:
                continue  # sparser first bars
            vel = (1.0 if i in (0, 4) else 0.72) * RNG.uniform(0.88, 1.08) * (0.85 if intro else 1.0)
            at = bar_t(bar, i * 0.5) + RNG.normal(0, 0.006)
            dur = 3.2 if i in (0, 4) else 2.4
            add_wrapped(g, vel * pluck(midi_hz(m), dur, bright=0.28, t60=2.6 if i in (0, 4) else 2.0, pick=0.2), at)
    g = sosc(peak(115, 2.0, 1.0), g)
    g = sosc(peak(2800, -3.0, 0.8), g)
    g = sosc(sos_lp(GTR_LP), g)
    t = np.arange(N) / SR
    trem = 1.0 - 0.28 * (0.5 + 0.5 * np.sin(2 * np.pi * seamless(4.6) * t))
    g *= trem
    # Stereo chorus: circular modulated delays.
    out = np.zeros((N, 2))
    for c, (rate, ph) in enumerate(((seamless(0.31), 0.0), (seamless(0.37), 1.9))):
        d = (0.012 + 0.0016 * np.sin(2 * np.pi * rate * t + ph)) * SR
        pos = np.arange(N) - d
        i0 = np.floor(pos).astype(int)
        fr = pos - i0
        wet = g[i0 % N] * (1 - fr) + g[(i0 + 1) % N] * fr
        out[:, c] = 0.75 * g + 0.45 * wet
    return out


def echo(x, beats=0.75, fb=0.32, wet=0.25, lp=2600):
    d = int(round(beats * BEAT * SR))
    acc = np.zeros_like(x)
    tap = x.copy()
    for k in range(1, 7):
        tap = np.roll(tap, d, axis=0) * fb
        tap = sosc(sos_lp(lp), tap)
        if k % 2 == 0:  # ping-pong
            tap = tap[:, ::-1]
        acc += tap
    return x + wet * acc / fb


def pad():
    p = np.zeros((N, 2))
    t_note = np.arange(int((4 * BEAT + 1.2) * SR)) / SR
    env = np.minimum(1.0, t_note / 0.9)
    rel_start = 4 * BEAT
    env = np.where(t_note > rel_start, env * np.exp(-(t_note - rel_start) / 0.45), env)
    for bar, name in enumerate(PROG):
        _, up = CHORDS[name]
        lvl = 0.5 if bar < INTRO else 0.7
        for j, m in enumerate(up):
            f = midi_hz(m + TRANS)
            for k, det in enumerate((-6, 0, 6)):
                ff = f * 2 ** (det / 1200)
                ph = (ff * t_note + RNG.random()) % 1.0
                saw = 2 * ph - 1
                pan = (k - 1) * 0.6
                v = saw * env * lvl / 3
                add_wrapped(p[:, 0], v * (1 - max(0, pan)) , bar_t(bar))
                add_wrapped(p[:, 1], v * (1 + min(0, pan)), bar_t(bar))
    return sosc(sos_lp(1100), sosc(sos_hp(160), p))


def bass():
    b = np.zeros(N)
    t = np.arange(int(1.9 * BEAT * SR)) / SR
    env = (1 - np.exp(-t / 0.008)) * (0.5 + 0.5 * np.exp(-t / 0.6))
    env[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))
    for bar, name in enumerate(PROG):
        if bar < INTRO:
            continue
        root, _ = CHORDS[name]
        root += TRANS
        beats = ((0, root), (2, root + 7 if name not in ("Gm6", "Em9") else root))
        if STYLE == "train":  # root-fifth on every beat
            beats = ((0, root), (1, root + 7), (2, root), (3, root + 7))
        for beat, m in beats:
            f = midi_hz(m - 12 if m > 47 else m)
            v = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)) * env
            add_wrapped(b, v * RNG.uniform(0.9, 1.0), bar_t(bar, beat) + RNG.normal(0, 0.004))
    return sosc(sos_lp(700), soft_clip(b * 0.6, 1.4))


def drums():
    d = np.zeros(N)
    tk = np.arange(int(0.4 * SR)) / SR
    kick = np.sin(2 * np.pi * np.cumsum(48 + 70 * np.exp(-tk / 0.03)) / SR) * np.exp(-tk / 0.22)
    ts = np.arange(int(0.35 * SR)) / SR
    brush_env = (1 - np.exp(-ts / 0.012)) * np.exp(-ts / 0.16)
    th = np.arange(int(0.08 * SR)) / SR
    bp = signal.butter(2, [900, 5200], "bandpass", fs=SR, output="sos")
    for bar in range(INTRO, BARS):
        last = bar == BARS - 1
        add_wrapped(d, 0.9 * kick, bar_t(bar, 0))
        if not last and STYLE != "sparse":
            add_wrapped(d, 0.75 * kick, bar_t(bar, 2))
        if INTRO * 2 <= bar < INTRO * 3 and bar % 2 == 1 and STYLE == "brush":
            add_wrapped(d, 0.4 * kick, bar_t(bar, 1.5))
        if STYLE == "train":  # brushed snare on every 8th, accents on 2 and 4
            for e in range(8):
                if last and e >= 6:
                    continue
                br = sosc(bp, RNG.standard_normal(len(ts))) * brush_env
                acc = 0.38 if e in (2, 6) else 0.16
                add_wrapped(d, acc * br, bar_t(bar, e * 0.5) + RNG.normal(0, 0.004))
            continue
        for beat in ((2,) if STYLE == "sparse" else (1, 3)):
            if last and beat == 3:
                continue
            br = sosc(bp, RNG.standard_normal(len(ts))) * brush_env
            add_wrapped(d, 0.35 * br, bar_t(bar, beat) + RNG.normal(0, 0.005))
        if STYLE == "sparse":
            continue
        for e in range(8):
            sh = sosc(sos_hp(5500), RNG.standard_normal(len(th))) * np.exp(-th / 0.035)
            add_wrapped(d, (0.2 if e % 2 else 0.12) * sh, bar_t(bar, e * 0.5) + RNG.normal(0, 0.004))
    # Faint brush swirl under everything after the intro.
    swirl = sosc(signal.butter(2, [1200, 4500], "bandpass", fs=SR, output="sos"), RNG.standard_normal(N))
    t = np.arange(N) / SR
    swirl *= 0.02 * (0.6 + 0.4 * np.sin(2 * np.pi * seamless(BPM / 60.0) * t))
    swirl *= (t >= bar_t(INTRO)) * (t < bar_t(BARS - 1))
    return d + swirl


def lead():
    t = np.arange(N) / SR
    f = np.full(N, midi_hz(62 + TRANS))
    a = np.zeros(N)
    vib = np.zeros(N)
    for bar, beat, beats, m, glide in MELODY:
        t0 = bar_t(bar, beat)
        t1 = t0 + beats * BEAT
        i0, i1 = int(t0 * SR), min(N, int((t1 + 0.35) * SR))
        tt = t[i0:i1] - t0
        target = midi_hz(m + TRANS)
        if glide is not None:
            src = midi_hz(glide + TRANS)
            gl = np.clip(tt / 0.11, 0, 1)
            gl = gl * gl * (3 - 2 * gl)
            f[i0:i1] = src * (target / src) ** gl
        else:
            f[i0:i1] = target
        env = np.minimum(1.0, tt / 0.16) * np.where(tt > beats * BEAT - 0.05,
                                                    np.exp(-(tt - (beats * BEAT - 0.05)) / 0.22), 1.0)
        a[i0:i1] = np.maximum(a[i0:i1], env)
        vib[i0:i1] = np.clip((tt - 0.3) / 0.5, 0, 1)
    f = f * 2 ** (11.0 / 1200 * vib * np.sin(2 * np.pi * 5.2 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = sum((1.0 / k ** 1.4) * np.sin(k * ph) for k in range(1, 12))
    y = y * a
    y = sosc(sos_lp(2800), y)
    y = sosc(peak(1250, 2.5, 1.2), y)
    return np.stack([0.8 * y, 1.0 * y], axis=1)


def crackle():
    c = np.zeros(N)
    count = int(T * 4)
    pos = RNG.integers(0, N, count)
    c[pos] = RNG.uniform(-1, 1, count) * RNG.uniform(0.2, 1.0, count) ** 3
    c = sosc(signal.butter(2, [900, 6000], "bandpass", fs=SR, output="sos"), c)
    hiss = sosc(sos_lp(5000), RNG.standard_normal(N)) * 0.0008
    return 0.05 * c + hiss


# Each stem is normalised over the bars where it plays, then mixed at these levels
# (dB relative to the guitar). Balanced so sections sit within ~3 dB.
MIX_DB_THEME = {"gtr": 0, "pad": -7, "bass": -8, "drums": -10, "lead": -6}
MIX_DB = dict(MIX_DB_THEME)
ACTIVE = {"gtr": (0, 32), "pad": (0, 32), "bass": (8, 32), "drums": (8, 31), "lead": (16, 31)}


def stems():
    """Render each part once so the mix can be balanced without re-rendering."""
    ir = make_ir(3.2, 2800, 25, seed=11)
    gtr = conv_reverb(echo(guitar(), wet=0.28), ir, 0.38, circular=True)
    pd = conv_reverb(pad(), ir, 0.5, circular=True)
    bs = bass()
    dr = conv_reverb(drums(), make_ir(1.2, 4000, 8, seed=13), 0.18, circular=True)
    ld = conv_reverb(echo(lead(), beats=0.75, fb=0.3, wet=0.3, lp=2200), ir, 0.45, circular=True)
    return {"gtr": gtr, "pad": pd, "bass": np.stack([bs, bs], 1), "drums": dr, "lead": ld,
            "crackle": np.stack([crackle()] * 2, 1)}


def mixdown(st, mix=None):
    if mix is None:
        bt = 4 * BEAT
        mix = {}
        for k, (a, b) in ACTIVE.items():
            ref = lufs(st[k][int(a * bt * SR):int(b * bt * SR)])
            mix[k] = 10 ** ((-20 + MIX_DB[k] - ref) / 20)
    m = sum(mix[k] * st[k] for k in mix) + st["crackle"]
    m = sosc(sos_hp(35), m)
    m = m / (np.max(np.abs(m)) + 1e-9)
    m = soft_clip(m * 1.1, 1.2)
    m = norm_lufs(m, -16.0)
    pk = np.max(np.abs(m))
    if pk > 0.89:
        m *= 0.89 / pk
    return m


def render():
    return mixdown(stems())


# --- trail variants -------------------------------------------------------------
# "Lantern Low": the theme's guitar turned dark and slow in B minor, for the night
# trestle and the mine. Kick and one brush per bar, the slide lead sighing above.
LOW_PROG = ["Bm9", "Gmaj7", "Em9", "F#7sus4", "Bm9", "Gmaj7", "Dmaj7", "F#7sus4",
            "Gmaj7", "A6", "Bm9", "Em9", "Gmaj7", "Em9", "F#7sus4", "F#7sus4"]
LOW_MELODY = [
    (8, 0, 3, 71, 69), (8, 3, 1, 74, None),
    (9, 0, 4, 73, 74),
    (10, 0, 2, 66, None), (10, 2, 2, 69, 66),
    (11, 0, 4, 67, 69),
    (12, 0, 2, 71, None), (12, 2, 1, 74, None), (12, 3, 1, 73, None),
    (13, 0, 4, 71, 73),
    (14, 0, 3, 73, 71), (14, 3, 1, 70, None),
]
# "Ridge Runner": up a tone in E, quicker, with a train beat, for the high trails.
HIGH_PROG = ["Dmaj7", "Bm7", "Gmaj7", "A6", "Dmaj7", "F#m7", "Gmaj7", "A7sus4",
             "Gmaj7", "A6", "F#m7", "Bm7", "Em9", "Gmaj7", "A7sus4", "A6"]
HIGH_MELODY = [
    (8, 0, 1, 74, None), (8, 1, 1, 76, None), (8, 2, 2, 78, 76),
    (9, 0, 2, 76, 78), (9, 2, 2, 73, None),
    (10, 0, 3, 69, 71), (10, 3, 1, 73, None),
    (11, 0, 2, 74, 73), (11, 2, 2, 78, None),
    (12, 0, 2, 79, 78), (12, 2, 1, 78, None), (12, 3, 1, 76, None),
    (13, 0, 3, 74, 76), (13, 3, 1, 71, None),
    (14, 0, 2, 74, None), (14, 2, 2, 76, 74),
    (15, 0, 4, 73, 74),
]
VARIANTS = {
    "trestle_dreams": {},
    "lantern_low": dict(bpm=68.0, bars=16, prog=LOW_PROG, melody=LOW_MELODY, intro=4, style="sparse",
                        lead_from=8, seed=2031, gtr_lp=4200, mix_db={"drums": -14, "pad": -5}),
    "ridge_runner": dict(bpm=96.0, bars=16, prog=HIGH_PROG, melody=HIGH_MELODY, intro=2, style="train",
                         trans=2, lead_from=8, seed=1890, mix_db={"drums": -9, "bass": -7}),
}


def render_variant(name):
    configure(**VARIANTS[name])
    y = render()
    configure()
    return y
