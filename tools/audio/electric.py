"""Electric drive loops for the battery bikes, the e-bikes and the electric unicycles.

There's no combustion here, so the sound is built from what an electric drive does
make (reasoning from how these drives work, not from recordings):
  motor whine   the stator's electrical frequency and its orders (6th and 12th are
                the torque-ripple orders of a three-phase motor), so it rises with speed
  inverter      a quiet PWM carrier tone with sidebands two electrical orders out
  gears         a hub or mid-drive gearbox adds a mesh tone (an e-bike's signature)
  chain / belt  band noise pulsing at the sprocket rate
  tires         road roar; knobby and fat tires add tread-block pulses
Idle is a "ready" hum: the controller's low buzz and a faint high tone, much quieter
than a combustion idle. All tones are whole cycles over the loop and noise is filtered
circularly, so the loops repeat seamlessly; in game the cruise loop is pitch-shifted
with speed like the engine loops.
"""
import numpy as np

from dsp import SR, sos_bp, sos_hp, sos_lp, sosc, soft_clip, norm_lufs

# f0: electrical frequency at cruise (Hz). orders: (multiple of f0, level).
# pwm: (carrier Hz, level). gear: (mesh multiple of f0, level) or None.
# chain: level of chain / belt noise; sprocket: its pulse rate (Hz).
# tire: road noise level; knobby: tread pulse depth; tread: tread pulse rate (Hz).
# idle: (hum Hz, high tone Hz, tick rate Hz or 0) for the ready hum.
MOTORS = {
    # Electric dirt bike: mid motor, chain, knobby tyres.
    "spark": dict(f0=290.0, orders=[(1, 1.0), (2, 0.3), (3, 0.18), (6, 0.45), (12, 0.1)],
                  pwm=(6100.0, 0.035), gear=None, chain=0.55, sprocket=31.0,
                  tire=0.45, knobby=0.55, tread=41.0, idle=(100.0, 2350.0, 0.0), drive=1.4),
    # Electric streetbike: big motor, belt, smooth tyres. Deeper and stronger.
    "surge": dict(f0=380.0, orders=[(1, 1.0), (2, 0.4), (3, 0.12), (6, 0.6), (12, 0.18)],
                  pwm=(7900.0, 0.03), gear=None, chain=0.2, sprocket=26.0,
                  tire=0.35, knobby=0.0, tread=0.0, idle=(110.0, 1900.0, 0.0), drive=1.5),
    # Electric moped: a rear hub motor, small wheels, a bit buzzy.
    "zip": dict(f0=520.0, orders=[(1, 1.0), (2, 0.5), (4, 0.2), (6, 0.35)],
                pwm=(4900.0, 0.05), gear=None, chain=0.0, sprocket=0.0,
                tire=0.3, knobby=0.0, tread=0.0, idle=(120.0, 2800.0, 0.0), drive=1.6),
    # Commuter e-bike: geared mid-drive whir, chain, freewheel ticking at idle.
    "commuter": dict(f0=230.0, orders=[(1, 0.5), (2, 0.25), (6, 0.2)],
                     pwm=(5600.0, 0.03), gear=(7.0, 0.9), chain=0.6, sprocket=19.0,
                     tire=0.3, knobby=0.0, tread=0.0, idle=(90.0, 1600.0, 21.0), drive=1.3),
    # Fat-tyre e-bike: geared hub, and the fat knobby tyres roar.
    "boulder": dict(f0=200.0, orders=[(1, 0.5), (2, 0.25), (6, 0.2)],
                    pwm=(5200.0, 0.03), gear=(9.0, 0.7), chain=0.45, sprocket=17.0,
                    tire=0.75, knobby=0.7, tread=27.0, idle=(85.0, 1500.0, 17.0), drive=1.4),
    # Electric unicycle: a direct-drive hub motor right under the rider, a clean high
    # whine; at a standstill it hums as it balances.
    "mono": dict(f0=460.0, orders=[(1, 1.0), (2, 0.3), (4, 0.15), (6, 0.3), (12, 0.08)],
                 pwm=(9100.0, 0.03), gear=None, chain=0.0, sprocket=0.0,
                 tire=0.3, knobby=0.0, tread=0.0, idle=(130.0, 1240.0, 0.0), drive=1.3),
    # Big off-road unicycle: lower, beefier, knobby tyre.
    "goliath": dict(f0=340.0, orders=[(1, 1.0), (2, 0.4), (3, 0.15), (6, 0.45), (12, 0.12)],
                    pwm=(7300.0, 0.035), gear=None, chain=0.0, sprocket=0.0,
                    tire=0.45, knobby=0.5, tread=33.0, idle=(115.0, 1020.0, 0.0), drive=1.4),
}


