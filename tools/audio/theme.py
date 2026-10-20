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
STYLE = "brush"  # drum feel: brush (theme), train (driving 8ths), sparse (kick + one brush),
                 # shuffle (swung two-beat), stomp (kick on every beat, snare backbeat)
SWING = 0.0    # beats the off-beat 8ths are pushed late (0.17 = triplet shuffle)
TRANS = 0      # semitones up from D
GTR_LP = 7500
VIB_CENTS = 11.0  # lead vibrato depth (the boss loop's theremin wobbles much wider)

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
    "Dm9": (50, [57, 60, 64, 65]),
    "Bbmaj7": (46, [57, 58, 62, 65]),
    "Fmaj7": (41, [57, 60, 64, 65]),
    "A7b9": (45, [55, 58, 61, 64]),
    # v0.8.2, for the story-area loops
    "D6": (50, [57, 59, 62, 66]),
    "G6": (43, [59, 62, 64, 67]),
    "A7": (45, [55, 61, 64, 69]),
    "E9": (40, [56, 59, 62, 66]),
    "Em7": (40, [55, 59, 62, 64]),
    "Am7": (45, [55, 60, 64, 67]),
    "B7": (47, [57, 59, 63, 66]),
    "Cmaj7": (48, [55, 59, 64, 67]),
    "C6": (48, [55, 57, 60, 64]),
    "Gm7": (43, [58, 62, 65, 69]),
    "C7sus4": (48, [55, 58, 60, 65]),
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
              lead_from=16, seed=1978, gtr_lp=7500, mix_db=None, vib=11.0, swing=0.0):
    """Re-point the composer at another arrangement (module globals, read at render)."""
    global BPM, BEAT, BARS, T, N, RNG, PROG, MELODY, INTRO, STYLE, TRANS, ACTIVE, GTR_LP, MIX_DB, VIB_CENTS, SWING
    BPM, BARS, INTRO, STYLE, TRANS, GTR_LP, VIB_CENTS, SWING = bpm, bars, intro, style, trans, gtr_lp, vib, swing
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


def sw(beat):
    """Swing: push off-beat 8ths late by SWING beats."""
    whole = np.floor(beat)
    return whole + 0.5 + SWING if abs(beat - whole - 0.5) < 1e-6 else beat


def _minor(name):
    return "m" in name.replace("maj", "")


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
            at = bar_t(bar, sw(i * 0.5)) + RNG.normal(0, 0.006)
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
    env_short = env * np.clip((0.95 * BEAT - t) / 0.06, 0, 1)
    for bar, name in enumerate(PROG):
        if bar < INTRO:
            continue
        root, _ = CHORDS[name]
        root += TRANS
        beats = ((0, root), (2, root + 7 if name not in ("Gm6", "Em9") else root))
        e = env
        if STYLE == "train":  # root-fifth on every beat
            beats = ((0, root), (1, root + 7), (2, root), (3, root + 7))
        elif STYLE == "stomp":  # boogie walk: root, third, fifth, sixth (or seventh on minor)
            third = root + (3 if _minor(name) else 5 if "sus" in name else 4)
            beats = ((0, root), (1, third), (2, root + 7), (3, root + (10 if _minor(name) else 9)))
            e = env_short
        for beat, m in beats:
            if STYLE == "stomp":
                f = midi_hz(m - (12 if root > 47 else 0))
            else:
                f = midi_hz(m - 12 if m > 47 else m)
            v = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)) * e
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
    tsn = np.arange(int(0.25 * SR)) / SR
    for bar in range(INTRO, BARS):
        last = bar == BARS - 1
        add_wrapped(d, 0.9 * kick, bar_t(bar, 0))
        if STYLE == "stomp":
            for b in (1, 2, 3):
                if not (last and b == 3):
                    add_wrapped(d, (0.7 if b == 2 else 0.55) * kick, bar_t(bar, b))
            for b in (1, 3):  # snare: brush noise with a little body
                if last and b == 3:
                    continue
                sn = sosc(bp, RNG.standard_normal(len(tsn))) * np.exp(-tsn / 0.07)
                sn += 0.5 * np.sin(2 * np.pi * 185 * tsn) * np.exp(-tsn / 0.04)
                add_wrapped(d, 0.42 * sn, bar_t(bar, b) + RNG.normal(0, 0.003))
            for e in range(8):
                if last and e >= 6:
                    continue
                sh = sosc(sos_hp(5500), RNG.standard_normal(len(th))) * np.exp(-th / 0.03)
                add_wrapped(d, (0.24 if e % 2 else 0.1) * sh, bar_t(bar, e * 0.5) + RNG.normal(0, 0.003))
            continue
        if not last and STYLE != "sparse":
            add_wrapped(d, 0.75 * kick, bar_t(bar, 2))
        if STYLE == "shuffle" and not last and bar % 2 == 1:
            add_wrapped(d, 0.35 * kick, bar_t(bar, sw(2.5)))  # swung pickup into beat 3
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
            add_wrapped(d, (0.2 if e % 2 else 0.12) * sh, bar_t(bar, sw(e * 0.5)) + RNG.normal(0, 0.004))
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
        t0 = bar_t(bar, sw(beat))
        t1 = bar_t(bar, sw(beat + beats))
        dur = t1 - t0
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
        env = np.minimum(1.0, tt / 0.16) * np.where(tt > dur - 0.05, np.exp(-(tt - (dur - 0.05)) / 0.22), 1.0)
        a[i0:i1] = np.maximum(a[i0:i1], env)
        vib[i0:i1] = np.clip((tt - 0.3) / 0.5, 0, 1)
    f = f * 2 ** (VIB_CENTS / 1200 * vib * np.sin(2 * np.pi * 5.2 * t))
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
# All 32 bars (v0.8.2): the three trail loops were 16 bars to fit a size cap, so they
# came round every 33-56 s. Each now has a B section and a varied return.

