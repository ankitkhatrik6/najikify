# ---------------------------------------------------------------------------
# Najikify app-level R8 / ProGuard rules
# ---------------------------------------------------------------------------
# Why this file exists
# --------------------
# Android release builds run R8 in "full mode" (the default from AGP 9 onwards).
# ML Kit creates most of its implementation through reflection from the
# `com.google.android.gms.internal.mlkit_*` packages. Those packages are NOT
# covered by the consumer rules shipped with ML Kit or with mobile_scanner
# (that file only keeps `com.google.mlkit.*`), so R8 removes them and
# `BarcodeScanning.getClient()` fails while the camera is starting:
#
#   java.lang.NullPointerException: Attempt to invoke virtual method
#   'java.lang.Class java.lang.Object.getClass()' on a null object reference
#
# mobile_scanner surfaces that native failure as:
#
#   MobileScannerException: code genericError, message: Attempt to invoke ...
#
# Debug builds never hit this because R8 is not applied to them. Keeping the
# internal ML Kit packages below restores the Android QR scanner / camera in
# release builds.
# ---------------------------------------------------------------------------

# ML Kit public API (BarcodeScanning, Barcode, InputImage, ...).
-keep class com.google.mlkit.** { *; }

# ML Kit internals reached through reflection (LazyInstanceMap, registrars,
# component discovery). These are the classes R8 full mode used to strip.
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_barcode_scanning.** { *; }

# Bundled barhopper barcode model bridge.
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }

# Optional ML Kit / Dynamite modules that are not packaged in this app but are
# referenced from the kept ML Kit code.
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**
-dontwarn com.google.android.gms.internal.mlkit_dynamite.**
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode_bundled.**

# CameraX resolves camera provider extensions and camera2 interop by name.
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# mobile_scanner plugin entry points (MethodChannel handlers, view/lifecycle).
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# permission_handler resolves the current Activity reflectively.
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Barcode/format parsing relies on enum values()/valueOf().
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
