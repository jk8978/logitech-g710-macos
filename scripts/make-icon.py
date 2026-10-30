#!/usr/bin/env python3
"""Render the G710Keys app icon.

Requires Pillow:  python3 -m pip install pillow
Writes docs/icon-1024.png and Resources/AppIcon.icns (macOS, uses iconutil).
"""
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4
W = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sc(*v):
    return tuple(int(x * S) for x in v)


def rect(*v):
    return [int(x * S) for x in v]


def render():
    img = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    mask = Image.new("L", (W * S, W * S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(rect(100, 100, 924, 924), radius=185 * S, fill=255)

    top, bot = (52, 71, 99), (10, 15, 23)
    grad = Image.new("RGB", (1, W * S))
    for y in range(W * S):
        t = y / (W * S - 1)
        grad.putpixel((0, y), tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    bg = grad.resize((W * S, W * S)).convert("RGBA")
    glow = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(rect(150, 250, 880, 780), fill=(10, 132, 255, 70))
    bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(110 * S)))
    img.paste(bg, (0, 0), mask)

    line = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    ImageDraw.Draw(line).rounded_rectangle(rect(240, 692, 784, 708), radius=8 * S, fill=(60, 200, 255, 230))
    img.alpha_composite(line.filter(ImageFilter.GaussianBlur(14 * S)))

    sh = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(rect(196, 424, 828, 728), radius=36 * S, fill=(0, 0, 0, 160))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22 * S)))

    kb_mask = Image.new("L", (W * S, W * S), 0)
    ImageDraw.Draw(kb_mask).rounded_rectangle(rect(196, 402, 828, 706), radius=36 * S, fill=255)
    kgrad = Image.new("RGB", (1, int(304 * S)))
    c1, c2 = (251, 253, 255), (208, 221, 236)
    for y in range(int(304 * S)):
        t = y / max(1, int(304 * S) - 1)
        kgrad.putpixel((0, y), tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)))
    kb = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    kb.paste(kgrad.resize((int(632 * S), int(304 * S))).convert("RGBA"),
             (196 * S, 402 * S), kb_mask.crop(rect(196, 402, 828, 706)))
    img.alpha_composite(kb)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(rect(196, 402, 828, 706), radius=36 * S, outline=(255, 255, 255, 95), width=2 * S)

    x0, y0 = 222, 424
    kw = (580 - 13 * 8) / 14
    rows_y = [(y0, 24, True)]
    yy = y0 + 24 + 14
    for _ in range(3):
        rows_y.append((yy, 40, False))
        yy += 40 + 10
    rows_y.append((yy, 40, False))

    font_g = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Black.ttf", int(24 * S))

    def key_rect(cx, cy, w, h, fill, topfill, radius=7):
        d.rounded_rectangle(rect(cx, cy, cx + w, cy + h), radius=radius * S, fill=fill)
        d.rounded_rectangle(rect(cx + 1, cy + 1, cx + w - 1, cy + h * 0.5),
                            radius=max(1, radius * S - 1), fill=topfill)

    for ri, (ry, rh, is_f) in enumerate(rows_y):
        if ri == 4:
            slot = lambda n: x0 + n * (kw + 8)
            for i in range(3):
                key_rect(slot(i), ry, kw, rh, (160, 176, 196, 255), (196, 210, 226, 255))
            sp_x = slot(3)
            sp_w = kw * 7 + 8 * 6
            key_rect(sp_x, ry, sp_w, rh, (160, 176, 196, 255), (196, 210, 226, 255), radius=8)
            rx = sp_x + sp_w + 8
            for i in range(4):
                key_rect(rx + i * (kw + 8), ry, kw, rh, (160, 176, 196, 255), (196, 210, 226, 255))
            continue
        for ci in range(14):
            cx = x0 + ci * (kw + 8)
            if (not is_f) and ri == 2 and ci == 1:
                g = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
                ImageDraw.Draw(g).rounded_rectangle(
                    rect(cx - 7, ry - 7, cx + kw + 7, ry + rh + 7), radius=12 * S, fill=(0, 170, 255, 210))
                img.alpha_composite(g.filter(ImageFilter.GaussianBlur(11 * S)))
                d = ImageDraw.Draw(img)
                d.rounded_rectangle(rect(cx, ry, cx + kw, ry + rh), radius=8 * S, fill=(9, 118, 238, 255))
                d.rounded_rectangle(rect(cx + 1, ry + 1, cx + kw - 1, ry + rh * 0.45),
                                    radius=7 * S, fill=(84, 206, 255, 255))
                bb = d.textbbox((0, 0), "G", font=font_g)
                tw, th = bb[2] - bb[0], bb[3] - bb[1]
                d.text((cx * S + (kw * S - tw) / 2 - bb[0], ry * S + (rh * S - th) / 2 - bb[1]),
                       "G", font=font_g, fill=(255, 255, 255, 255))
            elif is_f:
                key_rect(cx, ry, kw, rh, (150, 166, 186, 255), (178, 194, 212, 255), radius=6)
            else:
                key_rect(cx, ry, kw, rh, (176, 192, 210, 255), (206, 218, 232, 255))

    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", int(54 * S))
    label = "G710+"
    bb = d.textbbox((0, 0), label, font=font)
    d.text((512 * S - (bb[2] - bb[0]) / 2 - bb[0], 800 * S - (bb[3] - bb[1]) / 2 - bb[1]),
           label, font=font, fill=(255, 255, 255, 155))

    rim = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(rect(100, 100, 924, 924), radius=185 * S,
                                          outline=(255, 255, 255, 45), width=2 * S)
    img.alpha_composite(rim)
    return img.resize((W, W), Image.LANCZOS)


def main():
    icon = render()
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "Resources"), exist_ok=True)
    icon.save(os.path.join(ROOT, "docs", "icon-1024.png"))

    specs = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        for size, name in specs:
            icon.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, name))
        out = os.path.join(ROOT, "Resources", "AppIcon.icns")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
        print("wrote", out)


if __name__ == "__main__":
    main()
