// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // plugin Google Services FCM
}

android {
    namespace = "com.example.cso_mobile"   // ✅ doit correspondre à Firebase
    compileSdk = 36

    defaultConfig {
       applicationId = "com.example.cso_mobile" // ✅ doit correspondre à Firebase
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            signingConfig = signingConfigs.getByName("debug") // à changer plus tard
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ⚠️ Desugar pour Java 17
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))

    // Firebase Messaging
    implementation("com.google.firebase:firebase-messaging")

    // AndroidX Core
    implementation("androidx.core:core-ktx:1.12.0")

    // Flutter embedding
    implementation("io.flutter:flutter_embedding_debug:1.0.0") // si nécessaire
}
