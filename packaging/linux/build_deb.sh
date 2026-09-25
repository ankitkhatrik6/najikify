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

# 4. Install the icon and EXACTLY ONE desktop entry.
#
# A single launcher is installed as usr/share/applications/najikify.desktop.
# Earlier builds installed the very same file twice — once as najikify.desktop
# and once under the GTK application id (com.najikify.app.desktop) — which made
# the desktop menu show two identical "Najikify" entries launching the same
# binary. Never install a second copy here: the application id belongs in
# StartupWMClass (see packaging/linux/najikify.desktop), not in a second file.
install -Dm644 packaging/linux/najikify.desktop "${PACKAGE_DIR}/usr/share/applications/najikify.desktop"

# Defensive cleanup: drop any duplicate launcher that an older packaging layout
# (or the Flutter bundle) may have dropped into the staging tree.
rm -f "${PACKAGE_DIR}/usr/share/applications/com.najikify.app.desktop"
find "${PACKAGE_DIR}" -name '*.desktop' \
    ! -path "${PACKAGE_DIR}/usr/share/applications/najikify.desktop" -delete

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
# postinst/postrm refresh icon + desktop caches and remove the duplicate
# launcher that packages up to 1.0.6 installed as com.najikify.app.desktop.
# dpkg drops files that are gone from the new file list, but removing it here
# as well makes the menu correct even for installs that were upgraded by hand.
cat << 'EOF' > "${PACKAGE_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e
rm -f /usr/share/applications/com.najikify.app.desktop || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
exit 0
EOF
cat << 'EOF' > "${PACKAGE_DIR}/DEBIAN/postrm"
#!/bin/sh
set -e
rm -f /usr/share/applications/com.najikify.app.desktop || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
exit 0
EOF
chmod 0755 "${PACKAGE_DIR}/DEBIAN/postinst" "${PACKAGE_DIR}/DEBIAN/postrm"

# 4b. Guard: the staging tree must hold exactly one launcher. Fail loudly
# instead of shipping a package with duplicate application-menu entries.
ENTRY_COUNT="$(find "${PACKAGE_DIR}/usr/share/applications" -maxdepth 1 -name '*.desktop' | wc -l)"
if [ "${ENTRY_COUNT}" -ne 1 ]; then
    echo "ERROR: expected exactly 1 desktop entry, found ${ENTRY_COUNT}:" >&2
    find "${PACKAGE_DIR}/usr/share/applications" -maxdepth 1 -name '*.desktop' >&2
    exit 1
fi
echo "Desktop entries: $(cd "${PACKAGE_DIR}/usr/share/applications" && ls -1)"

# 5. Write control file
# Replaces: the .deb keeps the stable package identity (name + arch) and a
# strictly increasing Version so `sudo apt install ./najikify-*.deb` upgrades
# the installed release instead of conflicting with it. (A conflicting
# applicationId or a downgraded versionCode would produce the same error on
# Android; both are kept stable there too.)
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
DEB_PATH="build/${APP_NAME}-linux-${VERSION}-${ARCH}.deb"
dpkg-deb --root-owner-group --build "${PACKAGE_DIR}" "${DEB_PATH}"

# 7. Verify the finished package: it must ship exactly one Najikify launcher.
# This is the check that would have caught the duplicate desktop entry.
dpkg-deb -c "${DEB_PATH}" | grep -o 'usr/share/applications/[^ ]*\.desktop' | sort -u > /tmp/najikify-deb-entries.txt || true
DEB_ENTRY_COUNT="$(wc -l < /tmp/najikify-deb-entries.txt | tr -d ' ')"
echo "Launchers inside ${DEB_PATH} (${DEB_ENTRY_COUNT}):"
cat /tmp/najikify-deb-entries.txt
if [ "${DEB_ENTRY_COUNT}" -ne 1 ] || ! grep -q '^usr/share/applications/najikify\.desktop$' /tmp/najikify-deb-entries.txt; then
    echo "ERROR: ${DEB_PATH} must contain exactly one launcher " \
         "(usr/share/applications/najikify.desktop)." >&2
    exit 1
fi

echo "=== Successfully built ${DEB_PATH} ==="
