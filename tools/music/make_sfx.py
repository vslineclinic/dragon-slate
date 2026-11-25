"""효과음을 코드로 합성한다(numpy만 사용, 외부 음원 없음).
사용: python tools/music/make_sfx.py  ->  assets/sfx/<이름>.wav (16비트 모노 44.1kHz)
배경음악과 같은 라단조 음을 써서 섞여도 어색하지 않게 한다. 난수 씨앗을 고정해 다시 만들어도 같은 소리가 난다."""
import os
import wave
import numpy as np

SR = 44100
OUT = "assets/sfx"
RNG = np.random.default_rng(7)


def hz(semitone, octave=4):
    return 261.6256 * 2 ** ((semitone + 12 * (octave - 4)) / 12)


def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def adsr(n, attack=0.004, decay_rate=8.0):
    t = np.arange(n) / SR
    e = np.exp(-t * decay_rate)
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0, 1, a)
    fade = min(n, int(0.01 * SR))
    e[-fade:] *= np.linspace(1, 0, fade)
    return e


def sine(freq, dur, decay=8.0, harmonics=((1, 1.0),), attack=0.004, sweep=0.0):
    t = t_of(dur)
    f = freq * (1 + sweep * t / max(dur, 1e-6))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = sum(a * np.sin(phase * k) for k, a in harmonics)
    return out * adsr(len(t), attack, decay)


def noise(dur, decay=20.0, lowpass=0.0, attack=0.002):
    n = int(dur * SR)
    x = RNG.standard_normal(n)
    if lowpass:
        # 한 극 저역 통과: lowpass(0~1)가 클수록 둔탁하다.
        y = np.zeros(n)
        acc = 0.0
        for i in range(n):
            acc = acc * lowpass + x[i] * (1 - lowpass)
            y[i] = acc
        x = y / (np.max(np.abs(y)) + 1e-9)
    return x * adsr(n, attack, decay)


def at(sound, offset, total):
    out = np.zeros(int(total * SR))
    start = int(offset * SR)
    end = min(len(out), start + len(sound))
    out[start:end] += sound[: end - start]
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def bell(semitone, octave, dur=0.6, decay=5.0):
    f = hz(semitone, octave)
    return sine(f, dur, decay, ((1, 1.0), (2.0, 0.35), (3.01, 0.18), (4.2, 0.08)))


