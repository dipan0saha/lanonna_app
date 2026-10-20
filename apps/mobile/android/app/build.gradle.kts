import java.io.File
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
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

fun decodeDartDefines(): Map<String, String> {
    val raw = project.findProperty("dart-defines") as String? ?: return emptyMap()
    val result = mutableMapOf<String, String>()
    for (entry in raw.split(",")) {
        if (entry.isBlank()) continue
        val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
        val eq = decoded.indexOf('=')
        if (eq <= 0) continue
        result[decoded.substring(0, eq)] = decoded.substring(eq + 1)
    }
    return result
}

val mobileRoot = rootProject.file("..")
val appCheckDebugToken = readAppCheckDebugToken(mobileRoot)
val dartDefines = decodeDartDefines()
val appEnv = dartDefines["APP_ENV"] ?: "dev"
val appLinkHost = dartDefines["APP_LINK_HOST"] ?: "lanonna-dev.firebaseapp.com"
val isProdBuild = appEnv == "prod"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

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

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.isFile) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.lanonna.lanonna"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["applicationName"] = "com.lanonna.lanonna.LanonnaApplication"
        manifestPlaceholders["appLinkHost"] = appLinkHost
        buildConfigField("String", "APP_CHECK_DEBUG_TOKEN", "\"\"")
    }

    buildTypes {
        debug {
            buildConfigField(
                "String",
                "APP_CHECK_DEBUG_TOKEN",
                "\"${escapeBuildConfigString(appCheckDebugToken)}\"",
            )
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            when {
                isProdBuild && !keystorePropertiesFile.isFile -> {
                    throw GradleException(
                        "Prod release requires android/key.properties with an upload keystore. " +
                            "See apps/mobile/android/README.md",
                    )
                }
                keystorePropertiesFile.isFile -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                else -> {
                    signingConfig = signingConfigs.getByName("debug")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.firebase:firebase-common")
}
