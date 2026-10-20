# Release builds are shrunk by R8, which only keeps code it sees being called from
# Java/Kotlin. Some plugins call their Android code from Dart through JNI instead,
# so R8 strips or renames it and the app fails at runtime with NoSuchMethodError.

# shared_preferences_android: Dart calls SharedPreferencesApiRegistrar.getAll etc. via JNI.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# The JNI bridge used by shared_preferences_android and path_provider_android.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Kotlin coroutine types appear in those JNI method signatures (suspend functions).
-keep class kotlin.coroutines.Continuation { *; }
