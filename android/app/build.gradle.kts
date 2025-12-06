plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.wastefood"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.wastefood"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../../"
}

dependencies {
    // Lib desugaring agar bisa pakai Java 8+ API di Android lama
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Kotlin dan AndroidX Core modern
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.core:core-ktx:1.12.0")
}
