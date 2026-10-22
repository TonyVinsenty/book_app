"""Tiny images for the fixture books (no Pillow): valid small PNG, GIF and
grayscale JPEG files, and header-only 'huge' ones. Used by
make_fb2_fixtures.py and make_epub_fixtures.py. No copyright."""

import struct
import zlib


def _chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return (struct.pack('>I', len(data)) + body
            + struct.pack('>I', zlib.crc32(body)))


def png(width: int = 64, height: int = 48, seed: int = 0) -> bytes:
    """A real decodable RGB PNG made of colour tiles."""
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            cx, cy = x // 8, y // 8  # 8x8 colour tiles compress well
            rows += bytes(((cx * 53 + seed * 60) % 256, (cy * 71) % 256,
                           (cx * 29 + cy * 41 + seed * 90) % 256))
    return (b'\x89PNG\r\n\x1a\n'
            + _chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2,
                                          0, 0, 0))
            + _chunk(b'IDAT', zlib.compress(bytes(rows), 9))
            + _chunk(b'IEND', b''))


def png_header_only(width: int, height: int) -> bytes:
    """Claims a huge size; the data is one empty row, so it cannot be
    decoded. Cheap: about 100 bytes."""
    return (b'\x89PNG\r\n\x1a\n'
            + _chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 0,
                                          0, 0, 0))
            + _chunk(b'IDAT', zlib.compress(b'\x00'))
            + _chunk(b'IEND', b''))


def gif(width: int = 40, height: int = 30) -> bytes:
    """A real GIF89a, one colour, trivial LZW (clear code + 1 data code)."""
    header = b'GIF89a' + struct.pack('<HHBBB', width, height, 0x80, 0, 0)
    palette = bytes([200, 60, 60, 255, 255, 255])
    descriptor = b'\x2c' + struct.pack('<HHHHB', 0, 0, width, height, 0)
    # Min code size 2: clear = 4, end = 5. Emit clear, then pixels as 0
    # (3-bit codes, the table grows after every code, so keep it simple
    # by resetting with a clear code every 2 pixels).
    bits = []

    def put(code: int) -> None:
        bits.extend((code >> i) & 1 for i in range(3))

    put(4)
    for i in range(width * height):
        put(0)
        if i % 2 == 1:
            put(4)
    put(5)
    data = bytearray()
    for i in range(0, len(bits), 8):
        chunk = bits[i:i + 8]
        data.append(sum(b << k for k, b in enumerate(chunk)))
    blocks = bytearray()
    for i in range(0, len(data), 255):
        part = data[i:i + 255]
        blocks.append(len(part))
        blocks += part
    return (header + palette + descriptor + b'\x02' + bytes(blocks)
            + b'\x00;')


def jpeg(width: int = 64, height: int = 48) -> bytes:
    """A real baseline grayscale JPEG, flat grey (all blocks DC-only)."""
    def seg(marker: int, payload: bytes) -> bytes:
        return bytes([0xFF, marker]) + struct.pack('>H', len(payload) + 2) \
            + payload

    out = b'\xff\xd8'
    out += seg(0xE0, b'JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00')
    out += seg(0xDB, b'\x00' + bytes([1]) * 64)
    out += seg(0xC0, struct.pack('>BHHB', 8, height, width, 1)
               + bytes([1, 0x11, 0]))
    # One-code Huffman tables: code '0' of length 1 -> symbol 0.
    counts = bytes([1] + [0] * 15)
    out += seg(0xC4, b'\x00' + counts + b'\x00')
    out += seg(0xC4, b'\x10' + counts + b'\x00')
    out += seg(0xDA, bytes([1, 1, 0x00, 0, 63, 0]))
    blocks = ((width + 7) // 8) * ((height + 7) // 8)
    nbits = blocks * 2  # DC '0' + AC EOB '0' per block
    data = bytearray()
    for i in range(0, nbits, 8):
        left = min(8, nbits - i)
        data.append((0xFF >> left) & 0xFF if left < 8 else 0)
    stuffed = bytearray()
    for b in data:
        stuffed.append(b)
        if b == 0xFF:
            stuffed.append(0)
    return out + bytes(stuffed) + b'\xff\xd9'


def jpeg_header_only(width: int, height: int) -> bytes:
    """Claims a huge size, no scan data at all."""
    def seg(marker: int, payload: bytes) -> bytes:
        return bytes([0xFF, marker]) + struct.pack('>H', len(payload) + 2) \
            + payload
    return (b'\xff\xd8' + seg(0xE0, b'JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00')
            + seg(0xC0, struct.pack('>BHHB', 8, height, width, 1)
                  + bytes([1, 0x11, 0]))
            + b'\xff\xd9')
