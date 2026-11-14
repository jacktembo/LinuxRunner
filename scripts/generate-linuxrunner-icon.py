#!/usr/bin/env python3
"""Generate the opaque LinuxRunner app icon set from Branding/LinuxRunnerIcon.svg's geometry.

The mark is a white `>_` prompt with three speed lines on an orange-to-red
diagonal gradient. iOS applies its own corner mask, so the app icons are
full-bleed squares; the rounded SVGs are for documentation.
"""
import json, pathlib
from PIL import Image, ImageChops, ImageDraw

root = pathlib.Path(__file__).resolve().parents[1]
out = root / 'app/Assets.xcassets/LinuxRunnerAppIcon.appiconset'
out.mkdir(exist_ok=True)
manifest = json.loads((root / 'app/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())

START, END = (0xFF, 0x8A, 0x1F), (0xE0, 0x32, 0x3C)  # top-left, bottom-right
scale = 3
n = 1024 * scale

# Diagonal gradient: mask = (x + y) / 2, mapped from START to END.
vertical = Image.linear_gradient('L').resize((n, n))
mask = ImageChops.add(vertical, vertical.rotate(90), scale=2.0)
image = Image.composite(Image.new('RGB', (n, n), END), Image.new('RGB', (n, n), START), mask).convert('RGBA')

overlay = Image.new('RGBA', (n, n), (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

def line(points, width, opacity=1.0):
    fill = (255, 255, 255, round(255 * opacity))
    p = [(x * scale, y * scale) for x, y in points]
    draw.line(p, fill=fill, width=width * scale, joint='curve')
    r = width * scale / 2
    for x, y in p:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)

line([(178, 404), (292, 404)], 40, 0.55)   # speed lines
line([(128, 512), (292, 512)], 40, 0.80)
line([(178, 620), (292, 620)], 40, 0.55)
line([(392, 300), (604, 512), (392, 724)], 100)  # prompt chevron
draw.rounded_rectangle((642 * scale, 650 * scale, 864 * scale, 730 * scale), radius=22 * scale, fill=(255, 255, 255, 255))  # cursor

image = Image.alpha_composite(image, overlay).convert('RGB')
for item in manifest['images']:
    if 'filename' not in item:
        continue
    size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
    image.resize((size, size), Image.Resampling.LANCZOS).save(out / item['filename'])
(out / 'Contents.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Generated opaque LinuxRunner icon set')
