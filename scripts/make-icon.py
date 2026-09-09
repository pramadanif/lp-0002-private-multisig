#!/usr/bin/env python3
"""Draw app/assets/icon.png — the module's icon, in Basecamp's own visual language.

**Why a script rather than a checked-in binary nobody can regenerate.** The icon is packaged into
the .lgx and shown in Basecamp's sidebar next to the host's own modules. Those are Lucide line
glyphs on a 24x24 grid, stroked `#FFFFFF` on nothing — see the delivery demo's `mail.svg`, which
carries a note that Qt SVG resolves `currentColor` to black and so is invisible on the dark theme.
Our first icon was a dark rounded tile with filled shapes: correct, and obviously not from that set.

**What it draws, and why that shape.** Three nodes on a ring, two filled and one hollow: three
members, two of whom approved, which is the 2-of-3 threshold the deployed multisig enforces. It does
*not* try to depict the privacy property — that the chain records how many approved and never which
ones — because an icon cannot draw an absence, and pretending otherwise would need a caption. What
it does do is survive being small: at 24 px the ring is still a ring and the odd node still reads as
open, which a padlock or a shield full of detail would not.

**Fitting.** The constants below are shape, not placement: `render()` measures the glyph's bounding
box and scales and centres it to leave `PAD` units of margin on the tightest axis. So changing a
radius re-fits the whole thing instead of quietly pushing it off-centre.

No third-party imaging library: the PNG is emitted with `zlib` and `struct` from the standard
library, so this runs anywhere the rest of the toolchain does. Anti-aliasing is 4x supersampling.

    python3 scripts/make-icon.py [out.png]
"""
from __future__ import annotations

import math
import struct
import sys
import zlib

SIZE = 256          # what Basecamp's manifest wants
SS = 4              # supersampling factor
GRID = 24.0         # Lucide's coordinate space, so stroke weights match theirs
PAD = 2.2           # margin left on the tightest axis; Lucide's own glyphs sit at about 2

# Shape, in Lucide's 24-unit grid. Re-fitted by render(), so these are ratios in practice.
RING_R = 6.9
RING_W = 1.9
NODE_R = 2.05
NODE_W = 1.15      # the hollow node's wall: thinner than the ring so its hole survives 24 px
GAP = 1.0          # transparent breathing room where a node crosses the ring
ANGLES = (-90.0, 30.0, 150.0)   # top, lower-right, lower-left
FILLED = (True, True, False)    # two of three approved


def _dist(x: float, y: float, cx: float, cy: float) -> float:
    return math.hypot(x - cx, y - cy)


def _fit() -> tuple[float, float, float]:
    """Scale and centre so the drawn glyph sits PAD units inside the grid.

    Returns (scale, cx, cy) in grid units, with the shape constants read as unscaled.
    """
    node_out = NODE_R + max(NODE_W, 0.0) / 2.0
    ring_out = RING_R + RING_W / 2.0
    xs, ys = [], []
    for angle in ANGLES:
        rad = math.radians(angle)
        xs += [RING_R * math.cos(rad) - node_out, RING_R * math.cos(rad) + node_out]
        ys += [RING_R * math.sin(rad) - node_out, RING_R * math.sin(rad) + node_out]
    xs += [-ring_out, ring_out]
    ys += [-ring_out, ring_out]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)

    span = GRID - 2.0 * PAD
    scale = min(span / (x1 - x0), span / (y1 - y0))
    # Centre the *bounding box*, not the ring: the top node reaches further than the bottom arc.
    return scale, GRID / 2.0 - (x0 + x1) / 2.0 * scale, GRID / 2.0 - (y0 + y1) / 2.0 * scale


def render() -> bytearray:
    """Alpha coverage for one white glyph, supersampled then boxed down."""
    n = SIZE * SS
    px_per_unit = n / GRID
    fit, fcx, fcy = _fit()
    s = fit * px_per_unit

    cx, cy = fcx * px_per_unit, fcy * px_per_unit
    ring_r, ring_w = RING_R * s, RING_W * s
    node_r, node_w = NODE_R * s, NODE_W * s
    gap = GAP * s

    nodes = []
    for angle, filled in zip(ANGLES, FILLED):
        rad = math.radians(angle)
        nodes.append((cx + ring_r * math.cos(rad), cy + ring_r * math.sin(rad), filled))

    hi = bytearray(n * n)
    # A generous bounding box keeps this to the pixels the glyph can touch.
    reach = ring_r + node_r + gap + ring_w
    lo_y = max(0, int(cy - reach))
    hi_y = min(n, int(cy + reach) + 2)
    for py in range(lo_y, hi_y):
        y = py + 0.5
        row = py * n
        for px in range(n):
            x = px + 0.5
            on = False

            # The ring, minus a clear gap wherever a node sits on it.
            d = abs(_dist(x, y, cx, cy) - ring_r)
            if d <= ring_w / 2.0:
                on = True
                for nx, ny, _ in nodes:
                    if _dist(x, y, nx, ny) <= node_r + gap:
                        on = False
                        break

            if not on:
                for nx, ny, filled in nodes:
                    dn = _dist(x, y, nx, ny)
                    if filled:
                        if dn <= node_r:
                            on = True
                            break
                    elif abs(dn - node_r) <= node_w / 2.0:
                        on = True
                        break

            if on:
                hi[row + px] = 255

    # Box-downsample the coverage mask.
    alpha = bytearray(SIZE * SIZE)
    area = SS * SS
    for y in range(SIZE):
        for x in range(SIZE):
            total = 0
            for sy in range(SS):
                base = (y * SS + sy) * n + x * SS
                total += sum(hi[base:base + SS])
            alpha[y * SIZE + x] = total // area
    return alpha


def write_png(path: str, alpha: bytearray) -> None:
    """White RGBA, transparent ground — the same as Basecamp's own icons."""
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)                      # filter: none
        for x in range(SIZE):
            a = alpha[y * SIZE + x]
            raw += bytes((255, 255, 255, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def check(path: str) -> str | None:
    """Why the packaging step calls this. Basecamp draws a module icon at whatever size it likes,
    straight onto the dark rail, and does not tint it. An icon that is not 256x256 RGBA with a
    transparent ground either scales badly or ships as a white box, and nothing in the build would
    otherwise notice — the .lgx would pack happily and the fault would only appear after an install.
    """
    with open(path, "rb") as f:
        head = f.read(26)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return "not a PNG"
    w, h, depth, colour = struct.unpack(">IIBB", head[16:26])
    if (w, h, depth, colour) != (SIZE, SIZE, 8, 6):
        return f"{w}x{h}, bit depth {depth}, colour type {colour} — want {SIZE}x{SIZE} 8-bit RGBA"
    return None


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--check":
        target = args[1] if len(args) > 1 else "app/assets/icon.png"
        why = check(target)
        if why:
            sys.exit(f"{target}: {why} (regenerate with python3 scripts/make-icon.py)")
        print(f"{target} ok — {SIZE}x{SIZE} RGBA")
        sys.exit(0)

    out = args[0] if args else "app/assets/icon.png"
    write_png(out, render())
    print(f"wrote {out} — {SIZE}x{SIZE}, white on transparent")
