<div align="center">

# LocalDrop

**Private peer-to-peer file transfer for your local network.**

Move files and folders directly between Linux desktops and Android devices — no cloud, no accounts, no third-party uploads. Your data never leaves your Wi-Fi.

[![CI](https://github.com/ankitkhatrik6/localdrop/actions/workflows/ci.yml/badge.svg)](https://github.com/ankitkhatrik6/localdrop/actions/workflows/ci.yml)
[![Build & Release](https://github.com/ankitkhatrik6/localdrop/actions/workflows/release.yml/badge.svg)](https://github.com/ankitkhatrik6/localdrop/actions/workflows/release.yml)
[![Release](https://img.shields.io/github/v/release/ankitkhatrik6/localdrop?include_prereleases&sort=semver)](https://github.com/ankitkhatrik6/localdrop/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20Android-informational)](#supported-platforms)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

</div>

---

## Overview

LocalDrop turns any two devices on the same Wi-Fi or LAN into a direct transfer channel. It discovers peers automatically, streams files over HTTP with checksum verification, and keeps a local history of everything sent and received.

- **No cloud, no accounts.** Nothing is uploaded anywhere — transfers are strictly device-to-device.
- **Automatic discovery.** Peers on the same subnet find each other over UDP multicast/broadcast; no IP addresses to type.
- **QR pairing.** Optional trust-on-first-use pairing via QR code for a persistent trusted-device list.
- **Verified transfers.** Files stream over HTTP with per-file checksums and configurable conflict handling.
- **Cross-platform.** Linux desktop and Android from one Flutter codebase.

## Supported Platforms

| Platform | Artifact | Build command |
|----------|----------|---------------|
| Linux (Debian/Ubuntu, x86-64) | `.deb` package | `bash packaging/linux/build_deb.sh` |
| Linux (Debian/Ubuntu, x86-64) | Portable bundle | `flutter build linux --release` |
| Android | Universal `.apk` | `flutter build apk --release` |
| Android | Per-ABI `.apk` (smaller) | `flutter build apk --split-per-abi --release` |

> **No local Android SDK required.** Every push builds the `.deb` and `.apk` in GitHub Actions — see [Downloads](#downloads).

## How It Works

```
  Device A                     Network                        Device B
 +-------------+                                            +-------------+
 | Discovery   | --- UDP 53318 broadcast/multicast -------> | Discovery   |
 | (announce)  | <-- peer presence, every 4s --------------- | (announce)  |
 +-------------+                                            +-------------+
 | HTTP server | <-- GET /handshake, /transfer/init -------- | Send engine |
 |  dart:io    | --- stream file bytes over HTTP 53317 ----> |             |
 +-------------+                                            +-------------+
 | SQLite      |     local history, trusted devices         | SQLite      |
 +-------------+                                            +-------------+
```

1. **Discovery** — each peer broadcasts a presence announcement on UDP `53318` every 4 seconds and drops peers silent for 12 seconds.
2. **Handshake** — the sender calls `/handshake` on the receiver's HTTP server to exchange device metadata and obtain a session token.
3. **Transfer** — files stream over HTTP to the receiver; progress, speed and ETA update live on both ends.
4. **Verification** — checksums are compared per file; conflicts resolve via replace / keep-both / skip.
5. **History** — each side records the transfer in a local SQLite database (`sqflite` on Android, `sqflite_common_ffi` on desktop).

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `53317` | TCP | HTTP file streaming |
| `53318` | UDP | Peer discovery + presence announcements |

## Downloads

Prebuilt artifacts are published automatically by GitHub Actions.

- **Latest release** → [releases/latest](https://github.com/ankitkhatrik6/localdrop/releases/latest)
- **Artifacts from `main`** → [Actions → Build & Release](https://github.com/ankitkhatrik6/localdrop/actions/workflows/release.yml) → pick a run → **Artifacts**

| File | Platform |
|------|----------|
| `localdrop-linux-<version>-amd64.deb` | Debian / Ubuntu (x86-64) |
| `localdrop-linux-<version>-amd64.tar.gz` | Portable Linux bundle |
| `localdrop-android-<version>.apk` | Universal Android APK |

## Installation

### Linux (Debian / Ubuntu)

Download the `.deb` from [Releases](https://github.com/ankitkhatrik6/localdrop/releases/latest), then:

```bash
sudo apt install ./localdrop-linux-1.0.0-amd64.deb

# Required so peers can discover and reach each other
sudo ufw allow 53317/tcp
sudo ufw allow 53318/udp
```

Launch **LocalDrop** from your application menu (under *Network* / *File Transfer*), or:

```bash
localdrop
```

<details>
<summary>Building the <code>.deb</code> yourself</summary>

```bash
sudo bash packaging/linux/install_deps.sh   # clang, cmake, ninja, pkg-config, GTK3, SQLite dev
bash packaging/linux/build_deb.sh           # -> build/localdrop-linux-<version>-<arch>.deb
```
</details>

### Android

1. Download `localdrop-android-<version>.apk` from [Releases](https://github.com/ankitkhatrik6/localdrop/releases/latest).
2. Open it on the device and allow installation from unknown sources when prompted.
3. Grant camera (QR pairing) and storage/media permissions on first launch.

> The APK is signed with the debug key so it installs directly on any device. For Play Store distribution, configure a release keystore.

## Quick Start

```bash
# 1. Connect both devices to the same Wi-Fi / LAN

# 2. Start LocalDrop on both
localdrop

# 3. The other device appears under "Devices" on the Home tab within seconds

# 4. Click "Send Files" (or "Send Folder"), pick a device, then Accept on the receiver
```

### Requirements for a successful transfer

- Both devices on the **same subnet**.
- **Client / AP isolation disabled** on the router or access point — it blocks device-to-device traffic.
- Firewalls allow **`53317/tcp`** and **`53318/udp`** on both devices.

## Development

### Prerequisites

- **Flutter** 3.47+ (stable) with Linux desktop enabled:
  ```bash
  flutter config --enable-linux-desktop
  ```
- **Linux toolchain** — `clang cmake ninja-build pkg-config libgtk-3-dev libsqlite3-dev adb`:
  ```bash
  sudo bash packaging/linux/install_deps.sh
  ```
- **Android** — Android SDK (platform 35+), build-tools, and JDK 17+.

Verify your setup:

```bash
flutter doctor
```

### Run and test

```bash
flutter pub get          # fetch dependencies
flutter test             # unit + widget test suite
flutter analyze          # static analysis
flutter run -d linux     # run on the Linux desktop
flutter run              # run on a connected Android device (adb devices)
```

### Building

```bash
flutter build linux --release            # Linux bundle   -> build/linux/x64/release/bundle/
bash packaging/linux/build_deb.sh        # Debian package -> build/*.deb
flutter build apk --release              # Android APK    -> build/app/outputs/flutter-apk/app-release.apk
bash packaging/android/build_apk.sh      # same, via helper script
```

### Continuous Integration

| Workflow | Trigger | Output |
|----------|---------|--------|
| [`ci.yml`](.github/workflows/ci.yml) | push / PR | `flutter analyze` + `flutter test` on every change |
| [`release.yml`](.github/workflows/release.yml) | push to `main`, tag `v*`, manual | `.deb`, portable `.tar.gz`, universal `.apk`; published to a GitHub Release on tags |

No local Android SDK or desktop toolchain needed — the runners provide them.

## Project Structure

```
localdrop/
|-- lib/
|   |-- app/                 # App shell, routing, theming
|   |-- core/
|   |   |-- constants/       # App + network constants (ports, timeouts)
|   |   |-- errors/          # Typed exception hierarchy
|   |   +-- utils/           # Crypto, file, formatting, network helpers
|   |-- features/            # Screens: home, transfers, history, settings, pairing
|   |-- models/              # Device, Transfer, TransferFile, PairingSession
|   |-- services/            # Discovery, transfer server/client, DB, pairing, settings
|   |-- widgets/             # Reusable UI components
|   +-- main.dart            # Entry point + service bootstrap
|-- linux/                   # Linux runner (CMake, GTK)
|-- android/                 # Android runner (Gradle, manifest, resources)
|-- packaging/
|   |-- linux/               # .deb packaging + dependency installer
|   +-- android/             # APK build helper
|-- test/                    # Unit + widget tests
|-- assets/icons/            # Application icon
+-- .github/workflows/       # CI + release automation
```

## Technology

| Area | Choice |
|------|--------|
| UI / framework | Flutter (Material 3) |
| State management | `provider` |
| HTTP server / client | `dart:io` `HttpServer`, `http` |
| Persistence | `sqflite` + `sqflite_common_ffi` (SQLite) |
| Discovery | `dart:io` `RawDatagramSocket` (UDP multicast/broadcast) |
| Security | `crypto`, `convert` (session tokens, checksums) |
| Platform info | `device_info_plus`, `network_info_plus` |
| Pairing | `qr_flutter`, `mobile_scanner` |
| File handling | `file_picker`, `desktop_drop`, `path_provider` |

## Troubleshooting

<details>
<summary><strong>Devices don't see each other</strong></summary>

- Confirm both are on the same subnet: `ip -brief address`
- Check the firewall on both machines:
  ```bash
  sudo ufw status | grep -E '53317|53318'
  ```
- Disable **AP / client isolation** on the router — the most common cause.
- On machines with several NICs (Wi-Fi + Ethernet), both devices must use the same network.
</details>

<details>
<summary><strong>Transfer is rejected or times out</strong></summary>

- Run the app from a terminal (`localdrop`) to watch live logs.
- Verify the receiver is still running and the peer has not gone stale (12 s timeout).
- Large transfers may need the machine to stay awake.
</details>

<details>
<summary><strong>Linux build fails: GTK / clang / cmake missing</strong></summary>

```bash
sudo bash packaging/linux/install_deps.sh
flutter doctor     # "Linux toolchain" should be green
```
</details>

<details>
<summary><strong>Android build: SDK or JDK errors</strong></summary>

- Run `flutter doctor -v` and resolve the reported Android toolchain issues.
- JDK 17+ is required; confirm with `java -version`.
- If your machine struggles with Android builds, let [CI](#continuous-integration) produce the APK instead.
</details>

## Contributing

Contributions are welcome.

1. Fork the repository and create a branch: `git checkout -b feat/my-change`
2. Keep changes focused and add tests where it makes sense.
3. Ensure the checks pass locally:
   ```bash
   flutter analyze && flutter test
   ```
4. Open a pull request — CI verifies your branch automatically.

Keep code consistent with the existing architecture (`lib/services` for logic, `lib/features` for UI) and document any new network behaviour.

## Security

LocalDrop is designed for **trusted local networks**. Discovery and transfers use plain HTTP on the LAN, protected by per-session tokens and checksum verification — this is not transport encryption. Do not use it over untrusted or public networks.

To report a vulnerability, open a [private security advisory](https://github.com/ankitkhatrik6/localdrop/security/advisories/new) instead of a public issue.

## License

Released under the [MIT License](LICENSE).

<div align="center">

Built with [Flutter](https://flutter.dev) · Your files stay on your network.

</div>