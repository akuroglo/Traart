#!/usr/bin/env python3
"""Generate DMG background image for Traart installer.

Creates a 600x400 @2x (1200x800 pixels) background with:
- Dark gradient background
- "Traart" title + subtitle in teal
- Dashed arrow between app and Applications positions
- "Drag to Applications" hint

Requires: pip install Pillow
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)


# Dimensions (@2x)
W, H = 1200, 800
TEAL = (0, 191, 191)
TEAL_DIM = (0, 140, 140)
WHITE = (255, 255, 255)
ARROW_COLOR = (180, 180, 180)

# Icon positions (logical coords * 2 for @2x)
APP_X = 170 * 2   # 340
APPS_X = 430 * 2  # 860
ICON_Y = 200 * 2  # 400


def create_gradient(draw: ImageDraw.Draw, width: int, height: int):
    """Draw a dark vertical gradient."""
    top = (30, 30, 35)
    bottom = (20, 20, 24)
    for y in range(height):
        ratio = y / height
        r = int(top[0] + (bottom[0] - top[0]) * ratio)
        g = int(top[1] + (bottom[1] - top[1]) * ratio)
        b = int(top[2] + (bottom[2] - top[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))


def draw_dashed_arrow(draw: ImageDraw.Draw, x1: int, y1: int, x2: int, y2: int):
    """Draw a dashed horizontal arrow."""
    dash_len = 16
    gap_len = 10
    x = x1
    while x < x2 - 30:
        end = min(x + dash_len, x2 - 30)
        draw.line([(x, y1), (end, y1)], fill=ARROW_COLOR, width=3)
        x += dash_len + gap_len

    # Arrowhead
    arrow_tip = x2 - 10
    draw.polygon([
        (arrow_tip, y1),
        (arrow_tip - 20, y1 - 12),
        (arrow_tip - 20, y1 + 12),
    ], fill=ARROW_COLOR)


def get_font(size: int, bold: bool = False):
    """Try to load a system font, fall back to default."""
    font_paths = [
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    if bold:
        font_paths = [
            "/System/Library/Fonts/SFNSDisplayBold.ttf",
            "/System/Library/Fonts/HelveticaNeue.ttc",
        ] + font_paths

    for path in font_paths:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except (OSError, Exception):
                continue
    return ImageFont.load_default()


def main():
    output_dir = Path(__file__).parent.parent / "build"
    output_dir.mkdir(exist_ok=True)
    output_path = output_dir / "dmg-background.png"
    output_path_2x = output_dir / "dmg-background@2x.png"

    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)

    # Gradient background
    create_gradient(draw, W, H)

    # Title "Traart"
    title_font = get_font(60, bold=True)
    subtitle_font = get_font(28)
    hint_font = get_font(24)

    # Title at top center
    title_text = "Traart"
    bbox = draw.textbbox((0, 0), title_text, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, 80), title_text, fill=TEAL, font=title_font)

    # Subtitle
    sub_text = "Транскрибация речи"
    bbox = draw.textbbox((0, 0), sub_text, font=subtitle_font)
    sw = bbox[2] - bbox[0]
    draw.text(((W - sw) // 2, 155), sub_text, fill=TEAL_DIM, font=subtitle_font)

    # Dashed arrow between icon positions
    arrow_y = ICON_Y + 10
    draw_dashed_arrow(draw, APP_X + 80, arrow_y, APPS_X - 80, arrow_y)

    # Hint text below icons
    hint_text = "Перетащите в Applications"
    bbox = draw.textbbox((0, 0), hint_text, font=hint_font)
    hw = bbox[2] - bbox[0]
    draw.text(((W - hw) // 2, ICON_Y + 160), hint_text, fill=ARROW_COLOR, font=hint_font)

    # Save @2x version
    img.save(str(output_path_2x), "PNG")

    # Save @1x version (scaled down)
    img_1x = img.resize((W // 2, H // 2), Image.LANCZOS)
    img_1x.save(str(output_path), "PNG")

    print(f"DMG background created:")
    print(f"  @1x: {output_path}")
    print(f"  @2x: {output_path_2x}")


if __name__ == "__main__":
    main()
