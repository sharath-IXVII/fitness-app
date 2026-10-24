import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: create android/key.properties (never commit it) with
// storePassword, keyPassword, keyAlias and storeFile. See docs/RELEASE.md.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.GetYr_io.fittiePi"
    // 37: required by permission_handler. Only affects which APIs compile; minSdk
    // still decides which phones can install the app.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Final package name: choose it before the first Play upload; it can't change afterwards.
        applicationId = "com.GetYr_io.fittiePi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10+: the step counter (pedometer_2) needs API 29.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys so `flutter run --release` works before
            // a release keystore is set up. Play only accepts the release key.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Code shrinking is off until the app has been verified on devices:
            // R8 can strip classes that plugins (ML Kit, notifications) load
            // by reflection, which only shows up as a crash at runtime.
            isMinifyEnabled = false
            isShrinkResources = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Real phone/Google sign-in turns on once Firebase's google-services.json is
// placed in android/app/. Without it the app builds and runs in demo mode.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
