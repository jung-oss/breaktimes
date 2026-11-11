import java.io.FileInputStream
import java.util.Properties
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
// key.properties 파일 로드
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
android {
    namespace = "com.gemma.breaktimes.breaktimes"
    compileSdk = 35  // 플러그인 요구사항에 맞춰 35로 업데이트
    ndkVersion = "27.0.12077973"
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    // 릴리즈 서명 설정
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
    defaultConfig {
        applicationId = "com.gemma.breaktimes.breaktimes"
        minSdk = 23
        targetSdk = 35  // Android 15 지원을 위해 35로 업데이트
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // R8/ProGuard 활성화
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard 규칙 파일 적용
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            // 디버그 빌드 설정
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
flutter {
    source = "..\\.."
}
dependencies {
    // Core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Play Integrity API (Firebase App Check에서 자동으로 포함되지만 명시적으로 추가)
    implementation("com.google.android.play:integrity:1.4.0")
    
    // AndroidX Core (edge-to-edge 지원용)
    implementation("androidx.core:core-ktx:1.13.1")
}