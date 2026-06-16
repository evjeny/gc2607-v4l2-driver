#!/bin/bash
# Manually tune white-balance GAINS for the GC2607 GStreamer pipeline.
#
# White balance is done with two frei0r "levels" stages (a clean per-channel
# multiply): red and blue are boosted relative to green. A gain of G multiplies
# that channel by G (implemented as input-white-level = 1/G).
#
# Usage:
#   ./tune_wb.sh [RED_GAIN] [BLUE_GAIN]            live preview window (Ctrl+C)
#   ./tune_wb.sh --measure [RED_GAIN] [BLUE_GAIN]  print output R/G/B means
#
#   RED_GAIN / BLUE_GAIN : multipliers >= 1 (green is the 1.0 reference).
#   Defaults: 1.414 1.283 (measured gray-world values).
#
# Goal: in --measure mode, tweak the gains until R ≈ G ≈ B.
# When happy, put the gains in gc2607-stream.sh (R_GAIN / B_GAIN) and restart.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="preview"
[ "${1:-}" = "--measure" ] && { MODE="measure"; shift; }

RED_GAIN="${1:-1.414}"
BLUE_GAIN="${2:-1.283}"

# frei0r levels: input-white-level = 1/gain (clamped to a sane range).
iw() { awk -v g="$1" 'BEGIN{w=1.0/g; if(w>1)w=1; if(w<0.05)w=0.05; printf "%.4f", w}'; }
RW=$(iw "$RED_GAIN"); BW=$(iw "$BLUE_GAIN")

if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
echo "Freeing the camera (stopping gc2607-camera service / feeds)..."
$SUDO systemctl stop gc2607-camera 2>/dev/null || true
pkill -f gc2607-stream 2>/dev/null || true
pkill -f 'gst-launch.*v4l2sink' 2>/dev/null || true
sleep 1

source "$SCRIPT_DIR/camera_env.sh"
v4l2-ctl -d "$SUBDEV" --set-ctrl exposure=2002,analogue_gain=16 2>/dev/null || true
v4l2-ctl -d "$CAM_DEV" --set-fmt-video=width=1920,height=1080,pixelformat=BA10 >/dev/null 2>&1 || true

# WB stage: red channel (channel=0.0) then blue channel (channel=0.2).
WB="frei0r-filter-levels channel=0.0 input-white-level=$RW show-histogram=false ! \
    frei0r-filter-levels channel=0.2 input-white-level=$BW show-histogram=false"

echo "RED_GAIN=$RED_GAIN (input-white=$RW)   BLUE_GAIN=$BLUE_GAIN (input-white=$BW)"

if [ "$MODE" = "measure" ]; then
    rm -f /tmp/wb_tune.png
    eval gst-launch-1.0 -q \
        v4l2src device="$CAM_DEV" num-buffers=1 ! \
        '"video/x-bayer,format=grbg10le,width=1920,height=1080,framerate=30/1"' ! \
        bayer2rgb ! videoflip method=rotate-180 ! videoconvert ! '"video/x-raw,format=RGBA"' ! \
        $WB ! \
        videoconvert ! pngenc ! filesink location=/tmp/wb_tune.png >/dev/null 2>&1
    python3 - <<'PY'
import numpy as np
from PIL import Image
im = np.asarray(Image.open('/tmp/wb_tune.png').convert('RGB')).astype(float)
R,G,B = im[...,0].mean(), im[...,1].mean(), im[...,2].mean()
print(f"OUTPUT means: R={R:.1f} G={G:.1f} B={B:.1f}   R/G={R/G:.3f} B/G={B/G:.3f}")
print("Target: R/G and B/G both ~1.00. If R/G<1 raise RED_GAIN; if B/G<1 raise BLUE_GAIN.")
PY
    echo "Restart camera with: sudo systemctl start gc2607-camera"
else
    echo "Live preview (Ctrl+C to stop)..."
    eval gst-launch-1.0 \
        v4l2src device="$CAM_DEV" ! \
        '"video/x-bayer,format=grbg10le,width=1920,height=1080,framerate=30/1"' ! \
        bayer2rgb ! videoflip method=rotate-180 ! videoconvert ! '"video/x-raw,format=RGBA"' ! \
        $WB ! \
        videoconvert ! autovideosink
    echo "Preview stopped. Restart camera with: sudo systemctl start gc2607-camera"
fi
