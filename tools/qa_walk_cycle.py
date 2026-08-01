#!/usr/bin/env python3
"""Semantic-ish QA gate for a four-phase side-view walk cycle.

This is intentionally stricter than sprite-gen's generic structural inspect:
contact frames must alternate their leading-foot silhouette, gather frames must
keep both feet near the body center, and the two contact frames must not be
near-duplicates. It is a deterministic gate, not a substitute for a human
motion review.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image


def _alpha_stats(path: Path) -> tuple[float, float, float, int]:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"empty frame: {path}")
    left, top, right, bottom = bbox
    pixels = alpha.load()
    band_top = top + (bottom - top) * 0.78
    xs: list[int] = []
    ys: list[int] = []
    for y in range(int(band_top), bottom):
        for x in range(left, right):
            if pixels[x, y] >= 32:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise ValueError(f"no foot pixels in lower band: {path}")
    center = (left + right) / 2.0
    # Negative means the lower silhouette reaches left of the body center.
    mean_offset = (sum(xs) / len(xs)) - center
    extent_left = min(xs) - center
    extent_right = max(xs) - center
    return mean_offset, extent_left, extent_right, len(xs)


def _foot_component_offset(path: Path) -> float | None:
    """Return the centroid of the largest connected foot component.

    The broad lower silhouette used by the legacy metric can stay centered in
    front/diagonal views even when the two feet swap. Looking only at the last
    ~35 pixels isolates the leading foot and works for both planted and
    three-quarter poses.
    """
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return None
    left, top, right, bottom = bbox
    start_y = max(top, bottom - 36)
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    best: list[tuple[int, int]] = []
    for y in range(start_y, bottom):
        for x in range(left, right):
            if (x, y) in visited or pixels[x, y] < 32:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if (
                        left <= nx < right
                        and start_y <= ny < bottom
                        and (nx, ny) not in visited
                        and pixels[nx, ny] >= 32
                    ):
                        visited.add((nx, ny))
                        stack.append((nx, ny))
            if len(component) > len(best):
                best = component
    if len(best) < 8:
        return None
    center = (left + right) / 2.0
    return (sum(x for x, _ in best) / len(best)) - center


def _contact_distance(left: Path, right: Path) -> float:
    a = Image.open(left).convert("RGBA").resize((64, 64))
    b = Image.open(right).convert("RGBA").resize((64, 64))
    total = 0
    changed = 0
    for pa, pb in zip(a.getdata(), b.getdata()):
        total += 1
        if abs(pa[3] - pb[3]) > 16:
            changed += 1
    return changed / max(1, total)


def _contact_mirror_distance(left: Path, right: Path) -> float:
    """Compare contact frames after mirroring the second silhouette.

    Front/back views can have a centered lower silhouette, so a left/right
    swap may not change its centroid. A mirrored-contact match is a useful
    fallback in that case, while the normal contact distance still prevents
    duplicate frames.
    """
    a = Image.open(left).convert("RGBA").resize((64, 64))
    b = Image.open(right).convert("RGBA").transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((64, 64))
    total = 0
    changed = 0
    for pa, pb in zip(a.getdata(), b.getdata()):
        total += 1
        if max(abs(pa[channel] - pb[channel]) for channel in range(4)) > 24:
            changed += 1
    return changed / max(1, total)


def _visual_contact_distance(left: Path, right: Path) -> float:
    a = Image.open(left).convert("RGBA").resize((64, 64))
    b = Image.open(right).convert("RGBA").resize((64, 64))
    total = 0
    changed = 0
    for pa, pb in zip(a.getdata(), b.getdata()):
        total += 1
        if max(abs(pa[channel] - pb[channel]) for channel in range(4)) > 24:
            changed += 1
    return changed / max(1, total)


def _load_files(run_dir: Path, state: str) -> list[Path]:
    manifest = run_dir / "frames" / "frames-manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    row = next((entry for entry in data.get("rows", []) if entry.get("state") == state), None)
    if not row:
        raise ValueError(f"state not found in frames-manifest.json: {state}")
    files = [run_dir / rel for rel in row.get("files", [])]
    if len(files) != 4:
        raise ValueError(f"{state}: expected exactly 4 frames, found {len(files)}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate alternating feet in a 4-frame left walk.")
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--state", default="left_walk")
    parser.add_argument("--min-contact-difference", type=float, default=0.035)
    parser.add_argument("--min-leading-shift", type=float, default=5.0)
    parser.add_argument("--max-gather-shift", type=float, default=16.0)
    parser.add_argument(
        "--allow-either-leading",
        action="store_true",
        help="for front/diagonal/side views, require contact-frame alternation without assuming screen-left is the anatomical left foot",
    )
    args = parser.parse_args()

    try:
        frames = _load_files(args.run_dir, args.state)
        stats = [_alpha_stats(frame) for frame in frames]
        # Frame 0 and 2 are contact phases. Their lower silhouette must move in
        # opposite directions, otherwise both frames likely use the same leg.
        contact_mode = "screen-axis"
        if args.allow_either_leading:
            foot_offsets = [_foot_component_offset(frames[index]) for index in (0, 2)]
            foot_opposite = (
                foot_offsets[0] is not None
                and foot_offsets[1] is not None
                and abs(foot_offsets[0]) >= args.min_leading_shift
                and abs(foot_offsets[1]) >= args.min_leading_shift
                and foot_offsets[0] * foot_offsets[1] < 0.0
            )
            first_has_lead = abs(stats[0][0]) >= args.min_leading_shift
            third_has_lead = abs(stats[2][0]) >= args.min_leading_shift
            opposite_sign = stats[0][0] * stats[2][0] < 0.0
            if foot_opposite:
                contact_mode = "foot-component"
            elif first_has_lead and third_has_lead and opposite_sign:
                contact_mode = "screen-axis"
            else:
                normal_difference = max(
                    _contact_distance(frames[0], frames[2]),
                    _visual_contact_distance(frames[0], frames[2]),
                )
                mirrored_difference = _contact_mirror_distance(frames[0], frames[2])
                mirrored_contact = (
                    normal_difference >= args.min_contact_difference
                    and mirrored_difference <= normal_difference * 0.72
                )
                if not mirrored_contact:
                    raise ValueError(
                        "contact frames do not alternate leading feet: "
                        f"frame0={stats[0][0]:.2f}, frame2={stats[2][0]:.2f}"
                    )
                contact_mode = "mirrored-silhouette"
        else:
            if stats[0][0] >= -args.min_leading_shift:
                raise ValueError(f"frame 0 is not left-leading enough: offset={stats[0][0]:.2f}")
            if stats[2][0] <= args.min_leading_shift:
                raise ValueError(f"frame 2 is not right-leading enough: offset={stats[2][0]:.2f}")
        if abs(stats[1][0]) > args.max_gather_shift or abs(stats[3][0]) > args.max_gather_shift:
            raise ValueError(
                "gather frame feet are not centered: "
                f"frame1={stats[1][0]:.2f}, frame3={stats[3][0]:.2f}"
            )
        alpha_difference = _contact_distance(frames[0], frames[2])
        visual_difference = _visual_contact_distance(frames[0], frames[2])
        difference = max(alpha_difference, visual_difference)
        if difference < args.min_contact_difference:
            raise ValueError(f"contact frames are near-duplicates: visual difference={difference:.4f}")
        result = {
            "ok": True,
            "kind": "walk-cycle-qa",
            "state": args.state,
            "phase_contract": ["left_lead", "gather", "right_lead", "gather"],
            "leading_mode": "either-screen-axis" if args.allow_either_leading else "screen-left-then-screen-right",
            "contact_mode": contact_mode,
            "frames": [
                {"index": index, "lower_mean_offset": round(item[0], 3), "lower_left": round(item[1], 3), "lower_right": round(item[2], 3)}
                for index, item in enumerate(stats)
            ],
            "contact_alpha_difference": round(alpha_difference, 4),
            "contact_visual_difference": round(visual_difference, 4),
        }
        report = args.run_dir / "walk-cycle-qa.report.json"
        report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, indent=2))
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {"ok": False, "kind": "walk-cycle-qa", "state": args.state, "error": str(exc)}
        (args.run_dir / "walk-cycle-qa.report.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, indent=2))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
