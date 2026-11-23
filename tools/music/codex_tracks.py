"""Render the six Wyrmslot loops from the repository root.

WAVs are written to the existing art/music-src/codex directory.
"""

import wave

import numpy as np


RATE = 44_100
OUTPUT = "art/music-src/codex"
RMS_TARGET = 10 ** (-19 / 20)
PEAK_LIMIT = 10 ** (-3 / 20)
SCALE = (0, 2, 3, 5, 7, 8, 10)  # A natural minor

# Diatonic root and a playable voicing for each harmony.
CHORDS = {
    "Am": (0, (57, 60, 64, 69)),
    "F": (5, (57, 60, 65, 69)),
    "C": (2, (55, 60, 64, 67)),
    "G": (6, (55, 59, 62, 67)),
    "Dm": (3, (57, 62, 65, 69)),
    "Em": (4, (55, 59, 64, 67)),
}

# Attack, decay, sustain and release in seconds / linear gain, then partials.
VOICES = {
    "harp": (0.008, 0.30, 0.19, 0.32, ((1, 1), (2, .42), (3, .25), (4, .11), (6, .05))),
    "bell": (0.005, 0.44, 0.13, 0.68, ((1, 1), (2.01, .32), (2.76, .17), (4.08, .11))),
    "flute": (0.056, 0.22, 0.71, 0.22, ((1, 1), (2, .27), (3, .12), (5, .06))),
    "pad": (0.20, 0.47, 0.75, 0.46, ((1, 1), (2, .38), (3, .16), (4, .08), (5, .07))),
    "bass": (0.021, 0.20, 0.65, 0.15, ((1, 1), (2, .49), (3, .22), (5, .07))),
    "strings": (0.035, 0.18, 0.66, 0.23, ((1, 1), (2, .57), (3, .32), (4, .17), (5, .16), (7, .10))),
    "brass": (0.068, 0.24, 0.72, 0.27, ((1, 1), (2, .71), (3, .35), (4, .23), (5, .17), (7, .09))),
}

DRUM_MIX = {
    "kick": (.27, 0, .05),
    "tom": (.238, .23, .30),
    "wood": (.096, .28, .23),
    "shaker": (.089, -.40, .16),
}


class Track:
    def __init__(self, name, bpm, harmony, lead, octave, phrases, picking, bass, drums):
        self.name = name
        self.bpm = bpm
        self.harmony = tuple(harmony.split())
        self.lead = lead
        self.octave = octave
        self.phrases = phrases
        self.picking = picking
        self.bass = bass
        self.drums = drums


