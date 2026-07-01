import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Wczytanie danych do podpisywania z android/key.properties (poza gitem).
// Plik: keyAlias, keyPassword, storeFile, storePassword.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "pl.grkotarba.slowenia_app"
    // Przypięte jawnie (nie flutter.compileSdkVersion) — plugin ota_update ciągnie
    // androidx.core:1.16.0 wymagający compileSdk 35+. CI z innym stable Fluttera
    // mógłby mieć niższy domyślny → build fail. 36 spełnia wymóg pluginu.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring — wymagane przez ota_update 7+.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "pl.grkotarba.slowenia_app"
        // Przypięte jawnie — ota_update wymaga minSdk 23. Ustawiamy 24 (Android 7.0,
        // rozsądny floor 2026) niezależnie od domyślnego flutter.minSdkVersion na CI.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Jeśli mamy key.properties → używamy stałego keystore (wymagane dla OTA).
            // W przeciwnym razie fallback do debug (żeby `flutter run --release` działało).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
