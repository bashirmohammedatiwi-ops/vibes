import java.io.FileInputStream
import java.util.Properties

// مفتاح رفع المتاجر — android/key.properties (خارج git) يشير إلى ملف .jks في ~/vibes-keys
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vibes.vibes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vibes.vibes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // أداء وحجم: معالجات ARM64 الحديثة فقط — يستبعد x86/armeabi
        // (يخفض APK من ~190MB إلى ~90MB بلا أي تأثير على الهواتف الحقيقية)
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    // استبعاد مكتبات المعالجات غير المستخدمة من حزم AAR (Mapbox/WebRTC/Rive)
    packaging {
        jniLibs {
            excludes += listOf(
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/armeabi-v7a/**",
            )
        }
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.containsKey("storeFile")) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // توقيع الإصدار بمفتاح الرفع؛ بدون key.properties يرجع لمفتاح debug (للتجربة فقط)
            signingConfig = if (keystoreProperties.containsKey("storeFile"))
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
