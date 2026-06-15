#!/bin/bash
# Create virtual RGB camera with WHITE BALANCE for OBS/Meet/etc

set -e

echo "=== Creating Virtual RGB Camera with White Balance ==="
echo ""

# Resolve the actual camera/sensor nodes (v4l2loopback may take /dev/video0).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/camera_env.sh"

# Parse command line arguments for white balance gains
R_GAIN=${1:-1.2}  # Default red gain
G_GAIN=${2:-1.0}  # Default green gain (reference)
B_GAIN=${3:-1.5}  # Default blue gain

echo "White balance gains: R=$R_GAIN, G=$G_GAIN, B=$B_GAIN"
echo "(Usage: $0 [r_gain] [g_gain] [b_gain])"
echo ""

if ! dpkg -s v4l2loopback-dkms &>/dev/null; then
    echo "Please install: sudo apt install v4l2loopback-dkms v4l2loopback-utils"
    exit 1
fi

# v4l2-relayd holds the boot-time loopback open; stop it, then reset the module
# so our GStreamer producer can attach.
echo "Stopping v4l2-relayd and resetting v4l2loopback (needs sudo)..."
sudo systemctl stop v4l2-relayd 2>/dev/null || true
sleep 1
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe v4l2loopback devices=1 card_label="GC2607 RGB WB" exclusive_caps=1 max_buffers=2
sleep 1

# Detect the loopback device by driver name (video_nr is auto-assigned).
VIRT_DEV=""
for d in /dev/video*; do
    [ -e "$d" ] || continue
    if [ "$(v4l2-ctl -d "$d" --info 2>/dev/null | awk -F': ' '/Driver name/{print $2}')" = "v4l2 loopback" ]; then
        VIRT_DEV="$d"; break
    fi
done
if [ -z "$VIRT_DEV" ]; then
    echo "Error: Could not find virtual camera device"
    exit 1
fi

echo "Real camera:    $CAM_DEV"
echo "Virtual camera: $VIRT_DEV  (label: \"GC2607 RGB WB\")"
echo ""

# Set optimal exposure/gain for good brightness
# Exposure: 2002 (max), Gain: 16 (max, LUT index)
echo "Setting camera parameters..."
v4l2-ctl -d "$SUBDEV" --set-ctrl exposure=2002,analogue_gain=16

echo ""
echo "Starting Bayer to RGB conversion pipeline with WHITE BALANCE..."
echo "Press Ctrl+C to stop"
echo ""
echo "Adjust white balance by restarting with different gains:"
echo "  $0 1.0 1.0 1.3  # Reduce red, increase blue"
echo "  $0 1.5 1.0 1.2  # Increase red, increase blue"
echo ""

# GStreamer pipeline with white balance using frei0r coloradj_RGB
# frei0r r/g/b parameters: 0.0-1.0, where 0.5 is neutral (1.0x gain)
# Convert our gains to frei0r parameters: param = 0.5 * gain
R_PARAM=$(echo "scale=3; 0.5 * $R_GAIN" | bc)
G_PARAM=$(echo "scale=3; 0.5 * $G_GAIN" | bc)
B_PARAM=$(echo "scale=3; 0.5 * $B_GAIN" | bc)

echo "Frei0r RGB parameters: r=$R_PARAM, g=$G_PARAM, b=$B_PARAM"
echo ""

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
    v4l2sink device=$VIRT_DEV

echo ""
echo "Pipeline stopped."
