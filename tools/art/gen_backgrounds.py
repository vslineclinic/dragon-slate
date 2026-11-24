# 배경 그림을 코드로 그린다(그림 생성 AI 없이). 겹겹이 쌓은 실루엣 + 원근 바닥 + 빛.
# 사용: python tools/art/gen_backgrounds.py [이름...]   (이름 없으면 전부)
# 결과: assets/backgrounds/{plains_ruins,ice_canyon,volcano,abyss,title,chart}.png, assets/ui/{glow,grain,vignette}.png
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2  # 두 배로 그린 뒤 줄여서 가장자리를 매끈하게 한다.


def rgb(code):
    code = code.lstrip('#')
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vgrad(h, w, stops):
    """stops: [(위치 0~1, '#색')...] 세로 그러데이션."""
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)
    out = np.zeros((h, 3), dtype=np.float32)
    pos = [s[0] for s in stops]
    cols = [rgb(s[1]) for s in stops]
    for c in range(3):
        out[:, c] = np.interp(ys, pos, [col[c] for col in cols])
    return np.repeat(out[:, None, :], w, axis=1)


def tile_noise(size, cells, rng):
    """가로세로로 이어지는 부드러운 무작위 무늬 0~1."""
    grid = rng.random((cells, cells)).astype(np.float32)
    pad = np.pad(grid, 2, mode='wrap')
    scale = size // cells
    big = Image.fromarray((pad * 255).astype(np.uint8)).resize(((cells + 4) * scale, (cells + 4) * scale), Image.BICUBIC)
    arr = np.asarray(big, dtype=np.float32) / 255.0
    return arr[2 * scale:2 * scale + size, 2 * scale:2 * scale + size]


def fbm(size, rng, base=4, octaves=5):
    out = np.zeros((size, size), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += amp * tile_noise(size, base * 2 ** o, rng)
        total += amp
        amp *= 0.5
    out /= total
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def line1d(w, rng, base, amp, octaves=5, first=3):
    """능선 높이(픽셀 y) 한 줄."""
    xs = np.arange(w, dtype=np.float32)
    out = np.zeros(w, dtype=np.float32)
    a = 1.0
    for o in range(octaves):
        n = first * 2 ** o + 2
        pts = rng.random(n).astype(np.float32) - 0.5
        out += a * np.interp(xs, np.linspace(0, w - 1, n), pts)
        a *= 0.5
    return base + out * amp


def blend(img, color, alpha):
    """alpha: (h,w) 0~1."""
    img += (rgb(color) if isinstance(color, str) else color)[None, None, :] * alpha[..., None] - img * alpha[..., None]


def below(h, w, line, soft=1.5):
    ys = np.arange(h, dtype=np.float32)[:, None]
    return np.clip((ys - line[None, :]) / soft + 0.5, 0.0, 1.0)


def ridge(img, line, top, bottom, depth=220.0, alpha=1.0):
    """능선 아래를 위→아래 색으로 채운다."""
    h, w, _ = img.shape
    mask = below(h, w, line) * alpha
    ys = np.arange(h, dtype=np.float32)[:, None]
    t = np.clip((ys - line[None, :]) / depth, 0.0, 1.0)[..., None]
    col = rgb(top)[None, None, :] * (1 - t) + rgb(bottom)[None, None, :] * t
    img += (col - img) * mask[..., None]


def glow(img, cx, cy, radius, color, strength=1.0, power=2.0, squash=1.0):
    h, w, _ = img.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xs - cx) ** 2 + ((ys - cy) / squash) ** 2) / radius
    a = np.clip(1.0 - d, 0.0, 1.0) ** power * strength
    img += rgb(color)[None, None, :] * a[..., None]


def disc(img, cx, cy, radius, color, alpha=1.0, soft=1.5):
    h, w, _ = img.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    blend(img, color, np.clip((radius - d) / soft + 0.5, 0.0, 1.0) * alpha)


def stars(img, rng, count, y_max, color='#ffffff'):
    h, w, _ = img.shape
    for _ in range(count):
        x, y = rng.integers(0, w), rng.integers(0, int(y_max))
        b = rng.random() ** 3
        fade = 1.0 - y / y_max
        glow(img[max(0, y - 6):y + 7, max(0, x - 6):x + 7], min(x, 6), min(y, 6), 1.5 + 4.5 * b, color, (0.25 + 0.75 * b) * fade, 1.5)


def paste(img, layer):
    """PIL RGBA 레이어를 얹는다."""
    arr = np.asarray(layer, dtype=np.float32) / 255.0
    a = arr[..., 3:4]
    img += (arr[..., :3] - img) * a


