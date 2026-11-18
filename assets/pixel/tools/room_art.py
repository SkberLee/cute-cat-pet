#!/usr/bin/env python3
"""v0.3 cozy room dressing, low food dishes and a clean HUD frame (original art)."""
from __future__ import annotations

import math
from PIL import Image

OUT = (104, 54, 36, 255)
OUT_SOFT = (150, 104, 80, 255)


class Px:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.im.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c if len(c) == 4 else (*c, 255)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def ellipse(self, cx, cy, rx, ry, c, clip=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    if clip is None or clip(x, y):
                        self.put(x, y, c)

    def outline(self, col=OUT):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.p[x, y][3]:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.p[nx, ny][3] == 255:
                        add.append((x, y))
                        break
        for x, y in add:
            self.p[x, y] = col
        return self


# ---------------------------------------------------------------- window
def window():
    """56x46 window with sky, cloud, mullions and tie-back curtains."""
    g = Px(56, 46)
    frame, frame_d, frame_l = (240, 228, 214), (206, 186, 168), (255, 248, 238)
    sky_t, sky_b = (150, 206, 236), (196, 230, 246)
    # sky panes
    for y in range(5, 36):
        t = (y - 5) / 30
        col = tuple(int(sky_t[i] + (sky_b[i] - sky_t[i]) * t) for i in range(3))
        # banded (no dithering noise): quantize to 3 steps
        col = sky_t if t < 0.35 else ((172, 218, 242) if t < 0.7 else sky_b)
        g.hline(9, 46, y, col)
    # distant hills + cloud
    inside = lambda x, y: 9 <= x <= 46 and y <= 35
    g.ellipse(18, 38, 13, 6, (176, 214, 160), clip=inside)
    g.ellipse(38, 39, 14, 6, (150, 198, 140), clip=inside)
    for y in range(31, 36):
        for x in range(9, 47):
            pass
    g.ellipse(22, 13, 5, 2.4, (255, 255, 255))
    g.ellipse(27, 12, 4, 3, (255, 255, 255))
    g.ellipse(31, 13.5, 3.5, 2, (250, 252, 255))
    g.hline(19, 33, 15, (226, 238, 248))
    # frame
    g.rect(7, 3, 48, 4, frame)
    g.rect(7, 36, 48, 38, frame)
    g.rect(7, 3, 8, 38, frame)
    g.rect(47, 3, 48, 38, frame)
    g.vline(27, 5, 35, frame)
    g.vline(28, 5, 35, frame_d)
    g.hline(9, 46, 20, frame)
    g.hline(9, 46, 21, frame_d)
    g.hline(7, 48, 3, frame_l)
    g.hline(6, 49, 38, frame_d)
    g.hline(5, 50, 39, frame)   # sill
    g.hline(5, 50, 40, frame_d)
    # curtains (light; tinted by theme in game)
    cur, cur_d, cur_l = (250, 236, 238), (226, 200, 206), (255, 248, 248)
    for side in (0, 1):
        for y in range(1, 44):
            # gathered at the tie-back around y=26
            if y < 26:
                wdt = 6 + int((y / 26) * 2)
            else:
                wdt = 5 + int(((y - 26) / 18) * 4)
            if y in (25, 26, 27):
                wdt = 4
            for i in range(wdt):
                x = i if side == 0 else 55 - i
                col = cur
                if i == wdt - 1:
                    col = cur_d
                elif i % 3 == 1:
                    col = cur_l
                g.put(x, y, col)
        tie = (230, 160, 170)
        for y in (25, 26, 27):
            for i in range(5):
                g.put(i if side == 0 else 55 - i, y, tie)
    # curtain rod
    g.hline(0, 55, 0, (168, 120, 86))
    g.put(0, 1, (168, 120, 86))
    g.put(55, 1, (168, 120, 86))
    return g.outline().im


# ---------------------------------------------------------------- shelf
def shelf():
    """52x30 wall shelf with books, a tiny pot plant and a jar."""
    g = Px(52, 30)
    wood, wood_d, wood_l = (196, 138, 92), (160, 106, 68), (220, 168, 118)
    g.rect(1, 22, 50, 24, wood)
    g.hline(1, 50, 22, wood_l)
    g.hline(1, 50, 25, wood_d)
    for bx in (6, 44):
        g.rect(bx, 26, bx + 1, 28, wood_d)
    # books
    books = [(4, 9, (232, 132, 140)), (8, 7, (128, 180, 196)), (11, 10, (246, 206, 120)),
             (15, 8, (170, 150, 214))]
    for x, h, col in books:
        g.rect(x, 21 - h, x + 2, 21, col)
        dark = tuple(max(0, v - 40) for v in col)
        g.vline(x + 2, 21 - h, 21, dark)
        g.hline(x, x + 2, 21 - h + 2, (255, 248, 236))
    # leaning book
    for i in range(8):
        g.rect(19 + i // 3, 21 - i, 21 + i // 3, 21 - i, (140, 196, 160))
    # pot plant
    pot, pot_d = (214, 120, 92), (180, 92, 70)
    g.rect(30, 16, 37, 21, pot)
    g.vline(37, 16, 21, pot_d)
    g.hline(29, 38, 15, pot_d)
    leaf, leaf_d, leaf_l = (120, 186, 120), (84, 150, 96), (168, 216, 150)
    for (cx, cy, rx, ry) in ((33.5, 10, 3, 4), (29, 12, 3, 2.2), (38, 11.5, 3, 2.2), (34, 6, 2, 2.5)):
        g.ellipse(cx, cy, rx, ry, leaf)
    g.vline(33, 8, 14, leaf_d)
    g.put(32, 8, leaf_l)
    g.put(29, 11, leaf_l)
    g.put(38, 10, leaf_l)
    # jar of treats
    g.rect(42, 13, 47, 21, (236, 236, 244))
    g.rect(42, 11, 47, 12, (232, 132, 140))
    g.rect(43, 15, 46, 20, (204, 150, 100))
    g.put(43, 14, (255, 255, 255))
    return g.outline().im


# ---------------------------------------------------------------- picture
def picture():
    """26x22 framed painting: a fish and a heart on mint."""
    g = Px(26, 22)
    fr, fr_d, fr_l = (210, 160, 104), (172, 124, 78), (236, 196, 140)
    g.rect(1, 1, 24, 20, fr)
    g.hline(1, 24, 1, fr_l)
    g.hline(1, 24, 20, fr_d)
    g.vline(24, 1, 20, fr_d)
    g.rect(4, 4, 21, 17, (204, 236, 214))
    g.rect(4, 13, 21, 17, (176, 220, 196))
    # fish
    g.ellipse(11, 10, 4, 2.4, (96, 176, 216))
    g.put(15, 9, (96, 176, 216)); g.put(16, 8, (96, 176, 216)); g.put(16, 11, (96, 176, 216)); g.put(15, 11, (96, 176, 216))
    g.put(16, 9, (96, 176, 216)); g.put(16, 10, (96, 176, 216))
    g.put(9, 9, (40, 40, 56))
    g.hline(10, 12, 11, (170, 222, 240))
    # heart
    for (x, y) in ((17, 6), (19, 6), (16, 7), (17, 7), (18, 7), (19, 7), (20, 7), (17, 8), (18, 8), (19, 8), (18, 9)):
        g.put(x, y, (240, 128, 150))
    # hanging string
    return g.outline().im


# ---------------------------------------------------------------- clock
def clock():
    g = Px(18, 18)
    g.ellipse(8.5, 8.5, 7.5, 7.5, (236, 168, 120))
    g.ellipse(8.5, 8.5, 6, 6, (255, 250, 240))
    for a in range(12):
        ang = a / 12 * 2 * math.pi
        x = int(round(8.5 + math.sin(ang) * 5))
        y = int(round(8.5 - math.cos(ang) * 5))
        if a % 3 == 0:
            g.put(x, y, (150, 110, 90))
    g.vline(8, 4, 8, (90, 60, 50))
    g.hline(8, 11, 9, (90, 60, 50))
    g.put(8, 9, (232, 112, 132))
    return g.outline().im


# ---------------------------------------------------------------- floor plant
def plant():
    """28x44 potted monstera for the floor corner."""
    g = Px(28, 44)
    pot, pot_d, pot_l = (240, 232, 220), (206, 192, 178), (255, 252, 246)
    for y in range(30, 43):
        inset = (y - 30) // 4
        g.hline(6 + inset, 21 - inset, y, pot)
        g.put(21 - inset, y, pot_d)
        g.put(6 + inset, y, pot_l)
    g.hline(5, 22, 29, pot_d)
    g.hline(5, 22, 30, pot_l)
    g.hline(8, 19, 34, (232, 150, 160))
    leaf, leaf_d, leaf_l = (104, 176, 112), (70, 136, 86), (150, 206, 140)
    leaves = [(14, 12, 6, 5), (7, 18, 5.5, 4), (21, 17, 5.5, 4), (10, 7, 4, 3.5), (19, 8, 4, 3.5), (14, 22, 5, 4)]
    for cx, cy, rx, ry in leaves:
        g.ellipse(cx, cy, rx, ry, leaf)
        g.ellipse(cx - 1, cy - 1, rx * 0.5, ry * 0.45, leaf_l)
    # monstera splits + stems
    for cx, cy, rx, ry in leaves:
        g.put(int(cx), int(cy) + 1, leaf_d)
        g.put(int(cx + rx * 0.6), int(cy), (0, 0, 0, 0))
    g.vline(14, 18, 29, leaf_d)
    g.vline(13, 22, 29, leaf_d)
    return g.outline().im


# ---------------------------------------------------------------- dishes
def dish(kind):
    """32x32 low bowl/plate with food; origin is centred bottom-ish (sprite offset -12)."""
    g = Px(32, 32)
    bowl, bowl_d, bowl_l = (244, 150, 168), (214, 110, 136), (255, 200, 210)
    if kind == "milk":
        bowl, bowl_d, bowl_l = (150, 196, 230), (110, 160, 200), (196, 226, 246)
    # bowl body (low, wide)
    for y in range(20, 27):
        half = 12 - (y - 20) // 2
        g.hline(16 - half, 15 + half, y, bowl)
        g.put(15 + half, y, bowl_d)
        g.put(16 - half, y, bowl_l)
    g.hline(5, 26, 23, bowl_l)
    # rim ellipse
    g.ellipse(15.5, 19.5, 12, 3.0, bowl_l)
    g.ellipse(15.5, 19.5, 10, 2.0, (255, 236, 240) if kind != "milk" else (236, 246, 255))
    if kind == "kibble":
        for (x, y) in ((10, 18), (13, 17), (16, 18), (19, 17), (21, 18), (12, 19), (15, 19), (18, 19), (14, 16), (17, 16)):
            g.put(x, y, (168, 102, 54)); g.put(x + 1, y, (196, 134, 74))
    elif kind == "can":
        g.ellipse(15.5, 18.0, 8, 2.6, (210, 150, 90))
        g.ellipse(14.5, 17.2, 4, 1.4, (232, 182, 120))
        g.put(19, 18, (186, 124, 70)); g.put(11, 18, (186, 124, 70))
    elif kind == "fish":
        g.ellipse(15.5, 17, 7, 2.2, (96, 186, 220))
        g.put(23, 16, (96, 186, 220)); g.put(24, 15, (96, 186, 220)); g.put(24, 18, (96, 186, 220))
        g.put(23, 17, (96, 186, 220)); g.put(24, 16, (96, 186, 220)); g.put(24, 17, (96, 186, 220))
        g.put(11, 16, (40, 40, 56))
        g.hline(13, 18, 18, (170, 222, 240))
    elif kind == "milk":
        g.ellipse(15.5, 19.3, 9, 1.6, (255, 255, 255))
    return g.outline().im


# ---------------------------------------------------------------- HUD frame
def panel_frame():
    """96x48 9-slice panel: soft frame only (no baked-in bars — those were the HUD ghost)."""
    g = Px(96, 48)
    edge, fill, hi = (226, 170, 172), (255, 249, 244), (255, 255, 255)
    for y in range(48):
        for x in range(96):
            # rounded corners radius 5
            dx = min(x, 95 - x)
            dy = min(y, 47 - y)
            if dx < 5 and dy < 5 and (5 - dx) ** 2 + (5 - dy) ** 2 > 26:
                continue
            g.put(x, y, fill)
    # border 2px
    for y in range(48):
        for x in range(96):
            if g.p[x, y][3] == 0:
                continue
            border = False
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x + 2, y), (x - 2, y), (x, y + 2), (x, y - 2)):
                if not (0 <= nx < 96 and 0 <= ny < 48) or g.p[nx, ny][3] == 0:
                    border = True
                    break
            if border:
                g.put(x, y, edge)
    g.hline(6, 89, 3, hi)
    return g.im


