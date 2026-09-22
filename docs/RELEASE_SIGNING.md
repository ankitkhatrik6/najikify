# Release signing

Najikify's Android release APK is signed with a **dedicated release key**, never
with the shared Android debug key.

## Why this matters (Play Protect)

Installing a debug-signed APK shows:

> App blocked to protect your device — Play Protect hasn't seen an app from
> this developer before. It may be unsafe.

That is the Play Protect **"Uncommon"** category: `androiddebugkey` is a
well-known, globally shared, untrusted certificate, so Play Protect treats every
app signed with it as an unknown developer. Signing with a stable, unique release
key removes that signal — the same key across releases also means Android treats
new versions as legitimate updates instead of a different app.

Reference: <https://developers.google.com/android/play-protect/warning-strings>

## Release key

| Field | Value |
|-------|-------|
| Alias | `najikify` |
| Store type | PKCS12 (`.p12`) |
| Key algorithm | RSA 4096 |
| Validity | 30 years |
| SHA-256 fingerprint | `DE:39:18:44:45:FF:AC:FA:C7:F8:00:C9:3E:36:A4:55:5C:CD:63:51:6B:16:24:CE:1D:A8:E5:40:97:E2:4E:3C` |
| SHA-1 fingerprint | `76:51:D7:13:48:8C:93:DF:20:7C:DF:4B:CC:58:48:B9:0F:3B:36:76` |

The keystore itself is **never committed**. It is stored outside the repository
and injected into releases through GitHub Actions secrets:

| Secret | Purpose |
|--------|---------|
| `RELEASE_KEYSTORE_BASE64` | Base64 of `najikify-release.p12` |
| `RELEASE_STORE_PASSWORD` | Keystore password |
| `RELEASE_KEY_PASSWORD` | Key password (same as store password) |
| `RELEASE_KEY_ALIAS` | `najikify` |

## Verifying a downloaded APK

Anyone can confirm a downloaded APK really comes from this signing identity:

```bash
# Requires Android build-tools (apksigner)
apksigner verify --print-certs najikify-android-<version>.apk
```

The printed `Signer #1 certificate SHA-256 digest` must match the SHA-256
fingerprint in the table above. The CI job
`.github/workflows/release.yml` runs the same check on every release and fails
the build if the APK is debug-signed.

## Building locally with the release key

Create `android/key.properties` (git-ignored):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=najikify
storeFile=/absolute/path/to/najikify-release.p12
storeType=PKCS12
```

`flutter build apk --release` then uses the release key. Without this file (and
without the `RELEASE_KEYSTORE_*` environment variables) Gradle falls back to the
debug key with a warning so a fresh clone still builds.

## If Play Protect still blocks a sideload

Play Protect reputation is built up per signing certificate over time; a brand
new key can still be reported as "uncommon" on the first installs, but it is no
longer the debug key. Options for the user:

1. Tap **Install anyway** / **More details → Install anyway** in the Play
   Protect dialog.
2. Temporarily disable **Play Protect scanning** in
   *Play Store → Profile → Play Protect → Settings*.
3. Verify the APK against the SHA-256 fingerprint above before installing, which
   is the real security check for a sideloaded app.

Najikify also asks for the minimum permission set (camera + LAN networking), so
it does not trip the higher-severity Play Protect categories.
