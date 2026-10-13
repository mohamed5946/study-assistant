import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, if provided by CI in android/key.properties.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "com.valor.studyassistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    if (hasReleaseKey) {
        signingConfigs {
            create("release") {
                storeFile =
                    file(keystoreProperties.getProperty("storeFile")!!)
                storePassword =
                    keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (uses java.time APIs on API < 26)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.valor.studyassistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Stable release key when android/key.properties exists (CI),
            // otherwise the debug key so `flutter run --release` keeps working.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    // Desugared JDK libs for core library desugaring (see compileOptions above)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // home_widget asks for glance-appwidget:1.+ which resolves to
    // 1.3.0-alpha02 (needs compileSdk 37). Pin to the latest stable 1.x
    // that builds against SDK 36; the plugin only uses stable APIs.
    constraints {
        implementation("androidx.glance:glance-appwidget:1.1.1") {
            because("newer versions require compileSdk 37")
        }
    }
}