# "Lantern Low": the theme's guitar turned dark and slow in B minor, for the night
# trestle and the mine. Kick and one brush per bar, the slide lead sighing above.
LOW_PROG = ["Bm9", "Gmaj7", "Em9", "F#7sus4", "Bm9", "Gmaj7", "Dmaj7", "F#7sus4",
            "Gmaj7", "A6", "Bm9", "Em9", "Gmaj7", "Em9", "F#7sus4", "F#7sus4",
            "Em9", "F#7sus4", "Bm9", "Bm9", "Gmaj7", "Dmaj7", "Em9", "F#7sus4",
            "Bm9", "Gmaj7", "Em9", "F#7sus4", "Gmaj7", "A6", "F#7sus4", "F#7sus4"]
LOW_MELODY = [
    (8, 0, 3, 71, 69), (8, 3, 1, 74, None),
    (9, 0, 4, 73, 74),
    (10, 0, 2, 66, None), (10, 2, 2, 69, 66),
    (11, 0, 4, 67, 69),
    (12, 0, 2, 71, None), (12, 2, 1, 74, None), (12, 3, 1, 73, None),
    (13, 0, 4, 71, 73),
    (14, 0, 3, 73, 71), (14, 3, 1, 70, None),
    # B: up into the high F#, then down through the Em
    (16, 0, 3, 71, None), (16, 3, 1, 74, None),
    (17, 0, 4, 73, 74),
    (18, 0, 2, 78, None), (18, 2, 2, 76, 78),
    (19, 0, 4, 74, 76),
    (20, 0, 2, 71, None), (20, 2, 1, 74, None), (20, 3, 1, 78, None),
    (21, 0, 3, 73, None), (21, 3, 1, 69, None),
    (22, 0, 2, 71, 69), (22, 2, 2, 67, None),
    (23, 0, 4, 66, 67),
    # return, ending on the A# that leads back to B
    (24, 0, 3, 71, 69), (24, 3, 1, 74, None),
    (25, 0, 4, 78, 74),
    (26, 0, 2, 76, 78), (26, 2, 2, 71, None),
    (27, 0, 4, 73, 71),
    (28, 0, 2, 71, None), (28, 2, 2, 74, None),
    (29, 0, 4, 73, 74),
    (30, 0, 3, 71, 73), (30, 3, 1, 70, None),
]
# "Ridge Runner": up a tone in E, quicker, with a train beat, for the high trails.
HIGH_PROG = ["Dmaj7", "Bm7", "Gmaj7", "A6", "Dmaj7", "F#m7", "Gmaj7", "A7sus4",
             "Gmaj7", "A6", "F#m7", "Bm7", "Em9", "Gmaj7", "A7sus4", "A6",
             "Bm7", "Gmaj7", "Dmaj7", "A6", "Bm7", "Em9", "Gmaj7", "A7sus4",
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
    (16, 0, 1, 78, None), (16, 1, 1, 76, None), (16, 2, 2, 74, 76),
    (17, 0, 2, 71, None), (17, 2, 1, 74, None), (17, 3, 1, 78, None),
    (18, 0, 3, 81, 78), (18, 3, 1, 78, None),
    (19, 0, 2, 76, None), (19, 2, 2, 73, None),
    (20, 0, 1, 74, None), (20, 1, 1, 73, None), (20, 2, 2, 71, 73),
    (21, 0, 2, 67, None), (21, 2, 2, 71, None),
    (22, 0, 3, 74, 71), (22, 3, 1, 78, None),
    (23, 0, 4, 76, 78),
    (24, 0, 2, 79, None), (24, 2, 2, 78, None),
    (25, 0, 2, 76, 78), (25, 2, 1, 73, None), (25, 3, 1, 69, None),
    (26, 0, 3, 73, 71), (26, 3, 1, 76, None),
    (27, 0, 2, 74, 76), (27, 2, 2, 78, None),
    (28, 0, 2, 79, 78), (28, 2, 2, 74, None),
    (29, 0, 4, 71, 74),
    (30, 0, 2, 74, None), (30, 2, 2, 73, 74),
]
# "Saucer Stomp": the boss loop. D minor, quick train beat, and the slide lead turned
# into a wobbly theremin for the aliens.
BOSS_PROG = ["Dm9", "Bbmaj7", "Gm6", "A7sus4", "Dm9", "Bbmaj7", "Gm6", "A7b9",
             "Bbmaj7", "Fmaj7", "Gm6", "Dm9", "Bbmaj7", "Gm6", "A7sus4", "A7b9",
             "Gm6", "Dm9", "Bbmaj7", "A7sus4", "Gm6", "Dm9", "Bbmaj7", "A7b9",
             "Dm9", "Bbmaj7", "Gm6", "A7sus4", "Dm9", "Fmaj7", "Gm6", "A7b9"]
