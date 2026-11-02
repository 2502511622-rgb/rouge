#!/usr/bin/env python3
"""Compose six original loops and character skill cues; no sampled recordings."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/characters'
RATE = 32000
PROFILES = [
    ('gugu', 128, 50, 'cold electronic breakbeat'),
    ('dog', 116, 38, 'industrial drums and metallic bass'),
    ('cat', 96, 57, 'offbeat plucked oddities'),
    ('naiwa', 132, 33, 'syncopated distorted bass'),
    ('niulai', 88, 36, 'heavy drums and mournful strings'),
    ('kangaroo', 124, 43, 'street electronic funk'),
]


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def tone(freq, duration, style, rng):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * freq * t
    if style == 0:
        signal = np.sin(phase + 1.4 * np.sin(2 * phase)) * np.exp(-t * 5)
    elif style == 1:
        signal = np.tanh(2.4 * (np.sin(phase) + .3 * np.sin(phase * 1.43))) * np.exp(-t * 9)
    elif style == 2:
        signal = sum(np.sin(phase * n) / n ** 1.7 for n in range(1, 6)) * np.exp(-t * 13)
    elif style == 3:
        signal = np.tanh(3 * np.sin(phase + 2 * np.sin(t * 21))) * np.exp(-t * 8)
    elif style == 4:
        signal = sum(np.sin(phase * n + .06 * np.sin(t * 5)) / n ** 1.4 for n in range(1, 6))
        signal *= np.minimum(t / .08, 1) * np.exp(-t * 2.3)
    else:
        signal = (np.sin(phase) + .5 * np.sin(phase * 2)) * np.exp(-t * 12)
    return signal * np.minimum(t / .004, 1) * np.minimum((duration - t) / .025, 1)


def compose(kind, bpm, root):
    rng = np.random.default_rng(20261102 + kind)
    beat = 60 / bpm
    size = round(beat * 64 * RATE)  # sixteen bars, exact loop boundary
    stereo = np.zeros((size, 2))

    def add(signal, seconds, gain, pan=0):
        start = round(seconds * RATE)
        indices = (start + np.arange(len(signal))) % size
        stereo[indices, 0] += signal * gain * np.sqrt((1 - pan) / 2)
        stereo[indices, 1] += signal * gain * np.sqrt((1 + pan) / 2)

    for bar in range(16):
        chord = [0, -3, -5, -2][bar // 4]
        for step in range(16):
            position = (bar * 4 + step / 4) * beat
            if step in ([0, 6, 10] if kind in [0, 3] else [0, 8, 14]):
                t = np.arange(round(.24 * RATE)) / RATE
                kick = np.sin(2 * np.pi * (48 * t + 2.1 * (1 - np.exp(-t * 34)))) * np.exp(-t * 22)
                add(kick, position, .38)
            if step in [4, 12]:
                t = np.arange(round(.16 * RATE)) / RATE
                snare = rng.normal(0, .5, len(t)) * np.exp(-t * 32)
                add(snare, position, .18, .12)
            if step % (4 if kind == 4 else 2) == 0:
                t = np.arange(round(.045 * RATE)) / RATE
                noise = rng.normal(0, .4, len(t))
                hat = (noise - np.roll(noise, 1)) * np.exp(-t * 90)
                add(hat, position, .06, (-1 if step % 4 else 1) * .45)
            if step in ([0, 3, 6, 10, 14] if kind in [3, 5] else [0, 4, 8, 11]):
                pitch = root + chord + ([0, 0, 7, 10][step % 4])
                add(tone(note(pitch), beat * .7, kind, rng), position, .19)
            if step in ([2, 7, 10, 15] if kind == 2 else [2, 6, 10, 14]):
                pitch = root + 24 + chord + [0, 7, 10, 14, 12, 7, 3, 10][(bar + step // 2) % 8]
                add(tone(note(pitch), beat * (1.7 if kind == 4 else .65), kind, rng), position, .075, .35)
        if kind in [0, 4]:
            for interval in [0, 7, 10]:
                add(tone(note(root + 12 + chord + interval), beat * 4, 4, rng), bar * 4 * beat, .035, -.25)
    # Wrapped tails make the loop continuous. Leave ample mix headroom.
    stereo = np.tanh(stereo)
    stereo *= .68 / max(np.max(np.abs(stereo)), .001)
    return stereo


def cue(kind, event):
    rng = np.random.default_rng(7100 + kind * 10 + event)
    duration = [.38, .42, .52, .72, 1.15][event]
    t = np.arange(round(duration * RATE)) / RATE
    base = [390, 180, 1200, 115, 52, 220][kind]
    pitched = tone(base * [1, 1.4, .75, 1.8, .6][event], duration, kind, rng)
    noise = rng.normal(0, 1, len(t))
    smooth = np.convolve(noise, np.ones(17) / 17, mode='same')
    envelope = np.sin(np.pi * t / duration) ** 1.3
    signal = .55 * pitched + .35 * smooth * envelope
    if event == 4:
        signal += .3 * np.sin(2 * np.pi * 48 * t) * np.exp(-t * 5)
    signal *= np.minimum(t / .004, 1) * np.minimum((duration - t) / .03, 1)
    signal *= .72 / max(np.max(np.abs(signal)), .001)
    return np.column_stack([signal, signal])


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    report = {'type': 'original procedural composition and sound design',
              'sample_rate': RATE, 'recorded_meme_voices': False, 'files': {}}
    with tempfile.TemporaryDirectory() as temp:
        for kind, (name, bpm, root, style) in enumerate(PROFILES):
            sounds = [('bgm', compose(kind, bpm, root))]
            sounds += [(event, cue(kind, i)) for i, event in enumerate(['skill0', 'skill1', 'skill2', 'v', 'ca'])]
            for event, pcm in sounds:
                source = Path(temp) / 'audio.wav'
                with wave.open(str(source), 'wb') as output:
                    output.setnchannels(2)
                    output.setsampwidth(2)
                    output.setframerate(RATE)
                    output.writeframes(np.round(np.clip(pcm, -1, 1) * 32767).astype('<i2').tobytes())
                target = ROOT / f'{name}_{event}.ogg'
                subprocess.run(['ffmpeg', '-nostdin', '-y', '-v', 'error', '-i', str(source),
                                '-c:a', 'libvorbis', '-q:a', '5', '-metadata',
                                'comment=Original procedural audio; no sampled meme voices', str(target)], check=True)
                report['files'][target.name] = {'character': name, 'event': event, 'style': style,
                    'bpm': bpm, 'duration': len(pcm) / RATE,
                    'peak': float(np.max(np.abs(pcm))),
                    'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
    (ROOT / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Generated six original BGM loops and thirty character skill cues')


if __name__ == '__main__':
    main()