def canvas(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0)), None


def hexa(code, alpha=255):
    c = rgb(code)
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), alpha)


def ground(img, hy, tones, far, rng, cell=1.7, bands=(0.38, 0.6, 0.8), haze=0.55):
    """원근 바닥: 멀수록 무늬가 촘촘하고 far 색으로 흐려진다. tones: 어두움→밝음 4색."""
    h, w, _ = img.shape
    size = 1024
    tex = fbm(size, rng, 4, 5)
    ys = np.arange(hy, h, dtype=np.float32)
    t = (ys - hy + 1.0) / (h - hy)
    depth = 1.0 / (t * 0.92 + 0.08)
    xs = (np.arange(w, dtype=np.float32) - w / 2.0) / w
    u = xs[None, :] * depth[:, None] * 0.5 * cell
    v = np.repeat((depth * 1.05 * cell)[:, None], w, axis=1)
    iu = (u * size).astype(np.int64) % size
    iv = (v * size).astype(np.int64) % size
    n = tex[iv, iu]
    keep = smooth(0.0, 0.32, t)[:, None]  # 지평선 쪽은 무늬를 줄여 자글거림을 없앤다.
    n = 0.5 + (n - 0.5) * keep
    cols = [rgb(c) for c in tones]
    out = np.repeat(cols[0][None, None, :], h - hy, axis=0).repeat(w, axis=1).astype(np.float32)
    for i, edge in enumerate(bands):
        a = smooth(edge - 0.015, edge + 0.015, n)[..., None]
        out += (cols[i + 1][None, None, :] - out) * a
    out *= np.interp(t, [0.0, 1.0], [1.12, 0.86]).astype(np.float32)[:, None, None]
    fog = ((1.0 - smooth(0.0, haze, t)) ** 1.6 * 0.9)[:, None, None]
    out += (rgb(far)[None, None, :] - out) * fog
    img[hy:h] = out
    return t


def stage_light(img, hy, color, strength=0.16):
    """전장 가운데를 은은하게 밝혀 유닛이 서는 자리로 눈이 가게 한다."""
    h, w, _ = img.shape
    ys, xs = np.mgrid[hy:h, 0:w].astype(np.float32)
    d = ((xs - w * 0.5) / (w * 0.46)) ** 2 + ((ys - (hy + (h - hy) * 0.5)) / ((h - hy) * 0.5)) ** 2
    a = np.exp(-d * 1.6) * strength
    img[hy:h] += rgb(color)[None, None, :] * a[..., None]


def foreground(img, rng, kind, color, alpha=235):
    """맨 아래에 초점이 나간 어두운 앞풍경을 깔아 깊이를 준다. kind: grass | shard | rock"""
    h, w, _ = img.shape
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    fill = hexa(color, alpha)
    for _ in range(150 if kind == 'grass' else 46):
        x = rng.random()
        side = abs(x - 0.5) * 2.0
        tall = (20 + 90 * rng.random() * (0.35 + 0.65 * side ** 1.5)) * SS
        px = x * w
        if kind == 'grass':
            lean = rng.normal() * 26 * SS
            wd = (5 + 5 * rng.random()) * SS
            draw.polygon([(px - wd, h), (px + wd, h), (px + lean * 0.4 + wd * 0.2, h - tall * 0.6), (px + lean, h - tall)], fill=fill)
        elif kind == 'shard':
            wd = tall * (0.16 + 0.14 * rng.random())
            lean = rng.normal() * wd
            draw.polygon([(px - wd, h), (px + wd, h), (px + lean, h - tall * 1.1)], fill=fill)
        else:
            wd = tall * (0.7 + 0.6 * rng.random())
            pts = [(px - wd, h)]
            for i in range(5):
                pts.append((px - wd + 2 * wd * (i + 0.5) / 5, h - tall * (0.5 + 0.5 * rng.random()) * (1 - abs(i - 2) * 0.16)))
            pts.append((px + wd, h))
            draw.polygon(pts, fill=fill)
    paste(img, layer.filter(ImageFilter.GaussianBlur(2.2 * SS)))


def dots(img, hy, rng, count, colors):
    """작은 꽃 · 불씨 같은 점."""
    def one(draw, x, y, s, rng2):
        r = (1.6 + 1.6 * rng2.random()) * s
        draw.ellipse([x - r, y - r, x + r, y + r], fill=hexa(colors[int(rng2.integers(0, len(colors)))], 235))
    scatter(img, hy, rng, count, one, 0.08)


