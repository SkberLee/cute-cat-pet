#!/usr/bin/env python3
"""Generate original cozy pixel-art assets for 治愈猫 and pack them into .aseprite.

All pixel art is original (Stardew-like style, not traced). 3D screenshots are
only used as low-opacity 原图 reference layers and are copied into originals/.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ase_io import write_ase

ROOT = Path("/workspace/cute-cat-pet")
PIX = ROOT / "assets/pixel"
ORIG = PIX / "originals"
SHOT = ROOT / "screenshots"
ASE = "/home/box/bin/aseprite"

# ---------------------------------------------------------------------------
# Palette (warm, limited, pastel — cozy 16-bit)
# ---------------------------------------------------------------------------
P = {
    "ink":        (110, 64, 46, 255),
    "ink2":       (86, 50, 38, 255),
    "fur":        (255, 212, 74, 255),
    "fur_l":      (255, 230, 130, 255),
    "fur_d":      (236, 168, 48, 255),
    "fur_dd":     (214, 132, 36, 255),
    "stripe":     (220, 140, 40, 255),
    "white":      (255, 250, 242, 255),
    "white_d":    (236, 220, 204, 255),
    "eye":        (46, 184, 148, 255),
    "eye_d":      (28, 138, 110, 255),
    "eye_dd":     (18, 88, 74, 255),
    "eye_l":      (170, 232, 204, 255),
    "blush":      (255, 154, 170, 255),
    "nose":       (232, 108, 138, 255),
    "ear":        (255, 196, 202, 255),
    "bean":       (224, 118, 140, 255),
    "bean_d":     (196, 88, 112, 255),
    "floor":      (245, 226, 184, 255),
    "floor_l":    (252, 240, 214, 255),
    "floor_d":    (226, 200, 150, 255),
    "floor_line": (210, 178, 120, 255),
    "wall":       (255, 246, 230, 255),
    "wall_d":     (242, 226, 200, 255),
    "base":       (214, 176, 124, 255),
    "base_d":     (190, 148, 98, 255),
    "rug":        (255, 252, 250, 255),
    "rug_d":      (240, 226, 220, 255),
    "rug_line":   (226, 204, 196, 255),
    "mint":       (168, 216, 176, 255),
    "mint_l":     (200, 234, 200, 255),
    "mint_d":     (124, 176, 136, 255),
    "box":        (206, 150, 98, 255),
    "box_l":      (226, 180, 128, 255),
    "box_d":      (172, 118, 74, 255),
    "box_line":   (150, 100, 62, 255),
    "ottoman":    (250, 246, 240, 255),
    "ottoman_d":  (228, 220, 210, 255),
    "fish":       (96, 186, 220, 255),
    "fish_l":     (170, 222, 240, 255),
    "fish_d":     (64, 148, 186, 255),
    "kibble":     (168, 102, 54, 255),
    "kibble_l":   (196, 134, 74, 255),
    "bowl":       (244, 150, 168, 255),
    "bowl_d":     (216, 108, 136, 255),
    "bowl_l":     (255, 196, 206, 255),
    "can":        (236, 232, 226, 255),
    "can_d":      (196, 192, 188, 255),
    "can_pink":   (240, 128, 152, 255),
    "can_food":   (210, 150, 80, 255),
    "saucer":     (230, 220, 214, 255),
    "saucer_d":   (196, 184, 176, 255),
    "milk":       (255, 252, 246, 255),
    "yarn":       (164, 132, 216, 255),
    "yarn_l":     (204, 184, 236, 255),
    "yarn_d":     (120, 90, 176, 255),
    "wand":       (196, 148, 88, 255),
    "wand_d":     (160, 110, 60, 255),
    "feather":    (242, 150, 180, 255),
    "feather_d":  (216, 100, 140, 255),
    "feather_l":  (255, 210, 222, 255),
    "laser":      (255, 64, 80, 255),
    "laser_l":    (255, 170, 170, 255),
    "laser_g":    (255, 120, 130, 160),
    "mouse":      (184, 176, 196, 255),
    "mouse_l":    (216, 210, 224, 255),
    "mouse_d":    (140, 130, 156, 255),
    "mouse_b":    (240, 236, 242, 255),
    "skin":       (245, 198, 174, 255),
    "skin_l":     (255, 222, 200, 255),
    "skin_d":     (224, 164, 146, 255),
    "nail":       (255, 220, 220, 255),
    "heart":      (240, 90, 126, 255),
    "heart_l":    (255, 160, 176, 255),
    "spark":      (255, 232, 150, 255),
    "spark_l":    (255, 252, 230, 255),
    "panel":      (255, 248, 244, 255),
    "panel_d":    (236, 214, 208, 255),
    "panel_edge": (224, 170, 170, 255),
    "btn":        (252, 226, 228, 255),
    "btn_d":      (236, 196, 202, 255),
    "btn_l":      (255, 242, 242, 255),
    "mood":       (240, 128, 160, 255),
    "hunger":     (240, 176, 80, 255),
    "bond":       (160, 144, 216, 255),
    "bar_bg":     (230, 218, 214, 255),
    "text":       (90, 62, 78, 255),
    "shadow":     (110, 80, 60, 50),
}

PALETTE_ORDER = [
    "ink", "ink2", "fur", "fur_l", "fur_d", "fur_dd", "stripe",
    "white", "white_d", "eye", "eye_d", "eye_dd", "eye_l",
    "blush", "nose", "ear", "bean", "bean_d",
    "floor", "floor_l", "floor_d", "floor_line", "wall", "wall_d", "base", "base_d",
    "rug", "rug_d", "rug_line", "mint", "mint_l", "mint_d",
    "box", "box_l", "box_d", "box_line", "ottoman", "ottoman_d",
    "fish", "fish_l", "fish_d", "kibble", "kibble_l", "bowl", "bowl_d", "bowl_l",
    "can", "can_d", "can_pink", "can_food", "saucer", "saucer_d", "milk",
    "yarn", "yarn_l", "yarn_d", "wand", "wand_d", "feather", "feather_d", "feather_l",
    "laser", "laser_l", "mouse", "mouse_l", "mouse_d", "mouse_b",
    "skin", "skin_l", "skin_d", "nail", "heart", "heart_l", "spark", "spark_l",
    "panel", "panel_d", "panel_edge", "btn", "btn_d", "btn_l",
    "mood", "hunger", "bond", "bar_bg", "text",
]


class C:
    """Integer-only RGBA canvas (no anti-alias)."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x: int, y: int, c):
        if 0 <= x < self.w and 0 <= y < self.h and c[3] > 0:
            if c[3] < 255 and self.px[x, y][3] > 0:
                # simple over if dest exists
                r, g, b, a = self.px[x, y]
                a2 = c[3]
                inv = 255 - a2
                self.px[x, y] = (
                    (c[0] * a2 + r * inv) // 255,
                    (c[1] * a2 + g * inv) // 255,
                    (c[2] * a2 + b * inv) // 255,
                    min(255, a2 + a),
                )
            else:
                self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def opaque(self, x, y) -> bool:
        return self.get(x, y)[3] > 0

    def ellipse(self, cx, cy, rx, ry, c):
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.p(x, y, c)

    def circle(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c)

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, c)

    def rrect(self, x, y, w, h, r, c):
        self.rect(x + r, y, w - 2 * r, h, c)
        self.rect(x, y + r, w, h - 2 * r, c)
        self.circle(x + r, y + r, r, c)
        self.circle(x + w - 1 - r, y + r, r, c)
        self.circle(x + r, y + h - 1 - r, r, c)
        self.circle(x + w - 1 - r, y + h - 1 - r, r, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx - dy
        x, y = x0, y0
        while True:
            self.p(x, y, c)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy

    def tri(self, a, b, d, c):
        xs = [a[0], b[0], d[0]]
        ys = [a[1], b[1], d[1]]
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                # barycentric
                x1, y1 = a
                x2, y2 = b
                x3, y3 = d
                den = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
                if den == 0:
                    continue
                wa = ((y2 - y3) * (x - x3) + (x3 - x2) * (y - y3)) / den
                wb = ((y3 - y1) * (x - x3) + (x1 - x3) * (y - y3)) / den
                wc = 1 - wa - wb
                if wa >= -0.01 and wb >= -0.01 and wc >= -0.01:
                    self.p(x, y, c)

    def outline(self, color, diag=False):
        marks = []
        nbrs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diag:
            nbrs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] == 0:
                    continue
                for dx, dy in nbrs:
                    nx, ny = x + dx, y + dy
                    if not self.opaque(nx, ny):
                        marks.append((nx, ny))
        for x, y in marks:
            self.p(x, y, color)

    def bytes(self) -> bytes:
        return self.im.tobytes()

    def image(self) -> Image.Image:
        return self.im.copy()

    def save(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.im.save(path)


def col(name: str):
    return P[name]


# ---------------------------------------------------------------------------
# 原图 helpers
# ---------------------------------------------------------------------------
def _fit_rgba(im: Image.Image, w: int, h: int, alpha: float = 0.40) -> bytes:
    im = im.convert("RGBA")
    # letterbox into w,h (nearest after a shrink that preserves aspect)
    src = im
    # trim fully-transparent
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    scale = min(w / src.width, h / src.height)
    nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
    src = src.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(src, ((w - nw) // 2, (h - nh) // 2), src)
    px = canvas.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, int(a * alpha))
    return canvas.tobytes()


def ref_crop(name: str, box, w: int, h: int, alpha: float = 0.38, chroma=None) -> bytes:
    im = Image.open(ORIG / name).convert("RGBA")
    if box:
        im = im.crop(box)
    if chroma:
        px = im.load()
        cw, ch = im.size
        cr, cg, cb, tol = chroma
        for y in range(ch):
            for x in range(cw):
                r, g, b, a = px[x, y]
                if abs(r - cr) + abs(g - cg) + abs(b - cb) < tol:
                    px[x, y] = (r, g, b, 0)
    return _fit_rgba(im, w, h, alpha)


def empty_ref(w, h) -> bytes:
    return bytes(w * h * 4)


def _guess_size(nbytes):
    pix = nbytes // 4
    # prefer common sprite sizes
    for w in (16, 32, 48, 64, 80, 96, 128, 192):
        if pix % w == 0:
            h = pix // w
            if h > 0:
                return w, h
    # square fallback
    import math
    s = int(math.sqrt(pix))
    return s, pix // s


# ---------------------------------------------------------------------------
# Cat
# ---------------------------------------------------------------------------
def _paw_beans(c: C, x, y, facing="front"):
    """Draw a white sock paw with pink beans. (x,y) is top-left of a ~8x7 paw."""
    # white paw body
    c.ellipse(x + 3, y + 4, 4, 3.4, col("white"))
    c.ellipse(x + 3, y + 4, 4, 3.4, col("white"))
    # slight shade
    c.p(x + 1, y + 5, col("white_d"))
    c.p(x + 6, y + 5, col("white_d"))
    # main pad
    c.ellipse(x + 3, y + 5, 1.6, 1.3, col("bean"))
    # toe beans (3-4)
    toes = [(x, y + 2), (x + 2, y + 1), (x + 4, y + 1), (x + 6, y + 2)]
    for tx, ty in toes:
        c.p(tx, ty, col("bean"))
        c.p(tx, ty + 1, col("bean_d"))


def _face(c: C, cx, cy, blink=False, happy=False, mouth="w", look=0):
    """Draw the chibi face. look: -1 left, 0 center, +1 right; cy is eye row."""
    # white muzzle
    c.ellipse(cx, cy + 8, 11, 7, col("white"))
    c.ellipse(cx, cy + 9, 9, 6, col("white"))
    # forehead stripes (3)
    for dx, w in ((-6, 1.6), (0, 2.0), (6, 1.6)):
        c.ellipse(cx + dx, cy - 8, w, 4.2, col("stripe"))
    # blush
    c.ellipse(cx - 15, cy + 5, 3.2, 2.2, col("blush"))
    c.ellipse(cx + 15, cy + 5, 3.2, 2.2, col("blush"))
    # eyes
    lx, rx = cx - 9 + look, cx + 9 + look
    ey = cy
    if blink or happy:
        for ex in (lx, rx):
            if happy:
                # ^_^  cheery closed
                c.line(ex - 4, ey + 1, ex, ey - 2, col("ink2"))
                c.line(ex, ey - 2, ex + 4, ey + 1, col("ink2"))
                c.line(ex - 3, ey + 1, ex, ey - 1, col("ink"))
                c.line(ex, ey - 1, ex + 3, ey + 1, col("ink"))
            else:
                c.line(ex - 4, ey, ex + 4, ey, col("ink2"))
                c.line(ex - 3, ey + 1, ex + 3, ey + 1, col("ink"))
    else:
        for ex in (lx, rx):
            c.ellipse(ex, ey, 5.2, 6.2, col("ink2"))
            c.ellipse(ex, ey, 4.4, 5.4, col("eye_d"))
            c.ellipse(ex, ey - 0.3, 3.8, 4.6, col("eye"))
            c.ellipse(ex, ey + 1.5, 3.2, 2.4, col("eye_d"))
            # pupil
            c.ellipse(ex + look, ey + 1, 1.6, 2.2, col("eye_dd"))
            # shines
            c.p(ex - 2, ey - 3, col("white"))
            c.p(ex - 1, ey - 3, col("white"))
            c.p(ex - 2, ey - 2, col("white"))
            c.p(ex + 2, ey, col("eye_l"))
    # nose
    c.rect(cx - 1, cy + 6, 3, 2, col("nose"))
    c.p(cx, cy + 5, col("nose"))
    c.p(cx, cy + 7, col("blush"))
    # mouth
    my = cy + 10
    if mouth == "open":
        c.ellipse(cx, my + 1, 2.4, 2.0, col("ink2"))
        c.ellipse(cx, my + 1, 1.4, 1.2, col("blush"))
    elif mouth == "smile":
        c.line(cx - 3, my, cx, my + 2, col("ink"))
        c.line(cx, my + 2, cx + 3, my, col("ink"))
    else:  # w
        c.p(cx, my, col("ink"))
        c.p(cx - 1, my + 1, col("ink"))
        c.p(cx + 1, my + 1, col("ink"))
        c.p(cx - 2, my, col("ink"))
        c.p(cx + 2, my, col("ink"))


def _ears(c: C, cx, cy_head, back=False, perk=0):
    """Ears sitting on the head. perk shifts tips up."""
    # left
    tip_l = (cx - 14, cy_head - 20 - perk)
    c.tri((cx - 18, cy_head - 8), tip_l, (cx - 7, cy_head - 10), col("fur"))
    c.tri((cx - 16, cy_head - 9), (cx - 14, cy_head - 17 - perk), (cx - 9, cy_head - 10), col("ear"))
    c.p(tip_l[0], tip_l[1], col("fur_d"))
    # right
    tip_r = (cx + 14, cy_head - 20 - perk)
    c.tri((cx + 18, cy_head - 8), tip_r, (cx + 7, cy_head - 10), col("fur"))
    c.tri((cx + 16, cy_head - 9), (cx + 14, cy_head - 17 - perk), (cx + 9, cy_head - 10), col("ear"))
    c.p(tip_r[0], tip_r[1], col("fur_d"))
    if back:
        pass


def _tail(c: C, x, y, curl=1, shade=True):
    """Curved tail, tip to the right if curl>0."""
    pts = []
    if curl >= 0:
        segs = [(x, y), (x + 5, y + 2), (x + 9, y - 2), (x + 10, y - 8), (x + 6, y - 12)]
    else:
        segs = [(x, y), (x - 5, y + 2), (x - 9, y - 2), (x - 10, y - 8), (x - 6, y - 12)]
    prev = segs[0]
    r = 3.4
    for i, p in enumerate(segs):
        c.ellipse(p[0], p[1], r, r * 0.9, col("fur_d") if i == 0 else col("fur"))
        c.line(prev[0], prev[1], p[0], p[1], col("fur"))
        # thicken
        c.ellipse((prev[0] + p[0]) / 2, (prev[1] + p[1]) / 2, r, r * 0.85, col("fur"))
        prev = p
        r = max(2.0, r - 0.3)
    # stripe rings
    c.ellipse(segs[1][0], segs[1][1], 2.2, 2.0, col("stripe"))
    c.ellipse(segs[3][0], segs[3][1], 1.8, 1.6, col("stripe"))
    if shade:
        c.p(segs[-1][0], segs[-1][1] - 1, col("fur_l"))


def draw_cat_sit(blink=False, happy=False, mouth="w", paw_up=False, look=0, head_dy=0, squash=0, perk=0) -> C:
    c = C(64, 64)
    cx, ground = 32, 61
    body_cy = 50 + squash
    head_cy = 26 + head_dy
    # tail first (behind)
    _tail(c, 46, 50, curl=1)
    # body
    c.ellipse(cx, body_cy, 15, 11 - squash, col("fur"))
    c.ellipse(cx - 3, body_cy - 3, 10, 8, col("fur_l"))
    c.ellipse(cx + 8, body_cy + 3, 6, 6, col("fur_d"))
    # white chest
    c.ellipse(cx, body_cy - 3, 7, 6, col("white"))
    # hind paw hints
    c.ellipse(cx - 13, ground - 4, 3.5, 2.5, col("fur_d"))
    c.ellipse(cx + 13, ground - 4, 3.5, 2.5, col("fur_d"))
    # front paws
    if paw_up:
        _paw_beans(c, cx - 16, 40)
        _paw_beans(c, cx + 6, ground - 7)
    else:
        _paw_beans(c, cx - 12, ground - 7)
        _paw_beans(c, cx + 4, ground - 7)
    # head
    c.ellipse(cx, head_cy, 20, 16, col("fur"))
    c.ellipse(cx - 4, head_cy - 4, 12, 10, col("fur_l"))
    c.ellipse(cx + 10, head_cy + 4, 8, 8, col("fur_d"))
    _ears(c, cx, head_cy, perk=perk)
    # re-fill top of head to cover ear bases cleanly
    c.ellipse(cx, head_cy - 6, 14, 8, col("fur"))
    c.ellipse(cx - 3, head_cy - 8, 8, 5, col("fur_l"))
    _face(c, cx, head_cy, blink=blink, happy=happy, mouth=mouth, look=look)
    c.outline(col("ink"))
    return c


def draw_cat_side(frame=0, action="walk") -> C:
    """3/4-right facing cat. action: walk/sit/eat-ish."""
    c = C(64, 64)
    bounce = [0, -2, 0, -1][frame % 4]
    ground = 61 + (0 if action == "walk" else 0)
    # body center
    bx, by = 30, 44 + bounce
    if action == "sit":
        bx, by = 30, 50
    # tail
    _tail(c, bx - 16, by + 2, curl=-1)
    # body
    c.ellipse(bx, by, 16, 10, col("fur"))
    c.ellipse(bx - 2, by - 3, 10, 6, col("fur_l"))
    c.ellipse(bx + 6, by + 3, 8, 6, col("fur_d"))
    c.ellipse(bx + 4, by, 6, 5, col("white"))  # chest
    # legs
    if action == "walk":
        phase = [
            ((-6, 0), (6, 1), (-8, 1), (8, 0)),
            ((-2, -2), (4, 0), (-4, 0), (6, -2)),
            ((6, 0), (-6, 1), (8, 1), (-8, 0)),
            ((4, 0), (-2, -2), (6, -2), (-4, 0)),
        ][frame % 4]
        hips = [(-4, 6), (6, 6), (-8, 7), (8, 7)]  # FL FR HL HR relative to body
        colors_top = [col("fur"), col("fur"), col("fur_d"), col("fur_d")]
        for i, ((hx, hy), (dx, dy)) in enumerate(zip(hips, phase)):
            x, y = bx + hx + dx, by + hy + dy
            c.ellipse(x, y, 3, 5, colors_top[i])
            # white sock + tiny bean hint
            c.ellipse(x, y + 5, 2.6, 2.2, col("white"))
            c.p(x, y + 6, col("bean"))
    else:
        # sitting: haunches on the ground, white paws tucked in front
        c.ellipse(bx - 6, ground - 6, 8, 6, col("fur_d"))
        c.ellipse(bx + 2, ground - 5, 7, 5, col("fur"))
        c.ellipse(bx + 6, ground - 6, 4.5, 3.2, col("white"))
        c.ellipse(bx + 10, ground - 6, 4.5, 3.2, col("white"))
        c.p(bx + 5, ground - 4, col("bean"))
        c.p(bx + 7, ground - 3, col("bean"))
        c.p(bx + 9, ground - 3, col("bean"))
        c.p(bx + 11, ground - 4, col("bean"))
    # head (3/4)
    hx, hy = bx + 12, by - 16 + (0 if action != "sit" else -4)
    c.ellipse(hx, hy, 14, 13, col("fur"))
    c.ellipse(hx - 2, hy - 3, 8, 7, col("fur_l"))
    # ears
    c.tri((hx - 8, hy - 6), (hx - 7, hy - 18), (hx - 1, hy - 8), col("fur"))
    c.tri((hx - 7, hy - 8), (hx - 7, hy - 16), (hx - 3, hy - 8), col("ear"))
    c.tri((hx + 2, hy - 6), (hx + 8, hy - 18), (hx + 10, hy - 6), col("fur"))
    c.tri((hx + 4, hy - 7), (hx + 8, hy - 16), (hx + 9, hy - 7), col("ear"))
    c.ellipse(hx, hy - 6, 8, 5, col("fur"))
    # stripe
    c.ellipse(hx + 2, hy - 6, 1.6, 3.5, col("stripe"))
    c.ellipse(hx - 2, hy - 5, 1.2, 3.0, col("stripe"))
    # face
    c.ellipse(hx + 2, hy + 4, 8, 6, col("white"))
    c.ellipse(hx - 10, hy + 3, 2.4, 1.8, col("blush"))
    # eye (one full, one peeking)
    c.ellipse(hx + 4, hy - 1, 4.4, 5.2, col("ink2"))
    c.ellipse(hx + 4, hy - 1, 3.6, 4.4, col("eye_d"))
    c.ellipse(hx + 4, hy - 1, 3.2, 3.8, col("eye"))
    c.ellipse(hx + 4, hy + 1, 1.4, 2.0, col("eye_dd"))
    c.p(hx + 2, hy - 3, col("white"))
    c.p(hx + 3, hy - 3, col("white"))
    # peeking far eye
    c.ellipse(hx - 6, hy, 2.2, 3.0, col("ink2"))
    c.ellipse(hx - 6, hy, 1.6, 2.2, col("eye"))
    # nose / mouth
    c.rect(hx + 8, hy + 3, 2, 2, col("nose"))
    c.p(hx + 7, hy + 6, col("ink"))
    c.p(hx + 8, hy + 7, col("ink"))
    c.outline(col("ink"))
    return c



def _tail_peek(c: C, cx: int, cy: int, side: int = 1, raise_: int = 0) -> None:
    """Small tail peeking beside the hips, used for the front walk."""
    x = cx + side * 15
    y = cy + 3 - raise_
    c.ellipse(x, y, 3.2, 3.6, col("fur"))
    c.ellipse(x + side * 3, y - 3, 2.8, 3.0, col("fur"))
    c.ellipse(x + side * 4, y - 7, 2.4, 2.6, col("fur"))
    c.ellipse(x + side * 3, y - 3, 1.8, 1.8, col("stripe"))
    c.p(x + side * 4, y - 8, col("fur_l"))


def _ears_back(c: C, cx: int, cy: int, perk: int = 0) -> None:
    """Back of the ears — mostly fur, a hint of pink on the outer rim."""
    tip_l = (cx - 14, cy - 20 - perk)
    c.tri((cx - 18, cy - 8), tip_l, (cx - 7, cy - 10), col("fur"))
    c.tri((cx - 16, cy - 9), (cx - 14, cy - 16 - perk), (cx - 10, cy - 10), col("fur_d"))
    c.p(cx - 15, cy - 15 - perk, col("ear"))
    tip_r = (cx + 14, cy - 20 - perk)
    c.tri((cx + 18, cy - 8), tip_r, (cx + 7, cy - 10), col("fur"))
    c.tri((cx + 16, cy - 9), (cx + 14, cy - 16 - perk), (cx + 10, cy - 10), col("fur_d"))
    c.p(cx + 15, cy - 15 - perk, col("ear"))
    c.p(tip_l[0], tip_l[1], col("fur_d"))
    c.p(tip_r[0], tip_r[1], col("fur_d"))


def _head_back(c: C, cx: int, cy: int, perk: int = 0) -> None:
    """Back of the head: ears, fur, forehead stripes. No face."""
    c.ellipse(cx, cy, 20, 16, col("fur"))
    c.ellipse(cx, cy - 4, 12, 10, col("fur_l"))
    for dx, w in ((-6, 1.6), (0, 2.0), (6, 1.6)):
        c.ellipse(cx + dx, cy - 6, w, 4.0, col("stripe"))
    c.ellipse(cx, cy - 6, 14, 8, col("fur"))
    c.ellipse(cx - 3, cy - 8, 8, 5, col("fur_l"))
    _ears_back(c, cx, cy, perk=perk)


def _tail_back(c: C, cx: int, y_base: int, swing: int = 0, raise_: int = 0) -> None:
    """Tail rooted at the rump, curling to one side — stays below the head."""
    s = 1 if swing >= 0 else -1
    mag = abs(swing)
    segs = [
        (cx, y_base),
        (cx + s * (3 + mag // 2), y_base + 2),
        (cx + s * (7 + mag), y_base - 1 - raise_),
        (cx + s * (8 + mag), y_base - 6 - raise_),
        (cx + s * (5 + mag), y_base - 10 - raise_),
    ]
    prev = segs[0]
    r = 3.4
    for i, pt in enumerate(segs):
        c.ellipse(pt[0], pt[1], r, r * 0.9, col("fur_d") if i == 0 else col("fur"))
        c.ellipse((prev[0] + pt[0]) / 2, (prev[1] + pt[1]) / 2, r, r * 0.85, col("fur"))
        prev = pt
        r = max(2.0, r - 0.3)
    c.ellipse(segs[1][0], segs[1][1], 2.2, 2.0, col("stripe"))
    c.ellipse(segs[3][0], segs[3][1], 1.8, 1.6, col("stripe"))
    c.p(segs[-1][0], segs[-1][1] - 1, col("fur_l"))


def draw_cat_walk_down(frame: int) -> C:
    """Front walk (toward the camera). 4-frame bounce with stepping paws."""
    c = C(64, 64)
    cx, ground = 32, 61
    bounce = [0, -3, 0, -2][frame % 4]
    sway = [0, 1, 0, -1][frame % 4]
    body_cy = 49 + bounce
    head_cy = 24 + bounce + (0 if frame % 2 == 0 else -1)
    tail_side = 1 if frame in (0, 1) else -1
    _tail_peek(c, cx + sway, body_cy, side=tail_side, raise_=2 if frame % 2 else 0)
    c.ellipse(cx + sway, body_cy, 14, 10, col("fur"))
    c.ellipse(cx + sway - 3, body_cy - 3, 9, 7, col("fur_l"))
    c.ellipse(cx + sway, body_cy - 3, 7, 6, col("white"))
    # hind socks peeking just behind the front paws (white, not bare fur stubs)
    # Hind socks tucked under the hips (keep them attached to the body).
    if frame in (0, 1):
        c.ellipse(cx + sway + 12, body_cy + 8, 3.0, 2.4, col("white"))
        c.p(cx + sway + 12, body_cy + 9, col("bean"))
        c.ellipse(cx + sway - 12, body_cy + 9, 2.6, 2.0, col("fur_d"))
        c.ellipse(cx + sway - 12, body_cy + 10, 2.2, 1.6, col("white"))
    else:
        c.ellipse(cx + sway - 12, body_cy + 8, 3.0, 2.4, col("white"))
        c.p(cx + sway - 12, body_cy + 9, col("bean"))
        c.ellipse(cx + sway + 12, body_cy + 9, 2.6, 2.0, col("fur_d"))
        c.ellipse(cx + sway + 12, body_cy + 10, 2.2, 1.6, col("white"))
    paws = [
        ((-11, -7, False), (6, -6, False)),
        ((-10, -13, True), (5, -7, False)),
        ((-10, -6, False), (7, -7, False)),
        ((-11, -7, False), (6, -13, True)),
    ][frame % 4]
    for (dx, dy, lifted) in paws:
        x, y = cx + sway + dx, ground + dy + (bounce if not lifted else bounce - 1)
        _paw_beans(c, x, y)
    c.ellipse(cx + sway, head_cy, 19, 16, col("fur"))
    c.ellipse(cx + sway - 4, head_cy - 4, 12, 10, col("fur_l"))
    _ears(c, cx + sway, head_cy, perk=1 if frame % 2 else 0)
    c.ellipse(cx + sway, head_cy - 6, 14, 8, col("fur"))
    c.ellipse(cx + sway - 3, head_cy - 8, 8, 5, col("fur_l"))
    _face(c, cx + sway, head_cy, mouth="w", look=sway)
    c.outline(col("ink"))
    return c


def draw_cat_walk_up(frame: int) -> C:
    """Back walk (toward the wall). Ears + back + tail, no face."""
    c = C(64, 64)
    cx, ground = 32, 61
    bounce = [0, -3, 0, -2][frame % 4]
    sway = [0, -1, 0, 1][frame % 4]
    body_cy = 48 + bounce
    head_cy = 24 + bounce + (0 if frame % 2 == 0 else -1)
    # far (front) paws — tucked under the chest, drawn first
    far = [
        ((-8, 2), (8, 0)),
        ((-6, 0), (7, 2)),
        ((-8, 0), (8, 2)),
        ((-7, 2), (6, 0)),
    ][frame % 4]
    for (dx, dy) in far:
        c.ellipse(cx + sway + dx, body_cy + 8 + dy, 2.6, 2.2, col("fur_d"))
        c.ellipse(cx + sway + dx, body_cy + 10 + dy, 2.0, 1.6, col("white"))
    # body / back
    c.ellipse(cx + sway, body_cy, 14, 10, col("fur"))
    c.ellipse(cx + sway, body_cy - 3, 9, 7, col("fur_l"))
    c.ellipse(cx + sway, body_cy - 1, 2.0, 6, col("stripe"))
    c.ellipse(cx + sway, body_cy + 5, 1.6, 3.4, col("stripe"))
    # hind paws (closer)
    near = [
        ((-12, 0, False), (8, 1, False)),
        ((-11, 1, False), (9, -5, True)),
        ((-12, 1, False), (8, 0, False)),
        ((-11, -5, True), (9, 1, False)),
    ][frame % 4]
    for (dx, dy, lifted) in near:
        x = cx + sway + dx
        y = ground - 6 + dy + (bounce if not lifted else bounce - 1)
        if lifted:
            c.ellipse(x + 3, y + 2, 3.4, 3.0, col("fur_d"))
            c.ellipse(x + 3, y + 4, 3.0, 2.4, col("white"))
            c.p(x + 3, y + 5, col("bean"))
            c.p(x + 1, y + 3, col("bean"))
            c.p(x + 5, y + 3, col("bean"))
        else:
            c.ellipse(x + 3, y + 3, 3.4, 2.6, col("fur_d"))
            c.ellipse(x + 3, y + 5, 3.0, 2.2, col("white"))
            c.p(x + 3, y + 6, col("bean"))
    _head_back(c, cx + sway, head_cy, perk=1 if frame % 2 else 0)
    # tail from the rump, curling to alternate sides
    swing = [-2, 1, 3, 0][frame % 4]
    _tail_back(c, cx + sway, body_cy + 8, swing=swing, raise_=2 if frame % 2 else 0)
    c.outline(col("ink"))
    return c


def draw_cat_walk_side(frame: int) -> C:
    """Improved 3/4 side walk (sprite faces right). Clearer stride + bounce."""
    c = C(64, 64)
    bounce = [0, -3, 0, -2][frame % 4]
    ground = 61
    bx, by = 30, 44 + bounce
    # tail follows the stride (up on passing frames)
    raise_ = 2 if frame % 2 else 0
    _tail(c, bx - 16, by + 2 - raise_, curl=-1)
    # body
    c.ellipse(bx, by, 16, 10, col("fur"))
    c.ellipse(bx - 2, by - 3, 10, 6, col("fur_l"))
    c.ellipse(bx + 6, by + 3, 8, 6, col("fur_d"))
    c.ellipse(bx + 4, by, 6, 5, col("white"))
    # legs: longer travel so the step reads at 64px
    # FL FR HL HR  (dx, dy) relative to hip; negative dy = lifted
    phase = [
        ((-7, 1), (8, 0), (-9, 0), (9, 1)),
        ((1, -4), (3, 1), (-3, 1), (4, -3)),
        ((7, 0), (-7, 1), (9, 1), (-9, 0)),
        ((3, 1), (1, -4), (4, -3), (-3, 1)),
    ][frame % 4]
    hips = [(-4, 6), (7, 6), (-8, 7), (8, 7)]
    colors_top = [col("fur"), col("fur"), col("fur_d"), col("fur_d")]
    for i, ((hx, hy), (dx, dy)) in enumerate(zip(hips, phase)):
        x, y = bx + hx + dx, by + hy + dy
        c.ellipse(x, y, 3, 5, colors_top[i])
        c.ellipse(x, y + 5, 2.8, 2.4, col("white"))
        c.p(x, y + 6, col("bean"))
        if dy <= -3:
            # lifted paw: show a couple of toe beans
            c.p(x - 1, y + 4, col("bean"))
            c.p(x + 1, y + 4, col("bean"))
    # head (3/4, slightly bobs)
    hx, hy = bx + 12, by - 16 + (0 if frame % 2 == 0 else -1)
    c.ellipse(hx, hy, 14, 13, col("fur"))
    c.ellipse(hx - 2, hy - 3, 8, 7, col("fur_l"))
    c.tri((hx - 8, hy - 6), (hx - 7, hy - 18), (hx - 1, hy - 8), col("fur"))
    c.tri((hx - 7, hy - 8), (hx - 7, hy - 16), (hx - 3, hy - 8), col("ear"))
    c.tri((hx + 2, hy - 6), (hx + 8, hy - 18), (hx + 10, hy - 6), col("fur"))
    c.tri((hx + 4, hy - 7), (hx + 8, hy - 16), (hx + 9, hy - 7), col("ear"))
    c.ellipse(hx, hy - 6, 8, 5, col("fur"))
    c.ellipse(hx + 2, hy - 6, 1.6, 3.5, col("stripe"))
    c.ellipse(hx - 2, hy - 5, 1.2, 3.0, col("stripe"))
    c.ellipse(hx + 2, hy + 4, 8, 6, col("white"))
    c.ellipse(hx - 10, hy + 3, 2.4, 1.8, col("blush"))
    c.ellipse(hx + 4, hy - 1, 4.4, 5.2, col("ink2"))
    c.ellipse(hx + 4, hy - 1, 3.6, 4.4, col("eye_d"))
    c.ellipse(hx + 4, hy - 1, 3.2, 3.8, col("eye"))
    c.ellipse(hx + 4, hy + 1, 1.4, 2.0, col("eye_dd"))
    c.p(hx + 2, hy - 3, col("white"))
    c.p(hx + 3, hy - 3, col("white"))
    c.ellipse(hx - 6, hy, 2.2, 3.0, col("ink2"))
    c.ellipse(hx - 6, hy, 1.6, 2.2, col("eye"))
    c.rect(hx + 8, hy + 3, 2, 2, col("nose"))
    c.p(hx + 7, hy + 6, col("ink"))
    c.p(hx + 8, hy + 7, col("ink"))
    c.outline(col("ink"))
    return c


def draw_cat_sit_up() -> C:
    """Idle / sit facing the wall (back view)."""
    c = C(64, 64)
    cx, ground = 32, 61
    body_cy = 50
    head_cy = 26
    # haunches
    c.ellipse(cx, body_cy, 16, 11, col("fur"))
    c.ellipse(cx, body_cy - 3, 10, 8, col("fur_l"))
    c.ellipse(cx, body_cy, 2.0, 6, col("stripe"))
    c.ellipse(cx - 13, ground - 4, 4.0, 2.6, col("fur_d"))
    c.ellipse(cx + 13, ground - 4, 4.0, 2.6, col("fur_d"))
    # no face, just the back of the head
    _head_back(c, cx, head_cy, perk=0)
    # tail curled to the right, resting
    _tail(c, 46, 50, curl=1)
    c.outline(col("ink"))
    return c


def draw_cat_idle_side() -> C:
    return draw_cat_side(0, action="sit")


def draw_cat_eat(frame: int) -> C:
    # head lowered, chew
    bob = [7, 9, 7, 8][frame % 4]
    mouth = ["open", "w", "open", "smile"][frame % 4]
    return draw_cat_sit(blink=False, mouth=mouth, head_dy=bob, squash=1, look=0)


def draw_cat_jump(frame: int) -> C:
    c = C(64, 64)
    # 0 crouch, 1 launch, 2 air, 3 land
    lifts = [2, -8, -16, -3]
    squash = [2, -1, 0, 1]
    lift, sq = lifts[frame], squash[frame]
    cx = 32
    ground = 61
    by = 50 + lift + sq
    hy = 26 + lift
    _tail(c, 48, by, curl=1)
    c.ellipse(cx, by, 15, 11 - sq, col("fur"))
    c.ellipse(cx - 3, by - 3, 10, 7, col("fur_l"))
    c.ellipse(cx, by - 3, 7, 5, col("white"))
    if frame in (1, 2):
        # paws stretched
        for px, py in ((cx - 10, by + 8), (cx + 6, by + 8), (cx - 14, by + 2), (cx + 12, by + 2)):
            c.ellipse(px, py, 3.2, 2.6, col("white") if px > cx - 12 else col("fur_d"))
        if frame == 2:
            # front paws forward (pounce)
            _paw_beans(c, cx - 8, by + 6)
            _paw_beans(c, cx + 2, by + 6)
    else:
        _paw_beans(c, cx - 12, min(ground - 7, by + 6))
        _paw_beans(c, cx + 4, min(ground - 7, by + 6))
    c.ellipse(cx, hy, 20, 16, col("fur"))
    c.ellipse(cx - 4, hy - 4, 12, 10, col("fur_l"))
    _ears(c, cx, hy, perk=1 if frame in (1, 2) else 0)
    c.ellipse(cx, hy - 6, 14, 8, col("fur"))
    mouth = "open" if frame in (1, 2) else "w"
    _face(c, cx, hy, mouth=mouth, look=0)
    c.outline(col("ink"))
    return c


def draw_cat_sleep() -> C:
    c = C(64, 64)
    # curled on its side, head on the left
    c.ellipse(36, 44, 18, 12, col("fur"))
    c.ellipse(34, 41, 12, 8, col("fur_l"))
    c.ellipse(44, 48, 8, 6, col("fur_d"))
    # tail curling around
    _tail(c, 48, 50, curl=1)
    c.ellipse(50, 40, 4, 4, col("fur"))
    # head
    c.ellipse(20, 40, 14, 13, col("fur"))
    c.ellipse(18, 37, 8, 7, col("fur_l"))
    # one ear flop, one up
    c.tri((12, 32), (8, 22), (18, 32), col("fur"))
    c.tri((12, 31), (9, 24), (16, 32), col("ear"))
    c.tri((24, 30), (28, 22), (30, 32), col("fur"))
    c.ellipse(20, 34, 8, 5, col("fur"))
    # closed eyes, peaceful
    c.ellipse(20, 43, 8, 6, col("white"))
    c.line(14, 40, 18, 41, col("ink"))
    c.line(18, 41, 20, 40, col("ink"))
    c.rect(21, 42, 2, 2, col("nose"))
    c.p(20, 45, col("ink"))
    c.ellipse(10, 42, 2.5, 1.8, col("blush"))
    # tucked white paw
    c.ellipse(28, 50, 4, 3, col("white"))
    c.p(27, 51, col("bean"))
    c.p(29, 50, col("bean"))
    c.p(31, 51, col("bean"))
    c.outline(col("ink"))
    return c


def draw_cat_happy() -> C:
    c = draw_cat_sit(happy=True, mouth="smile", perk=1)
    # little hearts (on the sprite, as requested "happy/hearts")
    def heart(x, y, s=1):
        c.p(x - 1 * s, y, col("heart"))
        c.p(x + 1 * s, y, col("heart"))
        c.p(x, y, col("heart_l"))
        c.p(x - 1 * s, y + 1, col("heart"))
        c.p(x, y + 1, col("heart"))
        c.p(x + 1 * s, y + 1, col("heart"))
        c.p(x, y + 2, col("heart"))
        if s > 1:
            c.p(x, y + 3, col("heart"))
    heart(10, 14, 1)
    heart(52, 10, 1)
    heart(48, 20, 1)
    return c


def draw_cat_call() -> C:
    return draw_cat_sit(mouth="open", paw_up=True, perk=1, look=0)


def draw_cat_sit_side() -> C:
    return draw_cat_side(0, action="sit")


# ---------------------------------------------------------------------------
# Room
# ---------------------------------------------------------------------------
def draw_floor_32() -> C:
    """Seamless wood: full-width boards so the tile reads as planks, not bricks."""
    c = C(32, 32)
    bands = [(0, 6, "floor_l"), (6, 5, "floor"), (11, 7, "floor_l"), (18, 6, "floor"), (24, 8, "floor_l")]
    for i, (y, h, sh) in enumerate(bands):
        c.rect(0, y, 32, h, col(sh))
        for x in range(32):
            c.p(x, y + h - 1, col("floor_line"))
        # horizontal grain only (short 2-3px dashes)
        gy = y + max(1, h // 2)
        start = (i * 5) % 7
        for x in range(start, 32, 7):
            c.p(x, gy, col("floor_d"))
            c.p(x + 1, gy, col("floor_d"))
            if h > 5:
                c.p((x + 3) % 32, y + 2, col("floor_d"))
    return c


def draw_floor_16() -> C:
    c = C(16, 16)
    for i, (y, h, sh) in enumerate(((0, 5, "floor_l"), (5, 6, "floor"), (11, 5, "floor_l"))):
        c.rect(0, y, 16, h, col(sh))
        for x in range(16):
            c.p(x, y + h - 1, col("floor_line"))
        for x in range(1 + i * 3, 16, 6):
            c.p(x, y + h // 2, col("floor_d"))
            c.p(x + 1, y + h // 2, col("floor_d"))
    return c


def draw_wall_32(baseboard=False) -> C:
    c = C(32, 32)
    c.rect(0, 0, 32, 32, col("wall"))
    # very subtle mottling
    for x, y in ((4, 6), (12, 3), (20, 10), (28, 5), (8, 18), (24, 22), (16, 14)):
        c.p(x, y, col("wall_d"))
    if baseboard:
        c.rect(0, 24, 32, 8, col("base"))
        c.rect(0, 24, 32, 2, col("base_d"))
        c.rect(0, 30, 32, 1, col("ink"))
        for x in range(0, 32, 8):
            c.p(x, 27, col("base_d"))
    return c


def draw_rug() -> C:
    """White rounded/hex-ish rug 80x48."""
    c = C(80, 48)
    # soft shadow
    c.ellipse(40, 26, 36, 18, col("shadow"))
    # rug body — slightly hexagonal by stacking
    c.ellipse(40, 24, 34, 17, col("rug_d"))
    c.ellipse(40, 23, 33, 16, col("rug"))
    # inner stitch
    for t in range(0, 360, 8):
        import math
        ang = math.radians(t)
        x = int(40 + 28 * math.cos(ang))
        y = int(23 + 13 * math.sin(ang))
        if t % 16 == 0:
            c.p(x, y, col("rug_line"))
    # hex hint: flatter sides
    c.rect(16, 14, 48, 2, col("rug_line"))
    c.rect(16, 32, 48, 1, col("rug_line"))
    return c


def draw_lamp() -> C:
    c = C(32, 48)
    # stand
    c.rect(14, 28, 4, 16, col("base"))
    c.rect(13, 43, 6, 3, col("base_d"))
    c.rect(12, 44, 8, 2, col("base"))
    # mint sphere
    c.circle(16, 18, 11, col("ink"))
    c.circle(16, 18, 10, col("mint_d"))
    c.circle(16, 17, 9, col("mint"))
    c.ellipse(13, 14, 4, 3.5, col("mint_l"))
    c.p(11, 13, col("white"))
    c.outline(col("ink"))
    return c


def draw_box() -> C:
    c = C(32, 32)
    # isometric-ish cardboard cube, simple front+top
    # top
    c.rect(6, 8, 20, 8, col("box_l"))
    # front
    c.rect(6, 16, 20, 12, col("box"))
    # side
    for y in range(8, 28):
        c.p(26, y, col("box_d"))
        c.p(27, y, col("box_d"))
    c.rect(26, 16, 3, 12, col("box_d"))
    # flaps slightly open
    c.rect(8, 4, 8, 5, col("box_l"))
    c.rect(16, 5, 8, 4, col("box"))
    # tape
    c.rect(14, 8, 3, 20, col("white_d"))
    # lines
    c.line(6, 16, 25, 16, col("box_line"))
    c.outline(col("ink"))
    return c


def draw_ottoman() -> C:
    c = C(32, 28)
    c.rrect(4, 8, 24, 16, 3, col("ottoman"))
    c.rect(4, 18, 24, 6, col("ottoman_d"))
    c.rrect(4, 8, 24, 16, 3, col("ottoman"))  # restore top corners
    c.rect(6, 10, 10, 3, col("white"))
    c.outline(col("ink"))
    return c


# ---------------------------------------------------------------------------
# Food
# ---------------------------------------------------------------------------
def draw_fish() -> C:
    c = C(32, 32)
    # teardrop body facing left, light blue dried fish
    c.ellipse(16, 16, 11, 7, col("fish"))
    c.ellipse(14, 15, 7, 5, col("fish_l"))
    c.ellipse(20, 18, 5, 4, col("fish_d"))
    # tail
    c.tri((25, 16), (31, 10), (31, 22), col("fish"))
    c.tri((26, 16), (30, 12), (30, 20), col("fish_l"))
    # fin
    c.tri((16, 10), (20, 6), (20, 12), col("fish_d"))
    # eye
    c.circle(9, 15, 2, col("white"))
    c.p(9, 15, col("ink2"))
    c.p(8, 14, col("white"))
    # mouth
    c.p(5, 16, col("fish_d"))
    c.outline(col("ink"))
    return c


def draw_kibble(full=True) -> C:
    c = C(32, 32)
    # bowl
    c.ellipse(16, 22, 13, 6, col("bowl_d"))
    c.ellipse(16, 20, 13, 7, col("bowl"))
    c.ellipse(16, 18, 11, 5, col("bowl_l"))
    # inner
    c.ellipse(16, 20, 10, 4, col("bowl_d"))
    if full:
        c.ellipse(16, 19, 9, 3.4, col("kibble"))
        for x, y in ((10, 18), (14, 17), (18, 17), (21, 18), (13, 20), (17, 20), (16, 18)):
            c.circle(x, y, 1.6, col("kibble_l") if (x + y) % 2 == 0 else col("kibble"))
            c.p(x, y, col("kibble_l"))
    else:
        c.ellipse(16, 20, 9, 3, col("white_d"))
    c.outline(col("ink"))
    return c


def draw_can(open_=True) -> C:
    c = C(32, 32)
    # cylinder
    c.rect(9, 10, 14, 16, col("can"))
    c.ellipse(16, 10, 7, 3, col("white"))
    c.ellipse(16, 26, 7, 3, col("can_d"))
    c.rect(9, 10, 14, 4, col("can_pink"))
    c.ellipse(16, 10, 7, 3, col("can_pink"))
    # label heart
    c.p(15, 16, col("can_pink"))
    c.p(17, 16, col("can_pink"))
    c.p(16, 17, col("can_pink"))
    if open_:
        # open lid tilt
        c.ellipse(16, 8, 7, 3, col("can_d"))
        c.ellipse(20, 6, 6, 2.5, col("can"))
        c.ellipse(16, 11, 6, 2.5, col("can_food"))
        c.p(14, 11, col("kibble_l"))
        c.p(18, 12, col("kibble"))
    c.outline(col("ink"))
    return c


def draw_milk(full=True) -> C:
    c = C(32, 32)
    c.ellipse(16, 22, 12, 5, col("saucer_d"))
    c.ellipse(16, 20, 12, 6, col("saucer"))
    c.ellipse(16, 19, 9, 4, col("saucer_d"))
    if full:
        c.ellipse(16, 19, 8, 3.4, col("milk"))
        c.ellipse(16, 18, 6, 2, col("white"))
        # steam
        for x, y in ((12, 12), (13, 10), (16, 11), (17, 8), (20, 12)):
            c.p(x, y, col("white_d"))
    else:
        c.ellipse(16, 19, 8, 3, col("saucer"))
    c.outline(col("ink"))
    return c


# ---------------------------------------------------------------------------
# Toys
# ---------------------------------------------------------------------------
def draw_wand() -> C:
    c = C(32, 32)
    # thin fishing-rod style stick
    for i in range(16):
        x, y = 4 + i, 29 - i
        c.p(x, y, col("wand_d"))
        c.p(x + 1, y, col("wand"))
    c.p(4, 30, col("wand_d"))
    c.p(5, 30, col("wand"))
    # string
    c.line(19, 14, 22, 8, col("white_d"))
    c.p(21, 9, col("white_d"))
    # distinct feathers radiating from the tip
    # feather 1 up
    c.tri((22, 8), (20, 1), (24, 6), col("feather"))
    c.line(22, 8, 21, 2, col("feather_d"))
    # feather 2 right
    c.tri((22, 8), (30, 6), (24, 11), col("feather_l"))
    c.line(22, 8, 29, 7, col("feather"))
    # feather 3 down-right
    c.tri((22, 8), (28, 14), (20, 10), col("feather_d"))
    c.line(22, 8, 27, 13, col("feather"))
    # small white fluff
    c.p(23, 7, col("white"))
    c.p(22, 6, col("feather_l"))
    c.outline(col("ink"))
    return c


def draw_yarn() -> C:
    c = C(32, 32)
    c.circle(16, 16, 11, col("yarn_d"))
    c.circle(16, 16, 10, col("yarn"))
    c.ellipse(13, 13, 5, 4, col("yarn_l"))
    # winding lines
    c.ellipse(16, 16, 8, 9, col("yarn_d"))
    c.ellipse(16, 16, 6, 8, col("yarn"))
    c.line(8, 12, 24, 20, col("yarn_d"))
    c.line(10, 22, 23, 10, col("yarn_d"))
    # loose strand
    c.line(24, 18, 29, 24, col("yarn"))
    c.line(29, 24, 27, 28, col("yarn_d"))
    c.outline(col("ink"))
    return c


def draw_laser() -> C:
    c = C(32, 32)
    # soft glow (stepped, not blurred)
    c.circle(16, 16, 8, (255, 140, 150, 70))
    c.circle(16, 16, 5, (255, 100, 110, 120))
    c.circle(16, 16, 3, col("laser_l"))
    c.circle(16, 16, 2, col("laser"))
    c.p(16, 16, col("white"))
    # plus shine
    for d in range(1, 5):
        c.p(16 + d + 3, 16, col("laser_l") if d < 3 else (255, 180, 180, 180))
        c.p(16, 16 - d - 3, col("laser_l") if d < 3 else (255, 180, 180, 180))
    c.p(15, 15, col("white"))
    return c


def draw_mouse() -> C:
    c = C(32, 32)
    # curly tail first
    c.line(22, 22, 28, 18, col("bean"))
    c.line(28, 18, 29, 14, col("bean"))
    c.line(29, 14, 26, 12, col("blush"))
    # teardrop body (nose to the left)
    c.ellipse(15, 18, 11, 8, col("mouse"))
    c.ellipse(13, 17, 7, 6, col("mouse_l"))
    c.ellipse(18, 20, 6, 5, col("mouse_d"))
    # belly
    c.ellipse(14, 21, 6, 4, col("mouse_b"))
    # ears
    c.circle(10, 10, 5, col("mouse"))
    c.circle(10, 10, 3, col("ear"))
    c.circle(18, 9, 4, col("mouse"))
    c.circle(18, 9, 2.4, col("ear"))
    # stitch on forehead
    c.p(12, 14, col("mouse_d"))
    c.p(13, 15, col("mouse_d"))
    c.p(14, 16, col("mouse_d"))
    # eyes
    c.circle(10, 17, 1.6, col("ink2"))
    c.p(10, 16, col("white"))
    c.circle(15, 16, 1.6, col("ink2"))
    c.p(15, 15, col("white"))
    # nose
    c.circle(6, 18, 1.8, col("nose"))
    # whiskers
    c.line(4, 17, 1, 16, col("white_d"))
    c.line(4, 19, 1, 20, col("white_d"))
    c.line(8, 17, 5, 14, col("white_d"))
    c.line(7, 20, 3, 22, col("white_d"))
    # pink feet
    for fx in (10, 14, 17, 20):
        c.ellipse(fx, 25, 2, 1.4, col("bean"))
    c.outline(col("ink"))
    return c


# ---------------------------------------------------------------------------
# FX / UI
# ---------------------------------------------------------------------------
def draw_hand(size=32) -> C:
    c = C(size, size)
    # palm-down, fingers toward top, wrist at bottom (rounded, no arm)
    s = size / 32
    def X(v): return int(round(v * s))
    # wrist cap
    c.ellipse(X(16), X(24), X(7), X(4), col("skin_d"))
    c.ellipse(X(16), X(23), X(6), X(3), col("skin"))
    # palm
    c.ellipse(X(16), X(18), X(9), X(8), col("skin"))
    c.ellipse(X(16), X(17), X(7), X(5), col("skin_l"))
    # 4 fingers
    tips = [(8, 8), (13, 5), (18, 5), (23, 8)]
    for i, (fx, fy) in enumerate(tips):
        c.ellipse(X(fx), X(fy + 4), X(2.4), X(5), col("skin"))
        c.ellipse(X(fx), X(fy + 1), X(2.2), X(3), col("skin"))
        c.p(X(fx), X(fy), col("nail"))
        c.p(X(fx) - 1, X(fy + 1), col("nail"))
    # thumb (right side of palm, since palm-down looking at back? wait)
    # palm-down, back of hand facing us, thumb on the right (viewer's right = character's left? )
    # In v0.2.6 shots, thumb was on the right.
    c.ellipse(X(24), X(16), X(3), X(4), col("skin"))
    c.ellipse(X(25), X(13), X(2.4), X(3), col("skin"))
    c.p(X(25), X(11), col("nail"))
    # knuckle hints
    for kx in (10, 14, 18, 22):
        c.p(X(kx), X(13), col("skin_d"))
    c.outline(col("ink"))
    return c


def draw_heart(size=16) -> C:
    c = C(size, size)
    s = size / 16
    def X(v): return int(round(v * s))
    c.circle(X(5), X(6), X(4), col("heart"))
    c.circle(X(10), X(6), X(4), col("heart"))
    c.tri((X(2), X(7)), (X(13), X(7)), (X(8), X(14)), col("heart"))
    c.p(X(4), X(5), col("heart_l"))
    c.p(X(5), X(4), col("heart_l"))
    c.outline(col("ink"))
    return c


def draw_sparkle(kind=0) -> C:
    c = C(16, 16)
    cx, cy = 8, 8
    if kind == 0:
        c.p(cx, cy, col("spark_l"))
        for d in range(1, 6):
            colr = col("spark") if d < 3 else col("spark_l")
            c.p(cx + d, cy, colr)
            c.p(cx - d, cy, colr)
            c.p(cx, cy + d, colr)
            c.p(cx, cy - d, colr)
        c.p(cx, cy, col("white"))
    else:
        # diamond spark
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            c.p(cx + dx, cy + dy, col("spark") if abs(dx) + abs(dy) > 1 else col("spark_l"))
        c.p(cx, cy, col("white"))
    return c


def draw_bubble() -> C:
    """32x32 9-slice speech bubble (8px corners)."""
    c = C(32, 32)
    c.rrect(1, 1, 30, 24, 6, col("panel_edge"))
    c.rrect(3, 3, 26, 20, 5, col("panel"))
    # tail
    c.tri((12, 22), (18, 22), (10, 30), col("panel_edge"))
    c.tri((13, 22), (17, 21), (11, 28), col("panel"))
    return c


def draw_bubble_tail() -> C:
    c = C(16, 16)
    c.tri((8, 0), (14, 0), (2, 14), col("panel_edge"))
    c.tri((8, 1), (13, 1), (4, 12), col("panel"))
    return c


def draw_panel_mood() -> C:
    c = C(96, 48)
    c.rrect(0, 0, 96, 48, 6, col("panel_edge"))
    c.rrect(2, 2, 92, 44, 5, col("panel"))
    # title bar
    c.rrect(8, 6, 28, 8, 2, col("btn"))
    # 3 tracks
    colors = [col("mood"), col("hunger"), col("bond")]
    fills = [0.25, 0.8, 0.55]
    for i, (cc, f) in enumerate(zip(colors, fills)):
        y = 18 + i * 9
        c.rrect(8, y, 80, 7, 2, col("bar_bg"))
        fw = max(4, int(80 * f))
        c.rrect(8, y, fw, 7, 2, cc)
        c.p(10, y + 1, col("white"))
    return c


def draw_button(pressed=False) -> C:
    c = C(48, 20)
    bg = col("btn_d") if pressed else col("btn")
    edge = col("panel_edge")
    c.rrect(0, 0 if not pressed else 1, 48, 18, 4, edge)
    c.rrect(1, 1 if not pressed else 2, 46, 16, 3, bg)
    if not pressed:
        c.rect(4, 2, 16, 2, col("btn_l"))
    return c


def draw_picker() -> C:
    c = C(128, 48)
    c.rrect(0, 0, 128, 40, 6, col("panel_edge"))
    c.rrect(2, 2, 124, 36, 5, col("panel"))
    # 4 slots
    for i in range(4):
        x = 8 + i * 30
        c.circle(x + 12, 20, 11, col("btn"))
        c.circle(x + 12, 20, 10, col("btn_l"))
    # little tail up
    c.tri((60, 36), (72, 36), (66, 46), col("panel_edge"))
    c.tri((62, 36), (70, 36), (66, 44), col("panel"))
    return c


def draw_app_icon(fg_only=False) -> C:
    c = C(64, 64)
    if not fg_only:
        c.rrect(2, 2, 60, 60, 12, col("panel_edge"))
        c.rrect(4, 4, 56, 56, 11, col("btn"))
        c.rrect(6, 6, 52, 52, 10, col("ear"))
        # cream scallop
        c.circle(32, 36, 22, col("panel"))
    # cat face
    cx, cy = 32, 30
    c.ellipse(cx, cy, 20, 16, col("fur"))
    c.ellipse(cx - 3, cy - 3, 12, 10, col("fur_l"))
    _ears(c, cx, cy, perk=0)
    c.ellipse(cx, cy - 6, 14, 8, col("fur"))
    _face(c, cx, cy, mouth="w")
    if not fg_only:
        # tiny hearts
        c.p(10, 14, col("heart"))
        c.p(11, 15, col("heart"))
        c.p(54, 18, col("heart"))
        c.p(12, 50, col("heart_l"))
    c.outline(col("ink"))
    return c


def draw_palette() -> C:
    cols = 10
    rows = (len(PALETTE_ORDER) + cols - 1) // cols
    sw, sh = 16, 16
    c = C(cols * sw, rows * sh)
    for i, name in enumerate(PALETTE_ORDER):
        x, y = (i % cols) * sw, (i // cols) * sh
        c.rect(x, y, sw, sh, col(name))
    return c


# ---------------------------------------------------------------------------
# Pack / export
# ---------------------------------------------------------------------------
def scale_nn(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.Resampling.NEAREST)


def pack_sprite(path: Path, w, h, pixel_frames, ref_bytes, duration=140):
    """Write .aseprite with 原图 + pixel layers, then resave note later."""
    if isinstance(pixel_frames, C):
        pixel_frames = [pixel_frames]
    frames = [fr.bytes() if isinstance(fr, C) else fr for fr in pixel_frames]
    n = len(frames)
    if ref_bytes is None:
        ref_bytes = empty_ref(w, h)
    elif len(ref_bytes) != w * h * 4:
        # refit whatever underlay we have into the sprite canvas
        src = Image.frombytes("RGBA", _guess_size(len(ref_bytes)), ref_bytes)
        ref_bytes = _fit_rgba(src, w, h, alpha=1.0)  # already has baked alpha
    ref_frames = [ref_bytes] * n
    path.parent.mkdir(parents=True, exist_ok=True)
    write_ase(
        path,
        w,
        h,
        [
            {"name": "原图", "opacity": 255, "reference": True, "frames": ref_frames},
            {"name": "pixel", "opacity": 255, "frames": frames},
        ],
        duration=duration,
    )
    # also write PNG of first frame (and numbered frames)
    out_png = path.with_suffix(".png")
    Image.frombytes("RGBA", (w, h), frames[0]).save(out_png)
    if n > 1:
        for i, fr in enumerate(frames):
            Image.frombytes("RGBA", (w, h), fr).save(path.with_name(f"{path.stem}_{i}.png"))


def make_checker(w, h, cell=8):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    a, b = (248, 240, 230, 255), (236, 220, 200, 255)
    for y in range(h):
        for x in range(w):
            px[x, y] = a if ((x // cell) + (y // cell)) % 2 == 0 else b
    return im


def paste_label(draw: ImageDraw.ImageDraw, xy, text, fill=(90, 62, 78, 255)):
    try:
        font = ImageFont.truetype(
            "/usr/share/sand-box-stock-fonts/truetype/noto/NotoSansCJKsc-Regular.otf", 14
        )
    except Exception:
        try:
            font = ImageFont.truetype(
                "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 14
            )
        except Exception:
            font = ImageFont.load_default()
    draw.text(xy, text, fill=fill, font=font)
    return font


def find_cjk_font(size=16):
    candidates = [
        "/usr/share/sand-box-stock-fonts/truetype/noto/NotoSansSC-Regular.otf",
        "/usr/share/sand-box-stock-fonts/truetype/noto/NotoSansCJKsc-Regular.otf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    ]
    # search
    import glob
    extra = glob.glob("/usr/share/**/*CJK*.[ot]t[fc]", recursive=True) + glob.glob(
        "/usr/share/**/*NotoSansSC*", recursive=True
    )
    for p in candidates + extra:
        if p and Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def main():
    # --- references (cropped 3D shots, low alpha) ---
    # cat sit occupies mid of 720x1280 portrait: roughly x 160-560, y 350-900
    ref_sit = ref_crop("cat_sit_front.png", (140, 360, 580, 980), 64, 64)
    ref_paws = ref_crop("cat_paws_pads.png", (40, 80, 500, 880), 64, 64)
    ref_eat = ref_crop("cat_eat_fish.png", (80, 280, 640, 1100), 64, 64)
    ref_room = ref_crop("room_landscape.png", (200, 40, 1000, 520), 80, 48, alpha=0.30)
    ref_fish = ref_crop("ui_feed_picker.png", (80, 520, 200, 680), 32, 32, alpha=0.35)
    ref_kibble = ref_crop("ui_feed_picker.png", (200, 520, 340, 680), 32, 32, alpha=0.35)
    ref_can = ref_crop("ui_feed_picker.png", (340, 520, 480, 680), 32, 32, alpha=0.35)
    ref_milk = ref_crop("ui_feed_picker.png", (480, 520, 640, 680), 32, 32, alpha=0.35)
    ref_wand = ref_crop("ui_play_picker.png", (80, 520, 200, 680), 32, 32, alpha=0.35)
    ref_yarn = ref_crop("ui_play_picker.png", (200, 520, 340, 680), 32, 32, alpha=0.35)
    ref_laser = ref_crop("ui_play_picker.png", (340, 520, 480, 680), 32, 32, alpha=0.35)
    ref_mouse = ref_crop("toy_mouse_front.png", (150, 80, 650, 520), 32, 32, alpha=0.40)
    ref_hand = ref_crop("hand_closeup.png", (80, 40, 720, 560), 32, 32, alpha=0.40)
    ref_hud = ref_crop("ui_hud_portrait.png", (40, 20, 680, 260), 96, 48, alpha=0.30)
    ref_icon = ref_crop("app_icon.png", None, 64, 64, alpha=0.28)

    # --- cat ---
    pack_sprite(PIX / "cat/sit.aseprite", 64, 64, draw_cat_sit(), ref_sit)
    pack_sprite(PIX / "cat/sit_blink.aseprite", 64, 64, draw_cat_sit(blink=True), ref_sit)
    pack_sprite(PIX / "cat/sit_side.aseprite", 64, 64, draw_cat_sit_side(), ref_sit)
    pack_sprite(
        PIX / "cat/walk.aseprite",
        64,
        64,
        [draw_cat_walk_side(i) for i in range(4)],
        ref_sit,
        duration=110,
    )
    pack_sprite(
        PIX / "cat/walk_side.aseprite",
        64,
        64,
        [draw_cat_walk_side(i) for i in range(4)],
        ref_sit,
        duration=110,
    )
    pack_sprite(
        PIX / "cat/walk_down.aseprite",
        64,
        64,
        [draw_cat_walk_down(i) for i in range(4)],
        ref_sit,
        duration=110,
    )
    pack_sprite(
        PIX / "cat/walk_up.aseprite",
        64,
        64,
        [draw_cat_walk_up(i) for i in range(4)],
        ref_sit,
        duration=110,
    )
    pack_sprite(PIX / "cat/sit_up.aseprite", 64, 64, draw_cat_sit_up(), ref_sit)
    pack_sprite(PIX / "cat/idle_up.aseprite", 64, 64, draw_cat_sit_up(), ref_sit)
    pack_sprite(PIX / "cat/idle_down.aseprite", 64, 64, draw_cat_sit(), ref_sit)
    pack_sprite(PIX / "cat/idle_side.aseprite", 64, 64, draw_cat_idle_side(), ref_sit)
    pack_sprite(PIX / "cat/eat.aseprite", 64, 64, [draw_cat_eat(i) for i in range(4)], ref_eat, duration=130)
    pack_sprite(PIX / "cat/jump.aseprite", 64, 64, [draw_cat_jump(i) for i in range(4)], ref_sit, duration=100)
    pack_sprite(PIX / "cat/sleep.aseprite", 64, 64, draw_cat_sleep(), ref_sit)
    pack_sprite(PIX / "cat/happy.aseprite", 64, 64, draw_cat_happy(), ref_sit)
    pack_sprite(PIX / "cat/call.aseprite", 64, 64, draw_cat_call(), ref_paws)

    # --- room ---
    pack_sprite(PIX / "room/floor_wood_32.aseprite", 32, 32, draw_floor_32(), ref_room)
    pack_sprite(PIX / "room/floor_wood_16.aseprite", 16, 16, draw_floor_16(), empty_ref(16, 16))
    pack_sprite(PIX / "room/wall_cream.aseprite", 32, 32, draw_wall_32(False), ref_room)
    pack_sprite(PIX / "room/wall_baseboard.aseprite", 32, 32, draw_wall_32(True), ref_room)
    pack_sprite(PIX / "room/rug.aseprite", 80, 48, draw_rug(), ref_room)
    pack_sprite(PIX / "room/lamp.aseprite", 32, 48, draw_lamp(), ref_room)
    pack_sprite(PIX / "room/box.aseprite", 32, 32, draw_box(), ref_room)
    pack_sprite(PIX / "room/ottoman.aseprite", 32, 28, draw_ottoman(), ref_room)

    # --- food ---
    pack_sprite(PIX / "food/fish.aseprite", 32, 32, draw_fish(), ref_fish)
    pack_sprite(PIX / "food/kibble_bowl.aseprite", 32, 32, draw_kibble(True), ref_kibble)
    pack_sprite(PIX / "food/kibble_bowl_empty.aseprite", 32, 32, draw_kibble(False), ref_kibble)
    pack_sprite(PIX / "food/can.aseprite", 32, 32, draw_can(True), ref_can)
    pack_sprite(PIX / "food/milk.aseprite", 32, 32, draw_milk(True), ref_milk)
    pack_sprite(PIX / "food/milk_empty.aseprite", 32, 32, draw_milk(False), ref_milk)

    # --- toys ---
    pack_sprite(PIX / "toys/wand.aseprite", 32, 32, draw_wand(), ref_wand)
    pack_sprite(PIX / "toys/yarn.aseprite", 32, 32, draw_yarn(), ref_yarn)
    pack_sprite(PIX / "toys/laser.aseprite", 32, 32, draw_laser(), ref_laser)
    pack_sprite(PIX / "toys/mouse.aseprite", 32, 32, draw_mouse(), ref_mouse)

    # --- fx ---
    pack_sprite(PIX / "fx/hand.aseprite", 32, 32, draw_hand(32), ref_hand)
    pack_sprite(PIX / "fx/hand_48.aseprite", 48, 48, draw_hand(48), _fit_rgba(Image.open(ORIG / "hand_closeup.png"), 48, 48, 0.38))
    pack_sprite(PIX / "fx/heart.aseprite", 16, 16, draw_heart(16), empty_ref(16, 16))
    pack_sprite(PIX / "fx/sparkle.aseprite", 16, 16, [draw_sparkle(0), draw_sparkle(1)], empty_ref(16, 16), duration=180)
    pack_sprite(PIX / "fx/bubble_9slice.aseprite", 32, 32, draw_bubble(), empty_ref(32, 32))
    pack_sprite(PIX / "fx/bubble_tail.aseprite", 16, 16, draw_bubble_tail(), empty_ref(16, 16))

    # --- ui ---
    pack_sprite(PIX / "ui/panel_mood.aseprite", 96, 48, draw_panel_mood(), ref_hud)
    pack_sprite(PIX / "ui/button.aseprite", 48, 20, draw_button(False), empty_ref(48, 20))
    pack_sprite(PIX / "ui/button_pressed.aseprite", 48, 20, draw_button(True), empty_ref(48, 20))
    pack_sprite(PIX / "ui/picker_panel.aseprite", 128, 48, draw_picker(), empty_ref(128, 48))
    # icons reuse food/toys at 32x32 (own files for UI naming)
    for src, dst, ref in (
        (draw_fish, "icon_fish", ref_fish),
        (draw_kibble, "icon_kibble", ref_kibble),
        (draw_can, "icon_can", ref_can),
        (draw_milk, "icon_milk", ref_milk),
        (draw_wand, "icon_wand", ref_wand),
        (draw_yarn, "icon_yarn", ref_yarn),
        (draw_laser, "icon_laser", ref_laser),
        (draw_mouse, "icon_mouse", ref_mouse),
    ):
        pack_sprite(PIX / f"ui/{dst}.aseprite", 32, 32, src() if src != draw_kibble else src(True), ref)

    # app icons
    icon = draw_app_icon(False)
    pack_sprite(PIX / "ui/icon_cat_face.aseprite", 64, 64, icon, ref_icon)
    icon192 = scale_nn(icon.image(), 3)
    icon192.save(PIX / "ui/icon_app_192.png")
    # also wrap 192 in an aseprite (192x192)
    pack_sprite(PIX / "ui/icon_app_192.aseprite", 192, 192, [icon192.tobytes()], _fit_rgba(Image.open(ORIG / "app_icon.png"), 192, 192, 0.25))
    fg = draw_app_icon(True)
    pack_sprite(PIX / "ui/icon_app_fg.aseprite", 64, 64, fg, ref_icon)
    scale_nn(fg.image(), 3).save(PIX / "ui/icon_app_fg_192.png")

    pal = draw_palette()
    pal.save(PIX / "palette.png")
    pack_sprite(PIX / "palette.aseprite", pal.w, pal.h, pal, empty_ref(pal.w, pal.h))

    print("sprites packed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