def _hz(f, n):
    """Nearest frequency with a whole number of cycles in the loop."""
    loop_s = n / SR
    return max(1.0, round(f * loop_s)) / loop_s


def _phase(t, f, n, rng, vib=0.004, vib_hz=2.3):
    """Running phase of a tone at f with a slow, loop-periodic wobble (vib = depth as a
    share of f). Harmonics multiply this phase, so they wobble together."""
    f = _hz(f, n)
    fm = _hz(vib_hz, n)
    return 2 * np.pi * f * t + (vib * f / fm) * np.sin(2 * np.pi * fm * t + rng.random() * 6.28)


def _band(rng, n, lo, hi):
    return sosc(sos_bp(lo, hi), rng.standard_normal(n))


def render(name, state, target_s=8.0, seed=7):
    p = MOTORS[name]
    rng = np.random.default_rng(seed + (0 if state == "idle" else 1000) + sum(map(ord, name)))
    n = int(round(target_s * SR))
    t = np.arange(n) / SR
    y = np.zeros(n)

    if state == "idle":
        hum_hz, high_hz, tick_hz = p["idle"]
        ph = _phase(t, hum_hz, n, rng, vib=0.002)
        hum = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        y += 0.5 * hum
        # The controller's faint high tone (and, on a unicycle, its balancing wobble).
        hp = _phase(t, high_hz, n, rng, vib=0.012 if name in ("mono", "goliath") else 0.003, vib_hz=1.3)
        y += 0.14 * np.sin(hp) + 0.04 * np.sin(2 * hp)
        y += 0.05 * _band(rng, n, 2000, 6000)
        if tick_hz > 0:
            # Freewheel pawls ticking.
            ticks = np.zeros(n)
            step = n / round(tick_hz * target_s)
            k = np.arange(int(round(tick_hz * target_s)))
            pos = (k * step + rng.normal(0, 0.03, k.size) * step).astype(int) % n
            ticks[pos] = 1.0 + 0.2 * rng.standard_normal(k.size)
            click = sosc(sos_bp(2500, 7000), ticks)
            y += 1.6 * click / (np.max(np.abs(click)) + 1e-9) * 0.35
        y = y / (np.max(np.abs(y)) + 1e-9)
        y = soft_clip(y, 1.1)
        y = sosc(sos_hp(40), y)
        y = sosc(sos_lp(8000), y)
        y = norm_lufs(y, -30.0)
    else:
        ph = _phase(t, p["f0"], n, rng)
        whine = np.zeros(n)
        for k, g in p["orders"]:
            whine += g * np.sin(k * ph + rng.random() * 6.28)
        # Load swell: the whine breathes a little.
        sw = 1.0
        for f_sw, amt in ((0.7, 0.08), (1.9, 0.05)):
            sw = sw + amt * np.sin(2 * np.pi * _hz(f_sw, n) * t + rng.random() * 6.28)
        y += 0.55 * whine * sw
        fc, pw = p["pwm"]
        cph = 2 * np.pi * _hz(fc, n) * t
        y += pw * (np.sin(cph) + 0.5 * np.sin(cph + 2 * ph) + 0.5 * np.sin(cph - 2 * ph))
        if p["gear"]:
            gm, gg = p["gear"]
            gph = gm * ph
            gear = np.sin(gph) + 0.3 * np.sin(gph + ph) + 0.3 * np.sin(gph - ph) + 0.15 * np.sin(2 * gph)
            y += 0.3 * gg * gear * (1.0 + 0.3 * _band(rng, n, 2, 12) / 3.0)
        if p["chain"] > 0:
            pulse = 0.6 + 0.4 * np.sin(2 * np.pi * _hz(p["sprocket"], n) * t)
            ch = _band(rng, n, 500, 2600)
            y += 0.12 * p["chain"] * ch / (np.std(ch) + 1e-9) * pulse
        road = _band(rng, n, 70, 900)
        road = road / (np.std(road) + 1e-9)
        if p["knobby"] > 0:
            tread = 1.0 - p["knobby"] * 0.5 * (1.0 + np.sin(2 * np.pi * _hz(p["tread"], n) * t))
            road = road * tread
        y += 0.16 * p["tire"] * road
        y += 0.03 * _band(rng, n, 1500, 5000)  # air past the rider
        y = y / (np.max(np.abs(y)) + 1e-9)
        y = soft_clip(y, p["drive"])
        y = sosc(sos_hp(45), y)
        y = sosc(sos_lp(9000), y)
        y = norm_lufs(y, -21.0)
    pk = np.max(np.abs(y))
    if pk > 0.89:
        y *= 0.89 / pk
    meta = {"f0": round(_hz(p["f0"], n), 1), "seconds": round(n / SR, 3), "electric": True}
    return y, meta