def scatter(img, hy, rng, count, draw_one, t_min=0.06, edge_bias=0.0):
    """원근에 맞춰 소품을 뿌린다. draw_one(draw, x, y, scale, rng)."""
    h, w, _ = img.shape
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    items = []
    for _ in range(count):
        t = t_min + (1.0 - t_min) * rng.random() ** 1.6
        x = rng.random()
        if edge_bias > 0 and rng.random() < edge_bias:
            x = x * 0.22 if rng.random() < 0.5 else 1.0 - x * 0.22
        items.append((t, x))
    for t, x in sorted(items):
        y = hy + t * (h - hy)
        px = w / 2.0 + (x - 0.5) * w * (0.75 + 0.6 * t)
        draw_one(draw, px, y, (0.22 + 0.78 * t) * SS, rng)
    paste(img, layer)


def finish(img, w, h, vignette=0.32, grain=0.012, seed=7):
    hh, ww, _ = img.shape
    ys, xs = np.mgrid[0:hh, 0:ww].astype(np.float32)
    d = np.sqrt(((xs - ww / 2) / (ww / 2)) ** 2 + ((ys - hh / 2) / (hh / 2)) ** 2)
    img *= (1.0 - vignette * smooth(0.55, 1.45, d))[..., None]
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    arr = np.asarray(out, dtype=np.float32) / 255.0
    arr += (np.random.default_rng(seed).random((h, w, 1)).astype(np.float32) - 0.5) * 2 * grain
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))


def rock(tone, light, shadow):
    def one(draw, x, y, s, rng):
        r = (10 + 22 * rng.random()) * s
        pts = []
        for i in range(7):
            ang = math.pi + math.pi * i / 6.0
            rad = r * (0.75 + 0.35 * rng.random())
            pts.append((x + math.cos(ang) * rad, y + math.sin(ang) * rad * 0.62))
        draw.ellipse([x - r * 1.15, y - r * 0.16, x + r * 1.15, y + r * 0.2], fill=hexa(shadow, 90))
        draw.polygon(pts, fill=hexa(tone))
        top = [pts[1], pts[2], pts[3], pts[4], ((pts[2][0] + pts[4][0]) / 2, y - r * 0.2)]
        draw.polygon(top, fill=hexa(light))
    return one


def tuft(dark, light):
    def one(draw, x, y, s, rng):
        for i in range(int(3 + rng.integers(0, 3))):
            dx = (i - 2) * 5 * s + rng.normal() * 2 * s
            hgt = (9 + 9 * rng.random()) * s
            lean = rng.normal() * 4 * s
            col = light if rng.random() < 0.4 else dark
            draw.polygon([(x + dx - 2.2 * s, y), (x + dx + 2.2 * s, y), (x + dx + lean, y - hgt)], fill=hexa(col, 230))
    return one


def slab(tone, light, shadow):
    """바닥에 박힌 넓적한 돌(원근으로 납작)."""
    def one(draw, x, y, s, rng):
        wd = (26 + 30 * rng.random()) * s
        hg = wd * (0.22 + 0.1 * rng.random())
        skew = rng.normal() * 6 * s
        pts = [(x - wd + skew, y - hg), (x + wd * 0.9 + skew, y - hg * 1.1), (x + wd, y + hg), (x - wd * 0.92, y + hg * 0.9)]
        draw.polygon([(p[0] + 2 * s, p[1] + 4 * s) for p in pts], fill=hexa(shadow, 110))
        draw.polygon(pts, fill=hexa(tone, 235))
        draw.line([pts[0], pts[1]], fill=hexa(light, 200), width=max(1, int(2 * s)))
    return one


def crystal(tone, light, glowc):
    def one(draw, x, y, s, rng):
        n = int(2 + rng.integers(0, 3))
        for i in range(n):
            hgt = (22 + 34 * rng.random()) * s
            wd = (6 + 6 * rng.random()) * s
            dx = (i - n / 2) * 9 * s
            lean = rng.normal() * 7 * s
            tip = (x + dx + lean, y - hgt)
            draw.polygon([(x + dx - wd, y), (x + dx, y + 2 * s), tip], fill=hexa(tone))
            draw.polygon([(x + dx, y + 2 * s), (x + dx + wd, y), tip], fill=hexa(light))
        draw.ellipse([x - 20 * s, y - 3 * s, x + 20 * s, y + 5 * s], fill=hexa(glowc, 60))
    return one


