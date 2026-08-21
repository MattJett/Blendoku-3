"""A faithful Python port of the Swift level generator.

Design-time tool only: the Swift under Blendoku3/Core is the shipping source of
truth. This mirror exists so the 100-level curve can be verified (uniqueness,
sizes, timings, palette separation) and rendered on a machine without Xcode.
Keep it in step with Core/Generation when that code changes.
"""
import math
from bisect import insort

MASK = 0xFFFFFFFFFFFFFFFF
GOLDEN = 0x9E3779B97F4A7C15


class Rng:
    def __init__(self, seed):
        self.state = (seed + GOLDEN) & MASK

    def next(self):
        self.state = (self.state + GOLDEN) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return z ^ (z >> 31)

    def unit(self):
        return (self.next() >> 11) * (1.0 / 9007199254740992.0)

    def double(self, lo, hi):
        return lo + self.unit() * (hi - lo)

    def integer(self, lo, hi):
        if hi <= lo:
            return lo
        return lo + int(self.next() % (hi - lo + 1))

    def boolean(self, p):
        return self.unit() < p

    def pick(self, items):
        return items[self.integer(0, len(items) - 1)]

    def shuffled(self, items):
        result = list(items)
        for index in range(len(result) - 1, 0, -1):
            j = self.integer(0, index)
            result[index], result[j] = result[j], result[index]
        return result


def game_seed(level, salt):
    value = (level * GOLDEN) & MASK
    value ^= (salt * 0xC2B2AE3D27D4EB4F) & MASK
    value = ((value ^ (value >> 29)) * 0xBF58476D1CE4E5B9) & MASK
    return value ^ (value >> 32)


# ---------------------------------------------------------------- colour

def encode_srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055


def to_rgb(c):
    L, a, b = c
    lp = L + 0.3963377774 * a + 0.2158037573 * b
    mp = L - 0.1055613458 * a - 0.0638541728 * b
    sp = L - 0.0894841775 * a - 1.2914855480 * b
    lc, mc, sc = lp ** 3, mp ** 3, sp ** 3
    r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
    g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
    bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc
    return (encode_srgb(r), encode_srgb(g), encode_srgb(bl))


def displayable(c, margin=0.018):
    return all(margin <= v <= 1 - margin for v in to_rgb(c))


def chroma(c):
    return math.hypot(c[1], c[2])


def lch(lightness, chroma_value, hue):
    rad = hue * math.pi / 180
    return (lightness, chroma_value * math.cos(rad), chroma_value * math.sin(rad))


def add(x, y):
    return (x[0] + y[0], x[1] + y[1], x[2] + y[2])


def sub(x, y):
    return (x[0] - y[0], x[1] - y[1], x[2] - y[2])


def scale(x, k):
    return (x[0] * k, x[1] * k, x[2] * k)


def dist(x, y):
    return math.sqrt((x[0] - y[0]) ** 2 + (x[1] - y[1]) ** 2 + (x[2] - y[2]) ** 2)


def magnitude(x):
    return math.sqrt(x[0] ** 2 + x[1] ** 2 + x[2] ** 2)


# ------------------------------------------------------------- difficulty

CHAPTER_TITLES = ["First Light", "Turning Point", "Crossroads", "Lattice", "Twin Threads",
                  "Deep Field", "Whisper", "Constellation", "Labyrinth", "Event Horizon"]

ARCHETYPES = {
    1: ["row", "column", "elbow"],
    2: ["row", "column", "elbow", "tee"],
    3: ["elbow", "tee", "cross", "staircase"],
    4: ["block", "plusGrid", "cross", "tee"],
    5: ["row", "elbow", "block", "tee", "cross"],
    6: ["block", "comb", "ladder", "tee", "cross"],
    7: ["block", "cross", "staircase", "hbar", "comb"],
    8: ["row", "elbow", "block", "tee", "plusGrid", "diamond"],
    9: ["frame", "ladder", "spiral", "ubar", "hbar", "comb"],
    10: ["block", "frame", "spiral", "diamond", "ladder", "cross", "staircase"],
}

CHROMA_FRACTION = {1: (0.60, 1.00), 2: (0.58, 1.00), 3: (0.50, 0.95), 4: (0.48, 0.92),
                   5: (0.44, 0.90), 6: (0.40, 0.88), 7: (0.08, 0.30), 8: (0.38, 0.85),
                   9: (0.30, 0.72), 10: (0.24, 0.85)}

