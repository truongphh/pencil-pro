"""Synthesizes pencil-pro's placeholder audio: a gentle background music loop and the
two UI sounds (colour pick, picture saved). Pure numpy, no samples, no licences.

Usage:  python3 tools/audio/generate_sounds.py [out_dir]   (default: assets/audio)
Writes 16-bit mono 44.1 kHz WAV files. Implements: design/game-brief.md audio direction.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100


def midi_hz(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n: int, attack: float, decay: float) -> np.ndarray:
    """Fast attack, exponential decay envelope over n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def music_box(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Soft bell / music-box tone: sine plus a few quiet inharmonic partials."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = (np.sin(2 * np.pi * freq * t)
            + 0.30 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / 0.25)
            + 0.12 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t / 0.12))
    return amp * tone * env(n, 0.004, dur / 3.5)


def pad(freq: float, dur: float, amp: float) -> np.ndarray:
    """Warm sustained tone for the bass / chords, slow fade in and out."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    shape = np.minimum(np.clip(t / 0.15, 0, 1), np.clip((dur - t) / 0.3, 0, 1))
    return amp * tone * shape


def add_wrapped(buf: np.ndarray, sig: np.ndarray, start: int) -> None:
    """Mixes sig into buf at start; anything past the end wraps to the beginning so the
    loop is seamless."""
    idx = (start + np.arange(len(sig))) % len(buf)
    np.add.at(buf, idx, sig)


def make_music() -> np.ndarray:
    bpm = 92
    beat = 60 / bpm
    bars = 8
    total = int(bars * 4 * beat * SR)
    buf = np.zeros(total)
    # I - vi - IV - V in C major, twice.
    chords = [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]] * 2
    for bar, chord in enumerate(chords):
        t0 = bar * 4 * beat
        add_wrapped(buf, pad(midi_hz(chord[0] - 12), 4 * beat, 0.10), int(t0 * SR))
        for i, note in enumerate(chord):  # soft broken chord on beats 1-3
            add_wrapped(buf, music_box(midi_hz(note + 12), 1.6, 0.10), int((t0 + i * beat) * SR))
    # Pentatonic melody: (beat offset, midi note, length in beats); 32 beats total.
    melody = [
        (0, 72, 1), (1, 76, 1), (2, 79, 1.5), (3.5, 76, 0.5),
        (4, 81, 1), (5, 79, 1), (6, 76, 2),
        (8, 77, 1), (9, 76, 1), (10, 74, 1), (11, 72, 1),
        (12, 74, 1.5), (13.5, 76, 0.5), (14, 79, 2),
        (16, 72, 1), (17, 76, 1), (18, 79, 1), (19, 84, 1),
        (20, 81, 1.5), (21.5, 79, 0.5), (22, 76, 2),
        (24, 77, 1), (25, 81, 1), (26, 79, 1), (27, 76, 1),
        (28, 74, 1), (29, 79, 1), (30, 72, 2),
    ]
    for off, note, length in melody:
        add_wrapped(buf, music_box(midi_hz(note), max(1.2, length * beat * 1.8), 0.22),
                    int(off * beat * SR))
    return buf


def make_color_pick() -> np.ndarray:
    """Bubble 'blip': a quick upward pitch glide, ~0.15 s."""
    dur = 0.15
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 520 + 900 * (1 - np.exp(-t / 0.03))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * env(n, 0.003, 0.045)


def make_saved() -> np.ndarray:
    """Happy chime: rising C-major arpeggio of bell tones, ~1 s."""
    buf = np.zeros(int(1.1 * SR))
    for i, note in enumerate([72, 76, 79, 84]):
        sig = music_box(midi_hz(note), 0.8, 0.6 if i < 3 else 0.8)
        start = int(i * 0.09 * SR)
        buf[start:start + len(sig)] += sig[: len(buf) - start]
    return buf


def write_wav(path: Path, sig: np.ndarray, peak_db: float) -> None:
    sig = sig / np.max(np.abs(sig)) * 10 ** (peak_db / 20)
    data = (sig * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{path}  {len(sig) / SR:.2f}s")


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio")
    out.mkdir(parents=True, exist_ok=True)
    write_wav(out / "music_loop.wav", make_music(), -3.0)
    write_wav(out / "color_pick.wav", make_color_pick(), -6.0)
    write_wav(out / "saved.wav", make_saved(), -6.0)


if __name__ == "__main__":
    main()
