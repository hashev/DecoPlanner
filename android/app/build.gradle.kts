plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.hashev.decoplanner"
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
        applicationId = "io.github.hashev.decoplanner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("publicRelease") {
            val keystore = System.getenv("DECOPLANNER_ANDROID_KEYSTORE")
            if (!keystore.isNullOrBlank()) {
                storeFile = file(keystore)
                storePassword = System.getenv("DECOPLANNER_ANDROID_STORE_PASSWORD")
                keyPassword = System.getenv("DECOPLANNER_ANDROID_KEY_PASSWORD")
                keyAlias = System.getenv("DECOPLANNER_ANDROID_KEY_ALIAS")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("publicRelease")
        }
    }
}

flutter {
    source = "../.."
}

// Configuration of debug tasks remains possible without release secrets.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        listOf("DECOPLANNER_ANDROID_KEYSTORE", "DECOPLANNER_ANDROID_STORE_PASSWORD",
            "DECOPLANNER_ANDROID_KEY_PASSWORD", "DECOPLANNER_ANDROID_KEY_ALIAS").forEach {
            require(!System.getenv(it).isNullOrBlank()) { "Release signing requires $it" }
        }
    }
}
