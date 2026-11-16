"""Render docs/banner.png — the README hero image.

Pure Pillow drawing: no external assets, everything is generated
(dark glassmorphism background, gradient wordmark, glass player card).

    python tool/make_banner.py [--out docs/banner.png]
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2400, 1200

BG_TOP = (10, 8, 14)
BG_BOTTOM = (24, 17, 32)
VIOLET = (124, 108, 255)
CORAL = (255, 107, 90)
TEAL = (53, 211, 192)

FONT_DIR = Path("C:/Windows/Fonts")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def vertical_gradient(size: tuple[int, int], top, bottom) -> Image.Image:
    w, h = size
    grad = Image.new("RGB", (1, h))
    px = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((w, h), Image.BILINEAR)


def glow(size: tuple[int, int], center, radius: int, color, alpha: int) -> Image.Image:
    """Soft radial light blob, added on top of the background."""
    layer = Image.new("RGB", size, (0, 0, 0))
    draw = ImageDraw.Draw(layer)
    steps = 60
    for i in range(steps, 0, -1):
        r = int(radius * i / steps)
        a = alpha * (1 - i / steps) ** 1.6
        tint = tuple(round(color[c] * a / 255) for c in range(3))
        draw.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=tint
        )
    return layer.filter(ImageFilter.GaussianBlur(radius // 6))


def add(base: Image.Image, layer: Image.Image) -> Image.Image:
    return Image.blend(base, Image.blend(base, layer, 0.85), 1.0)


def screen(base: Image.Image, layer: Image.Image) -> Image.Image:
    from PIL import ImageChops

    return ImageChops.screen(base, layer)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def glass_panel(
    base: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill_alpha: int = 20,
    border_alpha: int = 46,
) -> None:
    """Translucent frosted rectangle with a bright top edge."""
    x0, y0, x1, y1 = box
    size = (x1 - x0, y1 - y0)
    mask = rounded_mask(size, radius)

    body = Image.new("RGBA", size, (255, 255, 255, fill_alpha))
    base.paste(Image.alpha_composite(base.crop(box).convert("RGBA"), body).convert("RGB"), box, mask)

    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1],
        radius,
        outline=(255, 255, 255, border_alpha),
        width=2,
    )
    # specular highlight along the top rim
    ed.arc([radius // 2, 2, size[0] - radius // 2, radius * 2], 200, 340, fill=(255, 255, 255, 120), width=3)
    base.paste(Image.alpha_composite(base.crop(box).convert("RGBA"), edge).convert("RGB"), box, mask)


def gradient_text(base: Image.Image, pos, text: str, fnt, top, bottom, spacing: int = 0) -> None:
    """Draw text filled with a vertical gradient."""
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    widths = [probe.textlength(ch, font=fnt) for ch in text]
    total = int(sum(widths) + spacing * (len(text) - 1))
    box_w, box_h = total + 8, int(fnt.size * 1.5)

    mask = Image.new("L", (box_w, box_h), 0)
    md = ImageDraw.Draw(mask)
    cursor = 0.0
    for ch, w in zip(text, widths):
        md.text((cursor, 0), ch, font=fnt, fill=255)
        cursor += w + spacing

    paint = vertical_gradient((box_w, box_h), top, bottom)
    base.paste(paint, (pos[0], pos[1]), mask)


def spaced_text(draw: ImageDraw.ImageDraw, pos, text: str, fnt, fill, spacing: int) -> None:
    cursor = pos[0]
    for ch in text:
        draw.text((cursor, pos[1]), ch, font=fnt, fill=fill)
        cursor += draw.textlength(ch, font=fnt) + spacing


def draw_player_card(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)

    # frosted body
    d.rounded_rectangle([0, 0, w, h], 64, fill=(255, 255, 255, 26))
    d.rounded_rectangle([0, 0, w - 1, h - 1], 64, outline=(255, 255, 255, 70), width=2)
    d.arc([40, 3, w - 40, 130], 200, 340, fill=(255, 255, 255, 150), width=3)

    # album artwork
    art_pad = 56
    art_w = w - art_pad * 2
    art_h = 470
    art = (art_pad, art_pad, art_pad + art_w, art_pad + art_h)
    art_size = (art_w, art_h)
    cover = vertical_gradient(art_size, VIOLET, CORAL).convert("RGBA")
    cg = ImageDraw.Draw(cover)
    cg.ellipse([art_size[0] * 0.06, -art_size[1] * 0.30, art_size[0] * 0.94, art_size[1] * 0.50], fill=(255, 255, 255, 26))
    # vinyl rings
    cx, cy = art_size[0] // 2, art_size[1] // 2 + 20
    for r in range(26, int(art_size[0] * 0.42), 12):
        alpha = max(18, 52 - r // 8)
        cg.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, alpha), width=2)
    cg.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(255, 255, 255, 200))
    cg.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(30, 20, 46, 230))
    card.paste(
        cover,
        (art[0], art[1]),
        rounded_mask(art_size, 40),
    )

    # text lines
    ty = art[3] + 54
    d.rounded_rectangle([art_pad, ty, art_pad + 400, ty + 26], 13, fill=(255, 255, 255, 190))
    d.rounded_rectangle([art_pad, ty + 46, art_pad + 268, ty + 46 + 18], 9, fill=(255, 255, 255, 70))

    # progress
    py = ty + 100
    d.rounded_rectangle([art_pad, py, w - art_pad, py + 9], 5, fill=(255, 255, 255, 44))
    knob_x = art_pad + int((w - art_pad * 2) * 0.62)
    d.rounded_rectangle([art_pad, py, knob_x, py + 9], 5, fill=VIOLET + (255,))
    d.ellipse([knob_x - 11, py - 6, knob_x + 11, py + 16], fill=(255, 255, 255, 255))

    # transport controls
    cy2 = py + 92
    mid = w // 2
    d.ellipse([mid - 44, cy2 - 44, mid + 44, cy2 + 44], fill=(255, 255, 255, 235))
    d.polygon([(mid - 11, cy2 - 21), (mid - 11, cy2 + 21), (mid + 20, cy2)], fill=(22, 15, 34, 255))
    for dx in (-140, 140):
        cxx = mid + dx
        d.polygon(
            [(cxx - 13, cy2 - 19), (cxx - 13, cy2 + 19), (cxx + 5, cy2)],
            fill=(255, 255, 255, 170),
        )
        d.rectangle([cxx + 5, cy2 - 19, cxx + 11, cy2 + 19], fill=(255, 255, 255, 170))

    shadow = card.filter(ImageFilter.GaussianBlur(0))
    base.paste(shadow, (x0, y0), shadow)


def build(out: Path) -> None:
    base = vertical_gradient((W, H), BG_TOP, BG_BOTTOM)

    for center, radius, color, alpha in (
        ((1820, 210), 820, VIOLET, 130),
        ((2280, 940), 700, CORAL, 100),
        ((760, 1120), 760, TEAL, 60),
    ):
        base = screen(base, glow((W, H), center, radius, color, alpha))

    # floating glass chips behind the player card (depth)
    chips = Image.new("RGB", (W, H), (0, 0, 0))
    cd = ImageDraw.Draw(chips)
    cd.rounded_rectangle([1380, 96, 2180, 420], 56, fill=(70, 58, 120))
    cd.rounded_rectangle([1560, 760, 2300, 1130], 56, fill=(120, 60, 80))
    base = screen(base, chips.filter(ImageFilter.GaussianBlur(72)))

    draw_player_card(base, (1452, 200, 2100, 1010))

    glass_panel(base, (188, 268, 700, 342), 37, fill_alpha=22, border_alpha=60)

    draw = ImageDraw.Draw(base)
    spaced_text(draw, (224, 293), "SELF-HOSTED  ·  ANDROID", font("segoeuib.ttf", 26), (226, 220, 250), 4)

    gradient_text(base, (180, 380), "MusicX", font("segoeuib.ttf", 208), (255, 255, 255), (196, 186, 255), spacing=2)

    # accent bar
    bar = vertical_gradient((110, 10), VIOLET, CORAL)
    base.paste(bar, (188, 640), rounded_mask((110, 10), 5))

    draw.text((184, 682), "液态玻璃音乐播放器", font=font("msyhbd.ttc", 82), fill=(236, 231, 248))
    draw.text(
        (188, 812),
        "连接你自己的音乐服务器，一个 App 听遍整个曲库",
        font=font("msyh.ttc", 40),
        fill=(158, 149, 184),
    )
    draw.text((188, 1000), "Flutter  ·  Android 8.0+  ·  Musix Hub API", font=font("segoeui.ttf", 26), fill=(110, 103, 132))

    out.parent.mkdir(parents=True, exist_ok=True)
    base.save(out, optimize=True)
    print(f"wrote {out} ({W}x{H})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="docs/banner.png")
    args = parser.parse_args()
    build(Path(args.out))
