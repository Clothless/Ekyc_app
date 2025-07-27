# --- ML Kit: Prevent R8 from removing ML Kit recognizers (Chinese, Japanese, etc.)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# --- JAI ImageIO: Prevent removal of image codec classes
-keep class javax.imageio.** { *; }
-dontwarn javax.imageio.**

-keep class com.github.jaiimageio.** { *; }
-dontwarn com.github.jaiimageio.**

# --- General Flutter/Plugin keep rules
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
