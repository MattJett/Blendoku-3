"""Draws the app icon: a full-bleed blend with one well cut into it.

The field comes from the same Oklab maths the game generates its puzzles from,
so the icon is a real board rather than a picture of one — sixteen colours
meeting flush with no gaps and no gutters, which is the object the whole app is
built around. The one dark cell is the move: the gap you are there to fill. It
is drawn as a well, lit from the same corner as every well inside the app.

Pure Python, no dependencies, so it runs anywhere.

    python3 Tools/icon/make_icon.py Blendoku3/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
import math, struct, sys, zlib, os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "levelcheck"))
import mirror

SIZE = 1024
GRID = 4
#: The ink ground, so the notch is the same colour as the app behind it.
GROUND = (0x0D, 0x0F, 0x12)
#: Which cell is missing. Off-centre on both axes — a hole in the middle of a
#: symmetrical grid reads as a design element, and off to one side reads as a
#: piece that has been taken out.
HOLE = (1, 2)  # row, column


def clamp8(value):
    return max(0, min(255, int(round(value))))


def main(out_path):
    # An affine Oklab field, exactly like a level: one axis climbs in
    # lightness, the other swings through hue.
    # Chroma is kept well below what the gamut allows. The app's own palettes
    # are restrained, and an icon in highlighter colours would promise a
    # different game than the one behind it.
    origin = mirror.lch(0.32, 0.095, 292)
    dx = mirror.scale(mirror.sub(mirror.lch(0.55, 0.105, 214), origin), 1.0 / (GRID - 1))
    dy = mirror.scale(mirror.sub(mirror.lch(0.74, 0.080, 104), origin), 1.0 / (GRID - 1))

    swatches = []
    for row in range(GRID):
        line = []
        for column in range(GRID):
            colour = mirror.add(mirror.add(origin, mirror.scale(dx, column)),
                                mirror.scale(dy, row))
            r, g, b = mirror.to_rgb(colour)
            line.append(tuple(clamp8(v * 255) for v in (r, g, b)))
        swatches.append(line)

    cell = SIZE / GRID
    pixels = bytearray(SIZE * SIZE * 3)

    for py in range(SIZE):
        row = min(GRID - 1, int(py / cell))
        base = py * SIZE * 3
        for px in range(SIZE):
            column = min(GRID - 1, int(px / cell))
            if (row, column) == HOLE:
                rgb = well_shade(px, py, row, column, cell)
            else:
                rgb = swatches[row][column]
            index = base + px * 3
            pixels[index] = rgb[0]
            pixels[index + 1] = rgb[1]
            pixels[index + 2] = rgb[2]

    write_png(out_path, pixels)
    print("wrote", out_path)


def well_shade(px, py, row, column, cell):
    """The missing cell, lit like every other well in the app.

    Dark along the top-left inside edge, light along the bottom-right — the
    same two shadows `SoftSurface` throws when `pressed` is set, so the notch
    reads as pressed into the icon rather than punched out of it.
    """
    x0, y0 = column * cell, row * cell
    # Distance in from each edge, normalised to the cell.
    left = (px - x0) / cell
    top = (py - y0) / cell
    reach = 0.42

    dark = max(0.0, 1.0 - max(left, top) / reach)
    light = max(0.0, 1.0 - max(1.0 - left, 1.0 - top) / reach)

    out = []
    for channel, value in enumerate(GROUND):
        value -= 13 * dark * dark             # deepen toward the top-left
        value += (58 if channel == 2 else 48) * light * light  # cool lift below
        out.append(clamp8(value))
    return tuple(out)


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
