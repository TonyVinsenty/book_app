"""Draw the seamless page textures (our own, so no image licenses apply).

Usage:
    python -I tool/textures/build_textures.py assets/textures [preview_dir]

Each tile is a 512x512 grayscale+alpha PNG shown at scale 2 (256 logical
pixels). A pixel is white (lightens the page) or black (darkens it) with a
small alpha, so one tile works over any palette color, day and night.
With [preview_dir], also writes the tiles 2x2 over the light and dark paper
colors to check seams and strength by eye.

Pure Python (no Pillow): the patterns are periodic in the tile size, and
the noise uses a wrapped lattice, so the edges meet without seams.
"""

import math
import random
import struct
import sys
import zlib
from pathlib import Path

SIZE = 512


def png(path, width, height, channels, rows):
    """Writes 8-bit rows (bytes per row) as PNG: 2 = gray+alpha, 3 = RGB."""
    color_type = {2: 4, 3: 2}[channels]
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(
            ">I", zlib.crc32(body)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def value_noise(cells, seed):
    """Smooth noise in about [-1, 1] on a cells x cells lattice that wraps."""
    rng = random.Random(seed)
    lattice = [[rng.uniform(-1, 1) for _ in range(cells)] for _ in range(cells)]
    step = SIZE / cells

    def at(x, y):
        fx, fy = x / step, y / step
        x0, y0 = int(fx), int(fy)
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        x0, y0 = x0 % cells, y0 % cells
        x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
        top = lattice[y0][x0] * (1 - tx) + lattice[y0][x1] * tx
        bottom = lattice[y1][x0] * (1 - tx) + lattice[y1][x1] * tx
        return top * (1 - ty) + bottom * ty

    return at


def fbm(octaves, seed):
    """Sum of [value_noise] octaves: (cells, weight) pairs."""
    layers = [(value_noise(c, seed + i), w) for i, (c, w) in enumerate(octaves)]
    total = sum(w for _, w in layers)
    return lambda x, y: sum(n(x, y) * w for n, w in layers) / total


def paper():
    """Grain and soft blotches of pulp."""
    blotches = fbm([(4, 1), (8, 0.7), (16, 0.5)], 10)
    fibres = fbm([(32, 1), (64, 0.6)], 20)
    grain = value_noise(256, 30)
    return lambda x, y: (
        0.45 * blotches(x, y) + 0.3 * fibres(x, y) + 0.35 * grain(x, y)
    )


def twill():
    """Diagonal ribs of a woven cloth, crossed by thin threads."""
    rib, thread = 16, 8
    noise = fbm([(64, 1), (128, 0.6)], 40)

    def at(x, y):
        ribs = math.sin(2 * math.pi * (x + y) / rib)
        threads = 0.65 + 0.35 * math.sin(2 * math.pi * y / thread)
        return 0.75 * ribs * threads + 0.3 * noise(x, y)

    return at


def scales():
    """Rows of overlapping round scales, each lit at the top, dark rim."""
    r = 32
    noise = fbm([(32, 1), (64, 0.5)], 50)

    def at(x, y):
        # The lowest row covering the pixel is on top.
        for j in range(math.floor(y / r) + 1, math.floor(y / r) - 2, -1):
            cy = j * r
            shift = r if j % 2 else 0
            i = round((x - shift) / (2 * r))
            for k in (i - 1, i, i + 1):
                cx = k * 2 * r + shift
                d = math.hypot(x - cx, y - cy) / r
                if d <= 1:
                    rim = max(0.0, (d - 0.86) / 0.14)
                    lit = 0.5 - 0.9 * d * d + 0.25 * (cy - y) / r
                    return lit * (1 - rim) - rim + 0.15 * noise(x, y)
        return 0.0

    return at


def mattress():
    """Quilted diamonds: puffed cells, sunken stitched seams."""
    cell = 64
    noise = fbm([(64, 1), (128, 0.5)], 60)

    def at(x, y):
        u, v = (x + y) % cell, (x - y) % cell
        du, dv = min(u, cell - u), min(v, cell - v)
        d = min(du, dv) / (cell / 2)
        puff = math.sqrt(d) - 0.55
        # Light from the top left: the upper sides of each cushion.
        light = 0.35 * (((u / cell) - 0.5) + ((0.5 - v / cell))) * -1
        seam = 0.0
        if min(du, dv) < 2.0:
            along = (x - y if du < dv else x + y) % 8
            seam = -1.0 if along < 5 else -0.4
        value = 0.8 * puff + light + 0.12 * noise(x, y)
        return seam if seam else value

    return at


# Name → (pattern, strongest alpha).
TEXTURES = {
    "paper": (paper, 0.10),
    "twill": (twill, 0.07),
    "scales": (scales, 0.08),
    "mattress": (mattress, 0.09),
}


def render(pattern):
    values = [[pattern(x + 0.5, y + 0.5) for x in range(SIZE)] for y in range(SIZE)]
    top = max(abs(v) for row in values for v in row) or 1
    return [[max(-1.0, min(1.0, v / top)) for v in row] for row in values]


def tile_rows(values, strength):
    for row in values:
        out = bytearray()
        for v in row:
            out += bytes((255 if v > 0 else 0, round(abs(v) * strength * 255)))
        yield out


def preview_rows(values, strength, background, opacity):
    for row in values + values:
        out = bytearray()
        for v in row + row:
            white = 255 if v > 0 else 0
            a = abs(v) * strength * opacity
            out += bytes(round(c * (1 - a) + white * a) for c in background)
        yield out


def main():
    out = Path(sys.argv[1])
    preview = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    out.mkdir(parents=True, exist_ok=True)
    for name, (make, strength) in TEXTURES.items():
        values = render(make())
        png(out / f"{name}.png", SIZE, SIZE, 2, tile_rows(values, strength))
        if preview:
            preview.mkdir(parents=True, exist_ok=True)
            for label, color, opacity in (
                ("day", (0xF6, 0xF0, 0xE4), 1.0),
                ("night", (0x1F, 0x1B, 0x17), 0.6),
            ):
                png(
                    preview / f"{name}-{label}.png",
                    SIZE * 2,
                    SIZE * 2,
                    3,
                    preview_rows(values, strength, color, opacity),
                )
        print(name)


if __name__ == "__main__":
    main()
