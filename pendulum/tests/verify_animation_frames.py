#!/usr/bin/env python3
"""
verify_animation_frames.py — Frame-clipping check for pendulum GIFs

Loads every frame of one or more animated GIFs, finds the bounding box
of all non-background/non-support-line content in each frame (rod,
pivot, bob, and trail colors), and confirms that bounding box stays
within the image with a genuine margin on every single frame — not a
sample.

This exists because the double-pendulum default animation clipped on
76% of its frames (383/501) and nothing in the app's existing test
suite or correctness checks would have caught it — those check physics
(energy conservation, period, chaos sensitivity), not rendering. This
script checks the actual rendered pixels of the actual exported GIF,
which is the only way to catch a framing bug like this.

Usage:
    python3 tests/verify_animation_frames.py [gif_path ...]
    python3 tests/verify_animation_frames.py            # checks every *.gif in output/

Classification rule (see pendulum/AGENTS.md for the reasoning):
A pixel counts as "content" (rod/bob/pivot/trail) unless it is
near-achromatic (max channel - min channel < 12) AND light
(min channel > 120). That single rule captures the background
(RGBColor[0.97,0.97,1.0] ~ (247,247,255)) and the grey support line
(GrayLevel[0.6] ~ (153,153,153), plus its antialiased blend toward the
background) without excluding the darker pure greys used for the rod
and pivot (GrayLevel[0.35]~89, GrayLevel[0.2]~51 on the simple-pendulum
frame) or any of the chromatic rod/bob/trail colors.
"""

import sys
import glob
import os
import numpy as np
from PIL import Image, ImageSequence

MARGIN_PX = 3          # minimum required gap between content bbox and image edge
ACHROMATIC_TOL = 12    # max(R,G,B) - min(R,G,B) below this = "grey-ish"
LIGHT_THRESHOLD = 120  # min(R,G,B) above this = "light" (background or support line)


def content_mask(rgb_arr):
    """rgb_arr: HxWx3 uint8 numpy array. Returns HxW bool mask of content pixels."""
    lo = rgb_arr.min(axis=2).astype(np.int16)
    hi = rgb_arr.max(axis=2).astype(np.int16)
    achromatic = (hi - lo) < ACHROMATIC_TOL
    light = lo > LIGHT_THRESHOLD
    background_like = achromatic & light
    return ~background_like


def content_bbox(mask):
    """Returns (minRow, maxRow, minCol, maxCol) or None if no content pixels."""
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if not rows.any():
        return None
    min_row, max_row = np.where(rows)[0][[0, -1]]
    min_col, max_col = np.where(cols)[0][[0, -1]]
    return int(min_row), int(max_row), int(min_col), int(max_col)


def check_gif(path):
    im = Image.open(path)
    w, h = im.size
    n_frames = 0
    violations = []  # (frame_idx, side, distance)
    worst = {"top": None, "bottom": None, "left": None, "right": None}

    for frame in ImageSequence.Iterator(im):
        rgb_arr = np.array(frame.convert("RGB"))
        mask = content_mask(rgb_arr)
        bbox = content_bbox(mask)
        n_frames += 1
        if bbox is None:
            continue
        min_row, max_row, min_col, max_col = bbox

        top_margin = min_row
        bottom_margin = (h - 1) - max_row
        left_margin = min_col
        right_margin = (w - 1) - max_col

        for side, margin in (("top", top_margin), ("bottom", bottom_margin),
                              ("left", left_margin), ("right", right_margin)):
            if margin < MARGIN_PX:
                violations.append((n_frames - 1, side, margin))
            if worst[side] is None or margin < worst[side]:
                worst[side] = margin

    return {
        "path": path,
        "n_frames": n_frames,
        "size": (w, h),
        "violations": violations,
        "worst": worst,
    }


def report(result):
    path = result["path"]
    n = result["n_frames"]
    w, h = result["size"]
    violations = result["violations"]
    worst = result["worst"]
    name = os.path.basename(path)

    status = "FAIL" if violations else "PASS"
    print(f"[{status}] {name}  ({n} frames, {w}x{h}px, required margin >= {MARGIN_PX}px)")
    print(f"       worst-case margins observed: "
          f"top={worst['top']}px  bottom={worst['bottom']}px  "
          f"left={worst['left']}px  right={worst['right']}px")

    if violations:
        by_side = {}
        for idx, side, margin in violations:
            by_side.setdefault(side, []).append((idx, margin))
        n_frames_affected = len({idx for idx, _, _ in violations})
        print(f"       {n_frames_affected}/{n} frames ({100.0*n_frames_affected/n:.1f}%) "
              f"violate the margin on at least one side")
        for side, items in by_side.items():
            worst_item = min(items, key=lambda t: t[1])
            print(f"       side={side}: {len(items)} frames violate; "
                  f"worst = frame {worst_item[0]} at {worst_item[1]}px "
                  f"({'clipped' if worst_item[1] < 0 else 'inside margin'})")
    print()
    return status == "PASS"


def main():
    args = sys.argv[1:]
    if args:
        paths = args
    else:
        out_dir = os.path.join(os.path.dirname(__file__), "..", "output")
        paths = sorted(glob.glob(os.path.join(out_dir, "*.gif")))

    if not paths:
        print("No GIF files found to check.")
        sys.exit(1)

    all_pass = True
    for path in paths:
        result = check_gif(path)
        ok = report(result)
        all_pass = all_pass and ok

    print("=" * 60)
    print("ALL PASS" if all_pass else "SOME ANIMATIONS FAILED — see above")
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