BOSS_MELODY = [
    (4, 0, 1, 74, None), (4, 1, 1, 72, None), (4, 2, 2, 69, 72),
    (5, 0, 2, 70, None), (5, 2, 2, 65, 70),
    (6, 0, 3, 67, 65), (6, 3, 1, 70, None),
    (7, 0, 4, 69, 70),
    (8, 0, 2, 74, None), (8, 2, 1, 77, None), (8, 3, 1, 76, None),
    (9, 0, 3, 72, 74), (9, 3, 1, 69, None),
    (10, 0, 2, 70, None), (10, 2, 2, 67, 70),
    (11, 0, 4, 69, 67),
    (12, 0, 2, 74, None), (12, 2, 2, 77, 74),
    (13, 0, 2, 79, None), (13, 2, 2, 76, None),
    (14, 0, 4, 74, 76),
    (15, 0, 3, 73, 74),
    (16, 0, 2, 70, None), (16, 2, 2, 74, 70),
    (17, 0, 3, 77, 74), (17, 3, 1, 76, None),
    (18, 0, 2, 74, None), (18, 2, 2, 69, 74),
    (19, 0, 4, 74, None),
    (20, 0, 1, 70, None), (20, 1, 1, 74, None), (20, 2, 2, 79, 74),
    (21, 0, 3, 77, 79), (21, 3, 1, 76, None),
    (22, 0, 2, 74, None), (22, 2, 2, 77, None),
    (23, 0, 4, 73, 74),
    (24, 0, 2, 81, None), (24, 2, 2, 77, 81),
    (25, 0, 2, 74, None), (25, 2, 2, 77, 74),
    (26, 0, 3, 76, 77), (26, 3, 1, 74, None),
    (27, 0, 4, 76, 74),
    (28, 0, 1, 74, None), (28, 1, 1, 72, None), (28, 2, 2, 69, 72),
    (29, 0, 2, 72, None), (29, 2, 2, 76, 72),
    (30, 0, 2, 74, 76), (30, 2, 2, 70, None),
    (31, 0, 2, 73, 70),
]

