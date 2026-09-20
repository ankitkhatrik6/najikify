#!/usr/bin/env bash
#
# Najikify — second-desktop setup script
#
# Installs the Najikify .deb on another Linux desktop, plus its runtime
# dependencies and the firewall rules needed for LAN discovery + transfer.
#
# Usage:
#   1. Copy this script and the .deb to the other desktop, e.g.:
#        scp build/najikify-linux-1.0.0-amd64.deb packaging/linux/setup_client.sh user@otherpc:~/
#      (or copy them via USB drive — both files must sit in the same folder)
#
#   2. On the other desktop run:
#        sudo bash setup_client.sh
#
#   Optional: pass the .deb path explicitly
#        sudo bash setup_client.sh /path/to/najikify-linux-1.0.0-amd64.deb
#
set -euo pipefail

DEB_PATH="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root:  sudo bash setup_client.sh" >&2
    exit 1
fi

# --- Locate the .deb -------------------------------------------------------
if [ -z "$DEB_PATH" ]; then
    DEB_PATH="$(find "$SCRIPT_DIR" -maxdepth 1 -name 'najikify*.deb' | head -n 1 || true)"
fi

if [ -z "$DEB_PATH" ] || [ ! -f "$DEB_PATH" ]; then
    echo "Could not find the Najikify .deb file." >&2
    echo "Put najikify-linux-*.deb next to this script, or pass its path:" >&2
    echo "  sudo bash setup_client.sh /path/to/najikify-linux-1.0.0-amd64.deb" >&2
    exit 1
fi

echo "=== Using package: $DEB_PATH ==="

echo "=== [1/4] Installing runtime dependencies ==="
apt update
# libgtk-3-0t64 is the 64-bit time_t build used by Ubuntu 24.04+/Debian trixie+;
# libgtk-3-0 is the older name still used by earlier releases.
apt install -y \
    libgtk-3-0t64 \
    libsqlite3-0 2>/dev/null || apt install -y libgtk-3-0 libsqlite3-0

echo "=== [2/4] Installing Najikify ==="
apt install -y "$DEB_PATH"

echo "=== [3/4] Opening Najikify firewall ports (UFW) ==="
if command -v ufw >/dev/null 2>&1; then
    ufw allow 53317/tcp || true   # HTTP file streaming
    ufw allow 53318/udp || true   # LAN peer discovery
else
    echo "ufw not installed, skipping firewall rules."
fi

echo "=== [4/4] Verifying installation ==="
if command -v najikify >/dev/null 2>&1; then
    echo "  binary:  $(command -v najikify)"
    missing="$(ldd /usr/lib/najikify/najikify 2>/dev/null | grep -c 'not found' || true)"
    if [ "$missing" = "0" ]; then
        echo "  libraries: OK (all resolved)"
    else
        echo "  libraries: $missing MISSING — install the missing packages and re-run"
    fi
else
    echo "  najikify command not found — installation may have failed" >&2
    exit 1
fi

cat <<'EOF'

=== Najikify is ready on this desktop ===

Now do the same (or just install the .deb) on the first desktop, then:
  1. Open Najikify on both desktops (app launcher -> Najikify, or run: najikify)
  2. Both must be on the same Wi-Fi / LAN
  3. Wait for the other machine to appear under "Devices"
  4. Click a device to connect, then use "Send Files" / "Send Folder"

If the other desktop never appears:
  - check both machines allow ports 53317/tcp and 53318/udp
    (sudo ufw status)
  - make sure the two machines are on the same subnet and client isolation
    (AP isolation) is disabled on the router
EOF
