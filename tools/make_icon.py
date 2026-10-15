#!/usr/bin/env python3
"""Draw nv27's app icon: the original nvALT icon with a blue "27" badge in SF Pro Bold.

Run on macOS (it needs the system's SF Pro font and iconutil):
    git show 7401933^:Notality.icns > /tmp/original.icns
    python3 tools/make_icon.py /tmp/original.icns Notality.icns
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SF_PRO = '/System/Library/Fonts/SFNS.ttf'

def badge(base1024):
    SS = 2                                   # draw at 2x and downsample for smooth edges
    W = 1024 * SS
    cx, cy, r = 224 * SS, 796 * SS, 184 * SS  # lower left, over the empty paper corner
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    shadow = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([cx - r, cy - r + 20 * SS, cx + r, cy + r + 20 * SS], fill=(0, 0, 0, 110))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18 * SS)))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))      # white ring
    ring = 18 * SS
    grad = Image.new('RGBA', (2 * (r - ring), 2 * (r - ring)))
    top, bottom = (64, 156, 255), (0, 98, 214)                                   # blue disc, light to dark
    gd = ImageDraw.Draw(grad)
    for y in range(grad.height):
        t = y / (grad.height - 1)
        gd.line([(0, y), (grad.width, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    mask = Image.new('L', grad.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, grad.width - 1, grad.height - 1], fill=255)
    layer.paste(grad, (cx - r + ring, cy - r + ring), mask)
    font = ImageFont.truetype(SF_PRO, 208 * SS)
    #SF Pro is a variable font: set its weight axis to Bold (700), leaving the other axes at their defaults
    axes = font.get_variation_axes()
    print('SF Pro axes:', [(a['name'], a['minimum'], a['default'], a['maximum']) for a in axes])
    font.set_variation_by_axes([700 if a['name'] in (b'Weight', 'Weight') else a['default'] for a in axes])
    d.text((cx, cy + 4 * SS), '27', font=font, fill=(255, 255, 255, 255), anchor='mm')
    base1024.alpha_composite(layer.resize((1024, 1024), Image.LANCZOS))
    return base1024

def main(src, dst):
    original = Image.open(src)
    original.size = max(original.info['sizes'])[:2]   # the largest representation
    original.load()
    icon = badge(original.convert('RGBA').resize((1024, 1024), Image.LANCZOS))
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, 'icon.iconset')
        os.mkdir(iconset)
        for size in (16, 32, 128, 256, 512):
            icon.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, 'icon_%dx%d.png' % (size, size)))
            icon.resize((size * 2, size * 2), Image.LANCZOS).save(os.path.join(iconset, 'icon_%dx%d@2x.png' % (size, size)))
        subprocess.check_call(['iconutil', '-c', 'icns', iconset, '-o', dst])
    icon.resize((512, 512), Image.LANCZOS).save(os.path.splitext(dst)[0] + '-preview.png')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