# --- story areas (v0.8.2; they borrowed the Free Ride loops before) ----------------
# "Hayloft Shuffle", Grandma's Farm: C major (written in D, down a tone), a swung
# two-beat with the slide lead playing a front-porch tune.
FARM_PROG = ["D6", "G6", "D6", "A7", "D6", "G6", "A7", "D6",
             "D6", "G6", "D6", "A7", "D6", "G6", "A7", "D6",
             "G6", "G6", "D6", "Bm7", "E9", "E9", "A7sus4", "A7",
             "D6", "G6", "D6", "Bm7", "Em9", "A7", "D6", "A7sus4"]
FARM_MELODY = [
    (8, 0, 1, 66, None), (8, 1, 1, 69, None), (8, 2, 1, 71, None), (8, 3, 1, 74, None),
    (9, 0, 2, 76, 74), (9, 2, 2, 74, None),
    (10, 0, 1.5, 71, None), (10, 1.5, 0.5, 69, None), (10, 2, 2, 66, 69),
    (11, 0, 3, 64, 66), (11, 3, 1, 67, None),
    (12, 0, 1, 66, None), (12, 1, 1, 69, None), (12, 2, 2, 74, 71),
    (13, 0, 2, 71, None), (13, 2, 2, 76, None),
    (14, 0, 2, 73, None), (14, 2, 2, 69, None),
    (15, 0, 4, 74, 73),
    (16, 0, 2, 79, None), (16, 2, 2, 76, None),
    (17, 0, 3, 74, 76), (17, 3, 1, 71, None),
    (18, 0, 2, 78, None), (18, 2, 2, 74, None),
    (19, 0, 4, 71, 74),
    (20, 0, 2, 68, None), (20, 2, 2, 71, 68),
    (21, 0, 2, 74, None), (21, 2, 2, 76, None),
    (22, 0, 3, 74, 76), (22, 3, 1, 76, None),
    (23, 0, 4, 73, 74),
    (24, 0, 1, 66, None), (24, 1, 1, 69, None), (24, 2, 1, 71, None), (24, 3, 1, 74, None),
    (25, 0, 2, 79, 76), (25, 2, 2, 76, None),
    (26, 0, 2, 78, None), (26, 2, 2, 74, None),
    (27, 0, 2, 71, None), (27, 2, 2, 69, None),
    (28, 0, 2, 67, None), (28, 2, 2, 71, None),
    (29, 0, 2, 73, None), (29, 2, 2, 76, 73),
    (30, 0, 4, 74, 76),
]
# "Coal Smoke", the Rail Yard: E minor blues on a train beat, a bit quicker than the
# high trails' loop.
YARD_PROG = ["Em7", "Em7", "Am7", "Em7", "Cmaj7", "B7", "Em7", "B7",
             "Em7", "Em7", "Am7", "Em7", "Cmaj7", "B7", "Em7", "B7",
             "Am7", "Am7", "Em7", "Em7", "Cmaj7", "D6", "B7", "B7",
             "Em7", "Am7", "Em7", "Cmaj7", "Am7", "B7", "Em7", "B7"]