# In each phrase, entries are (sixteenth-note offset, scale steps from chord
# root, gate in sixteenths). Negative intervals keep the line in its register.
TRACKS = (
    Track(
        "title", 76, "Am F C G Am Dm F Em Am F C G Dm Am F Em", "harp", 69,
        (
            ((0, 0, 5), (6, 2, 3), (10, 4, 5)),
            ((2, -3, 4), (8, -1, 3), (12, 0, 3)),
            ((0, 4, 6), (7, 2, 4), (12, 1, 3)),
            ((3, 2, 4), (9, 0, 3), (13, -2, 2)),
        ),
        (2, 7, 11, 14), (0, 9), (("shaker", (6, 14)),),
    ),
    Track(
        "prepare", 88, "F C Dm Am F C G Em F Am Dm C F Dm G Em", "harp", 69,
        (
            ((1, 0, 2), (4, 2, 2), (8, 4, 3), (12, 2, 2)),
            ((0, 2, 3), (5, 1, 2), (8, 0, 3), (13, -3, 2)),
            ((2, -3, 2), (5, 0, 2), (8, 2, 3), (14, 3, 2)),
            ((0, 4, 3), (6, 2, 2), (10, 0, 4)),
        ),
        (0, 3, 6, 9, 12, 15), (0, 8, 12), (("wood", (4, 10, 12)), ("shaker", (2, 6, 14))),
    ),
    Track(
        "battle_calm", 100, "Am C F G Am C Dm Em Am C F G F C Dm Am F Dm G Em", "flute", 69,
        (
            ((0, 0, 3), (4, 2, 3), (8, 4, 5), (14, 2, 2)),
            ((0, -3, 5), (6, -1, 2), (8, 0, 4), (13, 1, 2)),
            ((0, 2, 4), (6, 4, 2), (8, 3, 3), (12, 2, 3)),
            ((0, 0, 6), (8, -2, 3), (12, -3, 3)),
        ),
        (0, 4, 8, 12), (0, 4, 8, 12), (("kick", (0, 8)), ("wood", (4, 12)), ("shaker", (2, 6, 10, 14))),
    ),
    Track(
        "battle_rush", 138, "Am G F Em Am Dm F Em Am C F G Dm F Am Em Am G Dm F Am F G Em",
        "strings", 69,
        (
            ((0, 0, 2), (3, 0, 1), (4, 2, 3), (8, 4, 2), (11, 3, 1), (12, 2, 2)),
            ((0, -3, 3), (4, 0, 2), (7, 1, 1), (8, 2, 3), (13, 0, 2)),
            ((0, 4, 2), (2, 3, 1), (4, 2, 3), (8, 0, 2), (10, 2, 2), (12, 4, 3)),
            ((0, 2, 3), (4, 1, 2), (7, 0, 1), (8, -2, 3), (12, -3, 3)),
        ),
        (0, 2, 4, 6, 8, 10, 12, 14), (0, 3, 6, 8, 11, 14),
        (("kick", (0, 6, 8, 11)), ("tom", (4, 7, 12, 14)), ("shaker", (2, 4, 6, 8, 10, 12, 14, 15))),
    ),
    Track(
        "boss", 156, "Am Am F Em Am Dm F Em Am Am Dm F Am G F Em Dm Dm F Am Dm F G Em Am F Dm Em",
        "brass", 57,
        (
            ((0, 0, 5), (6, 0, 2), (9, 4, 5)),
            ((0, 2, 6), (7, 1, 2), (10, 0, 3), (14, -3, 2)),
            ((0, 0, 2), (3, 4, 5), (9, 3, 2), (12, 2, 4)),
            ((0, -3, 4), (5, -2, 3), (9, -1, 2), (12, 0, 3)),
        ),
        (0, 3, 7, 8, 11, 15), (0, 2, 3, 6, 8, 10, 11, 14),
        (("kick", (0, 3, 8, 10, 14)), ("tom", (4, 7, 12, 15)), ("shaker", (2, 6, 9, 12, 13, 15))),
    ),
    Track(
        "final_boss", 168,
        "Am F Dm G Am F Dm Em Am C F G Dm F Am Em Dm F C G Am F Dm Em Am G F Dm Am F G Em",
        "brass", 69,
        (
            ((0, 0, 3), (4, 4, 6), (11, 5, 2), (14, 4, 2)),
            ((0, 2, 5), (6, 1, 2), (8, 0, 4), (13, 2, 2)),
            ((0, 4, 4), (5, 7, 4), (10, 6, 2), (13, 4, 3)),
            ((0, 2, 3), (4, 1, 2), (8, 0, 3), (12, -3, 4)),
        ),
        (0, 2, 4, 6, 8, 10, 12, 14), (0, 2, 4, 6, 8, 10, 12, 14),
        (("kick", (0, 3, 6, 8, 10, 14)), ("tom", (4, 7, 12, 13, 15)),
         ("shaker", (1, 3, 5, 7, 9, 11, 13, 15))),
    ),
)


def scale_note(tonic, degree):
    octave, step = divmod(degree, len(SCALE))
    return tonic + 12 * octave + SCALE[step]


