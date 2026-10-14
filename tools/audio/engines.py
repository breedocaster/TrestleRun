"""Physically-modelled motorcycle engine loops, one per bike model.

Model: per-cylinder combustion pulses placed at the engine's real firing angles
-> exhaust pipe waveguide(s) (open-end reflection = quarter-wave resonances)
-> muffler/body EQ -> combustion rasp, valvetrain/gear/CVT mechanicals.
Loops are an exact whole number of engine cycles and filtered circularly, so they
repeat seamlessly. In game the loop is pitch-shifted for speed changes and revs.

Firing layouts (crank degrees in one cycle):
  chopper   45-degree V-twin, single crankpin      0, 315        (720 cycle)  "potato-potato"
  scrambler 270-degree parallel twin               0, 270        (720)
  dirt      4-stroke single                        0             (720)
  sport     inline-4, 180-degree flat crank        0,180,360,540 (720)
  cafe      inline-3, 120-degree crank             0,240,480     (720)
  scooter   2-stroke single, expansion chamber     0             (360)
  minibike  OHV 212cc single, small can muffler    0             (720)
"""
import numpy as np

from dsp import SR, sos_lp, sos_hp, sos_bp, peak, sosc, lfc, soft_clip, norm_lufs

ENGINES = {
    "chopper": dict(
        strokes=4, fire=[0, 315], gain=[1.0, 0.86], idle=950, cruise=2500,
        tau_ms=2.4, rise_ms=0.35, neg=0.45, jit_amp=(0.16, 0.07), jit_t=0.012,
        pipes=[(1.05, 0.66, 1.0), (1.18, 0.6, 0.8)], c=510.0,
        muffler=2300, res=[(110, 2, 1.2), (310, 8, 1.3), (680, 7, 1.6), (1250, 4, 2.0)], rad=0.5,
        rasp=0.7, rasp_band=(400, 2400), drive=(1.8, 2.5), low_cut=0.75,
        tick=0.012, whine=[], intake=0.03,
    ),
    "scrambler": dict(
        strokes=4, fire=[0, 270], gain=[1.0, 0.95], idle=1150, cruise=4300,
        tau_ms=1.6, rise_ms=0.25, neg=0.4, jit_amp=(0.1, 0.05), jit_t=0.008,
        pipes=[(0.92, 0.6, 1.0), (0.95, 0.6, 1.0)], c=520.0,
        muffler=2600, res=[(160, 2, 1.4), (430, 8, 1.5), (1000, 6, 2.0)], rad=0.5,
        rasp=0.6, rasp_band=(600, 3000), drive=(1.6, 2.1), low_cut=0.65,
        tick=0.012, whine=[(19.0, 0.004)], intake=0.04,
    ),
    "dirt": dict(
        strokes=4, fire=[0], gain=[1.0], idle=1750, cruise=6400,
        tau_ms=1.0, rise_ms=0.15, neg=0.5, jit_amp=(0.12, 0.06), jit_t=0.01,
        pipes=[(1.12, 0.55, 1.0)], c=530.0,
        muffler=3200, res=[(250, 3, 1.5), (780, 7, 2.0), (1700, 5, 2.5)], rad=0.6,
        rasp=0.7, rasp_band=(800, 4200), drive=(2.0, 2.8), low_cut=0.6,
        tick=0.03, whine=[(14.0, 0.003)], intake=0.06,
    ),
    "sport": dict(
        strokes=4, fire=[0, 180, 360, 540], gain=[1.0, 0.97, 1.02, 0.95], idle=1300, cruise=7600,
        tau_ms=0.6, rise_ms=0.12, neg=0.35, jit_amp=(0.08, 0.03), jit_t=0.004,
        pipes=[(0.68, 0.5, 1.0), (0.42, 0.45, 0.5)], c=540.0,
        muffler=4200, res=[(500, 4, 1.6), (1300, 6, 2.2), (2700, 4, 2.5)], rad=0.6,
        rasp=0.45, rasp_band=(1200, 5500), drive=(1.3, 1.7),
        tick=0.006, whine=[(22.0, 0.006), (44.0, 0.002)], intake=0.08,
    ),
    "cafe": dict(
        strokes=4, fire=[0, 240, 480], gain=[1.0, 0.9, 0.96], idle=1150, cruise=5600,
        tau_ms=1.0, rise_ms=0.2, neg=0.4, jit_amp=(0.09, 0.04), jit_t=0.006,
        pipes=[(0.86, 0.62, 1.0)], c=520.0,
        muffler=3000, res=[(210, 2, 1.3), (560, 8, 1.6), (1300, 6, 2.0)], rad=0.55,
        rasp=0.7, rasp_band=(700, 3600), drive=(1.6, 2.3), low_cut=0.8, low_cut_hz=240,
        tick=0.012, whine=[(17.0, 0.004)], intake=0.05,
    ),
    "scooter": dict(
        strokes=2, fire=[0], gain=[1.0], idle=1900, cruise=7400,
        tau_ms=0.35, rise_ms=0.08, neg=0.55, jit_amp=(0.22, 0.06), jit_t=0.01, skip=(0.28, 0.02),
        pipes=[(0.55, 0.8, 1.0)], c=520.0,
        muffler=3400, res=[(470, 5, 2.5), (1120, 9, 3.0), (2300, 4, 3.0)], rad=0.5,
        rasp=0.5, rasp_band=(1500, 5000), drive=(1.6, 2.2), low_cut=0.85,
        tick=0.0, whine=[(5.6, 0.012), (11.2, 0.005), (16.8, 0.002)], intake=0.05,
    ),
    "minibike": dict(
        strokes=4, fire=[0], gain=[1.0], idle=1800, cruise=4200,
        tau_ms=1.2, rise_ms=0.2, neg=0.45, jit_amp=(0.1, 0.06), jit_t=0.01,
        pipes=[(0.26, 0.45, 1.0)], c=520.0,
        muffler=2600, res=[(340, 4, 1.6), (1050, 8, 3.0), (2200, 4, 3.0)], rad=0.5,
        rasp=0.55, rasp_band=(900, 3800), drive=(1.8, 2.4),
        tick=0.045, whine=[], intake=0.05, fan=0.05,
    ),
}


