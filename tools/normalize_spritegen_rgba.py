#!/usr/bin/env python3
"""Remove an opaque checkerboard that some image providers bake into PNGs.

Only neutral, bright pixels connected to an image border are cleared, so light
fur and equipment inside the character remain intact.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def normalize(path: Path) -> bool:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    queue.extend((x, 0) for x in range(width))
    queue.extend((x, height - 1) for x in range(width))
    queue.extend((0, y) for y in range(height))
    queue.extend((width - 1, y) for y in range(height))

    def is_checkerboard(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha > 0 and min(red, green, blue) > 225 and max(red, green, blue) - min(red, green, blue) < 12

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if x < 0 or y < 0 or x >= width or y >= height or visited[index] or not is_checkerboard(x, y):
            continue
        visited[index] = 1
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    changed = False
    for y in range(height):
        for x in range(width):
            if visited[y * width + x] and pixels[x, y][3] != 0:
                red, green, blue, _ = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
                changed = True
    if changed:
        image.save(path)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    changed = 0
    for path in args.paths:
        if path.is_file() and path.suffix.lower() == ".png" and normalize(path):
            changed += 1
    print(f"normalized {changed} PNG(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