def pillar(draw, x, base, wd, hgt, tone, light, broken_rng=None, cap=True):
    top = base - hgt
    pts = [(x - wd / 2, base), (x - wd / 2, top), (x + wd / 2, top), (x + wd / 2, base)]
    if broken_rng is not None:
        pts = [(x - wd / 2, base), (x - wd / 2, top + wd * 0.5 * broken_rng.random()), (x - wd * 0.1, top),
               (x + wd * 0.15, top + wd * 0.6), (x + wd / 2, top + wd * 0.3 * broken_rng.random()), (x + wd / 2, base)]
    draw.polygon(pts, fill=hexa(tone))
    draw.rectangle([x - wd / 2, top + wd * 0.7, x - wd / 2 + wd * 0.22, base], fill=hexa(light))
    if cap and broken_rng is None:
        draw.rectangle([x - wd * 0.72, top - wd * 0.28, x + wd * 0.72, top], fill=hexa(tone))
        draw.rectangle([x - wd * 0.72, top - wd * 0.28, x + wd * 0.72, top - wd * 0.18], fill=hexa(light))
    draw.rectangle([x - wd * 0.66, base - wd * 0.2, x + wd * 0.66, base], fill=hexa(tone))


def haze_band(img, y, height, color, strength):
    h, w, _ = img.shape
    ys = np.arange(h, dtype=np.float32)
    a = np.exp(-((ys - y) / height) ** 2) * strength
    img += (rgb(color)[None, None, :] - img) * a[:, None, None]


# ───────────────────────── 전장 4곳 ─────────────────────────
FW, FH = 1280, 800
HORIZON = 0.165


def plains(rng):
    w, h = FW * SS, FH * SS
    hy = int(h * HORIZON)
    img = vgrad(h, w, [(0, '#27325f'), (0.07, '#5a4f86'), (0.125, '#c97b84'), (HORIZON, '#ffd9a0'), (1, '#ffd9a0')])
    stars(img, rng, 60, hy * 0.5)
    glow(img, w * 0.74, hy * 0.98, w * 0.3, '#ffcf8a', 0.55, 2.2, 0.5)
    disc(img, w * 0.74, hy * 0.86, 30 * SS, '#fff3d6')
    cloud = fbm(1024, rng, 3, 4)
    cl = np.asarray(Image.fromarray((cloud * 255).astype(np.uint8)).resize((w, hy)), dtype=np.float32) / 255.0
    blend(img[:hy], '#f4a6a0', smooth(0.56, 0.74, cl) * np.linspace(0.15, 0.6, hy, dtype=np.float32)[:, None])
    ridge(img, line1d(w, rng, hy * 0.58, hy * 0.5, 5, 2), '#8e79ad', '#b48ea8', hy * 0.5)
    ridge(img, line1d(w, rng, hy * 0.78, hy * 0.34, 5, 3), '#6a6494', '#8f7da0', hy * 0.4)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x in [0.06, 0.11, 0.2, 0.33, 0.52, 0.6, 0.86, 0.93]:
        tall = hy * (0.34 + 0.42 * rng.random())
        pillar(draw, w * x, hy + 4, 15 * SS, tall, '#4d4c78', '#7b6f9b', rng if rng.random() < 0.55 else None)
    draw.rectangle([w * 0.05, hy - hy * 0.62, w * 0.12, hy - hy * 0.55], fill=hexa('#4d4c78'))
    draw.arc([w * 0.52 - 6, hy - hy * 0.74, w * 0.6 + 6, hy + hy * 0.1], 180, 360, fill=hexa('#4d4c78'), width=14 * SS)
    paste(img, layer)
    ridge(img, line1d(w, rng, hy * 0.985, hy * 0.07, 4, 6), '#4c6a58', '#5f8a62', 60)
    t = ground(img, hy, ['#487359', '#528060', '#5f8f67', '#73a070'], '#d3cf9c', rng, haze=0.3)
    glow(img, w * 0.74, hy + 30 * SS, w * 0.34, '#ffd9a0', 0.22, 2.0, 0.22)
    stage_light(img, hy, '#ffe9b0', 0.14)
    scatter(img, hy, rng, 9, slab('#7f8f78', '#b9c4a0', '#2c4a3a'), 0.2, 1.0)
    scatter(img, hy, rng, 300, tuft('#2f5645', '#93b56c'), 0.05)
    dots(img, hy, rng, 120, ['#fff3c4', '#ffd0d8', '#ffe27a'])
    scatter(img, hy, rng, 14, rock('#7d7a86', '#b4adb5', '#243d31'), 0.12, 0.85)
    haze_band(img, hy + 2, 9 * SS, '#ffe6bd', 0.55)
    foreground(img, rng, 'grass', '#10221a')
    return finish(img, FW, FH, 0.26)


