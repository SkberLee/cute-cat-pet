#!/bin/bash
# Record a 540x960 borderless Godot demo on DISPLAY :7 via ffmpeg x11grab.
set -euo pipefail
cd /workspace/cute-cat-pet
export DISPLAY=${DISPLAY:-:7}
OUT=${1:-/workspace/cute-cat-pet/screenshots/v031_desktop_play.mp4}
RAW=/tmp/record/v031_raw.mp4
mkdir -p /tmp/record /workspace/cute-cat-pet/screenshots
rm -f "$RAW" /tmp/record/demo_done
GODOT=/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64
timeout 50 "$GODOT" --path /workspace/cute-cat-pet -s res://tools/record_demo.gd \
  --rendering-driver opengl3 --resolution 540x960 --position 0,0 \
  >/tmp/record/godot.log 2>&1 &
GPID=$!
# Start grabbing quickly so the idle + ease-in are in the tape.
sleep 0.35
ffmpeg -y -f x11grab -video_size 540x960 -framerate 30 -draw_mouse 0 -i "${DISPLAY}.0+0,0" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset fast "$RAW" \
  >/tmp/record/ffmpeg.log 2>&1 &
FPID=$!
# Stop ffmpeg as soon as the demo signals it is done (window still up).
for i in $(seq 1 80); do
  if [[ -f /tmp/record/demo_done ]]; then
    sleep 0.05
    break
  fi
  if ! kill -0 "$GPID" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
kill -INT "$FPID" 2>/dev/null || true
wait "$FPID" 2>/dev/null || true
wait "$GPID" 2>/dev/null || true
python3 - << PY
from pathlib import Path
import subprocess
from PIL import Image
raw = Path("/tmp/record/v031_raw.mp4")
out = Path("$OUT")
if not raw.exists() or raw.stat().st_size < 10000:
    raise SystemExit("raw recording missing or tiny")
dur = float(subprocess.check_output([
    "ffprobe","-v","error","-show_entries","format=duration","-of","default=nw=1:nk=1", str(raw)
]).decode().strip() or "0")
n = max(1, int(dur * 10) + 2)
subprocess.check_call([
    "ffmpeg","-y","-i",str(raw),"-vf","fps=10",f"/tmp/record/trim_%02d.png"
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def is_room(path: Path) -> bool:
    if not path.exists():
        return False
    im = Image.open(path)
    # Sample a few warm room pixels (wall + floor), reject grey wallpaper.
    samples = [
        im.getpixel((im.width//2, 80))[:3],
        im.getpixel((im.width//2, im.height//2))[:3],
        im.getpixel((im.width//3, int(im.height*0.4)))[:3],
    ]
    ok = 0
    for r,g,b in samples:
        # Reject greyscale wallpaper / a black clear; keep cream wall and wood floor.
        if abs(r - g) < 12 and abs(g - b) < 12:
            continue
        if r > 190 and g > 170 and (r - b) > 18:
            ok += 1
    return ok >= 2
frames = sorted(Path("/tmp/record").glob("trim_*.png"))
first, last = 0, len(frames)-1
for i,p in enumerate(frames):
    if is_room(p):
        first = i
        break
for i in range(len(frames)-1, -1, -1):
    if is_room(frames[i]):
        last = i
        break
ss = max(0.0, first / 10.0)
end = min(dur, (last + 1) / 10.0)
print(f"keep {ss:.2f}s .. {end:.2f}s of {dur:.2f}s")
cmd = ["ffmpeg","-y","-ss",f"{ss:.2f}","-to",f"{end:.2f}","-i",str(raw),
       "-c:v","libx264","-pix_fmt","yuv420p","-crf","18","-preset","fast", str(out)]
subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print("wrote", out, "size", out.stat().st_size)
PY
