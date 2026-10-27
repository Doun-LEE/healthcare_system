import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase 안드로이드 앱 설정(google-services.json)이 있을 때만 플러그인 적용.
// 파일이 없어도(구글 로그인 미설정) 빌드는 된다.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// 릴리스 서명: CI 는 환경변수, 로컬은 android/key.properties 로 전달한다.
// 둘 다 없으면 debug 키로 서명한다(업데이트 설치는 깨지므로 배포용으로는 쓰지 말 것).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val storeFilePath = System.getenv("ANDROID_KEYSTORE_PATH") ?: keyProps.getProperty("storeFile")
val storePass = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: keyProps.getProperty("storePassword")
val keyAliasName = System.getenv("ANDROID_KEY_ALIAS") ?: keyProps.getProperty("keyAlias")
val hasReleaseKey = storeFilePath != null && storePass != null && keyAliasName != null && file(storeFilePath).exists()

android {
    namespace = "com.doun.fit_routine"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.doun.fit_routine"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(storeFilePath!!)
                storePassword = storePass
                keyAlias = keyAliasName
                keyPassword = storePass
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}


dependencies {
    // 운동 기록 사진 글자 인식(기기 안, 오프라인) — 한국어 모델
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