YARD_MELODY = [
    (8, 0, 1, 71, None), (8, 1, 1, 74, None), (8, 2, 2, 76, 74),
    (9, 0, 1.5, 74, None), (9, 1.5, 0.5, 71, None), (9, 2, 2, 67, None),
    (10, 0, 2, 69, None), (10, 2, 2, 72, 69),
    (11, 0, 4, 71, 72),
    (12, 0, 2, 76, None), (12, 2, 1, 79, None), (12, 3, 1, 76, None),
    (13, 0, 3, 75, 76), (13, 3, 1, 78, None),
    (14, 0, 2, 76, None), (14, 2, 2, 71, None),
    (15, 0, 4, 69, 71),
    (16, 0, 2, 81, None), (16, 2, 2, 79, None),
    (17, 0, 3, 76, 79), (17, 3, 1, 72, None),
    (18, 0, 2, 74, None), (18, 2, 2, 71, 74),
    (19, 0, 4, 67, None),
    (20, 0, 2, 72, None), (20, 2, 2, 76, None),
    (21, 0, 2, 78, None), (21, 2, 2, 81, 78),
    (22, 0, 3, 78, 81), (22, 3, 1, 75, None),
    (23, 0, 4, 71, 75),
    (24, 0, 1, 71, None), (24, 1, 1, 74, None), (24, 2, 2, 76, 74),
    (25, 0, 2, 79, None), (25, 2, 2, 76, None),
    (26, 0, 2, 74, None), (26, 2, 2, 71, None),
    (27, 0, 4, 72, 71),
    (28, 0, 2, 69, None), (28, 2, 2, 72, None),
    (29, 0, 2, 75, None), (29, 2, 2, 78, 75),
    (30, 0, 4, 76, 78),
]
# "Windfall", the Old Orchard: slow F major with brushes, for apple trees at dusk.
ORCHARD_PROG = ["Fmaj7", "Dm9", "Gm7", "C7sus4", "Fmaj7", "Bbmaj7", "Gm7", "C7sus4",
                "Fmaj7", "Dm9", "Gm7", "C7sus4", "Fmaj7", "Bbmaj7", "Gm7", "C6",
                "Bbmaj7", "C6", "Dm9", "Dm9", "Bbmaj7", "Fmaj7", "Gm6", "A7b9",
                "Dm9", "Gm7", "C7sus4", "Fmaj7", "Bbmaj7", "Gm7", "C7sus4", "C7sus4"]
ORCHARD_MELODY = [
    (8, 0, 3, 72, 69), (8, 3, 1, 69, None),
    (9, 0, 2, 76, None), (9, 2, 2, 74, 76),
    (10, 0, 3, 70, None), (10, 3, 1, 74, None),
    (11, 0, 4, 72, 74),
    (12, 0, 2, 69, None), (12, 2, 1, 72, None), (12, 3, 1, 76, None),
    (13, 0, 3, 77, 76), (13, 3, 1, 74, None),
    (14, 0, 2, 70, None), (14, 2, 2, 74, None),
    (15, 0, 4, 76, 74),
    (16, 0, 2, 77, None), (16, 2, 2, 81, 77),
    (17, 0, 3, 79, 81), (17, 3, 1, 76, None),
    (18, 0, 2, 77, None), (18, 2, 2, 76, None),
    (19, 0, 4, 74, 76),
    (20, 0, 2, 70, None), (20, 2, 2, 74, None),
    (21, 0, 3, 72, 74), (21, 3, 1, 69, None),
    (22, 0, 2, 70, None), (22, 2, 2, 76, 70),
    (23, 0, 4, 73, 76),
    (24, 0, 3, 74, 73), (24, 3, 1, 77, None),
    (25, 0, 2, 79, None), (25, 2, 2, 77, None),
    (26, 0, 2, 77, None), (26, 2, 2, 72, None),
    (27, 0, 4, 76, 72),
    (28, 0, 2, 74, None), (28, 2, 2, 77, 74),
    (29, 0, 3, 74, 77), (29, 3, 1, 70, None),
    (30, 0, 4, 72, 70),
]
# "County Fair", the Speedway: A mixolydian (written in D, down a fourth), a stomping
# boogie for the wall of death.
FAIR_PROG = ["D6", "C6", "G6", "D6", "D6", "C6", "A7sus4", "A7",
             "D6", "C6", "G6", "D6", "Bm7", "G6", "A7sus4", "A7",
             "G6", "G6", "D6", "D6", "G6", "C6", "A7sus4", "A7",
             "D6", "C6", "G6", "D6", "Bm7", "C6", "A7sus4", "A7"]
