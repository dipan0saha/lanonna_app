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
    // Flutter passes each define as base64("KEY=value"), comma-separated.
    // Skip entries that are not valid base64 rather than failing configuration.
    for (entry in raw.split(",")) {
        val trimmed = entry.trim()
        if (trimmed.isEmpty()) continue
        val bytes = runCatching { Base64.getDecoder().decode(trimmed) }.getOrNull() ?: continue
        val decoded = String(bytes, Charsets.UTF_8)
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

// Prod must not ship with the dev Firebase app baked into native resources
// (Crashlytics, FCM and Analytics read google-services.json before Dart runs).
fun googleServicesProjectId(appDir: File): String? {
    val json = File(appDir, "google-services.json")
    if (!json.isFile) return null
    @Suppress("UNCHECKED_CAST")
    val root = groovy.json.JsonSlurper().parse(json) as Map<String, Any?>
    val info = root["project_info"] as Map<String, Any?>?
    return info?.get("project_id") as String?
}

// Upload keystore is prod-only; dev release must keep the debug cert (Firebase / Google Sign-In).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (isProdBuild && keystorePropertiesFile.isFile) {
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
        if (isProdBuild && keystorePropertiesFile.isFile) {
            create("release") {
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
            // Non-prod release always uses the debug keystore (ignores key.properties).
            // Prod without key.properties gets no signing config; the release-task check fails loudly.
            signingConfig = when {
                isProdBuild && keystorePropertiesFile.isFile -> signingConfigs.getByName("release")
                isProdBuild -> null
                else -> signingConfigs.getByName("debug")
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

// Prod release guards run only when a release task is actually scheduled, so a
// prod `flutter run` (debug) or Gradle sync still works without a keystore.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.project == project && task.name.contains("Release")
    }
    if (!isProdBuild || !releaseRequested) return@whenReady
    if (!keystorePropertiesFile.isFile) {
        throw GradleException(
            "Prod release requires android/key.properties with an upload keystore. " +
                "See apps/mobile/android/README.md",
        )
    }
    val missingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "Prod release: android/key.properties is missing ${missingKeys.joinToString()}. " +
                "See apps/mobile/android/README.md",
        )
    }
    val storeFile = file(keystoreProperties.getProperty("storeFile"))
    if (!storeFile.isFile) {
        throw GradleException(
            "Prod release: upload keystore not found at the storeFile path in android/key.properties.",
        )
    }
    val firebaseProject = googleServicesProjectId(project.projectDir)
    if (firebaseProject == null || firebaseProject == "lanonna-dev") {
        throw GradleException(
            "Prod release requires android/app/google-services.json for the prod Firebase project " +
                "(found ${firebaseProject ?: "none"}). Run flutterfire configure for prod first.",
        )
    }
}