def synth_note(voice, midi, gate, rng):
    attack, decay, sustain, release, partials = VOICES[voice]
    time = np.arange(gate + round(release * RATE)) / RATE
    key_up = gate / RATE
    level = np.clip(time / attack, 0, 1)
    level *= 1 - (1 - sustain) * np.clip((time - attack) / decay, 0, 1)
    held_level = np.interp(key_up, time, level)
    tail = time >= key_up
    level[tail] = held_level * np.maximum(0, 1 - (time[tail] - key_up) / release) ** 2

    frequency = 440 * 2 ** ((midi - 69) / 12)
    phase = 2 * np.pi * frequency * time
    if voice in ("flute", "pad", "strings", "brass"):
        phase += 0.12 * np.sin(2 * np.pi * 4.7 * time) * np.minimum(1, time / .23)
    tone = np.zeros_like(time)
    for harmonic, weight in partials:
        # Overtones of struck and plucked instruments fade faster than the fundamental.
        shimmer = np.exp(-time * (harmonic - 1) * 1.8) if voice in ("harp", "bell") else 1
        tone += weight * shimmer * np.sin(harmonic * phase + rng.uniform(-.45, .45))
    return tone * level / sum(weight for _, weight in partials)


def synth_drum(kind, rng):
    duration = {"kick": .30, "tom": .25, "wood": .11, "shaker": .14}[kind]
    time = np.arange(round(duration * RATE)) / RATE
    if kind == "kick":
        phase = 2 * np.pi * (45 * time + 92 * .022 * -np.expm1(-time / .022))
        tone = (np.sin(phase) + .19 * np.sin(2 * phase)) * np.exp(-time / .065)
    elif kind == "tom":
        phase = 2 * np.pi * (86 * time + 56 * .039 * -np.expm1(-time / .039))
        noise = rng.uniform(-1, 1, time.size)
        tone = (np.sin(phase) + .30 * np.sin(1.54 * phase)) * np.exp(-time / .053)
        tone += .21 * noise * np.exp(-time / .018)
    elif kind == "wood":
        phase = 2 * np.pi * rng.uniform(750, 820) * time
        tone = (.7 * np.sin(phase) + .26 * np.sin(1.63 * phase)) * np.exp(-time / .021)
    else:
        white = rng.uniform(-1, 1, time.size)
        bright = np.diff(white, prepend=white[0]) * .62
        tone = bright * (1 - np.exp(-time / .008)) * np.exp(-time / .031)
    return tone * np.minimum(time / .004, 1) * np.minimum((duration - time) / .024, 1)


class Loop:
    def __init__(self, track, seed):
        self.samples_per_step = RATE * 60 / (4 * track.bpm)
        self.rng = np.random.default_rng(seed)
        self.mix = np.zeros((self.frame(16 * len(track.harmony)), 2))
        self.room = np.zeros_like(self.mix)

    def frame(self, step):
        return round(step * self.samples_per_step)

    def add(self, step, sound, volume, pan, send):
        angle = (pan + 1) * np.pi / 4
        stereo = sound[:, None] * volume * np.array((np.cos(angle), np.sin(angle)))
        start = self.frame(step)
        # The next phrase starts before the previous note's release has ended.
        head = min(len(sound), len(self.mix) - start)
        self.mix[start:start + head] += stereo[:head]
        self.mix[:len(sound) - head] += stereo[head:]
        self.room[start:start + head] += send * stereo[:head]
        self.room[:len(sound) - head] += send * stereo[head:]

    def note(self, step, length, voice, midi, volume, pan=0, send=.2):
        gate = self.frame(step + length) - self.frame(step)
        tone = synth_note(voice, midi, gate, self.rng)
        self.add(step, tone, volume * self.rng.uniform(.91, 1.06), pan, send)

    def finish(self):
        # Circular taps carry reflections over the bar line, including at the loop seam.
        for index, (seconds, gain) in enumerate(((.037, .24), (.061, .21), (.109, .17),
                                                 (.167, .13), (.241, .09), (.347, .06))):
            reflected = self.room[:, ::-1] if index % 2 == 0 else self.room
            self.mix += gain * np.roll(reflected, round(seconds * RATE), axis=0)
        self.mix -= self.mix.mean(axis=0)
        self.mix *= RMS_TARGET / rms(self.mix)
        # Soften transients before matching loudness. Keep headroom after rounding to PCM.
        self.mix = .64 * np.tanh(self.mix / .64)
        self.mix -= self.mix.mean(axis=0)
        self.mix *= min(RMS_TARGET / rms(self.mix), (PEAK_LIMIT - 1 / 32767) / np.abs(self.mix).max())
        return np.rint(32767 * self.mix).astype("<i2")


