plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            signingConfig = signingConfigs.getByName("debug")
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
