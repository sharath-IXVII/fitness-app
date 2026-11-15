"""FittArc's own notification sounds. One motif for every kind, so the app is
recognised by ear: two short taps and a long note that curves upward like an
arc ("ta-ta-TAA"). Each kind plays it in its own voice."""
import sys, wave
import numpy as np

SR = 44100
E5, B5, E6, E4, B4 = 659.26, 987.77, 1318.51, 329.63, 493.88

def env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack)
    return a * np.exp(-decay * t)

def note(f0, dur, partials, decay, glide_from=None, glide_time=0.07):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = np.full(n, f0)
    if glide_from:
        k = np.clip(t / glide_time, 0, 1)
        f = glide_from + (f0 - glide_from) * (1 - (1 - k) ** 2)  # eases up, like an arc
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for mult, amp in partials:
        out += amp * np.sin(mult * phase) * env(n, decay=decay * (1 + 0.6 * (mult - 1)))
    return out

def kick(dur=0.12):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 55 + 110 * np.exp(-40 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-28 * t)

def drop(f0, dur=0.22):
    """A water drop: a quick upward chirp that dies fast."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f0 * (0.55 + 0.45 * np.clip(t / 0.045, 0, 1) ** 0.6)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, attack=0.003, decay=16)

def mix(total, parts):
    out = np.zeros(int(SR * total))
    for at, sig, gain in parts:
        i = int(SR * at)
        m = min(len(sig), len(out) - i)
        out[i:i + m] += gain * sig[:m]
    return out

BELL = [(1, 1.0), (2, 0.38), (3, 0.14), (4.2, 0.07)]
WARM = [(1, 1.0), (2, 0.5), (3, 0.28), (4, 0.14), (5, 0.07)]

def signature():
    return mix(1.35, [
        (0.00, note(E5, 0.16, BELL, 22), 0.75),
        (0.13, note(E5, 0.16, BELL, 22), 0.75),
        (0.27, note(B5, 1.05, BELL, 4.2, glide_from=B5 * 0.84), 1.0),
        (0.30, note(E6, 0.95, [(1, 1.0)], 5.5), 0.22),  # shimmer on top
    ])

def water():
    return mix(1.15, [
        (0.00, drop(E5), 0.8),
        (0.13, drop(E5), 0.8),
        (0.27, drop(B5, 0.5), 1.0),
        (0.27, note(B5, 0.8, [(1, 1.0), (2, 0.2)], 6.5, glide_from=B5 * 0.84), 0.45),
        (0.52, drop(E6, 0.3), 0.35),
    ])

def workout():
    return mix(1.4, [
        (0.00, kick(), 0.9), (0.00, note(E4, 0.18, WARM, 18), 0.6), (0.00, note(E5, 0.18, WARM, 18), 0.5),
        (0.13, kick(), 0.9), (0.13, note(E4, 0.18, WARM, 18), 0.6), (0.13, note(E5, 0.18, WARM, 18), 0.5),
        (0.27, kick(0.16), 1.0),
        (0.27, note(B4, 1.05, WARM, 4.0, glide_from=B4 * 0.84), 0.6),
        (0.27, note(E5, 1.05, WARM, 4.0, glide_from=E5 * 0.84), 0.7),
        (0.27, note(B5, 1.05, BELL, 4.4, glide_from=B5 * 0.84), 0.7),
    ])

def social():
    """The motif, then a softer answer a little higher: a friend calling back."""
    return mix(1.7, [
        (0.00, note(E5, 0.16, BELL, 22), 0.7),
        (0.13, note(E5, 0.16, BELL, 22), 0.7),
        (0.27, note(B5, 0.7, BELL, 5.5, glide_from=B5 * 0.84), 1.0),
        (0.70, note(B5, 0.16, BELL, 22), 0.4),
        (0.83, note(E6, 0.8, BELL, 5.0, glide_from=E6 * 0.84), 0.55),
    ])

def save(path, sig):
    sig = sig / np.abs(sig).max() * 0.86
    fade = int(SR * 0.04)
    sig[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((sig * 32767).astype('<i2').tobytes())

out = sys.argv[1]
for name, fn in [('fittarc_routine', signature), ('fittarc_water', water), ('fittarc_workout', workout), ('fittarc_social', social)]:
    save(f'{out}/{name}.wav', fn())
    print(name, 'ok')
