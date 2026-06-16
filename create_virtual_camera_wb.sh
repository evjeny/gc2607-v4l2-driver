#!/bin/bash
# Create a virtual RGB camera with custom white-balance gains.
# Thin wrapper around gc2607-stream.sh.
#
# Usage: ./create_virtual_camera_wb.sh [r_gain] [g_gain] [b_gain]
#        (defaults to the measured gray-world gains baked into gc2607-stream.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_ARGS=(OUT_FORMAT=YUY2 FPS=30 CARD_LABEL="aGC2607 WB")
[ -n "${1:-}" ] && ENV_ARGS+=("R_GAIN=$1")
[ -n "${2:-}" ] && ENV_ARGS+=("G_GAIN=$2")
[ -n "${3:-}" ] && ENV_ARGS+=("B_GAIN=$3")

exec env "${ENV_ARGS[@]}" "$SCRIPT_DIR/gc2607-stream.sh"
