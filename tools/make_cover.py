#!/usr/bin/env python3
"""Draws the placeholder itch.io cover, assets/cover.png (630x500), from the Urizen tiles and the
DINOBYTE font the game uses. A real cover replaces it later. Run: python3 -I tools/make_cover.py"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sheet = Image.open(os.path.join(ROOT, 'tools/data/urizen_onebit_tileset__v2d0.png')).convert('RGB')
font = Image.open(os.path.join(ROOT, 'tools/data/dbyte_1x.png')).convert('RGBA')

BG, WALL, TITLE, SUB, PLAYER, DIM = (26, 28, 44), (148, 176, 194), (115, 239, 247), (244, 244, 244), (244, 244, 244), (86, 108, 134)
W, H = 630, 500
img = Image.new('RGB', (W, H), BG)

def tile(col, row, x, y, scale, color):
    for ty in range(12):
        for tx in range(12):
            if max(sheet.getpixel((13 * col + 1 + tx, 13 * row + 1 + ty))) > 0:
                for sy in range(scale):
                    for sx in range(scale):
                        px, py = x + tx * scale + sx, y + ty * scale + sy
                        if 0 <= px < W and 0 <= py < H:
                            img.putpixel((px, py), color)

def text(s, y, scale, color):
    x0 = (W - len(s) * 6 * scale) // 2
    for i, ch in enumerate(s.encode('cp437')):
        cx, cy = (ch % 16) * 6, (ch // 16) * 8
        for gy in range(8):
            for gx in range(6):
                if font.getpixel((cx + gx, cy + gy))[3] > 0:
                    for sy in range(scale):
                        for sx in range(scale):
                            img.putpixel((x0 + (i * 6 + gx) * scale + sx, y + gy * scale + sy), color)

# A wall of the bulwark along the top and bottom.
for i in range(W // 36 + 1):
    tile(0, 2, i * 36, 0, 3, WALL)
    tile(0, 2, i * 36, H - 36, 3, WALL)
text("BLUSTERY", 90, 9, TITLE)
text("BULWARK", 170, 9, TITLE)
text("of SPLORR!!", 260, 5, SUB)
tile(104, 0, (W - 72) // 2, 330, 6, PLAYER)
text("placeholder cover", H - 64, 2, DIM)
img.save(os.path.join(ROOT, 'assets/cover.png'))
print("assets/cover.png", img.size)
