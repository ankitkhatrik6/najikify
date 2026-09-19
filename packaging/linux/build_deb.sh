#!/usr/bin/env bash
set -e

echo "=== Building LocalDrop Linux .deb Package ==="

APP_NAME="localdrop"
VERSION="1.0.0"
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

# 4. Copy desktop entry & icon
cp packaging/linux/localdrop.desktop "${PACKAGE_DIR}/usr/share/applications/"
if [ -f "assets/icons/localdrop.svg" ]; then
    cp assets/icons/localdrop.svg "${PACKAGE_DIR}/usr/share/icons/hicolor/scalable/apps/localdrop.svg"
fi

# 5. Write control file
cat << EOF > "${PACKAGE_DIR}/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Depends: libgtk-3-0t64 | libgtk-3-0, libsqlite3-0
Maintainer: LocalDrop Contributors <support@localdrop.org>
Description: Private peer-to-peer file transfer utility for LAN.
 Direct encrypted streaming transfers across Linux and Android devices.
EOF

# 6. Build .deb package
dpkg-deb --root-owner-group --build "${PACKAGE_DIR}" "build/${APP_NAME}-linux-${VERSION}-${ARCH}.deb"

echo "=== Successfully built build/${APP_NAME}-linux-${VERSION}-${ARCH}.deb ==="