ASSETS = {
    "room/window": window,
    "room/shelf": shelf,
    "room/picture": picture,
    "room/clock": clock,
    "room/plant": plant,
    "food/dish_fish": lambda: dish("fish"),
    "food/dish_kibble": lambda: dish("kibble"),
    "food/dish_can": lambda: dish("can"),
    "food/dish_milk": lambda: dish("milk"),
    "ui/panel_mood": panel_frame,
}


# ---------------------------------------------------------------- v0.3.1 room pass
def wallpaper():
    """32x32 seamless wallpaper: warm peach with soft stripes and tiny flowers."""
    g = Px(32, 32)
    base, band, dot, dot_c = (252, 236, 224), (247, 226, 212), (240, 196, 190), (250, 224, 170)
    for y in range(32):
        for x in range(32):
            g.put(x, y, band if (x % 16) in (6, 7, 8, 9) else base)
    for (cx, cy) in ((15, 7), (31, 23)):
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            g.put((cx + dx) % 32, (cy + dy) % 32, dot)
        g.put(cx % 32, cy % 32, dot_c)
    for (cx, cy) in ((4, 18), (20, 2)):
        g.put(cx, cy, (244, 212, 200))
    return g.im


def wainscot():
    """32x32 tile placed at wall y 40..72: wallpaper on top, chair rail, panel, baseboard."""
    g = Px(32, 32)
    rail_l, rail, rail_d = (236, 206, 170), (214, 178, 140), (176, 136, 102)
    pan, pan_l, pan_d = (246, 228, 206), (252, 240, 224), (220, 196, 170)
    for y in range(9, 32):
        for x in range(32):
            g.put(x, y, pan)
    g.hline(0, 31, 9, rail_l)
    g.hline(0, 31, 10, rail)
    g.hline(0, 31, 11, rail)
    g.hline(0, 31, 12, rail_d)
    # recessed panel (bevel)
    g.hline(3, 28, 15, pan_d)
    g.vline(3, 15, 24, pan_d)
    g.hline(3, 28, 25, pan_l)
    g.vline(28, 15, 25, pan_l)
    # baseboard
    g.hline(0, 31, 27, rail_l)
    g.rect(0, 28, 31, 30, rail)
    g.hline(0, 31, 31, rail_d)
    return g.im


