#!/bin/bash
# Install gc2607-camera.service so the virtual webcam starts automatically at
# boot (loads the driver, configures the IPU6 pipeline, and streams RGB+WB into
# a v4l2loopback device for OBS / Meet / Zoom / Chrome).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT=/etc/systemd/system/gc2607-camera.service

echo "=== Installing gc2607-camera.service ==="
echo "Repo: $SCRIPT_DIR"
echo ""

# v4l2-relayd holds the boot-time loopback open and fights for it; the raw GC2607
# is not a libcamera sensor, so relayd is useless here. Mask it.
echo "Masking v4l2-relayd (frees the v4l2loopback device)..."
sudo systemctl mask --now v4l2-relayd 2>/dev/null || true

echo "Writing $UNIT ..."
sudo tee "$UNIT" >/dev/null <<EOF
[Unit]
Description=GC2607 virtual camera (Bayer->RGB+WB into v4l2loopback)
After=multi-user.target
Conflicts=v4l2-relayd.service

[Service]
Type=simple
# Output format/fps for the virtual camera. Use I420 / 24 for Chrome/Meet.
Environment=OUT_FORMAT=YUY2
Environment=FPS=30
Environment=CARD_LABEL=GC2607 Camera
ExecStart=$SCRIPT_DIR/gc2607-stream.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and enabling the service..."
sudo systemctl daemon-reload
sudo systemctl enable --now gc2607-camera.service
sleep 3

echo ""
echo "=== Service status ==="
sudo systemctl status --no-pager gc2607-camera.service | head -15 || true
echo ""
echo "✅ Installed. The virtual camera ('GC2607 Camera') starts at every boot."
echo ""
echo "Manage it with:"
echo "  sudo systemctl status gc2607-camera     # check"
echo "  sudo systemctl restart gc2607-camera    # restart"
echo "  sudo systemctl disable --now gc2607-camera   # turn off autostart"
echo "  journalctl -u gc2607-camera -b          # logs since boot"
echo ""
echo "To switch to Chrome/Meet (I420/24fps), edit $UNIT:"
echo "  Environment=OUT_FORMAT=I420  /  Environment=FPS=24  then: sudo systemctl daemon-reload && sudo systemctl restart gc2607-camera"
