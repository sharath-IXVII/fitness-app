#!/usr/bin/env python3
"""Writes Fittarc's three notification sounds (android/app/src/main/res/raw).

All three share one idea, the "arc": a few soft bell notes that climb. Bell
tones are built from sine partials that fade at different speeds, with a
little echo, then lifted and rounded off so they are clearly audible without
being harsh.

    python3 tools/gen_notification_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 32000
OUT = Path(__file__).resolve().parent.parent / "android/app/src/main/res/raw"

# A bell: (frequency ratio, loudness, how fast it dies away)
BELL = [(1.0, 1.0, 3.2), (2.0, 0.42, 4.5), (2.76, 0.22, 6.5), (4.07, 0.12, 9.0), (5.4, 0.06, 12.0)]


def note(freq, length, bend=0.0, brightness=1.0):
    n = int(RATE * length)
    out = [0.0] * n
    for ratio, amp, decay in BELL:
        a = amp * (brightness if ratio > 1.5 else 1.0)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            # a tiny downward pitch bend at the start gives a "plink"
            f = freq * ratio * (1 + bend * math.exp(-t * 40))
            phase += 2 * math.pi * f / RATE
            out[i] += a * math.sin(phase) * math.exp(-t * decay)
    # soft 4 ms attack so there is no click
    for i in range(min(n, int(RATE * 0.004))):
        out[i] *= i / (RATE * 0.004)
    return out


def mix(parts, total):
    buf = [0.0] * int(RATE * total)
    for start, samples, gain in parts:
        s = int(RATE * start)
        for i, v in enumerate(samples):
            if s + i < len(buf):
                buf[s + i] += v * gain
    return buf


def thump(length=0.18, f0=95.0, f1=48.0):
    n = int(RATE * length)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t * 28)
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase) * math.exp(-t * 18))
    return out


def echo(buf, delay=0.085, gain=0.28, taps=3):
    out = buf[:] + [0.0] * int(RATE * delay * taps)
    for k in range(1, taps + 1):
        d = int(RATE * delay * k)
        for i, v in enumerate(buf):
            out[i + d] += v * (gain**k)
    return out


def finish(buf, fade=0.06):
    # lift quiet parts and round off peaks, then set the level just under full
    buf = [math.tanh(1.25 * v) for v in buf]
    peak = max(abs(v) for v in buf) or 1
    buf = [v / peak * 0.8 for v in buf]
    n = int(RATE * fade)
    for i in range(n):
        buf[len(buf) - 1 - i] *= i / n
    return buf


def save(name, buf):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))


E5, A5, CS6, E6, G5, D6, A4 = 659.25, 880.0, 1108.73, 1318.51, 783.99, 1174.66, 440.0
D5, FS5, B5 = 587.33, 739.99, 987.77

# Routine and My Day: a four-note climb that settles on a long ring.
save("fittarc_routine", finish(echo(mix([
    (0.00, note(E5, 0.5), 0.80),
    (0.12, note(A5, 0.5), 0.85),
    (0.24, note(CS6, 0.6), 0.90),
    (0.38, note(E6, 1.1), 1.00),
], 1.5))))

# Water: two soft drops, the second higher, like a drip into a glass.
save("fittarc_water", finish(echo(mix([
    (0.00, note(G5, 0.45, bend=0.06, brightness=0.7), 0.85),
    (0.20, note(D6, 0.8, bend=0.05, brightness=0.7), 1.00),
], 1.1), delay=0.11, gain=0.22)))

# Workout: a low thump, then a quick three-note climb. A call to move.
save("fittarc_workout", finish(echo(mix([
    (0.00, thump(), 1.10),
    (0.05, note(D5, 0.4), 0.80),
    (0.15, note(FS5, 0.4), 0.88),
    (0.25, note(A5, 0.5), 0.95),
    (0.37, note(D6 * 1.0, 1.0), 1.00),
], 1.4))))

print("wrote", sorted(p.name for p in OUT.glob("fittarc_*.wav")))