def ice(rng):
    w, h = FW * SS, FH * SS
    hy = int(h * HORIZON)
    img = vgrad(h, w, [(0, '#081230'), (0.08, '#173a6e'), (0.13, '#3f86b4'), (HORIZON, '#c8eef5'), (1, '#c8eef5')])
    stars(img, rng, 140, hy * 0.7)
    aur = fbm(1024, rng, 2, 3)
    au = np.asarray(Image.fromarray((aur * 255).astype(np.uint8)).resize((w, hy)), dtype=np.float32) / 255.0
    ys = np.linspace(0, 1, hy, dtype=np.float32)[:, None]
    band = np.exp(-((ys - 0.3 - (au - 0.5) * 0.5) / 0.13) ** 2)
    img[:hy] += rgb('#4dffc3')[None, None, :] * (band * 0.5)[..., None]
    band2 = np.exp(-((ys - 0.55 - (au.T[:hy, :w] if au.T.shape[0] >= hy and au.T.shape[1] >= w else au) * 0.0 - (au - 0.5) * 0.35) / 0.08) ** 2)
    img[:hy] += rgb('#6a8dff')[None, None, :] * (band2 * 0.28)[..., None]
    disc(img, w * 0.22, hy * 0.36, 20 * SS, '#f4fbff')
    glow(img, w * 0.22, hy * 0.36, 90 * SS, '#bfe3ff', 0.35)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for i in range(34):
        x = w * rng.random()
        tall = hy * (0.25 + 0.6 * rng.random() ** 2)
        wd = tall * (0.16 + 0.12 * rng.random())
        far = rng.random() < 0.5
        tone, light = ('#6fa5cf', '#a6d3ea') if far else ('#3f74ab', '#8fc4e6')
        tip = (x + rng.normal() * wd * 0.4, hy - tall)
        draw.polygon([(x - wd, hy + 4), (x, hy + 4), tip], fill=hexa(light))
        draw.polygon([(x, hy + 4), (x + wd, hy + 4), tip], fill=hexa(tone))
    paste(img, layer)
    t = ground(img, hy, ['#7fa9cf', '#9cc3e0', '#bcdcee', '#e4f4fb'], '#d6f1f7', rng, 1.5, (0.34, 0.56, 0.78), 0.4)
    # 얼음 금: 원근 무늬의 등고선.
    crack = fbm(1024, rng, 6, 3)
    ysg = np.arange(hy, h, dtype=np.float32)
    tt = (ysg - hy + 1.0) / (h - hy)
    depth = 1.0 / (tt * 0.92 + 0.08)
    xs = (np.arange(w, dtype=np.float32) - w / 2.0) / w
    iu = ((xs[None, :] * depth[:, None] * 0.5) * 1024).astype(np.int64) % 1024
    iv = (np.repeat((depth * 0.4)[:, None], w, axis=1) * 1024).astype(np.int64) % 1024
    c = crack[iv, iu]
    line = (1.0 - smooth(0.0, 0.012, np.abs(c - 0.5))) * smooth(0.12, 0.5, tt)[:, None]
    blend(img[hy:], '#5d90bf', line * 0.4)
    scatter(img, hy, rng, 26, crystal('#5d93c4', '#d9f2fb', '#ffffff'), 0.1, 0.7)
    stage_light(img, hy, '#ffffff', 0.08)
    haze_band(img, hy + 2, 9 * SS, '#e9fbfd', 0.55)
    foreground(img, rng, 'shard', '#17324f')
    return finish(img, FW, FH, 0.26)


