#!/usr/bin/env python3
"""Write a small labeled JPEG to stdout (for QA gallery seed uploads)."""
from __future__ import annotations

import argparse
import io
import sys

from PIL import Image, ImageDraw, ImageFont


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", required=True, help="Caption drawn on the image")
    parser.add_argument(
        "--hue",
        type=int,
        default=140,
        help="Background hue 0-360",
    )
    args = parser.parse_args()

    w, h = 640, 480
    hue = args.hue % 360
    # Simple HSV-ish block color without colorsys dependency noise
    r = int(180 + (hue % 80))
    g = int(160 + ((hue + 40) % 70))
    b = int(140 + ((hue + 80) % 90))
    img = Image.new("RGB", (w, h), (r % 256, g % 256, b % 256))
    draw = ImageDraw.Draw(img)
    font = _font(28)
    draw.multiline_text(
        (32, h // 2 - 40),
        args.label,
        fill=(28, 46, 23),
        font=font,
        spacing=8,
    )

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85, optimize=True)
    sys.stdout.buffer.write(buf.getvalue())


if __name__ == "__main__":
    main()
