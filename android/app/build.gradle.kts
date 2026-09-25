import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------- Signing ---
//
// A release APK must be signed with a dedicated, stable key — NOT the Android
// debug key. A debug-signed "release" APK is flagged by Google Play Protect as
//
//   "Play Protect hasn't seen an app from this developer before. It may be
//    unsafe." / "App blocked to protect your device."
//
// (Play Protect "Uncommon" category, see
// https://developers.google.com/android/play-protect/warning-strings)
// because `androiddebugkey` is a globally known, untrusted identity.
//
// Credentials are resolved from, in order:
//   1. android/key.properties          — local builds (git-ignored)
//   2. RELEASE_KEYSTORE_* env vars     — CI (GitHub Actions secrets)
//
// If neither is available the build falls back to the debug key so that a
// fresh clone can still run `flutter build apk`.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String? =
    (keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey))
        ?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("storeFile", "RELEASE_KEYSTORE_FILE")
val releaseStoreFile = releaseStorePath?.let { file(it) }
val releaseStorePassword = signingValue("storePassword", "RELEASE_STORE_PASSWORD")
val releaseKeyAliasValue = signingValue("keyAlias", "RELEASE_KEY_ALIAS")
val releaseKeyPasswordValue = signingValue("keyPassword", "RELEASE_KEY_PASSWORD")
val hasReleaseSigning = releaseStoreFile != null &&
    releaseStorePassword != null &&
    releaseKeyAliasValue != null &&
    releaseKeyPasswordValue != null

android {
    namespace = "com.najikify.app"
    // Pinned to 36: flutter_plugin_android_lifecycle (via file_picker)
    // requires compiling against Android API 36+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.najikify.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        //
        // Android 7.0 (API 24) is the hard floor: file_selector_android,
        // url_launcher_android and flutter_plugin_android_lifecycle all declare
        // minSdk 24 in their own manifests, so a lower value fails manifest
        // merging. Devices older than Android 7 therefore cannot install
        // Najikify — "App not installed as package appears to be invalid" on such
        // a device is a platform limit, not a signing problem. The APK is signed
        // with the v2 + v3 schemes, which is exactly what API 24+ verifies.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAliasValue
                keyPassword = releaseKeyPasswordValue
                // v1 (JAR) covers API <= 23, v2 covers API >= 24, v3 enables
                // signing-key rotation. All three are requested so the APK
                // verifies on every Android version we support.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Release builds run R8 in full mode (AGP 9 default). R8 strips the
            // ML Kit classes that BarcodeScanning.getClient() reaches through
            // reflection, which aborts the camera with
            // "Attempt to invoke virtual method 'java.lang.Class
            // java.lang.Object.getClass()' on a null object reference".
            // proguard-rules.pro keeps those classes so the Android QR scanner
            // works in release builds too.
            isMinifyEnabled = true
            // Keep resource shrinking off: Flutter assets/resources are looked
            // up dynamically and are not worth the risk for a sideloaded APK.
            isShrinkResources = false
            proguardFiles("proguard-rules.pro")
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Najikify: no release signing config found (android/key.properties " +
                        "or RELEASE_KEYSTORE_* env vars). Falling back to the debug key — " +
                        "this APK will be reported by Google Play Protect as an app " +
                        "'from a developer it hasn't seen before'."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}


kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Bundled ML Kit barcode scanning used by mobile_scanner. Declaring it here
    // (alongside the keep rules in proguard-rules.pro) pins the version that
    // ships in the APK and marks it as a direct dependency of the app module,
    // which keeps R8 from treating the reflection-accessed ML Kit classes as
    // unused code in release builds.
    implementation("com.google.mlkit:barcode-scanning:17.2.0")

    // CameraX versions used by mobile_scanner 5.x.
    implementation("androidx.camera:camera-lifecycle:1.3.3")
    implementation("androidx.camera:camera-camera2:1.3.3")
}

flutter {
    source = "../.."
}
