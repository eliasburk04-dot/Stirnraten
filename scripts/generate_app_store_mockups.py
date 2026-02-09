#!/usr/bin/env python3
"""
Generate App Store marketing mockups with frontal phone renders.

This script is intentionally conservative: it keeps the 2 existing mockups in
docs/app_store_mockups and generates exactly 3 additional portrait mockups from
the latest screenshots in ~/Downloads, so the folder ends up with exactly 5
images total.
"""

from __future__ import annotations

from pathlib import Path
from typing import Tuple
from urllib.request import urlopen

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
OUT_DIR = ROOT / "docs" / "app_store_mockups"
FONT_CACHE_DIR = ROOT / ".cache" / "mockup_fonts"

SRC_HOME = DOWNLOADS / "IMG_4259.PNG"
SRC_CATEGORIES = DOWNLOADS / "IMG_4260.PNG"
SRC_GAMEPLAY = DOWNLOADS / "IMG_4261.PNG"
SRC_GAMEPLAY_ALT = DOWNLOADS / "IMG_4267.PNG"
SRC_SETTINGS = DOWNLOADS / "IMG_4263.PNG"
SRC_RESULTS = DOWNLOADS / "IMG_4265.PNG"

# New (Feb 2026) screenshots from current UI.
SRC_CATEGORIES_SETTINGS_NEW = DOWNLOADS / "IMG_4275.PNG"
SRC_AI_WORDLIST_NEW = DOWNLOADS / "IMG_4276.PNG"
SRC_CUSTOM_WORDLISTS_NEW = DOWNLOADS / "IMG_4277.PNG"

PORTRAIT_SIZE = (1290, 2796)
LANDSCAPE_SIZE = (2796, 1290)

FREDOKA_VAR_NAME = "Fredoka-Var.ttf"
NUNITO_VAR_NAME = "Nunito-Var.ttf"

# Remove iOS status bar area (time, signal, battery) from portrait screenshots.
# Ratio is conservative to avoid cutting useful UI content.
STATUS_BAR_CROP_RATIO = 0.055

# Google Fonts raw (open-source). Download on demand into .cache so the script is repeatable.
FONT_URLS = {
    # Variable fonts (supported by Pillow / FreeType on macOS).
    FREDOKA_VAR_NAME: "https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf",
    NUNITO_VAR_NAME: "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf",
}


def _download_font(name: str) -> Path | None:
    url = FONT_URLS.get(name)
    if not url:
        return None
    try:
        FONT_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        dest = FONT_CACHE_DIR / name
        if dest.exists() and dest.stat().st_size > 10_000:
            return dest
        with urlopen(url, timeout=12) as r:
            data = r.read()
        if len(data) < 10_000:
            return None
        dest.write_bytes(data)
        return dest
    except Exception:
        return None


def _resolve_font_path(candidate: str) -> Path | None:
    # Absolute path.
    p = Path(candidate)
    if p.is_absolute() and p.exists():
        return p

    # Cache.
    cached = FONT_CACHE_DIR / candidate
    if cached.exists():
        return cached

    # Try to download by known name.
    downloaded = _download_font(candidate)
    if downloaded is not None and downloaded.exists():
        return downloaded

    # Try common font dirs (in case user has it installed).
    for base in (
        Path("/System/Library/Fonts"),
        Path("/System/Library/Fonts/Supplemental"),
        Path("/Library/Fonts"),
        Path.home() / "Library" / "Fonts",
    ):
        hit = next(base.glob(f"*{candidate.replace('.ttf','')}*"), None)
        if hit and hit.exists():
            return hit
    return None


def load_font_bold(size: int) -> ImageFont.ImageFont:
    # Title font (Fredoka) with a bold weight.
    try:
        path = _resolve_font_path(FREDOKA_VAR_NAME)
        if path and path.exists():
            font = ImageFont.truetype(str(path), size=size)
            if hasattr(font, "set_variation_by_axes"):
                # axes: Weight (300..700), Width (75..125)
                font.set_variation_by_axes([700, 100])
            return font
    except Exception:
        pass

    # Fallbacks.
    for cand in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        path = _resolve_font_path(cand)
        if path and path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def load_font_regular(size: int) -> ImageFont.ImageFont:
    # Subtitle font (Nunito) with a semibold-ish weight.
    try:
        path = _resolve_font_path(NUNITO_VAR_NAME)
        if path and path.exists():
            font = ImageFont.truetype(str(path), size=size)
            if hasattr(font, "set_variation_by_axes"):
                # axis: Weight (200..1000)
                font.set_variation_by_axes([650])
            return font
    except Exception:
        pass

    # Fallbacks.
    for cand in ("/System/Library/Fonts/Supplemental/Arial.ttf",):
        path = _resolve_font_path(cand)
        if path and path.exists():
            return ImageFont.truetype(str(path), size=size)
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