def volcano(rng):
    w, h = FW * SS, FH * SS
    hy = int(h * HORIZON)
    img = vgrad(h, w, [(0, '#12070d'), (0.07, '#3a1118'), (0.13, '#8a2a1c'), (HORIZON, '#ff9a3d'), (1, '#ff9a3d')])
    cloud = fbm(1024, rng, 3, 5)
    cl = np.asarray(Image.fromarray((cloud * 255).astype(np.uint8)).resize((w, hy)), dtype=np.float32) / 255.0
    blend(img[:hy], '#1b0a10', smooth(0.45, 0.7, cl) * np.linspace(0.9, 0.25, hy, dtype=np.float32)[:, None])
    cx = w * 0.66
    glow(img, cx, hy * 0.3, w * 0.22, '#ff6a1f', 0.75, 2.0, 0.8)
    xs = np.arange(w, dtype=np.float32)
    cone = hy * 0.3 + np.abs(xs - cx) * 0.34 + line1d(w, rng, 0, hy * 0.08, 5, 6)
    cone = np.maximum(cone, hy * 0.3)
    ridge(img, cone, '#2a1216', '#3d1a1a', hy * 0.9)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    pts = [(cx - 6 * SS, hy * 0.3)]
    y = hy * 0.3
    x = cx - 4 * SS
    while y < hy:
        y += 12 * SS
        x += rng.normal() * 9 * SS - 3 * SS
        pts.append((x, y))
    draw.line(pts, fill=hexa('#ffb347'), width=5 * SS, joint='curve')
    draw.line(pts, fill=hexa('#fff0a8'), width=2 * SS, joint='curve')
    paste(img, layer)
    glow(img, cx, hy * 0.3, 60 * SS, '#ffd27a', 0.9, 1.6)
    ridge(img, line1d(w, rng, hy * 0.9, hy * 0.3, 5, 4), '#22101a', '#30141a', 80)
    t = ground(img, hy, ['#191015', '#251519', '#34191b', '#472320'], '#8a3a22', rng, 1.7, (0.36, 0.6, 0.82), 0.34)
    lava = fbm(1024, rng, 5, 3)
    ysg = np.arange(hy, h, dtype=np.float32)
    tt = (ysg - hy + 1.0) / (h - hy)
    depth = 1.0 / (tt * 0.92 + 0.08)
    xsn = (xs - w / 2.0) / w
    iu = ((xsn[None, :] * depth[:, None] * 0.42) * 1024).astype(np.int64) % 1024
    iv = (np.repeat((depth * 0.34)[:, None], w, axis=1) * 1024).astype(np.int64) % 1024
    c = lava[iv, iu]
    dist = np.abs(c - 0.5)
    fade = smooth(0.1, 0.45, tt)[:, None]
    img[hy:] += rgb('#ff5a1a')[None, None, :] * ((1.0 - smooth(0.0, 0.05, dist)) * 0.3 * fade)[..., None]
    blend(img[hy:], '#ff8a2a', (1.0 - smooth(0.004, 0.012, dist)) * fade)
    blend(img[hy:], '#fff0a0', (1.0 - smooth(0.0, 0.005, dist)) * fade)
    scatter(img, hy, rng, 34, rock('#2c1a1e', '#5b2f2a', '#0c0608'), 0.1, 0.6)
    stage_light(img, hy, '#ff7a3a', 0.07)
    dots(img, hy, rng, 90, ['#ffb347', '#ff7a2a', '#fff0a0'])
    haze_band(img, hy + 2, 9 * SS, '#ffa24a', 0.55)
    foreground(img, rng, 'rock', '#0a0507')
    return finish(img, FW, FH, 0.36)


