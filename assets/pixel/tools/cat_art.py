#!/usr/bin/env python3
"""治愈猫 v0.3.1 cat sprite set (style C: chibi) — original, hand-tuned layered pixel art.

Not procedural blobs: every facing is built from one shared model sheet
(fixed head / body / leg anchors), painted with 4-tone ramps under one top
light, then a selective outline (dark warm brown on shadow sides, lighter on lit
tops, softer brown around white fur), inner contours where a near limb crosses
the body, and hand-authored stamps for eyes, nose, mouth, inner ears and tabby
stripes.  Heads are drawn from the same parts every frame and only move by
whole pixels when the body intentionally bobs, so there is no 1px jitter.

All art is original (Stardew-inspired palette / cozy 16-bit feel, nothing
traced or copied).
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

from PIL import Image

W = H = 96
SOLE = 90          # bottom row of a planted paw
CX = 47.5          # front/back centre line (pixels 47|48 mirror)
K = 1.5            # model units (authored on a 64 grid, sole 60) -> pixels

# ---------------------------------------------------------------------------
# Palette — limited ramps
# ---------------------------------------------------------------------------
FUR = [(255, 226, 146), (250, 190, 84), (228, 146, 58), (186, 104, 46)]
FUR_FAR = [(240, 186, 92), (226, 150, 64), (200, 116, 50), (164, 88, 42)]
WHT = [(255, 252, 244), (250, 240, 228), (232, 216, 204), (204, 184, 174)]
WHT_FAR = [(240, 228, 216), (226, 210, 198), (208, 190, 180), (184, 164, 156)]
STRIPE = (214, 124, 48)
STRIPE_D = (178, 92, 40)
OUT = (104, 54, 36)          # main outline (shadow side / bottom)
OUT_LIT = (150, 86, 48)      # lit top edge
OUT_W = (150, 112, 100)      # outline around white fur
INNER = (168, 92, 46)        # inner contour where limbs overlap body
INNER_W = (184, 150, 140)    # inner contour on white fur
PINK = (246, 172, 176)
PINK_D = (222, 128, 142)
NOSE = (232, 112, 132)
MOUTH = (122, 64, 52)
EYE_D = (40, 38, 56)
EYE = (52, 150, 138)
EYE_L = (124, 210, 186)
EYE_H = (255, 255, 255)
BLUSH = (250, 166, 166)
SHADOW1 = (148, 108, 78, 165)
SHADOW2 = (120, 86, 58, 100)

LIGHT = (0.0, -0.78, 0.62)   # top light, same for every facing


def _norm(v):
    l = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / l for a in v)


LIGHT = _norm(LIGHT)


def ramp_pick(ramp, i, bias=0.0):
    i += bias
    if i > 0.80:
        return ramp[0]
    if i > 0.40:
        return ramp[1]
    if i > 0.10:
        return ramp[2]
    return ramp[3]


# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
@dataclass
class Cv:
    px: dict = field(default_factory=dict)    # (x,y) -> rgb
    mat: dict = field(default_factory=dict)   # (x,y) -> 'fur'|'white'|'detail'|...
    part: dict = field(default_factory=dict)  # (x,y) -> part name
    shadow: dict = field(default_factory=dict)

    def put(self, x, y, col, mat, part):
        if 0 <= x < W and 0 <= y < H:
            self.px[(x, y)] = col
            self.mat[(x, y)] = mat
            self.part[(x, y)] = part

    def has(self, x, y):
        return (x, y) in self.px

    def image(self, scale=1):
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        p = im.load()
        for (x, y), c in self.shadow.items():
            p[x, y] = c
        for (x, y), c in self.px.items():
            p[x, y] = (c[0], c[1], c[2], 255)
        if scale != 1:
            im = im.resize((W * scale, H * scale), Image.NEAREST)
        return im

    def bytes(self):
        return self.image().tobytes()

    def flip(self):
        o = Cv()
        for (x, y), c in self.px.items():
            o.px[(W - 1 - x, y)] = c
            o.mat[(W - 1 - x, y)] = self.mat[(x, y)]
            o.part[(W - 1 - x, y)] = self.part[(x, y)]
        for (x, y), c in self.shadow.items():
            o.shadow[(W - 1 - x, y)] = c
        return o


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------
def ellipse(c, cx, cy, rx, ry, ramp, mat, part, bias=0.0, clip=None, light=LIGHT, only_over=None):
    x0, x1 = int(math.floor(cx - rx)) - 1, int(math.ceil(cx + rx)) + 1
    y0, y1 = int(math.floor(cy - ry)) - 1, int(math.ceil(cy + ry)) + 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            u = (x - cx) / rx
            v = (y - cy) / ry
            d = u * u + v * v
            if d > 1.0:
                continue
            if clip and not clip(x, y):
                continue
            if only_over is not None and c.part.get((x, y)) not in only_over:
                continue
            z = math.sqrt(max(0.0, 1.0 - d))
            i = u * light[0] + v * light[1] + z * light[2]
            c.put(x, y, ramp_pick(ramp, i, bias), mat, part)


def capsule(c, x0, y0, x1, y1, r0, r1, ramp, mat, part, bias=0.0, clip=None):
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy or 1e-6
    rmax = max(r0, r1)
    for y in range(int(min(y0, y1) - rmax) - 1, int(max(y0, y1) + rmax) + 2):
        for x in range(int(min(x0, x1) - rmax) - 1, int(max(x0, x1) + rmax) + 2):
            t = ((x - x0) * dx + (y - y0) * dy) / L2
            t = max(0.0, min(1.0, t))
            px, py = x0 + dx * t, y0 + dy * t
            r = r0 + (r1 - r0) * t
            ex, ey = x - px, y - py
            d = math.sqrt(ex * ex + ey * ey)
            if d > r:
                continue
            if clip and not clip(x, y):
                continue
            u = ex / r
            v = ey / r
            z = math.sqrt(max(0.0, 1.0 - min(1.0, u * u + v * v)))
            i = u * LIGHT[0] + v * LIGHT[1] * 0.6 + z * LIGHT[2] + 0.08
            c.put(x, y, ramp_pick(ramp, i, bias), mat, part)


def poly(c, pts, col_fn, mat, part):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            if _inside(pts, x, y):
                col = col_fn(x, y)
                if col:
                    c.put(x, y, col, mat, part)


def _inside(pts, x, y):
    px, py = x + 0.0, y + 0.0
    ins = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > py) != (yj > py):
            xc = (xj - xi) * (py - yi) / (yj - yi) + xi
            if px < xc:
                ins = not ins
        j = i
    return ins


def stamp(c, x, y, rows, cmap, mat="detail", part=None, only_on=None, flip=False):
    for j, row in enumerate(rows):
        n = len(row)
        for i, ch in enumerate(row):
            if ch in ". ":
                continue
            col = cmap[ch]
            xx = x + (n - 1 - i if flip else i)
            yy = y + j
            if only_on is not None and c.part.get((xx, yy)) not in only_on:
                continue
            c.put(xx, yy, col, mat, part or c.part.get((xx, yy), "detail"))


def recolor(c, region_fn, mapping):
    for k, col in list(c.px.items()):
        if region_fn(*k) and col in mapping:
            c.px[k] = mapping[col]


def stripe_band(c, pts, parts, width=1):
    """Paint a tabby stripe along a polyline, only over fur of given parts."""
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        steps = int(max(abs(bx - ax), abs(by - ay)) * 2) + 1
        for s in range(steps + 1):
            t = s / steps
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t
            for ox in range(width):
                k = (int(round(x)) + ox, int(round(y)))
                if c.part.get(k) in parts and c.mat.get(k) == "fur":
                    col = c.px[k]
                    c.px[k] = STRIPE if col in (FUR[0], FUR[1], FUR_FAR[0]) else STRIPE_D


def sock(c, part, y_from, ramp=WHT):
    """Turn the bottom of a leg white with the same shading band — no seam."""
    for k in list(c.px.keys()):
        if c.part.get(k) == part and k[1] >= y_from and c.mat.get(k) == "fur":
            src = FUR if c.px[k] in FUR else FUR_FAR
            idx = src.index(c.px[k]) if c.px[k] in src else 1
            c.px[k] = ramp[min(3, idx)]
            c.mat[k] = "white"


def contour(c, front_parts, behind_parts, min_y=-1, max_y=99):
    """Inner outline on the edge of a near part where it lies over a far part."""
    marks = []
    for (x, y), p in c.part.items():
        if p not in front_parts or y < min_y or y > max_y:
            continue
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if c.part.get((nx, ny)) in behind_parts:
                marks.append((x, y))
                break
    for k in marks:
        c.px[k] = INNER_W if c.mat.get(k) == "white" else INNER


def outline(c):
    add = {}
    for y in range(H):
        for x in range(W):
            if (x, y) in c.px:
                continue
            nb = [(x, y + 1), (x, y - 1), (x + 1, y), (x - 1, y)]
            hit = [k for k in nb if k in c.px]
            if not hit:
                continue
            mats = [c.mat.get(k) for k in hit]
            white = mats.count("white") > len(mats) / 2
            only_below = hit == [(x, y + 1)]
            if white:
                col = OUT_W
            elif only_below and y < 62:
                col = OUT_LIT
            else:
                col = OUT
            add[(x, y)] = col
    for k, col in add.items():
        c.px[k] = col
        c.mat[k] = "outline"
        c.part[k] = "outline"


def despeckle(c):
    """Remove lone pixels inside flat fills (never details or outline)."""
    changes = {}
    for (x, y), col in c.px.items():
        if c.mat.get((x, y)) not in ("fur", "white"):
            continue
        nb = [c.px.get(k) for k in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))]
        if None in nb:
            continue
        if all(n == nb[0] for n in nb) and nb[0] != col:
            nm = [c.mat.get(k) for k in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))]
            if all(m == c.mat[(x, y)] for m in nm):
                changes[(x, y)] = nb[0]
    for k, v in changes.items():
        c.px[k] = v


def ground_shadow(c, xs, sole=SOLE):
    """Soft contact shadow under planted paws, only on empty pixels."""
    for (x0, x1) in xs:
        for x in range(int(x0) - 1, int(x1) + 2):
            for y, col in ((sole + 1, SHADOW1), (sole + 2, SHADOW2)):
                if (x, y) not in c.px:
                    edge = x in (int(x0) - 1, int(x1) + 1)
                    if y == sole + 2 and edge:
                        continue
                    c.shadow[(x, y)] = SHADOW2 if edge else col


def finish(c, shadows=()):
    despeckle(c)
    outline(c)
    ground_shadow(c, shadows)
    return c

# ---------------------------------------------------------------------------
# Tail (front/back/side) — chain of circles along a curve, ringed stripes
# ---------------------------------------------------------------------------
def tail(c, pts, r0=2.6, r1=1.9, ramp=FUR, part="tail", rings=True, white_tip=False):
    # Catmull-Rom through control points
    samples = []
    P = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P) - 2):
        for s in range(8):
            t = s / 8
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t ** 3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
            samples.append((x, y))
    samples.append(pts[-1])
    n = len(samples)
    length = 0.0
    acc = [0.0]
    for a, b in zip(samples, samples[1:]):
        length += math.dist(a, b)
        acc.append(length)
    for k, (x, y) in enumerate(samples):
        t = k / max(1, n - 1)
        r = r0 + (r1 - r0) * t
        ellipse(c, x, y, r, r, ramp, "fur", part, bias=0.05)
    if rings:
        # stripe rings every ~5px along the tail, perpendicular to direction
        for k in range(1, n - 1):
            if int(acc[k] / 4.6) != int(acc[k - 1] / 4.6) and acc[k] > 4:
                x, y = samples[k]
                ax, ay = samples[k + 1][0] - samples[k - 1][0], samples[k + 1][1] - samples[k - 1][1]
                l = math.hypot(ax, ay) or 1
                nx, ny = -ay / l, ax / l
                r = r0 + (r1 - r0) * (k / (n - 1)) + 0.4
                for s in range(-6, 7):
                    q = (int(round(x + nx * r * s / 6)), int(round(y + ny * r * s / 6)))
                    if c.part.get(q) == part and c.mat.get(q) == "fur":
                        c.px[q] = STRIPE if c.px[q] in (ramp[0], ramp[1]) else STRIPE_D
    if white_tip:
        tx, ty = samples[-1]
        ellipse(c, tx, ty, r1 + 0.3, r1 + 0.3, WHT, "white", part)


# ---------------------------------------------------------------------------
# Model-unit helpers: poses are authored on a 64-unit grid (centre 31.5, sole
# 60) and mapped to the 80px canvas.  Whole-pixel offsets (bob, lift) are
# given in PIXELS and converted with /K so shapes shift without re-rasterising
# differently (no 1px jitter).
# ---------------------------------------------------------------------------
def X(x):
    return CX + (x - 31.5) * K


def Y(y):
    return SOLE + (y - 60.0) * K


def P(px):  # pixels -> model units
    return px / K


def el(c, x, y, rx, ry, ramp, mat, part, bias=0.0, clip=None, only_over=None):
    ellipse(c, X(x), Y(y), rx * K, ry * K, ramp, mat, part, bias=bias, clip=clip, only_over=only_over)


def cap(c, x0, y0, x1, y1, r0, r1, ramp, mat, part, bias=0.0, clip=None):
    capsule(c, X(x0), Y(y0), X(x1), Y(y1), r0 * K, r1 * K, ramp, mat, part, bias=bias, clip=clip)


def pl(c, pts, col_fn, mat, part):
    poly(c, [(X(a), Y(b)) for a, b in pts], col_fn, mat, part)


def tl(c, pts, r0, r1, ramp=FUR, part="tail", white_tip=True):
    tail(c, [(X(a), Y(b)) for a, b in pts], r0=r0 * K, r1=r1 * K, ramp=ramp, part=part, white_tip=False)
    if white_tip:
        # fluffy white pom on the last ~25% of the tail
        a, b = pts[-1]
        a2, b2 = pts[-2]
        tx, ty = X(a + (a2 - a) * 0.15), Y(b + (b2 - b) * 0.15)
        ellipse(c, tx, ty, r1 * K + 1.3, r1 * K + 1.3, WHT, "white", part, bias=0.15)


def sb(c, pts, parts):
    stripe_band(c, [(X(a), Y(b)) for a, b in pts], parts)


def sk(c, part, y_from, ramp=WHT):
    sock(c, part, Y(y_from), ramp)


def ct(c, front, behind, min_y=-99, max_y=999):
    contour(c, front, behind, min_y=Y(min_y) if min_y > -99 else -1, max_y=Y(max_y) if max_y < 999 else 999)


def ix_(x):
    return int(round(X(x)))


def iy_(y):
    return int(round(Y(y)))


def shadows_at(xs, half=3.0):
    return [(X(x) - half * K, X(x) + half * K) for x in xs]


# ---------------------------------------------------------------------------
# Face stamps (80px canvas — larger, cleaner chibi eyes)
# ---------------------------------------------------------------------------
EYEMAP = {"e": EYE_D, "g": EYE, "G": EYE_L, "h": EYE_H, "m": MOUTH, "n": NOSE,
          "p": PINK, "P": PINK_D, "b": BLUSH, "s": STRIPE, "S": STRIPE_D,
          "w": WHT[0], "W": WHT[2], "o": OUT}
EM = dict(EYEMAP)
BLUSH_L = (252, 192, 188)
EM.update({"B": BLUSH, "b": BLUSH_L})

EYE_OPEN = [
    "...eeeeee...",
    ".eeeeeeeeee.",
    "eehhheeeeeee",
    "ehhhheeeeeee",
    "ehhhheeeeeee",
    "eehheeeeeeee",
    "eeeeeggggeee",
    "eeggggggggee",
    "egggggggggge",
    "eggGGGGGhgge",
    "egGGGGGGGGge",
    ".eeGGGGGGee.",
    "...eeeeee...",
]
EYE_HALF = ["." * 12] * 5 + [
    "eeeeeeeeeeee",
    "eeheeeggggee",
    "eeggggggggee",
    "egggggggggge",
    "eggGGGGGhgge",
    "egGGGGGGGGge",
    ".eeGGGGGGee.",
    "...eeeeee...",
]
EYE_SHUT = ["." * 12] * 9 + ["e..........e", ".ee......ee.", "...eeeeee...", "." * 12]
EYE_HAPPY = ["." * 12] * 5 + ["...eeeeee...", ".ee......ee.", "e..........e"] + ["." * 12] * 5
SIDE_EYE = {
    "open": [".eeeeee.", "eehhheee", "ehhhheee", "ehhheeee", "eeheeeee", "eeggggee", "eggggghe", "egGGGgge", ".eGGGGe.", "..eeee.."],
    "half": ["........"] * 4 + ["eeeeeeee", "eheggeee", "eggggghe", "egGGGgge", ".eGGGGe.", "..eeee.."],
    "shut": ["........"] * 7 + ["e......e", ".eeeeee.", "........"],
    "happy": ["........"] * 4 + [".eeeeee.", "e......e"] + ["........"] * 4,
}

# Model sheet (style C), model units
HEAD = dict(cy=30.0, rx=17.8, ry=14.8)      # front / back head
BODY = dict(cy=51.0, rx=8.6, ry=5.8)        # standing torso (front)
LEG_X, HIP_X = 3.6, 7.0
SHEAD = dict(cx=39.5, cy=31.5, rx=14.4, ry=13.2)
SBODY = dict(cx=27.0, cy=49.0, rx=11.0, ry=6.4)


# ---------------------------------------------------------------------------
# FRONT head
# ---------------------------------------------------------------------------
def _ear_front(c, hx, hy, side, part, flat=False):
    rx, ry = HEAD["rx"], HEAD["ry"]
    if flat:   # relaxed, leaning out to the sides
        tip = (hx + side * rx * 0.86, hy - ry - 0.6)
        base_o = (hx + side * (rx + 0.6), hy - ry * 0.20)
        base_i = (hx + side * rx * 0.30, hy - ry * 0.80)
    else:
        tip = (hx + side * rx * 0.68, hy - ry - 3.6)
        base_o = (hx + side * rx * 0.99, hy - ry * 0.30)
        base_i = (hx + side * rx * 0.24, hy - ry * 0.84)
    cyc = Y(tip[1] + 2.6)
    tipy = Y(tip[1])
    pl(c, [base_i, tip, base_o], lambda x, y: (FUR[1] if y < tipy + 7 else FUR[2]) if y >= cyc else None, "fur", part)
    el(c, tip[0] - side * 0.3, tip[1] + 2.6, 2.6, 2.6, FUR, "fur", part, bias=0.1)
    # inner ear
    tx, ty = ix_(tip[0] - side * 0.3), iy_(tip[1] + 1.4)
    rows = ["pp", "ppp", "Pppp", "Pppp", "PPp"]
    for j, row in enumerate(rows):
        n = len(row)
        for i, ch in enumerate(row):
            if side < 0:
                xx = tx - 1 + i
            else:
                xx = tx + 1 - i
            c.put(xx, ty + j, EM[ch], "detail", part)


def front_head(c, dy=0.0, dx=0.0, eyes="open", ears="up", mouth="w", part="head"):
    hx, hy = 31.5 + dx, HEAD["cy"] + dy
    rx, ry = HEAD["rx"], HEAD["ry"]
    for side in (-1, 1):
        _ear_front(c, hx, hy, side, part + "_ear", flat=(ears == "flat"))
    yclip = Y(hy + ry * 0.3)
    el(c, hx, hy + ry * 0.35, rx + 0.6, ry * 0.55, FUR, "fur", part, clip=lambda x, y: y >= yclip, bias=0.06)
    el(c, hx, hy, rx, ry, FUR, "fur", part, bias=0.14)
    el(c, hx, hy + ry * 0.60, 4.4, 3.0, WHT, "white", part, bias=0.3)
    ix, iy = int(math.floor(X(hx))), iy_(hy)
    top = iy_(hy - ry) + 2
    # tabby M (2px strokes)
    stamp(c, ix, top, ["ss", "ss", "ss", "SS"], EM, "fur", part)
    stamp(c, ix - 4, top + 1, ["s", "s", "s", "S"], EM, "fur", part)
    stamp(c, ix + 5, top + 1, ["s", "s", "s", "S"], EM, "fur", part)
    stamp(c, ix - 8, top + 3, ["s", "s", "S"], EM, "fur", part)
    stamp(c, ix + 9, top + 3, ["s", "s", "S"], EM, "fur", part)
    # cheek stripes
    off = int(round(rx * K)) - 1
    stamp(c, ix - off, iy + 2, ["sss.", ".SSS"], EM, "fur", part, only_on=(part,))
    stamp(c, ix + off - 2, iy + 2, [".sss", "SSS."], EM, "fur", part, only_on=(part,))
    stamp(c, ix - off + 1, iy + 5, ["ss.", ".SS"], EM, "fur", part, only_on=(part,))
    stamp(c, ix + off - 2, iy + 5, [".ss", "SS."], EM, "fur", part, only_on=(part,))
    st = {"open": EYE_OPEN, "half": EYE_HALF, "shut": EYE_SHUT, "happy": EYE_HAPPY}[eyes]
    w, h = len(st[0]), len(st)
    ex = int(round(rx * 0.45 * K))
    ey = iy - h // 2 + 3
    stamp(c, ix - ex - w // 2 + 1, ey, st, EM, "detail", part)
    stamp(c, ix + ex - w // 2 + 1, ey, st, EM, "detail", part)
    by = ey + h - 1
    for sx in (ix - ex - w // 2 - 2, ix + ex + w // 2 - 2):
        stamp(c, sx, by, ["bBBBBb", ".bbbb."], EM, "detail", part, only_on=(part,))
    ny = iy_(hy + ry * 0.60) - 2
    c.put(ix, ny, NOSE, "detail", part)
    c.put(ix + 1, ny, NOSE, "detail", part)
    c.put(ix, ny + 1, PINK_D, "detail", part)
    c.put(ix + 1, ny + 1, PINK_D, "detail", part)
    if mouth == "w":
        for (x, y) in ((ix - 2, ny + 2), (ix + 3, ny + 2), (ix - 1, ny + 3), (ix + 2, ny + 3), (ix, ny + 2), (ix + 1, ny + 2)):
            c.put(x, y, MOUTH, "detail", part)
    else:  # open (meow / chew)
        for (x, y) in ((ix - 1, ny + 2), (ix + 2, ny + 2), (ix - 1, ny + 3), (ix + 2, ny + 3), (ix, ny + 4), (ix + 1, ny + 4)):
            c.put(x, y, MOUTH, "detail", part)
        for (x, y) in ((ix, ny + 2), (ix + 1, ny + 2), (ix, ny + 3), (ix + 1, ny + 3)):
            c.put(x, y, PINK_D, "detail", part)


def back_head(c, dy=0.0, dx=0.0, ear_twitch=0, part="head"):
    hx, hy = 31.5 + dx, HEAD["cy"] + dy
    rx, ry = HEAD["rx"], HEAD["ry"]
    for side in (-1, 1):
        tw = ear_twitch if side > 0 else 0
        tip = (hx + side * (rx * 0.68 + tw), hy - ry - 3.6 + abs(tw))
        base_o = (hx + side * rx * 0.99, hy - ry * 0.30)
        base_i = (hx + side * rx * 0.24, hy - ry * 0.84)
        cyc, tipy = Y(tip[1] + 2.6), Y(tip[1])
        pl(c, [base_i, tip, base_o], lambda x, y, cyc=cyc, tipy=tipy: (FUR[1] if y < tipy + 6 else FUR[2]) if y >= cyc else None,
           "fur", part + "_ear")
        el(c, tip[0] - side * 0.3, tip[1] + 2.6, 2.6, 2.6, FUR, "fur", part + "_ear", bias=0.1)
        # back of the ear: darker rim on the inner edge + a peek of pink at the base
        tx, ty = ix_(tip[0]), iy_(tip[1] + 1.0)
        for j in range(1, 8):
            c.put(tx - side * (1 + j // 2), ty + j, FUR[2], "fur", part + "_ear")
        c.put(ix_(hx + side * rx * 0.36), iy_(hy - ry * 0.80), PINK_D, "detail", part + "_ear")
    yclip = Y(hy + ry * 0.3)
    el(c, hx, hy + ry * 0.35, rx + 0.6, ry * 0.55, FUR, "fur", part, clip=lambda x, y: y >= yclip, bias=0.06)
    el(c, hx, hy, rx, ry, FUR, "fur", part, bias=0.24)
    ix, iy = int(math.floor(X(hx))), iy_(hy)
    top = iy_(hy - ry) + 2
    # bold tabby stripes converging toward the nape (reads clearly from behind)
    stamp(c, ix, top, ["ss", "ss", "ss", "SS", "SS", "SS", ".S"], EM, "fur", part)
    for side in (-1, 1):
        for k, (ox, oy, ln) in enumerate(((5, 1, 6), (10, 3, 5), (15, 7, 4))):
            x0 = ix + (side * ox if side < 0 else side * ox + 1)
            for j in range(ln):
                xx = x0 - side * (j // 3)
                k2 = (xx, top + oy + j)
                if c.part.get(k2) == part and c.mat.get(k2) == "fur":
                    c.px[k2] = STRIPE if j < ln - 1 else STRIPE_D
    # nape fluff: lighter cheeks visible at the sides
    for side in (-1, 1):
        stamp(c, ix + side * (int(rx * K) - 2) - (2 if side > 0 else 0), iy + 3, ["sss", ".SS"] if side < 0 else ["sss", "SS."],
              EM, "fur", part, only_on=(part,))


# ---------------------------------------------------------------------------
# Legs / paws
# ---------------------------------------------------------------------------
def paw(c, x, foot_px, part, lifted=False, far=False):
    """x in model units, foot_px = pixel row of the paw bottom."""
    ramp = WHT_FAR if far else WHT
    ellipse(c, X(x), foot_px - 1.4, 3.4 * K, 1.9 * K, ramp, "white", part, bias=0.2)
    xi = int(math.floor(X(x)))
    if not lifted:
        c.put(xi - 1, foot_px, ramp[2], "white", part)
        c.put(xi + 2, foot_px, ramp[2], "white", part)
    else:
        for xx in (xi, xi + 1):
            c.put(xx, foot_px, PINK_D, "detail", part)
        c.put(xi - 1, foot_px, PINK, "detail", part)
        c.put(xi + 2, foot_px, PINK, "detail", part)
        c.put(xi - 2, foot_px - 1, PINK, "detail", part)
        c.put(xi + 3, foot_px - 1, PINK, "detail", part)


def leg_front(c, x, top_y, lift_px, part, far=False, r=3.0):
    foot = SOLE - lift_px
    ramp = FUR_FAR if far else FUR
    fy = (foot - SOLE) / K + 60.0  # model units
    cap(c, x, top_y, x, fy - 2.0, r, r - 0.3, ramp, "fur", part)
    sock(c, part, foot - 4, WHT_FAR if far else WHT)
    paw(c, x, foot, part, lifted=lift_px > 0, far=far)


# ---------------------------------------------------------------------------
# FRONT / BACK standing
# ---------------------------------------------------------------------------
def front_stand(eyes="open", bob=0, legs=None, tail_sway=0.0, breathe=0, ears="up", mouth="w",
                head_dy=0, head_dx=0):
    """bob/legs in pixels (bob<0 = up).  legs: FL/FR/HL/HR -> lift px."""
    legs = legs or {"FL": 0, "FR": 0, "HL": 0, "HR": 0}
    c = Cv()
    b = P(bob)
    bcy = BODY["cy"] + b
    sw = tail_sway
    t0 = 31.5 + BODY["rx"] * 0.7
    tl(c, [(t0, bcy + 2), (t0 + 6, bcy), (t0 + 10 + sw * 0.5, bcy - 5), (t0 + 10 + sw, bcy - 11)], 3.2, 2.7)
    for side, k, part in ((-1, "HL", "hl"), (1, "HR", "hr")):
        x = 31.5 + side * HIP_X
        el(c, x, bcy + 2.5, 4.4, 5.0, FUR_FAR, "fur", part, bias=-0.05)
        leg_front(c, x, bcy + 3, legs[k], part, far=True, r=2.9)
    el(c, 31.5, bcy, BODY["rx"], BODY["ry"] + breathe * P(1) * 0.5, FUR, "fur", "body")
    el(c, 31.5, bcy + 0.5, BODY["rx"] * 0.55, BODY["ry"], WHT, "white", "body", bias=0.2,
       clip=lambda x, y: c.part.get((x, y)) == "body")
    stamp(c, ix_(31.5 - BODY["rx"]) + 1, iy_(bcy) - 2, ["s.", "ss", ".S"], EM, "fur", "body", only_on=("body",))
    stamp(c, ix_(31.5 + BODY["rx"]) - 2, iy_(bcy) - 2, [".s", "ss", "S."], EM, "fur", "body", only_on=("body",))
    for side, k, part in ((-1, "FL", "fl"), (1, "FR", "fr")):
        leg_front(c, 31.5 + side * LEG_X, bcy + 1, legs[k], part)
    ct(c, ("fl", "fr"), ("body", "hl", "hr"), min_y=bcy + 3)
    ct(c, ("body",), ("hl", "hr"), min_y=bcy)
    ct(c, ("fl",), ("fr",), min_y=bcy + 3)
    ct(c, ("fr",), ("fl",), min_y=bcy + 3)
    front_head(c, dy=b + P(head_dy), dx=P(head_dx), eyes=eyes, ears=ears, mouth=mouth)
    ct(c, ("head",), ("body",), min_y=HEAD["cy"])
    xs = [31.5 + s * d for s, d, k in ((-1, HIP_X, "HL"), (1, HIP_X, "HR"), (-1, LEG_X, "FL"), (1, LEG_X, "FR")) if legs[k] == 0]
    return finish(c, shadows_at(xs))


def back_stand(bob=0, legs=None, tail_sway=0.0, breathe=0, ear_twitch=0):
    legs = legs or {"FL": 0, "FR": 0, "HL": 0, "HR": 0}
    c = Cv()
    b = P(bob)
    bcy = BODY["cy"] + b
    # far forelegs peek out wider than the rump
    for side, k, part in ((-1, "FL", "ffl"), (1, "FR", "ffr")):
        leg_front(c, 31.5 + side * HIP_X, bcy + 1, legs[k], part, far=True, r=2.8)
    el(c, 31.5, bcy + 0.5, BODY["rx"] + 0.8, BODY["ry"] + 0.6 + breathe * P(1) * 0.5, FUR, "fur", "body")
    # spine stripe + side bands
    for yy in range(iy_(bcy - BODY["ry"]), iy_(bcy + 2)):
        for xx in (int(CX), int(CX) + 1):
            if c.part.get((xx, yy)) == "body":
                c.px[(xx, yy)] = STRIPE if c.px[(xx, yy)] in (FUR[0], FUR[1]) else STRIPE_D
    sb(c, [(31.5 - 7.5, bcy - 1.5), (31.5 - 3.5, bcy - 2.5)], ("body",))
    sb(c, [(31.5 + 3.5, bcy - 2.5), (31.5 + 7.5, bcy - 1.5)], ("body",))
    sb(c, [(31.5 - 8, bcy + 1.5), (31.5 - 4.5, bcy + 0.5)], ("body",))
    sb(c, [(31.5 + 4.5, bcy + 0.5), (31.5 + 8, bcy + 1.5)], ("body",))
    for side, k, part in ((-1, "HL", "nhl"), (1, "HR", "nhr")):
        x = 31.5 + side * LEG_X
        leg_front(c, x, bcy + 3, legs[k], part, r=3.0)
    ct(c, ("nhl", "nhr"), ("ffl", "ffr", "body"), min_y=bcy + 3)
    ct(c, ("nhl",), ("nhr",), min_y=bcy + 3)
    ct(c, ("nhr",), ("nhl",), min_y=bcy + 3)
    back_head(c, dy=b, ear_twitch=ear_twitch)
    ct(c, ("head",), ("body",), min_y=HEAD["cy"])
    sw = tail_sway
    # tail is nearest the camera: from the rump, curling up to the right, white pom
    tl(c, [(31.5, bcy + 2), (37, bcy + 3), (42 + sw * 0.3, bcy + 1), (45 + sw * 0.7, bcy - 3), (45 + sw, bcy - 8)], 3.0, 2.6)
    ct(c, ("tail",), ("head", "body", "nhr", "nhl", "ffr", "head_ear"))
    xs = [31.5 + s * d for s, d, k in ((-1, HIP_X, "FL"), (1, HIP_X, "FR"), (-1, LEG_X, "HL"), (1, LEG_X, "HR")) if legs[k] == 0]
    return finish(c, shadows_at(xs))


# ---------------------------------------------------------------------------
# SIDE (facing right; left = flip in game)
# ---------------------------------------------------------------------------
def side_head(c, dx=0.0, dy=0.0, eyes="open", ears="up", mouth="closed", part="head"):
    hx, hy, rx, ry = SHEAD["cx"] + dx, SHEAD["cy"] + dy, SHEAD["rx"], SHEAD["ry"]
    kx, ky = rx / 10.6, ry / 9.6
    flat = ears == "flat"
    ft = (hx + (5.0 if not flat else 2.0) * kx, hy - (12.4 if not flat else 10.6) * ky)
    ycut = Y(ft[1] + 2)
    pl(c, [(hx + 1.0 * kx, hy - 7.0 * ky), ft, (hx + 8.5 * kx, hy - 5.5 * ky)],
       lambda x, y: FUR_FAR[1] if y >= ycut else None, "fur", part + "_far_ear")
    el(c, ft[0], ft[1] + 2.4, 2.3, 2.3, FUR_FAR, "fur", part + "_far_ear", bias=-0.2)
    nt = (hx - (2.8 if not flat else 6.0) * kx, hy - (13.4 if not flat else 11.2) * ky)
    ycut2, nty = Y(nt[1] + 2.4), Y(nt[1])
    pl(c, [(hx - 8.0 * kx, hy - 5.0 * ky), nt, (hx + 2.5 * kx, hy - 7.5 * ky)],
       lambda x, y: (FUR[1] if y < nty + 6 else FUR[2]) if y >= ycut2 else None, "fur", part + "_ear")
    el(c, nt[0], nt[1] + 2.6, 2.6, 2.6, FUR, "fur", part + "_ear", bias=0.1)
    yc = Y(hy + 2 * ky)
    el(c, hx - 2.0 * kx, hy + 3.5 * ky, 9.0 * kx, 5.8 * ky, FUR, "fur", part, clip=lambda x, y: y >= yc, bias=0.06)
    el(c, hx, hy, rx, ry, FUR, "fur", part, bias=0.14)
    # snout projects past the round skull (a profile, never an owl face)
    mx = hx + rx * 0.80
    el(c, mx, hy + 2.8 * ky, 3.3, 2.9, FUR, "fur", part, bias=0.1)
    yc2 = Y(hy + 3.4 * ky)
    el(c, mx - 0.6, hy + 4.6 * ky, 3.3, 2.2, WHT, "white", part, bias=0.25,
       clip=lambda x, y: y >= yc2 and c.part.get((x, y)) == part)
    yc3 = Y(hy + 5.2 * ky)
    el(c, hx + 6.0 * kx, hy + 6.2 * ky, 3.4 * kx, 2.4 * ky, WHT, "white", part, bias=0.2,
       clip=lambda x, y: y >= yc3 and c.part.get((x, y)) == part)
    # inner ear (near)
    tx, ty = ix_(nt[0]), iy_(nt[1] + 1.4)
    for j, row in enumerate(["pp", "ppP", "ppPP", "pPP"]):
        for i, ch in enumerate(row):
            c.put(tx - 1 + i, ty + j, EM[ch], "detail", part + "_ear")
    ix, iy = ix_(hx), iy_(hy)
    top = iy_(hy - ry) + 2
    stamp(c, ix - 4, top, ["s.s.s", "s.s.s", "S.S.S", "..S.."], EM, "fur", part, only_on=(part,))
    stamp(c, ix - int(round(9 * kx * K)), iy + 1, ["sss.", ".SSS"], EM, "fur", part, only_on=(part,))
    stamp(c, ix - int(round(8 * kx * K)), iy + 4, ["ss.", ".SS"], EM, "fur", part, only_on=(part,))
    st = SIDE_EYE[eyes]
    ex = ix_(hx + rx * 0.30) - 1
    ey = iy - 7
    stamp(c, ex, ey, st, EM, "detail", part)
    stamp(c, ex - 1, ey + len(st), ["bBBBb", ".bbb."], EM, "detail", part, only_on=(part,))
    ny = iy_(hy + 2.4 * ky)
    nx = max(x for (x, y), pp in c.part.items() if y == ny and pp == part)
    c.put(nx, ny, NOSE, "detail", part)
    c.put(nx - 1, ny, NOSE, "detail", part)
    c.put(nx, ny + 1, PINK_D, "detail", part)
    my = ny + 3
    mxp = max(x for (x, y), pp in c.part.items() if y == my and pp == part)
    if mouth == "closed":
        c.put(mxp - 1, my, MOUTH, "detail", part)
        c.put(mxp - 2, my, MOUTH, "detail", part)
        c.put(mxp - 3, my - 1, MOUTH, "detail", part)
    else:
        c.put(mxp - 1, my, MOUTH, "detail", part)
        c.put(mxp - 2, my, PINK_D, "detail", part)
        c.put(mxp - 1, my + 1, PINK_D, "detail", part)
        c.put(mxp - 3, my, MOUTH, "detail", part)
        c.put(mxp - 2, my + 1, MOUTH, "detail", part)


def side_leg(c, hip_x, hip_y, foot_x, lift_px, part, far=False, haunch=None):
    ramp = FUR_FAR if far else FUR
    wr = WHT_FAR if far else WHT
    foot = SOLE - lift_px
    fy = (foot - SOLE) / K + 60.0
    if haunch:
        el(c, hip_x, hip_y, haunch[0], haunch[1], ramp, "fur", part, bias=-0.02)
    cap(c, hip_x, hip_y, foot_x, fy - 2.0, 3.1, 2.6, ramp, "fur", part)
    sock(c, part, foot - 4, wr)
    ellipse(c, X(foot_x + 0.8), foot - 1.4, 3.2 * K, 1.8 * K, wr, "white", part, bias=0.2)
    fx = ix_(foot_x + 0.8)
    if lift_px > 0:
        for xx, col in ((fx - 2, PINK), (fx - 1, PINK_D), (fx, PINK_D), (fx + 1, PINK)):
            c.put(xx, foot, col, "detail", part)
    else:
        c.put(fx + 3, foot, wr[2], "white", part)


def side_stand(eyes="open", bob=0, feet=None, tail_pts=None, breathe=0, head_dy=0, head_dx=0,
               ears="up", mouth="closed", lean=0.0):
    """bob/head_dy in px; feet: NF/FF/NH/FH -> (dx model units, lift px)."""
    feet = feet or {"NF": (0, 0), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)}
    c = Cv()
    b = P(bob)
    bx, by, brx, bry = SBODY["cx"], SBODY["cy"] + b, SBODY["rx"], SBODY["ry"]
    t0 = bx - brx * 0.85
    tp = tail_pts or [(t0 + 1, by - 2), (t0 - 4, by - 7), (t0 - 5, by - 14), (t0 - 3, by - 19)]
    tl(c, tp, 3.2, 2.7)
    hx0, fx0 = bx - brx * 0.55, bx + brx * 0.55
    hk = (brx * 0.30, bry * 0.80)
    side_leg(c, hx0 + 2, by + 1, hx0 + 2.5 + feet["FH"][0], feet["FH"][1], "fh", far=True)
    side_leg(c, fx0 + 2 + lean, by + 1, fx0 + 2.5 + feet["FF"][0], feet["FF"][1], "ff", far=True)
    el(c, bx, by, brx, bry + breathe * P(1) * 0.5, FUR, "fur", "body")
    el(c, bx + brx * 0.72, by + 1.5, 3.8, bry * 0.75, WHT, "white", "body", bias=0.15,
       clip=lambda x, y: c.part.get((x, y)) == "body")
    for sx in (-0.5, -0.15, 0.2):
        x = bx + brx * sx
        sb(c, [(x, by - bry), (x - 1, by - bry * 0.4), (x - 1, by + 0.5)], ("body",))
    ct(c, ("body",), ("fh", "ff"), min_y=by + 1)
    side_leg(c, hx0, by + 1.5, hx0 + feet["NH"][0], feet["NH"][1], "nh", haunch=hk)
    side_leg(c, fx0 + lean, by + 1.5, fx0 + feet["NF"][0], feet["NF"][1], "nf")
    ct(c, ("nh",), ("body", "fh", "tail"), min_y=by + 3)
    ct(c, ("nf",), ("body", "ff"), min_y=by + 3)
    side_head(c, dx=P(head_dx), dy=b + P(head_dy), eyes=eyes, ears=ears, mouth=mouth)
    ct(c, ("head",), ("body",))
    xs = []
    for k, x0 in (("NF", fx0), ("FF", fx0 + 2.5), ("NH", hx0), ("FH", hx0 + 2.5)):
        if feet[k][1] == 0:
            xs.append(x0 + feet[k][0] + 0.8)
    return finish(c, shadows_at(xs))


# ---------------------------------------------------------------------------
# Gait — bouncy chibi trot: diagonal pairs, short airborne-free hop in the body
# ---------------------------------------------------------------------------
DUTY = 0.625
BOB = [0, -1, -2, -1, 0, -1, -2, -1]      # px, up = negative (little hop each step)


def gait(f, n=8, phase=0.0, amp=3.0, lift_h=3):
    t = (f / n + phase) % 1.0
    if t < DUTY:
        s = t / DUTY
        return amp * (1 - 2 * s), 0
    s = (t - DUTY) / (1 - DUTY)
    dx = -amp + 2 * amp * s
    return dx, max(1, int(round(math.sin(math.pi * min(1.0, s * 1.15)) * lift_h)))


def walk_side(f):
    feet = {}
    for k, ph in (("NF", 0.0), ("FH", 0.0), ("FF", 0.5), ("NH", 0.5)):
        dx, lift = gait(f, phase=ph, amp=3.0, lift_h=4)
        feet[k] = (dx, lift)
    by = BOB[f]
    sw = math.sin((f / 8) * 2 * math.pi - 1.0)
    bx, byc, brx = SBODY["cx"], SBODY["cy"] + P(by), SBODY["rx"]
    t0 = bx - brx * 0.85
    tp = [(t0 + 1, byc - 2), (t0 - 4, byc - 7 + sw * 0.5), (t0 - 5 - sw, byc - 14), (t0 - 3 - sw * 2, byc - 19 + sw * 0.6)]
    hd = [0, 0, 1, 0, 0, 0, 1, 0][f]   # head lags the body by a pixel at the top of the hop
    return side_stand(bob=by, feet=feet, tail_pts=tp, head_dy=hd)


def walk_front(f, back=False):
    legs = {}
    for k, ph in (("FL", 0.0), ("HR", 0.0), ("FR", 0.5), ("HL", 0.5)):
        _, lift = gait(f, phase=ph, amp=1, lift_h=4)
        legs[k] = lift
    by = BOB[f]
    sway = math.sin((f / 8) * 2 * math.pi) * 2.0
    if back:
        return back_stand(bob=by, legs=legs, tail_sway=sway)
    tilt = [0, 1, 1, 0, 0, -1, -1, 0][f]     # head sways a pixel toward the lifted side
    return front_stand(bob=by, legs=legs, tail_sway=sway, head_dx=tilt, head_dy=[0, 0, 1, 0, 0, 0, 1, 0][f])


# ---------------------------------------------------------------------------
# Idles (16 frames @ 6 fps)
# ---------------------------------------------------------------------------
IDLE_N = 16


def _breath(f):
    return 1 if (f // 4) % 2 == 1 else 0


def _blink(f):
    return {12: "half", 13: "shut", 14: "half"}.get(f, "open")


def idle_front(f):
    sway = math.sin(f / IDLE_N * 2 * math.pi) * 2.5
    return front_stand(eyes=_blink(f), breathe=_breath(f), tail_sway=sway, head_dy=_breath(f))


def idle_back(f):
    sway = math.sin(f / IDLE_N * 2 * math.pi) * 2.5
    return back_stand(breathe=_breath(f), tail_sway=sway, ear_twitch=1 if f in (10, 11) else 0)


def idle_side(f):
    sw = math.sin(f / IDLE_N * 2 * math.pi)
    bx, by, brx = SBODY["cx"], SBODY["cy"], SBODY["rx"]
    t0 = bx - brx * 0.85
    tp = [(t0 + 1, by - 2), (t0 - 4, by - 7 + sw * 0.6), (t0 - 5 - sw * 1.2, by - 14), (t0 - 3 - sw * 2.4, by - 19 + sw)]
    return side_stand(eyes=_blink(f), breathe=_breath(f), tail_pts=tp, head_dy=_breath(f))


# ---------------------------------------------------------------------------
# Sits
# ---------------------------------------------------------------------------
SIT = dict(cy=52.0, rx=10.0, ry=7.4, hdy=2.0)


def sit_front(eyes="open", tail_sway=0.0, head_dy=0, head_dx=0, mouth="w", ears="up", paws=(0, 0), paw_out=(0, 0)):
    c = Cv()
    bcy, brx, bry = SIT["cy"], SIT["rx"], SIT["ry"]
    sw = tail_sway
    tl(c, [(31.5 + brx - 4, bcy + 4), (31.5 + brx + 4, bcy + 3), (31.5 + brx + 7 + sw * 0.4, bcy - 2), (31.5 + brx + 7 + sw, bcy - 8)], 3.0, 2.5)
    for side, part in ((-1, "hl"), (1, "hr")):
        el(c, 31.5 + side * (brx - 2.5), bcy + 2.5, 6.0, 6.5, FUR, "fur", part, bias=-0.05)
    el(c, 31.5, bcy, brx, bry, FUR, "fur", "body")
    el(c, 31.5, bcy - 0.5, brx * 0.55, bry * 0.9, WHT, "white", "body", bias=0.15,
       clip=lambda x, y: c.part.get((x, y)) == "body")
    stamp(c, ix_(31.5 - brx) + 1, iy_(bcy) - 3, ["s.", "ss", ".S"], EM, "fur", "body", only_on=("body",))
    stamp(c, ix_(31.5 + brx) - 2, iy_(bcy) - 3, [".s", "ss", "S."], EM, "fur", "body", only_on=("body",))
    ct(c, ("body",), ("hl", "hr"), min_y=bcy)
    for side, part in ((-1, "hpl"), (1, "hpr")):
        paw(c, 31.5 + side * (brx + 0.5), SOLE, part)
    for i, (side, part) in enumerate(((-1, "fl"), (1, "fr"))):
        lift = paws[i]
        x0 = 31.5 + side * 3.6
        x1 = x0 + side * paw_out[i]
        foot = SOLE - lift
        fy = (foot - SOLE) / K + 60.0
        cap(c, x0, bcy + 1, x1, fy - 2, 2.9, 2.7, FUR, "fur", part)
        sock(c, part, foot - 5)
        paw(c, x1, foot, part, lifted=lift > 0)
    ct(c, ("fl", "fr"), ("body", "hl", "hr"), min_y=bcy + 1)
    ct(c, ("fl",), ("fr",))
    ct(c, ("fr",), ("fl",))
    front_head(c, dy=SIT["hdy"] + P(head_dy), dx=P(head_dx), eyes=eyes, mouth=mouth, ears=ears)
    ct(c, ("head",), ("body",), min_y=HEAD["cy"] + 2)
    return finish(c, [(X(31.5 - brx - 4), X(31.5 + brx + 4))])


def sit_back(tail_sway=0.0):
    c = Cv()
    bcy, brx, bry = SIT["cy"], SIT["rx"] + 1, SIT["ry"] + 0.6
    el(c, 31.5, bcy, brx, bry, FUR, "fur", "body")
    for yy in range(iy_(bcy - bry), iy_(bcy + 3)):
        for xx in (int(CX), int(CX) + 1):
            if c.part.get((xx, yy)) == "body":
                c.px[(xx, yy)] = STRIPE if c.px[(xx, yy)] in (FUR[0], FUR[1]) else STRIPE_D
    for dy in (-2.0, 1.0):
        sb(c, [(31.5 - 9, bcy + dy + 1), (31.5 - 4, bcy + dy)], ("body",))
        sb(c, [(31.5 + 4, bcy + dy), (31.5 + 9, bcy + dy + 1)], ("body",))
    for side in (-1, 1):
        paw(c, 31.5 + side * (brx - 1), SOLE, "paw%d" % side)
    sw = tail_sway
    tl(c, [(31.5 + 2, 56.5), (31.5 + 9, 57.5), (31.5 + 14 + sw * 0.4, 55), (31.5 + 15 + sw, 49)], 2.9, 2.5)
    ct(c, ("tail",), ("body", "paw1"))
    back_head(c, dy=SIT["hdy"] + 1)
    ct(c, ("head",), ("body",), min_y=HEAD["cy"] + 2)
    return finish(c, [(X(31.5 - brx - 3), X(31.5 + brx + 3))])


def sit_side(eyes="open", tail_sway=0.0):
    c = Cv()
    sw = tail_sway
    # tail along the floor behind, wrapping forward, white pom in front
    el(c, 28.5, 51.0, 8.0, 8.4, FUR, "fur", "body")
    el(c, 33.5, 50.0, 3.4, 6.0, WHT, "white", "body", bias=0.2, clip=lambda x, y: c.part.get((x, y)) == "body")
    el(c, 24.5, 54.5, 6.8, 5.6, FUR, "fur", "nh", bias=-0.04)
    sb(c, [(20, 51), (21, 54)], ("nh",))
    sb(c, [(25, 44), (24, 47)], ("body",))
    ct(c, ("nh",), ("body",))
    paw(c, 29.0, SOLE, "nhp")
    ct(c, ("nhp",), ("nh",))
    # tail wraps from behind the haunch along the floor, pom in front of the hind paw
    tl(c, [(17, 55), (16, 58.4), (22, 58.8), (30 + sw, 58.6)], 2.6, 2.3)
    ct(c, ("tail",), ("nh", "nhp", "body"))
    cap(c, 34.0, 50, 35.0, 58, 3.0, 2.7, FUR, "fur", "nf")
    sock(c, "nf", SOLE - 5)
    paw(c, 35.6, SOLE, "nf")
    ct(c, ("nf",), ("body", "nh", "nhp", "tail"), min_y=52)
    side_head(c, dx=-3.5, dy=1.5, eyes=eyes)
    ct(c, ("head",), ("body",))
    return finish(c, [(X(14), X(40))])


# ---------------------------------------------------------------------------
# Eat (side): head dips into the bowl ahead, chews
# ---------------------------------------------------------------------------
def eat_side(f):
    dips = [3, 7, 10, 9, 10, 9]
    chew = ["closed", "closed", "open", "closed", "open", "closed"]
    d = dips[f]
    bx, by, brx = SBODY["cx"], SBODY["cy"], SBODY["rx"]
    t0 = bx - brx * 0.85
    tp = [(t0 + 1, by - 2), (t0 - 4, by - 7 + (f % 2)), (t0 - 5, by - 14), (t0 - 3 - (f % 2), by - 19)]
    # front legs splay a touch forward, rump stays up
    return side_stand(feet={"NF": (1.5, 0), "FF": (1.5, 0), "NH": (0, 0), "FH": (0, 0)}, tail_pts=tp,
                      head_dy=int(round(d * K)), head_dx=int(round(d * 0.45 * K)),
                      eyes="half" if d >= 8 else "open", mouth=chew[f], lean=0.8)


# ---------------------------------------------------------------------------
# Happy / petted (front sit)
# ---------------------------------------------------------------------------
def happy_front(f):
    return sit_front(eyes="happy", tail_sway=[-2, 0, 2, 0][f % 4], head_dy=[0, -1, 0, -1][f % 4], mouth="open" if f % 2 else "w")


def petted_front(f):
    lean = [0, -1, -2, -1][f % 4]
    return sit_front(eyes="happy" if f % 4 in (1, 2) else "shut", head_dy=lean,
                     ears="flat" if f % 4 in (1, 2) else "up", tail_sway=[0, 1, 2, 1][f % 4])


# ---------------------------------------------------------------------------
# Play
# ---------------------------------------------------------------------------
def _tp(by, a, b, c2, d):
    bx, brx = SBODY["cx"], SBODY["rx"]
    t0 = bx - brx * 0.85
    yb = SBODY["cy"] + P(by)
    return [(t0 + 1 + a[0], yb - 2 + a[1]), (t0 - 4 + b[0], yb - 7 + b[1]), (t0 - 5 + c2[0], yb - 14 + c2[1]), (t0 - 3 + d[0], yb - 19 + d[1])]


def play_side(f):
    """crouch, wiggle, wiggle, spring, airborne, land, bat up, bat down."""
    if f in (0, 1, 2):
        wig = [0, 1, -1][f]
        return side_stand(bob=3, feet={"NF": (2.5, 0), "FF": (2.5, 0), "NH": (-1 + wig, 0), "FH": (-1 + wig, 0)},
                          tail_pts=_tp(3, (0, 0), (-1, 4 + wig), (-3, 9), (-6, 11 + wig)), head_dy=2)
    if f == 3:
        return side_stand(bob=-3, feet={"NF": (3, 4), "FF": (4, 5), "NH": (-2, 0), "FH": (-1, 0)},
                          tail_pts=_tp(-3, (0, 0), (-1, 3), (-3, 6), (-5, 7)), head_dy=-1)
    if f == 4:
        return side_stand(bob=-7, feet={"NF": (5, 6), "FF": (6, 7), "NH": (-4, 4), "FH": (-3, 3)},
                          tail_pts=_tp(-7, (0, 0), (-2, 4), (-5, 8), (-9, 10)), head_dy=-1, eyes="open")
    if f == 5:
        return side_stand(bob=2, feet={"NF": (3, 0), "FF": (4, 0), "NH": (-2, 0), "FH": (-1, 0)},
                          tail_pts=_tp(2, (0, 0), (0, 1), (-1, 2), (0, 2)), head_dy=1)
    if f == 6:
        return side_stand(bob=0, feet={"NF": (4, 9), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)},
                          tail_pts=_tp(0, (0, 0), (0, 0), (0, 0), (1, 0)), mouth="open")
    return side_stand(bob=1, feet={"NF": (6, 3), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)},
                      tail_pts=_tp(1, (0, 0), (0, 0), (1, 0), (2, 0)))


def play_front(f):
    ups = [(0, 0), (6, 0), (9, 0), (0, 6), (0, 9), (0, 0)]
    l, r = ups[f]
    return sit_front(eyes="open", tail_sway=[0, 2, 3, -2, -3, 0][f], head_dy=-1 if (l or r) else 0,
                     mouth="open" if f in (2, 4) else "w", paws=(l, r),
                     paw_out=(l * 0.35 / K, r * 0.35 / K))


# ---------------------------------------------------------------------------
# Sleep (curled, breathing)
# ---------------------------------------------------------------------------
def sleep_curl(f):
    br = [0, 1, 1, 0][f % 4]
    c = Cv()
    b = P(br)
    el(c, 33.0, 53.5 - b * 0.5, 14.0, 6.5 + b * 0.5, FUR, "fur", "body")
    for sx in (26, 31, 36, 41):
        sb(c, [(sx, 47.5 - b), (sx - 1, 50.5), (sx - 1, 53)], ("body",))
    tl(c, [(46, 56), (42, 59.2), (33, 59.6), (25, 59)], 2.7, 2.3)
    ct(c, ("tail",), ("body",))
    # big head resting on the left, eyes shut
    hx, hy = 20.0, 49.5 - b * 0.5
    rx, ry = 11.5, 9.5
    for side, tipx in ((-1, -8.5), (1, 6.5)):
        tip = (hx + tipx, hy - ry - 2.6)
        cyc = Y(tip[1] + 2.2)
        pl(c, [(hx + tipx - side * 1 - 3, hy - ry * 0.4), tip, (hx + tipx + 4 - side, hy - ry * 0.75)],
           lambda x, y, cyc=cyc: FUR[1 if side > 0 else 2] if y >= cyc else None, "fur", "head_ear")
        el(c, tip[0], tip[1] + 2.2, 2.2, 2.2, FUR, "fur", "head_ear", bias=0.1)
    tx, ty = ix_(hx + 6.5), iy_(hy - ry - 1.2)
    for j, row in enumerate(["pp", "pPp", "pPp"]):
        for i, ch in enumerate(row):
            c.put(tx - 1 + i, ty + j, EM[ch], "detail", "head_ear")
    el(c, hx, hy, rx, ry, FUR, "fur", "head", bias=0.04)
    el(c, hx, hy + ry * 0.55, 4.2, 2.8, WHT, "white", "head", bias=0.25)
    ix, iy = int(math.floor(X(hx))), iy_(hy)
    top = iy_(hy - ry) + 2
    stamp(c, ix, top, ["ss", "ss", "SS"], EM, "fur", "head")
    stamp(c, ix - 4, top + 1, ["s", "s", "S"], EM, "fur", "head")
    stamp(c, ix + 5, top + 1, ["s", "s", "S"], EM, "fur", "head")
    ex = int(round(rx * 0.42 * K))
    stamp(c, ix - ex - 5, iy - 4, EYE_SHUT[8:], EM, "detail", "head")
    stamp(c, ix + ex - 5, iy - 4, EYE_SHUT[8:], EM, "detail", "head")
    for sx in (ix - ex - 5, ix + ex - 1):
        stamp(c, sx, iy + 2, ["bBBb", ".bb."], EM, "detail", "head", only_on=("head",))
    ny = iy_(hy + ry * 0.55) - 2
    c.put(ix, ny, NOSE, "detail", "head")
    c.put(ix + 1, ny, NOSE, "detail", "head")
    paw(c, hx + 5, SOLE - 1, "paw")
    paw(c, hx - 4, SOLE - 1, "paw2")
    ct(c, ("head",), ("body", "tail"))
    ct(c, ("paw", "paw2"), ("head", "body", "tail"))
    # "z" bubble is a game FX, not baked here
    return finish(c, [(X(8), X(48))])


# ---------------------------------------------------------------------------
# Animation table: name -> (frames, fps, loop)
# ---------------------------------------------------------------------------
def build_all():
    A = {}
    A["walk_side"] = ([walk_side(i) for i in range(8)], 10, True)
    A["walk_down"] = ([walk_front(i) for i in range(8)], 10, True)
    A["walk_up"] = ([walk_front(i, back=True) for i in range(8)], 10, True)
    A["idle_down"] = ([idle_front(i) for i in range(IDLE_N)], 6, True)
    A["idle_up"] = ([idle_back(i) for i in range(IDLE_N)], 6, True)
    A["idle_side"] = ([idle_side(i) for i in range(IDLE_N)], 6, True)
    A["sit"] = ([sit_front(tail_sway=s) for s in (0, 1, 2, 1)], 3, True)
    A["sit_blink"] = ([sit_front(eyes="half"), sit_front(eyes="shut"), sit_front(eyes="half")], 10, False)
    A["sit_side"] = ([sit_side(tail_sway=s) for s in (0, 1, 2, 1)], 3, True)
    A["sit_up"] = ([sit_back(tail_sway=s) for s in (0, 1, 2, 1)], 3, True)
    A["eat_side"] = ([eat_side(i) for i in range(6)], 7, False)
    A["happy"] = ([happy_front(i) for i in range(4)], 6, True)
    A["call"] = ([petted_front(i) for i in range(4)], 5, True)
    A["play_side"] = ([play_side(i) for i in range(8)], 11, False)
    A["play_down"] = ([play_front(i) for i in range(6)], 10, False)
    A["sleep"] = ([sleep_curl(i) for i in range(4)], 2, True)
    return A


if __name__ == "__main__":
    import sys
    A = build_all()
    sc = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    rows = list(A.items())
    maxn = max(len(v[0]) for _, v in rows)
    sheet = Image.new("RGBA", (maxn * (W * sc + 4) + 4, len(rows) * (H * sc + 4) + 4), (250, 240, 226, 255))
    for r, (name, (frames, fps, loop)) in enumerate(rows):
        for i, fr in enumerate(frames):
            im = fr.image(sc)
            sheet.paste(im, (4 + i * (W * sc + 4), 4 + r * (H * sc + 4)), im)
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cat_art_sheet.png"
    sheet.save(out)
    print("wrote", out, sheet.size)
