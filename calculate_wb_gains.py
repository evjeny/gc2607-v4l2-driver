#!/usr/bin/env python3
"""Calculate white balance gains from a raw Bayer capture"""

import numpy as np
import sys
from pathlib import Path

def calculate_wb_gains(raw_file, width=1920, height=1080, quiet=False):
    """Calculate gray world white balance gains from raw Bayer data"""

    def log(*a):
        if not quiet:
            print(*a)

    log(f"Reading {raw_file}...")
    data = np.fromfile(raw_file, dtype=np.uint16)

    expected_size = width * height
    if len(data) < expected_size:
        print(f"Error: File too small ({len(data)} < {expected_size})", file=sys.stderr)
        return None

    # Reshape to 2D array
    img = data[:expected_size].reshape(height, width)

    # Extract R, G, B channels (GRBG pattern)
    h2, w2 = height // 2, width // 2

    g1 = img[0::2, 0::2][:h2, :w2]  # G channel (first)
    r = img[0::2, 1::2][:h2, :w2]   # R channel
    b = img[1::2, 0::2][:h2, :w2]   # B channel
    g2 = img[1::2, 1::2][:h2, :w2]  # G channel (second)

    # Calculate channel averages
    r_avg = np.mean(r.astype(np.float32))
    g1_avg = np.mean(g1.astype(np.float32))
    g2_avg = np.mean(g2.astype(np.float32))
    b_avg = np.mean(b.astype(np.float32))

    g_avg = (g1_avg + g2_avg) / 2

    # Calculate gains (use green as reference)
    r_gain = g_avg / (r_avg + 1e-6)
    b_gain = g_avg / (b_avg + 1e-6)
    g_gain = 1.0

    log(f"\nChannel averages:")
    log(f"  R: {r_avg:.1f}")
    log(f"  G: {g_avg:.1f}")
    log(f"  B: {b_avg:.1f}")
    log(f"\nGray World White Balance Gains:")
    log(f"  Red:   {r_gain:.3f}")
    log(f"  Green: {g_gain:.3f}")
    log(f"  Blue:  {b_gain:.3f}")
    log(f"\nTo use these gains, run:")
    log(f"  ./create_virtual_camera_wb.sh {r_gain:.3f} {g_gain:.3f} {b_gain:.3f}")

    return (r_gain, g_gain, b_gain)

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    export = "--export" in sys.argv  # print only "R G B" gains (for scripts)

    if not args:
        print("Usage: ./calculate_wb_gains.py <raw_file> [--export]")
        print("\nThis script calculates optimal white balance gains from a raw capture.")
        print("  --export   print only 'R G B' gains on one line (for shell scripts)")
        sys.exit(1)

    gains = calculate_wb_gains(args[0], quiet=export)
    if export:
        if gains is None:
            sys.exit(1)
        print(f"{gains[0]:.3f} {gains[1]:.3f} {gains[2]:.3f}")
