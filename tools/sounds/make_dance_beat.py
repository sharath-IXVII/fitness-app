"""The dance beat for the Dance alarm: 8 bars at 120 BPM (16 s), made to
loop without a click. Four-on-the-floor kick, off-beat hats, a clap on 2 and
4, a bouncy bass and FittArc's arc motif (two taps and a rising note) on top."""
import sys, wave
import numpy as np

SR = 22050
BPM = 120
BEAT = 60 / BPM
BARS = 8
N = int(SR * BEAT * 4 * BARS)

def tone(f, dur, decay, shape='sine', glide=None):
    n = int(SR * dur); t = np.arange(n) / SR
    fr = np.full(n, f) if glide is None else glide + (f - glide) * (1 - np.exp(-t * 30))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    w = np.sin(ph) if shape == 'sine' else np.sign(np.sin(ph)) * 0.35 + np.sin(ph) * 0.65
    return w * np.exp(-decay * t) * np.minimum(1, t / 0.003)

def kick():
    n = int(SR * 0.25); t = np.arange(n) / SR
    f = 48 + 130 * np.exp(-35 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-12 * t)

rng = np.random.default_rng(7)
def noise(dur, decay, hp=True):
    n = int(SR * dur); x = rng.standard_normal(n)
    if hp: x = np.diff(x, prepend=0)
    return x * np.exp(-decay * np.arange(n) / SR)

out = np.zeros(N + SR)
def put(at, sig, g):
    i = int(at * SR); out[i:i + len(sig)] += g * sig

bass = [41.2, 41.2, 55.0, 49.0]  # E1 E1 A1 G1 per bar
for bar in range(BARS):
    b0 = bar * 4 * BEAT
    for k in range(4):
        put(b0 + k * BEAT, kick(), 0.9)
        put(b0 + k * BEAT + BEAT / 2, noise(0.05, 90), 0.12)
        if k in (1, 3): put(b0 + k * BEAT, noise(0.18, 22, hp=False), 0.22)
        root = bass[bar % 4]
        put(b0 + k * BEAT + BEAT / 2, tone(root * 2, BEAT / 2, 6, 'square'), 0.28)
    if bar % 2 == 1:  # the arc motif every other bar
        put(b0 + 0, tone(659.26, 0.14, 18), 0.22)
        put(b0 + 0.25, tone(659.26, 0.14, 18), 0.22)
        put(b0 + 0.5, tone(987.77, 0.9, 4, glide=830), 0.3)

loop = out[:N] + np.concatenate([out[N:N + SR], np.zeros(N - SR)])  # fold the tail in: seamless loop
loop = np.tanh(loop * 1.2) / np.tanh(1.2)
loop = loop / np.abs(loop).max() * 0.85
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((loop * 32767).astype('<i2').tobytes())
print('ok', round(N / SR, 1), 's')