FAIR_MELODY = [
    (8, 0, 0.5, 74, None), (8, 0.5, 0.5, 76, None), (8, 1, 1, 78, None), (8, 2, 2, 81, 78),
    (9, 0, 1, 79, None), (9, 1, 1, 76, None), (9, 2, 2, 72, None),
    (10, 0, 2, 74, None), (10, 2, 1, 71, None), (10, 3, 1, 74, None),
    (11, 0, 4, 78, 76),
    (12, 0, 1, 78, None), (12, 1, 1, 81, None), (12, 2, 2, 83, 81),
    (13, 0, 2, 79, None), (13, 2, 2, 76, None),
    (14, 0, 2, 74, None), (14, 2, 2, 76, None),
    (15, 0, 4, 73, 74),
    (16, 0, 2, 71, None), (16, 2, 2, 74, None),
    (17, 0, 3, 76, 74), (17, 3, 1, 79, None),
    (18, 0, 2, 78, None), (18, 2, 2, 81, None),
    (19, 0, 4, 83, 81),
    (20, 0, 2, 83, None), (20, 2, 2, 79, None),
    (21, 0, 2, 76, None), (21, 2, 2, 72, 76),
    (22, 0, 3, 74, 72), (22, 3, 1, 76, None),
    (23, 0, 4, 79, 76),
    (24, 0, 0.5, 74, None), (24, 0.5, 0.5, 76, None), (24, 1, 1, 78, None), (24, 2, 2, 81, 78),
    (25, 0, 2, 79, None), (25, 2, 2, 76, None),
    (26, 0, 2, 74, None), (26, 2, 2, 71, None),
    (27, 0, 4, 74, 71),
    (28, 0, 2, 78, None), (28, 2, 2, 81, None),
    (29, 0, 2, 79, None), (29, 2, 2, 76, None),
    (30, 0, 2, 74, None), (30, 2, 2, 73, 74),
]
VARIANTS = {
    "trestle_dreams": {},
    "lantern_low": dict(bpm=68.0, bars=32, prog=LOW_PROG, melody=LOW_MELODY, intro=4, style="sparse",
                        lead_from=8, seed=2031, gtr_lp=4200, mix_db={"drums": -14, "pad": -5}),
    "ridge_runner": dict(bpm=96.0, bars=32, prog=HIGH_PROG, melody=HIGH_MELODY, intro=2, style="train",
                         trans=2, lead_from=8, seed=1890, mix_db={"drums": -9, "bass": -7}),
    "saucer_stomp": dict(bpm=116.0, bars=32, prog=BOSS_PROG, melody=BOSS_MELODY, intro=1, style="train",
                         lead_from=4, seed=4242, gtr_lp=5200, vib=48.0, mix_db={"drums": -7, "bass": -6, "lead": -4}),
    "hayloft_shuffle": dict(bpm=92.0, bars=32, prog=FARM_PROG, melody=FARM_MELODY, intro=4, style="shuffle",
                            swing=0.17, trans=-2, lead_from=8, seed=1952, gtr_lp=7000, vib=14.0,
                            mix_db={"drums": -10, "bass": -7}),
    "coal_smoke": dict(bpm=104.0, bars=32, prog=YARD_PROG, melody=YARD_MELODY, intro=2, style="train",
                       lead_from=8, seed=1869, gtr_lp=6000, vib=16.0, mix_db={"drums": -9, "bass": -6}),
    "windfall": dict(bpm=72.0, bars=32, prog=ORCHARD_PROG, melody=ORCHARD_MELODY, intro=4, style="brush",
                     lead_from=8, seed=1937, gtr_lp=6000, vib=10.0, mix_db={"drums": -12, "pad": -6}),
    "county_fair": dict(bpm=120.0, bars=32, prog=FAIR_PROG, melody=FAIR_MELODY, intro=2, style="stomp",
                        trans=-5, lead_from=8, seed=1910, gtr_lp=7000, vib=9.0,
                        mix_db={"drums": -8, "bass": -6, "lead": -5}),
}


def render_variant(name):
    configure(**VARIANTS[name])
    y = render()
    configure()
    return y
