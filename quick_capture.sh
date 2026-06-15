#!/bin/bash
# Quick capture test (run after init_camera.sh)

set -e

echo "=== Quick Capture Test ==="
echo ""

# Resolve the actual camera/sensor nodes from the media graph.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/camera_env.sh"

echo "Camera: $CAM_DEV   Sensor: $SUBDEV"
echo "Current settings:"
v4l2-ctl -d "$SUBDEV" --get-ctrl exposure,analogue_gain
echo ""

echo "Capturing image..."
v4l2-ctl -d "$CAM_DEV" --stream-mmap --stream-count=1 --stream-to=capture.raw

echo "Converting to PNG (no brightness adjustment)..."
./view_raw_bright.py capture.raw 1.0

echo ""
echo "✅ Image saved as: test.png"
echo ""
echo "View: feh test.png"
