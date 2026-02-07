#!/usr/bin/env python3
"""
Generate App Store marketing mockups with frontal phone renders.

Source screenshots are expected in ~/Downloads:
- IMG_4259.PNG (home/start)
- IMG_4260.PNG (categories)
- IMG_4261.PNG (gameplay landscape)
- IMG_4263.PNG (categories + settings sheet)
- IMG_4265.PNG (result screen)
"""

from __future__ import annotations

from pathlib import Path
from typing import Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
OUT_DIR = ROOT / "docs" / "app_store_mockups"

SRC_HOME = DOWNLOADS / "IMG_4259.PNG"
SRC_CATEGORIES = DOWNLOADS / "IMG_4260.PNG"
SRC_GAMEPLAY = DOWNLOADS / "IMG_4261.PNG"
SRC_GAMEPLAY_ALT = DOWNLOADS / "IMG_4267.PNG"
SRC_SETTINGS = DOWNLOADS / "IMG_4263.PNG"
SRC_RESULTS = DOWNLOADS / "IMG_4265.PNG"

PORTRAIT_SIZE = (1290, 2796)
LANDSCAPE_SIZE = (2796, 1290)

FONT_BOLD_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
]

# Remove iOS status bar area (time, signal, battery) from portrait screenshots.
# Ratio is conservative to avoid cutting useful UI content.
STATUS_BAR_CROP_RATIO = 0.055


def load_font(size: int) -> ImageFont.ImageFont:
    for path in FONT_BOLD_CANDIDATES:
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def gradient_canvas(size: Tuple[int, int], c1: Tuple[int, int, int], c2: Tuple[int, int, int]) -> Image.Image:
    w, h = size
    canvas = Image.new("RGB", size)
    pix = canvas.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(c1[0] * (1 - t) + c2[0] * t)
        g = int(c1[1] * (1 - t) + c2[1] * t)
        b = int(c1[2] * (1 - t) + c2[2] * t)
        for x in range(w):
            pix[x, y] = (r, g, b)
    return canvas


def add_soft_glow(base: Image.Image, xy: Tuple[int, int], radius: int, color: Tuple[int, int, int, int]) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    x, y = xy
    gdraw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=80))
    base.alpha_composite(glow)


def fit_cover(img: Image.Image, size: Tuple[int, int]) -> Image.Image:
    src_w, src_h = img.size
    dst_w, dst_h = size
    src_ratio = src_w / src_h
    dst_ratio = dst_w / dst_h
    if src_ratio > dst_ratio:
        new_h = dst_h
        new_w = int(new_h * src_ratio)
    else:
        new_w = dst_w
        new_h = int(new_w / src_ratio)
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = (new_w - dst_w) // 2
    top = (new_h - dst_h) // 2
    return resized.crop((left, top, left + dst_w, top + dst_h))


def preprocess_screenshot(img: Image.Image) -> Image.Image:
    """Strip status bar from portrait screenshots before framing."""
    w, h = img.size
    if h <= w:
        return img
    crop_px = int(h * STATUS_BAR_CROP_RATIO)
    if crop_px <= 0 or crop_px >= h - 8:
        return img
    return img.crop((0, crop_px, w, h))


def draw_text_center(draw: ImageDraw.ImageDraw, text: str, y: int, size: int, color: Tuple[int, int, int], width: int) -> None:
    font = load_font(size)
    box = draw.textbbox((0, 0), text, font=font)
    tw = box[2] - box[0]
    x = (width - tw) // 2
    draw.text((x, y), text, font=font, fill=color)


