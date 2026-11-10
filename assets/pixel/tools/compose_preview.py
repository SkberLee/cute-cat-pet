#!/usr/bin/env python3
"""Build preview_sheet.png and screenshots/pixel_preview_*.png (integer nearest-neighbor)."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/workspace/cute-cat-pet")
PIX = ROOT / "assets/pixel"
SHOT = ROOT / "screenshots"
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BG = (255, 246, 232, 255)
INK = (90, 62, 78, 255)
MUTED = (160, 120, 110, 255)
PANEL = (255, 250, 244, 255)


def font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT, size=size, index=0)
    except Exception:
        return ImageFont.load_default()


def nn(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.Resampling.NEAREST)


def load(rel) -> Image.Image:
    return Image.open(PIX / rel).convert("RGBA")


def checker_paste(canvas, im, xy, cell=8):
    x, y = xy
    w, h = im.size
    # no checker under actual pixels only; just paste
    canvas.paste(im, (x, y), im)


def text(draw, xy, s, size=16, fill=INK):
    draw.text(xy, s, font=font(size), fill=fill)


def new_canvas(w, h, color=BG):
    return Image.new("RGBA", (w, h), color)


def compose_strip(paths, scale, gap=8, pad=8, bg=BG):
    imgs = [nn(load(p), scale) for p in paths]
    w = pad * 2 + sum(i.width for i in imgs) + gap * (len(imgs) - 1)
    h = pad * 2 + max(i.height for i in imgs)
    c = new_canvas(w, h)
    x = pad
    for im in imgs:
        c.paste(im, (x, pad + (h - pad * 2 - im.height) // 2), im)
        x += im.width + gap
    return c


def room_mockup(scale=5) -> Image.Image:
    """Assemble tiles + furniture + cat into a cozy room scene."""
    W, H = 208, 160
    scene = new_canvas(W, H, (0, 0, 0, 0))
    wall = load("room/wall_cream.png")
    base = load("room/wall_baseboard.png")
    floor = load("room/floor_wood_32.png")
    rug = load("room/rug.png")
    lamp = load("room/lamp.png")
    box = load("room/box.png")
    ott = load("room/ottoman.png")
    cat = load("cat/sit.png")
    fish = load("food/fish.png")
    bubble = load("fx/bubble_9slice.png")
    heart = load("fx/heart.png")
    panel = load("ui/panel_mood.png")
    btn = load("ui/button.png")

    # cream wall (top), baseboard just above the floor
    for x in range(0, W, 32):
        scene.paste(wall, (x, 0), wall)
        scene.paste(wall, (x, 20), wall)
        scene.paste(base, (x, 32), base)
    # floor starts below the baseboard stripe (tile y=24 is the wood cap)
    for y in range(64, H, 32):
        for x in range(0, W, 32):
            scene.paste(floor, (x, y), floor)
    # rug + furniture + cat
    scene.paste(rug, (64, 84), rug)
    scene.paste(lamp, (14, 32), lamp)
    scene.paste(box, (168, 88), box)
    scene.paste(ott, (8, 112), ott)
    scene.paste(cat, (72, 68), cat)
    scene.paste(fish, (118, 118), fish)
    scene.paste(bubble, (136, 40), bubble)
    scene.paste(heart, (124, 58), heart)
    scene.paste(heart.resize((12, 12), Image.Resampling.NEAREST), (150, 52), heart.resize((12, 12), Image.Resampling.NEAREST))
    # HUD tucked top-left, buttons along the bottom margin (showcase only)
    scene.paste(panel, (4, 4), panel)
    for i in range(3):
        scene.paste(btn, (28 + i * 52, 138), btn)
    return nn(scene, scale)


def preview_sheet():
    W = 1600
    # we'll grow height as we go; start large and crop
    c = new_canvas(W, 4000)
    d = ImageDraw.Draw(c)
    y = 24
    text(d, (40, y), "治愈猫 · 像素资源预览  （Stardew 风味的原创像素，非描摹）", 28)
    y += 44
    text(d, (40, y), "尺寸：猫 64×64 · 道具 32×32 · 地板/墙 16/32 · UI 可拉伸   源文件为 .aseprite（图层：原图 + pixel）", 16, MUTED)
    y += 36

    # palette
    text(d, (40, y), "调色板 palette.png", 20)
    y += 28
    pal = nn(load("palette.png"), 3)
    c.paste(pal, (40, y), pal)
    y += pal.height + 28

    # cat
    text(d, (40, y), "猫咪  sit / blink / side / sit_up / sleep / happy / call", 20)
    y += 28
    row = compose_strip(
        ["cat/sit.png", "cat/sit_blink.png", "cat/sit_side.png", "cat/sit_up.png", "cat/sleep.png", "cat/happy.png", "cat/call.png"],
        3, gap=10, pad=6,
    )
    c.paste(row, (40, y), row)
    y += row.height + 16
    text(d, (40, y), "走路 四向 walk_down / walk_up / walk_side ×4（侧向左右共用，游戏里水平翻转）", 20)
    y += 26
    for label, prefix in (("向屏幕 walk_down", "walk_down"), ("背对 walk_up", "walk_up"), ("侧面 walk_side", "walk_side")):
        text(d, (48, y), label, 14, MUTED)
        y += 20
        walk = compose_strip([f"cat/{prefix}_{i}.png" for i in range(4)], 3, gap=8, pad=6)
        c.paste(walk, (40, y), walk)
        y += walk.height + 10
    text(d, (40, y), "吃 eat ×4    跳/扑 jump ×4", 20)
    y += 26
    ej = compose_strip([f"cat/eat_{i}.png" for i in range(4)] + [f"cat/jump_{i}.png" for i in range(4)], 3, gap=8, pad=6)
    c.paste(ej, (40, y), ej)
    y += ej.height + 28

    # food toys hand
    text(d, (40, y), "食物  小鱼干 / 猫粮碗（满、空） / 罐头 / 牛奶（满、空）", 20)
    y += 26
    food = compose_strip(
        ["food/fish.png", "food/kibble_bowl.png", "food/kibble_bowl_empty.png", "food/can.png", "food/milk.png", "food/milk_empty.png"],
        4, gap=12, pad=6,
    )
    c.paste(food, (40, y), food)
    y += food.height + 16
    text(d, (40, y), "玩具  逗猫棒 / 毛线球 / 激光点 / 毛毡小老鼠", 20)
    y += 26
    toys = compose_strip(["toys/wand.png", "toys/yarn.png", "toys/laser.png", "toys/mouse.png"], 4, gap=12, pad=6)
    c.paste(toys, (40, y), toys)
    y += toys.height + 16
    text(d, (40, y), "特效  抚摸小手（仅手掌） / 爱心 / 闪光 / 对话框 9-slice", 20)
    y += 26
    fx = compose_strip(["fx/hand.png", "fx/hand_48.png", "fx/heart.png", "fx/sparkle.png", "fx/sparkle_1.png", "fx/bubble_9slice.png"], 4, gap=12, pad=6)
    c.paste(fx, (40, y), fx)
    y += fx.height + 28

    # room + ui
    text(d, (40, y), "房间  木地板 32/16（无缝） / 墙 / 踢脚线 / 白地毯 / 薄荷绿灯 / 纸箱 / 坐垫", 20)
    y += 26
    room = compose_strip(
        ["room/floor_wood_32.png", "room/floor_wood_16.png", "room/wall_cream.png", "room/wall_baseboard.png",
         "room/rug.png", "room/lamp.png", "room/box.png", "room/ottoman.png"],
        3, gap=10, pad=6,
    )
    c.paste(room, (40, y), room)
    y += room.height + 16
    text(d, (40, y), "UI  心情面板 / 按钮 / 选择面板 / 应用图标与前景", 20)
    y += 26
    ui = compose_strip(
        ["ui/panel_mood.png", "ui/button.png", "ui/button_pressed.png", "ui/picker_panel.png",
         "ui/icon_cat_face.png", "ui/icon_app_fg.png"],
        2, gap=10, pad=6,
    )
    c.paste(ui, (40, y), ui)
    y += ui.height + 28

    text(d, (40, y), "房间拼贴示意（地板+墙+家具+猫咪，仅预览，尚未做成玩法）", 20)
    y += 26
    mock = room_mockup(4)
    # maybe scale down if too wide
    if mock.width > W - 80:
        # shouldn't happen at 4x (192*4=768)
        pass
    c.paste(mock, (40, y), mock)
    y += mock.height + 32
    text(d, (40, y), "导出 PNG 时请只导出 pixel 图层（隐藏「原图」参考层）。v0.2.7 起这些素材已用于 2D 主场景；v0.2.8 起猫咪走路为四向（前 / 后 / 侧）。", 15, MUTED)
    y += 36

    out = c.crop((0, 0, W, y + 16))
    out_path = PIX / "preview_sheet.png"
    out.convert("RGB").save(out_path, optimize=True)
    print("wrote", out_path, out.size)
    return mock


def showcases():
    SHOT.mkdir(exist_ok=True)
    # cat sit 6x
    bg = new_canvas(64 * 6 + 80, 64 * 6 + 80)
    sit = nn(load("cat/sit.png"), 6)
    bg.paste(sit, (40, 40), sit)
    p = SHOT / "pixel_preview_cat_sit.png"
    bg.convert("RGB").save(p)
    print("wrote", p)

    # 4-directional walk sheet (also copied into assets/pixel)
    rows = []
    for prefix in ("walk_down", "walk_up", "walk_side"):
        rows.append(compose_strip([f"cat/{prefix}_{i}.png" for i in range(4)], 5, gap=12, pad=16))
    idles = compose_strip(["cat/idle_down.png", "cat/sit_up.png", "cat/idle_side.png"], 5, gap=12, pad=16)
    rows.append(idles)
    w = max(r.width for r in rows) + 16
    h = sum(r.height for r in rows) + 40
    sheet = new_canvas(w, h)
    yy = 8
    for r in rows:
        sheet.paste(r, (8, yy), r)
        yy += r.height + 8
    p = SHOT / "pixel_preview_cat_walk.png"
    sheet.convert("RGB").save(p)
    print("wrote", p)
    (PIX / "preview_walk_dirs.png").write_bytes((SHOT / "pixel_preview_cat_walk.png").read_bytes()) if False else sheet.convert("RGB").save(PIX / "preview_walk_dirs.png")
    print("wrote", PIX / "preview_walk_dirs.png")

    # foods 6x
    food = compose_strip(
        ["food/fish.png", "food/kibble_bowl.png", "food/kibble_bowl_empty.png", "food/can.png", "food/milk.png", "food/milk_empty.png"],
        6, gap=16, pad=24,
    )
    p = SHOT / "pixel_preview_foods.png"
    food.convert("RGB").save(p)
    print("wrote", p)

    # toys 6x
    toys = compose_strip(["toys/wand.png", "toys/yarn.png", "toys/laser.png", "toys/mouse.png"], 6, gap=20, pad=24)
    p = SHOT / "pixel_preview_toys.png"
    toys.convert("RGB").save(p)
    print("wrote", p)

    # hand 6x (32 and 48)
    hand = compose_strip(["fx/hand.png", "fx/hand_48.png"], 6, gap=24, pad=32)
    p = SHOT / "pixel_preview_hand.png"
    hand.convert("RGB").save(p)
    print("wrote", p)

    # room mockup 5x
    mock = room_mockup(5)
    # add a little margin
    canvas = new_canvas(mock.width + 40, mock.height + 40)
    canvas.paste(mock, (20, 20), mock)
    p = SHOT / "pixel_preview_room.png"
    canvas.convert("RGB").save(p)
    print("wrote", p)


if __name__ == "__main__":
    preview_sheet()
    showcases()
