#!/usr/bin/env bash
#
# Najikify — Linux build dependency installer
#
# Installs the native toolchain required to build the Linux desktop app and
# the Debian package, then opens the Najikify network ports.
#
# Usage:  sudo bash packaging/linux/install_deps.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root:  sudo bash packaging/linux/install_deps.sh" >&2
    exit 1
fi

echo "=== [1/3] Updating package lists ==="
apt update

echo "=== [2/3] Installing build toolchain ==="
apt install -y \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    libsqlite3-dev \
    adb

echo "=== [3/3] Opening Najikify firewall ports (UFW) ==="
if command -v ufw >/dev/null 2>&1; then
    ufw allow 53317/tcp || true   # HTTP file streaming
    ufw allow 53318/udp || true   # LAN peer discovery
else
    echo "ufw not installed, skipping firewall rules."
fi

echo
echo "=== Verifying toolchain ==="
for tool in clang cmake ninja pkg-config; do
    printf '  %-12s %s\n' "$tool" "$(command -v "$tool" || echo MISSING)"
done
if pkg-config --exists gtk+-3.0; then
    echo "  gtk+-3.0     OK ($(pkg-config --modversion gtk+-3.0))"
else
    echo "  gtk+-3.0     MISSING"
fi

echo
echo "=== Done. Next steps ==="
echo "  flutter doctor              # Linux toolchain should now be green"
echo "  bash packaging/linux/build_deb.sh"