#!/usr/bin/env python3
"""
Build a launch-ready app icon set from a 1024x1024 source image.

Why this script exists:
- iOS App Store icon must be opaque (no alpha channel).
- A source image with white canvas around the artwork can look like an extra
  background plate on the home screen.
- We preserve the original artwork and only recolor bright edge canvas pixels
  so the icon stays full-bleed and readable at small sizes.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, Tuple

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = Path.home() / "Downloads" / "97bcd647-706e-421e-9637-55a96b932aab.png"
MASTER_OUTPUT = ROOT / "assets/images/App_Icon.png"
IOS_DIR = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_DIR = ROOT / "android/app/src/main/res"

# Warm palette aligned with the game's current visual language.
TL = (255, 214, 40)
TR = (255, 134, 56)
BL = (255, 139, 36)
BR = (255, 75, 118)


def clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if v < lo else hi if v > hi else v


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix_rgb(a: Tuple[int, int, int], b: Tuple[int, int, int], t: float) -> Tuple[int, int, int]:
    return (
        int(round(lerp(a[0], b[0], t))),
        int(round(lerp(a[1], b[1], t))),
        int(round(lerp(a[2], b[2], t))),
    )


def make_gradient(size: int = 1024) -> Image.Image:
    grad = Image.new("RGB", (size, size))
    pix = grad.load()
    last = float(size - 1)
    for y in range(size):
        ty = y / last
        left = mix_rgb(TL, BL, ty)
        right = mix_rgb(TR, BR, ty)
        for x in range(size):
            tx = x / last
            pix[x, y] = mix_rgb(left, right, tx)
    return grad


def prep_source(source: Path) -> Image.Image:
    src = Image.open(source).convert("RGB")
    if src.size != (1024, 1024):
        src = src.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Slight zoom improves legibility for small icon sizes.
    zoom = 1.03
    zw = int(round(1024 * zoom))
    zh = int(round(1024 * zoom))
    ox = (zw - 1024) // 2
    oy = (zh - 1024) // 2
    src = src.resize((zw, zh), Image.Resampling.LANCZOS).crop((ox, oy, ox + 1024, oy + 1024))
    return src


def blend_edge_canvas(src: Image.Image, gradient: Image.Image) -> Image.Image:
    out = Image.new("RGB", src.size)
    src_px = src.load()
    bg_px = gradient.load()
    out_px = out.load()
    w, h = src.size
    edge_soft = 220.0

    for y in range(h):
        for x in range(w):
            r, g, b = src_px[x, y]
            br = (r + g + b) / 3.0
            chroma = max(r, g, b) - min(r, g, b)

            dist = min(x, y, (w - 1) - x, (h - 1) - y)
            edge = clamp((edge_soft - dist) / edge_soft)

            # Detect bright neutral canvas near edges and remap it to game colors.
            white = clamp((br - 225.0) / 30.0)
            neutral = clamp((40.0 - chroma) / 40.0)
            alpha = edge * white * neutral

            # Also catch bright edge glow that trends to near-white.
            bright_glow = edge * clamp((br - 244.0) / 10.0) * 0.65
            alpha = max(alpha, bright_glow)
            alpha = clamp(alpha)

            if alpha <= 0.001:
                out_px[x, y] = (r, g, b)
                continue

            rb, gb, bb = bg_px[x, y]
            out_px[x, y] = (
                int(round(r * (1.0 - alpha) + rb * alpha)),
                int(round(g * (1.0 - alpha) + gb * alpha)),
                int(round(b * (1.0 - alpha) + bb * alpha)),
            )

    out = ImageEnhance.Color(out).enhance(1.07)
    out = ImageEnhance.Contrast(out).enhance(1.05)
    out = out.filter(ImageFilter.UnsharpMask(radius=1.3, percent=105, threshold=2))
    return out


def save_master(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def export_ios(master: Image.Image) -> None:
    specs = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    IOS_DIR.mkdir(parents=True, exist_ok=True)
    for name, size in specs.items():
        out = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        out.save(IOS_DIR / name, format="PNG", optimize=True)


def export_android(master: Image.Image) -> None:
    specs: Dict[str, int] = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for rel, size in specs.items():
        dst = ANDROID_DIR / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(dst, format="PNG", optimize=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate iOS/Android app icons from a 1024x1024 source PNG.")
    parser.add_argument(
        "--source",
        type=Path,
        help="Path to source PNG (defaults to ~/Downloads/<latest icon candidate>).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = args.source or (DEFAULT_INPUT if DEFAULT_INPUT.exists() else MASTER_OUTPUT)
    src = prep_source(source)
    gradient = make_gradient(1024)
    master = blend_edge_canvas(src, gradient)
    save_master(master, MASTER_OUTPUT)
    export_ios(master)
    export_android(master)
    print(f"Built icons from: {source}")
    print(f"Master icon: {MASTER_OUTPUT}")


if __name__ == "__main__":
    main()
