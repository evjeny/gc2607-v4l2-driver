#!/bin/bash
# Create a virtual RGB camera for OBS Studio / Meet / Zoom (YUY2, 30fps).
# Thin wrapper around gc2607-stream.sh (the single streaming implementation).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env OUT_FORMAT=YUY2 FPS=30 CARD_LABEL="GC2607 Camera" \
    "$SCRIPT_DIR/gc2607-stream.sh"
