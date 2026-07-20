# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Billing (in_app_purchase)
-keep class com.android.vending.billing.** { *; }

# Play Core / deferred components — referenced by Flutter's split-install glue
# even when the app does not use deferred components.
-dontwarn com.google.android.play.core.**