def abyss(rng):
    w, h = FW * SS, FH * SS
    hy = int(h * HORIZON)
    img = vgrad(h, w, [(0, '#04030b'), (0.08, '#120c33'), (0.135, '#3a1f7a'), (HORIZON, '#a06be0'), (1, '#a06be0')])
    stars(img, rng, 260, hy * 0.85, '#e6dcff')
    neb = fbm(1024, rng, 2, 4)
    nb = np.asarray(Image.fromarray((neb * 255).astype(np.uint8)).resize((w, hy)), dtype=np.float32) / 255.0
    img[:hy] += rgb('#5a2bd0')[None, None, :] * (smooth(0.5, 0.85, nb) * 0.35)[..., None]
    ex, ey, er = w * 0.6, hy * 0.42, 34 * SS
    glow(img, ex, ey, er * 3.4, '#b58cff', 0.6, 2.4)
    glow(img, ex, ey, er * 1.5, '#ffffff', 0.95, 3.0)
    disc(img, ex, ey, er, '#05040c')
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for i in range(9):
        x = w * (0.05 + 0.9 * rng.random())
        y = hy * (0.3 + 0.5 * rng.random())
        wd = (30 + 70 * rng.random()) * SS
        top = [(x - wd, y), (x - wd * 0.5, y - wd * 0.14), (x + wd * 0.4, y - wd * 0.18), (x + wd, y)]
        bottom = [(x + wd * 0.5, y + wd * 0.55), (x, y + wd * 0.9), (x - wd * 0.45, y + wd * 0.5)]
        draw.polygon(top + bottom, fill=hexa('#1c1242'))
        draw.polygon(top, fill=hexa('#4a2f8f'))
    paste(img, layer)
    ridge(img, line1d(w, rng, hy * 0.96, hy * 0.12, 5, 5), '#1a1040', '#2a1a5c', 60)
    t = ground(img, hy, ['#0f0a22', '#1a1238', '#271a52', '#3a2874'], '#7a4fc4', rng, 1.7, (0.36, 0.6, 0.82), 0.36)
    # 바닥의 룬 고리(원근 타원).
    ring = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for cxn, tn, rn in [(0.32, 0.3, 0.2), (0.68, 0.55, 0.26), (0.45, 0.85, 0.34)]:
        cy = hy + tn * (h - hy)
        rx = w * rn * (0.4 + 0.6 * tn)
        ry = rx * (0.14 + 0.16 * tn)
        for k, a in [(1.0, 90), (0.82, 60), (0.5, 45)]:
            rd.ellipse([w * cxn - rx * k, cy - ry * k, w * cxn + rx * k, cy + ry * k], outline=hexa('#b79bff', a), width=max(2, int(2 * SS * (0.5 + tn))))
        for j in range(12):
            ang = math.tau * j / 12
            rd.line([(w * cxn + math.cos(ang) * rx * 0.82, cy + math.sin(ang) * ry * 0.82), (w * cxn + math.cos(ang) * rx, cy + math.sin(ang) * ry)], fill=hexa('#b79bff', 70), width=2 * SS)
    paste(img, ring.filter(ImageFilter.GaussianBlur(1.2)))
    scatter(img, hy, rng, 30, crystal('#3b257e', '#9c7bff', '#c8b3ff'), 0.1, 0.7)
    for _ in range(140):
        x, y = rng.integers(0, w), rng.integers(hy + 20, h)
        b = rng.random() ** 2
        glow(img[max(0, y - 8):y + 9, max(0, x - 8):x + 9], min(x, 8), min(y, 8), 2 + 6 * b, '#cdb8ff', 0.2 + 0.5 * b, 1.6)
    stage_light(img, hy, '#8f6bff', 0.1)
    haze_band(img, hy + 2, 9 * SS, '#b98cff', 0.55)
    foreground(img, rng, 'shard', '#07051a')
    return finish(img, FW, FH, 0.38)


# ───────────────────────── 타이틀 ─────────────────────────
def title(rng):
    W, H = 1600, 720
    w, h = W * SS, H * SS
    img = vgrad(h, w, [(0, '#07070f'), (0.3, '#161233'), (0.52, '#4a2350'), (0.66, '#b0483c'), (0.74, '#f0a45a'), (1, '#f0a45a')])
    stars(img, rng, 320, h * 0.5, '#fff1d6')
    cloud = fbm(1024, rng, 3, 5)
    cl = np.asarray(Image.fromarray((cloud * 255).astype(np.uint8)).resize((w, int(h * 0.7))), dtype=np.float32) / 255.0
    fade = np.interp(np.linspace(0, 1, cl.shape[0]), [0, 0.45, 1.0], [0.0, 0.25, 0.7]).astype(np.float32)[:, None]
    blend(img[:cl.shape[0]], '#3a1c3f', smooth(0.5, 0.72, cl) * fade)
    cx, cy = w * 0.5, h * 0.665
    glow(img, cx, cy, w * 0.42, '#ffb060', 0.5, 2.0, 0.7)
    glow(img, cx, cy, 250 * SS, '#ffd9a0', 0.55, 1.8)
    disc(img, cx, cy, 150 * SS, '#ffcf8f', 1.0, 3.0)
    disc(img, cx, cy, 140 * SS, '#ffe2ae', 1.0, 3.0)
    haze_band(img, cy - 30 * SS, 10 * SS, '#e58f5e', 0.5)
    haze_band(img, cy + 34 * SS, 7 * SS, '#d9774f', 0.45)
    ridge(img, line1d(w, rng, h * 0.62, h * 0.2, 6, 3), '#7c3f5c', '#a9564f', h * 0.2)
    haze_band(img, h * 0.7, 40 * SS, '#f2a868', 0.35)
    ridge(img, line1d(w, rng, h * 0.7, h * 0.16, 6, 4), '#4d2a4f', '#733a4c', h * 0.2)
    haze_band(img, h * 0.78, 36 * SS, '#b4585a', 0.3)
    ridge(img, line1d(w, rng, h * 0.79, h * 0.12, 6, 5), '#2a1a3a', '#3d2140', h * 0.2)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    base = h * 0.93
    for x, tall, wd, broken in [(0.035, 0.74, 54, False), (0.115, 0.6, 46, True), (0.185, 0.36, 40, True),
                                (0.965, 0.76, 54, False), (0.885, 0.52, 46, True), (0.815, 0.4, 40, False)]:
        pillar(draw, w * x, base, wd * SS, h * tall, '#120d1c', '#2a1a2e', rng if broken else None)
    draw.rectangle([w * 0.0, h * 0.19 - 26 * SS, w * 0.075, h * 0.19], fill=hexa('#120d1c'))
    draw.rectangle([w * 0.925, h * 0.17 - 26 * SS, w, h * 0.17], fill=hexa('#120d1c'))
    paste(img, layer)
    ridge(img, line1d(w, rng, h * 0.9, h * 0.05, 5, 6), '#0d0a15', '#07060c', 100)
    haze_band(img, h * 0.88, 30 * SS, '#5a2c48', 0.22)
    return finish(img, W, H, 0.5, 0.014)