def floor32():
    """Calm honey wood: long planks (few joints), soft seams, very sparse grain."""
    g = Px(32, 32)
    cols = [(228, 190, 142), (224, 185, 137), (229, 192, 144), (225, 187, 139)]
    seam, grain, joint = (210, 168, 120), (220, 180, 132), (208, 165, 118)
    for row in range(4):
        y0 = row * 8
        for y in range(y0, y0 + 8):
            for x in range(32):
                g.put(x, y, cols[row])
        g.hline(0, 31, y0 + 7, seam)
        if row in (0, 2):  # only every other plank has a butt joint in this tile
            jx = 9 if row == 0 else 25
            g.vline(jx, y0, y0 + 6, joint)
        if row in (1, 3):
            gx = 6 if row == 1 else 18
            for k in range(4):
                g.put(gx + k, y0 + 3, grain)
    return g.im


def tree():
    """32x52 potted ficus that sits on the floor (pot + contact shadow baked in)."""
    g = Px(32, 52)
    lv, lv_l, lv_d, lv_h = (124, 178, 108), (156, 204, 128), (86, 140, 86), (196, 230, 160)
    trunk, trunk_d = (150, 104, 70), (116, 78, 52)
    pot, pot_l, pot_d, rim = (214, 128, 92), (232, 156, 116), (180, 100, 72), (238, 170, 128)
    # trunk
    g.rect(15, 22, 16, 38, trunk)
    g.vline(16, 22, 38, trunk_d)
    g.put(14, 30, trunk); g.put(13, 29, trunk)
    # canopy: three overlapping puffs
    for cx, cy, r in ((10, 14, 7), (21, 13, 7.5), (16, 8, 7), (15, 18, 7)):
        g.ellipse(cx, cy, r, r * 0.9, lv)
    for cx, cy, r in ((9, 12, 4), (19, 9, 4), (15, 6, 3)):
        g.ellipse(cx - 1, cy - 1, r, r * 0.8, lv_l)
    for (x, y) in ((8, 10), (17, 6), (22, 10), (13, 4)):
        g.put(x, y, lv_h)
    for y in range(16, 26):
        for x in range(2, 30):
            if g.p[x, y][3] and y > 19 and g.p[x, y][:3] == lv:
                g.put(x, y, lv_d)
    g.outline()
    # pot (tapered) with rim
    for y in range(38, 49):
        w = 8 - (y - 38) * 0.25
        for x in range(int(16 - w), int(16 + w) + 1):
            g.put(x, y, pot_l if x < 13 else (pot_d if x > 19 else pot))
    g.rect(6, 36, 25, 38, rim)
    g.hline(6, 25, 39, pot_d)
    # outline pot
    for y in range(35, 50):
        for x in range(4, 28):
            if g.p[x, y][3] == 0 and any(0 <= x + dx < 32 and g.p[x + dx, y + dy][3] == 255 and g.p[x + dx, y + dy][:3] != (104, 54, 36)
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= y + dy < 52):
                g.put(x, y, OUT)
    # soft contact shadow on the floor
    for x in range(5, 27):
        for y, a in ((50, 70), (51, 40)):
            if g.p[x, y][3] == 0 and not (y == 51 and x in (5, 6, 25, 26)):
                g.put(x, y, (120, 80, 60, a))
    return g.im


