#!/bin/bash
# Create a virtual RGB camera (for OBS Studio, Google Meet, Zoom, etc.) by
# converting the GC2607 raw Bayer stream to RGB with white balance and feeding
# it into a v4l2loopback device.
#
# On Ubuntu the boot-time v4l2loopback instance ("Intel MIPI Camera") is left
# capture-locked by v4l2-relayd, so it cannot be fed. We reload the module to
# get a fresh device that our GStreamer pipeline can open as the producer.

set -e

echo "=== Creating Virtual RGB Camera (OBS/Meet) ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the real camera/sensor nodes (the IPU6 capture node is typically
# /dev/video1 because v4l2loopback claims /dev/video0).
source "$SCRIPT_DIR/camera_env.sh"

if ! dpkg -s v4l2loopback-dkms &>/dev/null; then
    echo "Please install: sudo apt install v4l2loopback-dkms v4l2loopback-utils"
    exit 1
fi

# v4l2-relayd holds the boot-time loopback open (it bridges libcamera cameras,
# which don't support the raw gc2607), so stop it to release the device.
echo "Stopping v4l2-relayd and resetting v4l2loopback (needs sudo)..."
sudo systemctl stop v4l2-relayd 2>/dev/null || true
sleep 1
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe v4l2loopback devices=1 card_label="GC2607 Camera" exclusive_caps=1 max_buffers=2
sleep 1

# Detect the loopback device by driver name (its video_nr is auto-assigned).
VIRT_DEV=""
for d in /dev/video*; do
    [ -e "$d" ] || continue
    if [ "$(v4l2-ctl -d "$d" --info 2>/dev/null | awk -F': ' '/Driver name/{print $2}')" = "v4l2 loopback" ]; then
        VIRT_DEV="$d"; break
    fi
done
if [ -z "$VIRT_DEV" ]; then
    echo "❌ Could not find the v4l2loopback device after reload."
    exit 1
fi

echo "Real camera:    $CAM_DEV"
echo "Virtual camera: $VIRT_DEV  (label: \"GC2607 Camera\")"
echo ""

# Optimal exposure/gain for indoor lighting.
echo "Setting camera parameters..."
v4l2-ctl -d "$SUBDEV" --set-ctrl exposure=2002,analogue_gain=16

# Gray-world white balance gains -> frei0r parameters (0.5 = neutral).
R_GAIN=1.034; G_GAIN=1.000; B_GAIN=1.246
R_PARAM=$(echo "scale=3; 0.5 * $R_GAIN" | bc)
G_PARAM=$(echo "scale=3; 0.5 * $G_GAIN" | bc)
B_PARAM=$(echo "scale=3; 0.5 * $B_GAIN" | bc)

echo ""
echo "Starting Bayer->RGB pipeline with white balance..."
echo "WB gains: R=$R_GAIN, G=$G_GAIN, B=$B_GAIN"
echo "Select \"GC2607 Camera\" in OBS/Meet. Press Ctrl+C to stop."
echo ""

# The GStreamer producer opens the loopback first, so it becomes the output side
# and apps see it as a normal capture camera.
gst-launch-1.0 -v \
    v4l2src device=$CAM_DEV ! \
    "video/x-bayer,format=grbg10le,width=1920,height=1080,framerate=30/1" ! \
    bayer2rgb ! \
    videoflip method=rotate-180 ! \
    videoconvert ! \
    "video/x-raw,format=RGBA" ! \
    frei0r-filter-coloradj-rgb r=$R_PARAM g=$G_PARAM b=$B_PARAM keep-luma=false ! \
    videoconvert ! \
    "video/x-raw,format=YUY2" ! \
    v4l2sink device=$VIRT_DEV sync=false

echo ""
echo "Pipeline stopped."
