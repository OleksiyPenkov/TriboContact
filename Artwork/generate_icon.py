import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ICO_PATH = os.path.join(HERE, "Windows", "AppIcon.ico")
PNG_PATH = os.path.join(HERE, "AppIcon.png")
UWP44_PATH = os.path.join(HERE, "Windows", "Uwp_44.png")
UWP150_PATH = os.path.join(HERE, "Windows", "Uwp_150.png")
HELP_LOGO_PATH = os.path.join(ROOT, "Help", "images", "logo.png")

ICON_SIZES = (16, 20, 24, 32, 40, 48, 64, 256)
BADGE_MIN_SIZE = 48

PLATE = (14, 42, 74, 255)
BORDER = (52, 152, 219, 255)
GRID = (30, 95, 138, 255)
CYAN = (0, 229, 255, 255)
TEAL = (60, 180, 220, 255)
CYAN_FILL_TOP = (0, 229, 255, 70)
TEAL_FILL = (60, 180, 220, 48)
SLATE_FILL = (141, 153, 166, 40)
BALL_FILL = (0, 229, 255, 42)
HEAD_FILL = (141, 153, 166, 56)
GOLD = (255, 213, 79, 240)
GOLD_SOFT = (255, 213, 79, 135)
MAGENTA = (255, 45, 149, 255)
MAGENTA_MID = (255, 110, 199, 225)
HALO_OUTER = (255, 45, 149, 95)


def _composite(img, draw_fn):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return Image.alpha_composite(img, layer)


def _load_font(pixels):
    for name in ("consola.ttf", "cour.ttf"):
        try:
            return ImageFont.truetype(name, pixels)
        except OSError:
            continue
    return ImageFont.load_default()


def _draw_badge(draw, unit):
    text = "APS"
    font = _load_font(max(unit(10.5), 6))
    widths = [draw.textlength(ch, font=font) for ch in text]
    gap = unit(2.0)
    total = sum(widths) + gap * (len(text) - 1)
    box = draw.textbbox((0, 0), text, font=font)
    x = unit(60) - total / 2.0
    y = unit(19.5) - (box[3] - box[1]) / 2.0 - box[1]
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=CYAN)
        x += w + gap


def draw_icon(size):
    supersampled = max(size * 4, 512)
    scale = supersampled / 120.0

    def unit(val):
        return int(round(val * scale))

    def stroke(val):
        return max(1, int(round(val * scale)))

    img = Image.new("RGBA", (supersampled, supersampled), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle(
        [unit(5), unit(5), unit(115), unit(115)],
        radius=unit(8),
        fill=PLATE,
        outline=BORDER,
        width=stroke(2.2),
    )

    for g in (30, 55, 80):
        draw.line([unit(5), unit(g), unit(115), unit(g)], fill=GRID, width=stroke(0.6))
    for g in (30, 60, 90):
        draw.line([unit(g), unit(5), unit(g), unit(115)], fill=GRID, width=stroke(0.6))

    if size >= BADGE_MIN_SIZE:
        badge_rect = [unit(40), unit(12), unit(80), unit(27)]
        img = _composite(img, lambda d: d.rounded_rectangle(badge_rect, radius=unit(3), fill=HEAD_FILL))
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle(badge_rect, radius=unit(3), outline=BORDER, width=stroke(1.4))
        _draw_badge(draw, unit)

        glow_arrow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_arrow)
        gd.line([unit(60), unit(27), unit(60), unit(36)], fill=MAGENTA_MID, width=stroke(2.6))
        gd.line([unit(55), unit(32), unit(60), unit(37)], fill=MAGENTA_MID, width=stroke(2.4))
        gd.line([unit(65), unit(32), unit(60), unit(37)], fill=MAGENTA_MID, width=stroke(2.4))
        img = Image.alpha_composite(img, glow_arrow.filter(ImageFilter.GaussianBlur(unit(1.5))))
        img = Image.alpha_composite(img, glow_arrow)

    lobe = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lobe)
    ld.ellipse([unit(33), unit(65), unit(87), unit(103)], fill=HALO_OUTER)
    ld.ellipse([unit(43), unit(70), unit(77), unit(94)], fill=GOLD_SOFT)
    ld.ellipse([unit(46), unit(72), unit(74), unit(88)], outline=GOLD, width=stroke(2.0))
    ld.ellipse([unit(39), unit(70), unit(81), unit(97)], outline=MAGENTA_MID, width=stroke(1.8))
    img = Image.alpha_composite(img, lobe.filter(ImageFilter.GaussianBlur(unit(1.8))))
    img = Image.alpha_composite(img, lobe)

    film_top = [unit(18), unit(65), unit(102), unit(75)]
    film_mid = [unit(18), unit(75), unit(102), unit(83)]
    sub_box = [unit(18), unit(83), unit(102), unit(105)]

    img = _composite(img, lambda d: d.rounded_rectangle(film_top, radius=unit(1.5), fill=CYAN_FILL_TOP))
    img = _composite(img, lambda d: d.rectangle(film_mid, fill=TEAL_FILL))
    img = _composite(img, lambda d: d.rounded_rectangle(sub_box, radius=unit(2.5), fill=SLATE_FILL))

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(film_top, radius=unit(1.5), outline=CYAN, width=stroke(2.0))
    draw.rectangle(film_mid, outline=TEAL, width=stroke(1.6))
    draw.rounded_rectangle(sub_box, radius=unit(2.5), outline=BORDER, width=stroke(2.0))

    ball = [unit(45.5), unit(36.5), unit(74.5), unit(65.5)]
    img = _composite(img, lambda d: d.ellipse(ball, fill=BALL_FILL))
    draw = ImageDraw.Draw(img)
    draw.ellipse(ball, outline=CYAN, width=stroke(2.6))

    patch = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(patch)
    pd.line([unit(45), unit(65), unit(75), unit(65)], fill=MAGENTA, width=stroke(3.2))
    img = Image.alpha_composite(img, patch.filter(ImageFilter.GaussianBlur(unit(1.8))))
    img = Image.alpha_composite(img, patch)

    if supersampled != size:
        img = img.resize((size, size), Image.LANCZOS)
    return img


def main():
    os.makedirs(os.path.dirname(ICO_PATH), exist_ok=True)
    os.makedirs(os.path.dirname(HELP_LOGO_PATH), exist_ok=True)
    images = {s: draw_icon(s) for s in ICON_SIZES}
    biggest = max(ICON_SIZES)
    images[biggest].save(
        ICO_PATH,
        format="ICO",
        sizes=[(s, s) for s in ICON_SIZES],
        append_images=[images[s] for s in ICON_SIZES if s != biggest],
    )
    images[biggest].save(PNG_PATH, format="PNG")
    draw_icon(44).save(UWP44_PATH, format="PNG")
    draw_icon(150).save(UWP150_PATH, format="PNG")
    draw_icon(128).save(HELP_LOGO_PATH, format="PNG")
    print("Generated icons:", ICO_PATH, PNG_PATH, UWP44_PATH, UWP150_PATH, HELP_LOGO_PATH)


if __name__ == "__main__":
    main()
