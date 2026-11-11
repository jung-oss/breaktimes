# Flutter Local Notifications 플러그인 관련 규칙
-keep class com.dexterous.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.work.** { *; }

# DateTimeComponents 클래스와 TimeZone 클래스 보존
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class org.threeten.bp.** { *; }
-keep class java.time.** { *; }

# TypeToken 관련 규칙 추가
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# 제네릭 보존
-keepattributes Signature
-keepattributes Exceptions
-keepattributes *Annotation*
-keepattributes Deprecated
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Flutter Foreground Task 관련 규칙
-keep class com.pravera.flutter_foreground_task.** { *; }

# 알람 관련 클래스 보존
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# SafetyNet API 제거 (Play Integrity API로 교체)
-dontwarn com.google.android.gms.safetynet.**
-dontwarn com.google.firebase.appcheck.safetynet.**

# Play Integrity API 관련 규칙 (필요한 경우)
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.firebase.appcheck.playintegrity.** { *; }

# Firebase App Check 관련 규칙
-keep class com.google.firebase.appcheck.** { *; }
-dontwarn com.google.firebase.appcheck.safetynet.**

# Android 15에서 지원 중단된 API 관련 경고 억제
-dontwarn android.view.Window$setStatusBarColor
-dontwarn android.view.Window$setNavigationBarColor
-dontwarn android.view.Window$setNavigationBarDividerColor

# Firebase Storage에서 발생하는 지원 중단 API 경고 억제
-dontwarn com.google.firebase.storage.**

# 직렬화/역직렬화 관련 클래스들
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 알림 설정 작업을 위한 TimeZone 및 DateTime 관련 클래스들
-keep class org.threeten.bp.zone.** { *; }
-keep class org.threeten.bp.format.** { *; }
-keep class org.threeten.bp.temporal.** { *; }

# 알림 데이터 구조체들
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.app.NotificationManagerCompat** { *; }
-keep class androidx.core.app.NotificationChannelCompat** { *; }
-keep class androidx.core.app.NotificationChannelGroupCompat** { *; }

# DateTimeComponents 클래스와 TypeToken 직접 지정
-keep class com.dexterous.flutterlocalnotifications.models.DateTimeComponents { *; }
-keep class com.dexterous.flutterlocalnotifications.models.styles.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.NotificationDetails** { *; }

# R8 최적화 무시 (TypeToken 문제에 도움)
-optimizations !class/unboxing/enum

# flutter_foreground_task 관련 규칙
-keep class com.pravera.flutter_foreground_task.** { *; }

# flutter_local_notifications 관련 규칙
-keep class com.dexterous.** { *; }

# Gson 관련 규칙 (TypeToken 문제 해결)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class * extends com.google.gson.TypeAdapter

# 기타 필요한 규칙
-keep class androidx.lifecycle.** { *; }
-keep class androidx.core.app.** { *; }