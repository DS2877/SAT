"""Synthesises the two carry stings as WAV files (pure standard library, no samples, so there
is nothing to license):

  success.wav - a short brass-style fanfare (rising major arpeggio into a held chord)
  fail.wav    - the classic "wah wah wah wahhh" descending trombone

Usage: python3 tools/music/stings.py <output-dir>
"""

import math
import struct
import sys
import wave

RATE = 44100


def brass(freq, t, vibrato=0.0):
    """Bright brass-like tone: a few decaying harmonics, optional vibrato."""
    f = freq * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
    out = 0.0
    for n, amp in ((1, 1.0), (2, 0.55), (3, 0.4), (4, 0.22), (5, 0.12), (6, 0.06)):
        out += amp * math.sin(2 * math.pi * f * n * t)
    return out / 2.4


def envelope(t, length, attack=0.02, release=0.12):
    if t < attack:
        return t / attack
    if t > length - release:
        return max(0.0, (length - t) / release)
    return 1.0


def render(notes, total):
    """notes: (start, length, [freqs], vibrato, gain)"""
    samples = [0.0] * int(total * RATE)
    for start, length, freqs, vibrato, gain in notes:
        first = int(start * RATE)
        for i in range(int(length * RATE)):
            idx = first + i
            if idx >= len(samples):
                break
            t = i / RATE
            v = sum(brass(f, t, vibrato) for f in freqs) / len(freqs)
            samples[idx] += v * envelope(t, length) * gain
    peak = max(abs(s) for s in samples) or 1
    return [s / peak * 0.85 for s in samples]


def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12 - 9) / 12)


def success():
    n = note
    return render(
        [
            (0.00, 0.14, [n("G4")], 0, 0.8),
            (0.14, 0.14, [n("C5")], 0, 0.85),
            (0.28, 0.14, [n("E5")], 0, 0.9),
            (0.42, 0.22, [n("G5")], 0, 1.0),
            (0.66, 0.12, [n("E5")], 0, 0.85),
            (0.80, 1.10, [n("C5"), n("E5"), n("G5"), n("C6")], 0.006, 1.0),
        ],
        2.0,
    )


def fail():
    n = note
    return render(
        [
            (0.00, 0.42, [n("G3")], 0.004, 0.9),
            (0.48, 0.42, [n("F#3")], 0.004, 0.9),
            (0.96, 0.42, [n("F3")], 0.004, 0.9),
            (1.44, 1.30, [n("E3")], 0.03, 1.0),  # the long wobbling "wahhh"
        ],
        2.9,
    )


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    write(f"{out}/success.wav", success())
    write(f"{out}/fail.wav", fail())
    print("stings written to", out)
