# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class mu.studio.raphus.lets_get_cooking_app.** { *; }

# -- Flutter R8 Rules --

# The Flutter engine includes code for "Deferred Components" (dynamic features)
# which references the Google Play Core library. Since you aren't using this feature,
# we tell R8 to ignore the missing classes to prevent the build error.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**