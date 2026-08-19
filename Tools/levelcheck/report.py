"""Generates all 100 levels through the mirror and reports on the curve."""
import sys, time, math, json
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import mirror

def main():
    rows = []
    total_start = time.time()
    failures = []
    for level in range(1, 101):
        stats = {}
        start = time.time()
        puzzle = mirror.generate(level, stats=stats)
        elapsed = time.time() - start
        if puzzle is None:
            failures.append(level)
            continue
        cells = puzzle["cells"]
        colours = [puzzle["solution"][c] for c in cells]
        tray = [puzzle["solution"][c] for c in puzzle["open"]] + puzzle["decoys"]
        unique = mirror.count_solutions(cells, puzzle["runs"], puzzle["solution"],
                                        puzzle["open"], extra=puzzle["decoys"], limit=3)
        minx, miny, maxx, maxy = mirror.bounds(cells)
        rows.append({
            "level": level,
            "chapter": puzzle["profile"]["chapter"],
            "cells": len(cells),
            "slots": len(puzzle["open"]),
            "clues": len(cells) - len(puzzle["open"]),
            "decoys": len(puzzle["decoys"]),
            "runs": len(puzzle["runs"]),
            "board": f"{maxx-minx+1}x{maxy-miny+1}",
            "shapes": ",".join(puzzle["shapes"]),
            "minStep": puzzle["profile"]["minStep"],
            "minPair": mirror.min_pair_distance(colours),
            "minTrayPair": mirror.min_pair_distance(tray),
            "solutions": unique,
            "attempt": stats.get("attempts"),
            "ms": elapsed * 1000,
        })
    total = time.time() - total_start

    print(f"{'lvl':>3} {'ch':>2} {'cells':>5} {'slot':>4} {'clue':>4} {'dec':>3} {'runs':>4} "
          f"{'board':>6} {'minStep':>7} {'minPair':>7} {'tray':>7} {'sol':>3} {'try':>3} {'ms':>7}  shapes")
    for r in rows:
        print(f"{r['level']:>3} {r['chapter']:>2} {r['cells']:>5} {r['slots']:>4} {r['clues']:>4} "
              f"{r['decoys']:>3} {r['runs']:>4} {r['board']:>6} {r['minStep']:>7.3f} "
              f"{r['minPair']:>7.3f} {r['minTrayPair']:>7.3f} {r['solutions']:>3} {r['attempt']:>3} "
              f"{r['ms']:>7.1f}  {r['shapes']}")

    bad = [r for r in rows if r["solutions"] != 1]
    print()
    print(f"levels generated : {len(rows)}/100   failures: {failures}")
    print(f"non-unique       : {[r['level'] for r in bad]}")
    print(f"total time       : {total:.2f}s   slowest: {max(r['ms'] for r in rows):.0f}ms "
          f"(level {max(rows, key=lambda r: r['ms'])['level']})")
    print(f"slots            : {min(r['slots'] for r in rows)} -> {max(r['slots'] for r in rows)}")
    print(f"cells            : {min(r['cells'] for r in rows)} -> {max(r['cells'] for r in rows)}")
    print(f"retries > 1      : {[ (r['level'], r['attempt']) for r in rows if r['attempt'] > 1]}")
    with open(__file__.rsplit('/',1)[0] + "/report.json", "w") as handle:
        json.dump(rows, handle, indent=1)

if __name__ == "__main__":
    main()
