#!/bin/bash
# Install all prerequisites for the GC2607 V4L2 driver on Ubuntu 24.04.4 LTS.
#
# Idempotent: safe to re-run. Installs build tools, kernel headers matching the
# running kernel, V4L2/I2C tooling, GStreamer + frei0r (for white balance),
# v4l2loopback (virtual camera), and the Python imaging libraries used by the
# view_raw_*.py / calculate_wb_gains.py helpers.

set -e

KERNEL_VER="$(uname -r)"

echo "==========================================="
echo "GC2607 Driver - Ubuntu Prerequisites"
echo "==========================================="
echo "Running kernel: $KERNEL_VER"
echo ""

if ! command -v apt-get >/dev/null 2>&1; then
    echo "❌ This installer targets Ubuntu/Debian (apt). Aborting."
    exit 1
fi

# Kernel headers: try the exact running-kernel package first, then fall back to
# the OEM/HWE metapackages. DKMS (v4l2loopback) and the out-of-tree builds need
# headers that match $(uname -r).
HEADER_PKG="linux-headers-${KERNEL_VER}"
HEADER_FALLBACKS=("linux-headers-oem-24.04" "linux-headers-generic-hwe-24.04" "linux-headers-generic")

PACKAGES=(
    build-essential
    zstd
    v4l-utils
    i2c-tools
    gstreamer1.0-tools
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-bad
    frei0r-plugins
    v4l2loopback-dkms
    v4l2loopback-utils
    python3-numpy
    python3-pil
    feh
    bc
    acpica-tools
    dpkg-dev
)

echo "Step 1: Updating package lists..."
sudo apt-get update
echo ""

echo "Step 2: Installing kernel headers for $KERNEL_VER..."
if apt-get install -y --dry-run "$HEADER_PKG" >/dev/null 2>&1; then
    sudo apt-get install -y "$HEADER_PKG"
    echo "✅ Installed $HEADER_PKG"
else
    echo "⚠️  $HEADER_PKG not directly available; installing metapackage fallback(s)."
    for pkg in "${HEADER_FALLBACKS[@]}"; do
        if sudo apt-get install -y "$pkg" 2>/dev/null; then
            echo "✅ Installed $pkg"
            break
        fi
    done
fi
echo ""

echo "Step 3: Installing build and runtime packages..."
sudo apt-get install -y "${PACKAGES[@]}"
echo ""

echo "Step 4: Verifying kernel build tree..."
if [ -d "/lib/modules/${KERNEL_VER}/build" ]; then
    echo "✅ /lib/modules/${KERNEL_VER}/build present"
else
    echo "⚠️  /lib/modules/${KERNEL_VER}/build is missing."
    echo "   The exact headers for the running kernel may not be installed."
    echo "   Available header packages:"
    dpkg -l 'linux-headers*' | awk '/^ii/{print "     "$2}'
    echo "   If you booted the OEM kernel, reboot after installing matching headers."
fi
echo ""

echo "==========================================="
echo "✅ Prerequisites installation complete"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Build the sensor driver:        make"
echo "  2. Patch + build the IPU6 bridge:  ./setup_ipu_bridge_mod.sh && ./compile_ipu_bridge_simple.sh"
echo "  3. Reboot, then load + test the camera (see README.md / CLAUDE.md)."
echo ""
