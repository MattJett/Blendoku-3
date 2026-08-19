"""Draws the app icon: a three-by-three blend cut from the same Oklab field the
game generates its puzzles from. Pure Python so it runs anywhere.

    python3 Tools/icon/make_icon.py Blendoku3/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
import math, struct, sys, zlib, os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "levelcheck"))
import mirror

SIZE = 1024
BACKDROP = (0x14, 0x16, 0x1E)


def rounded_coverage(px, py, x0, y0, x1, y1, radius):
    """Signed-distance coverage of a rounded rectangle, for cheap antialiasing."""
    cx = max(x0 + radius, min(px, x1 - radius))
    cy = max(y0 + radius, min(py, y1 - radius))
    distance = math.hypot(px - cx, py - cy) - radius
    return max(0.0, min(1.0, 0.5 - distance))


def main(out_path):
    pixels = bytearray()
    for _ in range(SIZE * SIZE):
        pixels += bytes(BACKDROP)

    # An affine Oklab field, exactly like a level: one axis climbs in
    # lightness, the other swings through hue.
    origin = mirror.lch(0.34, 0.115, 292)
    dx = mirror.sub(mirror.lch(0.52, 0.135, 214), origin)
    dy = mirror.sub(mirror.lch(0.80, 0.105, 96), origin)
    dx = mirror.scale(dx, 0.5)
    dy = mirror.scale(dy, 0.5)

    margin = 132
    gap = 26
    span = SIZE - margin * 2
    cell = (span - gap * 2) / 3.0
    radius = cell * 0.26

    for row in range(3):
        for column in range(3):
            colour = mirror.add(mirror.add(origin, mirror.scale(dx, column)),
                                mirror.scale(dy, row))
            r, g, b = mirror.to_rgb(colour)
            rgb = tuple(max(0, min(255, int(round(v * 255)))) for v in (r, g, b))

            x0 = margin + column * (cell + gap)
            y0 = margin + row * (cell + gap)
            x1, y1 = x0 + cell, y0 + cell

            for py in range(int(y0) - 2, int(y1) + 3):
                if not (0 <= py < SIZE):
                    continue
                base = py * SIZE * 3
                for px in range(int(x0) - 2, int(x1) + 3):
                    if not (0 <= px < SIZE):
                        continue
                    alpha = rounded_coverage(px + 0.5, py + 0.5, x0, y0, x1, y1, radius)
                    if alpha <= 0:
                        continue
                    index = base + px * 3
                    for channel in range(3):
                        old = pixels[index + channel]
                        pixels[index + channel] = int(round(old + (rgb[channel] - old) * alpha))

    write_png(out_path, pixels)
    print("wrote", out_path)


def write_png(path, pixels):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # no per-scanline filter
        raw += pixels[y * SIZE * 3:(y + 1) * SIZE * 3]

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    blob = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(blob)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
