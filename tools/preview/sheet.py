"""Tile captured preview frames into one contact sheet: sheet.py <dir> [cols] [width]"""
import sys
from pathlib import Path
from PIL import Image

directory = Path(sys.argv[1])
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 3
width = int(sys.argv[3]) if len(sys.argv) > 3 else 640
frames = sorted(directory.glob("frame_*.png"))
height = width * 9 // 16
rows = (len(frames) + cols - 1) // cols
sheet = Image.new("RGB", (width * cols, height * rows))
for i, path in enumerate(frames):
    sheet.paste(Image.open(path).convert("RGB").resize((width, height)), ((i % cols) * width, (i // cols) * height))
sheet.save(directory / "sheet.png")
print(directory / "sheet.png")