# ───────────────────────── 도감·스킬의 별지도 바탕 ─────────────────────────
def chart(rng):
    W, H = 1280, 720
    w, h = W * SS, H * SS
    img = vgrad(h, w, [(0, '#0b0c18'), (0.5, '#11101f'), (1, '#0a0910')])
    neb = fbm(1024, rng, 2, 5)
    nb = np.asarray(Image.fromarray((neb * 255).astype(np.uint8)).resize((w, h)), dtype=np.float32) / 255.0
    img += rgb('#2a2350')[None, None, :] * (smooth(0.45, 0.9, nb) * 0.45)[..., None]
    img += rgb('#3a2412')[None, None, :] * (smooth(0.5, 0.95, 1.0 - nb) * 0.3)[..., None]
    stars(img, rng, 520, h, '#fff1d6')
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = w * 0.5, h * 0.52
    gold = '#c9a45c'
    for r, a in [(0.2, 26), (0.34, 22), (0.48, 18), (0.62, 14), (0.78, 10)]:
        rr = h * r
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=hexa(gold, a), width=SS)
    for j in range(24):
        ang = math.tau * j / 24
        draw.line([(cx + math.cos(ang) * h * 0.2, cy + math.sin(ang) * h * 0.2), (cx + math.cos(ang) * h * 0.95, cy + math.sin(ang) * h * 0.95)], fill=hexa(gold, 9 if j % 2 else 16), width=SS)
    for j in range(72):
        ang = math.tau * j / 72
        r0, r1 = h * 0.48, h * (0.495 if j % 6 else 0.51)
        draw.line([(cx + math.cos(ang) * r0, cy + math.sin(ang) * r0), (cx + math.cos(ang) * r1, cy + math.sin(ang) * r1)], fill=hexa(gold, 30), width=SS)
    paste(img, layer)
    return finish(img, W, H, 0.55, 0.012)


# ───────────────────────── 작은 UI 그림 ─────────────────────────
def ui_assets(out):
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sqrt((xs - 31.5) ** 2 + (ys - 31.5) ** 2) / 31.5
    a = np.clip(1.0 - d, 0, 1) ** 2.2
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    arr[..., :3] = 255
    arr[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(out, 'glow.png'))
    g = np.random.default_rng(3).random((128, 128)).astype(np.float32)
    n = np.zeros((128, 128, 4), dtype=np.uint8)
    n[..., :3] = (g * 255).astype(np.uint8)[..., None]
    n[..., 3] = 255
    Image.fromarray(n).save(os.path.join(out, 'grain.png'))
    vw, vh = 320, 180
    ys, xs = np.mgrid[0:vh, 0:vw].astype(np.float32)
    d = np.sqrt(((xs - vw / 2) / (vw / 2)) ** 2 + ((ys - vh / 2) / (vh / 2)) ** 2)
    v = np.zeros((vh, vw, 4), dtype=np.uint8)
    v[..., 3] = (smooth(0.6, 1.42, d) * 255).astype(np.uint8)
    Image.fromarray(v).save(os.path.join(out, 'vignette.png'))


SCENES = {'plains_ruins': (plains, 11), 'ice_canyon': (ice, 23), 'volcano': (volcano, 37), 'abyss': (abyss, 41), 'title': (title, 5), 'chart': (chart, 9)}

if __name__ == '__main__':
    names = sys.argv[1:] or list(SCENES) + ['ui']
    os.makedirs('assets/backgrounds', exist_ok=True)
    os.makedirs('assets/ui', exist_ok=True)
    for name in names:
        if name == 'ui':
            ui_assets('assets/ui')
        else:
            fn, seed = SCENES[name]
            fn(np.random.default_rng(seed)).save('assets/backgrounds/%s.png' % name)
        print('made', name)
