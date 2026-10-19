// Committed on purpose. `flutter create` only writes files that are missing, so this one
// file - the one that needs a release signingConfig - stays under our control while the
// rest of the Android project (settings.gradle.kts, the wrapper, MainActivity, resources)
// is still generated at build time and keeps matching the installed Flutter version.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin has to be applied after the Android and Kotlin ones.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties points at the release keystore. CI writes it from repository
// secrets; locally you can write it by hand. Both it and the keystore are gitignored.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
val hasReleaseKey = releaseStoreFile != null && releaseStoreFile.exists()

if (hasReleaseKey) {
    logger.lifecycle("RelaxMD: signing release builds with the key from key.properties.")
} else {
    logger.lifecycle(
        "RelaxMD: no android/key.properties - signing release builds with the debug key. " +
            "Those APKs install on a clean phone but cannot upgrade an APK signed with another key."
    )
}

android {
    namespace = "com.relaxmd.relaxmd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.relaxmd.relaxmd"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // `flutter build apk --build-number=N` lands here; CI passes the run number so
        // every build looks like an upgrade to the phone.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // One stable key for every build, so a new APK installs over the previous one.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
