#!/bin/bash
# GC2607 virtual-camera streaming daemon.
#
# Loads the sensor, configures the IPU6 media pipeline, resets v4l2loopback, and
# streams the raw Bayer frames through bayer2rgb + gray-world white balance into
# the loopback so OBS / Meet / Zoom / Chrome see a normal RGB webcam.
#
# Designed to run either manually (sudo ./gc2607-stream.sh) or as the
# gc2607-camera.service systemd unit. Runs the GStreamer pipeline in the
# foreground so systemd can supervise it.
#
# Tunables (environment variables):
#   OUT_FORMAT   output pixel format for the loopback (default YUY2; I420 for Chrome)
#   FPS          output frame rate (default 30)
#   CARD_LABEL   v4l2loopback card label (default "GC2607 Camera")
#   R_GAIN/G_GAIN/B_GAIN  white-balance gains (default: measured gray-world values)
#   EXPOSURE/GAIN         sensor controls (default 2002 / 16)

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUT_FORMAT="${OUT_FORMAT:-YUY2}"
FPS="${FPS:-30}"
CARD_LABEL="${CARD_LABEL:-GC2607 Camera}"
EXPOSURE="${EXPOSURE:-2000}"
GAIN="${GAIN:-9}"

# Hardcoded white-balance gains (tuned with tune_wb.sh until R/G=B/G=1.0 at the
# pipeline output). Green dominates the raw Bayer stream, so red/blue are boosted
# relative to green. Applied as per-channel frei0r "levels" multipliers.
R_GAIN="${R_GAIN:-1.77}"
B_GAIN="${B_GAIN:-1.54}"

log() { echo "[gc2607-stream] $*"; }

if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

# --- 1. Load kernel modules (idempotent) --------------------------------------
log "Loading kernel modules..."
for m in videodev v4l2-async ipu_bridge intel-ipu6 intel-ipu6-isys; do
    $SUDO modprobe "$m" 2>/dev/null || true
done
if ! lsmod | grep -q '^gc2607'; then
    $SUDO insmod "$SCRIPT_DIR/gc2607.ko" 2>/dev/null || $SUDO modprobe gc2607 2>/dev/null || true
fi

# --- 2. Resolve camera nodes (wait for the sensor to bind) --------------------
log "Waiting for camera nodes..."
for _ in $(seq 1 30); do
    if source "$SCRIPT_DIR/camera_env.sh" 2>/dev/null && [ -n "${CAM_DEV:-}" ] && [ -n "${SUBDEV:-}" ]; then
        break
    fi
    sleep 1
done
if [ -z "${CAM_DEV:-}" ] || [ -z "${SUBDEV:-}" ]; then
    log "ERROR: camera not ready (CAM_DEV='${CAM_DEV:-}' SUBDEV='${SUBDEV:-}')"
    exit 1
fi
log "Camera: $CAM_DEV   Sensor: $SUBDEV   Media: $MEDIA_DEV"

# --- 3. Configure the IPU6 media pipeline -------------------------------------
log "Configuring media pipeline..."
media-ctl -d "$MEDIA_DEV" -V '"Intel IPU6 CSI2 0":0 [fmt:SGRBG10_1X10/1920x1080]' 2>/dev/null || true
media-ctl -d "$MEDIA_DEV" -V '"Intel IPU6 CSI2 0":1 [fmt:SGRBG10_1X10/1920x1080]' 2>/dev/null || true
v4l2-ctl -d "$CAM_DEV" --set-fmt-video=width=1920,height=1080,pixelformat=BA10 >/dev/null
media-ctl -d "$MEDIA_DEV" -l '"Intel IPU6 CSI2 0":1 -> "Intel IPU6 ISYS Capture 0":0[1]' 2>/dev/null || true

# --- 4. Sensor exposure / gain -----------------------------------------------
v4l2-ctl -d "$SUBDEV" --set-ctrl "exposure=$EXPOSURE,analogue_gain=$GAIN" 2>/dev/null || true

# --- 5. Reset v4l2loopback (stop v4l2-relayd which holds it open) -------------
log "Resetting v4l2loopback..."
$SUDO systemctl stop v4l2-relayd 2>/dev/null || true
sleep 1
$SUDO modprobe -r v4l2loopback 2>/dev/null || true
$SUDO modprobe v4l2loopback devices=1 card_label="$CARD_LABEL" exclusive_caps=1 max_buffers=2
sleep 1

VIRT_DEV=""
for d in /dev/video*; do
    [ -e "$d" ] || continue
    if [ "$(v4l2-ctl -d "$d" --info 2>/dev/null | awk -F': ' '/Driver name/{print $2}')" = "v4l2 loopback" ]; then
        VIRT_DEV="$d"; break
    fi
done
if [ -z "$VIRT_DEV" ]; then
    log "ERROR: v4l2loopback device not found after reload"
    exit 1
fi
log "Virtual camera: $VIRT_DEV  (label: \"$CARD_LABEL\")"

# --- 6. White balance --------------------------------------------------------
# Per-channel multiply via frei0r "levels": input-white-level = 1/gain boosts a
# channel by `gain`. Green is the reference (untouched). show-histogram=false is
# mandatory (it defaults to true and would overlay a histogram on the video).
iw() { awk -v g="$1" 'BEGIN{w=1.0/g; if(w>1)w=1; if(w<0.05)w=0.05; printf "%.4f", w}'; }
RW=$(iw "$R_GAIN"); BW=$(iw "$B_GAIN")
log "White balance: R_GAIN=$R_GAIN (input-white=$RW)  B_GAIN=$B_GAIN (input-white=$BW)"

# --- 7. Stream ---------------------------------------------------------------
log "Streaming $CAM_DEV -> $VIRT_DEV ($OUT_FORMAT ${FPS}fps). Ctrl+C to stop."
exec gst-launch-1.0 -e \
    v4l2src device="$CAM_DEV" ! \
    "video/x-bayer,format=grbg10le,width=1920,height=1080,framerate=$FPS/1" ! \
    bayer2rgb ! \
    videoflip method=rotate-180 ! \
    videoconvert ! \
    "video/x-raw,format=RGBA" ! \
    frei0r-filter-levels channel=0.0 input-white-level="$RW" show-histogram=false ! \
    frei0r-filter-levels channel=0.2 input-white-level="$BW" show-histogram=false ! \
    videoconvert ! \
    "video/x-raw,format=$OUT_FORMAT,framerate=$FPS/1" ! \
    v4l2sink device="$VIRT_DEV" sync=false
