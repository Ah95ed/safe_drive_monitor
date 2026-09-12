# Flutter Embedding & JNI Entry Points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve native JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# TensorFlow Lite / LiteRT native bindings
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.ai.edge.litert.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn com.google.ai.edge.litert.**

# Google ML Kit Face Detection
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.mlkit.common.** { *; }
-dontwarn com.google.mlkit.**

# Foreground Service & Lifecycle Preservation
-keep class com.eyewatchdriver.eye.safe_drive_monitor.DriverMonitoringService { *; }
-keep class com.eyewatchdriver.eye.safe_drive_monitor.MainActivity { *; }

# Play Core & Flutter Split Engine
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# Strip development logs in Release builds (Log.v, Log.d, Log.i)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