def render(track, intensity):
    loop = Loop(track, 20261123 + intensity)
    for bar, chord in enumerate(track.harmony):
        start = bar * 16
        root, voicing = CHORDS[chord]
        lead_root = (root + 2) % 7 - 2
        bass_root = (root + 3) % 7 - 3
        phrase_index = (bar + bar // 8) % 4
        phrase = track.phrases[phrase_index]
        for step, interval, length in phrase:
            midi = scale_note(track.octave, lead_root + interval)
            emphasis = 1 if step % 4 == 0 else .83
            loop.note(start + step, length, track.lead, midi, .25 * emphasis, -.12, .40)
            if intensity == 0 and step == phrase[0][0]:
                loop.note(start + step, min(length, 4), "bell", midi + 12, .088, .43, .63)
            if intensity == 5 and (step == 0 or bar % 4 == 2):
                loop.note(start + step, length, "strings", midi - 12, .135, .31, .29)

        for index, midi in enumerate(voicing):
            loop.note(start, 15.25, "pad", midi, .068, (-.72, .49, -.41, .74)[index], .30)
        for index, step in enumerate(track.picking):
            midi = voicing[(0, 2, 1, 3, 2, 1, 0, 3)[index]]
            voice = "harp" if intensity < 3 else "strings"
            loop.note(start + step, 1.5, voice, midi, .091, -.48 if index % 2 == 0 else .53, .32)

        next_bass_steps = track.bass[1:] + (16,)
        for index, (step, next_step) in enumerate(zip(track.bass, next_bass_steps)):
            interval = 4 if index % 4 == 2 else 0
            midi = scale_note(45, bass_root + interval)
            length = min(5.5, next_step - step - .3)
            gain = .16 + .018 * intensity
            loop.note(start + step, length, "bass", midi, gain, 0, .07)
            if intensity >= 4 and step in (0, 8):
                loop.note(start + step, length, "bass", midi - 12, .11, 0, .03)

        for kind, steps in track.drums:
            volume, pan, send = DRUM_MIX[kind]
            for step in steps:
                accent = 1 if step % 4 == 0 else .68
                loop.add(start + step, synth_drum(kind, loop.rng),
                         volume * accent * loop.rng.uniform(.87, 1.09), pan, send)
        if intensity >= 3 and bar % 4 == 3:
            for step, pan in ((13, -.35), (15.5, .40)):
                loop.add(start + step, synth_drum("tom", loop.rng), .19, pan, .32)
    return loop.finish()


def rms(samples):
    return np.sqrt(np.mean(np.square(samples, dtype=np.float64)))


def main():
    levels = []
    for intensity, track in enumerate(TRACKS):
        samples = render(track, intensity)
        length = len(samples) / RATE
        peak = np.abs(samples.astype(np.int32)).max() / 32768
        level = rms(samples) / 32768
        if not 40 <= length <= 64 or peak > PEAK_LIMIT:
            raise ValueError(f"{track.name}: length or peak outside the required range")
        filename = f"{OUTPUT}/{track.name}.wav"
        with wave.open(filename, "wb") as wav:
            wav.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
            wav.writeframes(samples.tobytes())
        level_db = 20 * np.log10(level)
        levels.append(level_db)
        print(f"{track.name:12} {length:6.2f} s  peak {20 * np.log10(peak):6.2f} dBFS  RMS {level_db:6.2f} dBFS")
    if max(levels) - min(levels) > 3:
        raise ValueError("Track RMS levels differ by more than 3 dB")


if __name__ == "__main__":
    main()
