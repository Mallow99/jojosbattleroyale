"""Contact sheet of chosen frames: pick.py <dir> <out.png> <i,j,k...> [cols]"""
import sys
from pathlib import Path
from PIL import Image

directory, out, picks = Path(sys.argv[1]), sys.argv[2], [int(x) for x in sys.argv[3].split(",")]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
w, h = 480, 270
rows = (len(picks) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows))
for k, i in enumerate(picks):
    im = Image.open(directory / f"frame_{i:04d}.png").convert("RGB").resize((w, h))
    sheet.paste(im, ((k % cols) * w, (k // cols) * h))
sheet.save(out)
