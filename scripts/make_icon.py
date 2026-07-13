#!/usr/bin/env python3
"""Generate Quip's AppIcon set.

A macOS "squircle" with a violet->pink diagonal gradient (Chorus family), and a
frosted-white speech bubble with a knockout play triangle inside ("an animated
reply"). Renders a 1024px master, then the standard macOS icon sizes into
Quip/Assets.xcassets/AppIcon.appiconset with a Contents.json.

Usage: python3 scripts/make_icon.py
"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(__file__)
OUT = os.path.normpath(os.path.join(HERE, "..", "Quip", "Assets.xcassets", "AppIcon.appiconset"))

S = 1024                      # master size
VIOLET = (124, 58, 237)       # #7C3AED
PINK = (219, 39, 119)         # #DB2777


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size, c0, c1):
    """Top-left c0 -> bottom-right c1, computed per-pixel (fast enough at 1024)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    denom = 2 * (size - 1)
    for y in range(size):
        for x in range(size):
            px[x, y] = lerp(c0, c1, (x + y) / denom)
    return img


def superellipse_mask(size, inset, n=5.0):
    """Filled Apple-style squircle mask centered in `size`, inset from the edge."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    cx = cy = size / 2
    a = (size - 2 * inset) / 2
    pts = []
    steps = 720
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = cx + a * math.copysign(abs(ct) ** (2 / n), ct)
        y = cy + a * math.copysign(abs(st) ** (2 / n), st)
        pts.append((x, y))
    d.polygon(pts, fill=255)
    return mask


def rounded_rect_pts(x0, y0, x1, y1, r):
    return (x0, y0, x1, y1), r


def build_master():
    # Transparent canvas; squircle content inset ~9% with a soft drop shadow,
    # matching the macOS icon grid look.
    inset = int(S * 0.085)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    grad = diagonal_gradient(S, VIOLET, PINK).convert("RGBA")
    mask = superellipse_mask(S, inset)

    # Soft drop shadow behind the squircle.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh_mask = mask.filter(ImageFilter.GaussianBlur(S * 0.02))
    shadow.putalpha(sh_mask.point(lambda v: int(v * 0.35)))
    shadow = Image.new("RGBA", (S, S), (10, 8, 20, 255))
    shadow.putalpha(sh_mask.point(lambda v: int(v * 0.30)))
    off = int(S * 0.012)
    icon.alpha_composite(shadow, (0, off))

    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    icon.alpha_composite(body)

    # Frosted speech bubble (rounded rect + tail), translucent white.
    bub = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bub)
    bx0, by0, bx1, by1 = int(S * 0.28), int(S * 0.30), int(S * 0.72), int(S * 0.62)
    r = int(S * 0.075)
    white = (255, 255, 255, 235)
    bd.rounded_rectangle([bx0, by0, bx1, by1], radius=r, fill=white)
    # Tail: a small triangle off the lower-left of the bubble.
    tail = [(int(S * 0.36), by1 - 4), (int(S * 0.34), int(S * 0.72)), (int(S * 0.46), by1 - 4)]
    bd.polygon(tail, fill=white)

    # Knockout play triangle: erase to let the gradient show through the bubble.
    cxp = (bx0 + bx1) / 2
    cyp = (by0 + by1) / 2
    pw = int(S * 0.11)
    play = [
        (cxp - pw * 0.55, cyp - pw),
        (cxp - pw * 0.55, cyp + pw),
        (cxp + pw * 0.95, cyp),
    ]
    bd.polygon(play, fill=(0, 0, 0, 0))
    # Draw the play by knockout: build an alpha where the triangle subtracts.
    knock = Image.new("L", (S, S), 0)
    kd = ImageDraw.Draw(knock)
    kd.polygon(play, fill=255)
    ba = bub.split()[3]
    ba = Image.composite(Image.new("L", (S, S), 0), ba, knock)
    bub.putalpha(ba)

    icon.alpha_composite(bub)
    return icon


# macOS AppIcon: (size_pt, scale) -> filename
ENTRIES = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    master = build_master()
    images = []
    for pt, scale in ENTRIES:
        px = pt * scale
        fn = f"icon_{pt}x{pt}@{scale}x.png" if scale == 2 else f"icon_{pt}x{pt}.png"
        master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, fn))
        images.append({"size": f"{pt}x{pt}", "idiom": "mac",
                       "filename": fn, "scale": f"{scale}x"})
    contents = {"images": images, "info": {"version": 1, "author": "xcode"}}
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    # Also save a preview master for eyeballing.
    master.save(os.path.join(HERE, "..", "docs", "icon-preview.png"))
    print(f"wrote {len(ENTRIES)} icon PNGs + Contents.json to {OUT}")


if __name__ == "__main__":
    main()
