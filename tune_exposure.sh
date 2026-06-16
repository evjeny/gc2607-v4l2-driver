#!/bin/bash
# Tune sensor EXPOSURE and GAIN to fix over/under-exposure.
#
# Exposure and gain are real-time sensor controls, so this adjusts the LIVE
# camera (no need to stop the gc2607-camera service) — keep OBS/Meet open and
# watch the change. It then samples the virtual-camera output and reports the
# mean brightness and the percentage of blown-out (clipped) highlights.
#
# Usage:
#   ./tune_exposure.sh [EXPOSURE] [GAIN]
#     EXPOSURE  4..2002 (lines).  Lower = darker.   Default 600
#     GAIN      0..16 (LUT index). Lower = darker/less noise. Default 2
#
# Aim for "clipped highlights" of just a few percent (some window glare is ok),
# with the mean brightness where the room looks right. When happy, bake the
# values into gc2607-stream.sh (EXPOSURE / GAIN) and restart the service.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/camera_env.sh"

EXPO="${1:-600}"
GAIN="${2:-2}"

echo "Setting exposure=$EXPO gain=$GAIN on $SUBDEV ..."
v4l2-ctl -d "$SUBDEV" --set-ctrl "exposure=$EXPO,analogue_gain=$GAIN"
sleep 1

# Find the loopback (the service output) to sample the final image.
VIRT=""
for d in /dev/video*; do
    [ -e "$d" ] || continue
    [ "$(v4l2-ctl -d "$d" --info 2>/dev/null | awk -F': ' '/Driver name/{print $2}')" = "v4l2 loopback" ] && { VIRT="$d"; break; }
done

if [ -n "$VIRT" ]; then
    SAMPLE="$VIRT"; KIND="virtual camera output (YUY2)"
else
    SAMPLE="$CAM_DEV"; KIND="raw sensor (no service running)"
    v4l2-ctl -d "$CAM_DEV" --set-fmt-video=width=1920,height=1080,pixelformat=BA10 >/dev/null 2>&1 || true
fi

echo "Sampling brightness from $SAMPLE ($KIND)..."
timeout 8 v4l2-ctl -d "$SAMPLE" --stream-mmap --stream-count=1 --stream-to=/tmp/expo.raw 2>/dev/null

python3 - "$SAMPLE" "$VIRT" <<'PY'
import sys, numpy as np
sample, virt = sys.argv[1], sys.argv[2]
data = np.fromfile('/tmp/expo.raw', dtype=np.uint8 if virt else np.uint16)
if data.size == 0:
    print("No frame captured (is the camera/service running?)"); sys.exit(1)
if virt:                       # YUY2: luma at even byte offsets, 0..255
    y = data[0::2].astype(float)
    clip = (y > 250).mean() * 100
    print(f"mean brightness: {y.mean():.1f}/255   clipped highlights: {clip:.1f}%")
else:                          # raw Bayer 10-bit (0..1023)
    v = data.astype(float)
    clip = (v > 1000).mean() * 100
    print(f"mean level: {v.mean():.0f}/1023   clipped highlights: {clip:.1f}%")
print("Lower EXPOSURE/GAIN if clipping is high; raise them if the image is too dark.")
PY

echo ""
echo "When happy, set EXPOSURE=$EXPO and GAIN=$GAIN in gc2607-stream.sh, then:"
echo "  sudo systemctl restart gc2607-camera"
