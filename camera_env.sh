#!/bin/bash
# Shared helper: detect the GC2607 camera's V4L2 nodes at runtime.
#
# The IPU6 capture node and the sensor subdev node are NOT fixed:
#  - v4l2loopback (or other drivers) can claim /dev/video0, pushing the IPU6
#    capture node to /dev/video1+;
#  - the sensor subdev index depends on probe order.
# Resolve them from the media graph instead of hardcoding.
#
# Source this file to get:
#   MEDIA_DEV  - the IPU6 media device   (e.g. /dev/media0)
#   CAM_DEV    - the IPU6 ISYS capture node (e.g. /dev/video1)
#   SUBDEV     - the gc2607 sensor subdev   (e.g. /dev/v4l-subdev6)
#
# Usage:
#   source "$(dirname "$0")/camera_env.sh"   # exits non-zero if not found

# Find the media device owned by the ipu6 driver (fallback: /dev/media0).
detect_media_dev() {
    local m
    for m in /dev/media*; do
        [ -e "$m" ] || continue
        if media-ctl -d "$m" --print-topology 2>/dev/null | grep -q "Intel IPU6"; then
            echo "$m"; return 0
        fi
    done
    [ -e /dev/media0 ] && { echo /dev/media0; return 0; }
    return 1
}

MEDIA_DEV="${MEDIA_DEV:-$(detect_media_dev)}"
if [ -z "$MEDIA_DEV" ]; then
    echo "❌ No IPU6 media device found. Is the camera stack loaded?" >&2
    return 1 2>/dev/null || exit 1
fi

# Capture node = device node of the first ISYS capture entity.
CAM_DEV="${CAM_DEV:-$(media-ctl -d "$MEDIA_DEV" -e 'Intel IPU6 ISYS Capture 0' 2>/dev/null)}"

# Sensor subdev = device node of the gc2607 entity (name includes the i2c addr,
# e.g. "gc2607 5-0037"), so match it generically.
GC2607_ENTITY="$(media-ctl -d "$MEDIA_DEV" --print-topology 2>/dev/null \
                 | grep -oE 'gc2607 [0-9]+-[0-9a-f]+' | head -1)"
if [ -n "$GC2607_ENTITY" ]; then
    SUBDEV="${SUBDEV:-$(media-ctl -d "$MEDIA_DEV" -e "$GC2607_ENTITY" 2>/dev/null)}"
fi

if [ -z "$CAM_DEV" ] || [ -z "$SUBDEV" ]; then
    echo "❌ Could not resolve camera nodes (CAM_DEV='$CAM_DEV' SUBDEV='$SUBDEV')." >&2
    echo "   Is the gc2607 driver loaded and bound to the IPU6 bridge?" >&2
    return 1 2>/dev/null || exit 1
fi

export MEDIA_DEV CAM_DEV SUBDEV
