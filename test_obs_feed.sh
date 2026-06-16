#!/bin/bash
# Smoke test: reset v4l2loopback, feed the GC2607 RGB+WB stream into it for a few
# seconds, then read a frame back to confirm the virtual camera produces video.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/camera_env.sh"

echo "Real camera: $CAM_DEV  sensor: $SUBDEV"
echo "Stopping v4l2-relayd (it holds the loopback; useless for raw gc2607)..."
sudo systemctl stop v4l2-relayd 2>/dev/null || true
sleep 1
echo "Resetting v4l2loopback..."
sudo modprobe -r v4l2loopback 2>&1 || { echo "modprobe -r failed (still in use)"; sudo fuser -v /dev/video0 2>&1; }
sudo modprobe v4l2loopback devices=1 card_label="aGC2607" exclusive_caps=1 max_buffers=2
sleep 1

VIRT=""
for d in /dev/video*; do
    [ -e "$d" ] || continue
    [ "$(v4l2-ctl -d "$d" --info 2>/dev/null | awk -F': ' '/Driver name/{print $2}')" = "v4l2 loopback" ] && { VIRT="$d"; break; }
done
echo "Loopback device: ${VIRT:-NOT FOUND}"
[ -z "$VIRT" ] && exit 1

echo "=== who currently has $VIRT open (before we feed) ==="
sudo fuser -v "$VIRT" 2>&1 || echo "(nobody)"

v4l2-ctl -d "$SUBDEV" --set-ctrl exposure=2002,analogue_gain=16

R=$(echo "scale=3;0.5*1.034"|bc); G=$(echo "scale=3;0.5*1.000"|bc); B=$(echo "scale=3;0.5*1.246"|bc)
gst-launch-1.0 -q \
    v4l2src device=$CAM_DEV ! "video/x-bayer,format=grbg10le,width=1920,height=1080,framerate=30/1" ! \
    bayer2rgb ! videoflip method=rotate-180 ! videoconvert ! "video/x-raw,format=RGBA" ! \
    frei0r-filter-coloradj-rgb r=$R g=$G b=$B keep-luma=false ! videoconvert ! "video/x-raw,format=YUY2" ! \
    v4l2sink device=$VIRT sync=false > /tmp/obs_gst.log 2>&1 &
GST=$!
echo "Feeding for 6s (gst pid $GST)..."
sleep 6

echo "=== Virtual camera negotiated format ==="
v4l2-ctl -d "$VIRT" --get-fmt-video | grep -iE 'Width|Pixel'
echo "=== Reading 1 frame back from $VIRT ==="
v4l2-ctl -d "$VIRT" --stream-mmap --stream-count=1 --stream-to=/tmp/obs.raw
ls -l /tmp/obs.raw
EXPECT=$((1920*1080*2)); echo "Expected YUY2 1080p frame size: $EXPECT bytes"

kill $GST 2>/dev/null || true; wait $GST 2>/dev/null || true
echo "=== gst log tail ==="; tail -5 /tmp/obs_gst.log