# Golden Care ProGuard/R8 Rules
# Applied to release builds for code shrinking and obfuscation

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services (Maps, Auth, etc.)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Razorpay
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Gson / JSON serialization
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of crypto classes
-keep class javax.crypto.** { *; }