MAX_CELL_CHROMA = {7: 0.130, 9: 0.28, 10: 0.30}

LIGHTNESS = {7: (0.34, 0.80), 10: (0.30, 0.84)}


def profile(level):
    level = max(1, min(100, level))
    chapter = max(1, min(10, (level - 1) // 10 + 1))
    t = (level - 1) / 99
    cells = 3 + swift_round(57 * (t ** 1.45))
    slots = min(38, max(2, swift_round(cells * 0.55)))
    min_step = 0.058 + 0.152 * ((1 - t) ** 2.6)
    max_step = min_step * (1.75 - 0.45 * t)
    decoys = 0 if level <= 25 else 1 if level <= 45 else 2 if level <= 65 else 3 if level <= 85 else 4
    divisor = 4.0 + 6.0 * t
    components = max(1, swift_round(cells / divisor))
    components = max(1, min(min(components, 6), cells // 3))
    max_span = min(11, max(3, min(3 + swift_round(8 * t), int(0.72 / min_step) + 1)))
    return {
        "level": level, "chapter": chapter, "cells": cells, "slots": slots,
        "components": components, "archetypes": ARCHETYPES[chapter],
        "minStep": min_step, "maxStep": max_step, "decoys": decoys,
        "baseHue": (level * 137.50776405003785) % 360,
        "hueSpread": 22 + 96 * (t ** 0.7),
        "chromaFraction": CHROMA_FRACTION[chapter],
        "maxCellChroma": MAX_CELL_CHROMA.get(chapter, 0.32),
        "lightness": LIGHTNESS.get(chapter, (0.28, 0.86)),
        "maxSpan": max_span,
        "maxSpan2D": max(3, min(max_span, int(0.34 / min_step) + 1)),
    }


def swift_round(value):
    # Swift's Double.rounded() is half-away-from-zero; Python's round() is banker's.
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


# ----------------------------------------------------------------- shapes

def bounds(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def normalise(points):
    minx, miny, _, _ = bounds(points)
    return sorted({(p[0] - minx, p[1] - miny) for p in points}, key=lambda p: (p[1], p[0]))


def orient(points, variant):
    out = []
    for x, y in points:
        v = variant % 4
        if v == 1:
            out.append((-y, x))
        elif v == 2:
            out.append((-x, -y))
        elif v == 3:
            out.append((y, -x))
        else:
            out.append((x, y))
    if variant >= 4:
        out = [(-x, y) for x, y in out]
    return normalise(out)


def is_planar(kind):
    return kind not in ("row", "column")


def build_shape(kind, budget, max_span, rng):
    span = max(3, max_span)
    budget = max(3, budget)
    clamp = lambda v: min(max(v, 3), span)
    clamp2 = lambda v: min(max(v, 2), span)

    if kind == "row":
        pts = [(i, 0) for i in range(clamp(budget))]
    elif kind == "column":
        pts = [(0, i) for i in range(clamp(budget))]
    elif kind == "elbow":
        arm = clamp(rng.integer(3, max(3, budget - 2)))
        leg = clamp(budget - arm + 1)
        pts = [(i, 0) for i in range(arm)] + [(arm - 1, i) for i in range(1, leg)]
    elif kind == "tee":
        arm = clamp(rng.integer(3, max(3, budget - 2)))
        leg = clamp(budget - arm + 1)
        j = arm // 2
        pts = [(i, 0) for i in range(arm)] + [(j, i) for i in range(1, leg)]
    elif kind == "cross":
        arm = clamp(rng.integer(3, max(3, budget // 2 + 2)))
        leg = clamp(budget - arm + 1)
        row, col = leg // 2, arm // 2
        pts = list({(i, row) for i in range(arm)} | {(col, i) for i in range(leg)})
    elif kind == "staircase":
        pts = [(0, 0)]
        cx = cy = 0
        horizontal = rng.boolean(0.5)
        w = h = 1
        while len(pts) < budget:
            run = rng.integer(3, max(3, min(span, 4)))
            grows = run - 1
            if horizontal and w + grows > span:
                break
            if not horizontal and h + grows > span:
                break
            for _ in range(grows):
                if horizontal:
                    cx += 1
                else:
                    cy += 1
                pts.append((cx, cy))
            if horizontal:
                w += grows
            else:
                h += grows
            horizontal = not horizontal
    elif kind == "block":
        height = clamp2(swift_round(math.sqrt(budget)))
        width = clamp2((budget + height - 1) // height)
        pts = [(x, y) for y in range(height) for x in range(width)]
    elif kind == "frame":
        height = clamp(rng.integer(3, max(3, span - 1)))
        width = clamp((budget + 4) // 2 - height)
        pts = list({(x, 0) for x in range(width)} | {(x, height - 1) for x in range(width)}
                   | {(0, y) for y in range(height)} | {(width - 1, y) for y in range(height)})
    elif kind == "ladder":
        width = clamp((budget - 2) // 2)
        s = {(x, 0) for x in range(width)} | {(x, 2) for x in range(width)}
        s |= {(0, 1), (width - 1, 1)}
        if width >= 5:
            s.add((width // 2, 1))
        pts = list(s)
    elif kind == "comb":
        width = clamp(budget // 2 + 1)
        s = {(x, 0) for x in range(width)}
        for x in range(0, width, 2):
            s |= {(x, 1), (x, 2)}
        pts = list(s)
    elif kind == "hbar":
        height = clamp(rng.integer(3, max(3, (budget - 1) // 2)))
        s = {(0, y) for y in range(height)} | {(2, y) for y in range(height)}
        s.add((1, height // 2))
        pts = list(s)
    elif kind == "ubar":
        height = clamp(rng.integer(3, max(3, budget // 2)))
        width = clamp(budget - 2 * height + 2)
        s = {(0, y) for y in range(height)} | {(width - 1, y) for y in range(height)}
        s |= {(x, height - 1) for x in range(width)}
        pts = list(s)
    elif kind == "spiral":
        pts = spiral(budget, span)
    elif kind == "plusGrid":
        height = clamp(max(3, swift_round(math.sqrt(budget + 4))))
        width = clamp(max(3, (budget + 4 + height - 1) // height))
        s = {(x, y) for y in range(height) for x in range(width)}
        s -= {(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)}
        pts = list(s)
    elif kind == "diamond":
        from_budget = swift_round((math.sqrt(2 * budget - 1) - 1) / 2)
        radius = max(1, min((span - 1) // 2, from_budget))
        s = set()
        for dy in range(-radius, radius + 1):
            w = radius - abs(dy)
            for dx in range(-w, w + 1):
                s.add((dx + radius, dy + radius))
        pts = list(s)
    else:
        raise ValueError(kind)
    return normalise(pts)


def spiral(budget, span):
    deltas = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    occupied = {(0, 0)}
    path = [(0, 0)]
    cursor = (0, 0)
    direction = 0
    turns = 0
    while len(path) < budget and turns < 4:
        dx, dy = deltas[direction]
        cand = (cursor[0] + dx, cursor[1] + dy)
        ok = 0 <= cand[0] < span and 0 <= cand[1] < span and cand not in occupied
        if ok:
            for ny in (-1, 0, 1):
                for nx in (-1, 0, 1):
                    if nx == 0 and ny == 0:
                        continue
                    nb = (cand[0] + nx, cand[1] + ny)
                    if nb != cursor and nb in occupied:
                        ok = False
        if ok:
            occupied.add(cand)
            path.append(cand)
            cursor = cand
            turns = 0
        else:
            direction = (direction + 1) % 4
            turns += 1
    return path


# ------------------------------------------------------------------ solver

def find_runs(cells):
    result = []
    cell_set = set(cells)
    for cell in sorted(cell_set, key=lambda p: (p[1], p[0])):
        if (cell[0] - 1, cell[1]) not in cell_set:
            pts = [cell]
            cur = (cell[0] + 1, cell[1])
            while cur in cell_set:
                pts.append(cur)
                cur = (cur[0] + 1, cur[1])
            if len(pts) >= 3:
                result.append(pts)
    for cell in sorted(cell_set, key=lambda p: (p[1], p[0])):
        if (cell[0], cell[1] - 1) not in cell_set:
            pts = [cell]
            cur = (cell[0], cell[1] + 1)
            while cur in cell_set:
                pts.append(cur)
                cur = (cur[0], cur[1] + 1)
            if len(pts) >= 3:
                result.append(pts)
    return result


def count_solutions(cells, runs, solution, open_cells, extra=(), limit=2, eps=1e-7):
    index_of = {p: i for i, p in enumerate(cells)}
    run_idx = [[index_of[p] for p in run] for run in runs]
    assigned = [None] * len(cells)
    tiles = []
    for i, p in enumerate(cells):
        if p in open_cells:
            tiles.append(solution[p])
        else:
            assigned[i] = solution[p]
    tiles += list(extra)
    used = [False] * len(tiles)
    found = [0]

    def search(assigned, used, remaining):
        assigned = list(assigned)
        used = list(used)
        changed = True
        while changed:
            changed = False
            for run in run_idx:
                known = [(pos, assigned[c]) for pos, c in enumerate(run) if assigned[c] is not None]
                if len(known) < 2:
                    continue
                (p0, c0), (p1, c1) = known[0], known[1]
                step = scale(sub(c1, c0), 1.0 / (p1 - p0))
                for pos, colour in known[2:]:
                    if dist(add(c0, scale(step, pos - p0)), colour) > eps:
                        return remaining
                for pos, c in enumerate(run):
                    if assigned[c] is not None:
                        continue
                    target = add(c0, scale(step, pos - p0))
                    match = None
                    for ti, tile in enumerate(tiles):
                        if not used[ti] and dist(tile, target) <= eps:
                            match = ti
                            break
                    if match is None:
                        return remaining
                    assigned[c] = tiles[match]
                    used[match] = True
                    remaining -= 1
                    changed = True
        if remaining == 0:
            found[0] += 1
            return remaining
        branch, best = -1, -1
        for run in run_idx:
            known = sum(1 for c in run if assigned[c] is not None)
            first_open = next((c for c in run if assigned[c] is None), -1)
            if first_open >= 0 and known > best:
                best, branch = known, first_open
        if branch < 0:
            branch = next((i for i, v in enumerate(assigned) if v is None), -1)
            if branch < 0:
                found[0] += 1
                return remaining
        for ti, tile in enumerate(tiles):
            if used[ti]:
                continue
            na, nu = list(assigned), list(used)
            na[branch] = tile
            nu[ti] = True
            search(na, nu, remaining - 1)
            if found[0] >= limit:
                return remaining
        return remaining

    search(assigned, used, len(open_cells))
    return found[0]


# --------------------------------------------------------------- generator

def min_pair_distance(colours):
    if len(colours) < 2:
        return float("inf")
    best = float("inf")
    for i in range(len(colours) - 1):
        for j in range(i + 1, len(colours)):
            best = min(best, dist(colours[i], colours[j]))
    return best


def fits(colour, ceiling):
    return displayable(colour) and 0.12 < colour[0] < 0.94 and chroma(colour) <= ceiling


def max_feasible_chroma(centre_l, hue, offsets, ceiling):
    def feasible(c):
        centre = lch(centre_l, c, hue)
        return all(fits(add(centre, o), ceiling) for o in offsets)
    if not feasible(0):
        return -1
    low, high = 0.0, 0.40
    for _ in range(18):
        mid = (low + high) / 2
        if feasible(mid):
            low = mid
        else:
            high = mid
    return low


L_BUDGET = 0.74
PLANAR_BUDGET = 0.38
STEP_BUDGET = 0.80


def make_field(points, prof, hue_offset, rng, avoid=(), attempts=320):
    minx, miny, maxx, maxy = bounds(points)
    span_x, span_y = maxx - minx, maxy - miny
    uses_x, uses_y = span_x > 0, span_y > 0
    separation = prof["minStep"] * 0.78

    for attempt in range(attempts):
        slack = attempt / attempts
        low = prof["minStep"] * (1 - 0.10 * slack)
        high = prof["maxStep"] * (1 + 0.18 * slack)
        high_x = max(low, min(high, STEP_BUDGET / span_x)) if uses_x else high
        high_y = max(low, min(high, STEP_BUDGET / span_y)) if uses_y else high

        hue_centre = prof["baseHue"] + hue_offset + rng.double(-12, 12)
        step_x = rng.double(low, high_x)
        step_y = rng.double(low, high_y)
        travel_x = step_x * span_x if uses_x else 0.0
        travel_y = step_y * span_y if uses_y else 0.0

        planar_x = rng.double(0, min(1, PLANAR_BUDGET / travel_x) if travel_x > 0 else 1)
        remaining = max(0.0, PLANAR_BUDGET - travel_x * planar_x)
        planar_y = rng.double(0, min(1, remaining / travel_y) if travel_y > 0 else 1)

        lift_x = math.sqrt(max(0.0, 1 - planar_x * planar_x)) * (1 if rng.boolean(0.5) else -1)
        magnitude_y = math.sqrt(max(0.0, 1 - planar_y * planar_y))
        free_sign = 1.0 if rng.boolean(0.5) else -1.0
        if travel_x * abs(lift_x) + travel_y * magnitude_y > L_BUDGET:
            lift_y = -magnitude_y * (-1 if lift_x < 0 else 1)
        else:
            lift_y = magnitude_y * free_sign

        theta_x = (hue_centre + rng.double(-prof["hueSpread"], prof["hueSpread"])) * math.pi / 180
        theta_y = (hue_centre + rng.double(-prof["hueSpread"], prof["hueSpread"])) * math.pi / 180

        dx = dy = (0.0, 0.0, 0.0)
        if uses_x:
            dx = scale((lift_x, planar_x * math.cos(theta_x), planar_x * math.sin(theta_x)), step_x)
        if uses_y:
            dy = scale((lift_y, planar_y * math.cos(theta_y), planar_y * math.sin(theta_y)), step_y)

        if uses_x and uses_y:
            cosine = abs((dx[0] * dy[0] + dx[1] * dy[1] + dx[2] * dy[2]) /
                         (magnitude(dx) * magnitude(dy)))
            if cosine > 0.90:
                continue

        offsets = [add(scale(dx, p[0] - span_x / 2), scale(dy, p[1] - span_y / 2)) for p in points]
        lowest_l = max(prof["lightness"][0], 0.135 - min(o[0] for o in offsets))
        highest_l = min(prof["lightness"][1], 0.925 - max(o[0] for o in offsets))
        if lowest_l > highest_l:
            continue

        centre_l = rng.double(lowest_l, highest_l)
        fraction = rng.double(*prof["chromaFraction"])

        factor = 1.0
        for _ in range(10):
            scaled_x, scaled_y = scale(dx, factor), scale(dy, factor)
            if uses_x and magnitude(scaled_x) < prof["minStep"] * 0.995:
                break
            if uses_y and magnitude(scaled_y) < prof["minStep"] * 0.995:
                break
            scaled = [scale(o, factor) for o in offsets]
            headroom = max_feasible_chroma(centre_l, hue_centre, scaled, prof["maxCellChroma"])
            if headroom >= 0.010:
                centre = lch(centre_l, headroom * fraction, hue_centre)
                origin = sub(sub(centre, scale(scaled_x, span_x / 2)), scale(scaled_y, span_y / 2))
                colours = [add(add(origin, scale(scaled_x, p[0])), scale(scaled_y, p[1])) for p in points]
                clear = not avoid or all(
                    all(dist(a, c) >= separation for a in avoid) for c in colours)
                if clear and all(fits(c, prof["maxCellChroma"]) for c in colours) and \
                        min_pair_distance(colours) >= separation:
                    return origin, scaled_x, scaled_y
            factor *= 0.92
    return None


def split_budget(total, parts):
    if parts <= 1:
        return [max(3, total)]
    base = max(3, total // parts)
    budgets = [base] * parts
    remainder = total - base * parts
    i = 0
    while remainder > 0:
        budgets[i % parts] += 1
        remainder -= 1
        i += 1
    return budgets


def pack(shapes):
    ordered = sorted(shapes, key=lambda s: -(bounds(s)[3] - bounds(s)[1] + 1))
    best, best_score = None, float("inf")
    for max_width in range(3, 11):
        placed = []
        cursor_x = shelf_y = shelf_h = 0
        overflowed = False
        for shape in ordered:
            minx, miny, maxx, maxy = bounds(shape)
            w, h = maxx - minx + 1, maxy - miny + 1
            if cursor_x > 0 and cursor_x + w > max_width:
                shelf_y += shelf_h + 1
                cursor_x = 0
                shelf_h = 0
            if w > max_width:
                overflowed = True
            placed.append([(x + cursor_x, y + shelf_y) for x, y in shape])
            cursor_x += w + 1
            shelf_h = max(shelf_h, h)
        if overflowed:
            continue
        flat = [p for s in placed for p in s]
        minx, miny, maxx, maxy = bounds(flat)
        w, h = maxx - minx + 1, maxy - miny + 1
        if w > 11 or h > 15:
            continue
        score = abs(w / h - 0.82) + w * 0.015
        if score < best_score:
            best_score, best = score, placed
    if best is None:
        return None
    flat = [p for s in best for p in s]
    minx, miny, _, _ = bounds(flat)
    return [[(x - minx, y - miny) for x, y in s] for s in best]


def generate(level, max_attempts=180, stats=None):
    prof = profile(level)
    for attempt in range(max_attempts):
        rng = Rng(game_seed(level, attempt))
        result = try_build(prof, attempt, rng)
        if result:
            if stats is not None:
                stats["attempts"] = attempt + 1
            return result
    return None


def try_build(prof, attempt, rng):
    # Later attempts ask for a slightly smaller board — see the Swift comment.
    relief = 1 - 0.25 * min(1, attempt / 110)
    wanted_cells = max(3, swift_round(prof["cells"] * relief))
    budgets = split_budget(wanted_cells, prof["components"])
    shapes = []
    for budget in budgets:
        kind = rng.pick(prof["archetypes"])
        span = prof["maxSpan2D"] if is_planar(kind) else prof["maxSpan"]
        shape = build_shape(kind, budget, span, rng)
        if len(shape) < 3:
            return None
        shapes.append((kind, orient(shape, rng.integer(0, 7))))

    placed = pack([s for _, s in shapes])
    if placed is None:
        return None
    flat = [p for s in placed for p in s]
    if len(set(flat)) != len(flat):
        return None
    if len(set(flat)) > wanted_cells + 8:
        return None
    cells = sorted(set(flat), key=lambda p: (p[1], p[0]))

    solution = {}
    used = []
    spread = prof["hueSpread"] * 0.9
    for index, shape in enumerate(placed):
        centred = index - (len(placed) - 1) / 2
        hue_offset = centred * spread if len(placed) > 1 else 0
        local = normalise(shape)
        field = make_field(local, prof, hue_offset, rng, avoid=used)
        if field is None:
            return None
        origin, dx, dy = field
        minx, miny, _, _ = bounds(shape)
        for x, y in shape:
            colour = add(add(origin, scale(dx, x - minx)), scale(dy, y - miny))
            solution[(x, y)] = colour
            used.append(colour)

    colours = [solution[c] for c in cells]
    if min_pair_distance(colours) < prof["minStep"] * 0.78:
        return None

    runs = find_runs(cells)
    if not runs:
        return None

    wanted = min(prof["slots"], max(2, int(len(cells) * 0.78)))
    open_cells = set()
    for point in rng.shuffled(cells):
        if len(open_cells) >= wanted:
            break
        candidate = open_cells | {point}
        if count_solutions(cells, runs, solution, candidate) == 1:
            open_cells = candidate
    if len(open_cells) < 2 or len(open_cells) < wanted - 3:
        return None

    decoys = []
    tries = 0
    while len(decoys) < prof["decoys"] and tries < 400:
        tries += 1
        anchor = rng.pick(colours)
        elevation = rng.double(-1.3, 1.3)
        theta = rng.double(0, 2 * math.pi)
        direction = (math.sin(elevation), math.cos(elevation) * math.cos(theta),
                     math.cos(elevation) * math.sin(theta))
        cand = add(anchor, scale(direction, rng.double(prof["minStep"] * 1.15, prof["minStep"] * 2.6)))
        if not displayable(cand) or not (0.14 < cand[0] < 0.92):
            continue
        if chroma(cand) > prof["maxCellChroma"]:
            continue
        sep = prof["minStep"] * 1.02
        if any(dist(c, cand) < sep for c in colours) or any(dist(d, cand) < sep for d in decoys):
            continue
        if count_solutions(cells, runs, solution, open_cells, extra=decoys + [cand]) != 1:
            continue
        decoys.append(cand)

    return {
        "level": prof["level"], "attempt": attempt, "profile": prof,
        "cells": cells, "solution": solution, "open": open_cells,
        "runs": runs, "decoys": decoys,
        "shapes": [k for k, _ in shapes],
    }