def _loop_len(rpm, strokes, target_s):
    cycle_s = (2.0 if strokes == 4 else 1.0) * 60.0 / rpm
    k = max(8, int(round(target_s / cycle_s)))
    n = int(round(k * cycle_s * SR))
    return n, k, n / k


def _seamless_hz(f, n):
    loop_s = n / SR
    return max(1.0, round(f * loop_s)) / loop_s


def render(name, state, target_s=4.0, seed=7):
    p = ENGINES[name]
    rng = np.random.default_rng(seed + (0 if state == "idle" else 1000) + sum(map(ord, name)))
    load = 0.35 if state == "idle" else 1.0
    li = 0 if state == "idle" else 1
    rpm = p["idle"] if state == "idle" else p["cruise"]
    cyc_deg = 720.0 if p["strokes"] == 4 else 360.0
    n, k, cyc = _loop_len(rpm, p["strokes"], target_s)
    crank_hz = (cyc_deg / 360.0) * SR / cyc  # revolutions per second actually used

    # --- combustion pulses -------------------------------------------------------
    # Blowdown pulse: near-instant rise when the exhaust valve cracks open, then
    # decay, then a slower negative scavenging lobe.
    tau = p["tau_ms"] / 1000.0 * SR
    tr = p.get("rise_ms", 0.25) / 1000.0 * SR
    kt = np.arange(int(tau * 16))
    kern = (1 - np.exp(-kt / tr)) * np.exp(-kt / tau) - p["neg"] * (kt / (3 * tau)) * np.exp(1 - kt / (3 * tau))
    kern /= np.max(np.abs(kern))
    rasp_tau = tau * 3.5
    rk = np.exp(-np.arange(int(rasp_tau * 8)) / rasp_tau)

    pulses = np.zeros(n)
    rasp_env = np.zeros(n)
    tick_ex = np.zeros(n)
    skip = p.get("skip", (0.0, 0.0))[li]
    interval = cyc / len(p["fire"])
    # RPM wander: cycle lengths drift a little but still sum to the loop length.
    wander = np.convolve(rng.standard_normal(k + 8), np.hanning(9), "same")[4:4 + k]
    durs = 1.0 + p.get("wander", 0.012) * wander / (np.std(wander) + 1e-9)
    durs *= k / durs.sum()
    starts = np.concatenate([[0.0], np.cumsum(durs)[:-1]]) * cyc
    drift = 0.0
    for c in range(k):
        drift = 0.85 * drift + 0.15 * rng.standard_normal()  # slow combustion wander
        for i, ang in enumerate(p["fire"]):
            pos = starts[c] + (ang / cyc_deg) * cyc * durs[c] + p["jit_t"] * interval * rng.standard_normal()
            a = p["gain"][i] * (1.0 + p["jit_amp"][li] * (0.6 * rng.standard_normal() + 0.4 * drift))
            if skip and rng.random() < skip:
                a *= 0.12
            a = max(a, 0.05)
            i0 = int(np.floor(pos)) % n
            idx = (i0 + np.arange(len(kern))) % n
            np.add.at(pulses, idx, a * kern)
            idx = (i0 + np.arange(len(rk))) % n
            np.add.at(rasp_env, idx, a * rk)
            if p["tick"] > 0:  # valve events: two per cylinder per cycle
                for off in (0.32, 0.61):
                    j = int((pos + off * cyc) % n)
                    tick_ex[j] += 0.6 + 0.4 * rng.random()

    # --- exhaust waveguides (round trip delay, inverting open end, lossy) ---------
    ex = np.zeros(n)
    for length, refl, g in p["pipes"]:
        d = max(2, int(round(2.0 * length / p["c"] * SR)))
        a = np.zeros(d + 2)
        a[0] = 1.0
        a[d] += refl * 0.5
        a[d + 1] += refl * 0.5
        ex += g * lfc([1.0], a, pulses)

    # --- combustion rasp ----------------------------------------------------------
    noise = rng.standard_normal(n)
    noise = sosc(sos_bp(*p["rasp_band"]), noise)
    ex += p["rasp"] * load * rasp_env * noise * 0.9

    # --- muffler / body -----------------------------------------------------------
    y = sosc(sos_lp(p["muffler"]), ex)
    for f0, g, q in p["res"]:
        y = sosc(peak(f0, g, q), y)
    y = y + p["rad"] * sosc(sos_hp(900), y)
    # Phones can't reproduce the sub-150 Hz thump; trade some of it for audible bark.
    y = y - p.get("low_cut", 0.5) * sosc(sos_lp(p.get("low_cut_hz", 150)), y)

    # --- mechanicals --------------------------------------------------------------
    rms = np.sqrt(np.mean(y ** 2)) + 1e-9
    mech = np.zeros(n)
    if p["tick"] > 0:
        click = rng.standard_normal(90) * np.exp(-np.arange(90) / 14.0)
        tk = np.real(np.fft.ifft(np.fft.fft(tick_ex) * np.fft.fft(np.pad(click, (0, n - 90)))))
        mech += p["tick"] * sosc(sos_hp(3200), tk) * rms * 6
    t = np.arange(n) / SR
    for order, lvl in p["whine"]:
        f = _seamless_hz(crank_hz * order, n)
        wob = 1 + 0.002 * np.sin(2 * np.pi * _seamless_hz(0.7, n) * t)
        mech += lvl * rms * 40 * np.sin(2 * np.pi * f * t * wob) * (0.6 + 0.4 * load)
    if p.get("fan"):
        fanmod = 0.6 + 0.4 * np.sin(2 * np.pi * _seamless_hz(crank_hz, n) * t)
        mech += p["fan"] * rms * 12 * sosc(sos_bp(1400, 4200), rng.standard_normal(n)) * fanmod
    if p["intake"] > 0:
        mech += p["intake"] * rms * 10 * load * sosc(sos_bp(250, 1400), rng.standard_normal(n))
    y = y + mech

    # Slow swells, like throttle/load and exhaust turbulence (periodic over the loop).
    sw = np.zeros(n)
    for f_sw, amt in ((_seamless_hz(0.6, n), 0.06), (_seamless_hz(1.7, n), 0.05), (_seamless_hz(3.3, n), 0.03)):
        sw += amt * np.sin(2 * np.pi * f_sw * t + rng.random() * 6.28)
    y = y * (1.0 + sw * (1.4 if state == "cruise" else 1.0))

    # --- drive, cleanup, level ------------------------------------------------------
    y = y / (np.max(np.abs(y)) + 1e-9)
    y = soft_clip(y, p["drive"][li])
    y = sosc(sos_hp(32), y)
    y = sosc(sos_lp(9000), y)
    y = norm_lufs(y, -24.0 if state == "idle" else -20.0)
    pk = np.max(np.abs(y))
    if pk > 0.89:
        y *= 0.89 / pk
    meta = {"rpm": round(crank_hz * 60), "fire_hz": round(crank_hz * len(p["fire"]) * (360.0 / cyc_deg), 1),
            "seconds": round(n / SR, 3), "cycles": k}
    return y, meta