def draw_phone(
    canvas: Image.Image,
    screenshot: Image.Image,
    body_box: Tuple[int, int, int, int],
    corner: int,
    bezel: int,
) -> None:
    x0, y0, x1, y1 = body_box

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((x0 + 8, y0 + 16, x1 + 8, y1 + 16), radius=corner, fill=(0, 0, 0, 95))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x0, y0, x1, y1), radius=corner, fill=(18, 22, 30))
    draw.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), radius=corner - 3, outline=(78, 84, 96), width=2)

    sx0 = x0 + bezel
    sy0 = y0 + bezel
    sx1 = x1 - bezel
    sy1 = y1 - bezel
    screen_w = sx1 - sx0
    screen_h = sy1 - sy0

    prepared = preprocess_screenshot(screenshot.convert("RGB"))
    screen = fit_cover(prepared, (screen_w, screen_h))
    mask = Image.new("L", (screen_w, screen_h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((0, 0, screen_w, screen_h), radius=max(12, int(corner * 0.55)), fill=255)
    canvas.paste(screen, (sx0, sy0), mask)

    # Speaker / camera hint for a "real phone" look.
    top_cy = y0 + int(bezel * 0.58)
    mid_x = (x0 + x1) // 2
    draw.rounded_rectangle((mid_x - 80, top_cy - 7, mid_x + 80, top_cy + 7), radius=7, fill=(34, 37, 46))
    draw.ellipse((mid_x + 96, top_cy - 8, mid_x + 112, top_cy + 8), fill=(34, 37, 46))


def build_portrait_mockup(src: Path, title: str, subtitle: str, out_name: str) -> None:
    bg = gradient_canvas(PORTRAIT_SIZE, (255, 235, 126), (255, 120, 126)).convert("RGBA")
    add_soft_glow(bg, (220, 2280), 360, (130, 255, 255, 120))
    add_soft_glow(bg, (1080, 600), 320, (255, 230, 160, 120))

    draw = ImageDraw.Draw(bg)
    draw_text_center(draw, title, 120, 76, (24, 31, 53), PORTRAIT_SIZE[0])
    draw_text_center(draw, subtitle, 222, 44, (53, 63, 89), PORTRAIT_SIZE[0])

    shot = Image.open(src).convert("RGB")
    phone_w, phone_h = 1020, 2180
    x0 = (PORTRAIT_SIZE[0] - phone_w) // 2
    y0 = 420
    draw_phone(bg, shot, (x0, y0, x0 + phone_w, y0 + phone_h), corner=140, bezel=50)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(OUT_DIR / out_name, format="PNG", optimize=True)


def build_portrait_gameplay_mockup(src: Path, out_name: str) -> None:
    bg = gradient_canvas(PORTRAIT_SIZE, (255, 218, 96), (255, 93, 86)).convert("RGBA")
    add_soft_glow(bg, (150, 2400), 360, (255, 180, 100, 120))
    add_soft_glow(bg, (1060, 700), 300, (255, 255, 180, 120))
    draw = ImageDraw.Draw(bg)
    draw_text_center(draw, "Action im Querformat", 120, 76, (255, 255, 255), PORTRAIT_SIZE[0])
    draw_text_center(draw, "Neigen, raten, Punkte holen", 222, 44, (255, 244, 230), PORTRAIT_SIZE[0])

    shot = Image.open(src).convert("RGB")
    phone_w, phone_h = 1140, 590
    x0 = (PORTRAIT_SIZE[0] - phone_w) // 2
    y0 = 990
    draw_phone(bg, shot, (x0, y0, x0 + phone_w, y0 + phone_h), corner=90, bezel=22)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(OUT_DIR / out_name, format="PNG", optimize=True)


def build_landscape_gameplay_mockup(
    src: Path,
    out_name: str,
    title: str = "Stirnraten Gameplay",
    subtitle: str | None = None,
) -> None:
    bg = gradient_canvas(LANDSCAPE_SIZE, (255, 215, 95), (255, 97, 88)).convert("RGBA")
    add_soft_glow(bg, (350, 1060), 290, (255, 255, 170, 110))
    add_soft_glow(bg, (2360, 250), 290, (255, 150, 130, 110))
    draw = ImageDraw.Draw(bg)
    draw_text_center(draw, title, 72, 84, (255, 255, 255), LANDSCAPE_SIZE[0])
    if subtitle:
      draw_text_center(draw, subtitle, 168, 44, (255, 244, 230), LANDSCAPE_SIZE[0])

    shot = Image.open(src).convert("RGB")
    phone_w, phone_h = 2240, 980
    x0 = (LANDSCAPE_SIZE[0] - phone_w) // 2
    y0 = 180
    draw_phone(bg, shot, (x0, y0, x0 + phone_w, y0 + phone_h), corner=120, bezel=36)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(OUT_DIR / out_name, format="PNG", optimize=True)


def assert_sources() -> None:
    missing = [
        str(p)
        for p in (
            SRC_HOME,
            SRC_CATEGORIES,
            SRC_GAMEPLAY,
            SRC_GAMEPLAY_ALT,
            SRC_SETTINGS,
            SRC_RESULTS,
        )
        if not p.exists()
    ]
    if missing:
        joined = "\n".join(missing)
        raise FileNotFoundError(f"Missing screenshots:\n{joined}")


def main() -> None:
    assert_sources()
    build_portrait_mockup(
        SRC_HOME,
        "Schnell starten",
        "Perfekt für jede Partyrunde",
        "01_startscreen_1290x2796.png",
    )
    build_portrait_mockup(
        SRC_CATEGORIES,
        "Viele Kategorien",
        "Finde sofort die passende Runde",
        "02_kategorien_1290x2796.png",
    )
    build_portrait_gameplay_mockup(
        SRC_GAMEPLAY,
        "03_gameplay_1290x2796.png",
    )
    build_portrait_mockup(
        SRC_SETTINGS,
        "Einstellungen direkt im Spiel",
        "Alles schnell anpassen",
        "05_einstellungen_1290x2796.png",
    )
    build_portrait_mockup(
        SRC_RESULTS,
        "Runde beendet",
        "Ergebnisse übersichtlich sehen",
        "06_auswertung_1290x2796.png",
    )
    build_landscape_gameplay_mockup(
        SRC_GAMEPLAY,
        "04_gameplay_landscape_2796x1290.png",
    )
    build_landscape_gameplay_mockup(
        SRC_GAMEPLAY_ALT,
        "07_gameplay_havana_2796x1290.png",
        title="Schnelle Runden",
        subtitle="Ratebegriffe in Sekunden",
    )
    print(f"Mockups generated in: {OUT_DIR}")


if __name__ == "__main__":
    main()
