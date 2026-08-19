"""Renders every generated level as an SVG contact sheet, so the palettes and
board shapes can be eyeballed without building the app."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mirror


def hexed(colour):
    r, g, b = mirror.to_rgb(colour)
    clamp = lambda v: max(0, min(255, int(round(v * 255))))
    return "#%02X%02X%02X" % (clamp(r), clamp(g), clamp(b))


def main(out_path, columns=10, cell=11, gap=2, pad=16):
    tiles = []
    for level in range(1, 101):
        puzzle = mirror.generate(level)
        assert puzzle, level
        tiles.append(puzzle)

    board_w = max(mirror.bounds(p["cells"])[2] + 1 for p in tiles)
    board_h = max(mirror.bounds(p["cells"])[3] + 1 for p in tiles)
    tile_w = board_w * (cell + gap) + 24
    tile_h = board_h * (cell + gap) + 34
    width = columns * tile_w + pad * 2
    height = ((len(tiles) + columns - 1) // columns) * tile_h + pad * 2

    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
             f'viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="#0d0f14"/>']
    for index, puzzle in enumerate(tiles):
        ox = pad + (index % columns) * tile_w
        oy = pad + (index // columns) * tile_h
        parts.append(f'<text x="{ox+2}" y="{oy+11}" fill="#7c8698" '
                     f'font-family="ui-monospace,monospace" font-size="9">'
                     f'{puzzle["level"]} · {len(puzzle["open"])}/{len(puzzle["cells"])}'
                     f'{"+" + str(len(puzzle["decoys"])) if puzzle["decoys"] else ""}</text>')
        for point in puzzle["cells"]:
            x = ox + point[0] * (cell + gap)
            y = oy + 18 + point[1] * (cell + gap)
            colour = hexed(puzzle["solution"][point])
            stroke = '' if point not in puzzle["open"] else ' stroke="#ffffff" stroke-opacity="0.55" stroke-width="1"'
            parts.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="2" '
                         f'fill="{colour}"{stroke}/>')
        for slot, colour in enumerate(puzzle["decoys"]):
            x = ox + slot * (cell + gap)
            y = oy + 18 + board_h * (cell + gap) - 2
            parts.append(f'<circle cx="{x+cell/2}" cy="{y+cell/2}" r="{cell/2.6}" '
                         f'fill="{hexed(colour)}" stroke="#ff5f6d" stroke-width="0.8"/>')
    parts.append('</svg>')
    with open(out_path, "w") as handle:
        handle.write("".join(parts))
    print("wrote", out_path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "levels.svg")
