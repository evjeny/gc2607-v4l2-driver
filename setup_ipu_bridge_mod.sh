#!/bin/bash
# Fetch the Ubuntu kernel's ipu-bridge.c, add GC2607 (GCTI2607) support, and
# stage it locally for building. Targets Ubuntu 24.04.4 LTS.
#
# The stock Ubuntu ipu-bridge module does NOT list GCTI2607, so the bridge must
# be rebuilt with an extra IPU_SENSOR_CONFIG entry. We build just that one
# module out-of-tree against the installed kernel headers, so we only need the
# matching ipu-bridge.c source file (fetched via `apt-get source`).

set -e

KERNEL_VER="$(uname -r)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="${KERNEL_SRC:-$SCRIPT_DIR/kernel-src}"
STAGED_SRC="$KERNEL_SRC/ipu-bridge.c"

echo "==========================================="
echo "IPU Bridge Modification Setup (Ubuntu)"
echo "==========================================="
echo "Running kernel: $KERNEL_VER"
echo "Staging dir:    $KERNEL_SRC"
echo ""

# Step 0: kernel headers (needed later to build the module)
if [ ! -d "/lib/modules/$KERNEL_VER/build" ]; then
    echo "⚠️  Kernel headers for $KERNEL_VER are not installed."
    echo "   Run ./install_prereqs_ubuntu.sh first (it installs linux-headers-$KERNEL_VER)."
    echo ""
fi

mkdir -p "$KERNEL_SRC"

# Step 1: obtain ipu-bridge.c matching the running kernel
echo "Step 1: Fetching ipu-bridge.c source..."
echo "---------------------------------------"
if [ -f "$STAGED_SRC" ]; then
    echo "✅ Source already staged at $STAGED_SRC (delete it to refetch)."
else
    # `apt-get source` needs deb-src enabled. The Ubuntu 24.04 sources are in
    # the deb822 file /etc/apt/sources.list.d/ubuntu.sources.
    if ! apt-get source --download-only "linux-image-unsigned-$KERNEL_VER" 2>/dev/null; then
        echo "⚠️  'apt-get source' failed. Enable source packages first, e.g.:"
        echo "    sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources"
        echo "    sudo apt-get update"
        echo "   Then re-run this script. Fetching the source as your user:"
        echo "    cd $KERNEL_SRC && apt-get source linux-image-unsigned-$KERNEL_VER"
        echo ""
        echo "   Alternatively set KERNEL_SRC to a tree that already contains"
        echo "   drivers/media/pci/intel/ipu-bridge.c and re-run."
        exit 1
    fi
    cd "$KERNEL_SRC"
    apt-get source "linux-image-unsigned-$KERNEL_VER"
    FOUND=$(find "$KERNEL_SRC" -path '*/drivers/media/pci/intel/ipu-bridge.c' | head -1)
    if [ -z "$FOUND" ]; then
        echo "❌ Could not locate ipu-bridge.c in the fetched source."
        exit 1
    fi
    cp "$FOUND" "$STAGED_SRC"
    echo "✅ Staged source: $STAGED_SRC"
fi
echo ""

# Step 2: add the GC2607 entry (idempotent)
echo "Step 2: Adding GC2607 (GCTI2607) sensor entry..."
echo "---------------------------------------"
if grep -q "GCTI2607" "$STAGED_SRC"; then
    echo "✅ GCTI2607 entry already present."
else
    # Insert our entry as the first element of the IPU_SENSOR_CONFIG array, by
    # prepending it ahead of the first existing IPU_SENSOR_CONFIG() occurrence.
    sed -i '0,/IPU_SENSOR_CONFIG(/s//\t\/* GalaxyCore GC2607 *\/\n\tIPU_SENSOR_CONFIG("GCTI2607", 1, 336000000),\n\tIPU_SENSOR_CONFIG(/' "$STAGED_SRC"
    if grep -q "GCTI2607" "$STAGED_SRC"; then
        echo "✅ GCTI2607 entry added."
    else
        echo "❌ Failed to add entry automatically. Add this line to the"
        echo "   IPU_SENSOR_CONFIG table in $STAGED_SRC manually:"
        echo '     IPU_SENSOR_CONFIG("GCTI2607", 1, 336000000),'
        exit 1
    fi
fi
echo ""

echo "==========================================="
echo "Setup complete."
echo "==========================================="
echo "Patched source: $STAGED_SRC"
echo ""
echo "Next: build + install the module:"
echo "  ./compile_ipu_bridge_simple.sh"
echo ""