def cat_bed():
    """48x32 round cat bed (light so the dress-up tint shows), cushion + heart."""
    g = Px(48, 32)
    rim, rim_l, rim_d = (248, 238, 236), (255, 250, 248), (222, 206, 206)
    inner, inner_d, cush, cush_l = (232, 214, 214), (210, 190, 192), (255, 246, 240), (255, 255, 252)
    g.ellipse(24, 19, 22, 10.5, rim)
    g.ellipse(24, 16, 20, 7, rim_l, clip=lambda x, y: y < 15)
    g.ellipse(24, 16, 16, 6, inner)
    g.ellipse(24, 18, 14, 4.6, inner_d, clip=lambda x, y: y < 17)
    g.ellipse(24, 18, 13, 4.4, cush)
    g.ellipse(21, 17, 7, 2.2, cush_l)
    for x in range(3, 46):
        for y in range(23, 30):
            if g.p[x, y][3] and g.p[x, y][:3] == rim:
                g.put(x, y, rim_d)
    # little heart on the front rim
    for (x, y) in ((22, 24), (23, 24), (25, 24), (26, 24), (22, 25), (23, 25), (24, 25), (25, 25), (26, 25), (23, 26), (24, 26), (25, 26), (24, 27)):
        g.put(x, y, (240, 150, 160))
    g.put(24, 24, (240, 150, 160))
    g.outline(OUT_SOFT)
    for x in range(4, 44):
        if g.p[x, 31][3] == 0:
            g.put(x, 31, (120, 80, 60, 60))
    return g.im


