# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve Annotations & Generics
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Network & Serializers
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Razorpay & Payment Gateway
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
-dontwarn proguard.annotation.**
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers

# Flutter deferred components / Play Core (not used, avoids R8 missing-class errors)
-dontwarn com.google.android.play.core.**

# Firestore / protobuf / OkHttp
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Google Sign-In / Credential & Sign in with Apple (web flow)
-keep class com.google.android.gms.auth.** { *; }

# Camera / ML / AR filter SDKs (add vendor packages here if introduced, e.g. DeepAR/Banuba)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class ai.deepar.** { *; }
-dontwarn ai.deepar.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Security & Crypto
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Geolocator Location Services (prevents release R8 method stripping)
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

