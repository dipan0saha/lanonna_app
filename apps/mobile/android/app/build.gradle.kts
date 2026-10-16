import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun readMaestroLocalEnvValue(mobileRoot: File, key: String): String {
    val envFile = File(mobileRoot, "maestro/local.env")
    if (!envFile.isFile) {
        return ""
    }
    for (line in envFile.readLines()) {
        val trimmed = line.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) {
            continue
        }
        val eq = trimmed.indexOf('=')
        if (eq <= 0) {
            continue
        }
        if (trimmed.substring(0, eq).trim() == key) {
            return trimmed.substring(eq + 1).trim().removeSurrounding("\"").removeSurrounding("'")
        }
    }
    return ""
}

fun readAppCheckDebugToken(mobileRoot: File): String {
    System.getenv("APP_CHECK_DEBUG_TOKEN")?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
    return readMaestroLocalEnvValue(mobileRoot, "APP_CHECK_DEBUG_TOKEN").trim()
}

fun escapeBuildConfigString(value: String): String =
    value.replace("\\", "\\\\").replace("\"", "\\\"")

val mobileRoot = rootProject.file("..")
val appCheckDebugToken = readAppCheckDebugToken(mobileRoot)

android {
    namespace = "com.lanonna.lanonna"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lanonna.lanonna"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["applicationName"] = "com.lanonna.lanonna.LanonnaApplication"
    }

    buildTypes {
        debug {
            buildConfigField(
                "String",
                "APP_CHECK_DEBUG_TOKEN",
                "\"${escapeBuildConfigString(appCheckDebugToken)}\"",
            )
        }
        release {
            buildConfigField("String", "APP_CHECK_DEBUG_TOKEN", "\"\"")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.firebase:firebase-common")
}