def bunting():
    """208x18 pastel flag garland for the upper wall (portrait shows more wall)."""
    g = Px(208, 18)
    string = (176, 136, 120)
    flags = [(246, 170, 176), (250, 222, 150), (170, 214, 196), (176, 200, 236), (232, 186, 230)]
    pts = []
    for x in range(208):
        y = 2 + int(round(4 * math.sin(math.pi * x / 207)))
        pts.append(y)
        g.put(x, y, string)
    for i, x0 in enumerate(range(6, 200, 16)):
        col = flags[i % len(flags)]
        y0 = pts[x0 + 5] + 1
        for j in range(9):
            for x in range(x0 + j // 2, x0 + 11 - j // 2):
                g.put(x, y0 + j, col)
        for x in range(x0, x0 + 11):
            g.put(x, y0, tuple(min(255, c + 18) for c in col))
    return g.im


def photo():
    """20x22 small frame with a paw print."""
    g = Px(20, 22)
    fr, fr_d, mat, paw = (204, 156, 110), (168, 120, 84), (252, 244, 232), (236, 156, 160)
    g.rect(0, 0, 19, 21, fr)
    g.rect(1, 20, 19, 21, fr_d)
    g.rect(3, 3, 16, 18, mat)
    g.ellipse(9.5, 13, 3, 2.4, paw)
    for (x, y) in ((6, 8), (8, 7), (11, 7), (13, 8)):
        g.put(x, y, paw); g.put(x, y + 1, paw)
    g.outline()
    return g.im


ASSETS.update({
    "room/wall_cream": wallpaper,
    "room/wall_baseboard": wainscot,
    "room/floor_wood_32": floor32,
    "room/tree": tree,
    "room/cat_bed": cat_bed,
    "room/bunting": bunting,
    "room/photo": photo,
})

if __name__ == "__main__":
    sheet = Image.new("RGBA", (900, 200), (70, 64, 78, 255))
    x = 4
    for k, fn in ASSETS.items():
        im = fn()
        big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        if x + big.width > 900:
            break
        sheet.paste(big, (x, 4), big)
        x += big.width + 6
    sheet.save("/tmp/room_art.png")
    s2 = Image.new("RGBA", (900, 200), (70, 64, 78, 255))
    x = 4
    for k in ["food/dish_fish", "food/dish_kibble", "food/dish_can", "food/dish_milk", "ui/panel_mood"]:
        im = ASSETS[k]()
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        s2.paste(big, (x, 4), big)
        x += big.width + 6
    s2.save("/tmp/room_art2.png")
    print("ok")