def wrap_lines(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    if not words:
        return [text]
    lines: list[str] = []
    current: list[str] = []
    for w in words:
        candidate = " ".join(current + [w])
        box = draw.textbbox((0, 0), candidate, font=font)
        if box[2] - box[0] <= max_width or not current:
            current.append(w)
            continue
        lines.append(" ".join(current))
        current = [w]
    if current:
        lines.append(" ".join(current))
    return lines


def draw_text_center(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    size: int,
    color: Tuple[int, int, int],
    width: int,
    *,
    max_width_ratio: float = 0.92,
    is_title: bool = True,
) -> None:
    font = load_font_bold(size) if is_title else load_font_regular(size)
    max_w = int(width * max_width_ratio)
    lines = wrap_lines(draw, text, font, max_w)

    # If still too wide (very long title), shrink a bit.
    while len(lines) > 2 and size > 44:
        size -= 4
        font = load_font_bold(size) if is_title else load_font_regular(size)
        lines = wrap_lines(draw, text, font, max_w)

    line_h = int(size * (1.15 if is_title else 1.25))
    for i, line in enumerate(lines[:2]):
        box = draw.textbbox((0, 0), line, font=font)
        tw = box[2] - box[0]
        x = (width - tw) // 2
        yy = y + i * line_h
        # Subtle shadow for legibility on gradients.
        draw.text((x, yy + 2), line, font=font, fill=(0, 0, 0, 40))
        draw.text((x, yy), line, font=font, fill=color)


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
    # iPhone-ish front render (modern flat sides + Dynamic Island).
    # Not a real iPhone 17 CAD, but matches the current "iPhone" visual language.
    draw.rounded_rectangle((x0, y0, x1, y1), radius=corner, fill=(16, 18, 22))
    draw.rounded_rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), radius=corner - 2, outline=(96, 102, 112), width=2)
    # Subtle rim highlight.
    rim = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rim)
    rdraw.rounded_rectangle((x0 + 6, y0 + 6, x1 - 6, y1 - 6), radius=corner - 6, outline=(255, 255, 255, 28), width=2)
    rim = rim.filter(ImageFilter.GaussianBlur(radius=1))
    canvas.alpha_composite(rim)

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

    # Note: We intentionally do NOT draw a notch/dynamic-island overlay in mockups,
    # so the top area stays clean for marketing screenshots.


def build_portrait_mockup(src: Path, title: str, subtitle: str, out_name: str) -> None:
    bg = gradient_canvas(PORTRAIT_SIZE, (255, 235, 126), (255, 120, 126)).convert("RGBA")
    add_soft_glow(bg, (220, 2280), 360, (130, 255, 255, 120))
    add_soft_glow(bg, (1080, 600), 320, (255, 230, 160, 120))

    draw = ImageDraw.Draw(bg)
    draw_text_center(draw, title, 120, 76, (24, 31, 53), PORTRAIT_SIZE[0], is_title=True)
    draw_text_center(draw, subtitle, 222, 44, (53, 63, 89), PORTRAIT_SIZE[0], is_title=False)

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
    draw_text_center(draw, "Action im Querformat", 120, 76, (255, 255, 255), PORTRAIT_SIZE[0], is_title=True)
    draw_text_center(draw, "Neigen, raten, Punkte holen", 222, 44, (255, 244, 230), PORTRAIT_SIZE[0], is_title=False)

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
    draw_text_center(draw, title, 72, 84, (255, 255, 255), LANDSCAPE_SIZE[0], is_title=True)
    if subtitle:
      draw_text_center(draw, subtitle, 168, 44, (255, 244, 230), LANDSCAPE_SIZE[0], is_title=False)

    shot = Image.open(src).convert("RGB")
    phone_w, phone_h = 2240, 980
    x0 = (LANDSCAPE_SIZE[0] - phone_w) // 2
    y0 = 180
    draw_phone(bg, shot, (x0, y0, x0 + phone_w, y0 + phone_h), corner=120, bezel=36)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(OUT_DIR / out_name, format="PNG", optimize=True)


def assert_sources() -> None:
    missing = [str(p) for p in (SRC_CATEGORIES_SETTINGS_NEW, SRC_AI_WORDLIST_NEW, SRC_CUSTOM_WORDLISTS_NEW) if not p.exists()]
    if missing:
        raise FileNotFoundError(
            "Missing screenshots in ~/Downloads:\n"
            + "\n".join(missing)
            + "\n\nExport 3 iPhone portrait screenshots to Downloads as:\n"
            + "- IMG_4275.PNG (Kategorien/Einstellungen)\n"
            + "- IMG_4276.PNG (KI-Woerterliste)\n"
            + "- IMG_4277.PNG (Eigene Woerter / gespeicherte Liste)\n"
        )


def prune_out_dir(keep: set[str]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for p in OUT_DIR.glob("*.png"):
        if p.name not in keep:
            p.unlink()


def main() -> None:
    assert_sources()

    # Keep the existing 2 images already checked in.
    keep = {
        "01_startscreen_1290x2796.png",
        "06_auswertung_1290x2796.png",
        # Newly generated (this script):
        "02_kategorien_1290x2796.png",
        "03_ki_woerterlisten_1290x2796.png",
        "04_eigene_listen_1290x2796.png",
    }

    build_portrait_mockup(
        SRC_CUSTOM_WORDLISTS_NEW,
        "Erstelle eigene Kategorien mit KI",
        "Deine Begriffe, jederzeit spielbereit",
        "02_kategorien_1290x2796.png",
    )
    build_portrait_mockup(
        SRC_AI_WORDLIST_NEW,
        "Erstelle eigene Listen mit KI oder per Hand",
        "Schnell anpassen und losspielen",
        "03_ki_woerterlisten_1290x2796.png",
    )
    build_portrait_mockup(
        SRC_CATEGORIES_SETTINGS_NEW,
        "Entdecke spannende Modi",
        "Klassisch, K.o., Schwer, Trinkspiel",
        "04_eigene_listen_1290x2796.png",
    )

    # Ensure we only keep the 5 final mockups.
    prune_out_dir(keep)
    print(f"Mockups generated in: {OUT_DIR}")


if __name__ == "__main__":
    main()
