#!/bin/bash
# Create a virtual RGB camera tuned for Chrome / Google Meet (I420, 24fps).
# Thin wrapper around gc2607-stream.sh (the single streaming implementation).
#
# Note: in Chrome/Chromium, disable chrome://flags -> "PipeWire Camera support"
# so the v4l2loopback device ("aGC2607 RGB") shows up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env OUT_FORMAT=I420 FPS=24 CARD_LABEL="aGC2607 RGB" \
    "$SCRIPT_DIR/gc2607-stream.sh"
