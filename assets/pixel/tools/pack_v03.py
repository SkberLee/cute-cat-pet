#!/usr/bin/env python3
"""Pack the v0.3 cat set + room dressing into .aseprite (原图 + pixel) and PNGs."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cat_art  # noqa: E402
import room_art  # noqa: E402

ROOT = Path("/workspace/cute-cat-pet")
PIX = ROOT / "assets/pixel"
ASE = "/home/box/bin/aseprite"
FINAL = PIX / "tools/finalize.js"

# name -> (frames builder key, fps, loop); "alias" entries reuse PNGs in Godot only.
OBSOLETE = ["eat", "jump", "walk", "happy", "call", "sleep", "sit", "sit_blink", "sit_side", "sit_up",
            "idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side"]


def _clean_cat_dir():
    d = PIX / "cat"
    for f in d.iterdir():
        if f.suffix in (".png", ".aseprite") or f.name.endswith(".png.import"):
            f.unlink()


def _finalize(path: Path):
    subprocess.run([ASE, "-b", str(path), "--script", str(FINAL)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pack_all(pack_sprite, ref_cat, finalize=True):
    _clean_cat_dir()
    anims = cat_art.build_all()
    manifest = {}
    for name, (frames, fps, loop) in anims.items():
        path = PIX / "cat" / f"{name}.aseprite"
        pack_sprite(path, 64, 64, [f.bytes() for f in frames], ref_cat, duration=int(1000 / fps))
        if len(frames) == 1:
            Image.frombytes("RGBA", (64, 64), frames[0].bytes()).save(PIX / "cat" / f"{name}_0.png")
        manifest[name] = (len(frames), fps, loop)
        if finalize:
            _finalize(path)
    for key, fn in room_art.ASSETS.items():
        im = fn()
        path = PIX / f"{key}.aseprite"
        pack_sprite(path, im.width, im.height, [im.tobytes()], None)
        if finalize:
            _finalize(path)
    return manifest


if __name__ == "__main__":
    import gen_pixel as g
    ref = g.ref_crop("cat_sit_front.png", (140, 360, 580, 980), 64, 64)
    m = pack_all(g.pack_sprite, ref)
    for k, v in m.items():
        print(k, v)
