# Zync release keep rules.
#
# JNI 符号形如 Java_com_zync_app_RawProcessorBridge_nativeRenderPreview，
# 一旦类名或 native 方法名被 R8 改写，C++ 侧就找不到入口，运行时直接崩溃。

-keep class com.zync.app.RawProcessorBridge { *; }
-keep class com.zync.app.SpektrafilmBridge { *; }
-keep class com.zync.app.VideoEditorBridge { *; }
-keep class com.zync.app.GradeLutFactory { *; }
-keep class com.zync.app.KeyframedGradeEffect { *; }
-keep class com.zync.app.SpatialGradeEffect { *; }
-keep class com.zync.app.VideoFrameGrabber { *; }
-keep class com.zync.app.CubeLutLoader { *; }
-keep class com.zync.app.TransferKeepAliveService { *; }

-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Flutter 嵌入层通过反射查找；插件注册表同样依赖类名。
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Media3 的扩展点由厂商/设备在运行时解析，缺少可选类时不应让构建失败。
-dontwarn androidx.media3.**
-keep class androidx.media3.** { *; }

# Flutter 的 deferred-components 分支引用了 Play Core；本应用不使用延迟组件，
# 因此这些类在运行时不存在，只需要让 R8 不要在编译期报缺失。
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