def arpeggio(notes, step, dur, decay=6.0):
    total = step * (len(notes) - 1) + dur
    return mix(*[at(bell(s, o, dur, decay), i * step, total) for i, (s, o) in enumerate(notes)])


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def build():
    os.makedirs(OUT, exist_ok=True)
    # 단추: 짧고 마른 나무 딸깍.
    save("click", mix(sine(1400, 0.05, 70, ((1, 1), (2.7, 0.3))), noise(0.03, 120) * 0.25), 0.45)
    # 석판 돌리기: 돌판이 구르는 낮은 웅웅 + 잔돌 소리.
    roll = noise(0.55, 4, 0.92) * 0.8 + sine(110, 0.55, 3, ((1, 1), (2, 0.4)), 0.05, -0.3) * 0.6
    ticks = mix(*[at(sine(900 + 60 * i, 0.03, 90) * 0.4, 0.05 + i * 0.07, 0.6) for i in range(7)])
    save("spin", mix(roll, ticks), 0.55)
    # 석판 한 줄이 멈춤: 돌이 맞물리는 툭.
    save("land", mix(sine(180, 0.12, 30, ((1, 1), (2.2, 0.3))), noise(0.06, 60, 0.6) * 0.5), 0.6)
    # 줄 맞춤: 라단조 위로 오르는 금빛 세 음.
    save("line", arpeggio([(2, 5), (9, 5), (14, 5)], 0.07, 0.45, 7), 0.6)
    # 밀기: 돌을 한 칸 미는 묵직한 쿵 + 끌림.
    save("nudge", mix(sine(140, 0.18, 18, ((1, 1), (1.5, 0.4)), 0.003, -0.25), noise(0.12, 25, 0.8) * 0.5), 0.6)
    # 알 고르기: 맑은 두 음.
    save("egg", arpeggio([(9, 5), (14, 5)], 0.06, 0.3, 10), 0.5)
    # 합치기: 바람이 감겨드는 소리 + 화음.
    whoosh = noise(0.4, 3, 0.85) * np.linspace(0.2, 1.0, int(0.4 * SR)) ** 2
    save("merge", mix(whoosh * 0.6, at(arpeggio([(2, 4), (9, 4), (14, 5)], 0.03, 0.5, 6), 0.25, 0.8)), 0.6)
    # 진화: 오르는 다섯 음 + 반짝임.
    evo = arpeggio([(2, 4), (5, 4), (9, 4), (14, 5), (17, 5)], 0.07, 0.6, 4)
    sparkle = mix(*[at(sine(hz(26 + 3 * i, 5), 0.15, 25) * 0.25, 0.3 + 0.05 * i, 1.0) for i in range(5)])
    save("evolve", mix(evo, sparkle), 0.7)
    # 새로 발견: 진화보다 긴 팡파르(바장조로 밝게).
    fan = arpeggio([(5, 4), (9, 4), (12, 4), (17, 5)], 0.09, 0.9, 3)
    chord = at(mix(bell(5, 4, 1.2, 2.2), bell(9, 4, 1.2, 2.2), bell(12, 4, 1.2, 2.2), bell(17, 5, 1.2, 2.2)), 0.4, 1.6)
    save("discover", mix(fan, chord * 0.7), 0.75)
    # 레벨 업: 짧게 오르는 세 음.
    save("levelup", arpeggio([(9, 4), (14, 5), (21, 5)], 0.06, 0.4, 7), 0.6)
    # 보상 · 마력: 작은 방울 소리.
    save("reward", mix(*[at(bell(s, 6, 0.35, 12) * 0.6, i * 0.05, 0.6) for i, s in enumerate([2, 9, 14, 9])]), 0.55)
    # 유물: 깊은 종.
    save("relic", mix(sine(hz(2, 3), 1.6, 1.8, ((1, 1), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1))), bell(14, 5, 1.2, 3) * 0.4), 0.7)
    # 안 됨: 낮게 두 번 웅.
    save("error", mix(sine(150, 0.1, 15, ((1, 1), (3, 0.3))), at(sine(120, 0.12, 15, ((1, 1), (3, 0.3))), 0.11, 0.25)), 0.5)
    # 타격(보통): 둔탁한 퍽.
    save("hit", mix(noise(0.08, 45, 0.7), sine(160, 0.08, 40, ((1, 1),), 0.001, -0.5) * 0.7), 0.5)
    # 타격(강): 원소 상성으로 세게 들어감.
    save("hit_strong", mix(noise(0.14, 28, 0.6), sine(110, 0.16, 22, ((1, 1), (2, 0.3)), 0.001, -0.5)), 0.65)
    # 치명타: 날카로운 쨍 + 퍽.
    save("crit", mix(noise(0.12, 30, 0.5) * 0.7, sine(1800, 0.18, 18, ((1, 1), (2.4, 0.4)), 0.001, -0.4) * 0.5, sine(90, 0.2, 18) * 0.8), 0.7)
    # 궁극기: 낮은 포효(톱니 비슷한 배음 + 떨림) 위에 폭발.
    t = t_of(1.1)
    growl_f = 70 * (1 + 0.5 * t) + 6 * np.sin(2 * np.pi * 23 * t)
    phase = 2 * np.pi * np.cumsum(growl_f) / SR
    growl = sum(np.sin(phase * k) / k for k in range(1, 9)) * adsr(len(t), 0.06, 2.2)
    boom = at(mix(noise(0.9, 4, 0.9), sine(55, 0.9, 4)), 0.35, 1.3)
    save("ult", mix(growl * 0.8, boom), 0.85)
    # 적이 쓰러짐: 가벼운 퐁.
    save("death_enemy", mix(sine(520, 0.12, 25, ((1, 1),), 0.002, -0.6), noise(0.05, 60, 0.5) * 0.3), 0.4)
    # 드래곤이 쓰러짐: 내려가는 낮은 음.
    save("death_dragon", sine(hz(2, 3), 0.7, 4, ((1, 1), (2, 0.4), (3, 0.2)), 0.01, -0.45), 0.6)
    # 승리: 바장조 화음으로 오름.
    save("win", mix(arpeggio([(5, 4), (9, 4), (12, 4)], 0.1, 0.5, 5), at(mix(bell(5, 4, 1.2, 2.5), bell(9, 4, 1.2, 2.5), bell(12, 4, 1.2, 2.5), bell(17, 5, 1.2, 2.5)), 0.32, 1.6) * 0.8), 0.7)
    # 패배: 라단조로 내려감.
    save("lose", mix(at(bell(9, 4, 0.7, 4), 0, 1.6), at(bell(5, 4, 0.7, 4), 0.22, 1.6), at(mix(bell(2, 4, 1.2, 2.5), bell(5, 3, 1.2, 2.5)), 0.44, 1.6)), 0.6)
    # 보스 등장: 징.
    gong = sine(hz(2, 2), 2.2, 1.3, ((1, 1), (1.48, 0.6), (2.03, 0.45), (2.97, 0.3), (4.1, 0.15)), 0.01)
    save("boss", mix(gong, noise(0.3, 12, 0.9) * 0.3), 0.8)
    # 다음 무리 등장: 짧은 뿔나팔.
    t = t_of(0.5)
    horn = sum(np.sin(2 * np.pi * hz(2, 3) * k * t) * (0.8 ** k) for k in range(1, 7)) * adsr(len(t), 0.06, 3)
    save("horn", horn, 0.5)


if __name__ == "__main__":
    build()
    print("효과음을 만들었어요:", sorted(os.listdir(OUT)))
