"""Draws the app icon «Книга и фокус» (docs/design/name-icon.html, №3; export
spec — docs/design/polish.md) into the Android and iOS resources.

Run from the repository root:
    uv run --with pillow python -I tool/icons/build_icons.py
"""

import json
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
BACKGROUND = "#E4DCF1"
COVER = "#7462A6"
LEFT_PAGE = "#FAF8FF"
RIGHT_PAGE = "#EFEAFA"
DOT = "#C2492F"

# Shapes in a 1024 box: moves, cubic curves and lines, as in the SVG.
COVER_PATH = [
    ("M", 512, 740),
    ("C", 430, 690, 340, 680, 240, 700),
    ("L", 240, 400),
    ("C", 340, 380, 430, 390, 512, 440),
    ("C", 594, 390, 684, 380, 784, 400),
    ("L", 784, 700),
    ("C", 684, 680, 594, 690, 512, 740),
]
LEFT_PATH = [
    ("M", 512, 690),
    ("C", 436, 648, 350, 636, 270, 652),
    ("L", 270, 390),
    ("C", 350, 374, 436, 384, 512, 430),
]
RIGHT_PATH = [
    ("M", 512, 690),
    ("C", 588, 648, 674, 636, 754, 652),
    ("L", 754, 390),
    ("C", 674, 374, 588, 384, 512, 430),
]
DOT_CENTER, DOT_RADIUS = (512, 300), 46

# Drawn this big, then made smaller: smooth edges.
MASTER = 4096


def points(path, scale):
    """The path as a polygon in a MASTER box, shrunk by scale about the
    centre."""
    k = MASTER / 1024

    def at(x, y):
        return (
            (512 + (x - 512) * scale) * k,
            (512 + (y - 512) * scale) * k,
        )

    out = []
    x0 = y0 = 0
    for op, *args in path:
        if op in ("M", "L"):
            x0, y0 = args
            out.append(at(x0, y0))
        else:
            x1, y1, x2, y2, x3, y3 = args
            for i in range(1, 49):
                t = i / 48
                u = 1 - t
                x = u**3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3
                y = u**3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3
                out.append(at(x, y))
            x0, y0 = x3, y3
    return out


def dot_box(scale):
    k = MASTER / 1024
    cx, cy = DOT_CENTER
    x = (512 + (cx - 512) * scale) * k
    y = (512 + (cy - 512) * scale) * k
    r = DOT_RADIUS * scale * k
    return (x - r, y - r, x + r, y + r)


def motif(scale, background=None, corner=0.0):
    """The book and the dot; on a square of background if given, with
    rounded corners (a part of the side) if corner."""
    image = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if background:
        draw.rounded_rectangle(
            (0, 0, MASTER - 1, MASTER - 1),
            radius=int(MASTER * corner),
            fill=background,
        )
    draw.polygon(points(COVER_PATH, scale), fill=COVER)
    draw.polygon(points(LEFT_PATH, scale), fill=LEFT_PAGE)
    draw.polygon(points(RIGHT_PATH, scale), fill=RIGHT_PAGE)
    draw.ellipse(dot_box(scale), fill=DOT)
    return image


def monochrome(scale):
    """Android 13 themed icon: one color, the pages cut out."""
    mask = Image.new("L", (MASTER, MASTER), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(points(COVER_PATH, scale), fill=255)
    draw.polygon(points(LEFT_PATH, scale), fill=0)
    draw.polygon(points(RIGHT_PATH, scale), fill=0)
    draw.ellipse(dot_box(scale), fill=255)
    image = Image.new("RGBA", (MASTER, MASTER), (255, 255, 255, 0))
    image.putalpha(mask)
    return image


def save(image, path, size, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    small = image.resize((size, size), Image.LANCZOS)
    if rgb:
        small = small.convert("RGB")
    small.save(path, optimize=True)


def android():
    res = ROOT / "android/app/src/main/res"
    # Inside the adaptive icon's safe circle (polish.md: 0.88).
    adaptive = 0.88
    legacy = motif(adaptive, BACKGROUND, corner=0.2)
    foreground = motif(adaptive)
    mono = monochrome(adaptive)
    for name, scale in {
        "mdpi": 1,
        "hdpi": 1.5,
        "xhdpi": 2,
        "xxhdpi": 3,
        "xxxhdpi": 4,
    }.items():
        folder = res / f"mipmap-{name}"
        save(legacy, folder / "ic_launcher.png", round(48 * scale))
        save(foreground, folder / "ic_launcher_foreground.png", round(108 * scale))
        save(mono, folder / "ic_launcher_monochrome.png", round(108 * scale))
    (res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    (res / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">{BACKGROUND}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )


def ios():
    # Square, no transparency: iOS rounds the corners itself.
    full = motif(1.0, BACKGROUND)
    folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text(encoding="utf-8"))
    for item in contents["images"]:
        side = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        save(full, folder / item["filename"], round(side * scale), rgb=True)


if __name__ == "__main__":
    android()
    ios()
