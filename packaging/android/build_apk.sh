#!/usr/bin/env bash
set -e

echo "=== Building LocalDrop Android .apk Package ==="

# 1. Build release APK with split per ABI or universal APK
flutter build apk --release

echo "=== Release APK generated at build/app/outputs/flutter-apk/app-release.apk ==="
