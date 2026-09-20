#!/usr/bin/env bash
set -e

echo "=== Building Najikify Linux .deb Package ==="

APP_NAME="najikify"
VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"
PACKAGE_DIR="build/linux-pkg/${APP_NAME}_${VERSION}_${ARCH}"

# 1. Build Flutter release bundle for Linux
flutter build linux --release

# 2. Prepare directory tree for .deb packaging
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/usr/bin"
mkdir -p "${PACKAGE_DIR}/usr/lib/${APP_NAME}"
mkdir -p "${PACKAGE_DIR}/usr/share/applications"
mkdir -p "${PACKAGE_DIR}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${PACKAGE_DIR}/DEBIAN"

# 3. Copy binary artifacts
cp -r build/linux/x64/release/bundle/* "${PACKAGE_DIR}/usr/lib/${APP_NAME}/"
ln -sf "/usr/lib/${APP_NAME}/${APP_NAME}" "${PACKAGE_DIR}/usr/bin/${APP_NAME}"

# 5. Install icons + desktop file (with 16/22/24/32 fallbacks), then refresh caches.
install -Dm644 packaging/linux/najikify.desktop "${PACKAGE_DIR}/usr/share/applications/najikify.desktop"
install -Dm644 packaging/linux/najikify.desktop "${PACKAGE_DIR}/usr/share/applications/com.najikify.app.desktop"
if [ -f "packaging/linux/icons/najikify.svg" ]; then
    install -Dm644 packaging/linux/icons/najikify.svg "${PACKAGE_DIR}/usr/share/icons/hicolor/scalable/apps/najikify.svg"
fi
for size in 16 22 24 32 48 128 256 512; do
    src=""
    if [ -f "packaging/linux/icons/hicolor/${size}x${size}/apps/najikify.png" ]; then
        src="packaging/linux/icons/hicolor/${size}x${size}/apps/najikify.png"
    elif [ -f "assets/icons/najikify.png" ]; then
        src="assets/icons/najikify.png"
    fi
    if [ -n "$src" ]; then
        mkdir -p "${PACKAGE_DIR}/usr/share/icons/hicolor/${size}x${size}/apps"
        if [ "$src" = "assets/icons/najikify.png" ]; then
            python3 -c "from PIL import Image; im=Image.open('$src').convert('RGBA').resize(($size,$size), Image.LANCZOS); im.save('${PACKAGE_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/najikify.png')" 2>/dev/null || cp "$src" "${PACKAGE_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/najikify.png"
        else
            cp "$src" "${PACKAGE_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/najikify.png"
        fi
    fi
done
install -Dm644 assets/icons/najikify.png "${PACKAGE_DIR}/usr/share/pixmaps/najikify.png"
# postinst/postrm refresh icon + desktop caches
cat << 'EOF' > "${PACKAGE_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
exit 0
EOF
cat << 'EOF' > "${PACKAGE_DIR}/DEBIAN/postrm"
#!/bin/sh
set -e
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
exit 0
EOF
chmod 0755 "${PACKAGE_DIR}/DEBIAN/postinst" "${PACKAGE_DIR}/DEBIAN/postrm"

# 5. Write control file
cat << EOF > "${PACKAGE_DIR}/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Depends: libgtk-3-0t64 | libgtk-3-0, libsqlite3-0
Maintainer: Ankit Khatri KC <ankikhatrik6@gmail.com>
Description: Private peer-to-peer file transfer utility for LAN.
 Direct encrypted streaming transfers across Linux and Android devices.
EOF

# 6. Build .deb package
dpkg-deb --root-owner-group --build "${PACKAGE_DIR}" "build/${APP_NAME}-linux-${VERSION}-${ARCH}.deb"

echo "=== Successfully built build/${APP_NAME}-linux-${VERSION}-${ARCH}.deb ==="
