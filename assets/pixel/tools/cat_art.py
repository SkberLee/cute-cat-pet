#!/usr/bin/env python3
"""治愈猫 v0.3 cat sprite set — original, hand-tuned layered pixel art.

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

W = H = 64
SOLE = 60          # bottom row of a planted paw
CX = 31.5          # front/back centre line (pixels 31|32 mirror)

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
            elif only_below and y < 40:
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
# Hand-authored face stamps
# ---------------------------------------------------------------------------
EYEMAP = {"e": EYE_D, "g": EYE, "G": EYE_L, "h": EYE_H, "m": MOUTH, "n": NOSE,
          "p": PINK, "P": PINK_D, "b": BLUSH, "s": STRIPE, "S": STRIPE_D,
          "w": WHT[0], "W": WHT[2], "o": OUT}

EYE_OPEN = [
    ".eee.",
    "ehhee",
    "ehgge",
    "egggG",
    "egGGe",
    ".eee.",
]
EYE_OPEN_R = [  # right eye: same light, highlight still top-left
    ".eee.",
    "ehhee",
    "ehgge",
    "Gggge",
    "eGGge",
    ".eee.",
]
EYE_HALF = [
    ".....",
    ".....",
    ".eee.",
    "eggge",
    "eGGGe",
    ".eee.",
]
EYE_SHUT = [  # gentle closed (blink / sleep) — downward arc
    ".....",
    ".....",
    ".....",
    "e...e",
    ".eee.",
    ".....",
]
EYE_HAPPY = [  # ^ ^
    ".....",
    ".....",
    ".eee.",
    "e...e",
    ".....",
    ".....",
]
SIDE_EYE = {
    "open": [".ee.", "ehge", "eggG", "eGGe", ".ee."],
    "half": ["....", "....", "eeee", "egGe", ".ee."],
    "shut": ["....", "....", "....", "e..e", ".ee."],
    "happy": ["....", ".ee.", "e..e", "....", "...."],
}

# ---------------------------------------------------------------------------
# FRONT model sheet
# ---------------------------------------------------------------------------
HEAD_F = dict(cx=CX, cy=25.0, rx=14.2, ry=11.4)


def _mx(x):
    return 63 - x


def front_head(c, dy=0, eyes="open", dx=0, ears="up", blush=True, mouth="w", part="head"):
    hx, hy = HEAD_F["cx"] + dx, HEAD_F["cy"] + dy
    # ears (behind head edge but painted first so head overlaps base)
    for side in (-1, 1):
        if ears == "up":
            tip = (hx + side * 10.0, hy - 15.0)
            base_o = (hx + side * 14.0, hy - 4.0)
            base_i = (hx + side * 3.5, hy - 9.5)
        else:  # flattened / leaning back
            tip = (hx + side * 12.5, hy - 13.0)
            base_o = (hx + side * 14.3, hy - 3.0)
            base_i = (hx + side * 4.5, hy - 9.5)
        pts = [base_i, tip, base_o]

        def ear_col(x, y, side=side, tip=tip):
            # lit on the upper edge, deeper toward the base
            return FUR[1] if y < tip[1] + 6 else FUR[2]
        poly(c, pts, ear_col, "fur", part + "_ear")
        # inner ear (pink), hand-placed relative to tip
        ix = int(round(tip[0])) - (1 if side > 0 else 0)
        iy = int(round(tip[1])) + 3
        inner = ["p.", "pp", "Pp", "Ppp"] if side < 0 else [".p", "pp", "pP", "ppP"]
        for j, row in enumerate(inner):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                xx = ix + (i - (len(row) - 1) if side > 0 else i) + (0 if side < 0 else 0)
                if side < 0:
                    xx = ix + i + 0
                else:
                    xx = ix - (len(row) - 1) + i + 1
                c.put(xx, iy + j, EYEMAP[ch], "detail", part + "_ear")
    ellipse(c, hx, hy, HEAD_F["rx"], HEAD_F["ry"], FUR, "fur", part, bias=0.04)
    # cheek fluff: slight wider bottom
    ellipse(c, hx, hy + 4.0, HEAD_F["rx"] + 0.6, 6.0, FUR, "fur", part, bias=0.0,
            clip=lambda x, y: y >= hy + 3)
    # white muzzle / chin
    ellipse(c, hx, hy + 6.4, 5.4, 3.7, WHT, "white", part, bias=0.3)
    ix, iy = int(math.floor(hx)), int(round(hy))
    # tabby M on forehead
    stamp(c, ix, iy - 10, ["ss", "ss", "SS"], EYEMAP, "fur", part)
    stamp(c, ix - 3, iy - 9, ["s", "s", "S"], EYEMAP, "fur", part)
    stamp(c, ix + 4, iy - 9, ["s", "s", "S"], EYEMAP, "fur", part)
    stamp(c, ix - 6, iy - 8, ["s", "S"], EYEMAP, "fur", part)
    stamp(c, ix + 7, iy - 8, ["s", "S"], EYEMAP, "fur", part)
    # cheek stripes
    stamp(c, ix - 13, iy + 1, ["ss.", ".SS"], EYEMAP, "fur", part, only_on=(part,))
    stamp(c, ix + 12, iy + 1, [".ss", "SS."], EYEMAP, "fur", part, only_on=(part,))
    # eyes
    el, er = {"open": (EYE_OPEN, EYE_OPEN_R), "half": (EYE_HALF, EYE_HALF),
              "shut": (EYE_SHUT, EYE_SHUT), "happy": (EYE_HAPPY, EYE_HAPPY)}[eyes]
    stamp(c, ix - 8, iy - 2, el, EYEMAP, "detail", part)
    stamp(c, ix + 5, iy - 2, er, EYEMAP, "detail", part)
    if blush:
        for bx in (ix - 10, ix - 9, ix + 10, ix + 11):
            c.put(bx, iy + 4, BLUSH, "detail", part)
    # nose + mouth (ω)
    c.put(ix, iy + 4, NOSE, "detail", part)
    c.put(ix + 1, iy + 4, NOSE, "detail", part)
    if mouth == "w":
        for (x, y) in ((ix - 2, iy + 5), (ix, iy + 5), (ix + 1, iy + 5), (ix + 3, iy + 5),
                       (ix - 1, iy + 6), (ix + 2, iy + 6)):
            c.put(x, y, MOUTH, "detail", part)
    elif mouth == "open":  # chewing / meow
        for (x, y) in ((ix, iy + 5), (ix + 1, iy + 5), (ix - 1, iy + 6), (ix + 2, iy + 6)):
            c.put(x, y, MOUTH, "detail", part)
        c.put(ix, iy + 6, PINK_D, "detail", part)
        c.put(ix + 1, iy + 6, PINK_D, "detail", part)
        c.put(ix, iy + 7, MOUTH, "detail", part)
        c.put(ix + 1, iy + 7, MOUTH, "detail", part)


def back_head(c, dy=0, dx=0, ear_twitch=0, part="head"):
    hx, hy = HEAD_F["cx"] + dx, HEAD_F["cy"] + dy
    for side in (-1, 1):
        tw = ear_twitch if side > 0 else 0
        tip = (hx + side * (10.0 + tw), hy - 15.0 + abs(tw))
        pts = [(hx + side * 3.5, hy - 9.5), tip, (hx + side * 14.0, hy - 4.0)]
        poly(c, pts, lambda x, y, t=tip: FUR[1] if y < t[1] + 4 else FUR[2], "fur", part + "_ear")
        # back of ear: a soft darker rim on the inner edge, pink peeking at the base
        ix = int(round(tip[0]))
        for j in range(2, 7):
            xx = ix - side * (j // 2)
            c.put(xx, int(round(tip[1])) + j, FUR[2], "fur", part + "_ear")
        c.put(int(round(hx + side * 6)), int(round(hy - 9)), PINK_D, "detail", part + "_ear")
    ellipse(c, hx, hy, HEAD_F["rx"], HEAD_F["ry"], FUR, "fur", part, bias=0.04)
    ellipse(c, hx, hy + 4.0, HEAD_F["rx"] + 0.6, 6.0, FUR, "fur", part,
            clip=lambda x, y: y >= hy + 3)
    ix, iy = int(math.floor(hx)), int(round(hy))
    # back-of-head tabby stripes running to the nape
    stamp(c, ix - 1, iy - 10, ["ss", "ss", "Ss", "Ss", ".S", ".S"], EYEMAP, "fur", part)
    stamp(c, ix + 1, iy - 10, ["ss", "ss", "sS", "sS", "S.", "S."], EYEMAP, "fur", part)
    stamp(c, ix - 6, iy - 8, ["s.", "s.", "Ss", ".S"], EYEMAP, "fur", part)
    stamp(c, ix + 6, iy - 8, [".s", ".s", "sS", "S."], EYEMAP, "fur", part)
    stamp(c, ix - 11, iy - 2, ["ss", ".S"], EYEMAP, "fur", part)
    stamp(c, ix + 11, iy - 2, ["ss", "S."], EYEMAP, "fur", part)


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
# Paws / legs
# ---------------------------------------------------------------------------
def paw_front(c, x, foot_y, part, lifted=False, far=False):
    ramp = WHT_FAR if far else WHT
    ellipse(c, x, foot_y - 1.0, 3.3, 1.9, ramp, "white", part, bias=0.2)
    if not lifted:
        # toe gaps on the planted paw
        c.put(int(math.floor(x)) - 1, foot_y, ramp[2], "white", part)
        c.put(int(math.floor(x)) + 2, foot_y, ramp[2], "white", part)
    else:
        xi = int(math.floor(x))
        for xx in (xi, xi + 1):
            c.put(xx, foot_y, PINK_D, "detail", part)
        c.put(xi - 1, foot_y, PINK, "detail", part)
        c.put(xi + 2, foot_y, PINK, "detail", part)


def foreleg_front(c, x, top_y, lift, part, far=False):
    """Straight leg from inside the chest to the paw; lifted = shorter, bent."""
    foot = SOLE - lift
    ramp = FUR_FAR if far else FUR
    if lift > 0:
        kx = x + (0.8 if x > CX else -0.8)
        capsule(c, x, top_y, kx, foot - 4, 3.0, 2.7, ramp, "fur", part)
        capsule(c, kx, foot - 4, x, foot - 2, 2.7, 2.6, ramp, "fur", part)
    else:
        capsule(c, x, top_y, x, foot - 2, 3.0, 2.6, ramp, "fur", part)
    sock(c, part, foot - 3, WHT_FAR if far else WHT)
    paw_front(c, x, foot, part, lifted=lift > 0, far=far)


def hindleg_front(c, x, lift, part, far=False):
    """Haunch + short shin peeking beside the chest (front view)."""
    foot = SOLE - lift
    ramp = FUR_FAR if far else FUR
    hip_y = 47.5
    ellipse(c, x, hip_y, 4.6, 6.2, ramp, "fur", part, bias=-0.05)
    capsule(c, x + (0.6 if x > CX else -0.6), hip_y + 3, x, foot - 2, 2.8, 2.5, ramp, "fur", part)
    sock(c, part, foot - 3, WHT_FAR if far else WHT)
    paw_front(c, x, foot, part, lifted=lift > 0, far=far)


# ---------------------------------------------------------------------------
# FRONT body
# ---------------------------------------------------------------------------
def front_stand(eyes="open", bob=0, legs=None, tail_sway=0.0, breathe=0, ears="up",
                head_dx=0, mouth="w", blush=True, hide_tail=False):
    """legs: dict FL/FR/HL/HR -> lift px (0 planted)."""
    legs = legs or {"FL": 0, "FR": 0, "HL": 0, "HR": 0}
    c = Cv()
    by = bob
    # tail behind everything: rises from behind the right hip and curls up
    if not hide_tail:
        sw = tail_sway
        tail(c, [(40, 46 + by), (47 + sw * 0.4, 42 + by), (50 + sw, 34 + by), (48 + sw * 1.4, 27 + by)])
    # hind haunches (behind chest)
    hindleg_front(c, CX - 9.5, legs["HL"], "hl", far=True)
    hindleg_front(c, CX + 9.5, legs["HR"], "hr", far=True)
    # torso / chest
    ellipse(c, CX, 42.5 + by, 10.0, 9.0 + breathe * 0.3, FUR, "fur", "body", bias=0.0)
    # white bib
    ellipse(c, CX, 43.0 + by, 5.6, 9.0 + breathe * 0.3, WHT, "white", "body", bias=0.2,
            clip=lambda x, y: (x, y) in c.px and c.part.get((x, y)) == "body")
    # side stripes on the torso
    stamp(c, int(CX) - 9, 40 + by, ["s.", "ss", ".S"], EYEMAP, "fur", "body", only_on=("body",))
    stamp(c, int(CX) + 9, 40 + by, [".s", "ss", "S."], EYEMAP, "fur", "body", only_on=("body",))
    # forelegs
    foreleg_front(c, CX - 4.5, 44 + by, legs["FL"], "fl")
    foreleg_front(c, CX + 4.5, 44 + by, legs["FR"], "fr")
    contour(c, ("fl", "fr"), ("body", "hl", "hr"), min_y=48 + by)
    contour(c, ("body",), ("hl", "hr"), min_y=44 + by)
    contour(c, ("fl",), ("fr",), min_y=46)
    contour(c, ("fr",), ("fl",), min_y=46)
    # head on top
    front_head(c, dy=by, eyes=eyes, ears=ears, dx=head_dx, mouth=mouth, blush=blush)
    contour(c, ("head",), ("body",), min_y=30 + by)
    shadows = []
    for k, x in (("HL", CX - 9.5), ("FL", CX - 4.5), ("FR", CX + 4.5), ("HR", CX + 9.5)):
        if legs[k] == 0:
            shadows.append((x - 3, x + 3))
    return finish(c, shadows)


def back_stand(bob=0, legs=None, tail_sway=0.0, breathe=0, ear_twitch=0):
    legs = legs or {"FL": 0, "FR": 0, "HL": 0, "HR": 0}
    c = Cv()
    by = bob
    # far forelegs peek beside the rump (behind)
    hindleg_front(c, CX - 9.0, legs["FL"], "ffl", far=True)
    hindleg_front(c, CX + 9.0, legs["FR"], "ffr", far=True)
    # back / rump: wider, rounder than the chest
    ellipse(c, CX, 43.0 + by, 11.0, 9.0 + breathe * 0.3, FUR, "fur", "body", bias=0.0)
    # spine stripe + side stripes
    for yy in range(35 + by, 45 + by):
        for xx in (31, 32):
            k = (xx, yy)
            if c.part.get(k) == "body":
                c.px[k] = STRIPE if c.px[k] in (FUR[0], FUR[1]) else STRIPE_D
    for sy, w in ((40, 3),):
        stripe_band(c, [(CX - 3.5 - w, sy + by + 1), (CX - 3.5, sy + by)], ("body",))
        stripe_band(c, [(CX + 3.5, sy + by), (CX + 3.5 + w, sy + by + 1)], ("body",))
    # near hind legs (closest to camera in back view)
    for side, k in ((-1, "HL"), (1, "HR")):
        x = CX + side * 4.8
        lift = legs[k]
        foot = SOLE - lift
        capsule(c, x, 47 + by, x - side * 0.4, foot - 2, 3.1, 2.7, FUR, "fur", "n" + k.lower(),
                clip=lambda xx, yy, by=by: yy >= 50 + by or (xx, yy) not in c.px)
        sock(c, "n" + k.lower(), foot - 3)
        paw_front(c, x, foot, "n" + k.lower(), lifted=lift > 0)
    contour(c, ("nhl", "nhr"), ("ffl", "ffr"), min_y=53)
    contour(c, ("nhl",), ("nhr",), min_y=53)
    contour(c, ("nhr",), ("nhl",), min_y=53)
    back_head(c, dy=by, ear_twitch=ear_twitch)
    contour(c, ("head",), ("body",), min_y=30 + by)
    # tail is nearest the camera: rises from the rump and curls up to the right
    sw = tail_sway
    tail(c, [(32, 50 + by), (39, 50 + by), (45 + sw * 0.3, 47 + by), (48 + sw * 0.7, 41 + by), (48 + sw, 35 + by)],
         r0=2.7, r1=2.0)
    contour(c, ("tail",), ("head", "body", "nhr", "nhl", "head_ear"), min_y=0)
    shadows = []
    for k, x in (("FL", CX - 9.0), ("HL", CX - 4.8), ("HR", CX + 4.8), ("FR", CX + 9.0)):
        if legs[k] == 0:
            shadows.append((x - 3, x + 3))
    return finish(c, shadows)


# ---------------------------------------------------------------------------
# SIDE model sheet (facing right; left = flip_h in game)
# ---------------------------------------------------------------------------
HEAD_S = dict(cx=44.0, cy=26.5, rx=10.6, ry=9.6)
BODY_S = dict(cx=29.0, cy=41.0, rx=15.0, ry=8.0)


def side_head(c, dx=0, dy=0, eyes="open", ears="up", mouth="closed", part="head"):
    hx, hy = HEAD_S["cx"] + dx, HEAD_S["cy"] + dy
    # far ear (behind, darker), near ear
    far_tip = (hx + 5.5, hy - 13.0) if ears == "up" else (hx + 1.5, hy - 11.0)
    poly(c, [(hx + 1.0, hy - 7.0), far_tip, (hx + 8.5, hy - 5.5)],
         lambda x, y: FUR_FAR[2], "fur", part + "_far_ear")
    near_tip = (hx - 2.5, hy - 14.0) if ears == "up" else (hx - 6.5, hy - 11.0)
    poly(c, [(hx - 8.0, hy - 5.0), near_tip, (hx + 2.5, hy - 7.5)],
         lambda x, y, t=near_tip: FUR[1] if y < t[1] + 5 else FUR[2], "fur", part + "_ear")
    ellipse(c, hx, hy, HEAD_S["rx"], HEAD_S["ry"], FUR, "fur", part, bias=0.04)
    # cheek fluff toward the back-bottom
    ellipse(c, hx - 2.0, hy + 3.5, 9.0, 5.8, FUR, "fur", part, clip=lambda x, y: y >= hy + 2)
    # snout / muzzle bump forward
    ellipse(c, hx + 8.2, hy + 3.2, 4.4, 3.6, WHT, "white", part, bias=0.25)
    ellipse(c, hx + 4.5, hy + 5.5, 4.8, 3.0, WHT, "white", part, bias=0.2,
            clip=lambda x, y: y >= hy + 4)
    ix, iy = int(round(hx)), int(round(hy))
    # inner ear pink on near ear
    nt = (int(round(near_tip[0])), int(round(near_tip[1])))
    for j, row in enumerate(["p", "pp", "pP", "ppP"]):
        for i, ch in enumerate(row):
            c.put(nt[0] + i, nt[1] + 3 + j, EYEMAP[ch], "detail", part + "_ear")
    # stripes on head: forehead + cheek
    stamp(c, ix - 3, iy - 9, ["s.s.s", "s.s.S", "S.S.."], EYEMAP, "fur", part, only_on=(part,))
    stamp(c, ix - 9, iy + 1, ["ss.", ".SS"], EYEMAP, "fur", part, only_on=(part,))
    # eye
    stamp(c, ix + 3, iy - 3, SIDE_EYE[eyes], EYEMAP, "detail", part)
    # blush
    c.put(ix + 2, iy + 3, BLUSH, "detail", part)
    c.put(ix + 3, iy + 3, BLUSH, "detail", part)
    # nose at snout tip + mouth
    c.put(ix + 12, iy + 1, NOSE, "detail", part)
    c.put(ix + 12, iy + 2, NOSE, "detail", part)
    if mouth == "closed":
        c.put(ix + 11, iy + 4, MOUTH, "detail", part)
        c.put(ix + 10, iy + 5, MOUTH, "detail", part)
    else:  # open / chew
        c.put(ix + 11, iy + 4, MOUTH, "detail", part)
        c.put(ix + 10, iy + 5, PINK_D, "detail", part)
        c.put(ix + 11, iy + 5, PINK_D, "detail", part)
        c.put(ix + 9, iy + 5, MOUTH, "detail", part)


def side_fore(c, hip_x, hip_y, foot_x, lift, part, far=False):
    ramp = FUR_FAR if far else FUR
    foot = SOLE - lift
    if lift > 0:
        # bent wrist: shoulder -> elbow -> paw tucked slightly back
        ex, ey = (hip_x + foot_x) / 2 + 1.5, (hip_y + foot) / 2
        capsule(c, hip_x, hip_y, ex, ey, 3.2, 2.7, ramp, "fur", part)
        capsule(c, ex, ey, foot_x, foot - 2, 2.7, 2.5, ramp, "fur", part)
    else:
        capsule(c, hip_x, hip_y, foot_x, foot - 2, 3.2, 2.5, ramp, "fur", part)
    sock(c, part, foot - 3, WHT_FAR if far else WHT)
    wr = WHT_FAR if far else WHT
    ellipse(c, foot_x + 0.8, foot - 1.0, 3.2, 1.8, wr, "white", part, bias=0.2)
    if lift > 0:
        c.put(int(round(foot_x)), foot, PINK_D, "detail", part)
        c.put(int(round(foot_x)) - 1, foot, PINK, "detail", part)
        c.put(int(round(foot_x)) + 1, foot, PINK, "detail", part)
    else:
        c.put(int(round(foot_x)) + 2, foot, wr[2], "white", part)


def side_hind(c, hip_x, hip_y, foot_x, lift, part, far=False):
    ramp = FUR_FAR if far else FUR
    foot = SOLE - lift
    # thigh (big rounded haunch)
    ellipse(c, hip_x, hip_y, 6.2, 7.2, ramp, "fur", part, bias=-0.02)
    # hock sits behind the paw — cat hind leg shape
    hock_x = foot_x - 2.6 - lift * 0.5
    hock_y = foot - 6 + lift * 0.3
    capsule(c, hip_x - 1.0, hip_y + 3.0, hock_x, hock_y, 3.4, 2.6, ramp, "fur", part)
    capsule(c, hock_x, hock_y, foot_x, foot - 2, 2.6, 2.4, ramp, "fur", part)
    sock(c, part, foot - 3, WHT_FAR if far else WHT)
    wr = WHT_FAR if far else WHT
    ellipse(c, foot_x + 0.8, foot - 1.0, 3.2, 1.8, wr, "white", part, bias=0.2)
    if lift > 0:
        c.put(int(round(foot_x)), foot, PINK_D, "detail", part)
        c.put(int(round(foot_x)) - 1, foot, PINK, "detail", part)
        c.put(int(round(foot_x)) + 1, foot, PINK, "detail", part)
    else:
        c.put(int(round(foot_x)) + 2, foot, wr[2], "white", part)


def side_stand(eyes="open", bob=0, feet=None, tail_pts=None, breathe=0, head_dy=0, ears="up",
               mouth="closed", head_dx=0):
    """feet: dict NF/FF/NH/FH -> (foot_x offset from neutral, lift)."""
    feet = feet or {"NF": (0, 0), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)}
    c = Cv()
    by = bob
    bx, byc = BODY_S["cx"], BODY_S["cy"] + by
    # neutral foot x: fore under shoulder, hind under hip
    NFX, FFX, NHX, FHX = 38.0, 41.0, 18.5, 21.5
    tp = tail_pts or [(15, 38 + by), (9, 33 + by), (7, 26 + by), (9, 20 + by)]
    tail(c, tp, r0=2.7, r1=2.0)
    # far legs first (darker ramp)
    side_hind(c, 22.0, 43.0 + by, FHX + feet["FH"][0], feet["FH"][1], "fh", far=True)
    side_fore(c, 40.0, 41.0 + by, FFX + feet["FF"][0], feet["FF"][1], "ff", far=True)
    # body
    ellipse(c, bx, byc, BODY_S["rx"], BODY_S["ry"] + breathe * 0.3, FUR, "fur", "body")
    # chest is white under the neck
    ellipse(c, bx + 11.5, byc + 2.0, 4.2, 5.2, WHT, "white", "body", bias=0.15,
            clip=lambda x, y: c.part.get((x, y)) == "body")
    # belly lighter underside
    for k in list(c.px):
        if c.part.get(k) == "body" and c.mat.get(k) == "fur" and k[1] >= byc + 5 and 22 <= k[0] <= 38:
            c.px[k] = FUR[2]
    # back stripes
    for sx in (20, 25, 30, 35):
        stripe_band(c, [(sx, byc - 8), (sx - 1, byc - 4), (sx - 1, byc - 1)], ("body",))
    contour(c, ("body",), ("fh", "ff"), min_y=byc + 2)
    # near legs
    side_hind(c, 19.5, 43.5 + by, NHX + feet["NH"][0], feet["NH"][1], "nh")
    side_fore(c, 37.5, 42.0 + by, NFX + feet["NF"][0], feet["NF"][1], "nf")
    contour(c, ("nh",), ("body", "fh", "tail"), min_y=byc + 5)
    contour(c, ("nf",), ("body", "ff"), min_y=byc + 5)
    side_head(c, dx=head_dx, dy=by + head_dy, eyes=eyes, ears=ears, mouth=mouth)
    contour(c, ("head",), ("body",), min_y=0)
    shadows = []
    for k, x0 in (("NF", NFX), ("FF", FFX), ("NH", NHX), ("FH", FHX)):
        if feet[k][1] == 0:
            fx = x0 + feet[k][0] + 0.8
            shadows.append((fx - 3, fx + 3))
    return finish(c, shadows)


# ---------------------------------------------------------------------------
# Gait
# ---------------------------------------------------------------------------
DUTY = 0.625


def gait(f, n=8, phase=0.0, amp=4.5, lift_h=3.0):
    t = (f / n + phase) % 1.0
    if t < DUTY:
        s = t / DUTY
        return amp * (1 - 2 * s), 0
    s = (t - DUTY) / (1 - DUTY) + (1 / 6)
    s = min(s, 1.0)
    dx = -amp + 2 * amp * ((t - DUTY) / (1 - DUTY) + 1 / 6)
    return min(amp, dx), int(round(math.sin(math.pi * min(1.0, s)) * lift_h))


BOB = [0, 1, 1, 0, 0, 1, 1, 0]


def walk_side(f):
    feet = {}
    for k, ph in (("NF", 0.0), ("FH", 0.0), ("FF", 0.5), ("NH", 0.5)):
        dx, lift = gait(f, phase=ph, amp=4.5, lift_h=3.0)
        feet[k] = (round(dx), lift)
    by = BOB[f]
    sw = math.sin((f / 8) * 2 * math.pi - 0.9)
    tp = [(15, 38 + by), (9, 33 + by + round(sw)), (6 - round(sw), 26 + by), (8 - round(sw * 1.5), 20 + by + round(sw))]
    return side_stand(bob=by, feet=feet, tail_pts=tp)


def walk_front(f, back=False):
    legs = {}
    for k, ph in (("FL", 0.0), ("HR", 0.0), ("FR", 0.5), ("HL", 0.5)):
        _, lift = gait(f, phase=ph, amp=1, lift_h=3.0)
        legs[k] = lift
    by = BOB[f]
    sway = round(math.sin((f / 8) * 2 * math.pi) * 1.5)
    if back:
        return back_stand(bob=by, legs=legs, tail_sway=sway)
    return front_stand(bob=by, legs=legs, tail_sway=sway)


# ---------------------------------------------------------------------------
# Idles (16 frames @ 6 fps): breathe, tail sway, blink / ear twitch
# ---------------------------------------------------------------------------
IDLE_N = 16


def _breath(f):
    return 1 if (f // 4) % 2 == 1 else 0


def idle_front(f):
    eyes = "open"
    if f == 12:
        eyes = "half"
    elif f == 13:
        eyes = "shut"
    elif f == 14:
        eyes = "half"
    sway = round(math.sin(f / IDLE_N * 2 * math.pi) * 2)
    return front_stand(eyes=eyes, breathe=_breath(f), tail_sway=sway)


def idle_back(f):
    sway = round(math.sin(f / IDLE_N * 2 * math.pi) * 2)
    tw = 1 if f in (10, 11) else 0
    return back_stand(breathe=_breath(f), tail_sway=sway, ear_twitch=tw)


def idle_side(f):
    eyes = "open"
    if f == 12:
        eyes = "half"
    elif f == 13:
        eyes = "shut"
    elif f == 14:
        eyes = "half"
    sw = math.sin(f / IDLE_N * 2 * math.pi)
    tp = [(15, 38), (9, 33 + round(sw)), (6 - round(sw), 26), (8 - round(sw * 2), 20 + round(sw))]
    return side_stand(eyes=eyes, breathe=_breath(f), tail_pts=tp)


# ---------------------------------------------------------------------------
# Sit loaf (front / side / back)
# ---------------------------------------------------------------------------
def sit_front(eyes="open", tail_sway=0, head_dy=0, head_dx=0, mouth="w", ears="up", blush=True,
              paw_up=0):
    c = Cv()
    # tail wraps around the front of the loaf (drawn after body)
    # haunches
    ellipse(c, CX - 9.0, 51.0, 6.5, 8.0, FUR, "fur", "hl", bias=-0.05)
    ellipse(c, CX + 9.0, 51.0, 6.5, 8.0, FUR, "fur", "hr", bias=-0.05)
    # round sitting body
    ellipse(c, CX, 47.0, 11.5, 11.0, FUR, "fur", "body")
    ellipse(c, CX, 46.0, 6.2, 8.5, WHT, "white", "body", bias=0.15,
            clip=lambda x, y: c.part.get((x, y)) == "body")
    stamp(c, int(CX) - 11, 44, ["s.", "ss", ".S"], EYEMAP, "fur", "body", only_on=("body",))
    stamp(c, int(CX) + 11, 44, [".s", "ss", "S."], EYEMAP, "fur", "body", only_on=("body",))
    contour(c, ("body",), ("hl", "hr"), min_y=46)
    # hind paws peeking out at the sides
    for side, part in ((-1, "hpl"), (1, "hpr")):
        ellipse(c, CX + side * 11.5, SOLE - 1.0, 3.6, 1.9, WHT, "white", part, bias=0.2)
    # tail curls from the right haunch along the floor in front of the hind paw
    sw = tail_sway
    tail(c, [(43, 53), (46, 57), (43 + sw * 0.3, 60), (37 + sw * 0.6, 60)], r0=2.4, r1=2.0)
    contour(c, ("tail",), ("hr", "body", "hpr"))
    # front legs: short straight columns between haunches into white paws
    for side, part in ((-1, "fl"), (1, "fr")):
        x = CX + side * 3.6
        lift = paw_up if side > 0 else 0
        capsule(c, x, 49, x, SOLE - 2 - lift, 2.8, 2.6, FUR, "fur", part)
        sock(c, part, SOLE - 4 - lift)
        paw_front(c, x, SOLE - lift, part, lifted=lift > 0)
    contour(c, ("fl", "fr"), ("body",), min_y=52)
    contour(c, ("fl",), ("fr",))
    contour(c, ("fr",), ("fl",))
    front_head(c, dy=4 + head_dy, eyes=eyes, dx=head_dx, mouth=mouth, ears=ears, blush=blush)
    contour(c, ("head",), ("body",), min_y=34)
    return finish(c, [(CX - 15, CX + 15)])


def sit_back(tail_sway=0):
    c = Cv()
    ellipse(c, CX, 47.5, 12.5, 12.5, FUR, "fur", "body")
    for yy in range(37, 50):
        for xx in (31, 32):
            if c.part.get((xx, yy)) == "body":
                c.px[(xx, yy)] = STRIPE if c.px[(xx, yy)] in (FUR[0], FUR[1]) else STRIPE_D
    stripe_band(c, [(CX - 9.5, 43), (CX - 6.5, 42)], ("body",))
    stripe_band(c, [(CX + 6.5, 42), (CX + 9.5, 43)], ("body",))
    for side in (-1, 1):
        ellipse(c, CX + side * 10.5, SOLE - 1.0, 3.6, 1.9, WHT, "white", "paw%d" % side, bias=0.2)
    sw = tail_sway
    tail(c, [(36, 57), (44, 59), (50 + sw * 0.5, 56), (52 + sw, 49)], r0=2.6, r1=2.0)
    contour(c, ("tail",), ("body",))
    back_head(c, dy=6)
    contour(c, ("head",), ("body",), min_y=34)
    return finish(c, [(CX - 15, CX + 15)])


def sit_side(eyes="open", tail_sway=0):
    c = Cv()
    sw = tail_sway
    # upright body (chest forward), haunch behind
    ellipse(c, 28.5, 47.0, 9.5, 12.0, FUR, "fur", "body")
    ellipse(c, 34.5, 45.0, 4.0, 7.0, WHT, "white", "body", bias=0.2,
            clip=lambda x, y: c.part.get((x, y)) == "body")
    # near haunch: big round thigh resting on the floor
    ellipse(c, 23.0, 51.5, 8.5, 8.0, FUR, "fur", "nh", bias=-0.04)
    stripe_band(c, [(17, 47), (18, 50)], ("nh",))
    contour(c, ("nh",), ("body",))
    # hind paw flat on the floor in front of the haunch
    ellipse(c, 28.5, SOLE - 1.0, 4.6, 1.9, WHT, "white", "nhp", bias=0.2)
    contour(c, ("nhp",), ("nh",))
    # tail along the floor, wrapping toward the front
    tail(c, [(15, 55), (13, 59), (20, 60), (27 + sw, 60)], r0=2.3, r1=1.9)
    contour(c, ("tail",), ("nh", "nhp", "body"))
    # straight front leg
    capsule(c, 35.0, 47, 36.0, SOLE - 2, 3.0, 2.6, FUR, "fur", "nf")
    sock(c, "nf", SOLE - 4)
    ellipse(c, 37.0, SOLE - 1.0, 3.3, 1.9, WHT, "white", "nf", bias=0.2)
    contour(c, ("nf",), ("body", "nh", "nhp", "tail"), min_y=50)
    side_head(c, dx=-3, dy=5, eyes=eyes)
    contour(c, ("head",), ("body",))
    return finish(c, [(14, 41)])


# ---------------------------------------------------------------------------
# Eat (side view, head down into the bowl, chewing)
# ---------------------------------------------------------------------------
def eat_side(f):
    """6 frames: lower(0,1) chew(2..5). Bowl is a separate prop in game."""
    c = Cv()
    dips = [6, 12, 16, 15, 16, 15]
    chew = ["closed", "closed", "open", "closed", "open", "closed"]
    dip = dips[f]
    tp = [(15, 38), (9, 34 + (f % 2)), (6, 28), (7 - (f % 2), 22)]
    tail(c, tp, r0=2.7, r1=2.0)
    side_hind(c, 22.0, 43.0, 21.5, 0, "fh", far=True)
    side_fore(c, 40.0, 42.0, 41.0, 0, "ff", far=True)
    ellipse(c, 29.0, 41.5, 15.0, 8.0, FUR, "fur", "body")
    ellipse(c, 40.5, 43.5, 4.2, 5.0, WHT, "white", "body", bias=0.15,
            clip=lambda x, y: c.part.get((x, y)) == "body")
    for sx in (20, 25, 30, 35):
        stripe_band(c, [(sx, 34), (sx - 1, 37), (sx - 1, 40)], ("body",))
    contour(c, ("body",), ("fh", "ff"), min_y=43)
    side_hind(c, 19.5, 43.5, 18.5, 0, "nh")
    side_fore(c, 38.0, 43.0, 39.0, 0, "nf")
    contour(c, ("nh",), ("body", "fh", "tail"), min_y=46)
    contour(c, ("nf",), ("body", "ff"), min_y=46)
    # neck stretches down/forward, head lowered toward the bowl
    hdx = 1 + int(dip * 0.2)
    capsule(c, 39, 37, HEAD_S["cx"] + hdx - 3, HEAD_S["cy"] + dip - 2, 5.2, 5.0, FUR, "fur", "neck")
    side_head(c, dx=hdx, dy=dip, eyes="half" if dip > 10 else "open",
              ears="up", mouth=chew[f])
    contour(c, ("head",), ("body", "neck", "nf", "ff"))
    return finish(c, [(15, 22), (18, 25), (35, 43), (38, 45)])


# ---------------------------------------------------------------------------
# Happy / petted (front, sitting) — eyes close, lean into the hand
# ---------------------------------------------------------------------------
def happy_front(f):
    sway = [-2, 0, 2, 0][f % 4]
    return sit_front(eyes="happy", tail_sway=sway, head_dy=[0, -1, 0, -1][f % 4], mouth="w")


def petted_front(f):
    # leans head up into the stroking hand, ears relaxed back, eyes shut
    lean = [0, -1, -2, -1][f % 4]
    return sit_front(eyes="happy" if f % 4 in (1, 2) else "shut", head_dy=lean,
                     ears="flat" if f % 4 in (1, 2) else "up", tail_sway=[0, 1, 2, 1][f % 4])


# ---------------------------------------------------------------------------
# Play (side pounce / bat) and front bat
# ---------------------------------------------------------------------------
def play_side(f):
    """8 frames: crouch, wiggle, wiggle, leap, stretch, land, bat up, bat down."""
    if f in (0, 1, 2):
        # crouch: body low, rump up, tail flick
        wig = [0, 1, -1][f]
        c = side_stand(bob=3, feet={"NF": (2, 0), "FF": (2, 0), "NH": (-1 + wig, 0), "FH": (-1 + wig, 0)},
                       tail_pts=[(15, 40), (9, 40 + wig), (4, 38), (2, 34 + wig)], head_dy=1, ears="up")
        return c
    if f == 3:  # spring
        return side_stand(bob=-3, feet={"NF": (4, 4), "FF": (5, 5), "NH": (-3, 0), "FH": (-2, 0)},
                          tail_pts=[(15, 35), (9, 33), (5, 30), (3, 26)], head_dy=-1)
    if f == 4:  # airborne stretch
        return side_stand(bob=-5, feet={"NF": (6, 7), "FF": (7, 8), "NH": (-5, 4), "FH": (-4, 3)},
                          tail_pts=[(14, 33), (8, 32), (3, 31), (0, 29)], head_dy=-1)
    if f == 5:  # land
        return side_stand(bob=2, feet={"NF": (3, 0), "FF": (4, 0), "NH": (-2, 0), "FH": (-1, 0)},
                          tail_pts=[(15, 39), (9, 36), (6, 30), (7, 25)])
    if f == 6:  # bat up
        return side_stand(bob=0, feet={"NF": (4, 8), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)},
                          tail_pts=[(15, 38), (9, 34), (6, 27), (8, 21)], ears="up")
    return side_stand(bob=1, feet={"NF": (6, 2), "FF": (0, 0), "NH": (0, 0), "FH": (0, 0)},
                      tail_pts=[(15, 38), (9, 33), (7, 26), (10, 21)])


def play_front(f):
    """6 frames: sits up and bats with alternating paws."""
    ups = [(0, 0), (6, 0), (9, 0), (0, 6), (0, 9), (0, 0)]
    l, r = ups[f]
    c = Cv()
    ellipse(c, CX - 9.0, 51.0, 6.5, 8.0, FUR, "fur", "hl", bias=-0.05)
    ellipse(c, CX + 9.0, 51.0, 6.5, 8.0, FUR, "fur", "hr", bias=-0.05)
    ellipse(c, CX, 46.0, 11.0, 11.5, FUR, "fur", "body")
    ellipse(c, CX, 45.0, 6.0, 8.5, WHT, "white", "body", bias=0.15,
            clip=lambda x, y: c.part.get((x, y)) == "body")
    contour(c, ("body",), ("hl", "hr"), min_y=46)
    for side in (-1, 1):
        ellipse(c, CX + side * 11.5, SOLE - 1.0, 3.6, 1.9, WHT, "white", "hp%d" % side, bias=0.2)
    sw = [0, 2, 3, -2, -3, 0][f]
    tail(c, [(42, 56), (47, 55), (51 + sw * 0.4, 49), (50 + sw, 42)], r0=2.4, r1=2.0)
    for side, lift, part in ((-1, l, "fl"), (1, r, "fr")):
        x = CX + side * (3.6 + lift * 0.85)
        foot = SOLE - lift
        if lift:
            capsule(c, CX + side * 3.6, 45, x, foot - 2, 2.9, 2.6, FUR, "fur", part)
        else:
            capsule(c, x, 49, x, foot - 2, 2.8, 2.6, FUR, "fur", part)
        sock(c, part, foot - 4)
        paw_front(c, x, foot, part, lifted=lift > 0)
    contour(c, ("fl", "fr"), ("body", "hl", "hr"), min_y=40)
    front_head(c, dy=3 - (1 if (l or r) else 0), eyes="open", mouth="open" if f in (2, 4) else "w")
    contour(c, ("head",), ("body",), min_y=33)
    return finish(c, [(CX - 15, CX + 15)])


# ---------------------------------------------------------------------------
# Sleep (curled side-on ball, breathing)
# ---------------------------------------------------------------------------
def sleep_curl(f):
    br = [0, 1, 1, 0][f % 4]
    c = Cv()
    ellipse(c, 31.0, 52.0 - br * 0.5, 17.0, 8.5 + br * 0.5, FUR, "fur", "body")
    for sx in (20, 26, 32, 38):
        stripe_band(c, [(sx, 44 - br), (sx - 1, 48), (sx - 1, 51)], ("body",))
    # tail wrapped around the front
    tail(c, [(46, 56), (40, 59), (30, 60), (20, 59)], r0=2.5, r1=2.0)
    contour(c, ("tail",), ("body",))
    # head tucked on the left resting on paws
    hx, hy = 19.0, 50.0 - br * 0.5
    poly(c, [(hx - 6, hy - 5), (hx - 7.5, hy - 12), (hx - 1, hy - 7)], lambda x, y: FUR[2], "fur", "head_ear")
    poly(c, [(hx + 1, hy - 7), (hx + 5, hy - 13), (hx + 8, hy - 6)], lambda x, y: FUR[1], "fur", "head_ear")
    c.put(int(hx) + 5, int(hy) - 9, PINK, "detail", "head_ear")
    c.put(int(hx) + 5, int(hy) - 8, PINK, "detail", "head_ear")
    ellipse(c, hx, hy, 9.5, 7.5, FUR, "fur", "head", bias=0.04)
    ellipse(c, hx, hy + 3.8, 5.5, 3.2, WHT, "white", "head", bias=0.25)
    ix, iy = int(hx), int(round(hy))
    stamp(c, ix - 1, iy - 7, ["ss", "Ss"], EYEMAP, "fur", "head")
    stamp(c, ix - 6, iy - 2, EYE_SHUT, EYEMAP, "detail", "head")
    stamp(c, ix + 2, iy - 2, EYE_SHUT, EYEMAP, "detail", "head")
    c.put(ix + 1, iy + 2, NOSE, "detail", "head")
    c.put(ix + 2, iy + 2, NOSE, "detail", "head")
    c.put(ix - 6, iy + 2, BLUSH, "detail", "head")
    c.put(ix + 8, iy + 2, BLUSH, "detail", "head")
    # front paws under chin
    ellipse(c, hx + 4, 58.5, 3.4, 1.9, WHT, "white", "paw", bias=0.2)
    ellipse(c, hx - 3, 58.5, 3.4, 1.9, WHT, "white", "paw2", bias=0.2)
    contour(c, ("head",), ("body", "tail"))
    contour(c, ("paw", "paw2"), ("head", "body", "tail"))
    return finish(c, [(12, 50)])


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
    sc = 4
    rows = []
    for name, (frames, fps, loop) in A.items():
        rows.append((name, frames))
    maxn = max(len(f) for _, f in rows)
    sheet = Image.new("RGBA", (maxn * (W * sc + 4) + 4, len(rows) * (H * sc + 4) + 4), (60, 54, 66, 255))
    for r, (name, frames) in enumerate(rows):
        for i, fr in enumerate(frames):
            sheet.paste(fr.image(sc), (4 + i * (W * sc + 4), 4 + r * (H * sc + 4)), fr.image(sc))
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cat_art_sheet.png"
    sheet.save(out)
    print("wrote", out, sheet.size)
