"""Shared DSP helpers for the offline audio build (numpy/scipy).

Everything that must loop is processed *circularly*: filters run over the signal
tiled three times and the middle copy is kept, so the loop seam is the filter's
steady state and clicks are impossible.
"""
import os
import subprocess
import tempfile

import numpy as np
import pyloudnorm
from scipy import signal
from scipy.io import wavfile

SR = 44100


def db(x):
    return 10 ** (x / 20.0)


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


# --- filtering ---------------------------------------------------------------

def sos_lp(fc, order=2):
    return signal.butter(order, fc, "lowpass", fs=SR, output="sos")


def sos_hp(fc, order=2):
    return signal.butter(order, fc, "highpass", fs=SR, output="sos")


def sos_bp(lo, hi, order=2):
    return signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos")


def peak(f0, gain_db, q):
    """RBJ peaking EQ as an sos row."""
    a = 10 ** (gain_db / 40.0)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * a, -2 * np.cos(w), 1 - al * a]
    aa = [1 + al / a, -2 * np.cos(w), 1 - al / a]
    return np.array([[b[0] / aa[0], b[1] / aa[0], b[2] / aa[0], 1.0, aa[1] / aa[0], aa[2] / aa[0]]])


def circ(fn, x):
    """Apply fn to a loop so the result is seamless: run on 3 copies, keep middle."""
    n = x.shape[0]
    y = fn(np.concatenate([x, x, x], axis=0))
    return y[n:2 * n]


def sosc(sos, x):
    return circ(lambda v: signal.sosfilt(sos, v, axis=0), x)


def lfc(b, a, x):
    return circ(lambda v: signal.lfilter(b, a, v, axis=0), x)


# --- reverb --------------------------------------------------------------------

def make_ir(seconds=2.4, damp_hz=3500.0, pre_ms=18.0, seed=1, stereo=True):
    """Exponentially decaying noise IR with high frequencies dying faster."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    chans = []
    for c in range(2 if stereo else 1):
        noise = rng.standard_normal(n)
        # Split bands so highs decay quicker (darker tail = dreamier).
        lo = signal.sosfilt(sos_lp(damp_hz), noise)
        hi = noise - lo
        rt_lo, rt_hi = seconds, seconds * 0.35
        ir = lo * np.exp(-6.9 * t / rt_lo) + hi * np.exp(-6.9 * t / rt_hi)
        ir *= 1.0 - np.exp(-t / 0.012)  # soft onset
        pre = np.zeros(int(pre_ms * SR / 1000))
        ir = np.concatenate([pre, ir])
        chans.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.stack(chans, axis=1) if stereo else chans[0]


def conv_reverb(x, ir, wet, circular=False):
    """x mono or stereo; ir stereo. Returns stereo dry+wet."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    n = x.shape[0]
    out = np.zeros_like(x)
    for c in range(2):
        if circular:
            m = n
            h = np.zeros(n)
            hl = ir[:, c][: n] if ir.shape[0] >= n else ir[:, c]
            h[: len(hl)] = hl
            if ir.shape[0] > n:  # fold long tails around the loop
                rest = ir[n:, c]
                for k in range(0, len(rest), n):
                    seg = rest[k:k + n]
                    h[: len(seg)] += seg
            wetc = np.real(np.fft.ifft(np.fft.fft(x[:, c]) * np.fft.fft(h)))[:m]
        else:
            wetc = signal.fftconvolve(x[:, c], ir[:, c])[:n]
        out[:, c] = x[:, c] * (1 - wet) + wetc * wet * 2.2
    return out


def pad_tail(x, seconds):
    z = np.zeros((int(seconds * SR),) + x.shape[1:])
    return np.concatenate([x, z], axis=0)


# --- loudness / output -----------------------------------------------------------

_meter = pyloudnorm.Meter(SR)


def lufs(x):
    """Integrated loudness; very short clips are padded (silence is gated out)."""
    need = int(0.5 * SR)
    if x.shape[0] < need:
        x = np.concatenate([x, np.zeros((need - x.shape[0],) + x.shape[1:])], axis=0)
    return _meter.integrated_loudness(x)


def norm_lufs(x, target):
    l = lufs(x)
    if not np.isfinite(l):
        return x
    return x * db(target - l)


def norm_peak(x, peak_db=-1.0):
    m = np.max(np.abs(x))
    return x if m == 0 else x * db(peak_db) / m


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def fade(x, fin=0.0, fout=0.0):
    x = x.copy()
    if fin > 0:
        n = int(fin * SR)
        x[:n] *= np.linspace(0, 1, n)[:, None] if x.ndim > 1 else np.linspace(0, 1, n)
    if fout > 0:
        n = int(fout * SR)
        x[-n:] *= np.linspace(1, 0, n)[:, None] if x.ndim > 1 else np.linspace(1, 0, n)
    return x


def loop_xfade(x, start, length, xf):
    """Cut [start, start+length) from a recording and make it loop with an
    equal-power crossfade of xf seconds (tail blended into head)."""
    s, n, f = int(start * SR), int(length * SR), int(xf * SR)
    body = x[s:s + n].copy()
    tail = x[s + n:s + n + f]
    t = np.linspace(0, np.pi / 2, f)
    fi, fo = np.sin(t), np.cos(t)
    if body.ndim > 1:
        fi, fo = fi[:, None], fo[:, None]
    body[:f] = body[:f] * fi + tail * fo
    return body


def write_ogg(path, x, quality=4):
    x = np.clip(x, -1.0, 1.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wavfile.write(tf.name, SR, (x * 32767).astype(np.int16))
        tmp = tf.name
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path],
                   check=True)
    os.unlink(tmp)


def read_audio(path, mono=False):
    """Decode anything ffmpeg understands to float at SR."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tmp = tf.name
    args = ["ffmpeg", "-v", "error", "-y", "-i", path, "-ar", str(SR)]
    if mono:
        args += ["-ac", "1"]
    subprocess.run(args + [tmp], check=True)
    sr, x = wavfile.read(tmp)
    os.unlink(tmp)
    x = x.astype(np.float64) / 32768.0
    return x
