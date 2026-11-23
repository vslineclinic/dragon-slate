"""배경음악 6곡을 코드로 합성한다(numpy만 사용, 외부 음원 없음).
사용: python tools/music/make_tracks.py  ->  art/music-src/claude/<이름>.wav
같은 조성(라단조/바장조)이라 곡을 바꿔 틀어도 어색하지 않고, 원형 버퍼에 그려서 끝과 처음이 이어진다."""
import os
import wave
import numpy as np

SR = 44100
OUT = "art/music-src/claude"
# 라 자연단음계(D E F G A Bb C)와 화음
SCALE = [2, 4, 5, 7, 9, 10, 12]
CHORDS = {
    "Dm": [2, 5, 9], "Bb": [10, 14, 17], "F": [5, 9, 12], "C": [0, 4, 7],
    "Gm": [7, 10, 14], "Am": [9, 12, 16], "A": [9, 13, 16],
}


def hz(semitone, octave=4):
    return 261.6256 * 2 ** ((semitone + 12 * (octave - 4)) / 12)


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, min(n // 2, int(attack * SR)))
    r = max(1, min(n - a, int(release * SR)))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def tone(freq, dur, harmonics, decay=0.0, attack=0.005, release=0.05, vibrato=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    phase = 2 * np.pi * freq * t
    if vibrato:
        phase += vibrato * np.sin(2 * np.pi * 5.2 * t)
    out = np.zeros(n)
    for k, amp in harmonics:
        if freq * k < SR * 0.45:
            out += amp * np.sin(phase * k) * (np.exp(-t * decay * (0.6 + 0.4 * k)) if decay else 1.0)
    return out * env(n, attack, release)


SAW = [(k, 1 / k ** 1.3) for k in range(1, 11)]
SQUARE = [(k, 1 / k ** 1.2) for k in range(1, 10, 2)]
SOFT = [(1, 1.0), (2, 0.35), (3, 0.15)]
BELL = [(1, 1.0), (2.76, 0.45), (5.4, 0.25), (8.9, 0.1)]


def harp(f, d):
    return tone(f, max(d, 0.9), [(k, 1 / k) for k in range(1, 7)], decay=3.2, release=0.2)


def bell(f, d):
    return tone(f, max(d, 1.6), BELL, decay=2.2, release=0.4)


def pad(f, d):
    return sum(tone(f * r, d, SAW, attack=0.25, release=0.35) for r in (0.996, 1.0, 1.005)) / 3


def lead(f, d):
    return tone(f, d, SQUARE, attack=0.012, release=0.06, vibrato=0.25)


def brass(f, d):
    return tone(f, d, SAW, attack=0.02, release=0.08)


def bass(f, d):
    return tone(f, d, [(1, 1.0), (2, 0.5), (3, 0.22), (4, 0.1)], decay=1.5, attack=0.004, release=0.04)


def kick(power=1.0):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 45 + 95 * np.exp(-t * 30)
    return power * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)


def tom(pitch=110.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = pitch * (0.75 + 0.6 * np.exp(-t * 18))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def snare(rng):
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    return 0.7 * rng.standard_normal(n) * np.exp(-t * 24) + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 32)


def hat(rng, length=0.05):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = np.diff(rng.standard_normal(n + 1))
    return 0.5 * noise * np.exp(-t * (3.0 / length))


class Song:
    def __init__(self, bpm, bars, seed):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.n = int(round(bars * 4 * self.beat * SR))
        self.dry = np.zeros((self.n, 2))
        self.wet = np.zeros((self.n, 2))
        self.rng = np.random.default_rng(seed)

    def add(self, when_beats, sig, gain=1.0, pan=0.0, wet=0.2):
        """원형으로 섞는다: 끝을 넘는 꼬리는 처음으로 접힌다."""
        start = int(round(when_beats * self.beat * SR)) % self.n
        idx = (start + np.arange(len(sig))) % self.n
        left, right = gain * (1 - max(0, pan)), gain * (1 + min(0, pan))
        np.add.at(self.dry[:, 0], idx, sig * left * (1 - wet))
        np.add.at(self.dry[:, 1], idx, sig * right * (1 - wet))
        np.add.at(self.wet[:, 0], idx, sig * left * wet)
        np.add.at(self.wet[:, 1], idx, sig * right * wet)

    def render(self, reverb_seconds=1.4):
        # 원형 합성곱 잔향: 반복 지점에서도 여운이 이어진다.
        m = int(reverb_seconds * SR)
        t = np.arange(m) / SR
        out = self.dry.copy()
        for ch in range(2):
            ir = np.zeros(self.n)
            ir[:m] = self.rng.standard_normal(m) * np.exp(-t * (5.0 / reverb_seconds))
            ir /= np.sqrt(np.sum(ir ** 2))
            out[:, ch] += 0.9 * np.fft.irfft(np.fft.rfft(self.wet[:, ch]) * np.fft.rfft(ir), self.n)
        rms = np.sqrt(np.mean(out ** 2))
        out = np.tanh(out * (0.17 / rms) * 1.4) / 1.4
        return np.clip(out, -0.7, 0.7)


def melody(song, chords, rhythm, octave, seed, form):
    """화음음을 강박에, 음계음을 약박에 두는 선율. form(예: AABA)으로 악구를 되풀이한다."""
    phrases = {}
    notes = []
    for bar, chord in enumerate(chords):
        key = form[(bar // 2) % len(form)]
        rng = np.random.default_rng(seed + ord(key) * 97 + (bar % 2))
        steps = phrases.setdefault((key, bar % 2), [int(rng.integers(-2, 3)) for _ in rhythm])
        tones = CHORDS[chord]
        position = 0.0
        degree = 4
        for i, length in enumerate(rhythm):
            if length < 0:
                position += -length
                continue
            if position % 1.0 == 0:
                pitch = tones[(i + steps[i]) % 3] + (12 if steps[i] > 1 else 0)
            else:
                degree = (degree + steps[i]) % 7
                pitch = SCALE[degree]
            notes.append((bar * 4 + position, length, pitch))
            position += length
    return [(when, length, hz(pitch, octave)) for when, length, pitch in notes]


def build(name, bpm, bars, progression, seed, style):
    song = Song(bpm, bars, seed)
    chords = [progression[i % len(progression)] for i in range(bars)]
    rng = song.rng
    for bar, chord in enumerate(chords):
        b = bar * 4
        root, third, fifth = CHORDS[chord]
        last_bar = bar % 8 == 7
        if style == "title":
            song.add(b, pad(hz(root, 3), 4 * song.beat) + pad(hz(fifth, 3), 4 * song.beat), 0.16, wet=0.5)
            for i, p in enumerate([root, fifth, third + 12, fifth, root + 12, fifth, third + 12, fifth]):
                song.add(b + i * 0.5, harp(hz(p, 4), 0.9), 0.3, pan=-0.3 + 0.08 * i, wet=0.45)
            song.add(b, bass(hz(root, 2), 3.5 * song.beat), 0.3, wet=0.1)
        elif style == "prepare":
            for i, p in enumerate([root, third, fifth, third, root + 12, fifth, third, fifth]):
                song.add(b + i * 0.5, harp(hz(p, 4), 0.5), 0.3, pan=0.25 if i % 2 else -0.25, wet=0.3)
            song.add(b, pad(hz(third, 4), 4 * song.beat), 0.08, wet=0.5)
            for beat in (0, 2.5):
                song.add(b + beat, bass(hz(root, 2), 1.2 * song.beat), 0.34, wet=0.05)
            song.add(b, kick(0.6), 0.5, wet=0.05)
            for i in range(4):
                song.add(b + i + 0.5, hat(rng), 0.12, pan=0.3, wet=0.1)
        elif style == "calm":
            for beat in range(4):
                song.add(b + beat, brass(hz(root, 3), 0.3 * song.beat) + brass(hz(fifth, 3), 0.3 * song.beat), 0.12, pan=-0.2, wet=0.3)
                song.add(b + beat, bass(hz(root if beat % 2 == 0 else fifth, 2), 0.8 * song.beat), 0.36, wet=0.05)
            song.add(b, kick(), 0.6, wet=0.05)
            song.add(b + 2, kick(0.8), 0.6, wet=0.05)
            for beat in (1, 3):
                song.add(b + beat, snare(rng), 0.2, wet=0.2)
            for i in range(8):
                song.add(b + i * 0.5, hat(rng), 0.08, pan=0.3, wet=0.1)
            if last_bar:
                for i in range(4):
                    song.add(b + 3 + i * 0.25, tom(140 - 12 * i), 0.3, pan=-0.3 + 0.2 * i, wet=0.25)
        else:
            heavy = style in ("boss", "final")
            eighths = [root, root, root + 12, root, fifth, root, root + 12, fifth] if not heavy else [root, root, root, third, root, root, fifth, third]
            for i, p in enumerate(eighths):
                song.add(b + i * 0.5, bass(hz(p, 2 if not heavy else 1), 0.45 * song.beat), 0.4, wet=0.03)
                if heavy:
                    song.add(b + i * 0.5, brass(hz(p, 2), 0.3 * song.beat), 0.09, wet=0.15)
            for beat in range(4):
                song.add(b + beat, kick(), 0.62, wet=0.04)
                if style == "final" and bar % 4 >= 2:
                    song.add(b + beat + 0.5, kick(0.7), 0.5, wet=0.04)
            for beat in (1, 3):
                song.add(b + beat, snare(rng), 0.26, wet=0.2)
            for i in range(16):
                song.add(b + i * 0.25, hat(rng, 0.035), 0.07 if i % 2 else 0.1, pan=0.35, wet=0.08)
            stab_beats = (0, 1.5, 3) if heavy else (0, 2.5)
            for beat in stab_beats:
                for p in (root, third, fifth):
                    song.add(b + beat, brass(hz(p, 3 if heavy else 4), 0.4 * song.beat), 0.09, pan=0.2, wet=0.3)
            if style == "final":
                song.add(b, pad(hz(root, 4), 4 * song.beat) + pad(hz(fifth, 4), 4 * song.beat) + pad(hz(third, 5), 4 * song.beat), 0.07, wet=0.6)
            if last_bar:
                for i in range(8):
                    song.add(b + 2 + i * 0.25, tom(170 - 10 * i if heavy else 150 - 8 * i), 0.34, pan=-0.4 + 0.1 * i, wet=0.25)

    tunes = {
        "title": ([2, 2, -1, 1, 1, 1], 5, bell, 0.22, "AABA", 0.5),
        "prepare": ([1, 0.5, 0.5, 1, -1, 1, 0.5, 0.5, 1, 1], 5, harp, 0.3, "AABA", 0.35),
        "calm": ([1, 0.5, 0.5, 1, 1, 1.5, 0.5, 1, -1], 5, lead, 0.13, "AABA", 0.3),
        "rush": ([0.5, 0.5, 0.5, 0.5, 1, 1, 0.5, 0.5, 1, 0.5, 0.5, 1], 5, lead, 0.14, "AABC", 0.25),
        "boss": ([1, 0.5, 0.5, 0.5, 0.5, 1, 1.5, 0.5, 1, 1], 4, lead, 0.16, "AABC", 0.3),
        "final": ([0.5, 0.5, 1, 0.5, 0.5, 1, 1, 0.5, 0.5, 0.5, 0.5, 1], 5, lead, 0.15, "ABAC", 0.35),
    }
    rhythm, octave, voice, gain, form, wet = tunes[style]
    for when, length, freq in melody(song, chords, rhythm, octave, seed * 7, form):
        song.add(when, voice(freq, length * song.beat * 0.95), gain, pan=0.1, wet=wet)
        if style == "final":
            song.add(when, voice(freq / 2, length * song.beat * 0.95), gain * 0.6, pan=-0.15, wet=wet)
    return song.render()


TRACKS = [
    ("title", 76, 16, ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"], 11, "title"),
    ("prepare", 88, 16, ["F", "C", "Dm", "Bb", "F", "C", "Gm", "C"], 23, "prepare"),
    ("battle_calm", 100, 24, ["Dm", "F", "C", "Dm", "Bb", "F", "Gm", "A"], 37, "calm"),
    ("battle_rush", 138, 32, ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"], 41, "rush"),
    ("boss", 156, 32, ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Gm", "A"], 53, "boss"),
    ("final_boss", 168, 40, ["Dm", "C", "Bb", "A", "Dm", "C", "Gm", "A"], 67, "final"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, bpm, bars, progression, seed, style in TRACKS:
        audio = build(name, bpm, bars, progression, seed, style)
        with wave.open(f"{OUT}/{name}.wav", "wb") as f:
            f.setnchannels(2)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes((audio * 32767).astype("<i2").tobytes())
        rms = float(np.sqrt(np.mean(audio ** 2)))
        print(f"{name}: {len(audio) / SR:.1f}s peak {np.max(np.abs(audio)):.2f} rms {20 * np.log10(rms):.1f}dB")


if __name__ == "__main__":
    main()
